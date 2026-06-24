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
builder.Services.AddOpenApi();
builder.Services.AddEndpointsApiExplorer();

builder.Services.AddSingleton<CoopCore.Api.Db.SqlConnectionFactory>();
builder.Services.AddScoped<CoopCore.Api.Interfaces.ISqlExecutor, CoopCore.Api.Db.SqlExecutor>();
builder.Services.AddScoped<CoopCore.Api.Interfaces.IAuthService, CoopCore.Api.Services.AuthService>();
builder.Services.AddScoped<CoopCore.Api.Interfaces.ISocioService, CoopCore.Api.Services.SocioService>();
builder.Services.AddScoped<CoopCore.Api.Interfaces.ICuentaService, CoopCore.Api.Services.CuentaService>();
builder.Services.AddScoped<CoopCore.Api.Interfaces.IPrestamoService, CoopCore.Api.Services.PrestamoService>();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

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
    servicio = "CoopCore.Api",
    version = "net10.0",
    ts = DateTimeOffset.UtcNow
}));

app.UseAuthorization();

app.MapControllers();

app.Run();
