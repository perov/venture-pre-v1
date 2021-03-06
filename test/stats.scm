;;; Copyright (c) 2014 MIT Probabilistic Computing Project.
;;;
;;; This file is part of Venture.
;;;
;;; Venture is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; Venture is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with Venture.  If not, see <http://www.gnu.org/licenses/>.

(declare (usual-integrations))

;;; From http://en.wikipedia.org/wiki/Kolmogorov-Smirnov_test

(define (k-s-cdf-series-one-term x k)
  (* (expt -1 (- k 1))
     (exp (* -2 k k x x))))

(define (sum-series term)
  (let loop ((next-k 1)
             (total 0))
    (let ((next-term (term next-k)))
      (if (< (abs (* next-term 1e14)) (abs total))
          (+ total next-term)
          (loop (+ next-k 1)
                (+ total next-term))))))

(define (k-s-cdf-by-series-one x)
  (sum-series (lambda (k) (k-s-cdf-series-one-term x k))))

(define (kolmogorov-survivor-function-by-series-one x)
  (* 2 (k-s-cdf-by-series-one x)))

(define (k-s-D-stat data cdf)
  (let* ((data (sort data <))
         (n (length data))
         (cdfvals (map cdf data))
         (D+ (scheme-apply
              max (map (lambda (i cdfval)
                         (- (/ (+ i 1) n) cdfval))
                       (iota n) cdfvals)))
         (D- (scheme-apply
              min (map (lambda (i cdfval)
                         (- (/ i n) cdfval))
                       (iota n) cdfvals))))
    (max (abs D+) (abs D-))))

(define (k-s-test data cdf)
  (let* ((n (length data))
         (D-stat (k-s-D-stat data cdf))
         (p-value (kolmogorov-survivor-function-by-series-one (* D-stat (sqrt n)))))
    ; (pp (list 'program-samples (sort data <) 'D-stat D-stat 'p-value p-value))
    p-value))

#|

 (define (uniform-cdf low high)
   (lambda (place)
     (min 1
          (max 0
               (/ (- place low)
                  (- high low))))))

1 ]=> (k-s-test '(.1 .1 .2) (uniform-cdf 0 1))

;Value 20: (.8 4.2986775848567596e-2)

1 ]=> (k-s-test '(.1 .1 .2 .3) (uniform-cdf 0 1))

;Value 21: (.7 3.9681879538114403e-2)

1 ]=> (k-s-test '(.1 .2 .3) (uniform-cdf 0 1))

;Value 22: (.7 .10571583583368427)

1 ]=> (k-s-test '(.1 .2 .3 .9) (uniform-cdf 0 1))

;Value 23: (.45 .39273070794065434)

1 ]=> (k-s-test '(.1 .2 .3 .8 .9) (uniform-cdf 0 1))

;Value 24: (.3 .7590978384203949)

1 ]=> (k-s-test '(.1 .2 .3 .8 .9 .1 .2 .3 .8 .9) (uniform-cdf 0 1))

;Value 25: (.3 .32910478909781504)

1 ]=> (k-s-test '(.1 .2 .3 .8 .9 .1 .2 .3 .8 .9 .1 .2 .3 .8 .9) (uniform-cdf 0 1))

;Value 26: (.3 .13437022652861091)

1 ]=> (k-s-test '(.1 .2 .3 .8 .9 .1 .2 .3 .8 .9 .1 .2 .3 .8) (uniform-cdf 0 1))

;Value 27: (.3428571428571429 .07439750491383416)

1 ]=> 
|#

;;; Chisq

(define-syntax ucode-primitive
  (sc-macro-transformer
   (lambda (form environment)
     environment
     ((access apply system-global-environment)
      make-primitive-procedure (cdr form)))))

(load-library-object-file (merge-pathnames "c-stats.so") #f)

(define (gsl-cdf-chisq-q x nu)
  (if (> x 1e4)
      0 ; TODO Poor man's underflow guard
      ((ucode-primitive GSL_CDF_CHISQ_Q 2)
       (->flonum x) (->flonum nu))))

(define (chi-sq-test data frequencies)
  (let* ((dof (length frequencies))
         (n (length data))
         (expected-counts (map (lambda (freq) (* n freq))
                               (map cdr frequencies)))
         (actual-counts (map (lambda (item)
                               (count-matching-items data (lambda (d) (equal? d item))))
                             (map car frequencies)))
         (stat (scheme-apply
                + (map (lambda (actual expected)
                         (/ (expt (- actual expected) 2)
                            expected))
                       actual-counts
                       expected-counts)))
         (p-value (gsl-cdf-chisq-q stat (- dof 1))))
    (fluid-let ((flonum-unparser-cutoff '(relative 5 normal)))
      (pp `( expected ,(map exact->inexact expected-counts)
             actual ,actual-counts
             chi-sq ,(exact->inexact stat)
             p-value ,p-value)))
    p-value))

#|
1 ]=> (chi-sq-test '(#t #t #t #f #f) '((#t . 0.5) (#f . 0.5)))

;Value 18: (.2 .6547208460185772)

1 ]=> (chi-sq-test '(#t #t #t #f) '((#t . 0.5) (#f . 0.5)))

;Value 17: (1. .3173105078629138)

1 ]=> (chi-sq-test '(#t #t #t #f #t #t #t #f #t #t #t #f #t #t #t #f #t #t #t #f) '((#t . 0.5) (#f . 0.5)))

;Value 16: (5. .02534731867746824)

|#

(define (gsl-cdf-gaussian-p x sigma)
  ((ucode-primitive GSL_CDF_GAUSSIAN_P 2)
   (->flonum x) (->flonum sigma)))

(define (gaussian-cdf x mu sigma)
  (gsl-cdf-gaussian-p (- x mu) sigma))

(define (gsl-sf-lngamma x)
  ((ucode-primitive GSL_SF_LNGAMMA 1) (->flonum x)))

(define log-gamma gsl-sf-lngamma)

(define (gsl-ran-gamma-pdf x shape theta)
  ((ucode-primitive GSL_RAN_GAMMA_PDF 3)
   (->flonum x) (->flonum shape) (->flonum theta)))

(define ((gamma-pdf alpha beta) x)
  (gsl-ran-gamma-pdf x alpha (/ 1 beta)))

(define (gsl-cdf-gamma-p x shape theta)
  ((ucode-primitive GSL_CDF_GAMMA_P 3)
   (->flonum x) (->flonum shape) (->flonum theta)))

(define ((gamma-cdf alpha beta) x)
  (gsl-cdf-gamma-p x alpha (/ 1 beta)))
