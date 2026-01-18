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
- `make create-repo` - Create repository (**requires** USERNAME, PASSWORD, and NAME env vars)

## Examples

### Create a user with custom credentials:
```bash
USERNAME=john PASSWORD=secret123 make create-user
```

### Create a repository with custom name:
```bash
USERNAME=admin PASSWORD=yourpassword NAME=my-project make create-repo
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

- `create-repo` requires:
  - `USERNAME` - Username of the user who owns the repository
  - `PASSWORD` - Password for authentication
  - `NAME` - Name of the repository to create

## Access

- Web UI: http://localhost:8888
- SSH: localhost:2222
- API: http://localhost:8888/api/v1

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
