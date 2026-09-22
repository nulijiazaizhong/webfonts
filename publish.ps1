<#
.SYNOPSIS
  发布到 npm，从而通过 jsDelivr 提供 CDN。

.EXAMPLE
  .\publish.ps1
  .\publish.ps1 -Version 7.9.1
  .\publish.ps1 -DryRun
#>
[CmdletBinding()]
param(
  [string]$Version,
  [string]$PackageName = "maple-mono-nf-cn-woff2",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
Set-Location $root

if (-not (Test-Path "webfonts")) { throw "缺少 webfonts/，请先运行 convert-fonts" }
if (-not (Test-Path "package.json")) { throw "缺少 package.json" }

if ($Version) {
  $pkg = Get-Content package.json -Raw | ConvertFrom-Json
  $pkg.version = $Version
  $pkg | ConvertTo-Json -Depth 5 | Set-Content package.json -Encoding utf8
  Write-Host "版本更新为 $Version"
}

# 同步 CDN CSS 中的 __CDN_BASE__
$ver = (Get-Content package.json -Raw | ConvertFrom-Json).version
$cdnBase = "https://cdn.jsdelivr.net/npm/$PackageName@$ver"
$cdnCss = Get-ChildItem css\*.cdn.css -ErrorAction SilentlyContinue
foreach ($f in $cdnCss) {
  $t = Get-Content $f.FullName -Raw
  $t = $t -replace '__CDN_BASE__', $cdnBase
  Set-Content -Path $f.FullName -Value $t -Encoding utf8
  Write-Host "已替换 CDN 前缀: $($f.Name) → $cdnBase"
}

if ($DryRun) {
  Write-Host "DryRun: npm publish --access public" -ForegroundColor Yellow
  npm pack --dry-run
} else {
  Write-Host "执行 npm publish --access public ..." -ForegroundColor Cyan
  npm publish --access public
  Write-Host "完成。CDN 前缀: $cdnBase" -ForegroundColor Green
  Write-Host "示例: $cdnBase/webfonts/MapleMono-NF-CN-Regular.woff2"
}
