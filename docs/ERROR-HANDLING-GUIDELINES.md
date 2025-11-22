# Error Handling Guidelines - Claude Code Watchdog

**Version**: 1.0
**Last Updated**: 2025-11-22
**Owner**: WS07 - Testing & Quality Assurance

---

## Overview

This document defines error handling standards for all Claude Code Watchdog PowerShell modules. Consistent error handling improves reliability, maintainability, and user experience.

---

## Core Principles

1. **Fail Fast**: Detect errors as early as possible
2. **Fail Safe**: Degrade gracefully when possible
3. **Fail Informatively**: Provide actionable error messages
4. **Never Fail Silently**: Always log or report errors
5. **Recover When Possible**: Implement retry and fallback mechanisms

---

## Error Classification

### Transient Errors
Errors that may succeed if retried:
- Network timeouts
- API rate limits
- Temporary file locks
- Resource unavailability

**Strategy**: Retry with exponential backoff

### Permanent Errors
Errors that won't resolve with retry:
- Invalid parameters
- File not found
- Authentication failures
- Configuration errors

**Strategy**: Fail fast and report clearly

### Critical Errors
Errors that compromise system integrity:
- Data corruption
- Security violations
- Unrecoverable state

**Strategy**: Stop execution, alert user, log details

---

## Standard Function Template

```powershell
function Verb-Noun {
    <#
    .SYNOPSIS
        Brief description of what this function does

    .DESCRIPTION
        Detailed description including error handling behavior

    .PARAMETER ParameterName
        Description of parameter

    .EXAMPLE
        Verb-Noun -ParameterName "value"

    .NOTES
        Workstream: WSXX
        Error Handling: Full try-catch with validation
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$RequiredParam,

        [Parameter()]
        [ValidateSet("Option1", "Option2", "Option3")]
        [string]$EnumParam = "Option1",

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$NumericParam = 10,

        [Parameter()]
        [ValidateScript({Test-Path $_})]
        [string]$PathParam
    )

    begin {
        # Validation and initialization
        Write-Verbose "Starting Verb-Noun with $RequiredParam"

        # Additional validation if needed
        if ($PSBoundParameters.ContainsKey('PathParam')) {
            if (-not (Test-Path $PathParam)) {
                $ex = [System.IO.FileNotFoundException]::new("Path not found: $PathParam")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    $ex,
                    'PathNotFound',
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $PathParam
                )
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
        }
    }

    process {
        try {
            # Main logic with error handling
            Write-Verbose "Processing $RequiredParam..."

            # External operation with retry
            $result = Invoke-WithRetry -ScriptBlock {
                # Operation that might fail transiently
                Invoke-ExternalAPI -Param $RequiredParam
            } -MaxRetries 3 -DelaySeconds 2

            # Validate result
            if (-not $result) {
                throw "Operation failed to return valid result"
            }

            return $result
        }
        catch [System.Net.WebException] {
            # Specific exception handling
            Write-Error "Network error in Verb-Noun: $($_.Exception.Message)"
            Write-WatchdogLog -Message "Network error: $_" -Level "Error"
            throw
        }
        catch [System.UnauthorizedAccessException] {
            # Security exception
            Write-Error "Access denied: $($_.Exception.Message)"
            Write-WatchdogLog -Message "Access denied: $_" -Level "Error"
            throw
        }
        catch {
            # Generic exception handling
            Write-Error "Unexpected error in Verb-Noun: $($_.Exception.Message)"
            Write-WatchdogLog -Message "Unexpected error in Verb-Noun: $_" -Level "Error"

            # Include stack trace in verbose mode
            Write-Verbose "Stack trace: $($_.ScriptStackTrace)"

            throw
        }
    }

    end {
        # Cleanup if needed
        Write-Verbose "Verb-Noun completed"
    }
}
```

---

## Parameter Validation

### Required vs Optional

```powershell
# Required parameter
[Parameter(Mandatory)]
[ValidateNotNullOrEmpty()]
[string]$RequiredParam

# Optional with default
[Parameter()]
[string]$OptionalParam = "default"
```

### Validation Attributes

```powershell
# Not null or empty
[ValidateNotNullOrEmpty()]

# Specific values only
[ValidateSet("Value1", "Value2", "Value3")]

# Numeric range
[ValidateRange(1, 100)]

# String length
[ValidateLength(1, 256)]

# Regex pattern
[ValidatePattern('^[A-Z]{3}\d{4}$')]

# Path exists
[ValidateScript({Test-Path $_})]

# Custom validation
[ValidateScript({
    if ($_ -gt 0) { return $true }
    throw "Value must be greater than 0"
})]
```

---

## Try-Catch Best Practices

### Basic Try-Catch

```powershell
try {
    # Code that might throw
    $result = Get-Content $Path
}
catch {
    Write-Error "Failed to read file: $_"
    throw
}
```

### Specific Exception Types

```powershell
try {
    $result = Invoke-RestMethod -Uri $Url
}
catch [System.Net.WebException] {
    # Handle network errors specifically
    if ($_.Exception.Status -eq 'Timeout') {
        Write-Warning "Request timed out. Retrying..."
        # Retry logic
    }
    else {
        throw
    }
}
catch [System.UnauthorizedAccessException] {
    Write-Error "Authentication failed. Check credentials."
    throw
}
catch {
    Write-Error "Unexpected error: $_"
    throw
}
```

### Finally Blocks

```powershell
$connection = $null
try {
    $connection = Open-Connection
    # Use connection
}
catch {
    Write-Error "Connection error: $_"
    throw
}
finally {
    # Always cleanup
    if ($connection) {
        Close-Connection $connection
    }
}
```

---

## Retry Logic

### Simple Retry

```powershell
function Invoke-WithRetry {
    param(
        [ScriptBlock]$ScriptBlock,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 2
    )

    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        try {
            return & $ScriptBlock
        }
        catch {
            $attempt++
            if ($attempt -ge $MaxRetries) {
                throw
            }

            Write-Warning "Attempt $attempt failed: $_. Retrying in $DelaySeconds seconds..."
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}
```

### Exponential Backoff

```powershell
function Invoke-WithExponentialBackoff {
    param(
        [ScriptBlock]$ScriptBlock,
        [int]$MaxRetries = 4,
        [int]$InitialDelaySeconds = 2
    )

    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        try {
            return & $ScriptBlock
        }
        catch {
            $attempt++
            if ($attempt -ge $MaxRetries) {
                throw
            }

            $delay = $InitialDelaySeconds * [Math]::Pow(2, $attempt - 1)
            Write-Warning "Attempt $attempt failed. Retrying in $delay seconds..."
            Start-Sleep -Seconds $delay
        }
    }
}
```

---

## Error Reporting

### Write-Error vs Throw

```powershell
# Write-Error: Non-terminating error (execution continues)
Write-Error "Failed to process item: $_"

# Throw: Terminating error (execution stops)
throw "Critical failure: cannot continue"

# Write-Error with ErrorAction Stop (makes it terminating)
Write-Error "Failed" -ErrorAction Stop
```

### Custom Error Records

```powershell
$ex = [System.ArgumentException]::new("Invalid project name")
$errorRecord = [System.Management.Automation.ErrorRecord]::new(
    $ex,
    'InvalidProjectName',
    [System.Management.Automation.ErrorCategory]::InvalidArgument,
    $ProjectName
)
$PSCmdlet.WriteError($errorRecord)
```

### Error Logging

```powershell
try {
    # Operation
}
catch {
    # Always log errors
    Write-WatchdogLog -Message "Error in operation: $_" -Level "Error"

    # Include context
    Write-WatchdogLog -Message "Context: ProjectName=$ProjectName, SessionId=$SessionId" -Level "Error"

    # Verbose stack trace
    Write-Verbose "Stack trace: $($_.ScriptStackTrace)"

    throw
}
```

---

## Fallback Mechanisms

### Simple Fallback

```powershell
try {
    $result = Get-PrimarySource
}
catch {
    Write-Warning "Primary source failed. Using fallback."
    $result = Get-FallbackSource
}
```

### Multiple Fallbacks

```powershell
$sources = @(
    { Get-PrimarySource },
    { Get-SecondarySource },
    { Get-TertiarySource }
)

$result = $null
foreach ($source in $sources) {
    try {
        $result = & $source
        if ($result) { break }
    }
    catch {
        Write-Warning "Source failed: $_"
        continue
    }
}

if (-not $result) {
    throw "All sources failed"
}
```

---

## Module-Specific Guidelines

### Windows MCP Integration (Invoke-WindowsMCP.ps1)

```powershell
function Invoke-WindowsMCP {
    param(
        [Parameter(Mandatory)]
        [string]$Tool,

        [Parameter()]
        [hashtable]$Parameters
    )

    try {
        # Check if MCP is available
        if (-not (Test-MCPAvailable)) {
            throw "Windows MCP is not available. Ensure it's installed and running."
        }

        # Call with retry (MCP can be temporarily busy)
        $result = Invoke-WithRetry -ScriptBlock {
            # Actual MCP call
            & mcp-client $Tool @Parameters
        } -MaxRetries 3 -DelaySeconds 1

        return $result
    }
    catch {
        Write-Error "Windows MCP operation failed: $_"
        Write-WatchdogLog -Message "MCP error: Tool=$Tool, Error=$_" -Level "Error"
        throw
    }
}
```

### API Calls (Invoke-ClaudeDecision.ps1)

```powershell
function Invoke-ClaudeAPI {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt
    )

    try {
        # Check rate limits before calling
        if (-not (Test-APIRateLimit)) {
            throw "API rate limit exceeded. Please wait."
        }

        # Call with timeout
        $result = Invoke-RestMethod -Uri $ApiUrl `
            -Method Post `
            -Body $Body `
            -TimeoutSec 30 `
            -ErrorAction Stop

        return $result
    }
    catch [System.Net.WebException] {
        # Network or HTTP errors
        $statusCode = $_.Exception.Response.StatusCode.value__

        switch ($statusCode) {
            429 {
                Write-Warning "Rate limited. Using fallback decision."
                return Invoke-FallbackDecision
            }
            401 {
                throw "Authentication failed. Check API key."
            }
            default {
                Write-Warning "API call failed (HTTP $statusCode). Using fallback."
                return Invoke-FallbackDecision
            }
        }
    }
    catch {
        Write-Error "Unexpected API error: $_"
        Write-WatchdogLog -Message "API error: $_" -Level "Error"
        return Invoke-FallbackDecision
    }
}
```

### File I/O

```powershell
function Save-ProjectState {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [hashtable]$State
    )

    try {
        # Ensure directory exists
        $dir = Split-Path $Path
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        # Atomic write (temp file + rename)
        $tempPath = "$Path.tmp"

        try {
            $State | ConvertTo-Json -Depth 10 | Set-Content $tempPath -Force

            # Validate JSON before committing
            $null = Get-Content $tempPath | ConvertFrom-Json

            # Atomic rename
            Move-Item $tempPath $Path -Force
        }
        finally {
            # Cleanup temp file if it exists
            if (Test-Path $tempPath) {
                Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        Write-Error "Failed to save project state: $_"
        Write-WatchdogLog -Message "State save error: Path=$Path, Error=$_" -Level "Error"
        throw
    }
}
```

---

## Testing Error Handling

### Unit Test Example

```powershell
Describe "Verb-Noun Error Handling" {
    Context "When parameter is invalid" {
        It "Should throw for null parameter" {
            { Verb-Noun -RequiredParam $null } | Should -Throw
        }

        It "Should throw for empty parameter" {
            { Verb-Noun -RequiredParam "" } | Should -Throw
        }
    }

    Context "When external service fails" {
        It "Should retry on transient error" {
            Mock Invoke-ExternalAPI { throw "Timeout" } -Verifiable

            { Verb-Noun -RequiredParam "test" } | Should -Not -Throw

            Assert-MockCalled Invoke-ExternalAPI -Times 3
        }

        It "Should use fallback on permanent error" {
            Mock Invoke-ExternalAPI { throw "Not found" }
            Mock Invoke-Fallback { return "fallback result" } -Verifiable

            $result = Verb-Noun -RequiredParam "test"

            $result | Should -Be "fallback result"
            Assert-MockCalled Invoke-Fallback -Times 1
        }
    }

    Context "When errors are logged" {
        It "Should log errors with Write-WatchdogLog" {
            Mock Write-WatchdogLog -Verifiable
            Mock Invoke-ExternalAPI { throw "Error" }

            { Verb-Noun -RequiredParam "test" } | Should -Throw

            Assert-MockCalled Write-WatchdogLog -Times 1
        }
    }
}
```

---

## Checklist for New Functions

Before committing a new function, verify:

- [ ] Has [CmdletBinding()] attribute
- [ ] All mandatory parameters have [Parameter(Mandatory)]
- [ ] Parameters have appropriate validation attributes
- [ ] Main logic wrapped in try-catch
- [ ] Specific exception types caught where possible
- [ ] Errors logged with Write-WatchdogLog
- [ ] User-friendly error messages
- [ ] Retry logic for transient failures
- [ ] Fallback mechanisms where appropriate
- [ ] Cleanup in finally block (if needed)
- [ ] Unit tests for error scenarios
- [ ] Documentation includes error behavior

---

## Common Mistakes to Avoid

### ❌ Don't: Silent Failures

```powershell
# BAD - error is ignored
try {
    Do-Something
}
catch {
    # Nothing - error is lost!
}
```

### ✅ Do: Log and/or Rethrow

```powershell
# GOOD - error is logged and propagated
try {
    Do-Something
}
catch {
    Write-WatchdogLog -Message "Error: $_" -Level "Error"
    throw
}
```

### ❌ Don't: Generic Error Messages

```powershell
# BAD - no context
throw "Operation failed"
```

### ✅ Do: Specific Error Messages

```powershell
# GOOD - clear and actionable
throw "Failed to read project config from $ConfigPath. Ensure file exists and is valid JSON."
```

### ❌ Don't: Catch Everything

```powershell
# BAD - catches all errors including ones we shouldn't handle
try {
    Critical-Operation
}
catch {
    # Try to continue anyway
}
```

### ✅ Do: Catch Specific Errors

```powershell
# GOOD - only handle errors we know how to recover from
try {
    Critical-Operation
}
catch [System.IO.FileNotFoundException] {
    # Handle missing file
    Create-DefaultFile
}
# Let other errors propagate
```

---

## References

- [PowerShell Error Handling Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-exceptions)
- [about_Try_Catch_Finally](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_try_catch_finally)
- [about_Parameter_Sets](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters)

---

**Document Version**: 1.0
**Last Review**: 2025-11-22
**Next Review**: 2025-12-22
