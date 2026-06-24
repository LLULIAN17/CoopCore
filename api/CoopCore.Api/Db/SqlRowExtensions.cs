namespace CoopCore.Api.Db;

public static class SqlRowExtensions
{
    public static string? GetString(
        this IReadOnlyDictionary<string, object?> row,
        string name)
    {
        var value = GetValue(row, name);
        return value?.ToString();
    }

    public static int GetInt32(
        this IReadOnlyDictionary<string, object?> row,
        string name)
    {
        return Convert.ToInt32(GetValue(row, name));
    }

    public static int? GetNullableInt32(
        this IReadOnlyDictionary<string, object?> row,
        string name)
    {
        var value = GetValue(row, name);
        return value is null ? null : Convert.ToInt32(value);
    }

    public static long GetInt64(
        this IReadOnlyDictionary<string, object?> row,
        string name)
    {
        return Convert.ToInt64(GetValue(row, name));
    }

    public static decimal GetDecimal(
        this IReadOnlyDictionary<string, object?> row,
        string name)
    {
        return Convert.ToDecimal(GetValue(row, name));
    }

    public static DateTime? GetNullableDateTime(
        this IReadOnlyDictionary<string, object?> row,
        string name)
    {
        var value = GetValue(row, name);
        return value is null ? null : Convert.ToDateTime(value);
    }

    public static DateTime GetDateTime(
        this IReadOnlyDictionary<string, object?> row,
        string name)
    {
        return Convert.ToDateTime(GetValue(row, name));
    }

    private static object? GetValue(
        IReadOnlyDictionary<string, object?> row,
        string name)
    {
        return row.TryGetValue(name, out var value)
            ? value
            : throw new KeyNotFoundException($"El resultado SQL no contiene la columna {name}.");
    }
}
