#lang racket/base

;; Two-Way Nondeterministic Finite Automaton (2NFA)
;; For distributed replication with bidirectional retry capability

(require racket/set
         racket/match)

(provide
 ;; Core structures
 2nfa?
 2nfa-states
 2nfa-alphabet
 2nfa-left-marker
 2nfa-right-marker
 2nfa-transitions
 2nfa-start
 2nfa-accept
 2nfa-reject
 2nfa-transition?
 2nfa-transition-from-state
 2nfa-transition-input
 2nfa-transition-next-states
 2nfa-transition-direction
 ;; Configuration
 2nfa-config?
 2nfa-config-state
 2nfa-config-position
 2nfa-config-input-tape
 ;; Operations
 2nfa-get-transitions
 2nfa-step
 2nfa-run
 2nfa-accepts?
 ;; Replication-specific
 create-replication-2nfa
 2nfa-propagate
 2nfa-rollback)

;; ============================================================
;; Core 2NFA Structure
;; ============================================================

;; Two-way NFA: M = (Q, Σ, L, R, δ, s, t, r)
;; Where:
;; - Q: finite set of states
;; - Σ: finite alphabet
;; - L: left endmarker
;; - R: right endmarker
;; - δ: Q × (Σ ∪ {L, R}) → 2^Q × {left, right}  (nondeterministic)
;; - s: start state
;; - t: accept state
;; - r: reject state

(struct 2nfa (states alphabet left-marker right-marker transitions start accept reject)
  #:transparent)

;; Transition structure: δ(state, input) → (set of next states, direction)
(struct 2nfa-transition (from-state input next-states direction)
  #:transparent)

;; Configuration: (state, position, input tape)
(struct 2nfa-config (state position input-tape)
  #:transparent)

;; ============================================================
;; 2NFA Operations
;; ============================================================

(define (2nfa-get-transitions automaton state input)
  "Get transition set for state and input"
  (let ([transitions (2nfa-transitions automaton)])
    (hash-ref transitions (cons state input) (set))))

(define (2nfa-step automaton config)
  "Execute one step of 2NFA computation"
  (let ([current-state (2nfa-config-state config)]
        [position (2nfa-config-position config)]
        [tape (2nfa-config-input-tape config)]
        [left-marker (2nfa-left-marker automaton)]
        [right-marker (2nfa-right-marker automaton)])
    
    ;; Determine current input symbol
    (let ([current-input
           (cond
             [(< position 0) left-marker]
             [(>= position (length tape)) right-marker]
             [else (list-ref tape position)])])
      
      ;; Get transitions for current state and input
      (let ([transitions (2nfa-get-transitions automaton current-state current-input)])
        (if (set-empty? transitions)
            ;; No transition - reject
            (set (2nfa-config (2nfa-reject automaton) position tape))
            ;; Apply all possible transitions
            (for/set ([trans transitions])
              (let* ([next-states (2nfa-transition-next-states trans)]
                     [direction (2nfa-transition-direction trans)]
                     [next-position
                      (match direction
                        ['left (max -1 (- position 1))]
                        ['right (+ position 1)])])
                ;; Create configs for all next states
                (for/set ([next-state next-states])
                  (2nfa-config next-state next-position tape)))))))))

(define (2nfa-run automaton input-tape max-steps)
  "Run 2NFA on input tape, return all possible configurations"
  (let ([start-config (2nfa-config (2nfa-start automaton) 0 input-tape)]
        [accept-set (2nfa-accept automaton)])
    
    (let loop ([configs (set start-config)]
               [steps 0])
      (cond
        ;; Check if any config is in accept state
        [(for/or ([config configs])
           (set-member? accept-set (2nfa-config-state config)))
         #t]
        
        ;; Max steps reached
        [(>= steps max-steps) #f]
        
        ;; No more configs (rejected)
        [(set-empty? configs) #f]
        
        ;; Continue computation
        [else
         (let ([next-configs (set)])
           (for ([config configs])
             (let ([new-configs (2nfa-step automaton config)])
               (set! next-configs (set-union next-configs new-configs))))
           (loop next-configs (+ steps 1)))]))))

(define (2nfa-accepts? automaton input-tape)
  "Check if 2NFA accepts input (within reasonable step limit)"
  (2nfa-run automaton input-tape 1000))

;; ============================================================
;; Replication-Specific 2NFA
;; ============================================================

(define (create-replication-2nfa)
  "Create 2NFA for transaction replication"
  (let* ([states (set 'q_idle 'q_pending 'q_propagating 'q_committed 'q_aborted)]
         [alphabet (set 'transfer 'withdraw 'deposit 'conflict 'success 'failure)]
         [transitions (make-hash)])
    
    ;; Forward propagation transitions (right)
    (hash-set! transitions
               (cons 'q_idle 'transfer)
               (set (2nfa-transition 'q_idle 'transfer (set 'q_pending) 'right)))
    
    (hash-set! transitions
               (cons 'q_pending 'R)  ; Right endmarker = propagate
               (set (2nfa-transition 'q_pending 'R (set 'q_propagating) 'right)))
    
    (hash-set! transitions
               (cons 'q_propagating 'R)
               (set (2nfa-transition 'q_propagating 'R (set 'q_committed) 'right)))
    
    ;; Backward rollback transitions (left)
    (hash-set! transitions
               (cons 'q_propagating 'conflict)
               (set (2nfa-transition 'q_propagating 'conflict (set 'q_aborted) 'left)))
    
    (hash-set! transitions
               (cons 'q_aborted 'L)  ; Left endmarker = rollback
               (set (2nfa-transition 'q_aborted 'L (set 'q_idle) 'left)))
    
    ;; Success path
    (hash-set! transitions
               (cons 'q_propagating 'success)
               (set (2nfa-transition 'q_propagating 'success (set 'q_committed) 'right)))
    
    (2nfa states
          alphabet
          'L
          'R
          transitions
          'q_idle
          (set 'q_committed)
          'q_aborted)))

(define (2nfa-propagate automaton transaction)
  "Propagate transaction through replication network"
  (let ([input-tape (list transaction 'R 'R)])  ; transaction → propagate → commit
    (if (2nfa-accepts? automaton input-tape)
        'committed
        'rejected)))

(define (2nfa-rollback automaton)
  "Rollback transaction using leftward movement"
  (let ([input-tape (list 'conflict 'L)])  ; conflict → rollback
    (if (2nfa-accepts? automaton input-tape)
        'rolled-back
        'rollback-failed)))

;; ============================================================
;; Example Usage
;; ============================================================

(module+ test
  (require rackunit)
  
  (let ([replication-2nfa (create-replication-2nfa)])
    ;; Test forward propagation
    (check-true (2nfa-accepts? replication-2nfa (list 'transfer 'R 'R)))
    
    ;; Test rollback
    (let ([rollback-2nfa (create-replication-2nfa)])
      (check-true (2nfa-accepts? rollback-2nfa (list 'transfer 'R 'conflict 'L))))))
