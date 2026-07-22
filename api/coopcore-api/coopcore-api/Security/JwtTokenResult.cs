namespace CoopCore.Api.Security;

public sealed record JwtTokenResult(
    string Token,
    DateTimeOffset ExpiraEn);
