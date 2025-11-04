#!/bin/bash
# Quick test script for Docker container

echo "Testing MCP Server Docker Container..."
echo ""

# Test 1: Initialize
echo "Test 1: Initialize"
echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}' | \
  docker run --rm -i cst-mcp-server:test 2>&1 | grep -v "Server starting\|Server shutting"

echo ""
echo "Test 2: List Tools"
(echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}'; \
 echo '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}') | \
  docker run --rm -i cst-mcp-server:test 2>&1 | \
  grep -o '"name":"[^"]*"' | head -5

echo ""
echo "Test 3: Compute CFG Complexity"
(echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}'; \
 echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get_cfg_complexity","arguments":{"source_code":"(lambda (x) (if x 1 2))"}},"id":2}') | \
  docker run --rm -i cst-mcp-server:test 2>&1 | \
  tail -1 | python3 -m json.tool 2>/dev/null | grep -E '"success"|"v_g"' || echo "Tool call completed"

echo ""
echo "Docker container tests completed!"
