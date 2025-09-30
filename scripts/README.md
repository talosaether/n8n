# n8n Deployment Scripts

Automated deployment, testing, backup, and restore scripts for n8n.

## Quick Start

```bash
# Deploy n8n
./deploy.sh

# Run tests
./integration-tests.sh

# Create backup
./backup.sh

# Restore backup
./restore.sh
```

## Scripts Overview

### 🚀 deploy.sh
**Idempotent deployment with automatic rollback**

```bash
./deploy.sh              # Deploy n8n
./deploy.sh --rollback   # Rollback to previous deployment
./deploy.sh --help       # Show help
```

**What it does:**
1. Pre-flight checks (Docker, env, credentials)
2. Creates backup
3. Pulls latest images
4. Deploys containers
5. Validates health
6. Auto-rollback on failure

---

### ✅ integration-tests.sh
**15 comprehensive integration tests**

```bash
./integration-tests.sh
```

**Tests:**
- Container status and health
- HTTP endpoints and API
- Authentication and security
- Resource usage and performance
- Network and configuration
- Logs and error detection

**Output:** Results saved to `../test-results.log`

---

### 💾 backup.sh
**Automated backup with retention**

```bash
./backup.sh              # Create backup
./backup.sh list         # List all backups
./backup.sh cleanup      # Remove old backups (30+ days)
./backup.sh --help       # Show help
```

**Backs up:**
- Environment configuration
- Docker Compose files
- n8n data volume (all workflows, credentials)
- Database files
- Container metadata

**Location:** `../backups/backup_YYYYMMDD_HHMMSS/`

---

### 🔄 restore.sh
**Interactive and automated restore**

```bash
./restore.sh                    # Interactive mode
./restore.sh --latest           # Restore latest backup
./restore.sh /path/to/backup    # Restore specific backup
./restore.sh --help             # Show help
```

**Process:**
1. Lists available backups
2. Confirmation prompt
3. Stops current deployment
4. Restores all data and config
5. Starts n8n
6. Validates health

---

## Prerequisites

All scripts require:
- Docker (20.10+)
- Docker Compose (2.0+)
- Bash
- curl (for testing)
- bc (for calculations)

## Environment Variables

Scripts read from `../.env`:
- `HOST_IP` - Server IP address
- `N8N_BASIC_AUTH_USER` - Admin username
- `N8N_BASIC_AUTH_PASSWORD` - Admin password
- `N8N_PORT` - n8n port (default: 5678)

## Exit Codes

All scripts follow standard exit codes:
- `0` - Success
- `1` - Failure

## Logging

Scripts provide colored output:
- 🟢 **GREEN** - Info/Success
- 🟡 **YELLOW** - Warnings
- 🔴 **RED** - Errors

## Automation

### Cron Examples

```bash
# Daily backup at 2 AM
0 2 * * * /opt/n8n/scripts/backup.sh >> /var/log/n8n-backup.log 2>&1

# Weekly integration tests
0 3 * * 0 /opt/n8n/scripts/integration-tests.sh >> /var/log/n8n-tests.log 2>&1

# Daily cleanup old backups
0 4 * * * /opt/n8n/scripts/backup.sh cleanup >> /var/log/n8n-cleanup.log 2>&1
```

### Systemd Service

Create `/etc/systemd/system/n8n-backup.service`:

```ini
[Unit]
Description=n8n Backup Service
After=docker.service

[Service]
Type=oneshot
WorkingDirectory=/opt/n8n
ExecStart=/opt/n8n/scripts/backup.sh
User=n8n
Group=n8n

[Install]
WantedBy=multi-user.target
```

Create `/etc/systemd/system/n8n-backup.timer`:

```ini
[Unit]
Description=n8n Backup Timer
Requires=n8n-backup.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

Enable:
```bash
sudo systemctl enable n8n-backup.timer
sudo systemctl start n8n-backup.timer
```

## CI/CD Integration

These scripts are designed for both manual and CI/CD use:

```yaml
# GitHub Actions example
- name: Deploy n8n
  run: ./scripts/deploy.sh

- name: Run Integration Tests
  run: ./scripts/integration-tests.sh

- name: Create Backup
  run: ./scripts/backup.sh
```

## Troubleshooting

### Permission Denied
```bash
chmod +x scripts/*.sh
```

### Docker Permission Issues
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

### Script Fails to Find .env
```bash
# Ensure .env exists in project root
ls -la ../.env

# Create from example
cp ../.env.example ../.env
```

### Backup/Restore Fails
```bash
# Check disk space
df -h

# Check Docker volumes
docker volume ls

# Check permissions
ls -la ../backups/
```

## Best Practices

1. **Always test in staging** before production
2. **Run integration tests** after every deployment
3. **Create backups** before major changes
4. **Test restore** procedures regularly
5. **Monitor logs** for issues
6. **Keep scripts updated** with project changes

## Security Notes

- Scripts never print passwords to logs
- Backups contain sensitive data - secure them
- Use `.env` file permissions: `chmod 600 ../.env`
- Review logs for unauthorized access attempts

## Support

For detailed documentation, see:
- [DEPLOYMENT.md](../DEPLOYMENT.md) - Complete deployment guide
- [README.md](../README.md) - Quick start guide
- [DEPLOYMENT_SUMMARY.md](../DEPLOYMENT_SUMMARY.md) - Implementation summary

## Version History

- **2025-09-30**: Initial release
  - deploy.sh v1.0 - Deployment automation
  - integration-tests.sh v1.0 - 15 tests
  - backup.sh v1.0 - Automated backups
  - restore.sh v1.0 - Interactive restore

---

**Last Updated**: 2025-09-30
