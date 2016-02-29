## Deimos

`deimos` is a very basic **scheme** interpreter written in `D`. The compiler used to build the sources is `DMD64 D Compiler v2.069`.

### example
    
    > 1
    1
    > #t
    #t
    > #f
    #f
    > #\c
    #\c
    > "asdf"
    "asdf"
    > ()
    ()
    > (0 . 1)
    (0 . 1)
    > (0 1 2 3)
    (0 1 2 3)
    > ^C

### changes

* v0.6   List literals
* v0.5   Empty list literal
* v0.4   String literals
* v0.3   Support for character literals
* v0.2   Support for booleans #f and #t
* v0.1   Support for integers

