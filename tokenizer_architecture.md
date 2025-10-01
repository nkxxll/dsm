# Tokenizer Architecture with Angstrom

This document analyzes the current approach to token position tracking (`row`, `col`) in `lib/tokenizer.ml` and explores idiomatic alternatives using Angstrom and other OCaml tools.

## Analysis of the Current Implementation

The current implementation in `lib/tokenizer.ml` passes an explicit state record `t = { col : int; row : int }` through the parsing functions.

```ocaml
val parse_plus : t -> (t * Token.t) Angstrom.t
```

This is a functional approach, which is idiomatic in OCaml. However, the implementation has some issues and can be made more robust and less manual by using features provided by Angstrom.

### Issues with the current approach:

1.  **Incorrect Position Updates**:
    *   Parsers like `parse_plus` increment the `row` number, but they should be incrementing the `col`.
    *   `parse_newline` increments `col`, but it should increment `row` and reset `col` to 0.
    *   The `ws` parser for whitespace consumes characters but does not update the position at all, leading to incorrect column numbers for subsequent tokens.
    *   The column increment is fixed at `+ 1`, which will be incorrect for multi-character tokens or keywords.

2.  **Manual State Management**: While functional, manually passing the state `t` and returning `(t * Token.t)` makes the parser signatures more complex. Angstrom's monadic interface can help manage state more cleanly.

## Idiomatic Solution: Using `Angstrom.pos`

The most idiomatic way to handle positions within a pure Angstrom-based solution is to use the `pos` parser.

`val pos : int Angstrom.t`

The `pos` parser returns the current offset (an `int`) from the beginning of the input buffer. You can capture the position before and after parsing a token to determine its location and length.

This gives you a precise offset, but not the `(row, col)` pair directly. To get line and column numbers, you need a way to translate an offset into a `(row, col)` coordinate. The best way to do this is to pre-process the input string to build a **line-ending table**.

### Strategy: The Line-Ending Table

1.  **Build the Table**: Before parsing, scan the entire input string once and create an array containing the offset of the beginning of each line.
2.  **Translate Offset to Position**: Write a function `position_of_offset(table, offset)` that performs a binary search on the line-ending table to quickly find the line number corresponding to the given `offset`. The column is then `offset - table.(line_number)`.
3.  **Use in Parsers**: Parsers can then be written to use `pos` to get offsets and the translation function to get `(row, col)`.

### Example Parser with `pos`

```ocaml
(* A helper to create a token using an offset-to-position function *)
let with_pos p =
  pos
  >>= fun start_pos ->
  p
  >>= fun (literal, type_) ->
  pos
  >>= fun end_pos ->
  return { Token.type_; literal; start_pos; end_pos }
;;

(* Example usage *)
let parse_plus =
  with_pos
    (char '+' >>| fun c -> (String.make 1 c, TokenType.Plus))
;;

(* The main parse function would then use the line-ending table to
   convert start_pos and end_pos into row/col for each token. *)
```

This approach is efficient, robust, and keeps the core parsing logic clean. The position calculation is centralized and handled separately from the grammar rules.

## Alternative Architecture: Separating Lexing and Parsing

For more complex languages, a common and highly recommended pattern in the OCaml ecosystem is to separate the **lexer** (which turns a stream of characters into a stream of tokens) from the **parser** (which turns a stream of tokens into an Abstract Syntax Tree).

1.  **Lexer**: A tool like **`sedlex`** is used. `sedlex` is a modern lexer generator that handles Unicode correctly and has excellent, built-in support for position tracking (`Sedlexing.new_line`, `Sedlexing.lexing_positions`). You write lexing rules as regular expressions, and `sedlex` generates an efficient OCaml function that produces tokens with correct position information.

2.  **Parser**: **Angstrom** can then be used to parse the stream of `Token.t` values produced by the lexer, instead of parsing raw `char` streams.

### Advantages of this approach:

*   **Separation of Concerns**: The code is cleaner and easier to maintain. The lexer worries about characters, whitespace, and comments. The parser worries about the grammatical structure of the token stream.
*   **Robustness**: `sedlex` is highly optimized and battle-tested for complex lexing tasks.
*   **Power**: This architecture is standard for production compilers and interpreters in OCaml (e.g., using `sedlex` + `menhir`).

## Recommendations

*   **For a simple, Angstrom-only solution**: The most idiomatic and robust approach is to **use `Angstrom.pos` combined with a pre-computed line-ending table**. This is a significant improvement over manual state passing.

*   **For future growth**: If the language is expected to become more complex, consider adopting the **`sedlex` + Angstrom** architecture. It is more scalable and aligns with best practices for building compilers and interpreters in OCaml.
