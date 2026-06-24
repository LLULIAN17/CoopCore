using Microsoft.Data.SqlClient;

namespace CoopCore.Api.Db;

public sealed class SqlConnectionFactory
{
    private readonly IConfiguration _configuration;

    public SqlConnectionFactory(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public SqlConnection CreateConnection()
    {
        var connectionString = _configuration.GetConnectionString("CoopCoreDb");

        if (string.IsNullOrWhiteSpace(connectionString) ||
            connectionString.Contains("CAMBIAR_EN_LOCAL", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "Configure ConnectionStrings:CoopCoreDb antes de ejecutar endpoints de datos.");
        }

        return new SqlConnection(connectionString);
    }
}
