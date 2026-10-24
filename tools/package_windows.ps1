param(
    [string]$Sdk = "",
    [string]$Output = ""
)
$ErrorActionPreference = 'Stop'
$projectDir = Split-Path $PSScriptRoot -Parent
if (!$Sdk) { $Sdk = Join-Path $projectDir '.tools/evengine/eve-sdk/win32' }
if (!$Output) {
    $Output = Join-Path $projectDir ("dist/super-mario-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-win64')
}
if (Test-Path -LiteralPath $Output) { throw "Output must be a new directory: $Output" }
if ((Get-Content -Raw "$projectDir/scripts/generated/parity_movie.nut") -match 'PARITY_MOVIE_ENABLED\s*<-\s*true') {
    throw 'Disable the generated parity replay before packaging'
}
& "$PSScriptRoot/build_native_audio.ps1" -Sdk $Sdk
New-Item -ItemType Directory -Path $Output | Out-Null
New-Item -ItemType Directory -Path "$Output/runtime" | Out-Null
Copy-Item -Path "$Sdk/bin/*" -Destination "$Output/runtime"
Copy-Item -LiteralPath "$projectDir/main.nut", "$projectDir/config.nut" -Destination $Output
# Keep development checks and hot reload in source runs, not player startup.
$releaseConfig = Get-Content -LiteralPath "$projectDir/config.nut" -Raw
foreach ($setting in @('hotReload', 'startupSelfTests')) {
    $pattern = "(?m)^(\s*" + $setting + "\s*=\s*)true\b"
    $releaseConfig = [regex]::Replace($releaseConfig, $pattern, '${1}false')
    if ($releaseConfig -notmatch ("(?m)^\s*" + $setting + "\s*=\s*false\b")) {
        throw "Release configuration must disable $setting"
    }
}
[System.IO.File]::WriteAllText((Join-Path $Output 'config.nut'), $releaseConfig,
    [System.Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath "$projectDir/assets", "$projectDir/scripts" -Destination $Output -Recurse
New-Item -ItemType Directory -Path "$Output/native/bin" -Force | Out-Null
Copy-Item -LiteralPath "$projectDir/native/bin/mario_audio.dll" -Destination "$Output/native/bin"
Copy-Item -LiteralPath "$projectDir/native/bin/SuperMario.exe" -Destination $Output
Copy-Item -LiteralPath "$PSScriptRoot/run_game.cmd" -Destination "$Output/Play.cmd"
Write-Host "Windows game: $Output/SuperMario.exe"
