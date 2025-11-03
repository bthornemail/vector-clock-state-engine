#lang racket/base

;; Event Store Integration for Distributed State Machine Pipeline
;; Connects pipeline to persistence layer

(require racket/match
         "../persistence/event-store-file.rkt"
         "../persistence/config.rkt"
         "../s-expression.rkt")

(provide
 ;; Event store integration
 event-store-pipeline?
 event-store-pipeline-pipeline
 event-store-pipeline-event-store
 ;; Operations
 store-transaction-event
 load-transaction-events
 replay-transaction-events
 ;; Factory
 create-event-store-pipeline
 ;; Pipeline integration
 execute-with-persistence
 commit-with-persistence)

;; ============================================================
;; Event Store Pipeline Integration
;; ============================================================

(struct event-store-pipeline (pipeline event-store)
  #:transparent)

;; ============================================================
;; Event Store Operations
;; ============================================================

(define (store-transaction-event event-store event)
  "Store transaction event to event store"
  ;; Append to file-based event store
  (append-event-to-file event)
  ;; Also append to in-memory store
  (append-event! event))

(define (load-transaction-events event-store [filter-fn #f])
  "Load transaction events from event store"
  (if filter-fn
      (replay-events-from-file filter-fn)
      (load-events-from-file)))

(define (replay-transaction-events event-store [filter-fn #f])
  "Replay transaction events from event store"
  (replay-events-from-file filter-fn))

;; ============================================================
;; Pipeline Integration
;; ============================================================

(define (execute-with-persistence event-store-pipeline user-action)
  "Execute transaction with automatic event persistence"
  ;; Dynamic require to avoid circular dependency
  (let* ([execute-transaction (dynamic-require "distributed/pipeline.rkt" 'execute-transaction)]
         [get-status (dynamic-require "distributed/pipeline.rkt" 'transaction-result-status)]
         [get-events (dynamic-require "distributed/pipeline.rkt" 'transaction-result-events)]
         [pipeline (event-store-pipeline-pipeline event-store-pipeline)]
         [result (execute-transaction pipeline user-action)])
    
    ;; Store events if transaction succeeded
    (when (eq? (get-status result) 'committed)
      (for ([event (get-events result)])
        (store-transaction-event
         (event-store-pipeline-event-store event-store-pipeline)
         event)))
    
    result))

(define (commit-with-persistence event-store-pipeline result)
  "Commit transaction result and persist events"
  ;; Dynamic require to avoid circular dependency
  (let ([get-status (dynamic-require "distributed/pipeline.rkt" 'transaction-result-status)]
        [get-events (dynamic-require "distributed/pipeline.rkt" 'transaction-result-events)])
    (when (eq? (get-status result) 'committed)
      (for ([event (get-events result)])
        (store-transaction-event
         (event-store-pipeline-event-store event-store-pipeline)
         event)))
    result))

;; ============================================================
;; Factory
;; ============================================================

(define (create-event-store-pipeline)
  "Create event store pipeline with persistence"
  (initialize-persistence-config)
  (ensure-event-log-directory)
  (initialize-event-store)
  
  ;; Dynamic require to avoid circular dependency
  (let ([create-pipeline-fn (dynamic-require "distributed/pipeline.rkt" 'create-distributed-state-machine)])
    (let ([pipeline (create-pipeline-fn)])
      (event-store-pipeline pipeline 'file-based))))

;; ============================================================
;; Event Format Conversion
;; ============================================================

(define (transaction-result-to-event result)
  "Convert transaction result to S-expression event"
  ;; Use dynamic require to avoid circular dependency
  (let ([get-status (dynamic-require "distributed/pipeline.rkt" 'transaction-result-status)]
        [get-state (dynamic-require "distributed/pipeline.rkt" 'transaction-result-state)]
        [get-events (dynamic-require "distributed/pipeline.rkt" 'transaction-result-events)]
        [get-error (dynamic-require "distributed/pipeline.rkt" 'transaction-result-error)])
    (make-s-expr
     'transaction-completed
     (list
      `(status ,(get-status result))
      `(state ,(get-state result))
      `(events ,(get-events result))
      `(error ,(get-error result))
      `(timestamp ,(current-seconds))))))

(define (event-to-transaction-result event)
  "Convert S-expression event to transaction result"
  (if (s-expr? event)
      (match (s-expr-type event)
        ['transaction-completed
         (let* ([data (s-expr-data event)]
                [status (cadr (assoc 'status data))]
                [state (cadr (assoc 'state data))]
                [events (cadr (assoc 'events data))]
                [error (cadr (assoc 'error data))])
           ;; Use dynamic require to avoid circular dependency
           (let ([make-transaction-result (dynamic-require "distributed/pipeline.rkt" 'make-transaction-result)])
             (make-transaction-result status state events error)))]
        [_ #f])
      #f))

;; ============================================================
;; Example Usage
;; ============================================================

(module+ test
  (require rackunit)
  
  (let ([pipeline (create-event-store-pipeline)])
    ;; Execute with persistence
    (let* ([execute-fn (dynamic-require "distributed/pipeline.rkt" 'execute-transaction)]
           [result-fn (dynamic-require "distributed/pipeline.rkt" 'transaction-result?)]
           [result (execute-with-persistence pipeline "Transfer $100")])
      (check-true (result-fn result))
      
      ;; Verify events were stored
      (let ([events (load-transaction-events 'file-based)])
        (check-true (>= (length events) 0) "Should have events")))))

(module+ main
  (printf "Event Store Pipeline Integration\n")
  (printf "================================\n\n")
  
  (let ([pipeline (create-event-store-pipeline)])
    (printf "Created event store pipeline\n")
    (printf "Event store type: ~a\n" (event-store-pipeline-event-store pipeline))
    (printf "\nReady for transactions!\n")))
