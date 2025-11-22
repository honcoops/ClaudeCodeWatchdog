<#
.SYNOPSIS
    Runs all unit and integration tests for Claude Code Watchdog

.DESCRIPTION
    Executes the complete test suite and generates coverage reports

.PARAMETER TestType
    Type of tests to run: Unit, Integration, or All (default)

.PARAMETER GenerateCoverageReport
    Generate code coverage report

.PARAMETER OutputPath
    Path for test results and coverage reports

.EXAMPLE
    .\Run-AllTests.ps1

.EXAMPLE
    .\Run-AllTests.ps1 -TestType Unit -GenerateCoverageReport

.NOTES
    Part of WS07 - Testing & Quality Assurance
    Requires: Pester 5.0+
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("Unit", "Integration", "All")]
    [string]$TestType = "All",

    [Parameter()]
    [switch]$GenerateCoverageReport,

    [Parameter()]
    [string]$OutputPath = "./test-results"
)

# Ensure Pester is installed
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Warning "Pester module not found. Installing..."
    Install-Module -Name Pester -Scope CurrentUser -Force -SkipPublisherCheck
}

# Import Pester
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

$ScriptRoot = Split-Path -Parent $PSCommandPath
$ProjectRoot = Split-Path -Parent $ScriptRoot

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

Write-Host "`n🧪 Claude Code Watchdog - Test Suite" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

# Configuration
$pesterConfig = @{
    Run = @{
        Path = @()
        PassThru = $true
    }
    Output = @{
        Verbosity = 'Detailed'
    }
    TestResult = @{
        Enabled = $true
        OutputPath = Join-Path $OutputPath "test-results.xml"
        OutputFormat = 'NUnitXml'
    }
}

# Add test paths based on type
switch ($TestType) {
    "Unit" {
        $pesterConfig.Run.Path += Join-Path $ScriptRoot "Unit"
        Write-Host "📋 Running Unit Tests..." -ForegroundColor Yellow
    }
    "Integration" {
        $pesterConfig.Run.Path += Join-Path $ScriptRoot "Integration"
        Write-Host "📋 Running Integration Tests..." -ForegroundColor Yellow
    }
    "All" {
        $pesterConfig.Run.Path += Join-Path $ScriptRoot "Unit"
        $pesterConfig.Run.Path += Join-Path $ScriptRoot "Integration"
        Write-Host "📋 Running All Tests (Unit + Integration)..." -ForegroundColor Yellow
    }
}

# Add code coverage if requested
if ($GenerateCoverageReport) {
    Write-Host "📊 Code coverage enabled" -ForegroundColor Cyan

    $pesterConfig.CodeCoverage = @{
        Enabled = $true
        Path = Get-ChildItem -Path (Join-Path $ProjectRoot "src") -Recurse -Filter "*.ps1" | Select-Object -ExpandProperty FullName
        OutputPath = Join-Path $OutputPath "coverage.xml"
        OutputFormat = 'JaCoCo'
    }
}

# Run tests
Write-Host "`nStarting tests..." -ForegroundColor Gray
$startTime = Get-Date

$result = Invoke-Pester -Configuration ([PesterConfiguration]$pesterConfig)

$duration = (Get-Date) - $startTime

# Display results
Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host "`n📊 Test Results Summary" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

Write-Host "`nExecution Time: " -NoNewline -ForegroundColor Gray
Write-Host "$([math]::Round($duration.TotalSeconds, 2))s" -ForegroundColor White

Write-Host "`n📝 Tests:" -ForegroundColor Cyan
Write-Host "  Total:   " -NoNewline -ForegroundColor Gray
Write-Host $result.TotalCount -ForegroundColor White

Write-Host "  Passed:  " -NoNewline -ForegroundColor Gray
Write-Host $result.PassedCount -ForegroundColor Green

Write-Host "  Failed:  " -NoNewline -ForegroundColor Gray
Write-Host $result.FailedCount -ForegroundColor $(if ($result.FailedCount -gt 0) { "Red" } else { "Gray" })

Write-Host "  Skipped: " -NoNewline -ForegroundColor Gray
Write-Host $result.SkippedCount -ForegroundColor Yellow

$passRate = if ($result.TotalCount -gt 0) {
    [math]::Round(($result.PassedCount / $result.TotalCount) * 100, 1)
} else { 0 }

Write-Host "  Pass Rate: " -NoNewline -ForegroundColor Gray
Write-Host "$passRate%" -ForegroundColor $(if ($passRate -eq 100) { "Green" } elseif ($passRate -ge 80) { "Yellow" } else { "Red" })

# Code coverage summary
if ($GenerateCoverageReport -and $result.CodeCoverage) {
    $coverage = $result.CodeCoverage

    Write-Host "`n📈 Code Coverage:" -ForegroundColor Cyan

    $coveredCommands = $coverage.CommandsExecuted
    $totalCommands = $coverage.CommandsAnalyzed
    $coveragePercent = if ($totalCommands -gt 0) {
        [math]::Round(($coveredCommands / $totalCommands) * 100, 1)
    } else { 0 }

    Write-Host "  Commands Analyzed:  " -NoNewline -ForegroundColor Gray
    Write-Host $totalCommands -ForegroundColor White

    Write-Host "  Commands Executed:  " -NoNewline -ForegroundColor Gray
    Write-Host $coveredCommands -ForegroundColor Green

    Write-Host "  Coverage:           " -NoNewline -ForegroundColor Gray
    Write-Host "$coveragePercent%" -ForegroundColor $(if ($coveragePercent -ge 80) { "Green" } elseif ($coveragePercent -ge 60) { "Yellow" } else { "Red" })

    # Files with low coverage
    $lowCoverageFiles = $coverage.CoverageReport | Where-Object {
        $_.CoveragePercent -lt 80
    } | Select-Object -First 5

    if ($lowCoverageFiles) {
        Write-Host "`n  ⚠️  Files with < 80% coverage:" -ForegroundColor Yellow
        foreach ($file in $lowCoverageFiles) {
            $fileName = Split-Path $file.Path -Leaf
            Write-Host "    - $fileName`: $($file.CoveragePercent)%" -ForegroundColor Gray
        }
    }

    Write-Host "`n  Coverage report: " -NoNewline -ForegroundColor Gray
    Write-Host $pesterConfig.CodeCoverage.OutputPath -ForegroundColor White
}

# Output files
Write-Host "`n📄 Output Files:" -ForegroundColor Cyan
Write-Host "  Test Results: " -NoNewline -ForegroundColor Gray
Write-Host $pesterConfig.TestResult.OutputPath -ForegroundColor White

# Failed tests details
if ($result.FailedCount -gt 0) {
    Write-Host "`n❌ Failed Tests:" -ForegroundColor Red

    foreach ($test in $result.Failed) {
        Write-Host "`n  Test: " -NoNewline -ForegroundColor Gray
        Write-Host $test.Name -ForegroundColor Red

        if ($test.ErrorRecord) {
            Write-Host "  Error: " -NoNewline -ForegroundColor Gray
            Write-Host $test.ErrorRecord.Exception.Message -ForegroundColor Red

            if ($test.ErrorRecord.ScriptStackTrace) {
                Write-Host "  Location: " -NoNewline -ForegroundColor Gray
                $location = ($test.ErrorRecord.ScriptStackTrace -split "`n")[0]
                Write-Host $location -ForegroundColor Gray
            }
        }
    }
}

Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor Gray

# Exit code
if ($result.FailedCount -gt 0) {
    Write-Host "`n❌ Tests FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n✅ Tests PASSED" -ForegroundColor Green
    exit 0
}
