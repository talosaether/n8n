# n8n Deployment Checklist

Use this checklist to ensure proper deployment and configuration.

## Pre-Deployment Checklist

### Environment Setup
- [ ] Docker installed (version 20.10+)
- [ ] Docker Compose installed (version 2.0+)
- [ ] Git installed and configured
- [ ] Server meets minimum requirements (2GB RAM, 10GB disk)
- [ ] Firewall configured (if applicable)

### Configuration
- [ ] Copy `.env.example` to `.env`
- [ ] Set `HOST_IP` to your server's IP address
- [ ] Set `N8N_BASIC_AUTH_USER` (admin username)
- [ ] Set `N8N_BASIC_AUTH_PASSWORD` (strong password, 20+ chars)
- [ ] Verify no default passwords in `.env`
- [ ] Set file permissions: `chmod 600 .env`
- [ ] Review and adjust timezone (`GENERIC_TIMEZONE`)
- [ ] Configure webhook URL (`WEBHOOK_URL`)

### Script Preparation
- [ ] Verify all scripts are executable: `ls -la scripts/*.sh`
- [ ] Validate script syntax: `bash -n scripts/*.sh`
- [ ] Review deployment script: `cat scripts/deploy.sh`
- [ ] Understand rollback procedure

---

## Deployment Checklist

### Initial Deployment
- [ ] Review configuration one final time: `cat .env`
- [ ] Ensure no other service using port 5678: `netstat -tuln | grep 5678`
- [ ] Run deployment script: `./scripts/deploy.sh`
- [ ] Wait for deployment completion (60-90 seconds)
- [ ] Verify no errors in output
- [ ] Check deployment logs: `docker-compose logs`

### Post-Deployment Validation
- [ ] Run integration tests: `./scripts/integration-tests.sh`
- [ ] Verify all tests pass (15/15)
- [ ] Review test results: `cat test-results.log`
- [ ] Access n8n web interface: `http://YOUR_HOST_IP:5678`
- [ ] Test login with configured credentials
- [ ] Verify basic authentication works
- [ ] Test creating a simple workflow
- [ ] Test webhook functionality (if required)

### Backup Verification
- [ ] Verify backup was created: `ls -la backups/`
- [ ] Check backup contents: `ls -la backups/backup_*/`
- [ ] Verify backup size is reasonable
- [ ] Test backup script manually: `./scripts/backup.sh`
- [ ] Test backup listing: `./scripts/backup.sh list`

---

## CI/CD Setup Checklist (Optional)

### GitHub Repository Setup
- [ ] Repository created on GitHub
- [ ] Local repository connected to GitHub
- [ ] `.env` added to `.gitignore` (verify!)
- [ ] Push code to GitHub: `git push origin main`

### GitHub Secrets Configuration
- [ ] `DOCKER_USERNAME` - Docker Hub username
- [ ] `DOCKER_PASSWORD` - Docker Hub password/token
- [ ] `DEPLOY_HOST` - Server hostname/IP
- [ ] `DEPLOY_USER` - SSH username
- [ ] `SSH_PRIVATE_KEY` - SSH private key
- [ ] `HOST_IP` - Server IP address
- [ ] `N8N_USER` - n8n admin username
- [ ] `N8N_PASSWORD` - n8n admin password
- [ ] Verify all secrets: `gh secret list`

### SSH Setup for CI/CD
- [ ] Generate SSH key pair for deployment
- [ ] Add public key to server's `~/.ssh/authorized_keys`
- [ ] Test SSH connection manually
- [ ] Add private key to GitHub Secrets
- [ ] Verify deploy user has Docker permissions
- [ ] Verify deploy user can access `/opt/n8n` directory

### Pipeline Testing
- [ ] Create test branch
- [ ] Push to test branch
- [ ] Verify test workflow runs successfully
- [ ] Review workflow logs in GitHub Actions
- [ ] Fix any issues found
- [ ] Merge to main when ready
- [ ] Verify deploy workflow runs
- [ ] Check deployment on server

---

## Security Checklist

### Credentials
- [ ] Strong password used (20+ characters)
- [ ] Password includes uppercase, lowercase, numbers, symbols
- [ ] No default passwords in use
- [ ] Credentials stored securely in `.env`
- [ ] `.env` file permissions set to 600
- [ ] `.env` not committed to git

### Network Security
- [ ] Firewall configured (if applicable)
- [ ] Only required ports open (5678)
- [ ] Consider IP whitelisting
- [ ] HTTPS configured (for production - via reverse proxy)
- [ ] SSL certificate valid (for production)

### Container Security
- [ ] Running as non-root user (verify in Dockerfile)
- [ ] Base images up to date
- [ ] Security scanning enabled in CI/CD
- [ ] Container resource limits set (if needed)
- [ ] Restart policy configured (unless-stopped)

### Access Control
- [ ] SSH key authentication configured
- [ ] Password authentication disabled (recommended)
- [ ] Fail2ban installed (recommended)
- [ ] Regular security audits scheduled
- [ ] Access logs monitored

---

## Operational Checklist

### Daily Tasks
- [ ] Check container status: `docker ps`
- [ ] Review logs for errors: `docker-compose logs --tail=100`
- [ ] Monitor resource usage: `docker stats n8n`
- [ ] Verify backups are being created

### Weekly Tasks
- [ ] Run integration tests: `./scripts/integration-tests.sh`
- [ ] Review backup retention: `./scripts/backup.sh list`
- [ ] Check for n8n updates: `docker-compose pull`
- [ ] Review access logs
- [ ] Clean up old backups: `./scripts/backup.sh cleanup`

### Monthly Tasks
- [ ] Test restore procedure: `./scripts/restore.sh --latest` (in staging!)
- [ ] Review and rotate credentials (if needed)
- [ ] Security audit (review logs, access patterns)
- [ ] Update documentation (if changes made)
- [ ] Review disk space usage: `df -h`
- [ ] Review Docker volume usage: `docker system df`

### Quarterly Tasks
- [ ] Rotate passwords
- [ ] Update SSH keys (if needed)
- [ ] Full disaster recovery test
- [ ] Review and update firewall rules
- [ ] Audit user access and permissions

---

## Troubleshooting Checklist

### Container Won't Start
- [ ] Check logs: `docker-compose logs n8n`
- [ ] Verify port availability: `netstat -tuln | grep 5678`
- [ ] Check disk space: `df -h`
- [ ] Verify .env configuration: `cat .env`
- [ ] Try rebuilding: `docker-compose down && docker-compose up -d`

### Health Check Failing
- [ ] Check container status: `docker ps`
- [ ] Inspect health: `docker inspect n8n | grep -A 10 Health`
- [ ] Manual health check: `curl http://localhost:5678/healthz`
- [ ] Review container logs: `docker-compose logs --tail=50`

### Authentication Issues
- [ ] Verify credentials in .env: `grep AUTH .env`
- [ ] Test basic auth: `curl -u user:pass http://localhost:5678`
- [ ] Restart container: `docker-compose restart`
- [ ] Clear browser cache and try again

### Integration Tests Failing
- [ ] Review test results: `cat test-results.log`
- [ ] Check specific failing tests
- [ ] Verify container is running: `docker ps`
- [ ] Check network connectivity
- [ ] Verify environment variables: `docker exec n8n env`

### Deployment Script Fails
- [ ] Review deployment log: `cat deploy.log`
- [ ] Check pre-flight errors
- [ ] Verify .env file exists and is valid
- [ ] Check Docker daemon: `docker ps`
- [ ] Try manual rollback: `./scripts/deploy.sh --rollback`

---

## Rollback Checklist

### When to Rollback
- [ ] Health checks failing after deployment
- [ ] Integration tests failing
- [ ] Critical functionality broken
- [ ] Performance degradation detected
- [ ] Security issue identified

### Rollback Procedure
- [ ] Stop current deployment: `docker-compose down`
- [ ] Run rollback script: `./scripts/deploy.sh --rollback`
- [ ] Wait for rollback completion
- [ ] Run integration tests: `./scripts/integration-tests.sh`
- [ ] Verify functionality restored
- [ ] Document rollback reason
- [ ] Investigate root cause
- [ ] Plan fix before next deployment

### Alternative Rollback
- [ ] List available backups: `./scripts/backup.sh list`
- [ ] Select backup to restore
- [ ] Run restore: `./scripts/restore.sh`
- [ ] Follow restore prompts
- [ ] Verify restoration successful
- [ ] Test functionality

---

## Disaster Recovery Checklist

### Regular Backups
- [ ] Automated backups configured
- [ ] Backup retention policy set (30 days)
- [ ] Backups verified regularly
- [ ] Off-site backup configured (recommended)
- [ ] Backup encryption enabled (for sensitive data)

### Recovery Testing
- [ ] Test restore in staging environment
- [ ] Verify all data restored correctly
- [ ] Document recovery time
- [ ] Document any issues encountered
- [ ] Update recovery procedures if needed

### Disaster Scenarios
- [ ] Server failure - restore to new server
- [ ] Data corruption - restore from backup
- [ ] Accidental deletion - restore specific backup
- [ ] Security breach - investigate, rotate credentials, restore clean backup
- [ ] Complete loss - rebuild from documentation and latest off-site backup

---

## Maintenance Checklist

### Keep System Updated
- [ ] Monitor n8n release notes
- [ ] Test updates in staging first
- [ ] Create backup before updating
- [ ] Update Docker images: `docker-compose pull`
- [ ] Redeploy: `./scripts/deploy.sh`
- [ ] Verify functionality after update

### Monitor Performance
- [ ] Track response times
- [ ] Monitor CPU and memory usage
- [ ] Check disk I/O performance
- [ ] Review workflow execution times
- [ ] Optimize slow workflows

### Documentation
- [ ] Keep deployment docs updated
- [ ] Document any custom configurations
- [ ] Maintain runbook for common issues
- [ ] Update contact information
- [ ] Document escalation procedures

---

## Compliance Checklist (If Applicable)

### Data Protection
- [ ] Data backup procedures documented
- [ ] Data retention policy defined
- [ ] Data encryption at rest (if required)
- [ ] Data encryption in transit (HTTPS)
- [ ] Access logs maintained

### Audit Trail
- [ ] Access logs enabled
- [ ] Change logs maintained
- [ ] Deployment history tracked (Git)
- [ ] Backup history maintained
- [ ] Security events logged

### Access Control
- [ ] User access documented
- [ ] Role-based access control configured
- [ ] Regular access reviews scheduled
- [ ] Terminated user access revoked
- [ ] Privileged access monitored

---

## Sign-Off Checklist

### Deployment Approval
- [ ] Deployment plan reviewed
- [ ] Rollback plan documented
- [ ] Stakeholders notified
- [ ] Change window scheduled
- [ ] Backup verified

### Post-Deployment
- [ ] All tests passed
- [ ] Functionality verified
- [ ] Performance acceptable
- [ ] No errors in logs
- [ ] Stakeholders notified
- [ ] Documentation updated
- [ ] Deployment recorded

### Sign-Off
- [ ] Deployed by: _________________ Date: _______
- [ ] Verified by: _________________ Date: _______
- [ ] Approved by: _________________ Date: _______

---

## Quick Reference

### Essential Commands
```bash
# Deploy
./scripts/deploy.sh

# Rollback
./scripts/deploy.sh --rollback

# Test
./scripts/integration-tests.sh

# Backup
./scripts/backup.sh

# Restore
./scripts/restore.sh

# Logs
docker-compose logs -f

# Status
docker-compose ps
```

### Essential Files
- `.env` - Configuration
- `docker-compose.yml` - Service definition
- `DEPLOYMENT.md` - Full documentation
- `scripts/` - Automation scripts

### Support Resources
- Documentation: `DEPLOYMENT.md`
- Summary: `DEPLOYMENT_SUMMARY.md`
- Script Help: `scripts/README.md`
- GitHub Setup: `.github/GITHUB_SECRETS_SETUP.md`

---

**Last Updated**: 2025-09-30
