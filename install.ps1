#Requires -Version 5.1
<# Link skills using directory junctions; no administrator privileges required. #>
[CmdletBinding()]
param(
  [ValidateSet('all', 'codex', 'claude', 'opencode')][string]$Agent = 'all',
  [switch]$DryRun,
  [switch]$List,
  [switch]$Help,
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$Skills
)
$ErrorActionPreference = 'Stop'
$SkillsSrc = Join-Path $PSScriptRoot 'skills'
if ($Help) {
  Write-Host 'Usage: ./install.ps1 [-Agent all|codex|claude|opencode] [-DryRun] [skill ...]'
  Write-Host 'Use -List to list skills. Existing ordinary directories are preserved.'
  exit 0
}
$available = @(Get-ChildItem -LiteralPath $SkillsSrc -Directory |
  Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } |
  Sort-Object Name | Select-Object -ExpandProperty Name)
if ($List) { $available; exit 0 }
$requested = @($Skills | Where-Object { $_ })
if ($requested.Count -eq 0) { $requested = $available }
foreach ($name in $requested) {
  if ($name -match '[/\\]' -or $available -notcontains $name) {
    [Console]::Error.WriteLine("Unknown skill: $name (use -List)"); exit 2
  }
}
$codexRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$targets = @()
if ($Agent -in @('all', 'codex')) {
  $targets += $(if ($env:CODEX_SKILLS_DIR) { $env:CODEX_SKILLS_DIR } else { Join-Path $codexRoot 'skills' })
}
if ($Agent -in @('all', 'claude')) {
  $targets += $(if ($env:CLAUDE_SKILLS_DIR) { $env:CLAUDE_SKILLS_DIR } else { Join-Path $HOME '.claude\skills' })
}
if ($Agent -in @('all', 'opencode')) {
  $targets += $(if ($env:OPENCODE_SKILLS_DIR) { $env:OPENCODE_SKILLS_DIR } else { Join-Path $HOME '.config\opencode\skills' })
}
function Normalize-Path([string]$Path) {
  [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
}
$conflicts = $false
foreach ($name in $requested) {
  $src = Join-Path $SkillsSrc $name
  foreach ($target in $targets) {
    $link = Join-Path $target $name
    $entry = if (Test-Path -LiteralPath $target) {
      Get-ChildItem -LiteralPath $target -Force | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    } else { $null }
    if ($entry -and -not $entry.LinkType) {
      [Console]::Error.WriteLine("Preserved existing ordinary path: $link")
      $conflicts = $true
      continue
    }
    $current = if ($entry) { @($entry.Target)[0] } else { $null }
    if ($entry -and $current -and
        (Normalize-Path $current) -eq (Normalize-Path $src) -and
        (Test-Path -LiteralPath $link)) {
      Write-Host "Already installed: $link"
      continue
    }
    if ($DryRun) { Write-Host "Plan: $link <- $src"; continue }
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    if ($entry) {
      # Remove the junction/symlink itself; do not recurse into its target.
      if ($entry.PSIsContainer) { [System.IO.Directory]::Delete($link) }
      else { [System.IO.File]::Delete($link) }
    }
    New-Item -ItemType Junction -Path $link -Target $src | Out-Null
    Write-Host "Linked: $link <- $src"
  }
}
if ($conflicts) { exit 1 }
Write-Host 'Done.'
