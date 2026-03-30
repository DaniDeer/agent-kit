# Disk Cleanup Skill

## Purpose

Automate disk cleanup on Linux systems (tested on Ubuntu 24.04), focusing on:

- Removing unused packages and cache
- Pruning Docker and containerd data
- Cleaning log files
- Identifying and suggesting large files/directories for manual review

## Steps

### 1. Remove Unused Packages and Cache

- `sudo apt autoremove -y`
- `sudo apt clean`
- `sudo apt-get autoclean -y`

### 2. Prune Docker and Containerd Data

- `docker system prune -a -f` # Remove unused Docker data
- `docker volume prune -f` # Remove unused Docker volumes
- (Optional, DANGEROUS) `sudo rm -rf /var/lib/containerd/io.containerd.content.v1.content/*` # Remove all containerd images

### 3. Clean Log Files

- `sudo journalctl --vacuum-time=7d` # Keep only 7 days of logs
- `sudo rm -rf /var/log/*.gz /var/log/*.[0-9]` # Remove old rotated logs
- `sudo rm -rf /var/log/journal/*` # Remove persistent journal logs (if not needed)

### 4. Identify Large Files/Directories

- `sudo du -ahx / | sort -rh | head -30` # List 30 largest files/dirs (may fail if disk is full)
- `sudo du -hxd1 /var /home /usr | sort -hr` # List largest subdirs in key locations

## Usage

- Run each command step-by-step, reviewing output before deleting critical data.
- For containerd cleanup, ensure all containers are stopped and images are not needed.
- For log cleanup, ensure compliance with any log retention policies.

## Example Script

```bash
#!/bin/bash
set -e

# 1. Remove unused packages and cache
sudo apt autoremove -y
sudo apt clean
sudo apt-get autoclean -y

# 2. Prune Docker and containerd data
sudo docker system prune -a -f
sudo docker volume prune -f
# Uncomment the next line ONLY if you want to remove ALL containerd images
# sudo rm -rf /var/lib/containerd/io.containerd.content.v1.content/*

# 3. Clean log files
sudo journalctl --vacuum-time=7d
sudo rm -rf /var/log/*.gz /var/log/*.[0-9]
sudo rm -rf /var/log/journal/*

# 4. Identify large files/directories
sudo du -ahx / | sort -rh | head -30
sudo du -hxd1 /var /home /usr | sort -hr
```

## Notes

- Always review what will be deleted, especially in /var/lib/containerd and /var/log.
- For production systems, consider backing up important data before running destructive commands.
- This skill is intended for Linux VM maintenance and troubleshooting low disk space situations.
- Most commands are Ubuntu/Debian-specific (apt), but log and Docker cleanup steps are similar on other Linux distros.
