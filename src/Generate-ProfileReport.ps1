# GitHub Profile README Report Generator
# Creates a modern, visually appealing report for GitHub profile README

param(
    [Parameter(Mandatory = $false)]
    [string]$GitHubUsername = "jorgeasaurus",
    
    [Parameter(Mandatory = $false)]
    [string]$GitHubToken = $env:GITHUB_TOKEN,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "profile_report.md",
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludePrivate,
    
    [Parameter(Mandatory = $false)]
    [int]$TopReposCount = 6,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipCloneData
)

# Import required functions
. "$PSScriptRoot\Get-GitHubCloneActivity.ps1"

function Get-LanguageColor {
    param([string]$Language)
    
    $colors = @{
        "JavaScript" = "f1e05a"
        "TypeScript" = "2b7489"
        "Python"     = "3572A5"
        "Java"       = "b07219"
        "C#"         = "178600"
        "C++"        = "f34b7d"
        "PHP"        = "4F5D95"
        "Ruby"       = "701516"
        "Go"         = "00ADD8"
        "Rust"       = "dea584"
        "Swift"      = "ffac45"
        "Kotlin"     = "F18E33"
        "PowerShell" = "012456"
        "Shell"      = "89e051"
        "HTML"       = "e34c26"
        "CSS"        = "563d7c"
        "Vue"        = "4fc08d"
        "React"      = "61dafb"
    }
    
    return $colors[$Language] ?? "858585"
}

function Format-Number {
    param([int]$Number)
    
    if ($Number -ge 1000000) {
        return "{0:N1}M" -f ($Number / 1000000)
    } elseif ($Number -ge 1000) {
        return "{0:N1}K" -f ($Number / 1000)
    } else {
        return $Number.ToString()
    }
}

function Generate-ProfileReport {
    Write-Host "Generating GitHub Profile Report for $GitHubUsername..." -ForegroundColor Cyan
    
    # Get all activity data
    $scriptPath = Join-Path $PSScriptRoot "Get-AllActivity.ps1"
    if (-not (Test-Path $scriptPath)) {
        # Try alternative path for GitHub Actions
        $scriptPath = Join-Path (Split-Path $PSScriptRoot) "src/Get-AllActivity.ps1"
    }
    . $scriptPath
    
    # Use platform-appropriate temp directory
    $tempDir = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
        $env:TEMP
    } else {
        "/tmp"
    }
    
    $tempJsonPath = Join-Path $tempDir "temp_activity_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    
    # Ensure we pass all parameters correctly to Get-AllGitHubActivity
    Write-Host "Fetching GitHub activity data..." -ForegroundColor Gray
    $activityData = Get-AllGitHubActivity -GitHubUsername $GitHubUsername -GitHubToken $GitHubToken -IncludePrivate:$IncludePrivate -OutputPath $tempJsonPath
    
    if (-not $activityData) {
        throw "Failed to fetch GitHub activity data"
    }
    
    # Start building the markdown report
    $report = @"
<!-- GitHub Activity Report - Auto-generated -->
<!-- Last Updated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC" -AsUTC) -->

## 📊 GitHub Stats

<div align="center">
  
![](https://img.shields.io/badge/Total_Repos-$($activityData.Summary.TotalRepositories)-blue?style=for-the-badge)
![](https://img.shields.io/badge/Total_Stars-$(Format-Number $activityData.Summary.TotalStars)-yellow?style=for-the-badge)
![](https://img.shields.io/badge/Total_Forks-$(Format-Number $activityData.Summary.TotalForks)-green?style=for-the-badge)
![](https://img.shields.io/badge/Total_Clones-$(Format-Number $activityData.Summary.TotalClones)-purple?style=for-the-badge)

</div>

## 🔥 Most Popular Repositories

<div align="center">
<table>
<tr>

"@

    # Get top repositories by different metrics
    $topByStars = $activityData.Repositories | Sort-Object Stars -Descending | Select-Object -First $TopReposCount
    $topByClones = $activityData.Repositories | Where-Object { $_.TotalClones -gt 0 } | Sort-Object TotalClones -Descending | Select-Object -First 3
    
    # Create repository cards
    $repoCards = @()
    $topRepos = $topByStars | Select-Object -First 6
    
    for ($i = 0; $i -lt $topRepos.Count; $i++) {
        $repo = $topRepos[$i]
        $repoName = $repo.Repository.Split('/')[-1]
        $languageColor = Get-LanguageColor -Language $repo.Language
        
        if ($i % 3 -eq 0 -and $i -gt 0) {
            $report += "</tr>`n<tr>`n"
        }
        
        $report += @"
<td>
  <a href="https://github.com/$($repo.Repository)">
    <img align="center" src="https://github-readme-stats.vercel.app/api/pin/?username=$GitHubUsername&repo=$repoName&theme=dark&hide_border=true" />
  </a>
</td>

"@
    }
    
    $report += @"
</tr>
</table>
</div>

## 📈 Activity Trends

### 🏆 Top Cloned Repositories (Last 14 days)

| Repository | Total Clones |
|------------|-------------|

"@

    # Add top cloned repositories
    $topByClones | ForEach-Object {
        $repoName = $_.Repository.Split('/')[-1]
        $report += "| [$repoName](https://github.com/$($_.Repository)) | $(Format-Number $_.TotalClones) |`n"
    }
    
    # Recent Activity section
    $report += @"

## 📅 Recent Activity

### 🚀 Recently Updated Repositories

| Repository | Last Updated | Language | Stars |
|------------|--------------|----------|-------|

"@

    # Add recently updated repos
    $recentRepos = $activityData.Repositories | 
    Where-Object { $_.PushedAt } | 
    Sort-Object { [DateTime]$_.PushedAt } -Descending | 
    Select-Object -First 5
        
    foreach ($repo in $recentRepos) {
        $repoName = $repo.Repository.Split('/')[-1]
        $lastUpdated = [DateTime]$repo.PushedAt
        $daysAgo = (Get-Date) - $lastUpdated
        
        $timeAgo = if ($daysAgo.Days -eq 0) { "Today" }
        elseif ($daysAgo.Days -eq 1) { "Yesterday" }
        elseif ($daysAgo.Days -lt 7) { "$($daysAgo.Days) days ago" }
        elseif ($daysAgo.Days -lt 30) { "$([math]::Floor($daysAgo.Days / 7)) weeks ago" }
        else { "$([math]::Floor($daysAgo.Days / 30)) months ago" }
        
        $languageBadge = if ($repo.Language) { 
            "![](https://img.shields.io/badge/-$($repo.Language)-$(Get-LanguageColor $repo.Language)?style=flat-square&logoColor=white)"
        } else { 
            "N/A" 
        }
        
        $report += "| [$repoName](https://github.com/$($repo.Repository)) | $timeAgo | $languageBadge | ⭐ $(Format-Number $repo.Stars) |`n"
    }
    
    # Footer
    $report += @"

---

<div align="center">
  <sub>📊 Auto-updated with PowerShell & GitHub Actions</sub>
</div>

<!-- Profile Report Generated by GitHub Activity Analyzer -->
"@

    # Save the report
    try {
        $report | Out-File -FilePath $OutputPath -Encoding UTF8 -NoNewline -ErrorAction Stop
        Write-Host "Profile report saved to: $OutputPath" -ForegroundColor Green
        
        # Verify file was created
        if (Test-Path $OutputPath) {
            $fileInfo = Get-Item $OutputPath
            Write-Host "Report file size: $($fileInfo.Length) bytes" -ForegroundColor Gray
        } else {
            throw "File was not created at $OutputPath"
        }
    } catch {
        Write-Error "Failed to save report: $_"
        throw
    }
    
    # Clean up temp file
    if ($tempJsonPath -and (Test-Path $tempJsonPath)) {
        Remove-Item $tempJsonPath -Force
    }
    
    return $report
}

# Don't auto-execute when dot-sourced - let the caller run the function