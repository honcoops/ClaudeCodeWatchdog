<#
.SYNOPSIS
    Installation script for Claude Code Watchdog

.DESCRIPTION
    Sets up the Claude Code Watchdog on a Windows system:
    - Checks prerequisites
    - Creates necessary directories
    - Installs required PowerShell modules
    - Creates default configuration
    - Optionally sets up scheduled task

.EXAMPLE
    .\Install-Watchdog.ps1

.EXAMPLE
    .\Install-Watchdog.ps1 -SkipScheduledTask

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS01 - Core Infrastructure
    Work Item: WI-1.9
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$SkipScheduledTask,

    [Parameter()]
    [switch]$Force
)

Write-Host @"

╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║         Claude Code Watchdog - Installation Wizard       ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Step 1: Check Prerequisites
Write-Host "`n📋 Step 1: Checking Prerequisites..." -ForegroundColor Cyan

function Test-Prerequisites {
    $errors = @()
    $warnings = @()

    # Check OS
    if (-not $IsWindows -and -not $env:OS -like "*Windows*") {
        $errors += "This tool requires Windows 10/11"
    }
    else {
        Write-Host "  ✅ Operating System: Windows" -ForegroundColor Green
    }

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $warnings += "PowerShell 7.0+ recommended (current: $($PSVersionTable.PSVersion))"
        Write-Host "  ⚠️  PowerShell Version: $($PSVersionTable.PSVersion) (7.0+ recommended)" -ForegroundColor Yellow
    }
    else {
        Write-Host "  ✅ PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Green
    }

    # Check for Git
    try {
        $gitVersion = git --version 2>$null
        Write-Host "  ✅ Git: $gitVersion" -ForegroundColor Green
    }
    catch {
        $warnings += "Git not found. Required for repository operations."
        Write-Host "  ⚠️  Git: Not installed" -ForegroundColor Yellow
    }

    # Check for required modules
    $requiredModules = @()  # BurntToast will be added later

    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            $warnings += "PowerShell module '$module' not installed (will attempt to install)"
            Write-Host "  ⚠️  Module $module : Not installed" -ForegroundColor Yellow
        }
        else {
            Write-Host "  ✅ Module $module : Installed" -ForegroundColor Green
        }
    }

    # Check for Windows MCP
    # TODO: Add actual Windows MCP check when available
    Write-Host "  ℹ️  Windows MCP: Not validated (ensure it's installed separately)" -ForegroundColor Gray

    return @{
        Errors = $errors
        Warnings = $warnings
    }
}

$prereqResults = Test-Prerequisites

if ($prereqResults.Errors.Count -gt 0) {
    Write-Host "`n❌ Prerequisites check failed:" -ForegroundColor Red
    foreach ($error in $prereqResults.Errors) {
        Write-Host "   - $error" -ForegroundColor Red
    }

    if (-not $Force) {
        Write-Host "`nUse -Force to continue anyway (not recommended)" -ForegroundColor Yellow
        exit 1
    }
}

if ($prereqResults.Warnings.Count -gt 0) {
    Write-Host "`n⚠️  Warnings:" -ForegroundColor Yellow
    foreach ($warning in $prereqResults.Warnings) {
        Write-Host "   - $warning" -ForegroundColor Yellow
    }
}

# Step 2: Create Directory Structure
Write-Host "`n📁 Step 2: Creating Directory Structure..." -ForegroundColor Cyan

$directories = @(
    "$HOME/.claude-automation",
    "$HOME/.claude-automation/logs",
    "$HOME/.claude-automation/state",
    "$HOME/.claude-automation/cache"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  ✅ Created: $dir" -ForegroundColor Green
    }
    else {
        Write-Host "  ℹ️  Already exists: $dir" -ForegroundColor Gray
    }
}

# Step 3: Install Required Modules
Write-Host "`n📦 Step 3: Installing Required PowerShell Modules..." -ForegroundColor Cyan

function Install-RequiredModules {
    # BurntToast for notifications (optional)
    if (-not (Get-Module -ListAvailable -Name BurntToast)) {
        Write-Host "  ⏳ Installing BurntToast module..." -ForegroundColor Gray
        try {
            Install-Module -Name BurntToast -Scope CurrentUser -Force -AllowClobber
            Write-Host "  ✅ Installed: BurntToast" -ForegroundColor Green
        }
        catch {
            Write-Host "  ⚠️  Failed to install BurntToast: $_" -ForegroundColor Yellow
            Write-Host "     Notifications will be disabled" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  ✅ BurntToast already installed" -ForegroundColor Green
    }
}

Install-RequiredModules

# Step 4: Create Default Configuration
Write-Host "`n⚙️  Step 4: Creating Default Configuration..." -ForegroundColor Cyan

$configPath = "$HOME/.claude-automation/watchdog-config.json"

if (Test-Path $configPath) {
    if ($Force) {
        Write-Host "  ⚠️  Overwriting existing configuration (Force mode)" -ForegroundColor Yellow
    }
    else {
        Write-Host "  ℹ️  Configuration already exists, skipping" -ForegroundColor Gray
        Write-Host "     Use -Force to overwrite" -ForegroundColor Gray
        $skipConfig = $true
    }
}

if (-not $skipConfig) {
    $defaultConfig = @{
        version = "1.0"
        polling = @{
            intervalSeconds = 120
            maxConcurrentProjects = 10
        }
        logging = @{
            level = "Info"
            maxLogAgeDays = 7
            maxLogSizeMB = 10
        }
        notifications = @{
            enabled = $true
            maxPerHour = 10
        }
        api = @{
            enabled = $false
            model = "claude-3-5-sonnet-20241022"
            maxTokens = 1000
            temperature = 0.7
            dailyCostLimit = 10.0
            weeklyCostLimit = 50.0
        }
        windowsMCP = @{
            maxRetries = 3
            retryDelaySeconds = 2
            visionMode = $false
        }
    }

    $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content $configPath -Force
    Write-Host "  ✅ Created default configuration at $configPath" -ForegroundColor Green
}

# Step 5: Create Registry File
Write-Host "`n📝 Step 5: Initializing Project Registry..." -ForegroundColor Cyan

$registryPath = "$HOME/.claude-automation/registry.json"

if (-not (Test-Path $registryPath)) {
    $registry = @{
        version = "1.0"
        lastUpdated = Get-Date -Format "o"
        projects = @{}
    }

    $registry | ConvertTo-Json -Depth 10 | Set-Content $registryPath -Force
    Write-Host "  ✅ Created project registry at $registryPath" -ForegroundColor Green
}
else {
    Write-Host "  ℹ️  Registry already exists, skipping" -ForegroundColor Gray
}

# Step 6: Create Scheduled Task (Optional)
if (-not $SkipScheduledTask) {
    Write-Host "`n⏰ Step 6: Setting up Scheduled Task (Optional)..." -ForegroundColor Cyan
    Write-Host "  ℹ️  Scheduled task creation skipped in this version" -ForegroundColor Gray
    Write-Host "     You can manually start the watchdog using: .\src\Core\Start-Watchdog.ps1" -ForegroundColor Gray
}
else {
    Write-Host "`n⏰ Step 6: Scheduled Task - Skipped" -ForegroundColor Gray
}

# Step 7: Validation
Write-Host "`n✅ Step 7: Validating Installation..." -ForegroundColor Cyan

$validationErrors = @()

# Check all directories exist
foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        $validationErrors += "Directory not found: $dir"
    }
}

# Check configuration exists
if (-not (Test-Path $configPath)) {
    $validationErrors += "Configuration file not found: $configPath"
}

# Check registry exists
if (-not (Test-Path $registryPath)) {
    $validationErrors += "Registry file not found: $registryPath"
}

if ($validationErrors.Count -gt 0) {
    Write-Host "`n❌ Validation failed:" -ForegroundColor Red
    foreach ($error in $validationErrors) {
        Write-Host "   - $error" -ForegroundColor Red
    }
    exit 1
}

Write-Host "  ✅ All components validated" -ForegroundColor Green

# Final Summary
Write-Host @"

╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              Installation Complete! ✅                    ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

📚 Next Steps:

1. Set your Claude API key (optional, for AI-powered decisions):
   .\Set-WatchdogAPIKey.ps1 -APIKey "your-api-key-here"

2. Register your first project:
   .\src\Registry\Register-Project.ps1 -ProjectName "my-project" -ConfigPath "C:\path\to\project-config.json"

3. Start the watchdog:
   .\src\Core\Start-Watchdog.ps1

📖 Documentation:
   - README.md - Project overview
   - ARCHITECTURE.md - Technical architecture
   - REQUIREMENTS.md - Detailed requirements
   - IMPLEMENTATION-GUIDE.md - Development guide

🐛 Issues or Questions:
   https://github.com/yourusername/claude-code-watchdog/issues

"@ -ForegroundColor Cyan

Write-Host "Happy watching! 🤖🔍`n" -ForegroundColor Green
