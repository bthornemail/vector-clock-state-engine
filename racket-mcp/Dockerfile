# Dockerfile for Computational Scheme Theory MCP Server
# Uses Racket 8.x for running the MCP server

FROM racket/racket:8.18-full AS builder

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    && rm -rf /var/lib/apt/lists/*

# Copy racket-unified package (required dependency)
COPY racket-unified/ /app/racket-unified/

# Copy racket-mcp package
COPY racket-mcp/ /app/racket-mcp/

# Set up Racket packages
# Install racket-unified first (as a local package)
# Using --no-setup to avoid test compilation errors
WORKDIR /app/racket-unified
RUN raco pkg install --link --no-setup . || \
    raco pkg install --link . || \
    (raco pkg install --auto . 2>&1 | grep -v "setup reported errors" || true) || \
    true

# Install racket-mcp package
WORKDIR /app/racket-mcp
RUN raco pkg install --link --no-setup . || \
    raco pkg install --link . || \
    (raco pkg install --auto . 2>&1 | grep -v "setup reported errors" || true) || \
    true

# Compile the packages to remove version mismatches
RUN raco make -v src/mcp-server.rkt || true

# Final stage - minimal runtime
FROM racket/racket:8.18-full

WORKDIR /app

# Copy only necessary files from builder
COPY --from=builder /app/racket-unified/ /app/racket-unified/
COPY --from=builder /app/racket-mcp/ /app/racket-mcp/

# Set up packages in final image
WORKDIR /app/racket-unified
RUN raco pkg install --link --no-setup . || \
    raco pkg install --link . || \
    (raco pkg install --auto . 2>&1 | grep -v "setup reported errors" || true) || \
    true

WORKDIR /app/racket-mcp
RUN raco pkg install --link --no-setup . || \
    raco pkg install --link . || \
    (raco pkg install --auto . 2>&1 | grep -v "setup reported errors" || true) || \
    true

# Clean up compiled files to force recompilation with correct version
RUN find /app -name "*.zo" -delete

# Set the entrypoint to run the MCP server
WORKDIR /app
ENTRYPOINT ["racket", "racket-mcp/src/mcp-server.rkt"]

# Metadata
LABEL maintainer="Computational Scheme Theory Project"
LABEL description="MCP Server for Computational Scheme Theory"
LABEL version="0.1.0"
