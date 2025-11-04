#lang racket/base

(require json
         racket/port
         racket/string
         "json-rpc.rkt"
         "mcp-tools.rkt"
         "mcp-resources.rkt"
         "mcp-prompts.rkt")

(provide
 start-mcp-server)

;; ============================================================
;; MCP Server - Main Implementation
;; ============================================================

;; MCP Protocol Version
(define MCP_PROTOCOL_VERSION "2024-11-05")

;; Initialize handler
(define (handle-initialize params)
  "Handle MCP initialize request"
  (hash 'protocolVersion MCP_PROTOCOL_VERSION
        'capabilities (hash
                      'tools (hash)
                      'resources (hash)
                      'prompts (hash))
        'serverInfo (hash
                    'name "computational-scheme-theory"
                    'version "0.1.0")))

;; Tools/list handler
(define (handle-tools-list params)
  "Handle tools/list request"
  (hash 'tools (get-mcp-tools)))

;; Tools/call handler
(define (handle-tools-call params)
  "Handle tools/call request - returns result in MCP content format"
  (with-handlers ([exn? (lambda (e)
                         (let ([error-hash (hash 'success #f 
                                                 'error (exn-message e)
                                                 'tool "tools/call")])
                           (hash 'content (list (hash 'type "text"
                                                      'text (jsexpr->string error-hash))))))])
    (let* ([name (hash-ref params 'name #f)]
           [arguments (hash-ref params 'arguments (hash))])
      (if name
          (let ([tool-result (call-mcp-tool name arguments)])
            ;; MCP requires result.content array with text items
            (hash 'content (list (hash 'type "text"
                                       'text (jsexpr->string tool-result)))))
          (let ([error-hash (hash 'success #f 'error "Missing tool name")])
            (hash 'content (list (hash 'type "text"
                                       'text (jsexpr->string error-hash)))))))))

;; Resources/list handler
(define (handle-resources-list params)
  "Handle resources/list request"
  (hash 'resources (get-mcp-resources)))

;; Resources/read handler
(define (handle-resources-read params)
  "Handle resources/read request - returns result in MCP contents format"
  (with-handlers ([exn? (lambda (e)
                         (let ([error-msg (format "Error reading resource: ~a" (exn-message e))])
                           (hash 'contents (list (hash 'uri ""
                                                       'mimeType "text/plain"
                                                       'text error-msg)))))])
    (let ([uri (hash-ref params 'uri #f)])
      (if uri
          (let ([resource-result (read-mcp-resource uri)])
            ;; MCP requires result.contents array with content items
            (if (hash-has-key? resource-result 'error)
                ;; Error case - return error message in contents
                (let ([error-text (hash-ref resource-result 'error "Unknown error")])
                  (hash 'contents (list (hash 'uri uri
                                              'mimeType "text/plain"
                                              'text error-text))))
                ;; Success case - return resource data
                (let ([mime-type (hash-ref resource-result 'mimeType "application/json")]
                      [text-content (hash-ref resource-result 'text "")])
                  (hash 'contents (list (hash 'uri uri
                                              'mimeType mime-type
                                              'text text-content))))))
          (hash 'contents (list (hash 'uri ""
                                      'mimeType "text/plain"
                                      'text "Missing resource URI")))))))

;; Prompts/list handler
(define (handle-prompts-list params)
  "Handle prompts/list request"
  (hash 'prompts (get-mcp-prompts)))

;; Prompts/get handler
(define (handle-prompts-get params)
  "Handle prompts/get request - returns prompt with argument substitution"
  (with-handlers ([exn? (lambda (e)
                         (hash 'error (format "Error getting prompt: ~a" (exn-message e))))])
    (let* ([name (hash-ref params 'name #f)]
           [arguments (hash-ref params 'arguments (hash))])
      (if name
          (get-mcp-prompt name arguments)
          (hash 'error "Missing prompt name")))))

;; Method router
(define (route-mcp-method method params)
  "Route MCP method to appropriate handler"
  (case method
    [("initialize") (handle-initialize params)]
    [("tools/list") (handle-tools-list params)]
    [("tools/call") (handle-tools-call params)]
    [("resources/list") (handle-resources-list params)]
    [("resources/read") (handle-resources-read params)]
    [("prompts/list") (handle-prompts-list params)]
    [("prompts/get") (handle-prompts-get params)]
    [else #f]))

;; Process a single JSON-RPC request
(define (process-request request-json)
  "Process a JSON-RPC request and return response"
  (cond
    ;; Validate request structure
    [(not (mcp-validate-request request-json))
     (mcp-create-error-response
      (get-request-id request-json)
      INVALID_REQUEST
      "Invalid JSON-RPC request")]
    
    ;; Route to method handler
    [else
     (let* ([method (get-request-method request-json)]
            [params (get-request-params request-json)]
            [id (get-request-id request-json)]
            [result (route-mcp-method method params)])
       (if result
           (mcp-create-response id result)
           (mcp-create-error-response
            id
            METHOD_NOT_FOUND
            (format "Method '~a' not found" method))))]))

;; Main server loop (stdio mode)
(define (start-mcp-server)
  "Start MCP server on stdio for AI assistant integration"
  ;; Log to stderr (so stdout is only for JSON-RPC)
  (fprintf (current-error-port) "Computational Scheme Theory MCP Server starting...\n")
  (flush-output (current-error-port))
  
  ;; Main request loop
  (let loop ([line-count 0])
    (let ([line (read-line)])
      (cond
        ;; EOF - exit gracefully
        [(eof-object? line)
         (fprintf (current-error-port) "MCP Server shutting down.\n")
         (flush-output (current-error-port))]
        
        ;; Empty line - skip
        [(string=? (string-trim line) "")
         (loop line-count)]
        
        ;; Process request
        [else
         (with-handlers ([exn? (lambda (e)
                                ;; Catch any unexpected errors and log to stderr
                                (fprintf (current-error-port) 
                                        "Error processing request: ~a\n" 
                                        (exn-message e))
                                (flush-output (current-error-port))
                                ;; Send error response
                                (let ([response (mcp-create-error-response
                                                 #f
                                                 INTERNAL_ERROR
                                                 (format "Internal server error: ~a" (exn-message e)))])
                                  (displayln (jsexpr->string response))
                                  (flush-output)))])
           (let* ([request-json (mcp-parse-request line)])
             (if request-json
                 (let ([response (process-request request-json)])
                   ;; Write response to stdout (JSON-RPC protocol)
                   (displayln (jsexpr->string response))
                   (flush-output))
                 (begin
                   ;; Parse error
                   (let ([response (mcp-create-error-response
                                    #f
                                    PARSE_ERROR
                                    "Parse error")])
                     (displayln (jsexpr->string response))
                     (flush-output)))))
           (loop (+ line-count 1)))]))))

;; Main entry point
(module+ main
  (start-mcp-server))

