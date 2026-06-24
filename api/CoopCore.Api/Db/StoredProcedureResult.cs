namespace CoopCore.Api.Db;

public sealed class StoredProcedureResult
{
    public StoredProcedureResult(
        IReadOnlyList<IReadOnlyList<IReadOnlyDictionary<string, object?>>> resultSets)
    {
        ResultSets = resultSets;
    }

    public IReadOnlyList<IReadOnlyList<IReadOnlyDictionary<string, object?>>> ResultSets { get; }

    public IReadOnlyList<IReadOnlyDictionary<string, object?>> FirstResultSet =>
        ResultSets.Count > 0
            ? ResultSets[0]
            : Array.Empty<IReadOnlyDictionary<string, object?>>();
}
