## Deimos

`deimos` is a very basic **scheme** interpreter written in `D`. The compiler used to build the sources is `DMD64 D Compiler v2.069`.

### example
    
    $ Welcome to Deimos Scheme. Use ctrl-c to exit.
    > 1
    1
    > #t
    #t
    > #f
    #f
    > -123; comment
    -123
    > #\c
    #\c
    > "asdf"
    "asdf"
    > (quote ())
    ()
    > (quote (0 . 1))
    (0 . 1)
    > (quote (0 1 2 3))
    (0 1 2 3)
    > (quote asdf)
    asdf
    > (define x 10)
    ok
    > x
    10
    > (set! x 20)
    ok
    > x
    20
    > (if #t 1 2)
    1
    > (+ 1 2)
    3
    > ((lambda (x) x) 1)
    1
    > (define (add x y) (+ x y))
    ok
    > (add 1 2)
    3
    > add
    #<compound-procedure>
    > (define (fib n) (if (or (= n 1) (= n 2))
                          1
                          (+ (fib (- n 1)) (fib (- n 2)))))
    ok
    > (fib 10)
    55
    > (begin 1 2)
    2
    > (cond (#f          1)
	    ((eq? #t #t) 2)
	    (else        3))
    2
    > (let ((x (+ 1 1))
            (y (- 5 2)))
        (+ x y))
    5
    > (and 1 2 #f 3)
    #f
    > (or #f #f 3 #f)
    3
    > (apply + '(1 2 3))
    6
    > (define env (environment))
    ok
    > (eval '(define z 25) env)
    ok
    > (eval 'z env)
    25
    > ^C

### changes

* v0.20b  `set-car!` and `set-cdr!` primitive procs added
* v0.20a  I/O procs added:
    - `load`
* v0.19   Implemented the `eval` primitive. Primitive functions added:
    - `environment`
    - `interaction-environment`
    - `null-environment`
* v0.18   Implemented the `apply` primitive
* v0.17   Implemented `or` and `and` as forms
* v0.16   Implemented the `let` form
* v0.15   Implemented the `cond` form
* v0.14   Implemented the `begin` form
* v0.13.1 More primitive procedures:
    - `null?`
    - `boolean?`
    - `symbol?`
    - `integer?`
    - `char?`
    - `string?`
    - `pair?`
    - `procedure?`
	- `integer->char`
	- `char->integer`
	- `number->string`
	- `string->number`
	- `symbol->string`
	- `string->symbol`
    - `cons`
    - `car`
    - `cdr`
    - `list`
    - `-`
    - `*`
    - `quotient`
    - `remainder`
    - `<`
    - `>`
    - `eq?`
* v0.13   compound procedure support + lambda functions
* v0.11   Initial support for primitive procedures (`+`)
* v0.10   Support for the `if` form
* v0.9    Forms `define` and `set!`
* v0.8    Expression quoting
* v0.7    Symbol literals
* v0.6    List literals
* v0.5    Empty list literal
* v0.4    String literals
* v0.3    Support for character literals
* v0.2    Support for booleans #f and #t
* v0.1    Support for integers

### License

MIT
