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
