---
title: "Git"
#description: ""
date: 2025-09-26T10:00:00+01:00
lastmod: 2025-09-26T10:00:00+01:00
draft: false
author: "Manzolo"
tags: ["git", "version-control", "commands", "github", "reference"]
categories: ["Command Reference"]
series: ["Command Line Mastery"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Git and Gitflow Guide

## Introduction

Git is a distributed version control system that enables multiple developers to collaborate on projects efficiently. Gitflow is a popular branching model that organizes Git branches for streamlined development and release management. This guide covers essential Git commands, introduces the Gitflow workflow, and provides practical examples for managing code repositories.

## What is Git?

Git tracks changes to files, allowing multiple users to work on the same project without conflicts. It supports branching, merging, and version history, making it ideal for software development and collaborative projects.

## What is Gitflow?

Gitflow is a branching strategy that defines specific branches for development, features, releases, and hotfixes. It ensures a structured workflow, especially for teams working on long-term projects with multiple releases.

## Prerequisites

- Git installed on your system (`git --version` to verify).
- Basic understanding of terminal commands.
- A Git repository (local or remote, e.g., on GitHub, GitLab, or Bitbucket).

Install Git if needed:

```bash
sudo apt update
sudo apt install git  # Ubuntu/Debian
```

## Basic Git Commands

### Repository Setup

```bash
# Initialize a new Git repository
git init

# Clone a remote repository
git clone https://github.com/user/repo.git

# Check repository status
git status
```

### Committing Changes

```bash
# Stage files for commit
git add file.txt
git add .  # Stage all changes

# Commit staged changes
git commit -m "Add feature X"

# Amend the last commit
git commit --amend -m "Updated message"
```

### Branching

```bash
# List all branches
git branch

# Create a new branch
git branch feature-x

# Switch to a branch
git checkout feature-x

# Create and switch to a new branch
git checkout -b feature-x

# Delete a branch
git branch -d feature-x
```

### Remote Operations

```bash
# Add a remote repository
git remote add origin https://github.com/user/repo.git

# Push changes to remote
git push origin main

# Pull changes from remote
git pull origin main

# Fetch changes without merging
git fetch origin
```

## Gitflow Workflow

Gitflow organizes branches into specific roles:

- **main**: Production-ready code.
- **develop**: Integration branch for features.
- **feature/***: For new features (branched from `develop`).
- **release/***: For preparing a release (branched from `develop`, merged into `main` and `develop`).
- **hotfix/***: For urgent fixes (branched from `main`, merged back into `main` and `develop`).
- **support/***: For maintaining older releases (optional).

### Setting Up Gitflow

Install `git-flow` (optional, for convenience):

```bash
sudo apt install git-flow  # Ubuntu/Debian
```

Initialize Gitflow:

```bash
git flow init
```

This sets up the branch structure with defaults (e.g., `main`, `develop`).

### Example 1: Creating a Feature Branch

Start a new feature:

```bash
git flow feature start my-feature
```

- **Explanation**: Creates a branch `feature/my-feature` from `develop`.
- **Usage**:
  ```bash
  # Make changes
  echo "New feature" > feature.txt
  git add feature.txt
  git commit -m "Implement my-feature"

  # Finish the feature (merges into develop)
  git flow feature finish my-feature
  ```

### Example 2: Preparing a Release

Start a release:

```bash
git flow release start 1.0.0
```

- **Explanation**: Creates a branch `release/1.0.0` from `develop`.
- **Usage**:
  ```bash
  # Make final adjustments (e.g., update version numbers)
  echo "1.0.0" > version.txt
  git add version.txt
  git commit -m "Bump version to 1.0.0"

  # Finish the release (merges into main and develop, tags the release)
  git flow release finish 1.0.0
  git push origin main develop --tags
  ```

### Example 3: Handling a Hotfix

Start a hotfix for a bug in production:

```bash
git flow hotfix start 1.0.1
```

- **Explanation**: Creates a branch `hotfix/1.0.1` from `main`.
- **Usage**:
  ```bash
  # Fix the bug
  echo "Bugfix" > patch.txt
  git add patch.txt
  git commit -m "Fix critical bug"

  # Finish the hotfix (merges into main and develop, tags the hotfix)
  git flow hotfix finish 1.0.1
  git push origin main develop --tags
  ```

## Useful Git Commands

### Viewing History

```bash
# View commit history
git log
git log --oneline --graph --all  # Compact, visual history

# Show changes in a commit
git show commit_hash
```

### Merging and Rebasing

```bash
# Merge a branch into the current branch
git merge feature-x

# Rebase current branch onto another
git rebase develop

# Resolve merge conflicts manually, then:
git add resolved_file
git rebase --continue  # or git merge --continue
```

### Stashing Changes

```bash
# Save uncommitted changes
git stash

# List stashed changes
git stash list

# Apply the latest stash
git stash apply

# Drop a stash
git stash drop stash@{0}
```

### Tagging

```bash
# Create a tag
git tag v1.0.0

# Push tags to remote
git push origin v1.0.0

# List tags
git tag
```

## Practical Script

Create a script to automate Gitflow setup and status checks:

```bash
#!/bin/bash
# manage_gitflow.sh

echo "=== Gitflow Management ==="
echo "Current repository: $(pwd)"
echo ""

# Initialize Gitflow if not already set up
if [ ! -f .git/config ] || ! grep -q "gitflow" .git/config; then
  echo "Initializing Gitflow..."
  git flow init -d
fi

echo "Current branches:"
git branch

echo ""
echo "Recent commits:"
git log --oneline --graph --all -n 5

echo ""
echo "Repository status:"
git status
```

Make it executable:

```bash
chmod +x manage_gitflow.sh
./manage_gitflow.sh
```

## Pro Tips

{{< callout type="tip" >}}
**Tip**: Use `git-flow` commands for consistency, but you can achieve the same results with standard Git commands if preferred.
{{< /callout >}}

{{< callout type="warning" >}}
**Warning**: Avoid force-pushing (`git push --force`) to shared branches like `main` or `develop` to prevent overwriting others' work.
{{< /callout >}}

{{< callout type="success" title="Quick Reference" >}}
**Essential shortcuts:**
- `git checkout -b feature/x`: Create and switch to a feature branch.
- `git push --set-upstream origin branch`: Push a new branch and set tracking.
- `git stash pop`: Apply and remove the latest stash.
- `git log --oneline`: View a concise commit history.
{{< /callout >}}

## Troubleshooting

- **Merge Conflicts**: Edit conflicting files, mark them as resolved (`git add`), and continue the merge or rebase.
- **Remote Push Errors**: Ensure you have the latest changes (`git pull --rebase`) before pushing.
- **Lost Commits**: Use `git reflog` to find lost commit hashes and recover them with `git checkout commit_hash`.
- **Gitflow Not Found**: Install `git-flow` or use standard Git commands to mimic the workflow.

## Next Steps

In future tutorials, we’ll cover:
- Advanced Git workflows (e.g., GitHub Flow).
- Automating Git tasks with hooks.
- Managing large repositories with Git LFS.
- Integrating Git with CI/CD pipelines.

## Practice Exercises

1. **Feature Development**: Create a feature branch, add a file, and merge it into `develop` using Gitflow.
2. **Release Process**: Simulate a release with a version tag and push it to a remote repository.
3. **Hotfix**: Create a hotfix branch, apply a fix, and merge it into `main` and `develop`.
4. **History Analysis**: Use `git log` and `git blame` to analyze changes in a file.

## Resources

- [Git Documentation](https://git-scm.com/doc)
- [Gitflow Workflow](https://nvie.com/posts/a-successful-git-branching-model/)
- [Atlassian Git Tutorials](https://www.atlassian.com/git)
- [Learn Git Branching](https://learngitbranching.js.org/)

---

*Practice Git and Gitflow to streamline your development workflow!*