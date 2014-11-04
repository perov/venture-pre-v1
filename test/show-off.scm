(in-test-group
 show-off

 (define-test (generate-truncated-gamma)
   (define program
     `(begin
        ,observe-defn
        (define standard-truncated-gamma
          (lambda (alpha)
            (model-in (rdb-extend (get-current-trace))
              (assume V (uniform 0 1))
              (assume X (expt V (/ 1 alpha)))
              (observe (flip (exp (- X))) #t)
              (infer rejection)
              (predict X))))
        (define truncated-gamma
          (lambda (alpha beta)
            (/ (standard-truncated-gamma alpha) beta)))
        (truncated-gamma 2 1)))
   (check (> (k-s-test (collect-samples program)
                       (lambda (x)
                         (/ ((gamma-cdf 2 1) x) ((gamma-cdf 2 1) 1))))
             *p-value-tolerance*)))

 (define-test (marsaglia-tsang-gamma)
   (define (program shape)
     `(begin
        ,exactly-defn
        ,observe-defn
        ,gaussian-defn
        (define marsaglia-standard-gamma-for-shape>1
          (lambda (alpha)
            (let ((d (- alpha 1/3)))
              (let ((c (/ 1 (sqrt (* 9 d)))))
                (model-in (rdb-extend (get-current-trace))
                  (assume x (normal 0 1))
                  (assume v (expt (+ 1 (* c x)) 3))
                  (observe (exactly (> v 0)) #t)
                  (infer rejection)
                  (observe (exactly (< (log (uniform 0 1)) (+ (* 0.5 x x) (* d (+ 1 (- v) (log v)))))) #t)
                  (infer rejection)
                  (predict (* d v)))))))
        (marsaglia-standard-gamma-for-shape>1 ,shape)))
   (check (> (k-s-test (collect-samples (program 2)) (gamma-cdf 2 1))
             *p-value-tolerance*))))