param(
    [string]$AddOnsPath = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $repoRoot "Tools\XFrames_Testing"

if (-not (Test-Path $sourcePath)) {
    throw "Could not find source addon folder: $sourcePath"
}

$repoParent = Split-Path -Parent $repoRoot
$repoParentName = Split-Path -Leaf $repoParent
$installMode = "build"

if ([string]::IsNullOrWhiteSpace($AddOnsPath)) {
    if ($repoParentName -ieq "AddOns") {
        $AddOnsPath = $repoParent
        $installMode = "install"
    } else {
        $AddOnsPath = Join-Path $repoRoot "Build"
    }
} else {
    $installMode = "install"
}

if (-not (Test-Path $AddOnsPath)) {
    New-Item -ItemType Directory -Path $AddOnsPath -Force | Out-Null
}

$targetPath = Join-Path $AddOnsPath "XFrames_Testing"

if (Test-Path $targetPath) {
    Remove-Item -Recurse -Force $targetPath
}

Copy-Item -Path $sourcePath -Destination $targetPath -Recurse -Force

Write-Host ""
Write-Host "XFrames_Testing prepared successfully." -ForegroundColor Green
Write-Host "Source : $sourcePath"
Write-Host "Target : $targetPath"
Write-Host ""

if ($installMode -eq "install") {
    Write-Host "This folder is ready to load as a separate addon in WoW." -ForegroundColor Cyan
} else {
    Write-Host "Repo is not inside a WoW AddOns folder, so a build/export copy was created." -ForegroundColor Yellow
    Write-Host "Copy 'XFrames_Testing' from the target path into your WoW _retail_\\Interface\\AddOns folder when ready." -ForegroundColor Yellow
}
