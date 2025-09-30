# GitHub Secrets Setup Guide

This guide explains how to configure GitHub Secrets for the CI/CD pipeline.

## Required Secrets

### Docker Hub Credentials

These secrets are required to push Docker images to your registry.

1. **DOCKER_USERNAME**
   - Your Docker Hub username
   - Example: `myusername`

2. **DOCKER_PASSWORD**
   - Your Docker Hub password or access token (recommended)
   - To create an access token:
     1. Go to https://hub.docker.com/settings/security
     2. Click "New Access Token"
     3. Give it a name (e.g., "GitHub Actions")
     4. Copy the token

### Deployment Server SSH

These secrets are required for automated deployment to your server.

3. **DEPLOY_HOST**
   - Your server's hostname or IP address
   - Example: `192.168.1.100` or `n8n.example.com`

4. **DEPLOY_USER**
   - SSH username for deployment
   - Example: `ubuntu` or `deploy`

5. **SSH_PRIVATE_KEY**
   - Your SSH private key for authentication
   - To generate a new key pair:
     ```bash
     ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_deploy
     ```
   - Copy the **private key** (entire file):
     ```bash
     cat ~/.ssh/github_deploy
     ```
   - Add the **public key** to your server:
     ```bash
     ssh-copy-id -i ~/.ssh/github_deploy.pub user@your-server
     ```

### n8n Configuration

These secrets configure your n8n instance.

6. **HOST_IP**
   - Your server's external IP address
   - Example: `192.168.1.100`

7. **N8N_USER**
   - n8n admin username
   - Example: `admin`

8. **N8N_PASSWORD**
   - n8n admin password
   - **Use a strong password (20+ characters)**
   - Example: Generate with: `openssl rand -base64 32`

## How to Add Secrets to GitHub

### Method 1: Via Web Interface

1. Go to your GitHub repository
2. Click **Settings** tab
3. Click **Secrets and variables** → **Actions** in the left sidebar
4. Click **New repository secret**
5. Enter the **Name** and **Value**
6. Click **Add secret**
7. Repeat for all secrets

### Method 2: Via GitHub CLI

```bash
# Install GitHub CLI if not already installed
# https://cli.github.com/

# Authenticate
gh auth login

# Add secrets
gh secret set DOCKER_USERNAME -b"your_username"
gh secret set DOCKER_PASSWORD -b"your_password"
gh secret set DEPLOY_HOST -b"192.168.1.100"
gh secret set DEPLOY_USER -b"ubuntu"
gh secret set SSH_PRIVATE_KEY < ~/.ssh/github_deploy
gh secret set HOST_IP -b"192.168.1.100"
gh secret set N8N_USER -b"admin"
gh secret set N8N_PASSWORD -b"your_secure_password"
```

## Verification

After adding all secrets, verify they're configured:

```bash
# List all secrets (values are hidden)
gh secret list
```

Expected output:
```
DEPLOY_HOST
DEPLOY_USER
DOCKER_PASSWORD
DOCKER_USERNAME
HOST_IP
N8N_PASSWORD
N8N_USER
SSH_PRIVATE_KEY
```

## Environment-Specific Secrets (Optional)

If you use multiple environments (production, staging), you can configure environment-specific secrets:

1. Go to **Settings** → **Environments**
2. Create environments: `production`, `staging`, `development`
3. Add environment-specific secrets to each

Then reference them in workflow:
```yaml
environment:
  name: production
```

## Security Best Practices

1. **Never commit secrets** to your repository
2. **Use strong passwords** (20+ characters)
3. **Rotate secrets** regularly (quarterly)
4. **Use SSH keys** instead of passwords where possible
5. **Limit secret scope** to only required workflows
6. **Review secret access** in audit logs regularly
7. **Use read-only tokens** when possible

## Troubleshooting

### Workflow fails with "Secret not found"

**Solution:** Verify the secret name matches exactly (case-sensitive):
```bash
gh secret list
```

### SSH authentication fails

**Solution:**
1. Verify the private key format is correct (includes `-----BEGIN ... KEY-----`)
2. Ensure public key is added to server's `~/.ssh/authorized_keys`
3. Test SSH connection manually:
   ```bash
   ssh -i ~/.ssh/github_deploy user@host
   ```

### Docker push fails

**Solution:**
1. Verify Docker Hub credentials are correct
2. Use access token instead of password
3. Ensure Docker Hub repository exists and is accessible

### Deployment fails with permission issues

**Solution:**
1. Ensure deploy user has Docker permissions:
   ```bash
   sudo usermod -aG docker $DEPLOY_USER
   ```
2. Verify deploy user can write to `/opt/n8n`:
   ```bash
   sudo chown -R $DEPLOY_USER:$DEPLOY_USER /opt/n8n
   ```

## Testing Secrets

Before deploying to production, test your workflow:

1. Create a test branch
2. Push changes to test branch
3. Monitor workflow execution in Actions tab
4. Verify each step completes successfully
5. If successful, merge to main for production deployment

## Secret Rotation

Plan to rotate secrets regularly:

### Monthly:
- Review access logs
- Check for unauthorized access

### Quarterly:
- Rotate passwords
- Update SSH keys if needed

### Annually:
- Full security audit
- Update all secrets

### After Team Changes:
- Rotate all secrets when team members leave
- Review access permissions

---

**Last Updated**: 2025-09-30
