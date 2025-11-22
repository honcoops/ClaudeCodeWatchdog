<#
.SYNOPSIS
    Audits error handling across all Claude Code Watchdog modules

.DESCRIPTION
    Analyzes all PowerShell modules for error handling patterns, gaps,
    and compliance with best practices. Generates a comprehensive report.

.NOTES
    Part of WS07 - Testing & Quality Assurance
    Work Item: WI-4.1 - Comprehensive Error Handling
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SourcePath = "../src",

    [Parameter()]
    [string]$OutputPath = "./error-handling-audit-report.md"
)

function Test-ErrorHandling {
    <#
    .SYNOPSIS
        Analyzes a PowerShell script file for error handling patterns
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $content = Get-Content $FilePath -Raw
    $fileName = Split-Path $FilePath -Leaf

    $analysis = @{
        FilePath = $FilePath
        FileName = $fileName
        HasTryCatch = $content -match '\btry\s*\{'
        TryCatchCount = ([regex]::Matches($content, '\btry\s*\{')).Count
        HasErrorAction = $content -match '-ErrorAction'
        HasWriteError = $content -match '\bWrite-Error\b'
        HasWriteWarning = $content -match '\bWrite-Warning\b'
        HasThrow = $content -match '\bthrow\b'
        HasParameterValidation = $content -match '\[Parameter\(.*Mandatory.*\)\]' -or $content -match '\[ValidateNotNull'
        HasCmdletBinding = $content -match '\[CmdletBinding\(\)\]'
        HasErrorVariable = $content -match '-ErrorVariable'
        HasShouldProcess = $content -match 'ShouldProcess'
        FunctionCount = ([regex]::Matches($content, '\bfunction\s+\S+')).Count
        Issues = @()
        Recommendations = @()
        Score = 0
    }

    # Analyze issues and recommendations
    if (-not $analysis.HasTryCatch) {
        $analysis.Issues += "No try-catch blocks found"
        $analysis.Recommendations += "Add try-catch blocks for error handling"
    }

    if (-not $analysis.HasCmdletBinding) {
        $analysis.Issues += "No [CmdletBinding()] attribute found"
        $analysis.Recommendations += "Add [CmdletBinding()] for better error handling support"
    }

    if (-not $analysis.HasParameterValidation) {
        $analysis.Issues += "No parameter validation found"
        $analysis.Recommendations += "Add parameter validation attributes ([Parameter(Mandatory)], [ValidateNotNull], etc.)"
    }

    if ($analysis.FunctionCount -gt 3 -and $analysis.TryCatchCount -lt $analysis.FunctionCount * 0.5) {
        $analysis.Issues += "Insufficient try-catch coverage (less than 50% of functions)"
        $analysis.Recommendations += "Add try-catch blocks to at least 80% of functions"
    }

    if (-not $analysis.HasWriteError -and -not $analysis.HasThrow) {
        $analysis.Issues += "No error reporting mechanism (Write-Error or throw)"
        $analysis.Recommendations += "Add Write-Error or throw statements for error reporting"
    }

    # Calculate score (0-100)
    $score = 0
    if ($analysis.HasTryCatch) { $score += 25 }
    if ($analysis.HasCmdletBinding) { $score += 15 }
    if ($analysis.HasParameterValidation) { $score += 15 }
    if ($analysis.HasWriteError -or $analysis.HasThrow) { $score += 15 }
    if ($analysis.HasWriteWarning) { $score += 10 }
    if ($analysis.HasErrorAction) { $score += 10 }
    if ($analysis.TryCatchCount -ge $analysis.FunctionCount * 0.8) { $score += 10 }

    $analysis.Score = $score

    return $analysis
}

function Get-ScoreGrade {
    param([int]$Score)

    if ($Score -ge 80) { return "A (Excellent)" }
    elseif ($Score -ge 70) { return "B (Good)" }
    elseif ($Score -ge 60) { return "C (Adequate)" }
    elseif ($Score -ge 50) { return "D (Needs Improvement)" }
    else { return "F (Critical)" }
}

# Main execution
Write-Host "🔍 Starting Error Handling Audit..." -ForegroundColor Cyan

$scriptRoot = Split-Path -Parent $PSCommandPath
$sourcePath = Join-Path $scriptRoot $SourcePath
$outputPath = Join-Path $scriptRoot $OutputPath

if (-not (Test-Path $sourcePath)) {
    Write-Error "Source path not found: $sourcePath"
    exit 1
}

# Find all PowerShell script files
$scriptFiles = Get-ChildItem -Path $sourcePath -Filter "*.ps1" -Recurse | Where-Object {
    $_.Name -notlike "*.Tests.ps1"
}

Write-Host "Found $($scriptFiles.Count) script files to analyze" -ForegroundColor Gray

# Analyze each file
$results = @()
$totalScore = 0

foreach ($file in $scriptFiles) {
    Write-Host "  Analyzing: $($file.Name)..." -ForegroundColor Gray
    $analysis = Test-ErrorHandling -FilePath $file.FullName
    $results += $analysis
    $totalScore += $analysis.Score
}

$averageScore = [math]::Round($totalScore / $results.Count, 1)
$averageGrade = Get-ScoreGrade -Score $averageScore

# Generate markdown report
$report = @"
# Error Handling Audit Report - Claude Code Watchdog

**Generated**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Files Analyzed**: $($results.Count)
**Average Score**: $averageScore / 100 ($averageGrade)

---

## Executive Summary

This report analyzes error handling patterns across all Claude Code Watchdog PowerShell modules.

### Overall Statistics

| Metric | Count | Percentage |
|--------|-------|------------|
| Files with try-catch blocks | $(($results | Where-Object HasTryCatch).Count) | $([math]::Round((($results | Where-Object HasTryCatch).Count / $results.Count) * 100, 1))% |
| Files with [CmdletBinding()] | $(($results | Where-Object HasCmdletBinding).Count) | $([math]::Round((($results | Where-Object HasCmdletBinding).Count / $results.Count) * 100, 1))% |
| Files with parameter validation | $(($results | Where-Object HasParameterValidation).Count) | $([math]::Round((($results | Where-Object HasParameterValidation).Count / $results.Count) * 100, 1))% |
| Files with Write-Error | $(($results | Where-Object HasWriteError).Count) | $([math]::Round((($results | Where-Object HasWriteError).Count / $results.Count) * 100, 1))% |
| Files with Write-Warning | $(($results | Where-Object HasWriteWarning).Count) | $([math]::Round((($results | Where-Object HasWriteWarning).Count / $results.Count) * 100, 1))% |

### Score Distribution

"@

# Add score distribution
$scoreGroups = $results | Group-Object { Get-ScoreGrade -Score $_.Score } | Sort-Object Name
foreach ($group in $scoreGroups) {
    $report += "- **$($group.Name)**: $($group.Count) files`n"
}

$report += @"

---

## Detailed Analysis by Module

"@

# Sort results by score (lowest first - need most attention)
$sortedResults = $results | Sort-Object Score

foreach ($result in $sortedResults) {
    $grade = Get-ScoreGrade -Score $result.Score
    $relPath = $result.FilePath -replace [regex]::Escape($sourcePath), 'src'

    $report += @"

### $($result.FileName)

**Path**: ``$relPath``
**Score**: $($result.Score)/100 ($grade)
**Functions**: $($result.FunctionCount)
**Try-Catch Blocks**: $($result.TryCatchCount)

**Error Handling Features:**
- Try-Catch Blocks: $(if ($result.HasTryCatch) { '✅' } else { '❌' })
- CmdletBinding: $(if ($result.HasCmdletBinding) { '✅' } else { '❌' })
- Parameter Validation: $(if ($result.HasParameterValidation) { '✅' } else { '❌' })
- Write-Error: $(if ($result.HasWriteError) { '✅' } else { '❌' })
- Write-Warning: $(if ($result.HasWriteWarning) { '✅' } else { '❌' })
- Throw Statements: $(if ($result.HasThrow) { '✅' } else { '❌' })

"@

    if ($result.Issues.Count -gt 0) {
        $report += "**Issues:**`n"
        foreach ($issue in $result.Issues) {
            $report += "- ⚠️  $issue`n"
        }
        $report += "`n"
    }

    if ($result.Recommendations.Count -gt 0) {
        $report += "**Recommendations:**`n"
        foreach ($rec in $result.Recommendations) {
            $report += "- 🔧 $rec`n"
        }
        $report += "`n"
    }
}

$report += @"

---

## Critical Findings

### Files Requiring Immediate Attention (Score < 50)

"@

$criticalFiles = $results | Where-Object { $_.Score -lt 50 } | Sort-Object Score
if ($criticalFiles.Count -eq 0) {
    $report += "✅ No critical issues found!`n`n"
} else {
    foreach ($file in $criticalFiles) {
        $report += "- **$($file.FileName)** (Score: $($file.Score)/100)`n"
        $report += "  - Issues: $($file.Issues.Count)`n"
        $report += "  - Path: ``$($file.FilePath -replace [regex]::Escape($sourcePath), 'src')```n`n"
    }
}

$report += @"

### Files with No Try-Catch Blocks

"@

$noTryCatch = $results | Where-Object { -not $_.HasTryCatch }
if ($noTryCatch.Count -eq 0) {
    $report += "✅ All files have try-catch blocks!`n`n"
} else {
    foreach ($file in $noTryCatch) {
        $report += "- $($file.FileName)`n"
    }
    $report += "`n"
}

$report += @"

---

## Recommendations

### High Priority

1. **Add try-catch blocks** to all functions that interact with external systems (APIs, file I/O, Windows MCP)
2. **Implement parameter validation** using PowerShell attributes ([Parameter(Mandatory)], [ValidateNotNull], etc.)
3. **Add [CmdletBinding()]** to all functions for consistent error handling behavior
4. **Standardize error reporting** using Write-Error for recoverable errors, throw for fatal errors

### Medium Priority

1. **Add Write-Warning** for non-critical issues that users should know about
2. **Use -ErrorAction** parameters consistently to control error behavior
3. **Implement error logging** for all caught exceptions
4. **Add input validation** at function entry points

### Low Priority

1. **Add ShouldProcess** support for functions that modify state
2. **Use -ErrorVariable** for advanced error handling scenarios
3. **Document error handling** in function help

---

## Next Steps

1. Review all files with Score < 70
2. Implement recommended error handling improvements
3. Create unit tests to verify error handling
4. Re-run audit after improvements

---

**Audit completed at**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

"@

# Save report
$report | Set-Content -Path $outputPath -Force

Write-Host "`n✅ Audit Complete!" -ForegroundColor Green
Write-Host "📊 Average Score: $averageScore / 100 ($averageGrade)" -ForegroundColor Cyan
Write-Host "📄 Report saved to: $outputPath" -ForegroundColor Gray
Write-Host "`nTop 5 files needing attention:" -ForegroundColor Yellow

$top5 = $sortedResults | Select-Object -First 5
foreach ($file in $top5) {
    $grade = Get-ScoreGrade -Score $file.Score
    Write-Host "  - $($file.FileName): $($file.Score)/100 ($grade)" -ForegroundColor $(if ($file.Score -lt 50) { 'Red' } elseif ($file.Score -lt 70) { 'Yellow' } else { 'Gray' })
}

Write-Host "`nFor detailed analysis, see: $outputPath" -ForegroundColor Gray
