# Gitea Setup

Simple Docker-based Gitea installation with automated initialization scripts.

## Prerequisites

- Docker and Docker Compose
- Make
- curl
- jq (optional, for JSON output)

## Quick Start

1. Start Gitea:
   ```bash
   make start
   ```

2. Initialize Gitea (installs Gitea without creating users):
   ```bash
   make init-gitea
   ```

3. Create an admin user:
   ```bash
   USERNAME=admin PASSWORD=yourpassword make create-user
   ```

4. Create a repository:
   ```bash
   USERNAME=admin PASSWORD=yourpassword NAME=my-repo make create-repo
   ```

## Available Commands

### Container Management

- `make start` - Start Gitea container
- `make stop` - Stop Gitea container
- `make logs` - View container logs
- `make clean` - Stop container and remove all data

### Gitea Setup

- `make init-gitea` - Initialize Gitea installation (no users created)
- `make create-user` - Create admin user (**requires** USERNAME and PASSWORD env vars)
- `make create-token` - Create access token that never expires (**requires** USERNAME and PASSWORD env vars)
- `make create-repo` - Create repository (**requires** USERNAME, PASSWORD, and NAME env vars)
- `make delete-repo` - Delete repository (**requires** USERNAME, PASSWORD, and NAME env vars)

## Examples

### Create a user with custom credentials:
```bash
USERNAME=john PASSWORD=secret123 make create-user
```

### Create an access token (never expires):
```bash
USERNAME=admin PASSWORD=yourpassword make create-token
```

The token will be displayed in the terminal. **Save it immediately** - it won't be shown again!

### Create a repository with custom name:
```bash
USERNAME=admin PASSWORD=yourpassword NAME=my-project make create-repo
```

### Delete a repository:
```bash
USERNAME=admin PASSWORD=yourpassword NAME=my-project make delete-repo
```

### Full setup in one go:
```bash
make start
sleep 5
make init-gitea
USERNAME=admin PASSWORD=admin123 make create-user
USERNAME=admin PASSWORD=admin123 NAME=test-repo make create-repo
```

## Required Parameters

**All parameters are required** - scripts will fail with clear error messages if any are missing:

- `create-user` requires:
  - `USERNAME` - Username for the admin user
  - `PASSWORD` - Password for the admin user

- `create-token` requires:
  - `USERNAME` - Username for the user who will own the token
  - `PASSWORD` - Password for authentication

- `create-repo` requires:
  - `USERNAME` - Username of the user who owns the repository
  - `PASSWORD` - Password for authentication
  - `NAME` - Name of the repository to create

- `delete-repo` requires:
  - `USERNAME` - Username of the user who owns the repository
  - `PASSWORD` - Password for authentication
  - `NAME` - Name of the repository to delete

## Access

- Web UI: http://localhost:8888
- SSH: localhost:2222
- API: http://localhost:8888/api/v1

## SSH Configuration for Passwordless Push

To push code without typing username/password, configure SSH authentication:

### 1. Add SSH Key to Gitea

First, add your SSH public key to your Gitea account:
- Go to http://localhost:8888
- Navigate to **Settings** → **SSH / GPG Keys**
- Click **Add Key** and paste your public key (usually `~/.ssh/id_rsa.pub` or `~/.ssh/id_ed25519.pub`)

### 2. Configure SSH Client

Add the following to your `~/.ssh/config` file:

```ssh-config
Host localhost
    HostName localhost
    Port 2222
    User git
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes
```

**Note:** Replace `~/.ssh/id_ed25519` with the path to your SSH private key if different (e.g., `~/.ssh/id_rsa`).

### 3. Configure Git Remote

Set up your git remote to use SSH. Replace `USERNAME` and `REPO_NAME` with your actual Gitea username and repository name:

```bash
git remote add local git@localhost:USERNAME/REPO_NAME.git
```

Or update an existing remote:

```bash
git remote set-url local git@localhost:USERNAME/REPO_NAME.git
```

**Example:**
```bash
git remote add local git@localhost:admin/gitea.git
```

### 4. Test SSH Connection

Verify SSH authentication works:

```bash
ssh -T git@localhost
```

You should see a message like:
```
Hi there, admin! You've successfully authenticated...
```

### 5. Push Code

Now you can push without entering credentials:

```bash
git push -u local HEAD
```

Or push to a specific branch:

```bash
git push -u local feature/split-scripts
```

**Troubleshooting:**
- If SSH connection fails, verify your SSH key is added to Gitea
- Check that port 2222 is accessible: `ssh -p 2222 git@localhost`
- Ensure your SSH config uses the correct IdentityFile path
- Verify the repository exists and you have push permissions

## Workaround Big git-lfs repository

When pushing large repositories with Git LFS, you may encounter errors about missing LFS objects in the commit history. This happens because Git LFS validates all objects referenced in the entire commit history being pushed, not just the current HEAD.

If you don't mind losing git history, you can create a new branch with no history and push only the current files:

### Create a Fresh Branch Without History

```bash
cd /path/to/your/repository

# Create a new orphan branch (no parent commits, no history)
git checkout --orphan fresh-start

# Remove all files from staging (they're still in your working directory)
git rm -rf --cached .

# Add all current files
git add .

# Create the initial commit
git commit -m "Initial commit - fresh start without history"

# Push to your local Gitea remote
git push -u local fresh-start
```

### Alternative: Push to a Different Branch Name

If you want to keep your current branch but push a fresh version:

```bash
cd /path/to/your/repository

# Create orphan branch with a specific name
git checkout --orphan master-clean

# Remove all tracked files from git index
git rm -rf --cached .

# Add everything back
git add .

# Commit
git commit -m "Fresh start - no history"

# Push to local remote
git push -u local master-clean
```

### What This Does

- Creates a new branch with no parent commits (orphan branch)
- Removes all files from Git's index
- Re-adds all current files as new
- Creates a single initial commit
- Pushes only that commit (no history)

### After Pushing

You'll have:
- A new branch on your Gitea remote with just one commit
- All your current files
- No git history (no old commits)
- No LFS history issues (since there's no history to validate)

You can then set this as your main branch or continue working from it. The old branch will remain locally but won't be pushed unless you explicitly push it.

**Note:** This procedure permanently discards all commit history. Make sure this is what you want before proceeding.

## Cleanup

To completely remove Gitea and all data:
```bash
make clean
```

This will stop the container and delete the `gitea-data` directory.

## Notes

- **All scripts are idempotent** - safe to run multiple times
- **No default values** - all parameters must be explicitly provided
- User creation requires Gitea to be initialized first (`make init-gitea`)
- Repository creation requires a user to exist first (`make create-user`)
- Data is persisted in the `gitea-data` directory
- Scripts will fail with clear error messages if required parameters are missing
