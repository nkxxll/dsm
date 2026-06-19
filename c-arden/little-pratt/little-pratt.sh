#!/usr/bin/env bash

set -euo pipefail

LP=${LP:-./lp}

if [[ ! -x "$LP" ]]; then
  printf 'missing executable: %s\n' "$LP" >&2
  exit 1
fi

test_expr() {
  local name=$1
  local input=$2
  local expected=$3
  local actual

  if ! actual=$(printf '%s\n' "$input" | "$LP"); then
    printf 'not ok - %s\n' "$name" >&2
    printf 'input: %s\n' "$input" >&2
    printf 'parser exited with failure\n' >&2
    return 1
  fi

  if [[ "$actual" != "$expected" ]]; then
    printf 'not ok - %s\n' "$name" >&2
    printf 'input:    %s\n' "$input" >&2
    printf 'expected: %s\n' "$expected" >&2
    printf 'actual:   %s\n' "$actual" >&2
    return 1
  fi

  printf 'ok - %s\n' "$name"
}

test_expr "postfix faculty" "4!" "(! 4)"
test_expr "prefix minus" "-4" "(- 4)"
test_expr "repeated prefix with infix" "--4 + 1" "(+ (- (- 4)) 1)"
test_expr "multiplication binds tighter than addition" "4 + 1 * 2" "(+ 4 (* 1 2))"
test_expr "mixed prefix infix postfix" "-4 + 1! * --2!" "(+ (- 4) (* (! 1) (- (- (! 2)))))"
test_expr "left associative subtraction" "4 - 1 - 2" "(- (- 4 1) 2)"
test_expr "left associative subtraction" "2 ^ 2 * 3 + 1" "(+ (* (^ 2 2) 3) 1)"
test_expr "right associative dot" "a.b.c" "(. a (. b c))"
