using CoopCore.Api.Models.Requests;
using CoopCore.Api.Models.Responses;

namespace CoopCore.Api.Interfaces;

public interface IAuthService
{
    Task<ServiceResult<LoginResponse>> LoginAsync(
        LoginRequest request,
        CancellationToken cancellationToken = default);
}
