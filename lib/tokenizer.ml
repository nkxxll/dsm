open Ppx_yojson_conv_lib.Yojson_conv.Primitives
open Angstrom
open Base

module TokenType = struct
  type t =
    | SEMICOLON
    | ASSIGN
    | COMMA
    | PLUS
    | MINUS
    | TIMES
    | DIVIDE
    | POWER
    | LPAR
    | RPAR
    | LSPAR
    | RSPAR
    | AMPERSAND
    | LT
    | GT
    | LTEQ
    | GTEQ
    | EQ
    | NEQ
    | IDENTIFIER of string
    | STRTOKEN of string
    | NUMTOKEN of float
    | TIMETOKEN of string
    | READ
    | WRITE
    | IF
    | THEN
    | ELSEIF
    | ELSE
    | ENDIF
    | FOR
    | IN
    | DO
    | ENDDO
    | NOW
    | CURRENTTIME
    | MINIMUM
    | MAXIMUM
    | FIRST
    | LAST
    | SUM
    | AVERAGE
    | EARLIEST
    | LATEST
    | UNKNOWN of string
  [@@deriving yojson]

  let token_type_from_string = function
    | "READ" -> READ
    | "WRITE" -> WRITE
    | "IF" -> IF
    | "THEN" -> THEN
    | "ELSEIF" -> ELSEIF
    | "ELSE" -> ELSE
    | "ENDIF" -> ENDIF
    | "FOR" -> FOR
    | "IN" -> IN
    | "DO" -> DO
    | "ENDDO" -> ENDDO
    | "NOW" -> NOW
    | "CURRENTTIME" -> CURRENTTIME
    | "MINIMUM" -> MINIMUM
    | "MAXIMUM" -> MAXIMUM
    | "FIRST" -> FIRST
    | "LAST" -> LAST
    | "SUM" -> SUM
    | "AVERAGE" -> AVERAGE
    | "EARLIEST" -> EARLIEST
    | "LATEST" -> LATEST
    | other -> IDENTIFIER other
  ;;

  let token_type_to_string = function
    | SEMICOLON -> "SEMICOLON"
    | ASSIGN -> "ASSIGN"
    | COMMA -> "COMMA"
    | PLUS -> "PLUS"
    | MINUS -> "MINUS"
    | TIMES -> "TIMES"
    | DIVIDE -> "DIVIDE"
    | POWER -> "POWER"
    | LPAR -> "LPAR"
    | RPAR -> "RPAR"
    | LSPAR -> "LSPAR"
    | RSPAR -> "RSPAR"
    | AMPERSAND -> "AMPERSAND"
    | LT -> "LT"
    | GT -> "GT"
    | LTEQ -> "LTEQ"
    | GTEQ -> "GTEQ"
    | EQ -> "EQ"
    | NEQ -> "NEQ"
    | IDENTIFIER s -> Printf.sprintf "IDENTIFIER %s" s
    | STRTOKEN s -> Printf.sprintf "STRTOKEN %s" s
    | NUMTOKEN n -> Printf.sprintf "NUMTOKEN %f" n
    | TIMETOKEN t -> Printf.sprintf "TIMETOKEN %s" t
    | READ -> "READ"
    | WRITE -> "WRITE"
    | IF -> "IF"
    | THEN -> "THEN"
    | ELSEIF -> "ELSEIF"
    | ELSE -> "ELSE"
    | ENDIF -> "ENDIF"
    | FOR -> "FOR"
    | IN -> "IN"
    | DO -> "DO"
    | ENDDO -> "ENDDO"
    | NOW -> "NOW"
    | CURRENTTIME -> "CURRENTTIME"
    | MINIMUM -> "MINIMUM"
    | MAXIMUM -> "MAXIMUM"
    | FIRST -> "FIRST"
    | LAST -> "LAST"
    | SUM -> "SUM"
    | AVERAGE -> "AVERAGE"
    | EARLIEST -> "EARLIEST"
    | LATEST -> "LATEST"
    | UNKNOWN s -> Printf.sprintf "UNKNOWN %s" s
  ;;
end

module Token = struct
  type t =
    { type_ : TokenType.t
    ; literal : string
    ; length : int
    ; col : int
    ; row : int
    }
  [@@deriving yojson]

  let to_list t =
    [ Int.to_string t.row; TokenType.token_type_to_string t.type_; t.literal ]
  ;;
end

type t =
  { tokens : Token.t list
  ; col : int
  ; row : int
  }

let create () = { col = 0; row = 0; tokens = [] }
let to_list t = List.map t.tokens ~f:Token.to_list

let is_digit = function
  | '0' .. '9' -> true
  | _ -> false
;;

let make_token tzer ~type_ ~literal ~len =
  let token = { Token.type_; literal; col = tzer.col; row = tzer.row; length = len } in
  { tzer with col = tzer.col + len; tokens = token :: tzer.tokens }
;;

let parse_language_string tokenizer =
  char '"'
  *> take_while (function
    | '"' -> false
    | _ -> true)
  <* char '"'
  >>| fun str ->
  let literal = Printf.sprintf {| "%s" |} str in
  let len = String.length literal in
  let token =
    { Token.type_ = STRTOKEN str
    ; literal
    ; col = tokenizer.col
    ; row = tokenizer.row
    ; length = len
    }
  in
  let plus_rows =
    String.fold str ~init:0 ~f:(fun acc ch ->
      match ch with
      | '\n' | '\r' -> acc + 1
      | _ -> acc)
  in
  { col = tokenizer.col + len
  ; row = tokenizer.row + plus_rows
  ; tokens = token :: tokenizer.tokens
  }
;;

let parse_ident tokenizer =
  take_while1 (function
    | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' -> true
    | _ -> false)
  >>| fun tok ->
  let len = String.length tok in
  let token_type = TokenType.token_type_from_string (String.uppercase tok) in
  make_token tokenizer ~type_:token_type ~literal:tok ~len
;;

let parse_number tokenizer =
  take_while1 is_digit
  >>= fun integer_part ->
  peek_char
  >>= (function
   | Some '.' ->
     char '.'
     >>= fun _ ->
     take_while1 is_digit >>= fun fractional_part -> return (Some fractional_part)
   | _ -> return None)
  >>| fun fractional_part_opt ->
  let literal, value =
    match fractional_part_opt with
    | Some fractional_part ->
      let s = integer_part ^ "." ^ fractional_part in
      s, Float.of_string s
    | None -> integer_part, Float.of_string integer_part
  in
  let len = String.length literal in
  make_token tokenizer ~type_:(NUMTOKEN value) ~literal ~len
;;

let time_parser tok =
  let digits = take_while1 is_digit in
  digits
  >>= fun p1 ->
  char ':' *> digits
  >>= fun p2 ->
  option "" (char ':' *> digits)
  >>= fun p3 ->
  let lit = if String.is_empty p3 then p1 ^ ":" ^ p2 else p1 ^ ":" ^ p2 ^ ":" ^ p3 in
  return (make_token tok ~type_:(TIMETOKEN lit) ~literal:lit ~len:(String.length lit))
;;

let parse_language (tokenizer : t) =
  let rec loop tok =
    peek_char
    >>= function
    | None -> return tok
    | Some ch ->
      (match ch with
       | ' ' | '\t' ->
         take_while1 (function
           | ' ' | '\t' -> true
           | _ -> false)
         >>= fun s ->
         let tz = { tok with col = tok.col + String.length s } in
         loop tz
       | '\n' | '\r' ->
         end_of_line
         >>= fun () ->
         let tz = { tok with row = tok.row + 1; col = 0 } in
         loop tz
       | '+' ->
         advance 1 >>= fun () -> loop (make_token tok ~type_:PLUS ~literal:"+" ~len:1)
       | '-' ->
         advance 1 >>= fun () -> loop (make_token tok ~type_:MINUS ~literal:"-" ~len:1)
       | '/' ->
         advance 1 >>= fun () -> loop (make_token tok ~type_:DIVIDE ~literal:"/" ~len:1)
       | '(' ->
         advance 1 >>= fun () -> loop (make_token tok ~type_:LPAR ~literal:"(" ~len:1)
       | ')' ->
         advance 1 >>= fun () -> loop (make_token tok ~type_:RPAR ~literal:")" ~len:1)
       | '[' ->
         advance 1 >>= fun () -> loop (make_token tok ~type_:LSPAR ~literal:"[" ~len:1)
       | ']' ->
         advance 1 >>= fun () -> loop (make_token tok ~type_:RSPAR ~literal:"]" ~len:1)
       | ',' ->
         advance 1 >>= fun () -> loop (make_token tok ~type_:COMMA ~literal:"," ~len:1)
       | '&' ->
         advance 1
         >>= fun () -> loop (make_token tok ~type_:AMPERSAND ~literal:"&" ~len:1)
       | ';' ->
         advance 1
         >>= fun () -> loop (make_token tok ~type_:SEMICOLON ~literal:";" ~len:1)
       | '=' ->
         advance 1 >>= fun () -> loop (make_token tok ~type_:EQ ~literal:"=" ~len:1)
       | ':' ->
         string ":="
         >>| (fun s -> make_token tok ~type_:ASSIGN ~literal:s ~len:(String.length s))
         >>= loop
       | '*' ->
         string "**"
         >>| (fun s -> make_token tok ~type_:POWER ~literal:s ~len:(String.length s))
         <|> (string "*"
              >>| fun s -> make_token tok ~type_:TIMES ~literal:s ~len:(String.length s))
         >>= loop
       | '<' ->
         string "<="
         >>| (fun s -> make_token tok ~type_:LTEQ ~literal:s ~len:(String.length s))
         <|> (string "<>"
              >>| fun s -> make_token tok ~type_:NEQ ~literal:s ~len:(String.length s))
         <|> (string "<"
              >>| fun s -> make_token tok ~type_:LT ~literal:s ~len:(String.length s))
         >>= loop
       | '>' ->
         string ">="
         >>| (fun s -> make_token tok ~type_:GTEQ ~literal:s ~len:(String.length s))
         <|> (string ">"
              >>| fun s -> make_token tok ~type_:GT ~literal:s ~len:(String.length s))
         >>= loop
       | 'a' .. 'z' | 'A' .. 'Z' | '_' -> parse_ident tok >>= loop
       | '"' -> parse_language_string tok >>= loop
       | '0' .. '9' -> time_parser tok <|> parse_number tok >>= loop
       | other ->
         advance 1
         >>= fun () ->
         let other_str = Char.to_string other in
         loop (make_token tok ~type_:(UNKNOWN other_str) ~literal:other_str ~len:1))
  in
  loop tokenizer
;;

let exec (tokenizer : t) (input : string) =
  match parse_string ~consume:All (parse_language tokenizer) input with
  | Ok final_tokenizer -> Ok (List.rev final_tokenizer.tokens)
  | Error msg -> Error msg
;;

let%test_module "Tokenizer Tests" =
  (module struct
    open Token
    open TokenType

    let print_tokens tokens =
      let s =
        List.map
          ~f:(fun t ->
            Printf.sprintf
              "Token { type = %s; literal = \"%s\"; length = %d; row = %d; col = %d }"
              (token_type_to_string t.type_)
              t.literal
              t.length
              t.row
              t.col)
          tokens
        |> String.concat ~sep:"\n"
      in
      Stdio.print_endline s
    ;;

    let run_test input =
      let tokenizer = create () in
      match exec tokenizer input with
      | Ok tokens -> print_tokens tokens
      | Error msg -> Stdio.print_endline ("Error: " ^ msg)
    ;;

    let%expect_test "simple operators" =
      run_test "+-*/;:=,()[]&<><=>=<>";
      [%expect
        {|
        Token { type = PLUS; literal = "+"; length = 1; row = 0; col = 0 }
        Token { type = MINUS; literal = "-"; length = 1; row = 0; col = 1 }
        Token { type = TIMES; literal = "*"; length = 1; row = 0; col = 2 }
        Token { type = DIVIDE; literal = "/"; length = 1; row = 0; col = 3 }
        Token { type = SEMICOLON; literal = ";"; length = 1; row = 0; col = 4 }
        Token { type = ASSIGN; literal = ":="; length = 2; row = 0; col = 5 }
        Token { type = COMMA; literal = ","; length = 1; row = 0; col = 7 }
        Token { type = LPAR; literal = "("; length = 1; row = 0; col = 8 }
        Token { type = RPAR; literal = ")"; length = 1; row = 0; col = 9 }
        Token { type = LSPAR; literal = "["; length = 1; row = 0; col = 10 }
        Token { type = RSPAR; literal = "]"; length = 1; row = 0; col = 11 }
        Token { type = AMPERSAND; literal = "&"; length = 1; row = 0; col = 12 }
        Token { type = NEQ; literal = "<>"; length = 2; row = 0; col = 13 }
        Token { type = LTEQ; literal = "<="; length = 2; row = 0; col = 15 }
        Token { type = GTEQ; literal = ">="; length = 2; row = 0; col = 17 }
        Token { type = NEQ; literal = "<>"; length = 2; row = 0; col = 19 }
        |}]
    ;;

    let%expect_test "operators with whitespace" =
      run_test "  + -   * /    ;";
      [%expect
        {| 
        Token { type = PLUS; literal = "+"; length = 1; row = 0; col = 2 }
        Token { type = MINUS; literal = "-"; length = 1; row = 0; col = 4 }
        Token { type = TIMES; literal = "*"; length = 1; row = 0; col = 8 }
        Token { type = DIVIDE; literal = "/"; length = 1; row = 0; col = 10 }
        Token { type = SEMICOLON; literal = ";"; length = 1; row = 0; col = 15 } |}]
    ;;

    let%expect_test "operators with newlines" =
      run_test "+\n-\n\n*";
      [%expect
        {| 
        Token { type = PLUS; literal = "+"; length = 1; row = 0; col = 0 }
        Token { type = MINUS; literal = "-"; length = 1; row = 1; col = 0 }
        Token { type = TIMES; literal = "*"; length = 1; row = 3; col = 0 } |}]
    ;;

    let%expect_test "identifiers and keywords" =
      run_test "If foo FOR bar";
      [%expect
        {|
        Token { type = IF; literal = "If"; length = 2; row = 0; col = 0 }
        Token { type = IDENTIFIER FOO; literal = "foo"; length = 3; row = 0; col = 3 }
        Token { type = FOR; literal = "FOR"; length = 3; row = 0; col = 7 }
        Token { type = IDENTIFIER BAR; literal = "bar"; length = 3; row = 0; col = 11 }
        |}]
    ;;

    let%expect_test "a mix of everything" =
      run_test "IF + foo;\n  WRITE - bar";
      [%expect
        {|
        Token { type = IF; literal = "IF"; length = 2; row = 0; col = 0 }
        Token { type = PLUS; literal = "+"; length = 1; row = 0; col = 3 }
        Token { type = IDENTIFIER FOO; literal = "foo"; length = 3; row = 0; col = 5 }
        Token { type = SEMICOLON; literal = ";"; length = 1; row = 0; col = 8 }
        Token { type = WRITE; literal = "WRITE"; length = 5; row = 1; col = 2 }
        Token { type = MINUS; literal = "-"; length = 1; row = 1; col = 8 }
        Token { type = IDENTIFIER BAR; literal = "bar"; length = 3; row = 1; col = 10 }
        |}]
    ;;

    let%expect_test "unknown characters" =
      run_test "+ # @ -";
      [%expect
        {| 
        Token { type = PLUS; literal = "+"; length = 1; row = 0; col = 0 }
        Token { type = UNKNOWN #; literal = "#"; length = 1; row = 0; col = 2 }
        Token { type = UNKNOWN @; literal = "@"; length = 1; row = 0; col = 4 }
        Token { type = MINUS; literal = "-"; length = 1; row = 0; col = 6 } |}]
    ;;

    let%expect_test "strings" =
      run_test
        {| "very cool string" "another string" "another very cool string
that goes over two lines" IF|};
      [%expect
        {|
        Token { type = STRTOKEN very cool string; literal = " "very cool string" "; length = 20; row = 0; col = 1 }
        Token { type = STRTOKEN another string; literal = " "another string" "; length = 18; row = 0; col = 22 }
        Token { type = STRTOKEN another very cool string
        that goes over two lines; literal = " "another very cool string
        that goes over two lines" "; length = 53; row = 0; col = 41 }
        Token { type = IF; literal = "IF"; length = 2; row = 1; col = 95 }
        |}]
    ;;

    let%expect_test "numbers and time" =
      run_test "123 123.45 12:34 12:34:56";
      [%expect
        {| 
        Token { type = NUMTOKEN 123.000000; literal = "123"; length = 3; row = 0; col = 0 }
        Token { type = NUMTOKEN 123.450000; literal = "123.45"; length = 6; row = 0; col = 4 }
        Token { type = TIMETOKEN 12:34; literal = "12:34"; length = 5; row = 0; col = 11 }
        Token { type = TIMETOKEN 12:34:56; literal = "12:34:56"; length = 8; row = 0; col = 17 } |}]
    ;;

    let%expect_test "json list output" =
      let input = "IF + foo;\n  WRITE - bar" in
      let tokenizer = create () in
      match exec tokenizer input with
      | Ok tokens ->
        yojson_of_list (fun t -> yojson_of_list yojson_of_string (Token.to_list t)) tokens
        |> Yojson.Safe.to_string
        |> Stdio.print_endline
      | Error msg -> Stdio.print_endline ("Error: " ^ msg)
    ;;
  end)
;;
