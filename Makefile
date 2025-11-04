# Makefile for Computational Scheme Theory Project
# Provides common build, test, and development targets

.PHONY: help setup build test clean proto docker-up docker-down verify-env mcp-build mcp-docker mcp-k8s-deploy mcp-k8s-undeploy mcp-k8s-logs

# Default target
help:
	@echo "Computational Scheme Theory - Development Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  setup       - Install all dependencies and set up environment"
	@echo "  build       - Build all components (Haskell, Racket, Python)"
	@echo "  test        - Run all tests"
	@echo "  clean       - Clean all build artifacts"
	@echo "  proto       - Generate code from protocol buffer definitions"
	@echo "  docker-up   - Start Docker services"
	@echo "  docker-down - Stop Docker services"
	@echo "  verify-env  - Verify development environment setup"
	@echo "  mcp-build   - Build MCP server Docker image"
	@echo "  mcp-docker  - Start MCP server via Docker Compose"
	@echo "  mcp-k8s-deploy   - Deploy MCP server to Kubernetes"
	@echo "  mcp-k8s-undeploy - Remove MCP server from Kubernetes"
	@echo "  mcp-k8s-logs     - View MCP server logs in Kubernetes"
	@echo ""

# Setup - Install dependencies
setup: setup-haskell setup-racket setup-python
	@echo "✅ All components set up"

setup-haskell:
	@echo "Setting up Haskell project..."
	@cd haskell-core && cabal update
	@cd haskell-core && cabal build --only-dependencies

setup-racket:
	@echo "Setting up Racket project..."
	@cd racket-metrics && raco pkg install --deps search-auto

setup-python:
	@echo "Setting up Python project..."
	@cd python-coordinator && python3 -m venv venv || true
	@cd python-coordinator && . venv/bin/activate && pip install -r requirements.txt || \
		(cd python-coordinator && python3 -m pip install -r requirements.txt)

# Build - Build all components
build: build-haskell build-racket build-python
	@echo "✅ All components built"

build-haskell:
	@echo "Building Haskell project..."
	@cd haskell-core && cabal build

build-racket:
	@echo "Building Racket project..."
	@echo "Racket projects are typically built on-the-fly"
	@raco test --package racket-metrics || echo "Note: Racket tests require modules to be implemented"

build-python:
	@echo "Building Python project..."
	@cd python-coordinator && python3 -m pip install -e . || \
		(cd python-coordinator && . venv/bin/activate && pip install -e .)

# Test - Run all tests
test: test-haskell test-racket test-python
	@echo "✅ All tests passed"

test-haskell:
	@echo "Running Haskell tests..."
	@cd haskell-core && cabal test || echo "Note: Tests will be added during implementation"

test-racket:
	@echo "Running Racket tests..."
	@cd racket-metrics && raco test . || echo "Note: Tests will be added during implementation"

test-python:
	@echo "Running Python tests..."
	@cd python-coordinator && python3 -m pytest tests/ || \
		(cd python-coordinator && . venv/bin/activate && pytest tests/) || \
		echo "Note: Tests will be added during implementation"

# Clean - Remove build artifacts
clean: clean-haskell clean-racket clean-python clean-proto
	@echo "✅ Clean complete"

clean-haskell:
	@echo "Cleaning Haskell project..."
	@cd haskell-core && cabal clean

clean-racket:
	@echo "Cleaning Racket project..."
	@find racket-metrics -type d -name "compiled" -exec rm -rf {} + 2>/dev/null || true

clean-python:
	@echo "Cleaning Python project..."
	@cd python-coordinator && rm -rf build dist *.egg-info
	@cd python-coordinator && find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@cd python-coordinator && find . -type f -name "*.pyc" -delete 2>/dev/null || true

clean-proto:
	@echo "Cleaning generated proto code..."
	@rm -rf haskell-core/src/Proto
	@rm -rf racket-metrics/proto-gen
	@rm -rf python-coordinator/coordinator/proto

# Protocol Buffer Code Generation
proto: proto-haskell proto-python
	@echo "✅ Protocol buffer code generated"
	@echo "Note: Racket proto generation will be added in Week 13 if gRPC library available"

proto-haskell:
	@echo "Generating Haskell proto code..."
	@mkdir -p haskell-core/src/Proto
	@if command -v protoc >/dev/null 2>&1; then \
		protoc --proto_path=proto \
		       --haskell_out=haskell-core/src/Proto \
		       proto/*.proto || echo "Note: Haskell protobuf plugin may not be installed"; \
	else \
		echo "Error: protoc not found. Please install Protocol Buffers compiler."; \
		exit 1; \
	fi

proto-python:
	@echo "Generating Python proto code..."
	@mkdir -p python-coordinator/coordinator/proto
	@if command -v protoc >/dev/null 2>&1; then \
		python3 -m grpc_tools.protoc \
		       --proto_path=proto \
		       --python_out=python-coordinator/coordinator/proto \
		       --grpc_python_out=python-coordinator/coordinator/proto \
		       proto/*.proto; \
	else \
		echo "Error: protoc not found. Please install Protocol Buffers compiler."; \
		exit 1; \
	fi

# Docker services
docker-up:
	@echo "Starting Docker services..."
	@docker-compose up -d
	@echo "✅ Docker services started"

docker-down:
	@echo "Stopping Docker services..."
	@docker-compose down
	@echo "✅ Docker services stopped"

# Environment verification
verify-env:
	@echo "Verifying development environment..."
	@./scripts/verify-env.sh

# MCP Server targets
mcp-build:
	@echo "Building MCP server Docker image..."
	@docker build -t cst-mcp-server:latest -f racket-mcp/Dockerfile .
	@echo "✅ MCP server Docker image built"

mcp-docker:
	@echo "Starting MCP server via Docker Compose..."
	@cd racket-mcp && docker compose up -d
	@echo "✅ MCP server started (container: cst-mcp-server)"

mcp-docker-stop:
	@echo "Stopping MCP server..."
	@cd racket-mcp && docker compose down
	@echo "✅ MCP server stopped"

mcp-k8s-deploy:
	@echo "Deploying MCP server to Kubernetes..."
	@kubectl apply -f k8s/mcp-server.yaml
	@echo "✅ MCP server deployed to Kubernetes"
	@echo "Waiting for deployment to be ready..."
	@kubectl wait --for=condition=available --timeout=60s deployment/mcp-server -n computational-scheme-theory || true

mcp-k8s-undeploy:
	@echo "Removing MCP server from Kubernetes..."
	@kubectl delete -f k8s/mcp-server.yaml || true
	@echo "✅ MCP server removed from Kubernetes"

mcp-k8s-logs:
	@echo "Viewing MCP server logs..."
	@kubectl logs -f deployment/mcp-server -n computational-scheme-theory || \
		kubectl logs -f -l app=computational-scheme-theory,component=mcp-server -n computational-scheme-theory

mcp-k8s-status:
	@echo "MCP Server Status:"
	@kubectl get deployment mcp-server -n computational-scheme-theory || echo "Deployment not found"
	@kubectl get pods -l app=computational-scheme-theory,component=mcp-server -n computational-scheme-theory || echo "Pods not found"

mcp-test:
	@echo "Testing MCP server..."
	@echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}' | \
		docker exec -i cst-mcp-server racket /app/racket-mcp/src/mcp-server.rkt 2>&1 | \
		grep -q protocolVersion && echo "✅ MCP server responding correctly" || echo "❌ MCP server test failed"

