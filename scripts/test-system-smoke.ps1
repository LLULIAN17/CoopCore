param(
    [string]$ServerInstance = '.\SQLEXPRESS',
    [string]$BaseUrl = 'http://127.0.0.1:5068',
    [string]$EvidencePath = 'docs\evidencias\sistema_completo_20260817.txt',
    [string]$DotnetPath = 'C:\Program Files\dotnet\dotnet.exe'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Data

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$apiDll = Join-Path $repo 'api\coopcore-api\coopcore-api\bin\Release\net10.0\coopcore-api.dll'
$evidence = [IO.Path]::GetFullPath((Join-Path $repo $EvidencePath))
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("coopcore-api-smoke-" + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($evidence)) | Out-Null

if (-not [IO.File]::Exists($DotnetPath)) {
    throw "No se encontro dotnet en $DotnetPath"
}
if (-not [IO.File]::Exists($apiDll)) {
    throw 'No existe el build Release de la API. Ejecute dotnet build -c Release.'
}

$log = [Collections.Generic.List[string]]::new()
$log.Add('COOPCORE - EVIDENCIA DE SISTEMA COMPLETO')
$log.Add('Fecha: 2026-08-17')
$log.Add("API: $BaseUrl")
$log.Add("SQL Server: $ServerInstance / CoopCoreDB")
$log.Add('Conexion usada: autenticacion integrada de Windows, cifrada y con certificado local confiable.')
$log.Add('Los tokens JWT no se escriben en esta evidencia.')
$log.Add('')

function Get-HttpFailureBody {
    param($Exception)
    if (-not $Exception.Response) {
        return ''
    }
    try {
        $stream = $Exception.Response.GetResponseStream()
        $reader = [IO.StreamReader]::new($stream)
        return $reader.ReadToEnd()
    }
    catch {
        return ''
    }
}

function Invoke-ApiCheck {
    param(
        [string]$Name,
        [string]$Method,
        [string]$Path,
        [int]$ExpectedStatus,
        [string]$Token = '',
        $Body = $null
    )

    $headers = @{}
    if ($Token) {
        $headers.Authorization = "Bearer $Token"
    }
    $parameters = @{
        Uri = "$BaseUrl$Path"
        Method = $Method
        Headers = $headers
        UseBasicParsing = $true
        TimeoutSec = 20
    }
    if ($null -ne $Body) {
        $parameters.ContentType = 'application/json'
        $parameters.Body = $Body | ConvertTo-Json -Depth 8 -Compress
    }

    $status = 0
    $content = ''
    try {
        $response = Invoke-WebRequest @parameters
        $status = [int]$response.StatusCode
        $content = $response.Content
    }
    catch {
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
            $content = Get-HttpFailureBody $_.Exception
        }
        else {
            throw
        }
    }

    $result = if ($status -eq $ExpectedStatus) { 'OK' } else { 'FALLO' }
    $log.Add("[$result] $Name | $Method $Path | esperado=$ExpectedStatus obtenido=$status")
    if ($status -ne $ExpectedStatus) {
        throw "$Name esperaba HTTP $ExpectedStatus y obtuvo $status. Body: $content"
    }

    if ($content) {
        return $content | ConvertFrom-Json
    }
    return $null
}

function Login {
    param([string]$Name, [string]$User, [string]$Password)
    $response = Invoke-ApiCheck $Name 'POST' '/api/auth/login' 200 '' @{
        usuario = $User
        password = $Password
    }
    if (-not $response.ok -or -not $response.datos.token) {
        throw "$Name no devolvio un JWT valido."
    }
    return [string]$response.datos.token
}

function Remove-SmokeGestion {
    param([long]$GestionCobranzaID)

    $connectionString =
        "Server=$ServerInstance;Database=CoopCoreDB;Integrated Security=True;" +
        'Encrypt=True;TrustServerCertificate=True;Application Name=CoopCore Smoke Cleanup;'
    $connection = [System.Data.SqlClient.SqlConnection]::new($connectionString)
    try {
        $connection.Open()
        $transaction = $connection.BeginTransaction()
        try {
            $command = $connection.CreateCommand()
            $command.Transaction = $transaction
            $command.CommandText = @'
DELETE FROM coop.Auditoria
WHERE Entidad = N'GESTION_COBRANZA'
  AND EntidadID = CONVERT(NVARCHAR(100), @GestionCobranzaID);
DELETE FROM coop.GestionCobranza
WHERE GestionCobranzaID = @GestionCobranzaID;
'@
            [void]$command.Parameters.Add('@GestionCobranzaID', [Data.SqlDbType]::BigInt)
            $command.Parameters['@GestionCobranzaID'].Value = $GestionCobranzaID
            [void]$command.ExecuteNonQuery()
            $transaction.Commit()
        }
        catch {
            $transaction.Rollback()
            throw
        }
    }
    finally {
        $connection.Close()
    }
}

$environmentNames = @(
    'ConnectionStrings__CoopCoreDb',
    'JwtSettings__SigningKey',
    'JwtSettings__Issuer',
    'JwtSettings__Audience',
    'JwtSettings__ExpirationMinutes',
    'ASPNETCORE_ENVIRONMENT'
)
$previousEnvironment = @{}
foreach ($name in $environmentNames) {
    $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

$stdoutPath = Join-Path $temporaryRoot 'api.stdout.txt'
$stderrPath = Join-Path $temporaryRoot 'api.stderr.txt'
$apiProcess = $null
$gestionId = $null

try {
    $env:ConnectionStrings__CoopCoreDb =
        "Server=$ServerInstance;Database=CoopCoreDB;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;"
    $env:JwtSettings__SigningKey = 'CoopCore-Smoke-Test-Signing-Key-2026-Only-Local'
    $env:JwtSettings__Issuer = 'CoopCore.Api'
    $env:JwtSettings__Audience = 'CoopCore.Clients'
    $env:JwtSettings__ExpirationMinutes = '60'
    $env:ASPNETCORE_ENVIRONMENT = 'Production'

    $apiProcess = Start-Process `
        -FilePath $DotnetPath `
        -ArgumentList ('"' + $apiDll + '" --urls ' + $BaseUrl) `
        -WorkingDirectory $repo `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -PassThru

    $ready = $false
    for ($attempt = 1; $attempt -le 30; $attempt++) {
        Start-Sleep -Milliseconds 500
        if ($apiProcess.HasExited) {
            throw "La API termino antes del healthcheck con codigo $($apiProcess.ExitCode)."
        }
        try {
            $health = Invoke-WebRequest -Uri "$BaseUrl/api/health" -UseBasicParsing -TimeoutSec 2
            if ([int]$health.StatusCode -eq 200) {
                $ready = $true
                break
            }
        }
        catch {
        }
    }
    if (-not $ready) {
        throw 'La API no respondio al healthcheck dentro de 15 segundos.'
    }

    [void](Invoke-ApiCheck 'Healthcheck' 'GET' '/api/health' 200)
    $tokenCajero = Login 'Login cajero' 'mlrojas' 'Lab_Cajero_001'
    $tokenOficial = Login 'Login oficial' 'cmena' 'Lab_Oficial_001'
    $tokenAuditor = Login 'Login auditor' 'asolis' 'Lab_Auditor_001'
    $tokenAdmin = Login 'Login admin' 'lporras' 'Lab_Admin_001'

    [void](Invoke-ApiCheck 'Consulta de socio' 'GET' '/api/socios/SO-1001' 200 $tokenCajero)
    [void](Invoke-ApiCheck 'Consulta de saldo' 'GET' '/api/cuentas/CTA-10001/saldo' 200 $tokenCajero)
    [void](Invoke-ApiCheck 'Consulta de movimientos' 'GET' '/api/cuentas/CTA-10001/movimientos' 200 $tokenCajero)
    [void](Invoke-ApiCheck 'Consulta de prestamo' 'GET' '/api/prestamos/PR-20001' 200 $tokenOficial)
    [void](Invoke-ApiCheck 'Busqueda de morosos' 'GET' '/api/clientes-morosos?fechaCorte=2026-02-01&diasMoraMinimos=1&pagina=1&tamanoPagina=20' 200 $tokenOficial)
    [void](Invoke-ApiCheck 'Dashboard de cartera' 'GET' '/api/cartera/dashboard?fechaCorte=2026-02-01' 200 $tokenOficial)
    [void](Invoke-ApiCheck 'Productos financieros' 'GET' '/api/productos-financieros?estado=ACTIVO' 200 $tokenAdmin)
    [void](Invoke-ApiCheck 'Alertas de cobranza' 'GET' '/api/cobranza/alertas?fechaCorte=2026-02-01&diasProximos=30' 200 $tokenOficial)
    [void](Invoke-ApiCheck 'Auditoria por rol auditor' 'GET' '/api/auditoria?entidad=EMPLEADO' 200 $tokenAuditor)

    [void](Invoke-ApiCheck 'Sin token' 'GET' '/api/cuentas/CTA-10001/saldo' 401)
    [void](Invoke-ApiCheck 'Rol insuficiente' 'GET' '/api/auditoria' 403 $tokenCajero)
    [void](Invoke-ApiCheck 'Validacion decimal invariante' 'POST' '/api/productos-financieros' 400 $tokenAdmin @{
        codigoProducto = 'PRE_SMOKE_INVALIDO'
        nombreProducto = 'Producto invalido de smoke test'
        tipoProducto = 'PRESTAMO'
        tasaInteres = 101
        montoMinimoApertura = 0
        estado = 'ACTIVO'
        cedulaEmpleado = 'EM-0103'
    })

    $writeResponse = Invoke-ApiCheck 'Escritura real de cobranza' 'POST' '/api/cobranza/gestiones' 201 $tokenOficial @{
        numeroPrestamo = 'PR-20001'
        cedulaEmpleado = 'EM-0102'
        tipoGestion = 'LLAMADA'
        resultado = 'CONTACTADO'
        comentario = 'Smoke test E2E 2026-08-17; registro reversible.'
        fechaCompromiso = $null
        montoCompromiso = $null
    }
    $gestionId = [long]$writeResponse.datos.gestionCobranzaID
    if ($gestionId -le 0) {
        throw 'La escritura de cobranza no devolvio GestionCobranzaID.'
    }
    $log.Add("[OK] Escritura confirmada en SQL Server | GestionCobranzaID=$gestionId")
    Remove-SmokeGestion $gestionId
    $log.Add('[OK] Limpieza de escritura smoke | gestion y auditoria eliminadas')
    $gestionId = $null

    $log.Add('')
    $log.Add('RESULTADO FINAL: APROBADO')
    $log.Add('Health, 4 logins, 9 lecturas, 3 casos negativos y 1 escritura real funcionaron.')
}
catch {
    $log.Add('')
    $log.Add('RESULTADO FINAL: FALLIDO')
    $log.Add($_.Exception.Message)
    if ([IO.File]::Exists($stderrPath)) {
        $log.Add('[API STDERR]')
        $log.Add([IO.File]::ReadAllText($stderrPath).TrimEnd())
    }
    throw
}
finally {
    if ($gestionId) {
        try {
            Remove-SmokeGestion $gestionId
            $log.Add('[OK] Limpieza de emergencia completada.')
        }
        catch {
            $log.Add('[ALERTA] No se pudo limpiar la gestion temporal: ' + $_.Exception.Message)
        }
    }
    if ($apiProcess -and -not $apiProcess.HasExited) {
        Stop-Process -Id $apiProcess.Id -Force
        $apiProcess.WaitForExit()
    }
    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process')
    }
    $cleanLog = @($log | ForEach-Object { $_.TrimEnd() })
    [IO.File]::WriteAllLines($evidence, $cleanLog, [Text.UTF8Encoding]::new($false))
    if ([IO.Directory]::Exists($temporaryRoot)) {
        [IO.Directory]::Delete($temporaryRoot, $true)
    }
}

Write-Host "Smoke test aprobado. Evidencia: $evidence"
