# n8n Docker Deployment

This Docker setup allows you to run n8n on an Ubuntu VM without modifying host configuration files.

## Prerequisites

- Docker installed on your Ubuntu VM
- Docker Compose installed

## Quick Start

1. **Build and start n8n:**
   ```bash
   docker-compose up -d
   ```

2. **Access n8n:**
   - Open your browser and navigate to: `http://YOUR_HOST_IP:5678`
   - Default credentials (CHANGE THESE!):
     - Username: `admin`
     - Password: `changeme123`

## Configuration

### Change Default Credentials

Edit `docker-compose.yml` and modify:
```yaml
- N8N_BASIC_AUTH_USER=your_username
- N8N_BASIC_AUTH_PASSWORD=your_secure_password
```

### Set Webhook URL

For webhooks to work properly, update the `WEBHOOK_URL` in `docker-compose.yml`:
```yaml
- WEBHOOK_URL=http://YOUR_HOST_IP:5678/
```

### Change Port

To use a different port, modify the port mapping in `docker-compose.yml`:
```yaml
ports:
  - "8080:5678"  # HOST_PORT:CONTAINER_PORT
```

## Docker Commands

- **Start n8n:** `docker-compose up -d`
- **Stop n8n:** `docker-compose down`
- **View logs:** `docker-compose logs -f`
- **Restart n8n:** `docker-compose restart`
- **Rebuild image:** `docker-compose build --no-cache`

## Data Persistence

All n8n data (workflows, credentials, executions) is stored in a Docker volume named `n8n_data`. This ensures your data persists across container restarts and updates.

## Networking

The container uses bridge networking and exposes port 5678 (default n8n port) to the host. You can access n8n from:
- Localhost: `http://localhost:5678`
- Host IP: `http://HOST_IP:5678`
- Other machines on network: `http://HOST_IP:5678`

## Security Notes

1. **Change default credentials** immediately after first deployment
2. Consider using HTTPS with a reverse proxy (nginx/traefik) for production
3. Restrict access using firewall rules if needed
4. Keep n8n updated regularly

## Updating n8n

1. Pull the latest image:
   ```bash
   docker-compose pull
   docker-compose up -d
   ```

2. Or rebuild from scratch:
   ```bash
   docker-compose down
   docker-compose build --no-cache
   docker-compose up -d
   ```