param(
    [string]$Sdk = "$env:USERPROFILE/.codex/cache/evengine/v0.6.0/sdk/eve-sdk/win32",
    [string]$BuildDir = "",
    [string]$OutputDir = ""
)
$ErrorActionPreference = 'Stop'
$projectDir = Split-Path $PSScriptRoot -Parent
if (!$BuildDir) { $BuildDir = Join-Path (Split-Path $projectDir -Parent) 'builds/super-mario-native-audio' }
if (!$OutputDir) { $OutputDir = Join-Path $projectDir 'native/bin' }
$vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
$vsDir = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$vsDir) { throw 'Visual Studio C++ Build Tools are required' }
$cmake = Join-Path $vsDir 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
$ctest = Join-Path (Split-Path $cmake -Parent) 'ctest.exe'
& $cmake -S "$projectDir/native/audio" -B $BuildDir -G 'Visual Studio 17 2022' -A x64 "-DEVEngine_DIR=$Sdk/cmake"
if ($LASTEXITCODE) { throw 'Native audio configure failed' }
& $cmake --build $BuildDir --config Release --parallel 4
if ($LASTEXITCODE) { throw 'Native audio build failed' }
& $ctest --test-dir $BuildDir -C Release --output-on-failure
if ($LASTEXITCODE) { throw 'Native audio tests failed' }
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Copy-Item -LiteralPath "$BuildDir/Release/mario_audio.dll" -Destination $OutputDir
Copy-Item -LiteralPath "$BuildDir/Release/SuperMario.exe" -Destination $OutputDir
Write-Host "Native audio and GUI launcher built: $OutputDir"
