---
name: disk-cleanup
description: "Free disk space on the host by removing unused Docker images, containers, volumes, and system packages. Use when: disk is running low, after updating MCP servers, clearing old Docker build cache."
---

# Skill: disk-cleanup

Automate disk cleanup on Linux systems (tested on Ubuntu 24.04), focusing on
removing unused packages, Docker/containerd data, and old log files. Also
identifies large files for manual review.

---

## When to run

- Disk space is running low (`df -h` shows high usage)
- After running `update-mcp-servers` (old image layers accumulate)
- After a large number of Docker builds
- Routine maintenance before a new machine bootstrap

---

## Procedure

### Step 1 — Remove unused packages and cache

```bash
sudo apt autoremove -y
sudo apt clean
sudo apt-get autoclean -y
```

### Step 2 — Prune Docker and containerd data

```bash
docker system prune -a -f      # Remove all unused Docker data (images, containers, networks)
docker volume prune -f          # Remove unused Docker volumes
```

> **DANGEROUS — only if you need the space and know what you are removing:**
>
> ```bash
> sudo rm -rf /var/lib/containerd/io.containerd.content.v1.content/*
> ```
>
> This removes all containerd images. Ensure all containers are stopped and
> images are not needed before running.

### Step 3 — Clean log files

```bash
sudo journalctl --vacuum-time=7d          # Keep only 7 days of logs
sudo rm -rf /var/log/*.gz /var/log/*.[0-9] # Remove old rotated logs
sudo rm -rf /var/log/journal/*             # Remove persistent journal logs
```

### Step 4 — Identify large files/directories

Use these to find what is consuming the most space:

```bash
sudo du -ahx / | sort -rh | head -30          # 30 largest files/dirs (may fail if disk is full)
sudo du -hxd1 /var /home /usr | sort -hr       # Largest subdirs in key locations
```

---

## Usage

Run each command step-by-step, reviewing output before deleting. Or run all at once
(skip the dangerous containerd step unless certain):

```bash
#!/bin/bash
set -e

# 1. Remove unused packages and cache
sudo apt autoremove -y
sudo apt clean
sudo apt-get autoclean -y

# 2. Prune Docker data
docker system prune -a -f
docker volume prune -f
# Uncomment ONLY if you want to remove ALL containerd images:
# sudo rm -rf /var/lib/containerd/io.containerd.content.v1.content/*

# 3. Clean log files
sudo journalctl --vacuum-time=7d
sudo rm -rf /var/log/*.gz /var/log/*.[0-9]
sudo rm -rf /var/log/journal/*

# 4. Identify large files/directories
sudo du -ahx / | sort -rh | head -30
sudo du -hxd1 /var /home /usr | sort -hr
```

---

## Notes

- Always review what will be deleted, especially containerd and journal paths.
- For production systems, back up important data before running destructive commands.
- Most commands are Ubuntu/Debian-specific (`apt`); Docker and log cleanup steps apply broadly.
- After pruning Docker images, run `bootstrap.sh --force` to rebuild MCP server images.
