param(
  [string]$SkillsRoot = "$env:USERPROFILE\.claude\skills"
)

$ErrorActionPreference = "Stop"

$SkillName = "adversarial-reviewer-lite"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
$SourceDir = Join-Path $RepoRoot "skills\$SkillName"
$DestDir = Join-Path $SkillsRoot $SkillName
$SourceSkill = Join-Path $SourceDir "SKILL.md"
$DestSkill = Join-Path $DestDir "SKILL.md"

if (-not (Test-Path -LiteralPath $SourceSkill)) {
  Write-Error "Could not find $SourceSkill. Run this script from a complete adversarial-reviewer-lite checkout."
}

if ((Split-Path -Leaf $DestDir) -ne $SkillName) {
  Write-Error "Refusing to install: destination does not end with $SkillName`: $DestDir"
}

if (Test-Path -LiteralPath $DestDir) {
  Remove-Item -LiteralPath $DestDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
Copy-Item -Recurse -Force -Path (Join-Path $SourceDir "*") -Destination $DestDir

if (-not (Test-Path -LiteralPath $DestSkill)) {
  Write-Error "Install failed: $DestSkill was not created."
}

Write-Host "Installed $SkillName to:"
Write-Host $DestDir
Write-Host ""
Write-Host "Restart Claude Code if it was already open, then run:"
Write-Host "/adversarial-reviewer-lite audit"
Write-Host ""
Write-Host "Optional habit reminder:"
Write-Host "Copy snippets/claude-md-reminder.md into your project's CLAUDE.md."
