# AGENTS.md

This project uses the `jj` git frontend as version control.

Structure:

- tokenizer is in @lib/tokenizer.ml
- the grammary for the parser generator is in @lemon/grammar.y and can be build with:
  ```
  cd lemon && make
  ```
- its a lemon grammar
- the interpreter is in @lib/interpreter.ml

## Build Tricks

If there are dependencies in ocmal missing then load the environment with:

```bash
eval $(opam env)
```

or:

```fish
eval (opam env)
```

## Test strategy

- make a new test with expect test in @lib/interpreter.ml
- run it with `dune runtest`
- eval the output
- if dune runtest outputs nothing the test passed
