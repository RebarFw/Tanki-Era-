[CmdletBinding()]
param(
    [string]$RuntimeZip = (Join-Path $PSScriptRoot 'runtime.zip'),
    [string]$IconFile = (Join-Path $PSScriptRoot 'icon128.ico'),
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'build'),
    [string]$SigningCertificateThumbprint,
    [string]$TimestampServer = 'http://timestamp.digicert.com',
    [switch]$RequireSignature
)
$ErrorActionPreference = 'Stop'
$signer = $null
if ($RequireSignature -and -not $SigningCertificateThumbprint) { throw 'A trusted code-signing identity is required.' }
if ($SigningCertificateThumbprint) {
    if ($SigningCertificateThumbprint -notmatch '^[a-fA-F0-9]{40}$') { throw 'Invalid signing thumbprint.' }
    $candidates = @(Get-ChildItem -Path 'Cert:\CurrentUser\My','Cert:\LocalMachine\My' -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $SigningCertificateThumbprint })
    if ($candidates.Count -ne 1) { throw 'Code-signing certificate not found or ambiguous.' }
    $signer = $candidates[0]
    if (-not $signer.HasPrivateKey -or $signer.NotAfter -le (Get-Date) -or $signer.NotBefore -gt (Get-Date) -or $signer.Subject -eq $signer.Issuer -or $signer.EnhancedKeyUsageList.ObjectId -notcontains '1.3.6.1.5.5.7.3.3' -or -not $signer.Verify()) {
        throw 'A valid, trusted, issued code-signing certificate with a private key is required.'
    }
    if ($TimestampServer -notmatch '^http://') { throw 'Windows PowerShell requires an HTTP Authenticode timestamp endpoint.' }
}
$expectedRuntime = '571a7829da6caacfb981cb701adfedbbefdeb4d7a72b2b915c03650005fe79d8'
if ((Get-FileHash -LiteralPath $RuntimeZip -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedRuntime) { throw 'Runtime archive differs from the reviewed release.' }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$exe = Join-Path $OutputDirectory 'Tanki Era.exe'
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ "/out:$exe" "/win32icon:$IconFile" "/resource:$RuntimeZip,TankiEra.runtime.zip" /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll (Join-Path $PSScriptRoot 'Launcher.cs')
if ($LASTEXITCODE -ne 0) { throw 'Compilation failed.' }
if ($signer) {
    $signature = Set-AuthenticodeSignature -LiteralPath $exe -Certificate $signer -HashAlgorithm SHA256 -IncludeChain NotRoot -TimestampServer $TimestampServer
    if ($signature.Status -ne 'Valid' -or -not $signature.TimeStamperCertificate) { throw 'A valid timestamped signature was not produced. Do not distribute this build.' }
}
Get-Item -LiteralPath $exe | Select-Object FullName,Length
Get-AuthenticodeSignature -LiteralPath $exe | Select-Object Status,@{Name='Publisher';Expression={$_.SignerCertificate.Subject}}
