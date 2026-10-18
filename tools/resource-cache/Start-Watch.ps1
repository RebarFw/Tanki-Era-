param([string]$RuntimeRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent))
$ErrorActionPreference = 'Stop'
$taskPublication = Join-Path $RuntimeRoot 'resource-publication'
$taskEnabled = Join-Path $taskPublication 'enabled.json'
if (-not (Test-Path -LiteralPath $taskEnabled)) { exit 0 }
if (-not (Get-Content -LiteralPath $taskEnabled -Raw | ConvertFrom-Json).enabled) { exit 0 }
$taskPython = (Get-Command python.exe -ErrorAction Stop).Source
$taskWatcher = Join-Path $PSScriptRoot 'auto_publish.py'
$taskPidFile = Join-Path $taskPublication 'publisher.pid'
if (Test-Path -LiteralPath $taskPidFile) {
    $taskExistingId = (Get-Content -LiteralPath $taskPidFile -Raw).Trim()
    if ($taskExistingId -match '^\d+$') {
        $taskExisting = Get-CimInstance Win32_Process -Filter "ProcessId=$taskExistingId" -ErrorAction SilentlyContinue
        if ($taskExisting -and $taskExisting.CommandLine -like ('*'+$taskWatcher+'*')) { exit 0 }
    }
}
$taskLogStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$taskProcess = Start-Process -FilePath $taskPython -ArgumentList @('-u',('"'+$taskWatcher+'"'),'--runtime',('"'+$RuntimeRoot+'"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskPublication "watcher-$taskLogStamp.stdout.log") -RedirectStandardError (Join-Path $taskPublication "watcher-$taskLogStamp.stderr.log")
try { $taskProcess.PriorityClass = 'BelowNormal' } catch { }
# The Python file lock prevents a second publisher from doing work.
