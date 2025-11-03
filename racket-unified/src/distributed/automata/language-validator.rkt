#lang racket/base

;; Language Validator L(M)
;; Validates state transitions against recognized language of automaton

(require racket/set
         racket/match
         racket/string
         racket/list)

(provide
 ;; Core structures
 language-validator?
 language-validator-automaton
 language-validator-accepted-language
 language-validator-rules
 ;; Validation rules
 validation-rule?
 validation-rule-name
 validation-rule-predicate
 ;; Operations
 validate-transition-in-language
 validate-state-change
 validate-command
 check-language-membership
 ;; Predefined languages
 TRANSACTION_LANGUAGE
 create-transaction-validator)

;; ============================================================
;; Language Validator Structure
;; ============================================================

;; Language validator: validates transitions against L(M)
(struct language-validator (automaton accepted-language rules)
  #:transparent)

;; Validation rule: (name, predicate function)
(struct validation-rule (name predicate)
  #:transparent)

;; ============================================================
;; Transition Validation
;; ============================================================

(define (validate-transition-in-language validator transition)
  "Check if transition is in L(M) - the recognized language"
  (let ([rules (language-validator-rules validator)]
        [accepted-language (language-validator-accepted-language validator)])
    
    ;; Check all rules
    (let ([rule-results
           (for/list ([rule rules])
             (let ([predicate (validation-rule-predicate rule)])
               (predicate transition)))])
      
      ;; All rules must pass
      (and (andmap (lambda (x) x) rule-results)
           (check-language-membership accepted-language transition)))))

(define (validate-state-change validator old-state new-state event)
  "Validate state change transition"
  (let ([transition (list old-state new-state event)])
    (validate-transition-in-language validator transition)))

(define (validate-command validator command current-state)
  "Validate command before execution"
  (let ([transition (list 'command command current-state)])
    (validate-transition-in-language validator transition)))

(define (check-language-membership language transition)
  "Check if transition string is in accepted language"
  (let ([transition-string (transition-to-string transition)])
    (set-member? language transition-string)))

(define (transition-to-string transition)
  "Convert transition to string representation"
  (string-join (map symbol->string (flatten transition)) " → "))

;; ============================================================
;; Predefined Validation Languages
;; ============================================================

;; Transaction validation language
(define TRANSACTION_LANGUAGE
  (set
   "balance >= amount"
   "sender.authenticated = true"
   "transaction.signature valid"
   "state_transition ∈ L(M)"
   "no_double_spend"
   "timestamp_valid"
   "causal_order_preserved"))

;; Validation rules for transactions
(define (create-balance-rule)
  (validation-rule
   'balance-check
   (lambda (transition)
     (match transition
       [(list old-state new-state (list 'transfer amount from to))
        (>= (get-balance from) amount)]
       [(list old-state new-state (list 'withdraw amount account))
        (>= (get-balance account) amount)]
       [_ #t]))))

(define (create-authentication-rule)
  (validation-rule
   'authentication-check
   (lambda (transition)
     (match transition
       [(list old-state new-state (list 'transfer amount from to))
        (authenticated? from)]
       [(list old-state new-state (list 'withdraw amount account))
        (authenticated? account)]
       [_ #t]))))

(define (create-signature-rule)
  (validation-rule
   'signature-check
   (lambda (transition)
     (match transition
       [(list old-state new-state (list 'transfer amount from to signature))
        (valid-signature? signature from amount to)]
       [_ #t]))))

(define (create-double-spend-rule)
  (validation-rule
   'double-spend-check
   (lambda (transition)
     (match transition
       [(list old-state new-state (list 'transfer amount from to))
        (not (transaction-exists? from amount))]
       [_ #t]))))

;; Placeholder functions (would be implemented with actual state)
(define (get-balance account) 100)  ; Placeholder
(define (authenticated? account) #t)  ; Placeholder
(define (valid-signature? signature from amount to) #t)  ; Placeholder
(define (transaction-exists? from amount) #f)  ; Placeholder

;; ============================================================
;; Transaction Validator Factory
;; ============================================================

(define (create-transaction-validator automaton)
  "Create validator for transaction language"
  (language-validator
   automaton
   TRANSACTION_LANGUAGE
   (list
    (create-balance-rule)
    (create-authentication-rule)
    (create-signature-rule)
    (create-double-spend-rule))))

;; ============================================================
;; Example Usage
;; ============================================================

(module+ test
  (require rackunit)
  
  (let ([validator (create-transaction-validator #f)])  ; No automaton needed for basic rules
    ;; Test valid transition
    (check-true (validate-transition-in-language validator
                                      '(q_idle q_pending (transfer 100 account1 account2))))
    
    ;; Test invalid transition (would fail balance check if implemented)
    ;; (check-false (validate-transition validator
    ;;                                   '(q_idle q_pending (transfer 200 account1 account2))))
    ))
