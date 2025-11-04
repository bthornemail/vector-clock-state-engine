# Docker Setup for MCP Server

This directory contains Docker configuration for running the Computational Scheme Theory MCP Server.

## Quick Start

### Build the Image

```bash
cd /path/to/vector-clock-state-engine
docker build -t cst-mcp-server -f racket-mcp/Dockerfile .
```

### Run the Container

The MCP server communicates via stdio, so you'll typically run it interactively or attach to it:

```bash
# Run interactively (for testing)
docker run -it --rm cst-mcp-server

# Run in background (for MCP client attachment)
docker run -d --name mcp-server cst-mcp-server
docker attach mcp-server
```

### Using Docker Compose

```bash
cd racket-mcp
docker-compose up -d
docker-compose attach mcp-server
```

## Integration with MCP Clients

### Claude Desktop / Cursor

To use the Docker container with Claude Desktop or Cursor, you'll need to configure the MCP client to connect to the container. Since MCP uses stdio, you'll need to:

1. Run the container with stdio attached
2. Configure your MCP client to execute: `docker exec -i mcp-server racket /app/racket-mcp/src/mcp-server.rkt`

Or use a wrapper script:

```bash
#!/bin/bash
# mcp-docker-wrapper.sh
docker exec -i mcp-server racket /app/racket-mcp/src/mcp-server.rkt
```

Then configure your MCP client with:
```json
{
  "mcpServers": {
    "computational-scheme": {
      "command": "/path/to/mcp-docker-wrapper.sh",
      "args": []
    }
  }
}
```

### Direct Container Execution

For development/testing, you can also run commands directly:

```bash
# Test initialize
echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}' | \
  docker exec -i mcp-server racket /app/racket-mcp/src/mcp-server.rkt

# List tools
(echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}'; \
 echo '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}') | \
  docker exec -i mcp-server racket /app/racket-mcp/src/mcp-server.rkt
```

## Development Mode

For development with live code changes, mount the source directories:

```bash
docker run -it --rm \
  -v $(pwd)/racket-unified:/app/racket-unified:ro \
  -v $(pwd)/racket-mcp:/app/racket-mcp:ro \
  cst-mcp-server
```

Or use docker-compose with volumes (already configured in `docker-compose.yml`).

## Troubleshooting

### Version Mismatch Errors

If you see version mismatch errors:
```bash
docker exec mcp-server find /app -name "*.zo" -delete
docker exec mcp-server raco make racket-mcp/src/mcp-server.rkt
```

### Rebuilding After Code Changes

```bash
docker build -t cst-mcp-server -f racket-mcp/Dockerfile .
```

### Checking Container Logs

```bash
docker logs mcp-server
```

## Architecture Notes

- **Base Image**: Uses `racket/racket:8.18-full` for full Racket support
- **Multi-stage Build**: Uses builder stage to compile packages, then copies to minimal runtime
- **Stdio Communication**: MCP protocol uses stdio, so no ports are exposed
- **Dependencies**: Automatically installs racket-unified and racket-mcp packages

## Production Considerations

For production deployments:
1. Consider using a minimal Racket base image
2. Remove development tools and documentation
3. Set up health checks
4. Configure logging
5. Use read-only filesystem where possible
