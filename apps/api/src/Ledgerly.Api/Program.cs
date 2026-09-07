using System.Security.Claims;
using System.Text;
using Ledgerly.Api.Infrastructure;
using Ledgerly.Api.Infrastructure.Auth;
using Ledgerly.Api.Infrastructure.Llm;
using Ledgerly.Api.Infrastructure.Supabase;
using Ledgerly.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

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

builder.Services.AddHttpContextAccessor();
builder.Services.AddHttpClient("supabase");
builder.Services.AddHttpClient("groq");

builder.Services.AddScoped<ICurrentUser, CurrentUser>();
builder.Services.AddScoped<ISupabaseRestClient, SupabaseRestClient>();
builder.Services.AddSingleton<ILlmService, GroqService>();

builder.Services.AddScoped<IAccountsService, AccountsService>();
builder.Services.AddScoped<ICategoriesService, CategoriesService>();
builder.Services.AddScoped<ITransactionsService, TransactionsService>();
builder.Services.AddScoped<IDashboardService, DashboardService>();
builder.Services.AddScoped<ISettingsService, SettingsService>();
builder.Services.AddScoped<IAiService, AiService>();

builder.Services.AddExceptionHandler<UnauthorizedExceptionHandler>();
builder.Services.AddProblemDetails();

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Ledgerly API",
        Version = "v1",
        Description = "Shared backend for Ledgerly web and mobile clients.",
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

if (!useJwks && legacySecret is null)
{
    Console.WriteLine(
        "WARNING: Supabase:Url is empty and no legacy JwtSecret is set. Auth will reject tokens.");
}
else
{
    var modes = new List<string>();
    if (useJwks) modes.Add($"JWKS ({authIssuer}/.well-known/jwks.json)");
    if (legacySecret is not null) modes.Add("legacy HS256 JwtSecret");
    Console.WriteLine($"Auth: validating JWTs via {string.Join(" + ", modes)}");
}

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
        policy.WithOrigins(cors.Origins.Length > 0 ? cors.Origins : ["http://localhost:3000"])
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseExceptionHandler();
app.UseCors("Ledgerly");
app.UseAuthentication();
app.UseAuthorization();
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
