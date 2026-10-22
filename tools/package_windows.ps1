param(
    [string]$Sdk = "$env:USERPROFILE/.codex/cache/evengine/v0.6.0/sdk/eve-sdk/win32",
    [string]$Output = ""
)
$ErrorActionPreference = 'Stop'
$projectDir = Split-Path $PSScriptRoot -Parent
if (!$Output) {
    $Output = Join-Path (Split-Path $projectDir -Parent) ("builds/super-mario-native-audio-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-win64')
}
if (Test-Path -LiteralPath $Output) { throw "Output must be a new directory: $Output" }
if ((Get-Content -Raw "$projectDir/scripts/generated/parity_movie.nut") -match 'PARITY_MOVIE_ENABLED\s*<-\s*true') {
    throw 'Disable the generated parity replay before packaging'
}
& "$PSScriptRoot/build_native_audio.ps1" -Sdk $Sdk
New-Item -ItemType Directory -Path $Output | Out-Null
Copy-Item -Path "$Sdk/bin/*" -Destination $Output
Copy-Item -LiteralPath "$projectDir/main.nut", "$projectDir/config.nut" -Destination $Output
Copy-Item -LiteralPath "$projectDir/assets", "$projectDir/scripts" -Destination $Output -Recurse
New-Item -ItemType Directory -Path "$Output/native/bin" -Force | Out-Null
Copy-Item -LiteralPath "$projectDir/native/bin/mario_audio.dll" -Destination "$Output/native/bin"
Copy-Item -LiteralPath "$PSScriptRoot/run_game.cmd" -Destination "$Output/Play.cmd"
Write-Host "Windows game: $Output/Play.cmd"
