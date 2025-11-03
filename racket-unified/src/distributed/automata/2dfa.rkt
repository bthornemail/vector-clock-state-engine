#lang racket/base

;; Two-Way Deterministic Finite Automaton (2DFA)
;; For distributed consensus with deterministic bidirectional transitions

(require racket/set
         racket/match)

(provide
 ;; Core structures
 2dfa?
 2dfa-states
 2dfa-alphabet
 2dfa-left-marker
 2dfa-right-marker
 2dfa-transition-fn
 2dfa-start
 2dfa-accept
 2dfa-reject
 2dfa-config?
 2dfa-config-state
 2dfa-config-position
 2dfa-config-input-tape
 ;; Operations
 2dfa-get-transition
 2dfa-step
 2dfa-run
 2dfa-accepts?
 ;; Consensus-specific
 create-consensus-2dfa
 2dfa-propose
 2dfa-promise
 2dfa-accept-message
 2dfa-commit
 2dfa-abort)

;; ============================================================
;; Core 2DFA Structure
;; ============================================================

;; Two-way DFA: M = (Q, Σ, L, R, δ, s, t, r)
;; Where:
;; - Q: finite set of states
;; - Σ: finite alphabet
;; - L: left endmarker
;; - R: right endmarker
;; - δ: Q × (Σ ∪ {L, R}) → Q × {left, right}  (deterministic function)
;; - s: start state
;; - t: accept state
;; - r: reject state

(struct 2dfa (states alphabet left-marker right-marker transition-fn start accept reject)
  #:transparent)

;; Configuration: (state, position, input tape)
(struct 2dfa-config (state position input-tape)
  #:transparent)

;; ============================================================
;; 2DFA Operations
;; ============================================================

(define (2dfa-get-transition automaton state input)
  "Get deterministic transition for state and input"
  (let ([transition-fn (2dfa-transition-fn automaton)])
    (transition-fn state input)))

(define (2dfa-step automaton config)
  "Execute one step of 2DFA computation"
  (let ([current-state (2dfa-config-state config)]
        [position (2dfa-config-position config)]
        [tape (2dfa-config-input-tape config)]
        [left-marker (2dfa-left-marker automaton)]
        [right-marker (2dfa-right-marker automaton)])
    
    ;; Determine current input symbol
    (let ([current-input
           (cond
             [(< position 0) left-marker]
             [(>= position (length tape)) right-marker]
             [else (list-ref tape position)])])
      
      ;; Get deterministic transition
      (let ([transition-result (2dfa-get-transition automaton current-state current-input)])
        (match transition-result
          [(cons next-state direction)
           (let ([next-position
                  (match direction
                    ['left (max -1 (- position 1))]
                    ['right (+ position 1)])])
             (2dfa-config next-state next-position tape))]
          [_ config])))))  ; Invalid transition - stay in current state

(define (2dfa-run automaton input-tape max-steps)
  "Run 2DFA on input tape, return final state"
  (let ([start-config (2dfa-config (2dfa-start automaton) 0 input-tape)]
        [accept-state (2dfa-accept automaton)]
        [reject-state (2dfa-reject automaton)])
    
    (let loop ([config start-config]
               [steps 0])
      (let ([current-state (2dfa-config-state config)])
        (cond
          ;; Accept state reached
          [(eq? current-state accept-state) 'accepted]
          
          ;; Reject state reached
          [(eq? current-state reject-state) 'rejected]
          
          ;; Max steps reached
          [(>= steps max-steps) 'timeout]
          
          ;; Continue computation
          [else
           (let ([next-config (2dfa-step automaton config)])
             (loop next-config (+ steps 1)))])))))

(define (2dfa-accepts? automaton input-tape)
  "Check if 2DFA accepts input"
  (eq? (2dfa-run automaton input-tape 1000) 'accepted))

;; ============================================================
;; Consensus-Specific 2DFA (Paxos-like)
;; ============================================================

(define (create-consensus-2dfa)
  "Create 2DFA for consensus protocol"
  (let* ([states (set 'q_propose 'q_promise 'q_accept 'q_committed 'q_abort)]
         [alphabet (set 'PREPARE 'PROMISE 'ACCEPT 'COMMIT 'ABORT 'quorum 'conflict 'L 'R)]
         [transition-fn
          (lambda (state input)
            (match (cons state input)
              ;; Forward transitions (right)
              [(cons 'q_propose 'PREPARE) (cons 'q_promise 'right)]
              [(cons 'q_promise 'PROMISE) (cons 'q_accept 'right)]
              [(cons 'q_accept 'quorum) (cons 'q_committed 'right)]
              [(cons 'q_accept 'COMMIT) (cons 'q_committed 'right)]
              
              ;; Backward transitions (left - rollback)
              [(cons 'q_accept 'conflict) (cons 'q_abort 'left)]
              [(cons 'q_abort 'L) (cons 'q_propose 'left)]
              
              ;; Endmarker handling
              [(cons 'q_propose 'R) (cons 'q_propose 'right)]  ; Stay at right endmarker
              [(cons 'q_committed 'R) (cons 'q_committed 'right)]  ; Accept state stays
              [(cons 'q_abort 'L) (cons 'q_abort 'left)]  ; Reject state stays
              
              ;; Default: no transition
              [_ (cons state 'right)]))])
    
    (2dfa states
          alphabet
          'L
          'R
          transition-fn
          'q_propose
          'q_committed
          'q_abort)))

;; Consensus protocol operations

(define (2dfa-propose automaton)
  "Propose transaction (PREPARE phase)"
  (let ([input-tape (list 'PREPARE)])
    (if (2dfa-accepts? automaton input-tape)
        'proposed
        'proposal-failed)))

(define (2dfa-promise automaton)
  "Receive promise (PROMISE phase)"
  (let ([input-tape (list 'PREPARE 'PROMISE)])
    (if (2dfa-accepts? automaton input-tape)
        'promised
        'promise-failed)))

(define (2dfa-accept-message automaton quorum-reached?)
  "Accept transaction (ACCEPT phase)"
  (let ([input-tape (if quorum-reached?
                        (list 'PREPARE 'PROMISE 'quorum)
                        (list 'PREPARE 'PROMISE 'conflict))])
    (match (2dfa-run automaton input-tape 1000)
      ['accepted 'committed]
      ['rejected 'aborted]
      [_ 'timeout])))

(define (2dfa-commit automaton)
  "Commit transaction"
  (let ([input-tape (list 'PREPARE 'PROMISE 'quorum 'COMMIT)])
    (if (2dfa-accepts? automaton input-tape)
        'committed
        'commit-failed)))

(define (2dfa-abort automaton)
  "Abort transaction (rollback)"
  (let ([input-tape (list 'PREPARE 'PROMISE 'conflict 'L)])  ; Move left to rollback
    (match (2dfa-run automaton input-tape 1000)
      ['accepted 'aborted]
      ['rejected 'abort-failed]
      [_ 'timeout])))

;; ============================================================
;; Example Usage
;; ============================================================

(module+ test
  (require rackunit)
  
  (let ([consensus-2dfa (create-consensus-2dfa)])
    ;; Test successful consensus path
    (check-equal? (2dfa-run consensus-2dfa (list 'PREPARE 'PROMISE 'quorum) 1000)
                  'accepted)
    
    ;; Test conflict and rollback
    (check-equal? (2dfa-run consensus-2dfa (list 'PREPARE 'PROMISE 'conflict 'L) 1000)
                  'accepted)))  ; Should reach abort state then rollback to propose
