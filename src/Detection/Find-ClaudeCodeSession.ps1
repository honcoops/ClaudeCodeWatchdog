<#
.SYNOPSIS
    Finds Claude Code sessions in browser windows

.DESCRIPTION
    Locates active Claude Code sessions using Windows MCP with intelligent
    session-to-project matching based on multiple criteria

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS02 - State Detection & Monitoring
    Version: 1.0
    Enhanced: 2024-11-22
#>

# Import dependencies
$ScriptRoot = Split-Path -Parent $PSCommandPath
. "$ScriptRoot/../Utils/Invoke-WindowsMCP.ps1"

function Find-ClaudeCodeSession {
    <#
    .SYNOPSIS
        Finds all open Claude Code sessions
    .DESCRIPTION
        Enumerates browser windows to locate Claude Code sessions:
        - Searches for Chrome/Edge windows
        - Identifies Claude Code tabs by title pattern
        - Extracts session IDs from URLs
        - Optionally filters by project name
    #>
    param(
        [Parameter()]
        [string]$ProjectName,

        [Parameter()]
        [switch]$AllSessions
    )

    Write-Verbose "Searching for Claude Code sessions$(if ($ProjectName) { " for project: $ProjectName" })..."

    $sessions = @()

    try {
        # Use Windows MCP to get window information
        # This would be implemented via the Windows MCP State tool
        # For now, we'll define the structure

        # Get all browser windows
        $browserWindows = Get-BrowserWindows

        if (-not $browserWindows -or $browserWindows.Count -eq 0) {
            Write-Verbose "No browser windows found"
            return $sessions
        }

        # Claude Code window title patterns
        $claudeCodePatterns = @(
            "*Claude Code*",
            "*code.anthropic.com*",
            "*claude.ai/chat*"
        )

        foreach ($window in $browserWindows) {
            $title = $window.Title

            # Check if this is a Claude Code window
            $isClaudeCode = $false
            foreach ($pattern in $claudeCodePatterns) {
                if ($title -like $pattern) {
                    $isClaudeCode = $true
                    break
                }
            }

            if (-not $isClaudeCode) {
                continue
            }

            Write-Verbose "Found Claude Code window: $title"

            # Extract session ID from title or URL
            $sessionId = $null
            if ($title -match '[0-9A-Z]{26}') {
                $sessionId = $matches[0]
            } elseif ($window.URL -match '[0-9A-Z]{26}') {
                $sessionId = $matches[0]
            }

            # Create session object
            $session = @{
                WindowHandle = $window.Handle
                WindowTitle = $title
                SessionId = $sessionId
                URL = $window.URL
                ProcessId = $window.ProcessId
                ProcessName = $window.ProcessName
                IsActive = $window.IsActive
                DetectedAt = Get-Date
            }

            # If filtering by project, try to match
            if ($ProjectName) {
                $matchScore = Get-SessionProjectMatchScore -Session $session -ProjectName $ProjectName
                if ($matchScore -gt 0) {
                    $session.MatchScore = $matchScore
                    $sessions += $session
                }
            } else {
                $sessions += $session
            }
        }

        if ($sessions.Count -gt 0) {
            Write-Verbose "Found $($sessions.Count) Claude Code session(s)"

            # Sort by match score if filtering by project
            if ($ProjectName) {
                $sessions = $sessions | Sort-Object -Property MatchScore -Descending
            }
        } else {
            Write-Verbose "No Claude Code sessions found"
        }

        return $sessions

    }
    catch {
        Write-Error "Failed to find Claude Code sessions: $_"
        return @()
    }
}

function Get-BrowserWindows {
    <#
    .SYNOPSIS
        Enumerates all browser windows using Windows MCP
    #>

    try {
        # This would use Windows MCP to enumerate windows
        # For now, we'll call the MCP wrapper with a placeholder

        # In a real implementation, this would:
        # 1. Call Windows-MCP to get all windows
        # 2. Filter for Chrome/Edge processes
        # 3. Extract window titles and URLs

        $windows = @()

        # Attempt to get window list via Windows MCP
        # This is a placeholder for the actual MCP call
        Write-Verbose "Enumerating browser windows (requires Windows MCP)"

        # In production, this would be:
        # $mcpResult = Invoke-WindowsMCPGetWindows
        # $windows = Parse-WindowsFromMCP -MCPResult $mcpResult

        return $windows

    } catch {
        Write-Warning "Error enumerating browser windows: $_"
        return @()
    }
}

function Get-SessionProjectMatchScore {
    <#
    .SYNOPSIS
        Calculates how well a session matches a project
    .DESCRIPTION
        Returns a score (0-100) indicating match confidence:
        - 100: Perfect match (session ID in project state)
        - 75: Strong match (repo name in window title)
        - 50: Medium match (project name in window title)
        - 25: Weak match (related keywords)
        - 0: No match
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Session,

        [Parameter(Mandatory)]
        [string]$ProjectName
    )

    $score = 0

    try {
        # Load project configuration
        $ScriptRoot = Split-Path -Parent $PSCommandPath
        . "$ScriptRoot/../Registry/Get-RegisteredProjects.ps1"

        $projects = Get-RegisteredProjects
        if (-not $projects.ContainsKey($ProjectName)) {
            return 0
        }

        $projectInfo = $projects[$ProjectName]

        # Perfect match: Session ID matches project's tracked session
        if ($projectInfo.sessionId -and $Session.SessionId -eq $projectInfo.sessionId) {
            return 100
        }

        # Load project config for more details
        if ($projectInfo.configPath -and (Test-Path $projectInfo.configPath)) {
            $config = Get-Content $projectInfo.configPath | ConvertFrom-Json

            # Strong match: Repo URL or name in window title
            if ($config.repoUrl -and $Session.WindowTitle -like "*$($config.repoUrl)*") {
                $score = [Math]::Max($score, 75)
            }

            # Extract repo name from path or URL
            if ($config.repoPath) {
                $repoName = Split-Path -Leaf $config.repoPath
                if ($Session.WindowTitle -like "*$repoName*") {
                    $score = [Math]::Max($score, 75)
                }
            }
        }

        # Medium match: Project name in window title
        if ($Session.WindowTitle -like "*$ProjectName*") {
            $score = [Math]::Max($score, 50)
        }

        # Weak match: Window title contains programming-related keywords
        $keywords = @("code", "development", "project", "repository")
        foreach ($keyword in $keywords) {
            if ($Session.WindowTitle.ToLower() -like "*$keyword*") {
                $score = [Math]::Max($score, 25)
                break
            }
        }

    } catch {
        Write-Warning "Error calculating match score: $_"
    }

    return $score
}

function Get-SessionWindowTitle {
    <#
    .SYNOPSIS
        Gets the window title for a session by ID
    .DESCRIPTION
        Looks up the window title for a specific session ID
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SessionId
    )

    try {
        # Find all Claude Code sessions
        $sessions = Find-ClaudeCodeSession -AllSessions

        # Find the session with matching ID
        $matchingSession = $sessions | Where-Object { $_.SessionId -eq $SessionId } | Select-Object -First 1

        if ($matchingSession) {
            return $matchingSession.WindowTitle
        }

        Write-Verbose "No window found for session ID: $SessionId"
        return "Claude Code (Session: $SessionId)"

    } catch {
        Write-Warning "Error getting session window title: $_"
        return "Claude Code"
    }
}

function Match-SessionToProject {
    <#
    .SYNOPSIS
        Matches a session to a registered project
    .DESCRIPTION
        Attempts to match a Claude Code session to a registered project
        based on multiple criteria, returning the best match
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Session,

        [Parameter(Mandatory)]
        [hashtable]$RegisteredProjects
    )

    try {
        if ($RegisteredProjects.Count -eq 0) {
            Write-Verbose "No registered projects to match against"
            return $null
        }

        $bestMatch = $null
        $bestScore = 0

        foreach ($projectName in $RegisteredProjects.Keys) {
            $score = Get-SessionProjectMatchScore -Session $Session -ProjectName $projectName

            if ($score -gt $bestScore) {
                $bestScore = $score
                $bestMatch = @{
                    ProjectName = $projectName
                    MatchScore = $score
                    ProjectInfo = $RegisteredProjects[$projectName]
                }
            }
        }

        # Only return matches with score >= 50 (medium confidence or higher)
        if ($bestScore -ge 50) {
            Write-Verbose "Session matched to project '$($bestMatch.ProjectName)' with score $bestScore"
            return $bestMatch
        }

        Write-Verbose "No confident match found (best score: $bestScore)"
        return $null

    } catch {
        Write-Warning "Error matching session to project: $_"
        return $null
    }
}

# Export functions
Export-ModuleMember -Function Find-ClaudeCodeSession, Get-SessionWindowTitle, Match-SessionToProject
