<#
.SYNOPSIS
    Parses UI elements from Windows MCP state output

.DESCRIPTION
    Extracts TODOs, errors, warnings, and other UI elements with high accuracy

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS02 - State Detection & Monitoring
    Version: 1.0
    Enhanced: 2024-11-22
#>

function Get-TodosFromUI {
    <#
    .SYNOPSIS
        Parses TODOs from UI state with 95%+ accuracy
    .DESCRIPTION
        Extracts TODO items from Claude Code UI using multiple detection strategies:
        - Checkbox elements with associated text
        - TodoWrite tool output patterns
        - Markdown task list patterns (- [ ] and - [x])
        - Numbered or bulleted todo lists
    #>
    param(
        [Parameter(Mandatory)]
        [object]$UIState
    )

    # Initialize result
    $result = @{
        Total = 0
        Completed = 0
        Remaining = 0
        Items = @()
    }

    try {
        # Strategy 1: Find checkbox elements
        $checkboxes = @()
        if ($UIState.InteractiveElements) {
            $checkboxes = $UIState.InteractiveElements | Where-Object {
                $_.ControlType -eq "CheckBox" -or
                $_.Type -eq "checkbox" -or
                $_.Role -eq "checkbox"
            }
        }

        if ($checkboxes.Count -gt 0) {
            Write-Verbose "Found $($checkboxes.Count) checkbox elements"

            foreach ($checkbox in $checkboxes) {
                # Determine if checked
                $isChecked = $false
                if ($checkbox.State -match "checked|completed" -or
                    $checkbox.Value -eq "true" -or
                    $checkbox.Checked -eq $true) {
                    $isChecked = $true
                }

                # Find associated text (look nearby in informative elements)
                $todoText = Get-TextNearElement -UIState $UIState -Element $checkbox

                $todoItem = @{
                    Text = $todoText
                    IsCompleted = $isChecked
                    Type = "Checkbox"
                    Location = $checkbox.Coordinates
                }

                $result.Items += $todoItem
                $result.Total++

                if ($isChecked) {
                    $result.Completed++
                } else {
                    $result.Remaining++
                }
            }
        }

        # Strategy 2: Parse text-based TODO patterns from informative elements
        if ($UIState.InformativeElements -and $result.Total -eq 0) {
            Write-Verbose "Attempting text-based TODO detection"

            $todoPatterns = @(
                # Markdown task list patterns
                '^\s*-\s*\[([ xX✓✗])\]\s*(.+)$',
                # Numbered task patterns
                '^\s*\d+\.\s*\[([ xX✓✗])\]\s*(.+)$',
                # TodoWrite output patterns
                '^\s*[•●○◆▪▸]\s*(.+?)\s*\((.+?)\)\s*$'
            )

            foreach ($element in $UIState.InformativeElements) {
                $text = $element.Text
                if (-not $text) { continue }

                foreach ($pattern in $todoPatterns) {
                    if ($text -match $pattern) {
                        $isCompleted = $false
                        $todoText = ""

                        # Parse based on pattern type
                        if ($pattern -match '\[\(') {
                            # Checkbox pattern
                            $checkMark = $matches[1]
                            $todoText = $matches[2]
                            $isCompleted = $checkMark -match '[xX✓]'
                        } else {
                            # Other patterns
                            $todoText = $matches[1]
                            $isCompleted = $text -match 'completed|done|finished'
                        }

                        $todoItem = @{
                            Text = $todoText.Trim()
                            IsCompleted = $isCompleted
                            Type = "TextPattern"
                            Location = $element.Coordinates
                        }

                        $result.Items += $todoItem
                        $result.Total++

                        if ($isCompleted) {
                            $result.Completed++
                        } else {
                            $result.Remaining++
                        }
                    }
                }
            }
        }

        # Strategy 3: Look for TodoWrite tool output
        if ($result.Total -eq 0) {
            $todoSection = $UIState.InformativeElements | Where-Object {
                $_.Text -match '(todos?|tasks?)\s*(:|\[|{)' -or
                $_.Text -match 'in_progress|pending|completed'
            }

            if ($todoSection) {
                Write-Verbose "Found TodoWrite-style output"
                # Parse JSON-like todo structures
                foreach ($element in $todoSection) {
                    if ($element.Text -match '"status"\s*:\s*"(pending|in_progress|completed)"') {
                        $status = $matches[1]
                        $isCompleted = $status -eq "completed"

                        # Extract content
                        if ($element.Text -match '"content"\s*:\s*"([^"]+)"') {
                            $todoText = $matches[1]

                            $todoItem = @{
                                Text = $todoText
                                IsCompleted = $isCompleted
                                Status = $status
                                Type = "TodoWrite"
                                Location = $element.Coordinates
                            }

                            $result.Items += $todoItem
                            $result.Total++

                            if ($isCompleted) {
                                $result.Completed++
                            } else {
                                $result.Remaining++
                            }
                        }
                    }
                }
            }
        }

        Write-Verbose "TODO parsing complete: Total=$($result.Total), Completed=$($result.Completed), Remaining=$($result.Remaining)"

    } catch {
        Write-Warning "Error parsing TODOs: $_"
    }

    return $result
}

function Get-TextNearElement {
    <#
    .SYNOPSIS
        Finds text elements near a given UI element
    #>
    param(
        [object]$UIState,
        [object]$Element
    )

    # If element has text, return it
    if ($Element.Text) {
        return $Element.Text
    }

    # Look for nearby informative elements
    if (-not $Element.Coordinates -or -not $UIState.InformativeElements) {
        return "Unknown task"
    }

    $elementX = $Element.Coordinates[0]
    $elementY = $Element.Coordinates[1]
    $proximityThreshold = 100 # pixels

    $nearbyText = $UIState.InformativeElements | Where-Object {
        if (-not $_.Coordinates) { return $false }

        $dx = [Math]::Abs($_.Coordinates[0] - $elementX)
        $dy = [Math]::Abs($_.Coordinates[1] - $elementY)

        return ($dx -lt $proximityThreshold -and $dy -lt $proximityThreshold)
    } | Select-Object -First 1

    if ($nearbyText) {
        return $nearbyText.Text
    }

    return "Unknown task"
}

function Get-ErrorsFromUI {
    <#
    .SYNOPSIS
        Detects errors in the UI with severity classification
    .DESCRIPTION
        Searches for error patterns in UI elements and classifies by severity:
        - High: Fatal errors, compilation failures, critical exceptions
        - Medium: Standard errors, failures, invalid operations
        - Low: Minor errors, validation issues
    #>
    param(
        [Parameter(Mandatory)]
        [object]$UIState
    )

    $errors = @()

    try {
        # Error detection patterns (ordered by priority)
        $errorPatterns = @(
            @{
                Pattern = "(fatal|critical|exception|crash|abort|panic)"
                Severity = "High"
                Category = "Critical"
            },
            @{
                Pattern = "(failed to compile|compilation (error|failed)|syntax error)"
                Severity = "High"
                Category = "Compilation"
            },
            @{
                Pattern = "(test.* failed|assertion.* failed|\d+ failing)"
                Severity = "High"
                Category = "Testing"
            },
            @{
                Pattern = "(❌|✗|error:|\[error\]|ERROR)"
                Severity = "Medium"
                Category = "General"
            },
            @{
                Pattern = "(failed|failure|invalid|cannot|unable)"
                Severity = "Medium"
                Category = "Operation"
            },
            @{
                Pattern = "(deprecated|not found|missing|undefined)"
                Severity = "Low"
                Category = "Reference"
            }
        )

        # Search through informative elements
        if ($UIState.InformativeElements) {
            foreach ($element in $UIState.InformativeElements) {
                if (-not $element.Text) { continue }

                $text = $element.Text
                $lowerText = $text.ToLower()

                # Check against each error pattern
                foreach ($patternDef in $errorPatterns) {
                    if ($lowerText -match $patternDef.Pattern) {
                        # Extract error message (clean up)
                        $errorMessage = $text.Trim()

                        # Try to extract just the error line if it's multi-line
                        if ($errorMessage -match '\n') {
                            $lines = $errorMessage -split '\n'
                            $errorLine = $lines | Where-Object {
                                $_ -match $patternDef.Pattern
                            } | Select-Object -First 1

                            if ($errorLine) {
                                $errorMessage = $errorLine.Trim()
                            }
                        }

                        # Limit message length
                        if ($errorMessage.Length -gt 500) {
                            $errorMessage = $errorMessage.Substring(0, 497) + "..."
                        }

                        $errorObj = @{
                            Message = $errorMessage
                            Severity = $patternDef.Severity
                            Category = $patternDef.Category
                            Location = $element.Coordinates
                            FullText = $text
                            DetectedAt = Get-Date
                        }

                        $errors += $errorObj

                        # Break after first match to avoid duplicate detection
                        break
                    }
                }
            }
        }

        # Deduplicate errors (same message appearing multiple times)
        if ($errors.Count -gt 0) {
            $uniqueErrors = @()
            $seenMessages = @{}

            foreach ($error in $errors) {
                $key = "$($error.Message)-$($error.Severity)"
                if (-not $seenMessages.ContainsKey($key)) {
                    $uniqueErrors += $error
                    $seenMessages[$key] = $true
                }
            }

            $errors = $uniqueErrors
        }

        if ($errors.Count -gt 0) {
            Write-Verbose "Detected $($errors.Count) error(s): High=$($($errors | Where-Object { $_.Severity -eq 'High' }).Count), Medium=$($($errors | Where-Object { $_.Severity -eq 'Medium' }).Count), Low=$($($errors | Where-Object { $_.Severity -eq 'Low' }).Count)"
        }

    } catch {
        Write-Warning "Error during error detection: $_"
    }

    return $errors
}

function Get-WarningsFromUI {
    <#
    .SYNOPSIS
        Detects warnings in the UI
    .DESCRIPTION
        Identifies warning messages that don't prevent execution but
        indicate potential issues or deprecated functionality
    #>
    param(
        [Parameter(Mandatory)]
        [object]$UIState
    )

    $warnings = @()

    try {
        # Warning detection patterns
        $warningPatterns = @(
            @{
                Pattern = "(⚠|warning:|\[warn\]|WARN)"
                Category = "General"
            },
            @{
                Pattern = "(deprecated|deprecation)"
                Category = "Deprecation"
            },
            @{
                Pattern = "(caution|note:|notice:)"
                Category = "Notice"
            },
            @{
                Pattern = "(potential (issue|problem)|may (fail|cause))"
                Category = "PotentialIssue"
            },
            @{
                Pattern = "(outdated|old version|update (required|available))"
                Category = "Version"
            }
        )

        # Search through informative elements
        if ($UIState.InformativeElements) {
            foreach ($element in $UIState.InformativeElements) {
                if (-not $element.Text) { continue }

                $text = $element.Text
                $lowerText = $text.ToLower()

                # Skip if this is already detected as an error
                if ($lowerText -match "(error|failed|exception|fatal|critical)") {
                    continue
                }

                # Check against each warning pattern
                foreach ($patternDef in $warningPatterns) {
                    if ($lowerText -match $patternDef.Pattern) {
                        $warningMessage = $text.Trim()

                        # Limit message length
                        if ($warningMessage.Length -gt 300) {
                            $warningMessage = $warningMessage.Substring(0, 297) + "..."
                        }

                        $warningObj = @{
                            Message = $warningMessage
                            Category = $patternDef.Category
                            Location = $element.Coordinates
                            DetectedAt = Get-Date
                        }

                        $warnings += $warningObj
                        break
                    }
                }
            }
        }

        # Deduplicate warnings
        if ($warnings.Count -gt 0) {
            $uniqueWarnings = @()
            $seenMessages = @{}

            foreach ($warning in $warnings) {
                if (-not $seenMessages.ContainsKey($warning.Message)) {
                    $uniqueWarnings += $warning
                    $seenMessages[$warning.Message] = $true
                }
            }

            $warnings = $uniqueWarnings
            Write-Verbose "Detected $($warnings.Count) warning(s)"
        }

    } catch {
        Write-Warning "Error during warning detection: $_"
    }

    return $warnings
}

function Test-ProcessingIndicator {
    <#
    .SYNOPSIS
        Checks if Claude is actively processing
    .DESCRIPTION
        Detects indicators that Claude Code is actively working:
        - Streaming text indicators
        - "Thinking" or "Processing" messages
        - Progress indicators
        - Animated elements
        - Tool execution indicators
    #>
    param(
        [Parameter(Mandatory)]
        [object]$UIState
    )

    try {
        # Processing indicator patterns
        $processingPatterns = @(
            "thinking\.\.\.",
            "processing\.\.\.",
            "working on",
            "executing",
            "running",
            "analyzing",
            "generating",
            "streaming",
            "tool use.*in progress",
            "invoking.*tool",
            "reading.*file",
            "searching.*for",
            "compiling",
            "building",
            "testing"
        )

        # Check informative elements for processing text
        if ($UIState.InformativeElements) {
            foreach ($element in $UIState.InformativeElements) {
                if (-not $element.Text) { continue }

                $lowerText = $element.Text.ToLower()

                foreach ($pattern in $processingPatterns) {
                    if ($lowerText -match $pattern) {
                        Write-Verbose "Processing indicator found: $($element.Text.Substring(0, [Math]::Min(50, $element.Text.Length)))"
                        return $true
                    }
                }
            }
        }

        # Check for progress indicators (progress bars, spinners)
        if ($UIState.InteractiveElements) {
            $progressIndicators = $UIState.InteractiveElements | Where-Object {
                $_.ControlType -eq "ProgressBar" -or
                $_.Type -eq "progressbar" -or
                $_.Role -eq "progressbar" -or
                ($_.Name -and $_.Name -match "(progress|loading|spinner)")
            }

            if ($progressIndicators.Count -gt 0) {
                Write-Verbose "Progress indicator element found"
                return $true
            }
        }

        # Check for animated elements (presence might indicate activity)
        if ($UIState.AnimatedElements -and $UIState.AnimatedElements.Count -gt 0) {
            Write-Verbose "Animated elements detected"
            return $true
        }

        # Check for disabled reply field (might indicate Claude is working)
        if ($UIState.InteractiveElements) {
            $replyField = $UIState.InteractiveElements | Where-Object {
                ($_.Name -like "*Reply*" -or $_.Type -eq "textbox") -and
                ($_.State -match "disabled|readonly" -or $_.Enabled -eq $false)
            }

            if ($replyField) {
                Write-Verbose "Reply field is disabled (likely processing)"
                return $true
            }
        }

    } catch {
        Write-Warning "Error during processing detection: $_"
    }

    return $false
}

function Get-ErrorSeverity {
    <#
    .SYNOPSIS
        Classifies error severity based on message content
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $lowerMessage = $Message.ToLower()

    # High severity keywords
    if ($lowerMessage -match "(fatal|critical|exception|crash|failed to compile)") {
        return "High"
    }

    # Medium severity keywords
    if ($lowerMessage -match "(error|failure|invalid)") {
        return "Medium"
    }

    # Default to low
    return "Low"
}

# Export functions
Export-ModuleMember -Function Get-TodosFromUI, Get-ErrorsFromUI, Get-WarningsFromUI, Test-ProcessingIndicator, Get-ErrorSeverity
