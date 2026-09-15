#Requires -Version 5.1
<#
.SYNOPSIS
  agent-skills-kit 一键安装（Windows 原生）：把指定 skill 链接到 opencode 与 Claude Code

.DESCRIPTION
  与 install.sh 行为对齐，改用目录联接（junction）把仓库中的 skill 映射到目标目录。
  联接（junction）在 Windows 上无需管理员权限或开发者模式，是目录链接的可移植选择。

.EXAMPLE
  ./install.ps1                 # 安装全部 skill
  ./install.ps1 shotframe       # 只安装指定 skill
  ./install.ps1 shotframe gh-stars
#>
[CmdletBinding()]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Skills
)

$ErrorActionPreference = 'Stop'

$RepoDir = $PSScriptRoot
$SkillsSrc = Join-Path $RepoDir 'skills'

$OpenCodeDir = if ($env:OPENCODE_SKILLS_DIR) { $env:OPENCODE_SKILLS_DIR } else { Join-Path $HOME '.config\opencode\skills' }
$ClaudeDir   = if ($env:CLAUDE_SKILLS_DIR)   { $env:CLAUDE_SKILLS_DIR }   else { Join-Path $HOME '.claude\skills' }

function Get-NormalizedPath([string]$Path) {
  return [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
}

function Link-One {
  param([string]$Target, [string]$Name, [string]$Source)

  if (-not (Test-Path -LiteralPath $Target)) {
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
  }
  $link = Join-Path $Target $Name

  # 用列目录判定存在性：即便联接目标是失效路径也能被识别
  $entry = Get-ChildItem -LiteralPath $Target -Force |
    Where-Object { $_.Name -eq $Name } |
    Select-Object -First 1

  if ($entry) {
    if ($entry.LinkType) {
      $current = @($entry.Target)[0]
      if ($current -and ((Get-NormalizedPath $current) -eq (Get-NormalizedPath $Source))) {
        Write-Host "  · $link 已指向本仓库且有效，跳过"
        return
      }
      Write-Host "  · $link 是旧/失效链接（→ $current），重新链接到 $Source"
      Remove-Item -LiteralPath $link -Force -Recurse
    } else {
      Write-Host "  · $link 已存在（非链接），跳过"
      return
    }
  }

  New-Item -ItemType Junction -Path $link -Target $Source | Out-Null
  Write-Host "  · $link ← $Source"
}

# 注意：未传参时 $Skills 为 $null，而 @($null).Count 是 1（不是 0），
# 必须先过滤掉空值，否则会走进循环并把 $null 当 skill 名处理。
$requested = @($Skills | Where-Object { $_ })
if ($requested.Count -eq 0) {
  $requested = @(Get-ChildItem -LiteralPath $SkillsSrc -Directory | Select-Object -ExpandProperty Name)
}

foreach ($name in $requested) {
  $name = Split-Path -Leaf $name
  $src = Join-Path $SkillsSrc $name
  if (-not (Test-Path -LiteralPath $src -PathType Container)) {
    [Console]::Error.WriteLine("✗ 找不到 skill: $name")
    exit 1
  }
  Write-Host "安装 $name →"
  Link-One -Target $OpenCodeDir -Name $name -Source $src
  Link-One -Target $ClaudeDir   -Name $name -Source $src
}

Write-Host '完成。重启 opencode / Claude Code 后即可使用。'
