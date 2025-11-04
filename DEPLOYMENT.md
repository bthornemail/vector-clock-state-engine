# Deployment Guide for Computational Scheme Theory MCP Server

This guide covers deploying the MCP server using Docker and Kubernetes.

## Docker Deployment

### Quick Start

```bash
# Build and start MCP server
make mcp-build
make mcp-docker

# Or manually:
cd racket-mcp
docker compose up -d
```

### Using Root Docker Compose

```bash
# Start all services including MCP server
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs mcp-server -f
```

### Testing Docker Deployment

```bash
# Test MCP server
make mcp-test

# Or manually:
echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}' | \
  docker exec -i cst-mcp-server racket /app/racket-mcp/src/mcp-server.rkt
```

## Kubernetes Deployment

### Prerequisites

- Kubernetes cluster (minikube, kind, or cloud provider)
- kubectl configured
- Docker image built and pushed to registry (if using remote cluster)

### Build and Push Docker Image

```bash
# Build image
make mcp-build

# Tag for registry (replace with your registry)
docker tag cst-mcp-server:latest <registry>/cst-mcp-server:latest

# Push to registry
docker push <registry>/cst-mcp-server:latest
```

### Deploy to Kubernetes

```bash
# Deploy using Makefile
make mcp-k8s-deploy

# Or manually:
kubectl apply -f k8s/mcp-server.yaml

# Using Kustomize:
kubectl apply -k k8s/
```

### Check Deployment Status

```bash
# Check deployment status
make mcp-k8s-status

# Or manually:
kubectl get deployment mcp-server -n computational-scheme-theory
kubectl get pods -l app=computational-scheme-theory,component=mcp-server -n computational-scheme-theory
```

### Access MCP Server in Kubernetes

Since MCP uses stdio, you'll typically use kubectl exec:

```bash
# Connect to MCP server pod
kubectl exec -it deployment/mcp-server -n computational-scheme-theory -- \
  racket /app/racket-mcp/src/mcp-server.rkt

# Test initialization
echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}' | \
  kubectl exec -i deployment/mcp-server -n computational-scheme-theory -- \
  racket /app/racket-mcp/src/mcp-server.rkt
```

### View Logs

```bash
# View logs
make mcp-k8s-logs

# Or manually:
kubectl logs -f deployment/mcp-server -n computational-scheme-theory
```

### Undeploy

```bash
# Remove deployment
make mcp-k8s-undeploy

# Or manually:
kubectl delete -f k8s/mcp-server.yaml
```

## Configuration

### Docker Compose Environment Variables

- `RACKET_VERSION`: Racket version (default: 8.18)

### Kubernetes Configuration

The Kubernetes deployment uses a ConfigMap for configuration:

- `RACKET_VERSION`: Racket version
- `MCP_PROTOCOL_VERSION`: MCP protocol version (2024-11-05)
- `SERVER_NAME`: Server name identifier

Edit `k8s/mcp-server.yaml` to modify these values.

## Health Checks

Both Docker and Kubernetes deployments include health checks that verify the MCP server responds to initialization requests.

### Docker Health Check

The health check sends an initialize request and verifies the response contains `protocolVersion`.

### Kubernetes Health Checks

- **Liveness Probe**: Ensures the container is running
- **Readiness Probe**: Ensures the MCP server is ready to accept requests

Both probes execute the same command as the Docker health check.

## Troubleshooting

### Container Not Starting

```bash
# Check container logs
docker logs cst-mcp-server

# Check Kubernetes pod logs
kubectl logs deployment/mcp-server -n computational-scheme-theory
```

### Health Check Failing

```bash
# Manually test health check
echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}' | \
  docker exec -i cst-mcp-server racket /app/racket-mcp/src/mcp-server.rkt
```

### Image Build Issues

```bash
# Clean build
docker build --no-cache -t cst-mcp-server:latest -f racket-mcp/Dockerfile .
```

### Kubernetes Pod Issues

```bash
# Describe pod for details
kubectl describe pod -l app=computational-scheme-theory,component=mcp-server -n computational-scheme-theory

# Check events
kubectl get events -n computational-scheme-theory --sort-by='.lastTimestamp'
```

## Production Considerations

1. **Resource Limits**: Adjust CPU/memory limits in Kubernetes manifests based on workload
2. **Replicas**: Consider scaling for high availability (modify replicas in deployment)
3. **Persistent Storage**: If needed, add PersistentVolumeClaims for data persistence
4. **Service Mesh**: Consider integrating with Istio/Linkerd for advanced networking
5. **Monitoring**: Add Prometheus metrics and Grafana dashboards
6. **Security**: Use secrets for sensitive configuration, enable RBAC

## Integration with Cursor/Claude Desktop

To use the MCP server with Cursor or Claude Desktop:

### Docker

Update `~/.cursor/mcp.json` or Claude Desktop config:

```json
{
  "mcpServers": {
    "computational-scheme-docker": {
      "command": "/home/main/docker-mcp-wrapper.sh",
      "args": [],
      "env": {}
    }
  }
}
```

### Kubernetes

Create a port-forward and use localhost:

```bash
# Port forward to local machine
kubectl port-forward deployment/mcp-server 8080:8080 -n computational-scheme-theory

# Configure MCP client to use localhost:8080
```

Or use a LoadBalancer/Ingress if your cluster supports it (though MCP uses stdio, so this may require a proxy).
