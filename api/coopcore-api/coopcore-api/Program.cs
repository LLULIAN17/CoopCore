using CoopCore.Api.Db;
using CoopCore.Api.Interfaces;
using CoopCore.Api.Services;

var builder = WebApplication.CreateBuilder(args);

var configuredPort = builder.Configuration.GetValue<int?>("ApiSettings:Port");
var hasExplicitUrls =
    !string.IsNullOrWhiteSpace(builder.Configuration["urls"]) ||
    !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("ASPNETCORE_URLS"));

if (configuredPort.HasValue && !hasExplicitUrls)
{
    builder.WebHost.UseUrls($"http://localhost:{configuredPort.Value}");
}

builder.Services.AddControllers();
builder.Services.AddAuthorization();
builder.Services.AddEndpointsApiExplorer();

builder.Services.AddSingleton<SqlConnectionFactory>();
builder.Services.AddScoped<ISqlExecutor, SqlExecutor>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<ISocioService, SocioService>();
builder.Services.AddScoped<ICuentaService, CuentaService>();
builder.Services.AddScoped<IPrestamoService, PrestamoService>();

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

app.MapGet("/api/health", () => Results.Ok(new
{
    ok = true,
    servicio = "CoopCore API",
    version = "net10.0",
    ts = DateTimeOffset.UtcNow
}));

app.UseAuthorization();
app.MapControllers();

app.Run();
