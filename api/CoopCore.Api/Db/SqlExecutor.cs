using System.Data;
using CoopCore.Api.Interfaces;
using Microsoft.Data.SqlClient;

namespace CoopCore.Api.Db;

public sealed class SqlExecutor : ISqlExecutor
{
    private readonly SqlConnectionFactory _connectionFactory;

    public SqlExecutor(SqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<StoredProcedureResult> ExecuteAsync(
        string storedProcedure,
        IEnumerable<SqlParameter> parameters,
        CancellationToken cancellationToken = default)
    {
        await using var connection = _connectionFactory.CreateConnection();
        await using var command = new SqlCommand(storedProcedure, connection)
        {
            CommandType = CommandType.StoredProcedure
        };

        foreach (var parameter in parameters)
        {
            command.Parameters.Add(parameter);
        }

        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var resultSets = new List<IReadOnlyList<IReadOnlyDictionary<string, object?>>>();

        do
        {
            var rows = new List<IReadOnlyDictionary<string, object?>>();

            while (await reader.ReadAsync(cancellationToken))
            {
                var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);

                for (var index = 0; index < reader.FieldCount; index++)
                {
                    var value = await reader.IsDBNullAsync(index, cancellationToken)
                        ? null
                        : reader.GetValue(index);

                    row[reader.GetName(index)] = value;
                }

                rows.Add(row);
            }

            resultSets.Add(rows);
        }
        while (await reader.NextResultAsync(cancellationToken));

        return new StoredProcedureResult(resultSets);
    }
}
