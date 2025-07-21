function Get-GitHubCloneActivity {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Repositories,
        
        [Parameter(Mandatory = $false)]
        [string]$GitHubUsername,
        
        [Parameter(Mandatory = $false)]
        [string]$GitHubToken,
        
        [Parameter(Mandatory = $false)]
        [int]$DelayBetweenRequests = 1000,  # milliseconds
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeTimestamps,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportToCsv,
        
        [Parameter(Mandatory = $false)]
        [string]$CsvPath = "github_clone_activity.csv"
    )
    
    $results = @()
    $totalRepos = $Repositories.Count
    $currentRepo = 0
    
    Write-Host "Fetching clone activity data for $totalRepos repositories..." -ForegroundColor Green
    
    foreach ($repo in $Repositories) {
        $currentRepo++
        Write-Progress -Activity "Fetching Clone Activity" -Status "Processing $repo ($currentRepo of $totalRepos)" -PercentComplete (($currentRepo / $totalRepos) * 100)
        
        try {
            # Clean the repo name - handle different input formats
            $cleanRepo = $repo
            if ($repo -match "github\.com/(.+)") {
                $cleanRepo = $matches[1]
            }
            if ($cleanRepo.EndsWith(".git")) {
                $cleanRepo = $cleanRepo.Substring(0, $cleanRepo.Length - 4)
            }
            
            # Construct the URL - using official GitHub API endpoint
            $url = "https://api.github.com/repos/$cleanRepo/traffic/clones"
            
            Write-Host "  Fetching: $cleanRepo" -ForegroundColor Cyan
            
            # Set up headers for authentication if provided
            $headers = @{
                'User-Agent' = 'PowerShell-GitHubCloneActivityFetcher'
            }
            
            if ($GitHubToken) {
                $headers['Authorization'] = "token $GitHubToken"
                $headers['Accept'] = 'application/vnd.github.v3+json'
            }
            
            # Make the request
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction Stop
            
            # Process the response - GitHub API v3 format
            $repoResult = [PSCustomObject]@{
                Repository   = $cleanRepo
                TotalClones  = $response.count
                UniqueClones = $response.uniques
                Success      = $true
                ErrorMessage = $null
                LastFetched  = Get-Date
                CloneData    = $response.clones
            }
            
            # Add timestamp conversion if requested
            if ($IncludeTimestamps) {
                $repoResult.CloneData = $response.clones | ForEach-Object {
                    [PSCustomObject]@{
                        Total  = $_.count
                        Unique = $_.uniques
                        Date   = [DateTime]$_.timestamp
                    }
                }
            }
            
            Write-Host "    ✓ Total: $($response.count), Unique: $($response.uniques)" -ForegroundColor Green
            
        } catch {
            Write-Warning "  ✗ Failed to fetch data for $cleanRepo : $($_.Exception.Message)"
            
            $repoResult = [PSCustomObject]@{
                Repository   = $cleanRepo
                TotalClones  = 0
                UniqueClones = 0
                Success      = $false
                ErrorMessage = $_.Exception.Message
                LastFetched  = Get-Date
                CloneData    = @()
            }
        }
        
        $results += $repoResult
        
        # Add delay between requests to be respectful to GitHub's servers
        if ($currentRepo -lt $totalRepos) {
            Start-Sleep -Milliseconds $DelayBetweenRequests
        }
    }
    
    Write-Progress -Activity "Fetching Clone Activity" -Completed
    
    # Display summary
    $successfulFetches = ($results | Where-Object Success).Count
    $totalClones = ($results | Where-Object Success | Measure-Object TotalClones -Sum).Sum
    $totalUniqueClones = ($results | Where-Object Success | Measure-Object UniqueClones -Sum).Sum
    
    Write-Host "`n=== SUMMARY ===" -ForegroundColor Yellow
    Write-Host "Repositories processed: $totalRepos" -ForegroundColor White
    Write-Host "Successful fetches: $successfulFetches" -ForegroundColor Green
    Write-Host "Failed fetches: $($totalRepos - $successfulFetches)" -ForegroundColor Red
    Write-Host "Total clones across all repos: $totalClones" -ForegroundColor Cyan
    Write-Host "Total unique clones across all repos: $totalUniqueClones" -ForegroundColor Cyan
    
    # Export to CSV if requested
    if ($ExportToCsv) {
        $csvData = $results | Select-Object Repository, TotalClones, UniqueClones, Success, ErrorMessage, LastFetched
        $csvData | Export-Csv -Path $CsvPath -NoTypeInformation
        Write-Host "Data exported to: $CsvPath" -ForegroundColor Green
    }
    
    return $results
}

function Get-GitHubRepositories {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GitHubUsername,
        
        [Parameter(Mandatory = $false)]
        [string]$GitHubToken,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludePrivate
    )
    
    try {
        $headers = @{
            'User-Agent' = 'PowerShell-GitHubRepoFetcher'
        }
        
        if ($GitHubToken) {
            $headers['Authorization'] = "token $GitHubToken"
            $headers['Accept'] = 'application/vnd.github.v3+json'
        }
        
        $repos = @()
        $page = 1
        $perPage = 100
        
        do {
            $url = "https://api.github.com/users/$GitHubUsername/repos?page=$page&per_page=$perPage"
            if ($IncludePrivate -and $GitHubToken) {
                $url += "&type=all"
            }
            
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
            $repos += $response
            $page++
            
            Write-Host "Fetched $($repos.Count) repositories..." -ForegroundColor Cyan
            
        } while ($response.Count -eq $perPage)
        
        $repoNames = $repos | ForEach-Object { "$GitHubUsername/$($_.name)" }
        
        Write-Host "Found $($repoNames.Count) repositories for user: $GitHubUsername" -ForegroundColor Green
        
        return $repoNames
        
    } catch {
        Write-Error "Failed to fetch repositories for user $GitHubUsername : $($_.Exception.Message)"
        return @()
    }
}

function Show-TopClonedRepos {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$CloneActivityResults,
        
        [Parameter(Mandatory = $false)]
        [int]$TopCount = 10
    )
    
    Write-Host "`n=== TOP $TopCount CLONED REPOSITORIES ===" -ForegroundColor Yellow
    
    $topRepos = $CloneActivityResults | 
    Where-Object Success | 
    Sort-Object TotalClones -Descending | 
    Select-Object -First $TopCount
    
    $topRepos | ForEach-Object {
        Write-Host "  $($_.Repository): $($_.TotalClones) total ($($_.UniqueClones) unique)" -ForegroundColor White
    }
}

# Example usage functions
function Get-MyGitHubCloneActivity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GitHubUsername,
        
        [Parameter(Mandatory = $false)]
        [string]$GitHubToken
    )
    
    # Get all repositories for the user
    $repos = Get-GitHubRepositories -GitHubUsername $GitHubUsername -GitHubToken $GitHubToken -IncludePrivate
    
    if ($repos.Count -eq 0) {
        Write-Warning "No repositories found for user: $GitHubUsername"
        return
    }
    
    # Get clone activity for all repos
    $results = Get-GitHubCloneActivity -Repositories $repos -GitHubToken $GitHubToken -ExportToCsv -IncludeTimestamps
    
    # Show top repositories
    Show-TopClonedRepos -CloneActivityResults $results -TopCount 10
    
    return $results
}

<#
.SYNOPSIS
Fetches GitHub clone activity data for multiple repositories.

.DESCRIPTION
This function takes an array of GitHub repository names and fetches clone activity data
for each repository using GitHub's traffic API endpoint.

NOTE: The GitHub API requires that you have push access to the repository
to view traffic data. You must be authenticated with a valid GitHub token
that has the appropriate permissions (repo scope).

.PARAMETER Repositories
Array of repository names in format "username/reponame" or full GitHub URLs

.PARAMETER GitHubUsername
Your GitHub username (optional, for authentication)

.PARAMETER GitHubToken
Your GitHub personal access token (recommended for private repos and higher rate limits)

.PARAMETER DelayBetweenRequests
Delay in milliseconds between requests to avoid rate limiting (default: 1000ms)

.PARAMETER IncludeTimestamps
Convert Unix timestamps to readable dates in the output

.PARAMETER ExportToCsv
Export results to a CSV file

.PARAMETER CsvPath
Path for the CSV export file (default: "github_clone_activity.csv")

.EXAMPLE
# Simple usage with repository array
$repos = @("username/repo1", "username/repo2", "username/repo3")
$results = Get-GitHubCloneActivity -Repositories $repos

.EXAMPLE
# With authentication and CSV export
$results = Get-GitHubCloneActivity -Repositories $repos -GitHubToken "your_token_here" -ExportToCsv

.EXAMPLE
# Get clone activity for all your repositories
$results = Get-MyGitHubCloneActivity -GitHubUsername "yourusername" -GitHubToken "your_token_here"

.EXAMPLE
# Manual repository list with timestamps
$myRepos = @(
    "jorgeasaurus/WinGet-Manifest-Fetcher",
    "jorgeasaurus/Intune-Snapshot-Recovery"
)
$results = Get-GitHubCloneActivity -Repositories $myRepos -IncludeTimestamps -ExportToCsv
#>