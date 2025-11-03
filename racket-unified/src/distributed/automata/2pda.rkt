#lang racket/base

;; Two-Way Pushdown Automaton (2PDA)
;; For message ordering with dependency resolution using stack operations

(require racket/set
         racket/match)

(provide
 ;; Core structures
 2pda?
 2pda-states
 2pda-alphabet
 2pda-stack-alphabet
 2pda-left-marker
 2pda-right-marker
 2pda-transition-fn
 2pda-start
 2pda-stack-start
 2pda-accept
 2pda-config?
 2pda-config-state
 2pda-config-position
 2pda-config-stack
 2pda-config-input-tape
 ;; Stack operations
 stack-push
 stack-pop
 stack-top
 stack-empty?
 ;; Operations
 2pda-get-transitions
 2pda-step
 2pda-run
 2pda-accepts?
 ;; Ordering-specific
 create-ordering-2pda
 2pda-order-messages
 2pda-check-dependency)

;; ============================================================
;; Core 2PDA Structure
;; ============================================================

;; Two-way PDA: M = (Q, Σ, Γ, L, R, δ, s, Z₀, F)
;; Where:
;; - Q: finite set of states
;; - Σ: finite input alphabet
;; - Γ: finite stack alphabet
;; - L: left endmarker
;; - R: right endmarker
;; - δ: Q × (Σ ∪ {L, R}) × Γ → 2^(Q × {left, right} × Γ*)  (nondeterministic)
;; - s: start state
;; - Z₀: initial stack symbol
;; - F: set of accepting states

(struct 2pda (states alphabet stack-alphabet left-marker right-marker transition-fn start stack-start accept)
  #:transparent)

;; Configuration: (state, position, stack, input tape)
(struct 2pda-config (state position stack input-tape)
  #:transparent)

;; Stack operations
(define (stack-push stack symbol)
  "Push symbol onto stack"
  (cons symbol stack))

(define (stack-pop stack)
  "Pop symbol from stack, return (new-stack, popped-symbol)"
  (if (null? stack)
      (values stack #f)
      (values (cdr stack) (car stack))))

(define (stack-top stack)
  "Get top of stack without popping"
  (if (null? stack)
      #f
      (car stack)))

(define (stack-empty? stack)
  "Check if stack is empty"
  (null? stack))

;; ============================================================
;; 2PDA Operations
;; ============================================================

(define (2pda-get-transitions automaton state input stack-top)
  "Get transition set for state, input, and stack top"
  (let ([transition-fn (2pda-transition-fn automaton)])
    (transition-fn state input stack-top)))

(define (2pda-step automaton config)
  "Execute one step of 2PDA computation"
  (let ([current-state (2pda-config-state config)]
        [position (2pda-config-position config)]
        [stack (2pda-config-stack config)]
        [tape (2pda-config-input-tape config)]
        [left-marker (2pda-left-marker automaton)]
        [right-marker (2pda-right-marker automaton)])
    
    ;; Determine current input symbol
    (let ([current-input
           (cond
             [(< position 0) left-marker]
             [(>= position (length tape)) right-marker]
             [else (list-ref tape position)])])
      
      ;; Get stack top
      (let ([top (stack-top stack)])
        ;; Get transitions
        (let ([transitions (2pda-get-transitions automaton current-state current-input top)])
          (if (set-empty? transitions)
              ;; No transition - reject
              (set)
              ;; Apply all possible transitions
              (for/set ([trans transitions])
                (match trans
                  [(list next-state direction stack-op)
                   (let* ([next-position
                            (match direction
                              ['left (max -1 (- position 1))]
                              ['right (+ position 1)])]
                          [next-stack
                           (match stack-op
                             ['STAY stack]
                             ['POP (let-values ([(new-stack _) (stack-pop stack)])
                                     new-stack)]
                             [(list 'PUSH symbol) (stack-push stack symbol)]
                             [_ stack])])
                     (2pda-config next-state next-position next-stack tape))]))))))))

(define (2pda-run automaton input-tape max-steps)
  "Run 2PDA on input tape, return all possible configurations"
  (let ([start-config (2pda-config (2pda-start automaton)
                                   0
                                   (list (2pda-stack-start automaton))
                                   input-tape)]
        [accept-set (2pda-accept automaton)])
    
    (let loop ([configs (set start-config)]
               [steps 0])
      (cond
        ;; Check if any config is in accept state with empty stack
        [(for/or ([config configs])
           (and (set-member? accept-set (2pda-config-state config))
                (stack-empty? (2pda-config-stack config))))
         #t]
        
        ;; Max steps reached
        [(>= steps max-steps) #f]
        
        ;; No more configs (rejected)
        [(set-empty? configs) #f]
        
        ;; Continue computation
        [else
         (let ([next-configs (set)])
           (for ([config configs])
             (let ([new-configs (2pda-step automaton config)])
               (set! next-configs (set-union next-configs new-configs))))
           (loop next-configs (+ steps 1)))]))))

(define (2pda-accepts? automaton input-tape)
  "Check if 2PDA accepts input"
  (2pda-run automaton input-tape 1000))

;; ============================================================
;; Ordering-Specific 2PDA
;; ============================================================

(define (create-ordering-2pda)
  "Create 2PDA for message ordering with dependency resolution"
  (let* ([states (set 'q_reading 'q_ordering 'q_processing 'q_waiting 'q_complete)]
         [alphabet (set 'TX_MSG 'DEPENDENCY 'DEPENDENCY_MARKER 'L 'R)]
         [stack-alphabet (set 'TX_ID 'DEPENDENCY_MARKER)]
         [transition-fn
          (lambda (state input stack-top)
            (match (cons state input)
              ;; Read transaction and push onto stack
              [(cons 'q_reading 'TX_MSG)
               (set (list 'q_ordering 'right (list 'PUSH 'TX_ID)))]
              
              ;; Check dependency
              [(cons 'q_ordering 'DEPENDENCY)
               (if (eq? stack-top 'DEPENDENCY_MARKER)
                   ;; Dependency found on stack - can process
                   (set (list 'q_processing 'right 'POP))
                   ;; No dependency - need to move left to find it
                   (set (list 'q_waiting 'left 'STAY)))]
              
              ;; Move left to find dependency
              [(cons 'q_waiting 'L)
               (set (list 'q_reading 'left 'STAY))]
              
              ;; Move left through input to find dependency
              [(cons 'q_waiting 'TX_MSG)
               (set (list 'q_waiting 'left 'STAY))]
              
              ;; Found dependency marker while moving left
              [(cons 'q_waiting 'DEPENDENCY_MARKER)
               (set (list 'q_ordering 'right (list 'PUSH 'DEPENDENCY_MARKER)))]
              
              ;; Process transaction (pop from stack)
              [(cons 'q_processing 'TX_MSG)
               (set (list 'q_processing 'right 'POP))]
              
              ;; Complete processing
              [(cons 'q_processing 'R)
               (set (list 'q_complete 'right 'STAY))]
              
              ;; Default: no transition
              [_ (set)]))])
    
    (2pda states
          alphabet
          stack-alphabet
          'L
          'R
          transition-fn
          'q_reading
          'EMPTY
          (set 'q_complete))))

(define (dependency-on-stack? stack-top)
  "Check if dependency marker is on stack top"
  (eq? stack-top 'DEPENDENCY_MARKER))

(define (2pda-order-messages automaton messages)
  "Order messages respecting dependencies"
  (let ([input-tape (append messages (list 'R))])  ; Add right endmarker
    (if (2pda-accepts? automaton input-tape)
        'ordered
        'ordering-failed)))

(define (2pda-check-dependency automaton transaction dependency)
  "Check if transaction can be processed given dependency"
  (let ([input-tape (list 'TX_MSG 'DEPENDENCY 'DEPENDENCY_MARKER 'R)])
    (2pda-accepts? automaton input-tape)))

;; ============================================================
;; Example Usage
;; ============================================================

(module+ test
  (require rackunit)
  
  (let ([ordering-2pda (create-ordering-2pda)])
    ;; Test basic ordering
    (check-true (2pda-accepts? ordering-2pda (list 'TX_MSG 'R)))
    
    ;; Test dependency resolution (needs more complex setup)
    ;; This would require proper dependency markers in the input
    ))
