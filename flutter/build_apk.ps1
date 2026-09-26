<#
.SYNOPSIS
    Build an APK and rename it to <applicationId>-<versionName>-<buildType>.apk

.DESCRIPTION
    Renaming cannot live in android/app/build.gradle: after the Gradle build
    finishes, the Flutter tool looks for app-<buildType>.apk by hardcoded name,
    so overriding outputFileName produces
    "Gradle build failed to produce an .apk file".
    Hence the rename happens here, after `flutter build apk` succeeds.

    Note: keep this file pure ASCII. Windows PowerShell 5.1 reads .ps1 as the
    ANSI codepage (GBK on zh-CN), so non-ASCII characters corrupt parsing.

.EXAMPLE
    .\build_apk.ps1              # debug build
    .\build_apk.ps1 -Release     # release build
#>
param(
    [switch]$Release
)

$ErrorActionPreference = 'Stop'
$projectDir = $PSScriptRoot
$buildType = if ($Release) { 'release' } else { 'debug' }
$flutterArg = if ($Release) { '--release' } else { '--debug' }

# Must match the values in android/app/build.gradle
$baseAppId = 'com.jisuxiongmao.jisuxiongmao'

Push-Location $projectDir
try {
    Write-Host "==> flutter build apk $flutterArg" -ForegroundColor Cyan
    & flutter build apk $flutterArg
    if ($LASTEXITCODE -ne 0) { throw "flutter build failed (exit $LASTEXITCODE)" }

    $pubspec = Get-Content (Join-Path $projectDir 'pubspec.yaml') -Raw
    $verName = [regex]::Match($pubspec, '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)').Groups[1].Value
    if (-not $verName) { throw 'could not parse version from pubspec.yaml' }

    # debug variant carries applicationIdSuffix ".debug" and versionNameSuffix "-debug"
    $fullAppId = if ($Release) { $baseAppId } else { "$baseAppId.debug" }
    $fullVer = if ($Release) { $verName } else { "$verName-debug" }
    $targetName = "$fullAppId-$fullVer-$buildType.apk"

    $outDir = Join-Path $projectDir "build\app\outputs\flutter-apk"
    $source = Join-Path $outDir "app-$buildType.apk"
    if (-not (Test-Path $source)) { throw "build artifact not found: $source" }

    $target = Join-Path $outDir $targetName
    if (Test-Path $target) { Remove-Item $target -Force }
    Move-Item $source $target
    Remove-Item (Join-Path $outDir "app-$buildType.apk.sha1") -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "==> BUILD OK" -ForegroundColor Green
    Write-Host "    $target"
}
finally {
    Pop-Location
}
