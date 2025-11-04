#lang racket/base

(require json
         racket/string)

(provide
 get-mcp-prompts
 get-mcp-prompt)

;; ============================================================
;; MCP Prompts - AI Assistant Templates
;; ============================================================

;; Prompt definitions for AI agents
(define mcp-prompt-definitions
  (list
   (hash 'name "analyze_program_complexity"
         'description "Analyze a Scheme program's complexity using H¹ cohomology and cyclomatic complexity"
         'arguments (list
                    (hash 'name "source_code"
                          'description "Scheme source code to analyze"
                          'required #t))
         'template "Analyze the following Scheme program and compute its complexity metrics:\n\n```scheme\n{{source_code}}\n```\n\nPlease:\n1. Compute H¹ cohomology using the compute_h1 tool\n2. Compute cyclomatic complexity V(G) using the get_cfg_complexity tool\n3. Validate the hypothesis H¹ = V(G) - k\n4. Provide insights about the program's complexity")
   
   (hash 'name "understand_program_structure"
         'description "Understand the binding structure and scope topology of a Scheme program"
         'arguments (list
                    (hash 'name "source_code"
                          'description "Scheme source code to analyze"
                          'required #t))
         'template "Analyze the binding structure of the following Scheme program:\n\n```scheme\n{{source_code}}\n```\n\nPlease:\n1. Extract bindings using extract_bindings tool\n2. Identify all lambda bindings and their scopes\n3. Explain how variable bindings create the program's scope topology\n4. Describe how this relates to the program's computational complexity")
   
   (hash 'name "convert_natural_language_to_operation"
         'description "Convert a natural language query into an executable M-expression"
         'arguments (list
                    (hash 'name "query"
                          'description "Natural language query describing the operation"
                          'required #t))
         'template "Convert the following natural language query into an M-expression:\n\n\"{{query}}\"\n\nPlease:\n1. Use process_natural_language tool to convert the query\n2. Parse the resulting M-expression\n3. Explain what operation will be performed\n4. Show how the M-expression represents the user's intent")
   
   (hash 'name "comprehensive_program_analysis"
         'description "Perform comprehensive analysis including H¹, CFG, complexity, and combinator detection"
         'arguments (list
                    (hash 'name "source_code"
                          'description "Scheme source code to analyze"
                          'required #t))
         'template "Perform comprehensive analysis of the following Scheme program:\n\n```scheme\n{{source_code}}\n```\n\nPlease:\n1. Use analyze_program tool for complete analysis\n2. Identify any Y/Z combinators present\n3. Explain the control flow graph structure\n4. Relate H¹ cohomology to cyclomatic complexity\n5. Provide recommendations for program optimization")
   
   (hash 'name "validate_hypothesis_for_program"
         'description "Validate the Computational Scheme Theory hypothesis H¹ = V(G) - k for a program"
         'arguments (list
                    (hash 'name "source_code"
                          'description "Scheme source code to analyze"
                          'required #t)
                    (hash 'name "k"
                          'description "Normalization constant (default: 0)"
                          'required #f)
                    (hash 'name "tolerance"
                          'description "Allowed tolerance (default: 0)"
                          'required #f))
         'template "Validate the Computational Scheme Theory hypothesis for this program:\n\n```scheme\n{{source_code}}\n```\n\nPlease:\n1. Compute H¹ cohomology\n2. Compute V(G) cyclomatic complexity\n3. Validate the hypothesis H¹ = V(G) - {{k}}\n4. If validation fails, explain why and what the difference means\n5. Discuss the relationship between static binding structure and dynamic control flow")
   
   (hash 'name "analyze_file_from_disk"
         'description "Analyze a Scheme file from the filesystem"
         'arguments (list
                    (hash 'name "file_path"
                          'description "Path to Scheme file (absolute or relative)"
                          'required #t))
         'template "Analyze the Scheme file at: {{file_path}}\n\nPlease:\n1. Use analyze_file tool to read and analyze the file\n2. Report all complexity metrics\n3. Identify any interesting patterns or structures\n4. Compare with typical program complexity")
   
   (hash 'name "explain_m_expression_system"
         'description "Explain the M-expression and S-expression duality in Computational Scheme Theory"
         'arguments (list)
         'template "Explain the M-expression and S-expression duality in Computational Scheme Theory:\n\n1. What are M-expressions and how do they represent user intent?\n2. What are S-expressions and how do they represent immutable facts?\n3. How do they relate to event sourcing?\n4. Demonstrate using parse_m_expression and convert_m_to_s tools\n5. Show how this enables deterministic natural language interfaces")
   
   (hash 'name "detect_combinators_in_program"
         'description "Detect Y/Z combinators and other recursive patterns in Scheme code"
         'arguments (list
                    (hash 'name "source_code"
                          'description "Scheme source code to analyze"
                          'required #t))
         'template "Detect combinators in this Scheme program:\n\n```scheme\n{{source_code}}\n```\n\nPlease:\n1. Use detect_combinators tool to find Y/Z combinators\n2. Explain what combinators are and why they're significant\n3. Describe how combinators relate to recursion and fixed points\n4. Discuss their impact on program complexity")))

;; Get list of MCP prompts (for protocol)
(define (get-mcp-prompts)
  "Return list of prompt definitions for MCP protocol"
  (map (lambda (prompt)
         (hash 'name (hash-ref prompt 'name)
               'description (hash-ref prompt 'description)
               'arguments (hash-ref prompt 'arguments)))
       mcp-prompt-definitions))

;; Get a specific prompt by name with argument substitution
(define (get-mcp-prompt name args)
  "Get prompt template with arguments substituted - returns MCP prompt format"
  (let ([prompt (findf (lambda (p) (equal? (hash-ref p 'name) name)) mcp-prompt-definitions)])
    (if prompt
        (let* ([template (hash-ref prompt 'template "")]
               [substituted-template (substitute-prompt-args template args)])
          (hash 'messages (list
                           (hash 'role "user"
                                 'content (hash 'type "text"
                                                'text substituted-template)))))
        (hash 'error (format "Prompt '~a' not found" name)))))

;; Substitute arguments in prompt template
(define (substitute-prompt-args template args)
  "Substitute {{arg_name}} placeholders in template with values from args hash"
  (let loop ([result template]
             [remaining-args (hash->list args)])
    (if (null? remaining-args)
        result
        (let* ([arg-pair (car remaining-args)]
               [arg-name (symbol->string (car arg-pair))]
               [arg-value (cdr arg-pair)]
               [placeholder (format "{{~a}}" arg-name)]
               [new-result (string-replace result placeholder (format "~a" arg-value))])
          (loop new-result (cdr remaining-args))))))
