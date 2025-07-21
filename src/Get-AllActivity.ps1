# GitHub Activity Analysis Script for jorgeasaurus
# This script gathers comprehensive activity data for all repositories

param(
    [Parameter(Mandatory = $false)]
    [string]$GitHubUsername = "jorgeasaurus",
    
    [Parameter(Mandatory = $false)]
    [string]$GitHubToken = $env:GITHUB_TOKEN,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "github_activity_report_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').json",
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludePrivate,
    
    [Parameter(Mandatory = $false)]
    [switch]$ExportCsv,
    
    [Parameter(Mandatory = $false)]
    [switch]$ShowVisualization
)

# Import required functions
. (Join-Path $PSScriptRoot "Get-GitHubCloneActivity.ps1")

function Get-GitHubRepoStats {
    param(
        [string]$Owner,
        [string]$Repo,
        [hashtable]$Headers
    )
    
    $stats = @{}
    
    try {
        # Get repository details
        $repoUrl = "https://api.github.com/repos/$Owner/$Repo"
        $repoInfo = Invoke-RestMethod -Uri $repoUrl -Headers $Headers -Method Get
        
        $stats.Stars = $repoInfo.stargazers_count
        $stats.Forks = $repoInfo.forks_count
        $stats.Watchers = $repoInfo.watchers_count
        $stats.OpenIssues = $repoInfo.open_issues_count
        $stats.Size = $repoInfo.size
        $stats.Language = $repoInfo.language
        $stats.CreatedAt = $repoInfo.created_at
        $stats.UpdatedAt = $repoInfo.updated_at
        $stats.PushedAt = $repoInfo.pushed_at
        
        # Get views (requires authentication)
        if ($Headers.Authorization) {
            try {
                $viewsUrl = "https://api.github.com/repos/$Owner/$Repo/traffic/views"
                $views = Invoke-RestMethod -Uri $viewsUrl -Headers $Headers -Method Get
                $stats.TotalViews = $views.count
                $stats.UniqueViews = $views.uniques
            } catch {
                $stats.TotalViews = "N/A"
                $stats.UniqueViews = "N/A"
            }
        }
        
    } catch {
        Write-Warning "Failed to get stats for $Owner/$Repo : $_"
    }
    
    return $stats
}

function Get-AllGitHubActivity {
    Write-Host "`n===== GitHub Activity Report for $GitHubUsername =====" -ForegroundColor Cyan
    Write-Host "Report generated at: $(Get-Date)" -ForegroundColor Gray
    
    # Set up headers
    $headers = @{
        'User-Agent' = 'PowerShell-GitHubActivityAnalyzer'
        'Accept' = 'application/vnd.github.v3+json'
    }
    
    if ($GitHubToken) {
        $headers['Authorization'] = "token $GitHubToken"
        Write-Host "Using authenticated requests" -ForegroundColor Green
    } else {
        Write-Warning "No GitHub token provided. Some data may be unavailable."
    }
    
    # Get all repositories
    Write-Host "`nFetching repositories..." -ForegroundColor Yellow
    $repos = Get-GitHubRepositories -GitHubUsername $GitHubUsername -GitHubToken $GitHubToken -IncludePrivate:$IncludePrivate
    
    if ($repos.Count -eq 0) {
        Write-Error "No repositories found!"
        return
    }
    
    Write-Host "Found $($repos.Count) repositories" -ForegroundColor Green
    
    # Get clone activity
    Write-Host "`nFetching clone activity..." -ForegroundColor Yellow
    $cloneActivity = Get-GitHubCloneActivity -Repositories $repos -GitHubToken $GitHubToken -IncludeTimestamps
    
    # Gather comprehensive stats for each repo
    Write-Host "`nGathering repository statistics..." -ForegroundColor Yellow
    $allRepoData = @()
    
    foreach ($repo in $repos) {
        $repoName = $repo.Split('/')[-1]
        Write-Host "  Processing: $repoName" -ForegroundColor Gray
        
        $repoStats = Get-GitHubRepoStats -Owner $GitHubUsername -Repo $repoName -Headers $headers
        $cloneData = $cloneActivity | Where-Object { $_.Repository -eq $repo }
        
        $repoData = [PSCustomObject]@{
            Repository = $repo
            Stars = $repoStats.Stars
            Forks = $repoStats.Forks
            Watchers = $repoStats.Watchers
            OpenIssues = $repoStats.OpenIssues
            Size = $repoStats.Size
            Language = $repoStats.Language
            CreatedAt = $repoStats.CreatedAt
            UpdatedAt = $repoStats.UpdatedAt
            PushedAt = $repoStats.PushedAt
            TotalClones = $cloneData.TotalClones
            UniqueClones = $cloneData.UniqueClones
            TotalViews = $repoStats.TotalViews
            UniqueViews = $repoStats.UniqueViews
            CloneData = $cloneData.CloneData
        }
        
        $allRepoData += $repoData
        Start-Sleep -Milliseconds 500  # Rate limiting
    }
    
    # Generate summary statistics
    $summary = @{
        TotalRepositories = $repos.Count
        TotalStars = ($allRepoData | Measure-Object -Property Stars -Sum).Sum
        TotalForks = ($allRepoData | Measure-Object -Property Forks -Sum).Sum
        TotalClones = ($allRepoData | Measure-Object -Property TotalClones -Sum).Sum
        TotalUniqueClones = ($allRepoData | Measure-Object -Property UniqueClones -Sum).Sum
        MostStarred = ($allRepoData | Sort-Object Stars -Descending | Select-Object -First 1).Repository
        MostForked = ($allRepoData | Sort-Object Forks -Descending | Select-Object -First 1).Repository
        MostCloned = ($allRepoData | Sort-Object TotalClones -Descending | Select-Object -First 1).Repository
        LanguageBreakdown = $allRepoData | Group-Object Language | Select-Object Name, Count | Sort-Object Count -Descending
    }
    
    # Display results
    Write-Host "`n===== SUMMARY =====" -ForegroundColor Yellow
    Write-Host "Total Repositories: $($summary.TotalRepositories)" -ForegroundColor White
    Write-Host "Total Stars: $($summary.TotalStars)" -ForegroundColor White
    Write-Host "Total Forks: $($summary.TotalForks)" -ForegroundColor White
    Write-Host "Total Clones: $($summary.TotalClones)" -ForegroundColor White
    Write-Host "Total Unique Clones: $($summary.TotalUniqueClones)" -ForegroundColor White
    Write-Host "`nMost Starred: $($summary.MostStarred)" -ForegroundColor Cyan
    Write-Host "Most Forked: $($summary.MostForked)" -ForegroundColor Cyan
    Write-Host "Most Cloned: $($summary.MostCloned)" -ForegroundColor Cyan
    
    Write-Host "`n===== LANGUAGE BREAKDOWN =====" -ForegroundColor Yellow
    $summary.LanguageBreakdown | ForEach-Object {
        if ($_.Name) {
            Write-Host "  $($_.Name): $($_.Count) repos" -ForegroundColor White
        }
    }
    
    # Show top 10 repositories by various metrics
    Write-Host "`n===== TOP 10 BY STARS =====" -ForegroundColor Yellow
    $allRepoData | Sort-Object Stars -Descending | Select-Object -First 10 | ForEach-Object {
        Write-Host "  $($_.Repository.Split('/')[-1]): $($_.Stars) stars" -ForegroundColor White
    }
    
    Write-Host "`n===== TOP 10 BY CLONES =====" -ForegroundColor Yellow
    $allRepoData | Where-Object { $_.TotalClones -gt 0 } | Sort-Object TotalClones -Descending | Select-Object -First 10 | ForEach-Object {
        Write-Host "  $($_.Repository.Split('/')[-1]): $($_.TotalClones) clones ($($_.UniqueClones) unique)" -ForegroundColor White
    }
    
    # Create output object
    $output = @{
        GeneratedAt = Get-Date
        Username = $GitHubUsername
        Summary = $summary
        Repositories = $allRepoData
    }
    
    # Save to JSON
    $output | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "`nFull report saved to: $OutputPath" -ForegroundColor Green
    
    # Export to CSV if requested
    if ($ExportCsv) {
        $csvPath = $OutputPath -replace '\.json$', '.csv'
        $allRepoData | Select-Object Repository, Stars, Forks, Watchers, OpenIssues, Language, TotalClones, UniqueClones, TotalViews, UniqueViews, CreatedAt, UpdatedAt |
            Export-Csv -Path $csvPath -NoTypeInformation
        Write-Host "CSV export saved to: $csvPath" -ForegroundColor Green
    }
    
    # Show visualization if requested
    if ($ShowVisualization) {
        Write-Host "`n===== ACTIVITY VISUALIZATION =====" -ForegroundColor Yellow
        
        # Simple text-based bar chart for top 10 cloned repos
        $maxClones = ($allRepoData | Measure-Object -Property TotalClones -Maximum).Maximum
        $scale = 50 / $maxClones
        
        $allRepoData | Where-Object { $_.TotalClones -gt 0 } | Sort-Object TotalClones -Descending | Select-Object -First 10 | ForEach-Object {
            $barLength = [math]::Round($_.TotalClones * $scale)
            $bar = "█" * $barLength
            $repoName = $_.Repository.Split('/')[-1]
            $repoName = $repoName.PadRight(30).Substring(0, 30)
            Write-Host "  $repoName $bar $($_.TotalClones)" -ForegroundColor Cyan
        }
    }
    
    return $output
}

# Main execution
if ($GitHubToken -eq $null -and $env:GITHUB_TOKEN) {
    $GitHubToken = $env:GITHUB_TOKEN
}

$activityData = Get-AllGitHubActivity

Write-Host "`nActivity analysis complete!" -ForegroundColor Green