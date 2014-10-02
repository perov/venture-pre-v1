(declare (usual-integrations apply eval))
(declare (integrate-external "syntax"))
(declare (integrate-external "pattern-case/pattern-case"))

(define (enforce-constraints trace)
  (receive (new-trace weight) (rebuild-rdb trace (rdb-constraints trace))
     (rdb-trace-commit! new-trace trace)))

(define (mcmc-step trace)
  (let* ((target-addr (select-uniformly (random-choices trace)))
         (proposed-value (prior-resimulate target-addr trace))
         (replacements (cons `(,target-addr . ,proposed-value) (rdb-constraints trace))))
    ;; (pp (list target-addr proposed-value))
    ;; (rdb-trace-search-one-record trace target-addr pp (lambda () (error "What?")))
    (receive (new-trace weight) (rebuild-rdb trace replacements)
      (let ((correction (- (log (length (random-choices trace)))
                           (log (length (random-choices new-trace))))))
        (if (< (log (random 1.0)) (+ weight correction))
            (rdb-trace-commit! new-trace trace))))))

(define mcmc-defn
  '(define mcmc
     (lambda (steps)
       (lambda (t)
         (begin
           (enforce-constraints t)
           (map (lambda (i) (mcmc-step t))
                (iota steps)))))))

;; Trick coin

(define trick-coin-example
  `(begin
     ,observe-defn
     (define model-trace (rdb-extend (get-current-trace)))
     (trace-in model-trace
               (begin
                 (define is-trick? (flip 0.5))
                 (define weight (if is-trick? (uniform 0 1) 0.5))
                 ($observe (flip weight) #t)
                 ($observe (flip weight) #t)
                 ($observe (flip weight) #t)
                 ($observe (flip weight) #t)
                 ($observe (flip weight) #t)
                 (define answer (list is-trick? weight))))
     (pp (trace-in (store-extend model-trace) answer))
     ,map-defn
     (enforce-constraints model-trace)
     (map (lambda (i) (mcmc-step model-trace))
          '(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20))
     (trace-in (store-extend model-trace) answer)))

;;; On observations: VKM argues that requiring observe to accept only
;;; a constant (!) (wrt current trace) procedure that has a density as
;;; the top expression is fine, for deep philosophical reasons.  The
;;; extra flexibility afforded by nesting and inference programming
;;; may go a long way to alleviating the trouble that causes.

;;; Hm.  The way I wrote this program, it never actually garbage
;;; collects old addresses from the trace, which has the two funny
;;; effects that
;;; a) Old choices stick around and may come back
;;; b) Proposals to shadow choices are made (and always accepted
;;;    because there is no likelihood)

(define trick-coin-example-syntax
  `(begin
     ,observe-defn
     ,map-defn
     ,mcmc-defn
     (model-in (rdb-extend (get-current-trace))
       (assume is-trick? (flip 0.5))
       (assume weight (if is-trick? (uniform 0 1) 0.5))
       (observe (flip weight) #t)
       (observe (flip weight) #t)
       (observe (flip weight) #t)
       (observe (flip weight) #t)
       (observe (flip weight) #t)
       (infer (mcmc 20))
       (predict (list is-trick? weight)))))

;;; Checking mu

(define mu-should-rerun-once
  ;; Should print thrice: once for the initial run, once for rerunning
  ;; the mu to generate a proposal, and once for rerunning the
  ;; application of the mu when building a full candidate from the
  ;; proposal, but not for explicitly rerunning the pp in the body.
  ;; Assessment should print twice, afterward: once for assessing the
  ;; old value and once for assessing the new one.
  `(begin
     (model-in (rdb-extend (get-current-trace))
       (assume f (make-sp
                  (lambda ()
                    (begin
                      (pp 'running)
                      1))
                  (lambda (val)
                    (begin
                      (pp 'assessing)
                      0))))
       (predict (f))
       (infer mcmc-step))))
