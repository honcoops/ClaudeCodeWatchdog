<#
.SYNOPSIS
    Git operations wrapper for Claude Code Watchdog

.DESCRIPTION
    Provides functions for Git branch creation, commits, pushes, and status checks

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS04 - Action & Execution
    Work Item: WI-3.3 - Git Integration Module
#>

# Import dependencies
$ScriptRoot = Split-Path -Parent $PSCommandPath
. "$ScriptRoot/../Logging/Write-WatchdogLog.ps1"

function Invoke-GitBranch {
    <#
    .SYNOPSIS
        Creates or switches to a Git branch
    .DESCRIPTION
        Creates a new branch or switches to an existing one with error handling
    #>
    param(
        [Parameter(Mandatory)]
        [string]$BranchName,

        [Parameter(Mandatory)]
        [string]$RepoPath,

        [Parameter()]
        [switch]$CreateNew,

        [Parameter()]
        [string]$BaseBranch = "main"
    )

    Write-Verbose "Git branch operation: $BranchName in $RepoPath"

    try {
        # Validate repository path
        if (-not (Test-Path $RepoPath)) {
            throw "Repository path does not exist: $RepoPath"
        }

        # Change to repository directory
        Push-Location $RepoPath

        try {
            # Check if we're in a Git repository
            $gitRoot = git rev-parse --show-toplevel 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Not a Git repository: $RepoPath"
            }

            # Check if branch exists
            $branchExists = git rev-parse --verify $BranchName 2>&1
            $exists = $LASTEXITCODE -eq 0

            if ($CreateNew) {
                if ($exists) {
                    Write-Warning "Branch '$BranchName' already exists, switching to it"
                    git checkout $BranchName 2>&1 | Out-Null

                    if ($LASTEXITCODE -ne 0) {
                        throw "Failed to checkout existing branch: $BranchName"
                    }
                }
                else {
                    Write-Verbose "Creating new branch: $BranchName from $BaseBranch"

                    # Ensure we're on the base branch first
                    git checkout $BaseBranch 2>&1 | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "Could not checkout base branch '$BaseBranch', using current branch"
                    }

                    # Create and checkout new branch
                    git checkout -b $BranchName 2>&1 | Out-Null

                    if ($LASTEXITCODE -ne 0) {
                        throw "Failed to create branch: $BranchName"
                    }

                    Write-Host "✅ Created and switched to branch: $BranchName" -ForegroundColor Green
                }
            }
            else {
                # Just switch to existing branch
                if (-not $exists) {
                    throw "Branch does not exist: $BranchName (use -CreateNew to create it)"
                }

                git checkout $BranchName 2>&1 | Out-Null

                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to checkout branch: $BranchName"
                }

                Write-Host "✅ Switched to branch: $BranchName" -ForegroundColor Green
            }

            # Verify current branch
            $currentBranch = git rev-parse --abbrev-ref HEAD
            if ($currentBranch -ne $BranchName) {
                throw "Branch verification failed: expected '$BranchName', got '$currentBranch'"
            }

            Write-WatchdogLog -Message "Git branch operation successful: $BranchName" -Level "Info"

            return @{
                Success = $true
                Branch = $BranchName
                Created = (-not $exists)
                CurrentBranch = $currentBranch
            }
        }
        finally {
            Pop-Location
        }
    }
    catch {
        Write-Error "Git branch operation failed: $_"
        Write-WatchdogLog -Message "Git branch operation failed: $_" -Level "Error"

        return @{
            Success = $false
            Branch = $BranchName
            Error = $_.Exception.Message
        }
    }
}

function Invoke-GitCommit {
    <#
    .SYNOPSIS
        Creates a Git commit with the specified message
    .DESCRIPTION
        Stages changes and creates a commit with proper error handling
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [string]$RepoPath,

        [Parameter()]
        [string[]]$Files = @("."),

        [Parameter()]
        [switch]$AllowEmpty
    )

    Write-Verbose "Creating Git commit in $RepoPath"

    try {
        # Validate repository path
        if (-not (Test-Path $RepoPath)) {
            throw "Repository path does not exist: $RepoPath"
        }

        Push-Location $RepoPath

        try {
            # Check if we're in a Git repository
            $gitRoot = git rev-parse --show-toplevel 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Not a Git repository: $RepoPath"
            }

            # Stage files
            Write-Verbose "Staging files: $($Files -join ', ')"

            foreach ($file in $Files) {
                git add $file 2>&1 | Out-Null

                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to stage files: $file"
                }
            }

            # Check if there are changes to commit
            $statusOutput = git status --porcelain
            $hasChanges = $statusOutput.Count -gt 0

            if (-not $hasChanges -and -not $AllowEmpty) {
                Write-Warning "No changes to commit"
                return @{
                    Success = $true
                    Committed = $false
                    Message = "No changes to commit"
                    CommitHash = $null
                }
            }

            # Create commit
            Write-Verbose "Creating commit with message: $Message"

            $commitArgs = @("-m", $Message)
            if ($AllowEmpty) {
                $commitArgs += "--allow-empty"
            }

            git commit @commitArgs 2>&1 | Out-Null

            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create commit"
            }

            # Get commit hash
            $commitHash = git rev-parse HEAD

            Write-Host "✅ Created commit: $commitHash" -ForegroundColor Green
            Write-Host "   Message: $Message" -ForegroundColor Gray

            Write-WatchdogLog -Message "Git commit created: $commitHash - $Message" -Level "Info"

            return @{
                Success = $true
                Committed = $true
                Message = $Message
                CommitHash = $commitHash
                Timestamp = Get-Date
            }
        }
        finally {
            Pop-Location
        }
    }
    catch {
        Write-Error "Git commit failed: $_"
        Write-WatchdogLog -Message "Git commit failed: $_" -Level "Error"

        return @{
            Success = $false
            Committed = $false
            Error = $_.Exception.Message
        }
    }
}

function Invoke-GitPush {
    <#
    .SYNOPSIS
        Pushes commits to remote repository
    .DESCRIPTION
        Pushes current branch to remote with retry logic and error handling
    #>
    param(
        [Parameter(Mandatory)]
        [string]$RepoPath,

        [Parameter()]
        [string]$Remote = "origin",

        [Parameter()]
        [string]$Branch,

        [Parameter()]
        [switch]$SetUpstream,

        [Parameter()]
        [int]$MaxRetries = 4,

        [Parameter()]
        [switch]$Force
    )

    Write-Verbose "Pushing to remote: $Remote"

    try {
        # Validate repository path
        if (-not (Test-Path $RepoPath)) {
            throw "Repository path does not exist: $RepoPath"
        }

        Push-Location $RepoPath

        try {
            # Get current branch if not specified
            if (-not $Branch) {
                $Branch = git rev-parse --abbrev-ref HEAD
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to determine current branch"
                }
            }

            Write-Verbose "Pushing branch '$Branch' to remote '$Remote'"

            # Build push command
            $pushArgs = @($Remote, $Branch)

            if ($SetUpstream) {
                $pushArgs = @("-u", $Remote, $Branch)
            }

            if ($Force) {
                $pushArgs += "--force"
                Write-Warning "Using force push - this will overwrite remote history"
            }

            # Retry logic with exponential backoff
            $attempt = 0
            $success = $false
            $retryDelay = 2

            while ($attempt -lt $MaxRetries -and -not $success) {
                $attempt++
                Write-Verbose "Push attempt $attempt of $MaxRetries"

                try {
                    git push @pushArgs 2>&1 | Out-Null

                    if ($LASTEXITCODE -eq 0) {
                        $success = $true
                        Write-Host "✅ Successfully pushed to $Remote/$Branch" -ForegroundColor Green
                    }
                    else {
                        if ($attempt -lt $MaxRetries) {
                            Write-Warning "Push failed, retrying in $retryDelay seconds..."
                            Start-Sleep -Seconds $retryDelay
                            $retryDelay *= 2
                        }
                    }
                }
                catch {
                    if ($attempt -lt $MaxRetries) {
                        Write-Warning "Push error: $_, retrying in $retryDelay seconds..."
                        Start-Sleep -Seconds $retryDelay
                        $retryDelay *= 2
                    }
                    else {
                        throw
                    }
                }
            }

            if (-not $success) {
                throw "Failed to push after $MaxRetries attempts"
            }

            Write-WatchdogLog -Message "Git push successful: $Remote/$Branch" -Level "Info"

            return @{
                Success = $true
                Remote = $Remote
                Branch = $Branch
                Attempts = $attempt
                Timestamp = Get-Date
            }
        }
        finally {
            Pop-Location
        }
    }
    catch {
        Write-Error "Git push failed: $_"
        Write-WatchdogLog -Message "Git push failed: $_" -Level "Error"

        return @{
            Success = $false
            Remote = $Remote
            Branch = $Branch
            Error = $_.Exception.Message
        }
    }
}

function Get-GitStatus {
    <#
    .SYNOPSIS
        Gets the current Git repository status
    .DESCRIPTION
        Returns detailed status information about the repository
    #>
    param(
        [Parameter(Mandatory)]
        [string]$RepoPath
    )

    try {
        if (-not (Test-Path $RepoPath)) {
            throw "Repository path does not exist: $RepoPath"
        }

        Push-Location $RepoPath

        try {
            # Get current branch
            $currentBranch = git rev-parse --abbrev-ref HEAD 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Not a Git repository or failed to get current branch"
            }

            # Get status
            $statusOutput = git status --porcelain

            # Count changes
            $modified = ($statusOutput | Where-Object { $_ -match '^\s*M' }).Count
            $added = ($statusOutput | Where-Object { $_ -match '^\s*A' }).Count
            $deleted = ($statusOutput | Where-Object { $_ -match '^\s*D' }).Count
            $untracked = ($statusOutput | Where-Object { $_ -match '^\?\?' }).Count

            # Check if clean
            $isClean = $statusOutput.Count -eq 0

            # Get last commit
            $lastCommit = git log -1 --format="%H %s" 2>&1
            if ($LASTEXITCODE -eq 0) {
                $commitParts = $lastCommit -split ' ', 2
                $lastCommitHash = $commitParts[0]
                $lastCommitMessage = if ($commitParts.Count -gt 1) { $commitParts[1] } else { "" }
            }
            else {
                $lastCommitHash = $null
                $lastCommitMessage = "No commits yet"
            }

            # Check tracking status
            $trackingStatus = git status -sb 2>&1 | Select-Object -First 1
            $isTracking = $trackingStatus -match '\[.*\]'

            return @{
                Success = $true
                CurrentBranch = $currentBranch
                IsClean = $isClean
                Modified = $modified
                Added = $added
                Deleted = $deleted
                Untracked = $untracked
                TotalChanges = $statusOutput.Count
                LastCommitHash = $lastCommitHash
                LastCommitMessage = $lastCommitMessage
                IsTracking = $isTracking
                TrackingStatus = $trackingStatus
            }
        }
        finally {
            Pop-Location
        }
    }
    catch {
        Write-Error "Failed to get Git status: $_"

        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Wait-ForGitCommit {
    <#
    .SYNOPSIS
        Waits for a Git commit operation to complete
    .DESCRIPTION
        Monitors for commit completion by checking repository state
    #>
    param(
        [Parameter(Mandatory)]
        [string]$RepoPath,

        [Parameter()]
        [int]$TimeoutSeconds = 60,

        [Parameter()]
        [int]$PollIntervalSeconds = 2
    )

    Write-Verbose "Waiting for Git commit to complete..."

    try {
        $startTime = Get-Date
        $initialStatus = Get-GitStatus -RepoPath $RepoPath

        if (-not $initialStatus.Success) {
            throw "Failed to get initial Git status"
        }

        $initialCommit = $initialStatus.LastCommitHash

        while (((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
            Start-Sleep -Seconds $PollIntervalSeconds

            $currentStatus = Get-GitStatus -RepoPath $RepoPath

            if ($currentStatus.Success) {
                # Check if a new commit was created
                if ($currentStatus.LastCommitHash -ne $initialCommit) {
                    Write-Verbose "New commit detected: $($currentStatus.LastCommitHash)"
                    return @{
                        Success = $true
                        NewCommit = $currentStatus.LastCommitHash
                        Message = $currentStatus.LastCommitMessage
                        WaitTime = ((Get-Date) - $startTime).TotalSeconds
                    }
                }

                # Check if working directory became clean (commit completed)
                if ($currentStatus.IsClean -and -not $initialStatus.IsClean) {
                    Write-Verbose "Working directory became clean"
                    return @{
                        Success = $true
                        Completed = $true
                        WaitTime = ((Get-Date) - $startTime).TotalSeconds
                    }
                }
            }
        }

        # Timeout reached
        Write-Warning "Timeout waiting for Git commit"
        return @{
            Success = $false
            Error = "Timeout after $TimeoutSeconds seconds"
        }
    }
    catch {
        Write-Error "Error waiting for Git commit: $_"

        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Test-GitAuthentication {
    <#
    .SYNOPSIS
        Tests if Git authentication is properly configured
    .DESCRIPTION
        Verifies that Git can authenticate to the remote repository
    #>
    param(
        [Parameter(Mandatory)]
        [string]$RepoPath,

        [Parameter()]
        [string]$Remote = "origin"
    )

    try {
        Push-Location $RepoPath

        try {
            # Try to fetch from remote
            Write-Verbose "Testing Git authentication for remote: $Remote"

            git ls-remote $Remote 2>&1 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-Verbose "Git authentication successful"
                return @{
                    Success = $true
                    Authenticated = $true
                    Remote = $Remote
                }
            }
            else {
                Write-Warning "Git authentication may have failed"
                return @{
                    Success = $false
                    Authenticated = $false
                    Remote = $Remote
                    Error = "ls-remote failed"
                }
            }
        }
        finally {
            Pop-Location
        }
    }
    catch {
        Write-Error "Git authentication test failed: $_"

        return @{
            Success = $false
            Authenticated = $false
            Error = $_.Exception.Message
        }
    }
}

# Export functions
Export-ModuleMember -Function Invoke-GitBranch, Invoke-GitCommit, Invoke-GitPush,
    Get-GitStatus, Wait-ForGitCommit, Test-GitAuthentication
