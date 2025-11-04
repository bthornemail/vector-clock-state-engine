#!/bin/bash
# Docker wrapper script for MCP Server
# This script allows MCP clients to connect to the Docker container via stdio

CONTAINER_NAME="mcp-server"

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Error: Container '${CONTAINER_NAME}' is not running" >&2
    echo "Start it with: docker start ${CONTAINER_NAME} or docker-compose up -d" >&2
    exit 1
fi

# Execute MCP server in container, forwarding stdio
exec docker exec -i "${CONTAINER_NAME}" racket /app/racket-mcp/src/mcp-server.rkt "$@"
