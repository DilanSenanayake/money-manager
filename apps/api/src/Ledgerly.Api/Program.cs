using System.Diagnostics;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using Ledgerly.Api.Infrastructure;
using Ledgerly.Api.Infrastructure.Auth;
using Ledgerly.Api.Infrastructure.Llm;
using Ledgerly.Api.Infrastructure.Logging;
using Ledgerly.Api.Infrastructure.Supabase;
using Ledgerly.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Logging.ClearProviders();
builder.Logging.Configure(options =>
{
    options.ActivityTrackingOptions =
        ActivityTrackingOptions.TraceId
        | ActivityTrackingOptions.SpanId
        | ActivityTrackingOptions.ParentId;
});
if (builder.Environment.IsProduction())
{
    builder.Logging.AddJsonConsole(options =>
    {
        options.IncludeScopes = true;
        options.UseUtcTimestamp = true;
        options.TimestampFormat = "yyyy-MM-dd'T'HH:mm:ss.fff'Z'";
        options.JsonWriterOptions = new JsonWriterOptions { Indented = false };
    });
}
else
{
    builder.Logging.AddSimpleConsole(options =>
    {
        options.IncludeScopes = true;
        options.SingleLine = true;
        options.UseUtcTimestamp = true;
        options.TimestampFormat = "yyyy-MM-dd'T'HH:mm:ss.fff'Z' ";
    });
}

builder.WebHost.ConfigureKestrel(options =>
{
    options.Limits.MaxRequestBodySize = 1_048_576;
});

builder.Services.Configure<SupabaseOptions>(
    builder.Configuration.GetSection(SupabaseOptions.SectionName));
builder.Services.Configure<GroqOptions>(
    builder.Configuration.GetSection(GroqOptions.SectionName));
builder.Services.Configure<LedgerlyCorsOptions>(
    builder.Configuration.GetSection(LedgerlyCorsOptions.SectionName));

var supabase = builder.Configuration.GetSection(SupabaseOptions.SectionName).Get<SupabaseOptions>()
               ?? new SupabaseOptions();
var cors = builder.Configuration.GetSection(LedgerlyCorsOptions.SectionName).Get<LedgerlyCorsOptions>()
           ?? new LedgerlyCorsOptions();

if (builder.Environment.IsProduction())
{
    if (string.IsNullOrWhiteSpace(supabase.Url) || string.IsNullOrWhiteSpace(supabase.AnonKey))
    {
        throw new InvalidOperationException(
            "Supabase:Url and Supabase:AnonKey must be set in production (Supabase__Url, Supabase__AnonKey).");
    }

    if (cors.Origins is null || cors.Origins.Length == 0)
    {
        throw new InvalidOperationException(
            "Cors:Origins must be set in production (e.g. Cors__Origins__0=https://your-app.vercel.app).");
    }
}

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    // Trust the reverse proxy sitting in front of this process (Caddy, Nginx, cloud LB).
    // The proxy MUST overwrite client-supplied X-Forwarded-* headers.
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});

builder.Services.AddHttpContextAccessor();
builder.Services.AddHttpClient("supabase", client =>
{
    client.Timeout = TimeSpan.FromSeconds(15);
});
builder.Services.AddHttpClient("groq", client =>
{
    client.Timeout = TimeSpan.FromSeconds(30);
});

builder.Services.AddScoped<ICurrentUser, CurrentUser>();
builder.Services.AddScoped<ISupabaseRestClient, SupabaseRestClient>();
builder.Services.AddSingleton<ILlmService, GroqService>();

builder.Services.AddScoped<IAccountsService, AccountsService>();
builder.Services.AddScoped<ICategoriesService, CategoriesService>();
builder.Services.AddScoped<ITransactionsService, TransactionsService>();
builder.Services.AddScoped<IDashboardService, DashboardService>();
builder.Services.AddScoped<ISettingsService, SettingsService>();
builder.Services.AddScoped<IAiService, AiService>();
builder.Services.AddScoped<IExportService, ExportService>();

builder.Services.AddExceptionHandler<UnauthorizedExceptionHandler>();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddProblemDetails();

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.OnRejected = async (context, ct) =>
    {
        var http = context.HttpContext;
        var logger = http.RequestServices
            .GetRequiredService<ILoggerFactory>()
            .CreateLogger("Ledgerly.Api.RateLimit");
        logger.LogWarning(
            "Rate limit exceeded {Method} {Path} {RequestId} {UserId}",
            http.Request.Method,
            http.Request.Path.Value,
            http.TraceIdentifier,
            RequestLoggingMiddleware.UserId(http));

        http.Response.ContentType = "application/json";
        await http.Response.WriteAsJsonAsync(
            new { error = "Too many requests. Please wait a moment and try again." },
            ct);
    };

    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(httpContext =>
    {
        var key = httpContext.User.FindFirst("sub")?.Value
                  ?? httpContext.Connection.RemoteIpAddress?.ToString()
                  ?? "anon";
        return RateLimitPartition.GetFixedWindowLimiter(
            key,
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 120,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
            });
    });

    options.AddPolicy("ai", httpContext =>
    {
        var key = httpContext.User.FindFirst("sub")?.Value
                  ?? httpContext.Connection.RemoteIpAddress?.ToString()
                  ?? "anon";
        return RateLimitPartition.GetFixedWindowLimiter(
            $"ai:{key}",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 20,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
            });
    });
});

builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.NumberHandling =
            JsonNumberHandling.AllowReadingFromString;
    });
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Smart Money Manager API",
        Version = "v1",
        Description = "Shared backend for Smart Money Manager web and mobile clients.",
    });
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "Supabase JWT access token. Example: Bearer {token}",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
    });
    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer",
                }
            },
            Array.Empty<string>()
        }
    });
});

var supabaseUrl = (supabase.Url ?? "").TrimEnd('/');
var authIssuer = string.IsNullOrWhiteSpace(supabaseUrl)
    ? "supabase"
    : $"{supabaseUrl}/auth/v1";

// Prefer JWKS (asymmetric ES256/RS256) when Url is set.
// Also accept legacy HS256 JwtSecret when configured — many projects still use it,
// and JWKS is empty for HS256-only Auth setups.
var useJwks = !string.IsNullOrWhiteSpace(supabaseUrl);
var legacySecret = GetLegacyJwtSecret(supabase.JwtSecret);
var authModes = new List<string>();
if (useJwks) authModes.Add("JWKS");
if (legacySecret is not null) authModes.Add("legacy HS256");

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.MapInboundClaims = false;
        options.SaveToken = true;

        if (useJwks)
        {
            options.MetadataAddress =
                $"{authIssuer}/.well-known/openid-configuration";
            options.RequireHttpsMetadata = supabaseUrl.StartsWith(
                "https://",
                StringComparison.OrdinalIgnoreCase);
        }

        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = authIssuer,
            ValidateAudience = true,
            ValidAudience = "authenticated",
            ValidateIssuerSigningKey = true,
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(5),
            NameClaimType = "sub",
            RoleClaimType = "role",
        };

        // Always attach HS256 key when present so Url+legacy secret works
        // (JWKS alone fails for HS256-only Supabase projects).
        if (legacySecret is not null)
        {
            options.TokenValidationParameters.IssuerSigningKey =
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(legacySecret));
        }

        options.Events = new JwtBearerEvents
        {
            OnAuthenticationFailed = context =>
            {
                var logger = context.HttpContext.RequestServices
                    .GetRequiredService<ILoggerFactory>()
                    .CreateLogger("Ledgerly.Api.Auth");
                logger.LogWarning(
                    context.Exception,
                    "Authentication failed {Method} {Path} {RequestId}",
                    context.Request.Method,
                    context.Request.Path.Value,
                    context.HttpContext.TraceIdentifier);
                return Task.CompletedTask;
            },
            OnTokenValidated = context =>
            {
                var role = context.Principal?.FindFirst("role")?.Value
                           ?? context.Principal?.FindFirst(ClaimTypes.Role)?.Value;
                if (!string.Equals(role, "authenticated", StringComparison.Ordinal))
                {
                    context.Fail("Token role must be 'authenticated'.");
                }

                return Task.CompletedTask;
            },
        };
    });

builder.Services.AddAuthorization(options =>
{
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});

builder.Services.AddCors(options =>
{
    options.AddPolicy("Ledgerly", policy =>
    {
        policy.WithHeaders("Authorization", "Content-Type", "Accept")
            .WithMethods("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS");

        if (builder.Environment.IsDevelopment())
        {
            // Flutter web (Chrome) uses a fresh localhost port each run.
            policy.SetIsOriginAllowed(origin =>
            {
                if (!Uri.TryCreate(origin, UriKind.Absolute, out var uri))
                    return false;
                return uri.Host is "localhost" or "127.0.0.1";
            });
        }
        else
        {
            policy.WithOrigins(cors.Origins.Length > 0 ? cors.Origins : ["http://localhost:3000"]);
        }
    });
});

var app = builder.Build();

var version = typeof(Program).Assembly.GetName().Version?.ToString() ?? "unknown";
app.Logger.LogInformation(
    "Ledgerly API starting Environment {Environment} Version {Version}",
    app.Environment.EnvironmentName,
    version);
if (authModes.Count == 0)
{
    app.Logger.LogWarning(
        "Supabase URL and legacy JWT secret are unset. Auth will reject tokens.");
}
else
{
    app.Logger.LogInformation("JWT validation enabled via {AuthModes}", string.Join(" + ", authModes));
}

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseRequestLogging();
app.UseExceptionHandler();
app.UseForwardedHeaders();
app.Use(async (context, next) =>
{
    context.Response.OnStarting(() =>
    {
        var headers = context.Response.Headers;
        headers["X-Content-Type-Options"] = "nosniff";
        headers["X-Frame-Options"] = "DENY";
        headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
        headers["X-Permitted-Cross-Domain-Policies"] = "none";
        headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";
        if (context.Request.IsHttps)
        {
            headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains";
        }

        return Task.CompletedTask;
    });
    await next();
});
app.UseCors("Ledgerly");
app.UseAuthentication();
app.UseUserLogScope();
app.UseAuthorization();
app.UseRateLimiter();
app.MapControllers();

app.Run();

/// <summary>
/// Legacy JWT secret is a long shared HMAC string — not a signing-key id (UUID/kid).
/// </summary>
static string? GetLegacyJwtSecret(string? value)
{
    if (string.IsNullOrWhiteSpace(value)) return null;
    if (Guid.TryParse(value, out _)) return null;
    if (value.Length < 32) return null;
    return value;
}
