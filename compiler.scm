#lang racket
(define (compose functions)
  (foldr (lambda (curr rest)
           (lambda (x) (curr rest)))
         (lambda (x) x)
         functions))
(define (make-tagged tag datum)
  (list tag datum))
(define (tagged->tag tagged)
  (list-ref tagged 0))
(define (tagged->datum tagged)
  (list-ref tagged 1))
(define (tag=? tag tagged)
  (eq? (tagged->tag tagged) tag))
(define (parse-s-expr expr)
  (define (const? expr)
    (or (number? expr)
        (eq? expr #t)
        (eq? expr #f)))
  (define (identifier? expr)
    (symbol? expr))
  (define (lambda? expr)
    (eq? 'lambda (car expr)))
  (define (let? expr)
    (or (eq? 'let (car expr))
        (eq? 'let* (car expr))))
  (define (if-then-else? expr)
    (eq? 'if (car expr)))
  (define (cond? expr)
    (eq? 'cond (car expr)))
  (define (letrec? expr)
    (eq? 'letrec (car expr)))
  (define (call? expr)
    (pair? expr))
  (define (lambda->binding-vars expr)
    (list-ref expr 1))
  (define (lambda->body expr)
    (list-ref expr 2))
  (define (let->bindings expr)
    (map (lambda (x) (list-ref x 0)) (list-ref expr 1)))
  (define (let->binding-inits expr)
    (map (lambda (x) (list-ref x 1)) (list-ref expr 1)))
  (define (let->body expr)
    (list-ref expr 2))
  (define (if-then-else->if expr)
    (list-ref expr 1))
  (define (if-then-else->then expr)
    (list-ref expr 2))
  (define (if-then-else->else expr)
    (list-ref expr 3))
  (define (letrec->name expr)
    (list-ref (list-ref expr 1) 0))
  (define (letrec->induction-variables expr)
    (cdr (list-ref expr 1)))
  (define (letrec->body expr)
    (list-ref expr 2))
  (define (call->applicator expr)
    (parse-s-expr (list-ref expr 0)))
  (define (call->applicands expr)
    (map parse-s-expr (cdr expr)))
  (define (parse-cond-subs expr)
    (define (parse-cond-sub sub)
      (list (parse-s-expr (list-ref sub 0))
            (parse-s-expr (list-ref sub 1))))
    (map parse-cond-sub (cdr expr)))
  (cond
    [(const? expr) (make-tagged 'const expr)]
    [(identifier? expr) (make-tagged 'identifier expr)]
    [(lambda? expr) (make-tagged 'lambda (list (lambda->binding-vars expr)
                                               (parse-s-expr (lambda->body expr))))]
    [(let? expr) (make-tagged 'let (list (let->bindings expr)
                                         (map parse-s-expr (let->binding-inits expr))
                                         (parse-s-expr (let->body expr))))]
    [(if-then-else? expr) (make-tagged 'if-then-else (list (parse-s-expr (if-then-else->if expr))
                                                           (parse-s-expr (if-then-else->then expr))
                                                           (parse-s-expr(if-then-else->else expr))))]
    [(cond? expr) (make-tagged 'cond (parse-cond-subs expr))]
    [(letrec? expr) (make-tagged 'letrec (list (letrec->name expr)
                                               (letrec->induction-variables expr)
                                               (parse-s-expr (letrec->body expr))))]
    [(call? expr) (make-tagged 'call
                               (list
                                (call->applicator expr)
                                (call->applicands  expr)))]))
; Environment
(define (env-sub env)
  (env 'sub))
(define (env-head env)
  (env 'head))
(define (empty-env? env)
  (env 'empty?))
(define (env-val env)
  (env 'val))
(define (env-lookup env expr)
  (if (empty-env? env)
      #f
      (if (eq? (tagged->datum expr) (env-head env))
          (env-val env)
          (env-lookup (env-sub env) expr))))
(define (empty-env)
  (lambda (signal)
    (cond
      [(eq? signal 'sub) '()]
      [(eq? signal 'empty?) #t]
      [(eq? signal 'head) '()]
      [(eq? signal 'val) '()])))
(define (extend-env env binding value) 
  (lambda (signal)
    (cond
      [(eq? signal 'sub) env]
      [(eq? signal 'empty?) #f]
      [(eq? signal 'head) binding]
      [(eq? signal 'val) value])))
; Macro Expansion
(define (expand-macros env expr)
  (define (const? expr)
    (eq? 'const (tagged->tag expr)))
  (define (identifier? expr)
    (eq? 'identifier (tagged->tag expr)))
  (define (lambda? expr)
    (eq? 'lambda (tagged->tag expr)))
  (define (call? expr)
    (eq? 'call (tagged->tag expr)))
  (define (if-then-else? expr)
    (eq? 'if-then-else (tagged->tag expr)))
  (define (let? expr)
    (eq? 'let (tagged->tag expr)))
  (define (letrec? expr)
    (eq? 'letrec (tagged->tag expr)))
  (define (lambda->body expr)
    (list-ref (tagged->datum expr) 1))
  (define (if-then-else->if expr)
    (list-ref (tagged->datum expr) 0))
  (define (if-then-else->then expr)
    (list-ref (tagged->datum expr) 1))
  (define (if-then-else->else expr)
    (list-ref (tagged->datum expr) 2))
  (define (call->applicator expr)
    (list-ref (tagged->datum expr) 0))
  (define (call->applicands expr)
    (list-ref (tagged->datum expr) 1))
  (cond
    [(const? expr) expr]
    [(identifier? expr) (env-lookup env expr)]
    [(lambda? expr) (expand-macros env (lambda->body expr))]
    [(if-then-else? expr) (make-tagged 'if-then-else (list (expand-macros env (if-then-else->if expr))
                                                           (expand-macros env (if-then-else->then expr))
                                                           (expand-macros env (if-then-else->else expr))))]
    [(let? expr) expr] ; TODO : Implement macro expansion for lets
    [(letrec? expr) expr] ; TODO Implement macro expansion for letrecs
    [(call? expr) (make-tagged 'call (list (expand-macros env (call->applicator expr))
                                           (map (lambda (applicand) (expand-macros env applicand)) (call->applicands expr))))]))
                                       
; Desugaring layer
; Code reusability can be greatly improved here lmao
(define (multi-binding-let->nested-let expr)
  (define (let->bindings expr)
    (list-ref (tagged->datum expr) 0))
  (define (let->binding-inits expr)
    (list-ref (tagged->datum expr) 1))
  (define (let->body expr)
    (list-ref (tagged->datum expr) 2))
  (define (multi-binding-let->nested-let-impl bindings inits body)
    (if (null? bindings)
        (make-tagged 'let (list '() '() body))
        (make-tagged 'let (list (list (car bindings))
                                (list (car inits))
                                (multi-binding-let->nested-let-impl (cdr bindings) (cdr inits) body)))))
  (multi-binding-let->nested-let-impl (let->bindings expr) (let->binding-inits expr) (let->body expr)))
(define (let->redundant-lambda expr)
  (define (let->bindings expr)
    (list-ref (tagged->datum expr) 0))
  (define (let->binding-inits expr)
    (list-ref (tagged->datum expr) 1))
  (define (let->body expr)
    (list-ref (tagged->datum expr) 2))
  (if (eq? 'let (tagged->tag expr))
      (make-tagged 'call (list (make-tagged 'lambda (list (let->bindings expr) (let->redundant-lambda (let->body expr))))
                               (let->binding-inits expr)))
      expr))
(define (letrec->fix-form expr)
  (define (letrec->name expr)
    (list-ref expr 1))
  (define (letrec->induction-variables expr)
    (list-ref expr 2))
  (define (letrec->body expr)
    (list-ref expr 3))
  (define (letrec-body->fix-body expr)
    '())
  (make-tagged 'call (list (parse-s-expr '(lambda (f)
                                            ((lambda (x)
                                               (f (lambda (y)
                                                    ((x x) y))))
                                             (lambda (x)
                                               (f (lambda (y)
                                                    ((x x) y)))))))
                           (make-tagged 'lambda (list '(self)
                                                      (letrec-body->fix-body expr))))))
(define (desugar expr)
  (define (const? expr)
    (eq? 'const (tagged->tag expr)))
  (define (identifier? expr)
    (eq? 'identifier (tagged->tag expr)))
  (define (lambda? expr)
    (eq? 'lambda (tagged->tag expr)))
  (define (call? expr)
    (eq? 'call (tagged->tag expr)))
  (define (if-then-else? expr)
    (eq? 'if-then-else (tagged->tag expr)))
  (define (let? expr)
    (eq? 'let (tagged->tag expr)))
  (define (letrec? expr)
    (eq? 'letrec (tagged->tag expr)))
  (cond
    [(let? expr) (let->redundant-lambda (multi-binding-let->nested-let expr))]
    [(letrec? expr) (letrec->fix-form expr)]
    [else expr]))
; Generators
(define (generate-constant out env expr)
  (display (tagged->datum expr) out))
(define (generate-identifier out env expr)
  (if (null? expr)
      '()
      (if (env-lookup env expr)
          (display (tagged->datum expr) out)
          (error "Invalid identifier"))))
(define (generate-lambda out env expr)
  (define (generate-lambda-binding-vars out env vars)
    (if (null? vars)
        '()
        (begin
          (display (car vars) out)
          (if (not (null? (cdr vars)))
              (begin
                (display "," out)
                (generate-lambda-binding-vars out env (cdr vars)))
              '()))))
  (define (make-lambda-env env expr)
    (define (add-bindings env bindings)
      (if (null? bindings)
          env
          (extend-env (add-bindings env (cdr bindings))
                      (car bindings) #t)))
    (add-bindings env (lambda->binding-vars expr)))
  (define (lambda->binding-vars expr)
    (list-ref (tagged->datum expr) 0))
  (define (lambda->body expr)
    (list-ref (tagged->datum expr) 1))
  (display "(" out)
  (generate-lambda-binding-vars out env (lambda->binding-vars expr))
  (display ")" out)
  (display " => " out)
  (display "{ return " out)
  (generate-expr out (make-lambda-env env expr) (lambda->body expr))
  (display "; }" out))
(define (generate-call out env expr)
  (define (call->applicator expr)
    (list-ref (tagged->datum expr) 0))
  (define (call->applicands expr)
    (list-ref (tagged->datum expr) 1))
  (define (generate-call-impl out env applicator applicands)
    (define (generate-applicator-evaluation applicator)
      (define (convert-to-eval-lambda applicator)
        (make-tagged 'lambda (list '()
                                   applicator)))
      (display "(" out)
      (generate-lambda out env (convert-to-eval-lambda applicator))
      (display ")" out))
    (define (generate-applicands applicands)
      (if (null? applicands)
          (display "" out)
          (begin
            (generate-expr out env (car applicands))
            (if (null? (cdr applicands))
                (display "" out)
                (begin
                  (display ",")
                  (generate-applicands (cdr applicands)))))))
    (generate-applicator-evaluation applicator)
    (display "()" out)
    (display "(" out)
    (generate-applicands applicands)
    (display ")" out))
  (generate-call-impl out env (call->applicator expr) (call->applicands expr)))
(define (generate-if-then-else out env expr)
  (define (if-then-else->if expr)
    (list-ref (tagged->datum expr) 0))
  (define (if-then-else->then expr)
    (list-ref (tagged->datum expr) 1))
  (define (if-then-else->else expr)
    (list-ref (tagged->datum expr) 2))
  (display "(()" out)
  (display " => " out)
  (display " { " out)
  (display " if " out)
  (display "(" out)
  (generate-expr out env (if-then-else->if expr))
  (display ")" out)
  (display " { return " out)
  (generate-expr out env (if-then-else->then expr))
  (display " ;} " out)
  (display " else " out)
  (display " { return " out)
  (generate-expr out env (if-then-else->else expr))
  (display " ;} " out)
  (display " })" out)
  (display "()" out))
(define (generate-expr out env expr)
  (define (const? expr)
    (eq? 'const (tagged->tag expr)))
  (define (identifier? expr)
    (eq? 'identifier (tagged->tag expr)))
  (define (lambda? expr)
    (eq? 'lambda (tagged->tag expr)))
  (define (call? expr)
    (eq? 'call (tagged->tag expr)))
  (define (if-then-else? expr)
    (eq? 'if-then-else (tagged->tag expr)))
  (cond
    [(null? expr) (display " " out)]
    [(const? expr) (generate-constant out env expr)]
    [(identifier? expr) (generate-identifier out env expr)]
    [(lambda? expr) (generate-lambda out env expr)]
    [(call? expr) (generate-call out env expr)]
    [(if-then-else? expr) (generate-if-then-else out env expr)]))
; Utility functions for testing
(define (string->s-expr text)
  (port->list read (open-input-string text)))
(define (parse-string text)
  (map parse-s-expr (string->s-expr text)))
(define (compile port env expr)
  (generate-expr port env (desugar expr)))
                               
