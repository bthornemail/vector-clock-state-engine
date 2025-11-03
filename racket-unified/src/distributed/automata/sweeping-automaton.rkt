#lang racket/base

;; Sweeping Automaton
;; Bidirectional consistency checking for audit and reconciliation

(require racket/set
         racket/match
         racket/list
         "2dfa.rkt")

(provide
 ;; Core structures
 sweeping-automaton?
 sweeping-automaton-left-to-right
 sweeping-automaton-right-to-left
 ;; Audit operations
 sweep-left-to-right
 sweep-right-to-left
 perform-audit-sweep
 reconcile-inconsistency
 ;; Consistency checking
 check-transition-validity
 verify-state-sequence
 detect-inconsistencies
 ;; Factory
 create-sweeping-automaton)

;; ============================================================
;; Sweeping Automaton Structure
;; ============================================================

;; Sweeping automaton: uses 2DFA for bidirectional consistency checking
(struct sweeping-automaton (left-to-right right-to-left)
  #:transparent)

;; ============================================================
;; Left-to-Right Sweep
;; ============================================================

(define (sweep-left-to-right automaton event-history)
  "Sweep left-to-right through event history, verifying transitions"
  (let ([2dfa (sweeping-automaton-left-to-right automaton)]
        [events (list->vector event-history)])
    
    (let loop ([position 0]
               [current-state 'q_start]
               [verified-transitions '()])
      (cond
        ;; Reached end
        [(>= position (vector-length events))
         (list 'ltr-complete verified-transitions current-state)]
        
        ;; Process current event
        [else
         (let ([current-event (vector-ref events position)]
               [input-tape (list (vector-ref events position))])
           (let ([result (2dfa-run 2dfa input-tape 100)])
             (match result
               ['accepted
                (loop (+ position 1)
                      'q_accepted
                      (cons (cons position current-event) verified-transitions))]
               ['rejected
                (list 'ltr-invalid position current-event current-state)]
               [_ (list 'ltr-timeout position current-event)])))]))))

;; ============================================================
;; Right-to-Left Sweep
;; ============================================================

(define (sweep-right-to-left automaton event-history)
  "Sweep right-to-left through event history, verifying backward compatibility"
  (let ([2dfa (sweeping-automaton-right-to-left automaton)]
        [events (reverse (list->vector event-history))])
    
    (let loop ([position 0]
               [current-state 'q_start]
               [verified-transitions '()])
      (cond
        ;; Reached beginning
        [(>= position (vector-length events))
         (list 'rtl-complete verified-transitions current-state)]
        
        ;; Process current event (in reverse)
        [else
         (let ([current-event (vector-ref events position)]
               [input-tape (list 'L (vector-ref events position))])  ; Left movement + event
           (let ([result (2dfa-run 2dfa input-tape 100)])
             (match result
               ['accepted
                (loop (+ position 1)
                      'q_accepted
                      (cons (cons position current-event) verified-transitions))]
               ['rejected
                (list 'rtl-invalid position current-event current-state)]
               [_ (list 'rtl-timeout position current-event)])))]))))

;; ============================================================
;; Complete Audit Sweep
;; ============================================================

(define (perform-audit-sweep automaton event-history)
  "Perform bidirectional sweep to verify consistency"
  
  ;; Left-to-right sweep
  (let ([ltr-result (sweep-left-to-right automaton event-history)])
    
    ;; Right-to-left sweep
    (let ([rtl-result (sweep-right-to-left automaton event-history)])
      
      ;; Compare results
      (match (cons ltr-result rtl-result)
        [(cons (list 'ltr-complete ltr-transitions ltr-state)
               (list 'rtl-complete rtl-transitions rtl-state))
         (if (equal? ltr-transitions (reverse rtl-transitions))
             (list 'consistent ltr-transitions)
             (reconcile-inconsistency automaton ltr-result rtl-result))]
        
        [(cons (list 'ltr-invalid pos event state) _)
         (list 'inconsistent 'ltr pos event)]
        
        [(cons _ (list 'rtl-invalid pos event state))
         (list 'inconsistent 'rtl pos event)]
        
        [_ (list 'audit-failed ltr-result rtl-result)]))))

;; ============================================================
;; Inconsistency Reconciliation
;; ============================================================

(define (reconcile-inconsistency automaton ltr-result rtl-result)
  "Reconcile inconsistencies found during audit"
  (match (cons ltr-result rtl-result)
    [(cons (list 'ltr-complete ltr-transitions _)
           (list 'rtl-complete rtl-transitions _))
     ;; Find positions where transitions differ
     (let ([inconsistencies
            (for/list ([i (range (min (length ltr-transitions)
                                       (length rtl-transitions)))])
              (let ([ltr-trans (list-ref ltr-transitions i)]
                    [rtl-trans (list-ref (reverse rtl-transitions) i)])
                (if (equal? ltr-trans rtl-trans)
                    #f
                    (list i ltr-trans rtl-trans))))])
       (list 'reconciliation-needed
             (filter (lambda (x) x) inconsistencies)))]
    
    [_ (list 'reconciliation-failed ltr-result rtl-result)]))

;; ============================================================
;; Consistency Checking Utilities
;; ============================================================

(define (check-transition-validity from-state to-state event)
  "Check if a single transition is valid"
  (and (symbol? from-state)
       (symbol? to-state)
       (list? event)
       ;; Additional validity checks would go here
       #t))

(define (verify-state-sequence states events)
  "Verify that state sequence matches event sequence"
  (if (= (length states) (+ (length events) 1))
      (let loop ([state-seq states]
                 [event-seq events]
                 [position 0])
        (cond
          [(null? event-seq) #t]
          [(null? (cdr state-seq)) #f]
          [else
           (let ([from-state (car state-seq)]
                 [to-state (cadr state-seq)]
                 [event (car event-seq)])
             (if (check-transition-validity from-state to-state event)
                 (loop (cdr state-seq) (cdr event-seq) (+ position 1))
                 #f))]))
      #f))

(define (detect-inconsistencies event-history)
  "Detect inconsistencies in event history"
  (let ([inconsistencies '()])
    ;; Check for duplicate transactions
    (let ([seen-transactions (make-hash)])
      (for ([event event-history]
            [i (in-naturals)])
        (match event
          [(list 'transfer amount from to)
           (let ([key (list from to amount)])
             (if (hash-has-key? seen-transactions key)
                 (set! inconsistencies
                       (cons (list 'duplicate-transaction i key)
                             inconsistencies))
                 (hash-set! seen-transactions key i)))]
          [_ #f])))
    inconsistencies))

;; ============================================================
;; Create Sweeping Automaton
;; ============================================================

(define (create-sweeping-automaton)
  "Create sweeping automaton for audit"
  (let* ([ltr-2dfa (create-consensus-2dfa)]  ; Use consensus 2DFA as base
         [rtl-2dfa (create-consensus-2dfa)])  ; Same for right-to-left
    (sweeping-automaton ltr-2dfa rtl-2dfa)))

;; ============================================================
;; Example Usage
;; ============================================================

(module+ test
  (require rackunit)
  
  (let ([sweeper (create-sweeping-automaton)]
        [event-history (list '(transfer 100 account1 account2)
                              '(withdraw 50 account2)
                              '(deposit 25 account1))])
    ;; Perform audit sweep
    (let ([result (perform-audit-sweep sweeper event-history)])
      (check-true (list? result))
      ;; Result should be either 'consistent or 'inconsistent
      (check-true (member (car result) '(consistent inconsistent reconciliation-needed))))))
