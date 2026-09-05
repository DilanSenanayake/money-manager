using System.Text;
using Ledgerly.Api.Infrastructure;
using Ledgerly.Api.Infrastructure.Gemini;
using Ledgerly.Api.Infrastructure.Supabase;
using Ledgerly.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<SupabaseOptions>(
    builder.Configuration.GetSection(SupabaseOptions.SectionName));
builder.Services.Configure<GeminiOptions>(
    builder.Configuration.GetSection(GeminiOptions.SectionName));
builder.Services.Configure<LedgerlyCorsOptions>(
    builder.Configuration.GetSection(LedgerlyCorsOptions.SectionName));

var supabase = builder.Configuration.GetSection(SupabaseOptions.SectionName).Get<SupabaseOptions>()
               ?? new SupabaseOptions();
var cors = builder.Configuration.GetSection(LedgerlyCorsOptions.SectionName).Get<LedgerlyCorsOptions>()
           ?? new LedgerlyCorsOptions();

builder.Services.AddHttpContextAccessor();
builder.Services.AddHttpClient("supabase");
builder.Services.AddHttpClient("gemini");

builder.Services.AddScoped<ICurrentUser, CurrentUser>();
builder.Services.AddScoped<ISupabaseRestClient, SupabaseRestClient>();
builder.Services.AddSingleton<IGeminiService, GeminiService>();

builder.Services.AddScoped<IAccountsService, AccountsService>();
builder.Services.AddScoped<ICategoriesService, CategoriesService>();
builder.Services.AddScoped<ITransactionsService, TransactionsService>();
builder.Services.AddScoped<IDashboardService, DashboardService>();
builder.Services.AddScoped<ISettingsService, SettingsService>();
builder.Services.AddScoped<IAiService, AiService>();

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

// Asymmetric signing keys (ES256/RS256): validate via JWKS from Supabase Auth.
// Legacy: optional long HS256 shared secret (not a signing-key UUID/kid).
var useJwks = !string.IsNullOrWhiteSpace(supabaseUrl);
var legacySecret = GetLegacyJwtSecret(supabase.JwtSecret);

if (!useJwks && legacySecret is null)
{
    Console.WriteLine(
        "WARNING: Supabase:Url is empty and no legacy JwtSecret is set. Auth will reject tokens.");
}
else if (useJwks)
{
    Console.WriteLine($"Auth: validating JWTs via JWKS ({authIssuer}/.well-known/jwks.json)");
}
else
{
    Console.WriteLine("Auth: validating JWTs with legacy HS256 JwtSecret");
}

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
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
            ClockSkew = TimeSpan.FromMinutes(2),
            NameClaimType = "sub",
        };

        if (!useJwks)
        {
            options.TokenValidationParameters.IssuerSigningKey =
                new SymmetricSecurityKey(
                    Encoding.UTF8.GetBytes(
                        legacySecret ?? "dev-placeholder-secret-at-least-32-chars!!"));
        }
    });

builder.Services.AddAuthorization();

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
