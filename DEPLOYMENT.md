# n8n Deployment Guide

Complete guide for deploying, testing, and managing your n8n instance.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Scripts](#deployment-scripts)
- [Integration Tests](#integration-tests)
- [Backup and Restore](#backup-and-restore)
- [CI/CD Pipeline](#cicd-pipeline)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)

---

## Prerequisites

### Required Software
- Docker (version 20.10+)
- Docker Compose (version 2.0+)
- Git
- Bash (for automation scripts)

### System Requirements
- Minimum 2GB RAM
- 10GB free disk space
- Ubuntu 20.04+ or similar Linux distribution

---

## Quick Start

### 1. Initial Configuration

Copy the example environment file and configure your settings:

```bash
cp .env.example .env
nano .env
```

**Critical settings to update:**
- `HOST_IP`: Your server's IP address
- `N8N_BASIC_AUTH_USER`: Your admin username
- `N8N_BASIC_AUTH_PASSWORD`: Strong password (REQUIRED)

### 2. Deploy n8n

Use the automated deployment script:

```bash
./scripts/deploy.sh
```

This script will:
- Run pre-flight checks
- Create a backup
- Pull latest images
- Deploy n8n
- Run health checks
- Automatic rollback on failure

### 3. Verify Deployment

Access n8n:
- Local: `http://localhost:5678`
- Network: `http://YOUR_HOST_IP:5678`

---

## Deployment Scripts

### Deploy Script (`scripts/deploy.sh`)

**Main deployment automation with rollback support.**

#### Usage:
```bash
# Deploy n8n
./scripts/deploy.sh

# Rollback to previous deployment
./scripts/deploy.sh --rollback

# Show help
./scripts/deploy.sh --help
```

#### Features:
- Pre-flight validation
- Automatic backup before deployment
- Health check validation
- Automatic rollback on failure
- Idempotent operations
- Keeps last 10 backups

#### Exit Codes:
- `0`: Success
- `1`: Failure (deployment rolled back)

---

## Integration Tests

### Test Script (`scripts/integration-tests.sh`)

**Comprehensive post-deployment validation suite.**

#### Usage:
```bash
./scripts/integration-tests.sh
```

#### Tests Performed:

1. **Container Health**
   - Container running status
   - Health check status
   - Restart policy validation

2. **Network & Connectivity**
   - HTTP endpoint reachability
   - Port binding verification
   - Network configuration
   - Response time measurement

3. **Security**
   - Basic authentication enforcement
   - API endpoint accessibility
   - Environment variable validation

4. **Resource Management**
   - CPU usage monitoring
   - Memory usage monitoring
   - Volume persistence

5. **Application Health**
   - /healthz endpoint
   - Container logs analysis
   - Webhook configuration

#### Test Results:
Results are saved to `test-results.log` with detailed pass/fail information.

#### Exit Codes:
- `0`: All tests passed
- `1`: One or more tests failed

---

## Backup and Restore

### Backup Script (`scripts/backup.sh`)

**Automated backup of n8n data and configuration.**

#### Usage:
```bash
# Create a new backup
./scripts/backup.sh
./scripts/backup.sh create

# List all backups
./scripts/backup.sh list

# Cleanup old backups
./scripts/backup.sh cleanup
```

#### What Gets Backed Up:
- Environment configuration (`.env`)
- Docker Compose configuration
- Dockerfile
- n8n data volume (all workflows, credentials, executions)
- SQLite database
- Container image information

#### Backup Location:
`./backups/backup_YYYYMMDD_HHMMSS/`

#### Retention Policy:
Backups older than 30 days are automatically removed.

### Restore Script (`scripts/restore.sh`)

**Restore n8n from a backup.**

#### Usage:
```bash
# Interactive restore (select from list)
./scripts/restore.sh

# Restore from specific backup
./scripts/restore.sh /path/to/backups/backup_20250101_120000

# Restore latest backup
./scripts/restore.sh --latest
```

#### Warning:
Restore will **stop the current deployment** and **replace all data**. Use with caution!

---

## CI/CD Pipeline

### GitHub Actions Workflows

Two workflows are configured for automated testing and deployment:

#### 1. Test Workflow (`.github/workflows/test.yml`)

**Triggers:**
- Pull requests to main/master
- Pushes to non-main branches
- Daily scheduled runs (2 AM UTC)

**Jobs:**
- **Lint**: Validates configuration files and scripts
- **Build**: Builds Docker image
- **Integration Test**: Runs full test suite
- **Security Scan**: Trivy vulnerability scanning
- **Deployment Test**: Validates deployment scripts

#### 2. Deploy Workflow (`.github/workflows/deploy.yml`)

**Triggers:**
- Push to main/master branch
- Manual workflow dispatch

**Jobs:**
- **Test**: Runs integration tests
- **Build**: Builds and pushes Docker image to registry
- **Deploy**: Deploys to server via SSH
- **Notify**: Sends deployment notifications

### Required GitHub Secrets

Configure these secrets in your repository settings:

**Docker Hub:**
- `DOCKER_USERNAME`: Docker Hub username
- `DOCKER_PASSWORD`: Docker Hub password/token

**Deployment Server:**
- `DEPLOY_HOST`: Server hostname/IP
- `DEPLOY_USER`: SSH user
- `SSH_PRIVATE_KEY`: SSH private key for authentication

**n8n Configuration:**
- `HOST_IP`: Server IP address
- `N8N_USER`: n8n admin username
- `N8N_PASSWORD`: n8n admin password

### Manual Deployment via GitHub Actions

1. Go to Actions tab in your GitHub repository
2. Select "Deploy n8n" workflow
3. Click "Run workflow"
4. Select environment (production/staging/development)
5. Click "Run workflow" button

---

## Monitoring and Maintenance

### Health Check Endpoint

n8n provides a health check endpoint:

```bash
curl http://localhost:5678/healthz
```

Expected response: HTTP 200 OK

### View Logs

```bash
# View all logs
docker-compose logs -f

# View last 100 lines
docker-compose logs --tail=100

# View specific timeframe
docker-compose logs --since 1h
```

### Check Resource Usage

```bash
# Container stats
docker stats n8n

# Disk usage
docker system df
```

### Regular Maintenance Tasks

**Daily:**
- Check logs for errors
- Monitor resource usage
- Verify backups are being created

**Weekly:**
- Review backup retention
- Check for n8n updates
- Review security logs

**Monthly:**
- Test restore procedure
- Review and update credentials
- Security audit

---

## Troubleshooting

### Container Won't Start

**Check logs:**
```bash
docker-compose logs n8n
```

**Common issues:**
- Port 5678 already in use
- Insufficient memory
- Corrupted volume data

**Solution:**
```bash
# Stop and remove containers
docker-compose down

# Remove volumes (WARNING: deletes data)
docker volume rm n8n_data

# Restore from backup
./scripts/restore.sh --latest
```

### Health Check Failing

**Verify container is running:**
```bash
docker ps | grep n8n
```

**Check health status:**
```bash
docker inspect n8n | grep -A 10 Health
```

**Manual health check:**
```bash
curl -v http://localhost:5678/healthz
```

### Authentication Issues

**Verify credentials in .env:**
```bash
grep AUTH .env
```

**Reset password:**
1. Edit `.env` file
2. Update `N8N_BASIC_AUTH_PASSWORD`
3. Restart: `docker-compose restart`

### Deployment Script Fails

**Check pre-flight requirements:**
```bash
# Verify .env exists and has required variables
cat .env

# Check for default password
grep "changeme123" .env

# Verify Docker is running
docker ps
```

**Manual rollback:**
```bash
./scripts/deploy.sh --rollback
```

### Data Loss / Corruption

**Restore from backup:**
```bash
# List available backups
./scripts/backup.sh list

# Restore specific backup
./scripts/restore.sh /path/to/backup
```

### Performance Issues

**Check resource limits:**
```bash
# CPU and memory usage
docker stats n8n

# Adjust Docker resources in daemon.json
```

**Optimize execution settings:**
Edit `.env`:
```bash
EXECUTIONS_TIMEOUT=1800      # Reduce from 3600
EXECUTIONS_TIMEOUT_MAX=3600  # Reduce from 7200
```

---

## Security Best Practices

### 1. Strong Passwords

- Use passwords with 20+ characters
- Mix uppercase, lowercase, numbers, symbols
- Never use default passwords
- Rotate passwords quarterly

### 2. Network Security

**Use HTTPS in production:**
- Deploy reverse proxy (nginx/traefik)
- Obtain SSL certificate (Let's Encrypt)
- Force HTTPS redirect

**Firewall rules:**
```bash
# Allow only specific IPs
sudo ufw allow from YOUR_IP to any port 5678
sudo ufw enable
```

### 3. Environment Variables

- Never commit `.env` to version control
- Use secrets management (GitHub Secrets, Vault)
- Restrict file permissions:
  ```bash
  chmod 600 .env
  ```

### 4. Regular Updates

```bash
# Pull latest n8n image
docker-compose pull

# Deploy with automatic backup
./scripts/deploy.sh
```

### 5. Backup Encryption

**Encrypt sensitive backups:**
```bash
# Encrypt backup
tar czf - backups/backup_20250101_120000 | gpg -c > backup.tar.gz.gpg

# Decrypt backup
gpg -d backup.tar.gz.gpg | tar xzf -
```

### 6. Access Control

- Limit SSH access to deployment server
- Use SSH keys instead of passwords
- Implement fail2ban for brute force protection
- Regular security audits

### 7. Container Security

- Run containers as non-root user (already configured)
- Keep base images updated
- Scan for vulnerabilities (Trivy in CI/CD)
- Limit container capabilities

### 8. Monitoring & Alerting

**Set up alerts for:**
- Failed deployments
- High resource usage
- Failed authentication attempts
- Service downtime

### 9. Disaster Recovery

**Test your DR plan:**
1. Schedule quarterly DR tests
2. Document recovery procedures
3. Maintain off-site backups
4. Verify backup integrity

---

## Quick Reference

### Common Commands

```bash
# Deploy
./scripts/deploy.sh

# Rollback
./scripts/deploy.sh --rollback

# Run tests
./scripts/integration-tests.sh

# Create backup
./scripts/backup.sh

# Restore backup
./scripts/restore.sh

# View logs
docker-compose logs -f

# Restart
docker-compose restart

# Stop
docker-compose down

# Start
docker-compose up -d
```

### File Locations

```
/home/fnuser/dev/repos/n8n/
├── .env                          # Environment configuration
├── .env.example                  # Example configuration
├── docker-compose.yml            # Docker Compose config
├── Dockerfile                    # Docker image definition
├── README.md                     # Basic documentation
├── DEPLOYMENT.md                 # This file
├── backups/                      # Backup directory
│   └── backup_YYYYMMDD_HHMMSS/  # Individual backups
├── scripts/                      # Automation scripts
│   ├── deploy.sh                # Deployment script
│   ├── integration-tests.sh     # Test suite
│   ├── backup.sh                # Backup script
│   └── restore.sh               # Restore script
└── .github/workflows/            # CI/CD pipelines
    ├── deploy.yml               # Deployment workflow
    └── test.yml                 # Test workflow
```

---

## Support

### Resources

- **n8n Documentation**: https://docs.n8n.io
- **n8n Community**: https://community.n8n.io
- **Docker Documentation**: https://docs.docker.com

### Getting Help

1. Check logs: `docker-compose logs -f`
2. Run integration tests: `./scripts/integration-tests.sh`
3. Review this documentation
4. Check GitHub Actions logs (if using CI/CD)
5. Visit n8n community forum

---

## Version History

- **2025-09-30**: Initial deployment automation and documentation
  - Automated deployment scripts
  - Integration test suite
  - Backup/restore functionality
  - CI/CD pipelines
  - Comprehensive documentation

---

**Last Updated**: 2025-09-30
