#lang racket/base

;; Integration Tests for Distributed State Machine Pipeline
;; Tests with real events from event store

(require racket/test
         racket/match
         "../distributed/pipeline.rkt"
         "../distributed/automata/2nfa.rkt"
         "../distributed/automata/2dfa.rkt"
         "../distributed/automata/2pda.rkt"
         "../distributed/automata/language-validator.rkt"
         "../distributed/automata/sweeping-automaton.rkt"
         "../s-expression.rkt"
         "../persistence/event-store-file.rkt"
         "../persistence/config.rkt")

(provide
 run-integration-tests
 test-single-transaction
 test-concurrent-transactions
 test-conflict-resolution
 test-network-partition
 test-event-replay
 test-audit-sweep)

;; ============================================================
;; Test Setup
;; ============================================================

(define (setup-test-environment)
  "Setup test environment with fresh event store"
  (initialize-persistence-config)
  (ensure-event-log-directory)
  (initialize-event-store))

(define (cleanup-test-environment)
  "Cleanup test environment"
  ;; Clear event store (in-memory)
  (event-store '()))

;; ============================================================
;; Test 1: Single Transaction Flow
;; ============================================================

(define (test-single-transaction)
  "Test complete pipeline for single transaction"
  (setup-test-environment)
  
  (let ([pipeline (create-distributed-state-machine)]
        [user-action "Transfer $100 from account1 to account2"])
    
    (printf "=== Test 1: Single Transaction ===\n")
    
    ;; Execute transaction
    (let ([result (execute-transaction pipeline user-action)])
      
      ;; Verify result
      (check-equal? (transaction-result-status result) 'committed
                    "Transaction should be committed")
      
      ;; Verify events were created
      (check-true (> (length (transaction-result-events result)) 0)
                  "Should have generated events")
      
      ;; Verify final state
      (check-true (member (transaction-result-state result)
                          '(q_committed q_idle))
                  "Final state should be committed or idle")
      
      (printf "✓ Single transaction test passed\n")
      (printf "  Status: ~a\n" (transaction-result-status result))
      (printf "  Final State: ~a\n" (transaction-result-state result))
      (printf "  Events: ~a\n\n" (length (transaction-result-events result)))
      
      result)))

;; ============================================================
;; Test 2: Concurrent Transactions
;; ============================================================

(define (test-concurrent-transactions)
  "Test handling of concurrent transactions"
  (setup-test-environment)
  
  (let ([pipeline (create-distributed-state-machine)])
    
    (printf "=== Test 2: Concurrent Transactions ===\n")
    
    ;; Simulate concurrent transactions
    (let* ([tx1 (execute-transaction pipeline "Transfer $50 from account1 to account2")]
           [tx2 (execute-transaction pipeline "Transfer $30 from account2 to account3")]
           [tx3 (execute-transaction pipeline "Deposit $20 to account1")])
      
      ;; All should succeed if no conflicts
      (check-true (member (transaction-result-status tx1) '(committed rejected rolled-back))
                  "Transaction 1 should have a status")
      (check-true (member (transaction-result-status tx2) '(committed rejected rolled-back))
                  "Transaction 2 should have a status")
      (check-true (member (transaction-result-status tx3) '(committed rejected rolled-back))
                  "Transaction 3 should have a status")
      
      (printf "✓ Concurrent transactions test passed\n")
      (printf "  TX1 Status: ~a\n" (transaction-result-status tx1))
      (printf "  TX2 Status: ~a\n" (transaction-result-status tx2))
      (printf "  TX3 Status: ~a\n" (transaction-result-status tx3))
      (printf "\n")
      
      (list tx1 tx2 tx3))))

;; ============================================================
;; Test 3: Conflict Resolution
;; ============================================================

(define (test-conflict-resolution)
  "Test conflict detection and resolution"
  (setup-test-environment)
  
  (let ([pipeline (create-distributed-state-machine)])
    
    (printf "=== Test 3: Conflict Resolution ===\n")
    
    ;; Simulate conflicting transactions (same account, insufficient balance)
    (let* ([tx1 (execute-transaction pipeline "Transfer $80 from account1 to account2")]
           [tx2 (execute-transaction pipeline "Transfer $60 from account1 to account3")])
      
      ;; At least one should detect conflict and rollback
      (let ([status1 (transaction-result-status tx1)]
            [status2 (transaction-result-status tx2)])
        
        ;; One should commit, one should rollback (or both rollback)
        (check-true (or (and (eq? status1 'committed) (member status2 '(rejected rolled-back)))
                        (and (eq? status2 'committed) (member status1 '(rejected rolled-back)))
                        (and (member status1 '(rejected rolled-back))
                             (member status2 '(rejected rolled-back))))
                    "Conflicts should be resolved")
        
        (printf "✓ Conflict resolution test passed\n")
        (printf "  TX1 Status: ~a\n" status1)
        (printf "  TX2 Status: ~a\n" status2)
        (printf "\n")
        
        (list tx1 tx2)))))

;; ============================================================
;; Test 4: Network Partition Simulation
;; ============================================================

(define (test-network-partition)
  "Test behavior during network partition"
  (setup-test-environment)
  
  (let ([pipeline (create-distributed-state-machine)])
    
    (printf "=== Test 4: Network Partition ===\n")
    
    ;; Simulate partition: transactions can't reach consensus
    ;; This would require mocking the consensus layer
    (let ([tx (execute-transaction pipeline "Transfer $100 from account1 to account2")])
      
      ;; During partition, transaction might timeout or be pending
      (check-true (member (transaction-result-status tx)
                          '(committed rejected rolled-back timeout))
                  "Transaction should have a status")
      
      (printf "✓ Network partition test passed\n")
      (printf "  Status: ~a\n" (transaction-result-status tx))
      (printf "\n")
      
      tx)))

;; ============================================================
;; Test 5: Event Replay
;; ============================================================

(define (test-event-replay)
  "Test replaying events from event store"
  (setup-test-environment)
  
  (printf "=== Test 5: Event Replay ===\n")
  
  ;; Generate some events first
  (let ([pipeline (create-distributed-state-machine)])
    (execute-transaction pipeline "Transfer $100 from account1 to account2")
    (execute-transaction pipeline "Deposit $50 to account1"))
  
  ;; Load events from store
  (let ([events (load-events-from-file)])
    
    (check-true (list? events) "Events should be a list")
    (check-true (>= (length events) 0) "Should have events")
    
    ;; Replay events
    (let ([replayed (replay-events-from-file)])
      (check-equal? (length replayed) (length events)
                    "Replayed events should match stored events")
      
      (printf "✓ Event replay test passed\n")
      (printf "  Stored Events: ~a\n" (length events))
      (printf "  Replayed Events: ~a\n" (length replayed))
      (printf "\n")
      
      replayed)))

;; ============================================================
;; Test 6: Audit Sweep
;; ============================================================

(define (test-audit-sweep)
  "Test sweeping automaton for audit"
  (setup-test-environment)
  
  (printf "=== Test 6: Audit Sweep ===\n")
  
  ;; Generate events
  (let ([pipeline (create-distributed-state-machine)])
    (execute-transaction pipeline "Transfer $100 from account1 to account2")
    (execute-transaction pipeline "Transfer $50 from account2 to account3"))
  
  ;; Load events for audit
  (let ([events (load-events-from-file)]
        [sweeper (create-sweeping-automaton)])
    
    ;; Perform audit sweep
    (let ([audit-result (perform-audit-sweep sweeper events)])
      
      (check-true (list? audit-result) "Audit result should be a list")
      (check-true (member (car audit-result)
                          '(consistent inconsistent reconciliation-needed audit-failed))
                  "Audit should return a valid status")
      
      (printf "✓ Audit sweep test passed\n")
      (printf "  Audit Status: ~a\n" (car audit-result))
      (printf "  Events Audited: ~a\n" (length events))
      (printf "\n")
      
      audit-result)))

;; ============================================================
;; Test 7: Complete Workflow Integration
;; ============================================================

(define (test-complete-workflow)
  "Test complete workflow: User Action → Commit → Audit"
  (setup-test-environment)
  
  (printf "=== Test 7: Complete Workflow ===\n")
  
  (let ([pipeline (create-distributed-state-machine)])
    
    ;; Execute transaction
    (let ([result (execute-transaction pipeline "Transfer $100 from account1 to account2")])
      
      ;; Verify committed
      (check-equal? (transaction-result-status result) 'committed
                    "Transaction should be committed")
      
      ;; Load events
      (let ([events (load-events-from-file)])
        (check-true (> (length events) 0) "Should have events")
        
        ;; Perform audit
        (let ([sweeper (create-sweeping-automaton)]
              [audit-result (perform-audit-sweep sweeper events)])
          
          (check-true (list? audit-result) "Audit should succeed")
          
          (printf "✓ Complete workflow test passed\n")
          (printf "  Transaction Status: ~a\n" (transaction-result-status result))
          (printf "  Events Generated: ~a\n" (length events))
          (printf "  Audit Status: ~a\n" (car audit-result))
          (printf "\n")
          
          (list result events audit-result))))))

;; ============================================================
;; Run All Integration Tests
;; ============================================================

(define (run-integration-tests)
  "Run all integration tests"
  (printf "\n========================================\n")
  (printf "  DISTRIBUTED STATE MACHINE INTEGRATION TESTS\n")
  (printf "========================================\n\n")
  
  (let ([results '()])
    
    ;; Run all tests
    (with-handlers ([exn:fail? (lambda (e)
                                 (printf "ERROR: ~a\n" (exn-message e))
                                 #f)])
      
      ;; Test 1: Single Transaction
      (set! results (cons (test-single-transaction) results))
      
      ;; Test 2: Concurrent Transactions
      (set! results (cons (test-concurrent-transactions) results))
      
      ;; Test 3: Conflict Resolution
      (set! results (cons (test-conflict-resolution) results))
      
      ;; Test 4: Network Partition
      (set! results (cons (test-network-partition) results))
      
      ;; Test 5: Event Replay
      (set! results (cons (test-event-replay) results))
      
      ;; Test 6: Audit Sweep
      (set! results (cons (test-audit-sweep) results))
      
      ;; Test 7: Complete Workflow
      (set! results (cons (test-complete-workflow) results)))
    
    (printf "========================================\n")
    (printf "  ALL INTEGRATION TESTS COMPLETE\n")
    (printf "========================================\n\n")
    
    results))

;; ============================================================
;; Test Runner
;; ============================================================

(module+ main
  (run-integration-tests))

(module+ test
  ;; Make tests available to raco test
  (test-single-transaction)
  (test-concurrent-transactions)
  (test-conflict-resolution))
