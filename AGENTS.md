# AGENTS.md

## Build Tricks

To clean object files in the lemon directory before building with dune, run `make oclean` in the lemon dir.
This removes grammar.o and cjson.o which can conflict with dune's build rules.

If there are dependencies in ocmal missing then load the environment with:
```bash
eval $(opam env)
```

or:

```fish
eval (opam env)
```
