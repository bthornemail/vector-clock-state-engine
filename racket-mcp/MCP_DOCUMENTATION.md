# MCP Server Documentation - Computational Scheme Theory

This document provides comprehensive documentation for all MCP servers configured in the system, including tools, resources, and prompts available to AI agents.

## Overview

The Computational Scheme Theory MCP servers provide AI agents with:
- **Mathematical Analysis Tools**: Compute H¹ cohomology, cyclomatic complexity, and validate the central hypothesis
- **Program Analysis**: Extract binding structures, build control flow graphs, detect combinators
- **Natural Language Processing**: Convert natural language to executable M-expressions
- **Event Sourcing**: Transform M-expressions (intent) to S-expressions (facts)

## Available MCP Servers

### 1. computational-scheme (Direct Racket)

**Command**: `racket /home/main/vector-clock-state-engine/racket-mcp/src/mcp-server.rkt`

**Status**: ✅ Active  
**Version**: 0.1.0  
**Protocol**: MCP 2024-11-05

#### Tools (12)

1. **compute_h1** - Compute H¹ cohomology from Scheme source code
   - Input: `source_code` (string) - R5RS Scheme code
   - Output: H¹ value, binding count, simplices, Betti numbers
   - Description: Topological invariant from static binding structure

2. **compute_vg** - Compute V(G) cyclomatic complexity
   - Input: `source_code` (string) - R5RS Scheme code
   - Output: V(G) value
   - Description: Dynamic complexity metric from control flow

3. **validate_hypothesis** - Validate H¹ = V(G) - k
   - Input: `h1`, `v_g`, `k` (optional), `tolerance` (optional)
   - Output: Validation result, difference, message
   - Description: Tests the Computational Scheme Theory hypothesis

4. **process_natural_language** - Convert NL to M-expression
   - Input: `query` (string) - Natural language query
   - Output: M-expression structure
   - Description: Uses SGP-ASLN for deterministic NLP

5. **build_cfg** - Build control flow graph
   - Input: `source_code` (string)
   - Output: CFG structure (nodes, edges, entry/exit)
   - Description: Constructs dynamic execution flow representation

6. **detect_combinators** - Detect Y/Z combinators
   - Input: `source_code` (string)
   - Output: Combinator detection results
   - Description: Identifies recursive patterns

7. **analyze_program** - Comprehensive program analysis
   - Input: `source_code` (string)
   - Output: Combined H¹, CFG, complexity, combinators
   - Description: Complete static and dynamic analysis

8. **parse_m_expression** - Parse M-expression from string
   - Input: `expression` (string)
   - Output: Structured M-expression
   - Description: Parses meta-language commands

9. **convert_m_to_s** - Convert M-expression to S-expression
   - Input: `m_expression` (string), `proof` (optional)
   - Output: S-expression event
   - Description: Implements M/S-expression duality

10. **extract_bindings** - Extract binding structure
    - Input: `source_code` (string)
    - Output: Bindings, simplices, Betti numbers
    - Description: Static scope analysis

11. **get_cfg_complexity** - Get cyclomatic complexity locally
    - Input: `source_code` (string)
    - Output: V(G), nodes, edges, components
    - Description: Local CFG complexity computation

12. **analyze_file** - Analyze Scheme file from disk
    - Input: `file_path` (string)
    - Output: Comprehensive analysis results
    - Description: File-based program analysis

#### Resources (3)

1. **computational-scheme://bindings** - Binding Algebra
   - Contains commutative rig structure R_Scheme
   - Binding relationships and scope regions
   - Used for H¹ computation

2. **computational-scheme://topology** - Scope Topology
   - Zariski topology from visibility regions
   - Čech complex and simplicial structure
   - Topological invariants data

3. **computational-scheme://knowledge-graph** - Knowledge Graph
   - Semantic relationships from NLP
   - Symbolic concept mappings
   - Intent structures

#### Prompts (8)

1. **analyze_program_complexity** - Analyze program complexity
   - Args: `source_code`
   - Guides agent through H¹ and V(G) computation

2. **understand_program_structure** - Understand binding structure
   - Args: `source_code`
   - Explains scope topology and complexity

3. **convert_natural_language_to_operation** - Convert NL to operation
   - Args: `query`
   - Demonstrates M-expression conversion

4. **comprehensive_program_analysis** - Full program analysis
   - Args: `source_code`
   - Complete analysis workflow

5. **validate_hypothesis_for_program** - Validate hypothesis
   - Args: `source_code`, `k` (optional), `tolerance` (optional)
   - Tests H¹ = V(G) - k relationship

6. **analyze_file_from_disk** - Analyze file
   - Args: `file_path`
   - File-based analysis workflow

7. **explain_m_expression_system** - Explain M/S-expression duality
   - Args: None
   - Educational prompt about event sourcing

8. **detect_combinators_in_program** - Detect combinators
   - Args: `source_code`
   - Combinator detection and explanation

---

### 2. computational-scheme-docker (Docker Container)

**Command**: `/home/main/docker-mcp-wrapper.sh`  
**Container**: `cst-mcp-server`  
**Status**: ✅ Active (running)

Same tools, resources, and prompts as direct Racket server, but running in Docker for isolation.

---

### 3. enhanced-h2gnn (Enhanced H²GNN)

**Command**: `tsx /home/main/hyperbolic-geometric-neural-network/src/mcp/enhanced-h2gnn-mcp-server.ts`

**Status**: ✅ Active  
**Version**: 2.1.0

#### Key Features
- HD addressing for deterministic service routing
- Advanced learning with memory consolidation
- Persistent understanding storage
- Interactive learning sessions
- Adaptive responses based on learning history

#### Tools
- Learning operations (learn_concept, retrieve_memories)
- Knowledge graph operations
- Team collaboration tools
- Coding standard enforcement
- Adaptive learning recommendations

#### Resources
- Memory storage
- Knowledge graph data
- Learning progress data
- Understanding snapshots

#### Prompts
- Concept analysis prompts
- Hierarchical reasoning prompts
- Semantic exploration prompts

---

### 4. h2gnn (H²GNN)

**Command**: `tsx /home/main/hyperbolic-geometric-neural-network/src/mcp/h2gnn-mcp-server.ts`

**Status**: ✅ Active

#### Key Features
- WordNet integration
- Hyperbolic geometry for semantic relationships
- Knowledge graph construction
- Code generation from patterns

#### Tools
- WordNet queries
- Hyperbolic distance computation
- Hierarchical Q&A
- Knowledge graph operations
- Code generation and analysis

#### Resources
- WordNet data
- Knowledge graphs
- Code patterns

#### Prompts
- Concept analysis
- Hierarchical reasoning
- Semantic exploration

---

### 5. filesystem (Standard MCP)

**Command**: `npx -y @modelcontextprotocol/server-filesystem ~/`

**Status**: ✅ Active

Standard filesystem access for reading/writing files.

---

### 6. redis (Standard MCP)

**Command**: `npx -y @modelcontextprotocol/server-redis`

**Status**: ✅ Active  
**Connection**: `redis://127.0.0.1:6379`

Standard Redis operations for caching and state management.

---

## Usage Examples for AI Agents

### Example 1: Analyze Program Complexity

```json
{
  "method": "prompts/get",
  "params": {
    "name": "analyze_program_complexity",
    "arguments": {
      "source_code": "(lambda (x) (lambda (y) (+ x y)))"
    }
  }
}
```

### Example 2: Compute H¹

```json
{
  "method": "tools/call",
  "params": {
    "name": "compute_h1",
    "arguments": {
      "source_code": "(lambda (x) x)"
    }
  }
}
```

### Example 3: Validate Hypothesis

```json
{
  "method": "tools/call",
  "params": {
    "name": "validate_hypothesis",
    "arguments": {
      "h1": 0,
      "v_g": 1,
      "k": 0,
      "tolerance": 0
    }
  }
}
```

### Example 4: Natural Language Processing

```json
{
  "method": "tools/call",
  "params": {
    "name": "process_natural_language",
    "arguments": {
      "query": "compute H1 for program test"
    }
  }
}
```

## Best Practices for Agents

1. **Use Prompts First**: Prompts provide structured workflows - use them before calling individual tools
2. **Combine Tools**: Use `analyze_program` for comprehensive analysis instead of calling multiple tools
3. **Validate Hypothesis**: Always validate H¹ = V(G) - k after computing both metrics
4. **File Analysis**: Use `analyze_file` for disk-based programs instead of reading manually
5. **Error Handling**: Check `success` field in tool responses before proceeding
6. **Resource Access**: Resources require program context - use tools first to establish context

## Protocol Details

- **Transport**: stdio (standard input/output)
- **Protocol**: JSON-RPC 2.0
- **MCP Version**: 2024-11-05
- **Encoding**: UTF-8 JSON

## Troubleshooting

### Server Not Responding
- Check server logs via stderr
- Verify server process is running
- Check file permissions

### Tool Errors
- Verify input schema matches requirements
- Check source code is valid R5RS Scheme
- Ensure required parameters are provided

### Resource Errors
- Resources require program context
- Use tools first to establish context
- Check resource URI format

---

**Last Updated**: 2025-11-04  
**Maintained By**: Computational Scheme Theory Project
