param(
    [Parameter(Mandatory = $true)][string]$SharedTools,
    [switch]$SkipPython,
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
$projectDir = Split-Path $PSScriptRoot -Parent
$sharedToolsDir = (Resolve-Path -LiteralPath $SharedTools).Path
$sdkDir = Join-Path $sharedToolsDir 'evengine/eve-sdk/win32'
$evePath = Join-Path $sdkDir 'bin/eve.exe'
$mesenPath = Join-Path $sharedToolsDir 'mesen/mesen-agent.exe'
foreach ($requiredPath in @($evePath, $mesenPath, (Join-Path $sdkDir 'cmake/EVEngineConfig.cmake'))) {
    if (!(Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Missing shared tool: $requiredPath. Install pinned tools with setup_windows.ps1 first."
    }
}
# Only executables and SDK inputs are shared. Build caches and plugins stay local.
$env:EVE_EXE = $evePath
$env:MESEN_AGENT = $mesenPath
if (!$SkipPython) {
    & python -c 'import sys; assert sys.version_info >= (3, 12), "Python 3.12+ is required"'
    if ($LASTEXITCODE) { throw 'Install Python 3.12+ and put python on PATH' }
    $worktreePython = Join-Path $projectDir '.venv/Scripts/python.exe'
    if (!(Test-Path -LiteralPath $worktreePython)) {
        & python -m venv (Join-Path $projectDir '.venv')
        if ($LASTEXITCODE) { throw 'Cannot create worktree Python environment' }
    }
    & $worktreePython -m pip install -r (Join-Path $projectDir 'requirements.txt')
    if ($LASTEXITCODE) { throw 'Worktree Python dependency installation failed' }
}
if (!$SkipBuild) {
    & (Join-Path $PSScriptRoot 'build_native_audio.ps1') -Sdk $sdkDir
    if ($LASTEXITCODE) { throw 'Worktree native build failed' }
}
Write-Host "Worktree ready: $projectDir"
Write-Host 'EVE_EXE and MESEN_AGENT are set for this PowerShell process only; rerun in new terminals.'
Write-Host "For packaging, pass -Sdk '$sdkDir' to tools/package_windows.ps1."
