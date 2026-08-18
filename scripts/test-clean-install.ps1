param(
    [string]$ServerInstance = '.\SQLEXPRESS',
    [string]$TemporaryDatabase = 'CoopCoreCleanTestDB',
    [string]$EvidencePath = 'docs\evidencias\instalacion_limpia_20260817.txt'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($TemporaryDatabase -notmatch '^CoopCore[A-Za-z0-9_]*TestDB$') {
    throw 'El nombre temporal debe iniciar con CoopCore y finalizar en TestDB.'
}
if ($TemporaryDatabase -eq 'CoopCoreDB') {
    throw 'La prueba nunca puede usar CoopCoreDB como base temporal.'
}

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidence = [IO.Path]::GetFullPath((Join-Path $repo $EvidencePath))
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("coopcore-clean-" + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($evidence)) | Out-Null

$scripts = @(
    '00_create_database.sql',
    '01_schema_tables.sql',
    '02_seed_data.sql',
    '03_functions.sql',
    '03_views.sql',
    '04_stored_procedures.sql',
    '05_transactions.sql',
    '06_security.sql',
    '07_security_tests.sql',
    '08_concurrency_tests.sql',
    '09_execution_plan_baseline.sql',
    '09_indexes_optimization.sql',
    '10_revision3_tests.sql',
    '11_busqueda_clientes_morosos.sql',
    '12_busqueda_clientes_morosos_tests.sql',
    '13_dashboard_cartera.sql',
    '14_productos_financieros.sql',
    '15_alertas_cobranza.sql',
    '16_ampliacion_50_tests.sql',
    '17_entrega_final_tests.sql'
)

function Invoke-SqlcmdCaptured {
    param([string[]]$Arguments)

    $stdoutPath = Join-Path $temporaryRoot ("stdout-" + [guid]::NewGuid().ToString('N') + '.txt')
    $stderrPath = Join-Path $temporaryRoot ("stderr-" + [guid]::NewGuid().ToString('N') + '.txt')
    $quotedArguments = foreach ($argument in $Arguments) {
        if ($argument -match '[\s"]') {
            '"' + $argument.Replace('"', '\"') + '"'
        }
        else {
            $argument
        }
    }
    $process = Start-Process `
        -FilePath 'sqlcmd.exe' `
        -ArgumentList ($quotedArguments -join ' ') `
        -Wait `
        -PassThru `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath
    $stdout = [IO.File]::ReadAllText($stdoutPath)
    $stderr = [IO.File]::ReadAllText($stderrPath)

    [pscustomobject]@{
        ExitCode = $process.ExitCode
        StdOut = $stdout
        StdErr = $stderr
    }
}

$log = [Collections.Generic.List[string]]::new()
$log.Add('COOPCORE - EVIDENCIA DE INSTALACION LIMPIA')
$log.Add('Fecha: 2026-08-17')
$log.Add("Servidor: $ServerInstance")
$log.Add("Base temporal: $TemporaryDatabase")
$log.Add("Scripts esperados: $($scripts.Count)")
$log.Add('La base temporal se elimina al terminar; CoopCoreDB no se modifica.')
$log.Add('')

try {
    $escapedDatabase = $TemporaryDatabase.Replace(']', ']]')
    $cleanupSql = @"
IF DB_ID(N'$TemporaryDatabase') IS NOT NULL
BEGIN
    ALTER DATABASE [$escapedDatabase] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$escapedDatabase];
END;
"@
    $cleanup = Invoke-SqlcmdCaptured @('-S', $ServerInstance, '-E', '-C', '-b', '-Q', $cleanupSql)
    if ($cleanup.ExitCode -ne 0) {
        throw "No se pudo preparar la base temporal: $($cleanup.StdErr)"
    }

    foreach ($scriptName in $scripts) {
        $source = Join-Path $repo "sql\$scriptName"
        if (-not [IO.File]::Exists($source)) {
            throw "No existe el script requerido: $scriptName"
        }

        $content = [IO.File]::ReadAllText($source)
        $content = $content.Replace('CoopCoreDB', $TemporaryDatabase)
        $temporaryScript = Join-Path $temporaryRoot $scriptName
        [IO.File]::WriteAllText($temporaryScript, $content, [Text.UTF8Encoding]::new($true))

        $started = [DateTime]::UtcNow
        $result = Invoke-SqlcmdCaptured @(
            '-S', $ServerInstance,
            '-E',
            '-C',
            '-b',
            '-r1',
            '-f', '65001',
            '-i', $temporaryScript
        )
        $elapsed = [math]::Round(([DateTime]::UtcNow - $started).TotalSeconds, 2)

        $log.Add("===== $scriptName =====")
        $log.Add("ExitCode: $($result.ExitCode)")
        $log.Add("DuracionSegundos: $elapsed")
        if ($result.StdOut.Trim()) {
            $log.Add($result.StdOut.TrimEnd())
        }
        if ($result.StdErr.Trim()) {
            $log.Add($(if ($result.ExitCode -eq 0) { '[MENSAJES SQLCMD]' } else { '[STDERR]' }))
            $log.Add($result.StdErr.TrimEnd())
        }
        $log.Add('')

        if ($result.ExitCode -ne 0) {
            throw "Fallo $scriptName con codigo $($result.ExitCode)."
        }
    }

    $verificationSql = @"
SET NOCOUNT ON;
USE [$escapedDatabase];
SELECT
    (SELECT COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID(N'coop')) AS Tablas,
    (SELECT COUNT(*) FROM sys.procedures WHERE schema_id = SCHEMA_ID(N'coop')) AS Procedimientos,
    (SELECT COUNT(*) FROM sys.objects WHERE schema_id = SCHEMA_ID(N'coop') AND type IN ('FN','IF','TF')) AS Funciones,
    (SELECT COUNT(*) FROM sys.views WHERE schema_id = SCHEMA_ID(N'coop')) AS Vistas,
    (SELECT COUNT(*) FROM sys.triggers WHERE parent_class_desc = 'OBJECT_OR_COLUMN') AS Triggers;
"@
    $verification = Invoke-SqlcmdCaptured @(
        '-S', $ServerInstance, '-E', '-C', '-b', '-h-1', '-W', '-s', '|', '-Q', $verificationSql
    )
    if ($verification.ExitCode -ne 0) {
        throw "Fallo la verificacion final: $($verification.StdErr)"
    }
    $counts = @(
        $verification.StdOut -split "`r?`n" |
            Where-Object { $_ -match '^\d+\|\d+\|\d+\|\d+\|\d+$' }
    ) | Select-Object -Last 1
    if (-not $counts) {
        throw "No se encontro la fila de conteos en: $($verification.StdOut)"
    }
    $log.Add('===== VERIFICACION FINAL =====')
    $log.Add('Tablas|Procedimientos|Funciones|Vistas|Triggers')
    $log.Add($counts)
    $log.Add('')

    if ($counts -notmatch '^10\|24\|2\|4\|1$') {
        throw "Conteos inesperados: $counts"
    }

    $log.Add('RESULTADO FINAL: APROBADO')
    $log.Add('Los 20 scripts terminaron con ExitCode 0 y los conteos son correctos.')
}
catch {
    $log.Add('RESULTADO FINAL: FALLIDO')
    $log.Add($_.Exception.Message)
    throw
}
finally {
    $dropSql = @"
IF DB_ID(N'$TemporaryDatabase') IS NOT NULL
BEGIN
    ALTER DATABASE [$escapedDatabase] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$escapedDatabase];
END;
"@
    $drop = Invoke-SqlcmdCaptured @('-S', $ServerInstance, '-E', '-C', '-b', '-Q', $dropSql)
    $log.Add('')
    $log.Add("Limpieza base temporal ExitCode: $($drop.ExitCode)")
    $cleanLog = @($log | ForEach-Object { $_.TrimEnd() })
    [IO.File]::WriteAllLines($evidence, $cleanLog, [Text.UTF8Encoding]::new($false))

    if ([IO.Directory]::Exists($temporaryRoot)) {
        [IO.Directory]::Delete($temporaryRoot, $true)
    }
}

Write-Host "Instalacion limpia aprobada. Evidencia: $evidence"
