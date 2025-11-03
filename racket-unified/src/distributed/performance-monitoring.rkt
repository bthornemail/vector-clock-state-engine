#lang racket/base

;; Performance Monitoring and Metrics for Distributed State Machine
;; Tracks performance metrics and provides optimization

(require racket/match
         racket/date)

(provide
 ;; Metrics structures
 performance-metrics?
 performance-metrics-transaction-count
 performance-metrics-total-latency
 performance-metrics-successful-transactions
 performance-metrics-failed-transactions
 performance-metrics-conflicted-transactions
 performance-metrics-cache-hits
 performance-metrics-cache-misses
 performance-metrics-start-time
 ;; Monitoring
 transaction-monitor?
 transaction-monitor-metrics
 transaction-monitor-cache
 transaction-monitor-timing-start
 ;; Operations
 start-transaction-timing
 end-transaction-timing
 record-transaction
 record-conflict
 record-cache-hit
 record-cache-miss
 get-performance-metrics
 ;; Cache
 transaction-cache?
 transaction-cache-cache
 transaction-cache-max-size
 cache-get
 cache-set
 cache-clear
 ;; Factory
 create-transaction-monitor
 ;; Optimization
 optimize-pipeline
 batch-transactions)

;; ============================================================
;; Performance Metrics Structure
;; ============================================================

(struct performance-metrics
  (transaction-count
   total-latency
   successful-transactions
   failed-transactions
   conflicted-transactions
   cache-hits
   cache-misses
   start-time)
  #:transparent
  #:mutable)

;; ============================================================
;; Transaction Monitor
;; ============================================================

(struct transaction-monitor
  (metrics cache timing-start)
  #:transparent
  #:mutable)

;; ============================================================
;; Transaction Cache
;; ============================================================

(struct transaction-cache
  (cache max-size)
  #:transparent
  #:mutable)

;; ============================================================
;; Performance Metrics Calculations
;; ============================================================

(define (get-average-latency metrics)
  "Calculate average latency"
  (let ([count (performance-metrics-transaction-count metrics)]
        [total (performance-metrics-total-latency metrics)])
    (if (> count 0)
        (/ total count)
        0)))

(define (get-success-rate metrics)
  "Calculate success rate"
  (let ([total (performance-metrics-transaction-count metrics)]
        [successful (performance-metrics-successful-transactions metrics)])
    (if (> total 0)
        (/ successful total)
        0)))

(define (get-conflict-rate metrics)
  "Calculate conflict rate"
  (let ([total (performance-metrics-transaction-count metrics)]
        [conflicted (performance-metrics-conflicted-transactions metrics)])
    (if (> total 0)
        (/ conflicted total)
        0)))

(define (get-cache-hit-rate metrics)
  "Calculate cache hit rate"
  (let ([hits (performance-metrics-cache-hits metrics)]
        [misses (performance-metrics-cache-misses metrics)])
    (if (> (+ hits misses) 0)
        (/ hits (+ hits misses))
        0)))

(define (get-performance-metrics monitor)
  "Get formatted performance metrics"
  (let ([metrics (transaction-monitor-metrics monitor)])
    (list
     `(transaction-count ,(performance-metrics-transaction-count metrics))
     `(average-latency ,(get-average-latency metrics))
     `(success-rate ,(get-success-rate metrics))
     `(conflict-rate ,(get-conflict-rate metrics))
     `(cache-hit-rate ,(get-cache-hit-rate metrics))
     `(uptime ,(- (current-seconds)
                  (performance-metrics-start-time metrics))))))

;; ============================================================
;; Transaction Timing
;; ============================================================

(define (start-transaction-timing monitor)
  "Start timing a transaction"
  (set-transaction-monitor-timing-start! monitor (current-milliseconds))
  monitor)

(define (end-transaction-timing monitor)
  "End timing and record latency"
  (let* ([start (transaction-monitor-timing-start monitor)]
         [end (current-milliseconds)]
         [latency (- end start)])
    (when start
      (let ([metrics (transaction-monitor-metrics monitor)])
        (set-performance-metrics-total-latency!
         metrics
         (+ (performance-metrics-total-latency metrics) latency))))
    latency))

;; ============================================================
;; Recording Operations
;; ============================================================

(define (record-transaction monitor status)
  "Record transaction completion"
  (let ([metrics (transaction-monitor-metrics monitor)])
    (set-performance-metrics-transaction-count!
     metrics
     (+ (performance-metrics-transaction-count metrics) 1))
    
    (when (eq? status 'committed)
      (set-performance-metrics-successful-transactions!
       metrics
       (+ (performance-metrics-successful-transactions metrics) 1)))
    
    (when (member status '(rejected rolled-back))
      (set-performance-metrics-failed-transactions!
       metrics
       (+ (performance-metrics-failed-transactions metrics) 1)))))

(define (record-conflict monitor)
  "Record conflict"
  (let ([metrics (transaction-monitor-metrics monitor)])
    (set-performance-metrics-conflicted-transactions!
     metrics
     (+ (performance-metrics-conflicted-transactions metrics) 1))))

(define (record-cache-hit monitor)
  "Record cache hit"
  (let ([metrics (transaction-monitor-metrics monitor)])
    (set-performance-metrics-cache-hits!
     metrics
     (+ (performance-metrics-cache-hits metrics) 1))))

(define (record-cache-miss monitor)
  "Record cache miss"
  (let ([metrics (transaction-monitor-metrics monitor)])
    (set-performance-metrics-cache-misses!
     metrics
     (+ (performance-metrics-cache-misses metrics) 1))))

;; ============================================================
;; Cache Operations
;; ============================================================

(define (cache-get cache key)
  "Get value from cache"
  (let ([cached (transaction-cache-cache cache)])
    (hash-ref cached key #f)))

(define (cache-set cache key value)
  "Set value in cache"
  (let* ([current-cache (transaction-cache-cache cache)]
         [max-size (transaction-cache-max-size cache)]
         [current-size (hash-count current-cache)])
    
    ;; If cache is full, remove oldest entry (FIFO)
    (when (and max-size (>= current-size max-size))
      (let ([first-key (car (hash-keys current-cache))])
        (hash-remove! current-cache first-key)))
    
    ;; Add new entry
    (hash-set! (transaction-cache-cache cache) key value)
    value))

(define (cache-clear cache)
  "Clear cache"
  (set-transaction-cache-cache! cache (make-hash))
  cache)

;; ============================================================
;; Factory Functions
;; ============================================================

(define (create-transaction-monitor [max-cache-size 1000])
  "Create transaction monitor with metrics and cache"
  (let ([metrics (performance-metrics 0 0 0 0 0 0 0 (current-seconds))])
    (transaction-monitor metrics (transaction-cache (make-hash) max-cache-size) #f)))

;; ============================================================
;; Pipeline Optimization
;; ============================================================

(define (optimize-pipeline pipeline monitor)
  "Optimize pipeline based on metrics"
  (let ([metrics (transaction-monitor-metrics monitor)])
    ;; Clear cache if hit rate is too low
    (when (< (get-cache-hit-rate metrics) 0.1)
      (cache-clear (transaction-monitor-cache monitor))
      (printf "Cache cleared due to low hit rate\n"))
    
    ;; Log performance warnings
    (when (> (get-conflict-rate metrics) 0.5)
      (printf "WARNING: High conflict rate: ~a\n" (get-conflict-rate metrics)))
    
    (when (> (get-average-latency metrics) 1000)
      (printf "WARNING: High average latency: ~a ms\n" (get-average-latency metrics)))
    
    pipeline))

(define (batch-transactions pipeline monitor transactions)
  "Process multiple transactions in batch"
  ;; Dynamic require to avoid circular dependency
  (let ([execute-transaction (dynamic-require "distributed/pipeline.rkt" 'execute-transaction)]
        [get-status (dynamic-require "distributed/pipeline.rkt" 'transaction-result-status)])
    (let ([results '()])
      (for ([tx transactions])
        (let ([result (execute-transaction pipeline tx)])
          (record-transaction monitor (get-status result))
          (set! results (cons result results))))
      (reverse results))))

;; ============================================================
;; Example Usage
;; ============================================================

(module+ test
  (require rackunit)
  
  (let ([monitor (create-transaction-monitor)])
    ;; Test cache
    (cache-set (transaction-monitor-cache monitor) 'test-key 'test-value)
    (check-equal? (cache-get (transaction-monitor-cache monitor) 'test-key) 'test-value)
    
    ;; Test metrics
    (record-transaction monitor 'committed)
    (record-transaction monitor 'rejected)
    (record-conflict monitor)
    
    (let ([metrics (get-performance-metrics monitor)])
      (check-true (> (length metrics) 0) "Should have metrics"))))

(module+ main
  (printf "Performance Monitoring System\n")
  (printf "============================\n\n")
  
  (let ([monitor (create-transaction-monitor)])
    (printf "Created transaction monitor\n")
    (printf "Max cache size: ~a\n" (transaction-cache-max-size (transaction-monitor-cache monitor)))
    (printf "\nReady for monitoring!\n")))
