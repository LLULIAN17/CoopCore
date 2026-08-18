param(
    [string]$ServerInstance = '.\SQLEXPRESS',
    [string]$Database = 'CoopCoreDB',
    [string]$OutputDirectory = 'docs\evidencias\planes'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Data

function Invoke-NonQuery {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [System.Data.SqlClient.SqlTransaction]$Transaction,
        [string]$CommandText
    )

    $command = $Connection.CreateCommand()
    $command.Transaction = $Transaction
    $command.CommandTimeout = 120
    $command.CommandText = $CommandText
    [void]$command.ExecuteNonQuery()
}

function Get-EstimatedPlanXml {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [System.Data.SqlClient.SqlTransaction]$Transaction,
        [string]$Query
    )

    Invoke-NonQuery $Connection $Transaction 'SET SHOWPLAN_XML ON;'
    try {
        $command = $Connection.CreateCommand()
        $command.Transaction = $Transaction
        $command.CommandTimeout = 120
        $command.CommandText = $Query
        return [string]$command.ExecuteScalar()
    }
    finally {
        Invoke-NonQuery $Connection $Transaction 'SET SHOWPLAN_XML OFF;'
    }
}

function Get-PlanSummary {
    param([string]$PlanXml)

    [xml]$document = $PlanXml
    $namespace = [System.Xml.XmlNamespaceManager]::new($document.NameTable)
    $namespace.AddNamespace('sp', 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')

    $statement = $document.SelectSingleNode('//sp:StmtSimple', $namespace)
    $operators = @(
        $document.SelectNodes('//sp:RelOp', $namespace) |
            ForEach-Object { $_.PhysicalOp } |
            Where-Object { $_ } |
            Select-Object -Unique
    )
    $indexes = @(
        $document.SelectNodes('//sp:Object[@Index]', $namespace) |
            ForEach-Object { $_.Index.Trim('[', ']') } |
            Where-Object { $_ } |
            Select-Object -Unique
    )

    [pscustomobject]@{
        EstimatedCost = [decimal]::Parse(
            $statement.StatementSubTreeCost,
            [Globalization.CultureInfo]::InvariantCulture
        )
        Operators = $operators -join ', '
        Indexes = $indexes -join ', '
    }
}

$cases = @(
    [pscustomobject]@{
        Key = 'movimientos'
        IndexName = 'IX_Movimiento_Cuenta_Fecha'
        DropSql = 'DROP INDEX IX_Movimiento_Cuenta_Fecha ON coop.Movimiento;'
        CreateSql = @'
CREATE INDEX IX_Movimiento_Cuenta_Fecha
    ON coop.Movimiento (CuentaID, FechaMovimiento DESC, MovimientoID DESC)
    INCLUDE (TipoMovimiento, Monto, Referencia, Observacion, EjecutadoPorEmpleadoID);
'@
        Query = @'
SELECT TOP (50)
    MovimientoID, TipoMovimiento, Monto, Referencia, Observacion,
    FechaMovimiento, EjecutadoPorEmpleadoID
FROM coop.Movimiento
WHERE CuentaID = 1
ORDER BY FechaMovimiento DESC, MovimientoID DESC;
'@
    }
    [pscustomobject]@{
        Key = 'cuentas_por_socio'
        IndexName = 'IX_Cuenta_Socio_Saldo'
        DropSql = 'DROP INDEX IX_Cuenta_Socio_Saldo ON coop.Cuenta;'
        CreateSql = @'
CREATE INDEX IX_Cuenta_Socio_Saldo
    ON coop.Cuenta (SocioID)
    INCLUDE (Saldo);
'@
        Query = @'
SELECT SocioID, COUNT(*) AS CantidadCuentas, SUM(Saldo) AS SaldoTotal
FROM coop.Cuenta
WHERE SocioID = 1
GROUP BY SocioID;
'@
    }
    [pscustomobject]@{
        Key = 'prestamos_por_socio'
        IndexName = 'IX_Prestamo_Socio_Saldo'
        DropSql = 'DROP INDEX IX_Prestamo_Socio_Saldo ON coop.Prestamo;'
        CreateSql = @'
CREATE INDEX IX_Prestamo_Socio_Saldo
    ON coop.Prestamo (SocioID)
    INCLUDE (SaldoPendiente);
'@
        Query = @'
SELECT SocioID, COUNT(*) AS CantidadPrestamos, SUM(SaldoPendiente) AS SaldoTotal
FROM coop.Prestamo
WHERE SocioID = 1
GROUP BY SocioID;
'@
    }
    [pscustomobject]@{
        Key = 'cuotas_por_prestamo'
        IndexName = 'IX_Cuota_Prestamo_Numero_Covering'
        DropSql = 'DROP INDEX IX_Cuota_Prestamo_Numero_Covering ON coop.Cuota;'
        CreateSql = @'
CREATE INDEX IX_Cuota_Prestamo_Numero_Covering
    ON coop.Cuota (PrestamoID, NumeroCuota)
    INCLUDE (FechaVencimiento, MontoCuota, MontoPagado, FechaPago, EstadoCuota);
'@
        Query = @'
SELECT NumeroCuota, FechaVencimiento, MontoCuota, MontoPagado, FechaPago, EstadoCuota
FROM coop.Cuota
WHERE PrestamoID = 1
ORDER BY NumeroCuota;
'@
    }
    [pscustomobject]@{
        Key = 'auditoria_por_accion'
        IndexName = 'IX_Auditoria_Accion_Fecha'
        DropSql = 'DROP INDEX IX_Auditoria_Accion_Fecha ON coop.Auditoria;'
        CreateSql = @'
CREATE INDEX IX_Auditoria_Accion_Fecha
    ON coop.Auditoria (Accion, FechaEvento DESC, AuditoriaID DESC)
    INCLUDE (Entidad, EmpleadoID, EntidadID, UsuarioSQL, UsuarioBD);
'@
        Query = @'
SELECT TOP (100)
    AuditoriaID, Entidad, EntidadID, Accion, FechaEvento,
    UsuarioSQL, UsuarioBD, EmpleadoID
FROM coop.Auditoria
WHERE Accion = N'LOGIN'
ORDER BY FechaEvento DESC, AuditoriaID DESC;
'@
    }
)

$resolvedOutput = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\$OutputDirectory"))
[IO.Directory]::CreateDirectory($resolvedOutput) | Out-Null

$connectionString =
    "Server=$ServerInstance;Database=$Database;Integrated Security=True;" +
    'Encrypt=True;TrustServerCertificate=True;Application Name=CoopCore Plan Evidence;'
$connection = [System.Data.SqlClient.SqlConnection]::new($connectionString)
$results = [Collections.Generic.List[object]]::new()

try {
    $connection.Open()

    foreach ($case in $cases) {
        $transaction = $connection.BeginTransaction()
        try {
            Invoke-NonQuery $connection $transaction $case.DropSql
            $beforeXml = Get-EstimatedPlanXml $connection $transaction $case.Query
            $beforeSummary = Get-PlanSummary $beforeXml

            Invoke-NonQuery $connection $transaction $case.CreateSql
            $afterXml = Get-EstimatedPlanXml $connection $transaction $case.Query
            $afterSummary = Get-PlanSummary $afterXml

            $beforePath = Join-Path $resolvedOutput "$($case.Key)_antes.sqlplan"
            $afterPath = Join-Path $resolvedOutput "$($case.Key)_despues.sqlplan"
            [IO.File]::WriteAllText($beforePath, $beforeXml, [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText($afterPath, $afterXml, [Text.UTF8Encoding]::new($false))

            $delta = $afterSummary.EstimatedCost - $beforeSummary.EstimatedCost
            $deltaPercent = if ($beforeSummary.EstimatedCost -eq 0) {
                0
            }
            else {
                [math]::Round(($delta / $beforeSummary.EstimatedCost) * 100, 2)
            }

            $results.Add([pscustomobject]@{
                Caso = $case.Key
                Indice = $case.IndexName
                CostoAntes = $beforeSummary.EstimatedCost
                CostoDespues = $afterSummary.EstimatedCost
                DeltaCosto = $delta
                DeltaPorcentaje = $deltaPercent
                OperadoresAntes = $beforeSummary.Operators
                OperadoresDespues = $afterSummary.Operators
                IndicesAntes = $beforeSummary.Indexes
                IndicesDespues = $afterSummary.Indexes
            })
        }
        finally {
            $transaction.Rollback()
        }
    }
}
finally {
    $connection.Close()
}

$csvPath = Join-Path $resolvedOutput 'resumen_costos_estimados.csv'
$results | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding utf8

$markdown = [Collections.Generic.List[string]]::new()
$markdown.Add('# Comparacion reproducible de costos estimados')
$markdown.Add('')
$markdown.Add('Fuente: planes XML estimados generados por SQL Server con `SET SHOWPLAN_XML ON`.')
$markdown.Add('Cada indice se elimina y recrea dentro de una transaccion que se revierte al finalizar.')
$markdown.Add('')
$markdown.Add('| Caso | Indice | Costo antes | Costo despues | Delta | Delta % | Indice elegido despues |')
$markdown.Add('|---|---|---:|---:|---:|---:|---|')
foreach ($result in $results) {
    $markdown.Add(
        "| $($result.Caso) | ``$($result.Indice)`` | $($result.CostoAntes) | " +
        "$($result.CostoDespues) | $($result.DeltaCosto) | $($result.DeltaPorcentaje)% | " +
        "$($result.IndicesDespues) |"
    )
}
$markdown.Add('')
$markdown.Add('Los archivos `.sqlplan` son evidencia original y se pueden abrir directamente en SSMS.')
$markdownPath = Join-Path $resolvedOutput 'resumen_costos_estimados.md'
[IO.File]::WriteAllLines($markdownPath, $markdown, [Text.UTF8Encoding]::new($false))

$results | Format-Table Caso, Indice, CostoAntes, CostoDespues, DeltaPorcentaje -AutoSize
Write-Host "Evidencia guardada en $resolvedOutput"
