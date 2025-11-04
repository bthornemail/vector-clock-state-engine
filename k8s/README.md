# Kubernetes manifests for Computational Scheme Theory
# 
# This directory contains Kubernetes manifests for deploying the Computational Scheme Theory
# system components including the MCP server.
#
# Usage:
#   kubectl apply -f k8s/
#   kubectl apply -f k8s/mcp-server.yaml
#
# For namespace-scoped deployment:
#   kubectl apply -f k8s/mcp-server.yaml -n computational-scheme-theory
#
# Building and pushing Docker image:
#   docker build -t cst-mcp-server:latest -f racket-mcp/Dockerfile .
#   docker tag cst-mcp-server:latest <registry>/cst-mcp-server:latest
#   docker push <registry>/cst-mcp-server:latest
#
# Updating image in deployment:
#   kubectl set image deployment/mcp-server mcp-server=<registry>/cst-mcp-server:latest -n computational-scheme-theory
#
# MCP Server Access:
#   Since MCP uses stdio, you'll typically use kubectl exec to connect:
#   kubectl exec -it deployment/mcp-server -n computational-scheme-theory -- racket /app/racket-mcp/src/mcp-server.rkt
#
# Health Check:
#   kubectl exec deployment/mcp-server -n computational-scheme-theory -- sh -c 'echo "{\"jsonrpc\":\"2.0\",\"method\":\"initialize\",\"params\":{},\"id\":1}" | racket /app/racket-mcp/src/mcp-server.rkt'
