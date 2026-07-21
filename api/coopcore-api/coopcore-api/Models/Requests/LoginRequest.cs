namespace CoopCore.Api.Models.Requests;

public sealed record LoginRequest(
    string? Usuario,
    string? Password);
