using CoopCore.Api.Db;
using Microsoft.Data.SqlClient;

namespace CoopCore.Api.Interfaces;

public interface ISqlExecutor
{
    Task<StoredProcedureResult> ExecuteAsync(
        string storedProcedure,
        IEnumerable<SqlParameter> parameters,
        CancellationToken cancellationToken = default);
}
