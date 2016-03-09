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
    > (define (fib n) (if (= n 1)
                          1
                          (if (= n 2)
                              1
                              (+ (fib (- n 1)) (fib (- n 2))))))
    ok
    > (fib 10)
    55
    > ^C

### changes

* v0.13.1  More primitive procedures:
    - `null?`
    - `boolean?`
    - `symbol?`
    - `integer?`
    - `char?`
    - `string?`
    - `pair?`
    - `procedure?`
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
