param([switch]$SkipPython)
$ErrorActionPreference = 'Stop'
$projectDir = Split-Path $PSScriptRoot -Parent
$toolsDir = Join-Path $projectDir '.tools'
New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
function Install-PinnedArchive($Name, $Url, $Hash, $Destination) {
    $archive = Join-Path $toolsDir "$Name.zip"
    if (!(Test-Path -LiteralPath $archive) -or
        (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Hash) {
        Invoke-WebRequest -Uri $Url -OutFile $archive
    }
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Hash) {
        throw "Checksum mismatch: $Name"
    }
    Expand-Archive -LiteralPath $archive -DestinationPath $Destination -Force
}
Install-PinnedArchive 'evengine-v0.6.0' `
    'https://github.com/EVEngine/EVEngine/releases/download/v0.6.0/eve-sdk-win32-v0.6.0.zip' `
    '8b4dccb5c86e41de4e71627576a4fdc1030b225e61024c4fa71a44c45c08d8c7' `
    (Join-Path $toolsDir 'evengine')
Install-PinnedArchive 'mesen-agent-v0.1.0' `
    'https://github.com/atonamy/mesen-agent/releases/download/v0.1.0/mesen-agent-windows-x64.zip' `
    '169a1f797fc7104d603a3cee19cbb0b62d44ed32686333eafca1b2295cd756c8' `
    (Join-Path $toolsDir 'mesen')
if (!$SkipPython) {
    & python -c 'import sys; assert sys.version_info >= (3, 12), "Python 3.12+ is required"'
    if ($LASTEXITCODE) { throw 'Install Python 3.12+ and put python on PATH' }
    $pythonExe = Join-Path $projectDir '.venv/Scripts/python.exe'
    if (!(Test-Path -LiteralPath $pythonExe)) {
        & python -m venv (Join-Path $projectDir '.venv')
        if ($LASTEXITCODE) { throw 'Cannot create Python environment' }
    }
    & $pythonExe -m pip install -r (Join-Path $projectDir 'requirements.txt')
    if ($LASTEXITCODE) { throw 'Python dependency installation failed' }
}
Write-Host 'Pinned tools installed in .tools/. Next: ./tools/package_windows.ps1'
