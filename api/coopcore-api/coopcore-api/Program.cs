using System.Security.Claims;
using CoopCore.Api.Db;
using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Responses;
using CoopCore.Api.Options;
using CoopCore.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.OpenApi;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);
var jwtSettings = builder.Configuration
    .GetSection(JwtSettings.SectionName)
    .Get<JwtSettings>() ?? new JwtSettings();

var configuredPort = builder.Configuration.GetValue<int?>("ApiSettings:Port");
var hasExplicitUrls =
    !string.IsNullOrWhiteSpace(builder.Configuration["urls"]) ||
    !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("ASPNETCORE_URLS"));

if (configuredPort.HasValue && !hasExplicitUrls)
{
    builder.WebHost.UseUrls($"http://localhost:{configuredPort.Value}");
}

builder.Services.AddControllers();
builder.Services.Configure<ApiBehaviorOptions>(options =>
{
    options.InvalidModelStateResponseFactory = context =>
    {
        var errors = context.ModelState
            .Where(item => item.Value?.Errors.Count > 0)
            .ToDictionary(
                item => item.Key,
                item => item.Value!.Errors
                    .Select(error => string.IsNullOrWhiteSpace(error.ErrorMessage)
                        ? "Valor invalido."
                        : error.ErrorMessage)
                    .ToArray());

        return new BadRequestObjectResult(
            new ApiResponse<IReadOnlyDictionary<string, string[]>>(
                false,
                "La solicitud contiene datos invalidos.",
                errors));
    };
});
builder.Services.Configure<JwtSettings>(
    builder.Configuration.GetSection(JwtSettings.SectionName));
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwtSettings.Issuer,
            ValidateAudience = true,
            ValidAudience = jwtSettings.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(jwtSettings.GetSigningKeyBytes()),
            ValidateLifetime = true,
            NameClaimType = ClaimTypes.Name,
            RoleClaimType = ClaimTypes.Role,
            ClockSkew = TimeSpan.FromMinutes(1)
        };

        options.Events = new JwtBearerEvents
        {
            OnChallenge = async context =>
            {
                context.HandleResponse();
                context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                context.Response.ContentType = "application/json";

                await context.Response.WriteAsJsonAsync(
                    new ApiResponse<object>(
                        false,
                        "Token JWT requerido o invalido."));
            },
            OnForbidden = async context =>
            {
                context.Response.StatusCode = StatusCodes.Status403Forbidden;
                context.Response.ContentType = "application/json";

                await context.Response.WriteAsJsonAsync(
                    new ApiResponse<object>(
                        false,
                        "El usuario autenticado no tiene permisos para esta operacion."));
            }
        };
    });
builder.Services.AddAuthorization();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "CoopCore API",
        Version = "v1",
        Description = "API oficial de CoopCore para socios, cuentas, prestamos, transacciones y auditoria."
    });

    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "JWT Bearer. Escriba: Bearer {token}",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT"
    });

    options.DocumentFilter<CoopCore.Api.Security.AuthorizeDocumentFilter>();
});

builder.Services.AddSingleton<SqlConnectionFactory>();
builder.Services.AddScoped<ISqlExecutor, SqlExecutor>();
builder.Services.AddScoped<IJwtTokenService, JwtTokenService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<ISocioService, SocioService>();
builder.Services.AddScoped<ICuentaService, CuentaService>();
builder.Services.AddScoped<IPrestamoService, PrestamoService>();
builder.Services.AddScoped<IAuditoriaService, AuditoriaService>();

var app = builder.Build();

app.UseExceptionHandler(errorApp =>
{
    errorApp.Run(async context =>
    {
        context.Response.StatusCode = StatusCodes.Status500InternalServerError;
        context.Response.ContentType = "application/json";

        await context.Response.WriteAsJsonAsync(new
        {
            ok = false,
            mensaje = "Error interno en la API."
        });
    });
});

app.UseSwagger();
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/swagger/v1/swagger.json", "CoopCore API v1");
    options.RoutePrefix = "swagger";
});

app.MapGet("/api/health", () => Results.Ok(new
{
    ok = true,
    servicio = "CoopCore API",
    version = "net10.0",
    ts = DateTimeOffset.UtcNow
}));

app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
