using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Requests;
using CoopCore.Api.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CoopCore.Api.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<IActionResult> Login(
        [FromBody] LoginRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _authService.LoginAsync(request, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }

    [HttpPost("cambiar-password")]
    [Authorize(Roles = ApiRoles.Todos)]
    public async Task<IActionResult> CambiarPassword(
        [FromBody] CambiarPasswordRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _authService.CambiarPasswordAsync(request, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }
}
