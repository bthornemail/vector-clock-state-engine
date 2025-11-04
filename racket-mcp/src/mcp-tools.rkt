#lang racket/base

(require json
         racket/match
         racket/string
         racket/file
         "../../racket-unified/src/algorithms/unified-pipeline.rkt"
         "../../racket-unified/src/bridge/racket-bridge.rkt"
         "../../racket-unified/src/m-expression.rkt"
         "../../racket-unified/src/nlp/layer1-interface.rkt"
         "../../racket-unified/src/algorithms/cfg-builder.rkt"
         "../../racket-unified/src/algorithms/cfg-types.rkt"
         "../../racket-unified/src/algorithms/cyclomatic.rkt"
         "../../racket-unified/src/algorithms/combinator-detector.rkt"
         "../../racket-unified/src/algorithms/algorithm1.rkt"
         "../../racket-unified/src/s-expression.rkt"
         "../../racket-unified/src/m-s-compiler.rkt")

(provide
 get-mcp-tools
 call-mcp-tool)

;; ============================================================
;; MCP Tools - Wrapping racket-unified API
;; ============================================================

;; Tool: compute_h1
(define (tool-compute-h1 params)
  "Compute H¹ cohomology from Scheme source code"
  (with-handlers ([exn? (lambda (e)
                         (hash 'success #f
                               'error (format "Error computing H¹: ~a" (exn-message e))))])
    (let* ([source (hash-ref params 'source_code "")]
           [result (compute-h1-from-source-detailed source)])
      (if (pipeline-result-success result)
          (hash 'success #t
                'h1 (pipeline-result-h1 result)
                'bindings (pipeline-result-num-bindings result)
                'simplices_0 (pipeline-result-num-simplices0 result)
                'simplices_1 (pipeline-result-num-simplices1 result)
                'simplices_2 (pipeline-result-num-simplices2 result))
          (hash 'success #f
                'error (or (pipeline-result-error result) "Unknown error"))))))

;; Tool: compute_vg (optional, requires service)
(define (tool-compute-vg params)
  "Compute V(G) cyclomatic complexity (requires Racket service)"
  (if (racket-service-available?)
      (let-values ([(vg error) (call-racket-vg (hash-ref params 'source_code ""))])
        (if error
            (hash 'success #f 'error error)
            (hash 'success #t 'v_g vg)))
      (hash 'success #f 'error "Racket V(G) service not available")))

;; Tool: validate_hypothesis
(define (tool-validate-hypothesis params)
  "Validate hypothesis H¹ = V(G) - k"
  (let* ([h1 (hash-ref params 'h1 #f)]
         [vg (hash-ref params 'v_g #f)]
         [k (hash-ref params 'k 0)]
         [tolerance (hash-ref params 'tolerance 0)])
    (if (and h1 vg)
        (let-values ([(valid? diff msg) (validate-hypothesis h1 vg k tolerance)])
          (hash 'valid valid?
                'difference diff
                'message msg))
        (hash 'success #f 'error "Missing h1 or v_g parameter"))))

;; Tool: process_natural_language
(define (tool-process-natural-language params)
  "Convert natural language query to M-expression"
  (let ([query (hash-ref params 'query "")])
    (with-handlers ([exn? (lambda (e)
                          (hash 'success #f
                                'error (exn-message e)))])
      (let ([m-expr (nl-to-m-expression query)])
        (hash 'success #t
              'm_expression (hash 'op (if (m-expr? m-expr) (m-expr-op m-expr) #f)
                                  'args (if (m-expr? m-expr) 
                                           (m-expr-args m-expr) 
                                           '()))
              'raw_query query)))))

;; Tool: build_cfg
(define (tool-build-cfg params)
  "Build control flow graph from Scheme source code"
  (with-handlers ([exn? (lambda (e)
                         (hash 'success #f
                               'error (format "Error building CFG: ~a" (exn-message e))))])
    (let* ([source (hash-ref params 'source_code "")]
           [cfg (build-cfg-from-source source)])
      (hash 'success #t
            'entry_node (cfg-entry cfg)
            'exit_node (cfg-exit cfg)
            'num_nodes (hash-count (cfg-nodes cfg))
            'num_edges (length (cfg-edges cfg))))))

;; Tool: detect_combinators
(define (tool-detect-combinators params)
  "Detect Y/Z combinators in Scheme source code"
  (with-handlers ([exn? (lambda (e)
                         (hash 'success #f
                               'error (format "Error detecting combinators: ~a" (exn-message e))))])
    (let* ([source (hash-ref params 'source_code "")]
           [ast-nodes (parse-r5rs source)]
           [main-ast (if (null? ast-nodes)
                        #f
                        (if (= (length ast-nodes) 1)
                            (car ast-nodes)
                            (ast-app (source-loc "" 1 1)
                                    (ast-var (source-loc "" 1 1) 'begin)
                                    ast-nodes)))]
           [y-detected (if main-ast (detect-y-combinator main-ast) '())]
           [z-detected (if main-ast (detect-z-combinator main-ast) '())]
           [all-combinators (if main-ast (detect-all-combinators main-ast) '())])
      (hash 'success #t
            'y_combinator_found (not (null? y-detected))
            'z_combinator_found (not (null? z-detected))
            'all_combinators (map (lambda (c) (format "~a" c)) all-combinators)))))

;; Tool: analyze_program
(define (tool-analyze-program params)
  "Comprehensive program analysis combining H¹, CFG, and combinators"
  (with-handlers ([exn? (lambda (e)
                         (hash 'success #f
                               'error (format "Error analyzing program: ~a" (exn-message e))))])
    (let* ([source (hash-ref params 'source_code "")]
           [h1-result (compute-h1-from-source-detailed source)]
           [cfg (build-cfg-from-source source)]
           [complexity (compute-cyclomatic-complexity cfg)]
           [ast-nodes (parse-r5rs source)]
           [main-ast (if (null? ast-nodes)
                        #f
                        (if (= (length ast-nodes) 1)
                            (car ast-nodes)
                            (ast-app (source-loc "" 1 1)
                                    (ast-var (source-loc "" 1 1) 'begin)
                                    ast-nodes)))]
           [combinators (if main-ast (detect-all-combinators main-ast) '())])
      (hash 'success (pipeline-result-success h1-result)
            'h1 (if (pipeline-result-success h1-result)
                    (pipeline-result-h1 h1-result)
                    #f)
            'bindings (if (pipeline-result-success h1-result)
                         (pipeline-result-num-bindings h1-result)
                         #f)
            'cfg (hash 'num_nodes (hash-count (cfg-nodes cfg))
                      'num_edges (length (cfg-edges cfg))
                      'cyclomatic_complexity (complexity-metrics-v-g complexity))
            'combinators (map (lambda (c) (format "~a" c)) combinators)
            'error (if (pipeline-result-success h1-result)
                      #f
                      (pipeline-result-error h1-result))))))

;; Tool: parse_m_expression
(define (tool-parse-m-expression params)
  "Parse M-expression from string representation"
  (with-handlers ([exn? (lambda (e)
                         (hash 'success #f
                               'error (format "Error parsing M-expression: ~a" (exn-message e))))])
    (let* ([expr-str (hash-ref params 'expression "")]
           [parsed (read (open-input-string expr-str))])
      (if (list? parsed)
          (let ([m-expr (parse-m-expr parsed)])
            (hash 'success #t
                  'op (m-expr-op m-expr)
                  'args (m-expr-args m-expr)
                  'string (m-expr->string m-expr)))
          (hash 'success #f 'error "Expression must be a list")))))

;; Tool: convert_m_to_s
(define (tool-convert-m-to-s params)
  "Convert M-expression to S-expression"
  (with-handlers ([exn? (lambda (e)
                         (hash 'success #f
                               'error (format "Error converting M to S: ~a" (exn-message e))))])
    (let* ([m-expr-str (hash-ref params 'm_expression "")]
           [m-expr-parsed (read (open-input-string m-expr-str))]
           [m-expr (if (list? m-expr-parsed)
                      (parse-m-expr m-expr-parsed)
                      (error "Invalid M-expression format"))]
           [proof (hash-ref params 'proof "mcp-conversion")]
           [s-expr (m-expr->s-expr m-expr proof)])
      (hash 'success #t
            's_expression (hash 'type (s-expr-type s-expr)
                               'data (s-expr-data s-expr))
            'executable #t))))

;; Tool: extract_bindings
(define (tool-extract-bindings params)
  "Extract binding structure from Scheme source code"
  (with-handlers ([exn? (lambda (e)
                         (hash 'success #f
                               'error (format "Error extracting bindings: ~a" (exn-message e))))])
    (let* ([source (hash-ref params 'source_code "")]
           [result (compute-h1-from-source-detailed source)])
      (if (pipeline-result-success result)
          (hash 'success #t
                'num_bindings (pipeline-result-num-bindings result)
                'simplices_0 (pipeline-result-num-simplices0 result)
                'simplices_1 (pipeline-result-num-simplices1 result)
                'simplices_2 (pipeline-result-num-simplices2 result)
                'beta0 (pipeline-result-beta0 result)
                'beta1 (pipeline-result-beta1 result))
          (hash 'success #f
                'error (pipeline-result-error result))))))

;; Tool: get_cfg_complexity
(define (tool-get-cfg-complexity params)
  "Get cyclomatic complexity from CFG (local computation, no service required)"
  (with-handlers ([exn? (lambda (e)
                         (hash 'success #f
                               'error (format "Error computing CFG complexity: ~a" (exn-message e))))])
    (let* ([source (hash-ref params 'source_code "")]
           [cfg (build-cfg-from-source source)]
           [complexity (compute-cyclomatic-complexity cfg)])
      (hash 'success #t
            'v_g (complexity-metrics-v-g complexity)
            'num_nodes (complexity-metrics-nodes complexity)
            'num_edges (complexity-metrics-edges complexity)
            'components (complexity-metrics-components complexity)))))

;; Tool: analyze_file
(define (tool-analyze-file params)
  "Analyze a Scheme file from disk"
  (with-handlers ([exn? (lambda (e)
                         (hash 'success #f
                               'error (format "Error analyzing file: ~a" (exn-message e))))])
    (let* ([file-path (hash-ref params 'file_path "")]
           [full-path (if (string-prefix? file-path "/")
                         file-path
                         (build-path (current-directory) file-path))])
      (if (file-exists? full-path)
          (let ([source (file->string full-path)])
            (tool-analyze-program (hash 'source_code source)))
          (hash 'success #f 'error (format "File not found: ~a" full-path))))))

;; MCP Tool Definitions with JSON Schemas
(define mcp-tool-definitions
  (list
   (hash 'name "compute_h1"
         'description "Compute H¹ cohomology from Scheme source code using the unified pipeline"
         'inputSchema (hash
                      'type "object"
                      'properties (hash
                                   'source_code (hash
                                                'type "string"
                                                'description "Scheme source code to analyze"))
                      'required (list "source_code"))
         'handler tool-compute-h1)
   
   (hash 'name "compute_vg"
         'description "Compute V(G) cyclomatic complexity from Scheme source (requires Racket service)"
         'inputSchema (hash
                      'type "object"
                      'properties (hash
                                   'source_code (hash
                                                'type "string"
                                                'description "Scheme source code to analyze"))
                      'required (list "source_code"))
         'handler tool-compute-vg)
   
   (hash 'name "validate_hypothesis"
         'description "Validate the hypothesis H¹ = V(G) - k"
         'inputSchema (hash
                      'type "object"
                      'properties (hash
                                   'h1 (hash 'type "number" 'description "H¹ cohomology value")
                                   'v_g (hash 'type "number" 'description "V(G) cyclomatic complexity")
                                   'k (hash 'type "number" 'description "Normalization constant (default: 0)")
                                   'tolerance (hash 'type "number" 'description "Allowed tolerance (default: 0)"))
                      'required (list "h1" "v_g"))
         'handler tool-validate-hypothesis)
   
   (hash 'name "process_natural_language"
         'description "Convert natural language query to M-expression using SGP-ASLN"
         'inputSchema (hash
                      'type "object"
                      'properties (hash
                                   'query (hash
                                          'type "string"
                                          'description "Natural language query (e.g., 'compute H1 for program test')"))
                      'required (list "query"))
         'handler tool-process-natural-language)
   
   (hash 'name "build_cfg"
         'description "Build control flow graph from Scheme source code"
         'inputSchema (hash
                      'type "object"
                      'properties (hash
                                   'source_code (hash
                                                'type "string"
                                                'description "Scheme source code to analyze"))
                      'required (list "source_code"))
         'handler tool-build-cfg)
   
   (hash 'name "detect_combinators"
         'description "Detect Y/Z combinators in Scheme source code"
         'inputSchema (hash
                      'type "object"
                      'properties (hash
                                   'source_code (hash
                                                'type "string"
                                                'description "Scheme source code to analyze"))
                      'required (list "source_code"))
         'handler tool-detect-combinators)
   
   (hash 'name "analyze_program"
         'description "Comprehensive program analysis combining H¹, CFG, and combinators"
         'inputSchema (hash
                      'type "object"
                      'properties (hash
                                   'source_code (hash
                                                'type "string"
                                                'description "Scheme source code to analyze"))
                      'required (list "source_code"))
         'handler tool-analyze-program)
   
   (hash 'name "parse_m_expression"
         'description "Parse M-expression from string representation"
         'inputSchema (hash
                      'type "object"
                      'properties (hash
                                   'expression (hash
                                               'type "string"
                                               'description "M-expression as string (e.g., '(createBinding x scope1)')"))
                      'required (list "expression"))
         'handler tool-parse-m-expression)
   
   (hash 'name "convert_m_to_s"
         'description "Convert M-expression to S-expression"
         'inputSchema (hash
                      'type "object"
                      'properties (hash
                                   'm_expression (hash
                                                 'type "string"
                                                 'description "M-expression as string")
                                   'proof (hash
                                          'type "string"
                                          'description "Proof/metadata string (optional)"))
                      'required (list "m_expression"))
         'handler tool-convert-m-to-s)
   
   (hash 'name "extract_bindings"
         'description "Extract binding structure from Scheme source code"
         'inputSchema (hash
                      'type "object"
                      'properties (hash
                                   'source_code (hash
                                                'type "string"
                                                'description "Scheme source code to analyze"))
                      'required (list "source_code"))
         'handler tool-extract-bindings)
   
   (hash 'name "get_cfg_complexity"
         'description "Get cyclomatic complexity from CFG (local computation, no service required)"
         'inputSchema (hash
                      'type "object"
                      'properties (hash
                                   'source_code (hash
                                                'type "string"
                                                'description "Scheme source code to analyze"))
                      'required (list "source_code"))
         'handler tool-get-cfg-complexity)
   
   (hash 'name "analyze_file"
         'description "Analyze a Scheme file from disk"
         'inputSchema (hash
                      'type "object"
                      'properties (hash
                                   'file_path (hash
                                              'type "string"
                                              'description "Path to Scheme file (absolute or relative)"))
                      'required (list "file_path"))
         'handler tool-analyze-file)))

;; Get list of MCP tools (without handlers, for protocol)
(define (get-mcp-tools)
  "Return list of tool definitions for MCP protocol"
  (map (lambda (tool)
         (hash 'name (hash-ref tool 'name)
               'description (hash-ref tool 'description)
               'inputSchema (hash-ref tool 'inputSchema)))
       mcp-tool-definitions))

;; Call a specific tool by name
(define (call-mcp-tool tool-name params)
  "Call a tool by name with given parameters"
  (with-handlers ([exn? (lambda (e)
                         (hash 'success #f 
                               'error (format "Error calling tool '~a': ~a" tool-name (exn-message e))))])
    (let ([tool (findf (lambda (t) (equal? (hash-ref t 'name) tool-name)) mcp-tool-definitions)])
      (if tool
          (let ([handler (hash-ref tool 'handler)])
            (handler params))
          (hash 'success #f 'error (format "Tool '~a' not found" tool-name))))))

