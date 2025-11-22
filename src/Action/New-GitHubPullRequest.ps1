<#
.SYNOPSIS
    GitHub Pull Request creation for Claude Code Watchdog

.DESCRIPTION
    Automates PR creation using GitHub API with comprehensive metadata

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS04 - Action & Execution
    Work Item: WI-3.5 - GitHub Pull Request Creation
#>

# Import dependencies
$ScriptRoot = Split-Path -Parent $PSCommandPath
. "$ScriptRoot/Invoke-GitOperations.ps1"
. "$ScriptRoot/../Logging/Write-WatchdogLog.ps1"
. "$ScriptRoot/../Utils/Get-SecureAPIKey.ps1"

function New-GitHubPullRequest {
    <#
    .SYNOPSIS
        Creates a GitHub pull request
    .DESCRIPTION
        Creates a PR with generated title and body based on phase completion
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$ProjectConfig,

        [Parameter(Mandatory)]
        [string]$HeadBranch,

        [Parameter()]
        [string]$BaseBranch = "main",

        [Parameter()]
        [string]$Title,

        [Parameter()]
        [string]$Body,

        [Parameter()]
        [hashtable]$PhaseInfo,

        [Parameter()]
        [string]$GitHubToken
    )

    Write-Host "`n📋 Creating GitHub Pull Request..." -ForegroundColor Cyan

    try {
        # Extract repo information from URL
        $repoInfo = Get-RepoInfoFromUrl -RepoUrl $ProjectConfig.repoUrl

        if (-not $repoInfo.Success) {
            throw "Failed to parse repository URL: $($ProjectConfig.repoUrl)"
        }

        # Get GitHub token if not provided
        if (-not $GitHubToken) {
            $GitHubToken = Get-SecureAPIKey -KeyName "GitHubToken" -ErrorAction SilentlyContinue
        }

        if (-not $GitHubToken) {
            throw "GitHub token not found. Set it using Set-SecureAPIKey -KeyName 'GitHubToken' -APIKey 'your-token'"
        }

        # Generate PR title if not provided
        if (-not $Title) {
            $Title = Generate-PRTitle -PhaseInfo $PhaseInfo -ProjectConfig $ProjectConfig
        }

        # Generate PR body if not provided
        if (-not $Body) {
            $Body = Generate-PRBody -PhaseInfo $PhaseInfo -ProjectConfig $ProjectConfig
        }

        Write-Verbose "Creating PR: $HeadBranch -> $BaseBranch"
        Write-Verbose "Title: $Title"

        # Build GitHub API request
        $apiUrl = "https://api.github.com/repos/$($repoInfo.Owner)/$($repoInfo.Repo)/pulls"

        $prData = @{
            title = $Title
            head = $HeadBranch
            base = $BaseBranch
            body = $Body
            draft = $false
        } | ConvertTo-Json

        # Set headers
        $headers = @{
            "Authorization" = "Bearer $GitHubToken"
            "Accept" = "application/vnd.github+json"
            "User-Agent" = "ClaudeCodeWatchdog/1.0"
        }

        # Create PR via GitHub API
        Write-Verbose "Calling GitHub API: $apiUrl"

        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $prData -ContentType "application/json"

        if ($response.html_url) {
            Write-Host "✅ Pull request created successfully!" -ForegroundColor Green
            Write-Host "   URL: $($response.html_url)" -ForegroundColor Cyan
            Write-Host "   Number: #$($response.number)" -ForegroundColor Gray

            Write-WatchdogLog -Message "GitHub PR created: $($response.html_url)" -Level "Info"

            return @{
                Success = $true
                PRNumber = $response.number
                PRURL = $response.html_url
                Title = $response.title
                State = $response.state
                CreatedAt = $response.created_at
            }
        }
        else {
            throw "GitHub API response did not include PR URL"
        }
    }
    catch {
        $errorMessage = $_.Exception.Message

        # Handle common GitHub API errors
        if ($errorMessage -match "401") {
            $errorMessage = "Authentication failed - check GitHub token"
        }
        elseif ($errorMessage -match "422") {
            $errorMessage = "PR creation failed - branch may already have a PR or validation error"
        }
        elseif ($errorMessage -match "404") {
            $errorMessage = "Repository not found - check repository URL and permissions"
        }

        Write-Error "Failed to create GitHub PR: $errorMessage"
        Write-WatchdogLog -Message "GitHub PR creation failed: $errorMessage" -Level "Error"

        return @{
            Success = $false
            Error = $errorMessage
        }
    }
}

function Generate-PRTitle {
    <#
    .SYNOPSIS
        Generates a descriptive PR title
    #>
    param(
        [Parameter()]
        [hashtable]$PhaseInfo,

        [Parameter(Mandatory)]
        [hashtable]$ProjectConfig
    )

    if ($PhaseInfo -and $PhaseInfo.name) {
        return "Complete Phase: $($PhaseInfo.name)"
    }
    else {
        return "Automated update from Claude Code Watchdog"
    }
}

function Generate-PRBody {
    <#
    .SYNOPSIS
        Generates a comprehensive PR body with phase summary
    #>
    param(
        [Parameter()]
        [hashtable]$PhaseInfo,

        [Parameter(Mandatory)]
        [hashtable]$ProjectConfig
    )

    $body = @"
## Summary

This PR completes **$($PhaseInfo.name)** for the $($ProjectConfig.projectName) project.

"@

    # Add phase details if available
    if ($PhaseInfo) {
        $body += @"

### Phase Information

- **Phase**: $($PhaseInfo.name)

"@

        if ($PhaseInfo.description) {
            $body += "- **Description**: $($PhaseInfo.description)`n"
        }

        if ($PhaseInfo.estimatedDuration) {
            $body += "- **Estimated Duration**: $($PhaseInfo.estimatedDuration)`n"
        }

        if ($PhaseInfo.completedTasks) {
            $body += "- **Tasks Completed**: $($PhaseInfo.completedTasks)`n"
        }
    }

    # Add decision log link if available
    if ($ProjectConfig.repoPath) {
        $decisionLogPath = ".claude-automation/decision-log.md"
        $body += @"

### Decision Log

See automated decision-making details in [$decisionLogPath]($decisionLogPath).

"@
    }

    # Add automated notice
    $body += @"

### Testing & Review

- [ ] Code compiles without errors
- [ ] Tests pass
- [ ] No regressions introduced
- [ ] Documentation updated

---

*This pull request was automatically generated by [Claude Code Watchdog](https://github.com/honcoops/ClaudeCodeWatchdog).*
*Generated at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")*
"@

    return $body
}

function Get-RepoInfoFromUrl {
    <#
    .SYNOPSIS
        Extracts owner and repo name from GitHub URL
    #>
    param(
        [Parameter(Mandatory)]
        [string]$RepoUrl
    )

    try {
        # Match patterns like:
        # - github.com/owner/repo
        # - github.com/owner/repo.git
        # - https://github.com/owner/repo
        # - git@github.com:owner/repo.git

        if ($RepoUrl -match 'github\.com[:/]([^/]+)/([^/\.]+)') {
            return @{
                Success = $true
                Owner = $matches[1]
                Repo = $matches[2]
                FullName = "$($matches[1])/$($matches[2])"
            }
        }
        else {
            return @{
                Success = $false
                Error = "Could not parse GitHub URL: $RepoUrl"
            }
        }
    }
    catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Update-PullRequest {
    <#
    .SYNOPSIS
        Updates an existing pull request
    .DESCRIPTION
        Modifies PR title, body, or state
    #>
    param(
        [Parameter(Mandatory)]
        [string]$RepoUrl,

        [Parameter(Mandatory)]
        [int]$PRNumber,

        [Parameter()]
        [string]$Title,

        [Parameter()]
        [string]$Body,

        [Parameter()]
        [ValidateSet("open", "closed")]
        [string]$State,

        [Parameter()]
        [string]$GitHubToken
    )

    try {
        # Extract repo information
        $repoInfo = Get-RepoInfoFromUrl -RepoUrl $RepoUrl

        if (-not $repoInfo.Success) {
            throw "Failed to parse repository URL: $RepoUrl"
        }

        # Get GitHub token
        if (-not $GitHubToken) {
            $GitHubToken = Get-SecureAPIKey -KeyName "GitHubToken" -ErrorAction SilentlyContinue
        }

        if (-not $GitHubToken) {
            throw "GitHub token not found"
        }

        # Build update data
        $updateData = @{}

        if ($Title) { $updateData.title = $Title }
        if ($Body) { $updateData.body = $Body }
        if ($State) { $updateData.state = $State }

        if ($updateData.Count -eq 0) {
            throw "No updates specified"
        }

        # API request
        $apiUrl = "https://api.github.com/repos/$($repoInfo.Owner)/$($repoInfo.Repo)/pulls/$PRNumber"

        $headers = @{
            "Authorization" = "Bearer $GitHubToken"
            "Accept" = "application/vnd.github+json"
            "User-Agent" = "ClaudeCodeWatchdog/1.0"
        }

        $jsonData = $updateData | ConvertTo-Json

        $response = Invoke-RestMethod -Uri $apiUrl -Method Patch -Headers $headers -Body $jsonData -ContentType "application/json"

        Write-Host "✅ Pull request #$PRNumber updated successfully" -ForegroundColor Green

        return @{
            Success = $true
            PRNumber = $response.number
            PRURL = $response.html_url
            State = $response.state
        }
    }
    catch {
        Write-Error "Failed to update PR: $_"

        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-PullRequest {
    <#
    .SYNOPSIS
        Retrieves information about a pull request
    #>
    param(
        [Parameter(Mandatory)]
        [string]$RepoUrl,

        [Parameter(Mandatory)]
        [int]$PRNumber,

        [Parameter()]
        [string]$GitHubToken
    )

    try {
        # Extract repo information
        $repoInfo = Get-RepoInfoFromUrl -RepoUrl $RepoUrl

        if (-not $repoInfo.Success) {
            throw "Failed to parse repository URL: $RepoUrl"
        }

        # Get GitHub token
        if (-not $GitHubToken) {
            $GitHubToken = Get-SecureAPIKey -KeyName "GitHubToken" -ErrorAction SilentlyContinue
        }

        if (-not $GitHubToken) {
            throw "GitHub token not found"
        }

        # API request
        $apiUrl = "https://api.github.com/repos/$($repoInfo.Owner)/$($repoInfo.Repo)/pulls/$PRNumber"

        $headers = @{
            "Authorization" = "Bearer $GitHubToken"
            "Accept" = "application/vnd.github+json"
            "User-Agent" = "ClaudeCodeWatchdog/1.0"
        }

        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers

        return @{
            Success = $true
            PRNumber = $response.number
            PRURL = $response.html_url
            Title = $response.title
            Body = $response.body
            State = $response.state
            HeadBranch = $response.head.ref
            BaseBranch = $response.base.ref
            Mergeable = $response.mergeable
            CreatedAt = $response.created_at
            UpdatedAt = $response.updated_at
        }
    }
    catch {
        Write-Error "Failed to get PR info: $_"

        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Add-PRComment {
    <#
    .SYNOPSIS
        Adds a comment to a pull request
    #>
    param(
        [Parameter(Mandatory)]
        [string]$RepoUrl,

        [Parameter(Mandatory)]
        [int]$PRNumber,

        [Parameter(Mandatory)]
        [string]$Comment,

        [Parameter()]
        [string]$GitHubToken
    )

    try {
        # Extract repo information
        $repoInfo = Get-RepoInfoFromUrl -RepoUrl $RepoUrl

        if (-not $repoInfo.Success) {
            throw "Failed to parse repository URL: $RepoUrl"
        }

        # Get GitHub token
        if (-not $GitHubToken) {
            $GitHubToken = Get-SecureAPIKey -KeyName "GitHubToken" -ErrorAction SilentlyContinue
        }

        if (-not $GitHubToken) {
            throw "GitHub token not found"
        }

        # API request
        $apiUrl = "https://api.github.com/repos/$($repoInfo.Owner)/$($repoInfo.Repo)/issues/$PRNumber/comments"

        $headers = @{
            "Authorization" = "Bearer $GitHubToken"
            "Accept" = "application/vnd.github+json"
            "User-Agent" = "ClaudeCodeWatchdog/1.0"
        }

        $commentData = @{
            body = $Comment
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $commentData -ContentType "application/json"

        Write-Host "✅ Comment added to PR #$PRNumber" -ForegroundColor Green

        return @{
            Success = $true
            CommentId = $response.id
            CommentURL = $response.html_url
        }
    }
    catch {
        Write-Error "Failed to add PR comment: $_"

        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Export functions
Export-ModuleMember -Function New-GitHubPullRequest, Generate-PRTitle, Generate-PRBody,
    Get-RepoInfoFromUrl, Update-PullRequest, Get-PullRequest, Add-PRComment
