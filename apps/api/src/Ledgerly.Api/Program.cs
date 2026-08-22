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

if (string.IsNullOrWhiteSpace(supabase.JwtSecret))
{
    Console.WriteLine("WARNING: Supabase:JwtSecret is not configured. Auth will reject tokens.");
}

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = string.IsNullOrWhiteSpace(supabase.Url)
                ? "supabase"
                : $"{supabase.Url.TrimEnd('/')}/auth/v1",
            ValidateAudience = true,
            ValidAudience = "authenticated",
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(
                    string.IsNullOrWhiteSpace(supabase.JwtSecret)
                        ? "dev-placeholder-secret-at-least-32-chars!!"
                        : supabase.JwtSecret)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(2),
            NameClaimType = "sub",
        };
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
