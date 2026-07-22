namespace CoopCore.Api.Security;

public static class ApiRoles
{
    public const string Admin = "ADMIN_APP";
    public const string Cajero = "CAJERO_APP";
    public const string OficialCredito = "OFICIAL_CREDITO_APP";
    public const string Auditor = "AUDITOR_APP";

    public const string Todos = Admin + "," + Cajero + "," + OficialCredito + "," + Auditor;
    public const string Caja = Admin + "," + Cajero;
    public const string Credito = Admin + "," + OficialCredito;
    public const string Auditoria = Admin + "," + Auditor;
}
