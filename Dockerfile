FROM node:18-bookworm-slim

# Set n8n version (you can update this to pin a specific version)
ARG N8N_VERSION=latest

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install n8n globally
RUN if [ "$N8N_VERSION" = "latest" ]; then \
        npm install -g n8n; \
    else \
        npm install -g n8n@${N8N_VERSION}; \
    fi

# Create data directory and set ownership
RUN mkdir -p /home/node/.n8n && \
    chown -R node:node /home/node

# Set working directory
WORKDIR /home/node

# Run as node user for security
USER node

# Set environment variables with sane defaults
ENV N8N_HOST=0.0.0.0
ENV N8N_PORT=5678
ENV N8N_PROTOCOL=http
ENV WEBHOOK_URL=http://localhost:5678/
ENV GENERIC_TIMEZONE=UTC
ENV N8N_LOG_LEVEL=info

# Expose n8n default port
EXPOSE 5678

# Start n8n
CMD ["n8n"]