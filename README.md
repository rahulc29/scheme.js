# Scheme.js 

A Scheme to JavaScript compiler. Untyped lambda calculus is the primary intermediate representation. 
Most primitives are implemented using macro expansion. Expression-oriented semantics are implemented by inserting redundant lambdas. 

Consider the following definition of factorial : 

```scheme
(letrec [f n] 
        (if (eq? n 0)
            1
            (* n (f (- n 1))))
        (f 5))
; Outputs 120
```

Compiles into the following monstrosity (I have prettified the code generated) : 

```js
((f) => {
    return (() => {
        return (x) => {
            return (() => {
                return f;
            })()((y) => {
                return (() => {
                    return (() => {
                        return x;
                    })()(x);
                })()(y);
            });
        };
    })()((x) => {
        return (() => {
            return f;
        })()((y) => {
            return (() => {
                return (() => {
                    return x;
                })()(x);
            })()(y);
        });
    });
})((f) => {
    return (n) => {
        if (n === 0) {
            return 1;
        } else {
            return n * (f(n - 1));
        }
    }
})(5)
// Outputs 120 
```

I invite you to use the developer tools available in your browser and insert the following code and play around with it! 

Of course, it would be better if I showed you all the layers that went into the construction of said monstrosity!

Firstly, the desugaring layer will unfold the `letrec` into a `let` 

```scheme
(let [f (fix (lambda (f) 
              (lambda (n) 
               (if (eq? n 0)
                    1
                    (n * (f (- n 1)))))))]
    (f 5))
```

What on god's earth is `fix`? I live by a simple principle :

> Do not implement recursion if you can get away with fixpoint combinators. 

In our situation, we _can_ get away with fixpoint combinators! 

In particular, the macro expansion layer will expand `fix` into the call-by-value Y combinator. 

This will generate the following code : 

```scheme
(let [f ((lambda (f) 
          ((lambda (x) 
            (f (lambda (y) ((x x) y)))) 
           (lambda (x) 
            (f (lambda (y) ((x x) y)))))) 
         (lambda (f) 
          (lambda (n) 
           (if (eq? n 0) 
                1 
                (* n (f (- n 1)))))))]
      (f 5))
```

Already pretty ugly, huh? 

This code will then be compiled into JavaScript, thus producing the garbage code we saw.
