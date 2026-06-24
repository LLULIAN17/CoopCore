namespace CoopCore.Api.Models.Responses;

public sealed record ApiResponse<T>(
    bool Ok,
    string Mensaje,
    T? Datos = default);

public sealed record ServiceResult<T>(
    int StatusCode,
    ApiResponse<T> Response)
{
    public static ServiceResult<T> Success(
        T datos,
        string mensaje = "Operacion realizada correctamente.",
        int statusCode = StatusCodes.Status200OK)
    {
        return new ServiceResult<T>(
            statusCode,
            new ApiResponse<T>(true, mensaje, datos));
    }

    public static ServiceResult<T> Failure(
        int statusCode,
        string mensaje,
        T? datos = default)
    {
        return new ServiceResult<T>(
            statusCode,
            new ApiResponse<T>(false, mensaje, datos));
    }
}
