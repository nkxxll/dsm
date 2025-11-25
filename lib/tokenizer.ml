open Ppx_yojson_conv_lib.Yojson_conv.Primitives
open Angstrom
open Base

module TokenType = struct
  type t =
    | AMPERSAND
    | ASSIGN
    | AVERAGE
    | COMMA
    | CURRENTTIME
    | DIVIDE
    | DO
    | EARLIEST
    | ELSE
    | ELSEIF
    | ENDDO
    | ENDIF
    | EQ
    | FALSE
    | FIRST
    | FOR
    | GT
    | GTEQ
    | IDENTIFIER of string
    | IF
    | IN
    | INCREASE
    | LAST
    | LATEST
    | LPAR
    | LSPAR
    | LT
    | LTEQ
    | MAXIMUM
    | MINIMUM
    | MINUS
    | NEQ
    | NOW
    | NULL
    | NUMTOKEN of float
    | PLUS
    | POWER
    | READ
    | RPAR
    | RSPAR
    | SEMICOLON
    | STRTOKEN of string
    | SUM
    | THEN
    | TIME
    | TIMES
    | TIMETOKEN of string
    | TRUE
    | UPPERCASE
    | WRITE
    | UNKNOWN of string
  [@@deriving yojson]

  let token_type_from_string str =
    match String.uppercase str with
    | "AVERAGE" -> AVERAGE
    | "CURRENTTIME" -> CURRENTTIME
    | "DO" -> DO
    | "EARLIEST" -> EARLIEST
    | "ELSE" -> ELSE
    | "ELSEIF" -> ELSEIF
    | "ENDDO" -> ENDDO
    | "ENDIF" -> ENDIF
    | "FALSE" -> FALSE
    | "FIRST" -> FIRST
    | "FOR" -> FOR
    | "IF" -> IF
    | "IN" -> IN
    | "INCREASE" -> INCREASE
    | "LAST" -> LAST
    | "LATEST" -> LATEST
    | "MAXIMUM" -> MAXIMUM
    | "MINIMUM" -> MINIMUM
    | "NOW" -> NOW
    | "NULL" -> NULL
    | "READ" -> READ
    | "SUM" -> SUM
    | "THEN" -> THEN
    | "TIME" -> TIME
    | "TRUE" -> TRUE
    | "UPPERCASE" -> UPPERCASE
    | "WRITE" -> WRITE
    | other -> IDENTIFIER other
  ;;

  let token_type_to_string = function
    | AMPERSAND -> "AMPERSAND"
    | ASSIGN -> "ASSIGN"
    | AVERAGE -> "AVERAGE"
    | COMMA -> "COMMA"
    | CURRENTTIME -> "CURRENTTIME"
    | DIVIDE -> "DIVIDE"
    | DO -> "DO"
    | EARLIEST -> "EARLIEST"
    | ELSE -> "ELSE"
    | ELSEIF -> "ELSEIF"
    | ENDDO -> "ENDDO"
    | ENDIF -> "ENDIF"
    | EQ -> "EQ"
    | FALSE -> "FALSE"
    | FIRST -> "FIRST"
    | FOR -> "FOR"
    | GT -> "GT"
    | GTEQ -> "GTEQ"
    | IDENTIFIER _ -> "IDENTIFIER"
    | IF -> "IF"
    | IN -> "IN"
    | INCREASE -> "INCREASE"
    | LAST -> "LAST"
    | LATEST -> "LATEST"
    | LPAR -> "LPAR"
    | LSPAR -> "LSPAR"
    | LT -> "LT"
    | LTEQ -> "LTEQ"
    | MAXIMUM -> "MAXIMUM"
    | MINIMUM -> "MINIMUM"
    | MINUS -> "MINUS"
    | NEQ -> "NEQ"
    | NOW -> "NOW"
    | NULL -> "NULL"
    | NUMTOKEN _ -> "NUMTOKEN"
    | PLUS -> "PLUS"
    | POWER -> "POWER"
    | READ -> "READ"
    | RPAR -> "RPAR"
    | RSPAR -> "RSPAR"
    | SEMICOLON -> "SEMICOLON"
    | STRTOKEN _ -> "STRTOKEN"
    | SUM -> "SUM"
    | THEN -> "THEN"
    | TIME -> "TIME"
    | TIMES -> "TIMES"
    | TIMETOKEN _ -> "TIMETOKEN"
    | TRUE -> "TRUE"
    | UPPERCASE -> "UPPERCASE"
    | WRITE -> "WRITE"
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

let create () = { col = 1; row = 1; tokens = [] }
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

let tokenize input =
  let tokenizer = create () in
  exec tokenizer input
  |> Result.map ~f:(fun tokens ->
    yojson_of_list (fun t -> yojson_of_list yojson_of_string (Token.to_list t)) tokens
    |> Yojson.Safe.pretty_to_string)
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
        Token { type = PLUS; literal = "+"; length = 1; row = 1; col = 1 }
        Token { type = MINUS; literal = "-"; length = 1; row = 1; col = 2 }
        Token { type = TIMES; literal = "*"; length = 1; row = 1; col = 3 }
        Token { type = DIVIDE; literal = "/"; length = 1; row = 1; col = 4 }
        Token { type = SEMICOLON; literal = ";"; length = 1; row = 1; col = 5 }
        Token { type = ASSIGN; literal = ":="; length = 2; row = 1; col = 6 }
        Token { type = COMMA; literal = ","; length = 1; row = 1; col = 8 }
        Token { type = LPAR; literal = "("; length = 1; row = 1; col = 9 }
        Token { type = RPAR; literal = ")"; length = 1; row = 1; col = 10 }
        Token { type = LSPAR; literal = "["; length = 1; row = 1; col = 11 }
        Token { type = RSPAR; literal = "]"; length = 1; row = 1; col = 12 }
        Token { type = AMPERSAND; literal = "&"; length = 1; row = 1; col = 13 }
        Token { type = NEQ; literal = "<>"; length = 2; row = 1; col = 14 }
        Token { type = LTEQ; literal = "<="; length = 2; row = 1; col = 16 }
        Token { type = GTEQ; literal = ">="; length = 2; row = 1; col = 18 }
        Token { type = NEQ; literal = "<>"; length = 2; row = 1; col = 20 }
        |}]
    ;;

    let%expect_test "operators with whitespace" =
      run_test "  + -   * /    ;";
      [%expect
        {|
        Token { type = PLUS; literal = "+"; length = 1; row = 1; col = 3 }
        Token { type = MINUS; literal = "-"; length = 1; row = 1; col = 5 }
        Token { type = TIMES; literal = "*"; length = 1; row = 1; col = 9 }
        Token { type = DIVIDE; literal = "/"; length = 1; row = 1; col = 11 }
        Token { type = SEMICOLON; literal = ";"; length = 1; row = 1; col = 16 }
        |}]
    ;;

    let%expect_test "operators with newlines" =
      run_test "+\n-\n\n*";
      [%expect
        {|
        Token { type = PLUS; literal = "+"; length = 1; row = 1; col = 1 }
        Token { type = MINUS; literal = "-"; length = 1; row = 2; col = 0 }
        Token { type = TIMES; literal = "*"; length = 1; row = 4; col = 0 }
        |}]
    ;;

    let%expect_test "identifiers and keywords" =
      run_test "If foo FOR bar";
      [%expect
        {|
        Token { type = IF; literal = "If"; length = 2; row = 1; col = 1 }
        Token { type = IDENTIFIER; literal = "foo"; length = 3; row = 1; col = 4 }
        Token { type = FOR; literal = "FOR"; length = 3; row = 1; col = 8 }
        Token { type = IDENTIFIER; literal = "bar"; length = 3; row = 1; col = 12 }
        |}]
    ;;

    let%expect_test "a mix of everything" =
      run_test "IF + foo;\n  WRITE - bar";
      [%expect
        {|
        Token { type = IF; literal = "IF"; length = 2; row = 1; col = 1 }
        Token { type = PLUS; literal = "+"; length = 1; row = 1; col = 4 }
        Token { type = IDENTIFIER; literal = "foo"; length = 3; row = 1; col = 6 }
        Token { type = SEMICOLON; literal = ";"; length = 1; row = 1; col = 9 }
        Token { type = WRITE; literal = "WRITE"; length = 5; row = 2; col = 2 }
        Token { type = MINUS; literal = "-"; length = 1; row = 2; col = 8 }
        Token { type = IDENTIFIER; literal = "bar"; length = 3; row = 2; col = 10 }
        |}]
    ;;

    let%expect_test "unknown characters" =
      run_test "+ # @ -";
      [%expect
        {|
        Token { type = PLUS; literal = "+"; length = 1; row = 1; col = 1 }
        Token { type = UNKNOWN #; literal = "#"; length = 1; row = 1; col = 3 }
        Token { type = UNKNOWN @; literal = "@"; length = 1; row = 1; col = 5 }
        Token { type = MINUS; literal = "-"; length = 1; row = 1; col = 7 }
        |}]
    ;;

    let%expect_test "strings" =
      run_test
        {| "very cool string" "another string" "another very cool string
that goes over two lines" IF|};
      [%expect
        {|
        Token { type = STRTOKEN; literal = " "very cool string" "; length = 20; row = 1; col = 2 }
        Token { type = STRTOKEN; literal = " "another string" "; length = 18; row = 1; col = 23 }
        Token { type = STRTOKEN; literal = " "another very cool string
        that goes over two lines" "; length = 53; row = 1; col = 42 }
        Token { type = IF; literal = "IF"; length = 2; row = 2; col = 96 }
        |}]
    ;;

    let%expect_test "numbers and time" =
      run_test "123 123.45 12:34 12:34:56";
      [%expect
        {|
        Token { type = NUMTOKEN; literal = "123"; length = 3; row = 1; col = 1 }
        Token { type = NUMTOKEN; literal = "123.45"; length = 6; row = 1; col = 5 }
        Token { type = TIMETOKEN; literal = "12:34"; length = 5; row = 1; col = 12 }
        Token { type = TIMETOKEN; literal = "12:34:56"; length = 8; row = 1; col = 18 }
        |}]
    ;;

    let%expect_test "json list output" =
      let input = "IF + foo;\n  WRITE - bar" in
      let tokenizer = create () in
      match exec tokenizer input with
      | Ok tokens ->
        yojson_of_list (fun t -> yojson_of_list yojson_of_string (Token.to_list t)) tokens
        |> Yojson.Safe.pretty_to_string
        |> Stdio.print_endline;
        [%expect
          {|
        [
          [ "1", "IF", "IF" ],
          [ "1", "PLUS", "+" ],
          [ "1", "IDENTIFIER", "foo" ],
          [ "1", "SEMICOLON", ";" ],
          [ "2", "WRITE", "WRITE" ],
          [ "2", "MINUS", "-" ],
          [ "2", "IDENTIFIER", "bar" ]
        ]
        |}]
      | Error msg ->
        Stdio.print_endline ("Error: " ^ msg);
        [%expect.unreachable]
    ;;

    let%expect_test "power times power times" =
      let input =
        {|WRITE 1 ** 1;
        WRITE 1 * 1;
        WRITE 1 *** 1;|}
      in
      let tokenizer = create () in
      match exec tokenizer input with
      | Ok tokens ->
        yojson_of_list (fun t -> yojson_of_list yojson_of_string (Token.to_list t)) tokens
        |> Yojson.Safe.pretty_to_string
        |> Stdio.print_endline;
        [%expect
          {|
          [
            [ "1", "WRITE", "WRITE" ],
            [ "1", "NUMTOKEN", "1" ],
            [ "1", "POWER", "**" ],
            [ "1", "NUMTOKEN", "1" ],
            [ "1", "SEMICOLON", ";" ],
            [ "2", "WRITE", "WRITE" ],
            [ "2", "NUMTOKEN", "1" ],
            [ "2", "TIMES", "*" ],
            [ "2", "NUMTOKEN", "1" ],
            [ "2", "SEMICOLON", ";" ],
            [ "3", "WRITE", "WRITE" ],
            [ "3", "NUMTOKEN", "1" ],
            [ "3", "POWER", "**" ],
            [ "3", "TIMES", "*" ],
            [ "3", "NUMTOKEN", "1" ],
            [ "3", "SEMICOLON", ";" ]
          ]
          |}]
      | Error msg ->
        Stdio.print_endline ("Error: " ^ msg);
        [%expect.unreachable]
    ;;

    let%expect_test "weird keyword capitalization" =
      let input =
        {|wRite 1 ** 1;
         thEN 1 * 1;
         Identifier 1 *** 1;|}
      in
      let tokenizer = create () in
      match exec tokenizer input with
      | Ok tokens ->
        yojson_of_list (fun t -> yojson_of_list yojson_of_string (Token.to_list t)) tokens
        |> Yojson.Safe.pretty_to_string
        |> Stdio.print_endline;
        [%expect
          {|
          [
            [ "1", "WRITE", "wRite" ],
            [ "1", "NUMTOKEN", "1" ],
            [ "1", "POWER", "**" ],
            [ "1", "NUMTOKEN", "1" ],
            [ "1", "SEMICOLON", ";" ],
            [ "2", "THEN", "thEN" ],
            [ "2", "NUMTOKEN", "1" ],
            [ "2", "TIMES", "*" ],
            [ "2", "NUMTOKEN", "1" ],
            [ "2", "SEMICOLON", ";" ],
            [ "3", "IDENTIFIER", "Identifier" ],
            [ "3", "NUMTOKEN", "1" ],
            [ "3", "POWER", "**" ],
            [ "3", "TIMES", "*" ],
            [ "3", "NUMTOKEN", "1" ],
            [ "3", "SEMICOLON", ";" ]
          ]
          |}]
      | Error msg ->
        Stdio.print_endline ("Error: " ^ msg);
        [%expect.unreachable]
    ;;

    let%expect_test "with tokenize keyword capitalization" =
      let input =
        {|wRite 1 ** 1;
         thEN 1 * 1;
         Identifier 1 *** 1;|}
      in
      (match tokenize input with
       | Ok out -> Stdio.print_endline out
       | Error msg -> Stdio.print_endline ("error " ^ msg));
      [%expect
        {|
          [
            [ "1", "WRITE", "wRite" ],
            [ "1", "NUMTOKEN", "1" ],
            [ "1", "POWER", "**" ],
            [ "1", "NUMTOKEN", "1" ],
            [ "1", "SEMICOLON", ";" ],
            [ "2", "THEN", "thEN" ],
            [ "2", "NUMTOKEN", "1" ],
            [ "2", "TIMES", "*" ],
            [ "2", "NUMTOKEN", "1" ],
            [ "2", "SEMICOLON", ";" ],
            [ "3", "IDENTIFIER", "Identifier" ],
            [ "3", "NUMTOKEN", "1" ],
            [ "3", "POWER", "**" ],
            [ "3", "TIMES", "*" ],
            [ "3", "NUMTOKEN", "1" ],
            [ "3", "SEMICOLON", ";" ]
          ]
          |}]
    ;;
  end)
;;
