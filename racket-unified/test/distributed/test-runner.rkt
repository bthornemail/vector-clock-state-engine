#lang racket/base

;; Comprehensive Test Runner for Distributed State Machine
;; Runs all tests and generates report

(require racket/test
         racket/format
         "integration-tests.rkt"
         "../src/distributed/event-store-integration.rkt"
         "../src/distributed/performance-monitoring.rkt")

(provide
 run-all-tests
 generate-test-report
 test-suite-results?)

;; ============================================================
;; Test Suite Results
;; ============================================================

(struct test-suite-results
  (total-tests passed-tests failed-tests errors warnings duration)
  #:transparent)

;; ============================================================
;; Test Runner
;; ============================================================

(define (run-all-tests)
  "Run all tests and return results"
  (let ([start-time (current-milliseconds)]
        [test-results '()]
        [passed 0]
        [failed 0]
        [errors '()])
    
    (printf "\n")
    (printf "╔════════════════════════════════════════════════════════════╗\n")
    (printf "║  DISTRIBUTED STATE MACHINE - COMPREHENSIVE TEST SUITE     ║\n")
    (printf "╚════════════════════════════════════════════════════════════╝\n\n")
    
    ;; Run integration tests
    (printf "Running Integration Tests...\n")
    (printf "─────────────────────────────\n")
    
    (with-handlers ([exn:fail? (lambda (e)
                                 (printf "ERROR: ~a\n" (exn-message e))
                                 (set! errors (cons e errors))
                                 (set! failed (+ failed 1)))])
      
      ;; Test 1: Single Transaction
      (printf "[1/7] Single Transaction Test... ")
      (let ([result (test-single-transaction)])
        (if result
            (begin (printf "✓ PASSED\n")
                   (set! passed (+ passed 1))
                   (set! test-results (cons (list 'single-transaction #t result) test-results)))
            (begin (printf "✗ FAILED\n")
                   (set! failed (+ failed 1))
                   (set! test-results (cons (list 'single-transaction #f #f) test-results)))))
      
      ;; Test 2: Concurrent Transactions
      (printf "[2/7] Concurrent Transactions Test... ")
      (let ([result (test-concurrent-transactions)])
        (if result
            (begin (printf "✓ PASSED\n")
                   (set! passed (+ passed 1))
                   (set! test-results (cons (list 'concurrent-transactions #t result) test-results)))
            (begin (printf "✗ FAILED\n")
                   (set! failed (+ failed 1))
                   (set! test-results (cons (list 'concurrent-transactions #f #f) test-results)))))
      
      ;; Test 3: Conflict Resolution
      (printf "[3/7] Conflict Resolution Test... ")
      (let ([result (test-conflict-resolution)])
        (if result
            (begin (printf "✓ PASSED\n")
                   (set! passed (+ passed 1))
                   (set! test-results (cons (list 'conflict-resolution #t result) test-results)))
            (begin (printf "✗ FAILED\n")
                   (set! failed (+ failed 1))
                   (set! test-results (cons (list 'conflict-resolution #f #f) test-results)))))
      
      ;; Test 4: Network Partition
      (printf "[4/7] Network Partition Test... ")
      (let ([result (test-network-partition)])
        (if result
            (begin (printf "✓ PASSED\n")
                   (set! passed (+ passed 1))
                   (set! test-results (cons (list 'network-partition #t result) test-results)))
            (begin (printf "✗ FAILED\n")
                   (set! failed (+ failed 1))
                   (set! test-results (cons (list 'network-partition #f #f) test-results)))))
      
      ;; Test 5: Event Replay
      (printf "[5/7] Event Replay Test... ")
      (let ([result (test-event-replay)])
        (if result
            (begin (printf "✓ PASSED\n")
                   (set! passed (+ passed 1))
                   (set! test-results (cons (list 'event-replay #t result) test-results)))
            (begin (printf "✗ FAILED\n")
                   (set! failed (+ failed 1))
                   (set! test-results (cons (list 'event-replay #f #f) test-results)))))
      
      ;; Test 6: Audit Sweep
      (printf "[6/7] Audit Sweep Test... ")
      (let ([result (test-audit-sweep)])
        (if result
            (begin (printf "✓ PASSED\n")
                   (set! passed (+ passed 1))
                   (set! test-results (cons (list 'audit-sweep #t result) test-results)))
            (begin (printf "✗ FAILED\n")
                   (set! failed (+ failed 1))
                   (set! test-results (cons (list 'audit-sweep #f #f) test-results)))))
      
      ;; Test 7: Complete Workflow
      (printf "[7/7] Complete Workflow Test... ")
      (let ([result (test-complete-workflow)])
        (if result
            (begin (printf "✓ PASSED\n")
                   (set! passed (+ passed 1))
                   (set! test-results (cons (list 'complete-workflow #t result) test-results)))
            (begin (printf "✗ FAILED\n")
                   (set! failed (+ failed 1))
                   (set! test-results (cons (list 'complete-workflow #f #f) test-results)))))
      )
    
    ;; Calculate duration
    (let ([end-time (current-milliseconds)]
          [duration (- (current-milliseconds) start-time)])
      
      ;; Print summary
      (printf "\n")
      (printf "╔════════════════════════════════════════════════════════════╗\n")
      (printf "║  TEST SUMMARY                                              ║\n")
      (printf "╠════════════════════════════════════════════════════════════╣\n")
      (printf "║  Total Tests: ~a                                          ║\n" (+ passed failed))
      (printf "║  Passed:      ~a                                          ║\n" passed)
      (printf "║  Failed:      ~a                                          ║\n" failed)
      (printf "║  Duration:    ~a ms                                       ║\n" duration)
      (printf "╚════════════════════════════════════════════════════════════╝\n")
      
      ;; Generate report
      (let ([results (test-suite-results
                      (+ passed failed)
                      passed
                      failed
                      errors
                      '()
                      duration)])
        (generate-test-report results)
        results))))

;; ============================================================
;; Test Report Generation
;; ============================================================

(define (generate-test-report results)
  "Generate detailed test report"
  (let ([report-file "test-results/report.txt"])
    (make-directory* "test-results")
    
    (with-output-to-file report-file
      (lambda ()
        (printf "DISTRIBUTED STATE MACHINE TEST REPORT\n")
        (printf "=====================================\n\n")
        (printf "Generated: ~a\n\n" (date->string (seconds->date (current-seconds)) #t))
        (printf "Test Results:\n")
        (printf "  Total Tests: ~a\n" (test-suite-results-total-tests results))
        (printf "  Passed:      ~a\n" (test-suite-results-passed-tests results))
        (printf "  Failed:      ~a\n" (test-suite-results-failed-tests results))
        (printf "  Duration:   ~a ms\n" (test-suite-results-duration results))
        (printf "\n")
        
        (when (> (length (test-suite-results-errors results)) 0)
          (printf "Errors:\n")
          (for ([error (test-suite-results-errors results)])
            (printf "  - ~a\n" (exn-message error)))))
      
      #:exists 'replace)
    
    (printf "\nTest report saved to: ~a\n" report-file)))

;; ============================================================
;; Main Entry Point
;; ============================================================

(module+ main
  (run-all-tests))
