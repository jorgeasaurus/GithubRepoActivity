# GitHub Profile Activity Setup Guide

This guide will help you set up automatic GitHub activity reports in your profile README.

## 🚀 Quick Setup

### 1. Fork or Use This Repository

You can either:
- Fork this repository to your account
- Or use it as a template for your own activity analyzer

### 2. Update Your Profile README

Add these markers to your `[username]/[username]` repository's README.md where you want the activity report to appear:

```markdown
<!-- GITHUB-ACTIVITY:START -->
<!-- GITHUB-ACTIVITY:END -->
```

Example placement in your README:

```markdown
# Hi there! 👋

I'm a passionate developer working on various projects.

## 📊 My GitHub Activity

<!-- GITHUB-ACTIVITY:START -->
<!-- GITHUB-ACTIVITY:END -->

## 📫 How to reach me
...
```

### 3. Set Up GitHub Secrets

You'll need to set up one or two secrets:

#### Required: ACTIVITY_TOKEN
For accessing clone/traffic data:
1. Create a Personal Access Token with `repo` scope
2. Go to your repository Settings → Secrets and variables → Actions
3. Add a new secret called `ACTIVITY_TOKEN`
4. Paste your token

#### Optional: PROFILE_TOKEN
Only needed if your profile repository is private:
1. Create another Personal Access Token (or use the same one)
2. Add a secret called `PROFILE_TOKEN`

### 4. Enable GitHub Actions

Make sure GitHub Actions are enabled in your repository settings.

### 5. Run the Workflow

The workflow will:
- Run automatically every day at 2 AM UTC
- Update when you push changes to the main branch
- Can be manually triggered from the Actions tab

## 📊 What's Included in the Report

The automated report includes:

- **Statistics Badges**: Total repos, stars, forks, and clones
- **Popular Repositories**: Top 6 repos by stars with cards
- **Activity Trends**: Most cloned repositories
- **Language Distribution**: Programming language breakdown
- **Recent Activity**: Recently updated repositories
- **Contribution Stats**: GitHub streak and contribution graphs

## 🎨 Customization

Edit `src/Generate-ProfileReport.ps1` to customize:

- Number of top repositories shown (`-TopReposCount`)
- Include/exclude private repositories (`-IncludePrivate`)
- Show/hide language chart (`-IncludeLanguageChart`)
- Badge styles and colors
- Section ordering and content

## 🔧 Manual Generation

To generate a report manually:

```powershell
# Generate report locally
pwsh -NoProfile -Command ". ./src/Generate-ProfileReport.ps1 -GitHubUsername 'yourusername'"

# With all options
pwsh -NoProfile -Command ". ./src/Generate-ProfileReport.ps1 -GitHubUsername 'yourusername' -IncludeLanguageChart -TopReposCount 8"
```

## 📝 Example Output

Your profile will display:
- Dynamic badges with your stats
- Repository cards for your most popular projects
- Tables showing activity trends
- Beautiful visualizations of your contributions

## 🐛 Troubleshooting

### Report not updating?
1. Check Actions tab for workflow runs
2. Ensure markers are present in your README
3. Verify tokens have correct permissions

### Missing data?
1. Clone/traffic data requires push access to repos
2. Private repo data requires authenticated token
3. Some stats may take 24 hours to populate

## 🤝 Contributing

Feel free to submit issues or PRs to improve the report generator!