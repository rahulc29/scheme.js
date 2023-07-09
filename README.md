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
