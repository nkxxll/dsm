open Ppx_yojson_conv_lib.Yojson_conv.Primitives
open Angstrom
open Base

module TokenType = struct
  type t =
    | THE
    | DAY
    | THAN
    | OF
    | SQRT
    | WITHIN
    | NOT
    | IS
    | OCCUR
    | SAME
    | AMPERSAND
    | ANY
    | ASSIGN
    | AVERAGE
    | COMMA
    | COUNT
    | CURRENTTIME
    | DIVIDE
    | DO
    | DOT
    | EARLIEST
    | ELSE
    | ELSEIF
    | ENDDO
    | ENDIF
    | EQ
    | FALSE
    | FIRST
    | FOR
    | GREATER
    | GT
    | GTEQ
    | HOURS
    | IDENTIFIER of string
    | IF
    | IN
    | INCREASE
    | INTERVAL
    | LAST
    | LATEST
    | LPAR
    | LSPAR
    | LT
    | LTEQ
    | LISTTYPE
    | MAXIMUM
    | MINIMUM
    | MINUTES
    | MINUS
    | NEQ
    | NOW
    | NULL
    | NUMTOKEN of float
    | PLUS
    | POWER
    | RANGE
    | READ
    | RPAR
    | RSPAR
    | SECONDS
    | SEMICOLON
    | STRTOKEN of string
    | SUM
    | THEN
    | TIME
    | TIMES
    | TIMETOKEN of string
    | TRACE
    | TRUE
    | UPPERCASE
    | AS
    | WRITE
    | WHERE
    | NUMBERTYPE
    | TO
    | YEAR
    | MONTH
    | WEEK
    | UNKNOWN of string
  [@@deriving yojson]

  let token_type_from_string str =
    match String.uppercase str with
    | "THE" -> THE
    | "AS" -> AS
    | "THAN" -> THAN
    | "OF" -> OF
    | "TO" -> TO
    | "SQRT" -> SQRT
    | "DAY" -> DAY
    | "DAYS" -> DAY
    | "WHERE" -> WHERE
    | "WITHIN" -> WITHIN
    | "NOT" -> NOT
    | "IS" -> IS
    | "SAME" -> SAME
    | "LIST" -> LISTTYPE
    | "ANY" -> ANY
    | "AVERAGE" -> AVERAGE
    | "COUNT" -> COUNT
    | "CURRENTTIME" -> CURRENTTIME
    | "RANGE" -> RANGE
    | "DOT" -> DOT
    | "DO" -> DO
    | "EARLIEST" -> EARLIEST
    | "ELSE" -> ELSE
    | "ELSEIF" -> ELSEIF
    | "ENDDO" -> ENDDO
    | "ENDIF" -> ENDIF
    | "FALSE" -> FALSE
    | "FIRST" -> FIRST
    | "FOR" -> FOR
    | "GREATER" -> GREATER
    | "HOURS" -> HOURS
    | "HOUR" -> HOURS
    | "IF" -> IF
    | "IN" -> IN
    | "INCREASE" -> INCREASE
    | "INTERVAL" -> INTERVAL
    | "LAST" -> LAST
    | "LATEST" -> LATEST
    | "MAXIMUM" -> MAXIMUM
    | "MINIMUM" -> MINIMUM
    | "MINUTES" -> MINUTES
    | "MINUTE" -> MINUTES
    | "NOW" -> NOW
    | "NULL" -> NULL
    | "OCCUR" -> OCCUR
    | "OCCURS" -> OCCUR
    | "OCCURRED" -> OCCUR
    | "READ" -> READ
    | "SECONDS" -> SECONDS
    | "SECOND" -> SECONDS
    | "SUM" -> SUM
    | "THEN" -> THEN
    | "TIME" -> TIME
    | "TRACE" -> TRACE
    | "TRUE" -> TRUE
    | "UPPERCASE" -> UPPERCASE
    | "WRITE" -> WRITE
    | "NUMBER" -> NUMBERTYPE
    | "YEAR" -> YEAR
    | "YEARS" -> YEAR
    | "MONTH" -> MONTH
    | "MONTHS" -> MONTH
    | "WEEK" -> WEEK
    | "WEEKS" -> WEEK
    | other -> IDENTIFIER other
  ;;

  let token_type_to_string = function
    | OF -> "OF"
    | TO -> "TO"
    | SQRT -> "SQRT"
    | WHERE -> "WHERE"
    | WITHIN -> "WITHIN"
    | DAY -> "DAY"
    | NOT -> "NOT"
    | THAN -> "THAN"
    | IS -> "IS"
    | SAME -> "SAME"
    | THE -> "THE"
    | NUMBERTYPE -> "NUMBER"
    | AS -> "AS"
    | LISTTYPE -> "LIST"
    | DOT -> "DOT"
    | RANGE -> "RANGE"
    | AMPERSAND -> "AMPERSAND"
    | ANY -> "ANY"
    | ASSIGN -> "ASSIGN"
    | AVERAGE -> "AVERAGE"
    | COMMA -> "COMMA"
    | COUNT -> "COUNT"
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
    | GREATER -> "GREATER"
    | GT -> "GT"
    | GTEQ -> "GTEQ"
    | HOURS -> "HOURS"
    | IDENTIFIER _ -> "IDENTIFIER"
    | IF -> "IF"
    | IN -> "IN"
    | INCREASE -> "INCREASE"
    | INTERVAL -> "INTERVAL"
    | LAST -> "LAST"
    | LATEST -> "LATEST"
    | LPAR -> "LPAR"
    | LSPAR -> "LSPAR"
    | LT -> "LT"
    | LTEQ -> "LTEQ"
    | MAXIMUM -> "MAXIMUM"
    | MINIMUM -> "MINIMUM"
    | MINUTES -> "MINUTES"
    | MINUS -> "MINUS"
    | NEQ -> "NEQ"
    | NOW -> "NOW"
    | NULL -> "NULL"
    | OCCUR -> "OCCUR"
    | NUMTOKEN _ -> "NUMTOKEN"
    | PLUS -> "PLUS"
    | POWER -> "POWER"
    | READ -> "READ"
    | RPAR -> "RPAR"
    | RSPAR -> "RSPAR"
    | SECONDS -> "SECONDS"
    | SEMICOLON -> "SEMICOLON"
    | STRTOKEN _ -> "STRTOKEN"
    | SUM -> "SUM"
    | THEN -> "THEN"
    | TIME -> "TIME"
    | TIMES -> "TIMES"
    | TIMETOKEN _ -> "TIMETOKEN"
    | TRACE -> "TRACE"
    | TRUE -> "TRUE"
    | UPPERCASE -> "UPPERCASE"
    | WRITE -> "WRITE"
    | YEAR -> "YEAR"
    | MONTH -> "MONTH"
    | WEEK -> "WEEK"
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

  let to_string t =
    Printf.sprintf
      "Token { type = %s; literal = \"%s\"; length = %d; row = %d; col = %d }"
      (TokenType.token_type_to_string t.type_)
      t.literal
      t.length
      t.row
      t.col
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

let time_parser =
  let digits = take_while1 is_digit in
  digits
  >>= fun p1 ->
  char ':' *> digits
  >>= fun p2 ->
  option "" (char ':' *> digits)
  <* option "" (string "Z")
  >>= fun p3 ->
  if String.is_empty p3 then return (p1 ^ ":" ^ p2) else return (p1 ^ ":" ^ p2 ^ ":" ^ p3)
;;

let date_parser =
  let digits = take_while1 is_digit in
  digits
  >>= fun p1 ->
  char '-' *> digits
  >>= fun p2 -> char '-' *> digits >>| fun p3 -> p1 ^ "-" ^ p2 ^ "-" ^ p3
;;

let date_parser_full tok =
  date_parser
  >>| fun literal ->
  make_token tok ~type_:(TIMETOKEN literal) ~literal ~len:(String.length literal)
;;

let time_parser_full tok =
  time_parser
  >>| fun literal ->
  make_token tok ~type_:(TIMETOKEN literal) ~literal ~len:(String.length literal)
;;

let date_time_parser tok =
  date_parser
  >>= fun date ->
  option None (char 'T' *> time_parser >>| fun t -> Some t)
  >>= fun maybe_time ->
  let literal =
    match maybe_time with
    | Some time -> date ^ "T" ^ time
    | None -> date
  in
  return (make_token tok ~type_:(TIMETOKEN literal) ~literal ~len:(String.length literal))
;;

let concat_char this other = Char.to_string this ^ Char.to_string other
let concat_char_string this other = this ^ Char.to_string other

let range_parser tok =
  string "..." >>| fun literal -> make_token tok ~type_:RANGE ~literal ~len:3
;;

let dot_parser tok =
  char '.' >>| fun c -> make_token tok ~type_:DOT ~literal:(Char.to_string c) ~len:1
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
         string "//"
         >>= (fun _ ->
         take_while (function
           | '\n' -> false
           | _ -> true)
         >>= fun _ -> loop tok)
         <|> (advance 1
              >>= fun () -> loop (make_token tok ~type_:DIVIDE ~literal:"/" ~len:1))
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
       | '.' -> range_parser tok <|> dot_parser tok >>= loop
       | 'a' .. 'z' | 'A' .. 'Z' | '_' -> parse_ident tok >>= loop
       | '"' -> parse_language_string tok >>= loop
       | '0' .. '9' ->
         date_time_parser tok
         <|> date_parser_full tok
         <|> time_parser_full tok
         <|> parse_number tok
         >>= loop
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
    (* filter out the tokens *)
    let tokens =
      List.filter tokens ~f:(fun item -> not (String.equal (Token.to_string item) "THE"))
    in
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

    let%expect_test "with tokenize keyword capitalization" =
      let input = {|x := ["Hallo Welt", null, 4711, 2020-01-01T12:30:00, false, now];|} in
      (match tokenize input with
       | Ok out -> Stdio.print_endline out
       | Error msg -> Stdio.print_endline ("error " ^ msg));
      [%expect
        {|
        [
          [ "1", "IDENTIFIER", "x" ],
          [ "1", "ASSIGN", ":=" ],
          [ "1", "LSPAR", "[" ],
          [ "1", "STRTOKEN", " \"Hallo Welt\" " ],
          [ "1", "COMMA", "," ],
          [ "1", "NULL", "null" ],
          [ "1", "COMMA", "," ],
          [ "1", "NUMTOKEN", "4711" ],
          [ "1", "COMMA", "," ],
          [ "1", "TIMETOKEN", "2020-01-01T12:30:00" ],
          [ "1", "COMMA", "," ],
          [ "1", "FALSE", "false" ],
          [ "1", "COMMA", "," ],
          [ "1", "NOW", "now" ],
          [ "1", "RSPAR", "]" ],
          [ "1", "SEMICOLON", ";" ]
        ]
        |}]
    ;;

    let%expect_test "with tokenize keyword capitalization" =
      let input =
        {|x := ["Hallo Welt", null, 4711, 2020-01-01T12:30:00, false, now];
        trace x;
        trace x is number;
        trace 1 + 2 * 4 / 5 - -3 + 4 ** 3 ** 2;
        trace -2 ** 10;
        y := [100,200,150];
        trace [maximum y, average y, increase y];
        trace uppercase ["Hallo", "Welt", 4711];
        trace sqrt y;
        x := 1 ... 7;
        trace x;
        trace x < 5;
        trace x is not within (x - 1) to 5;
        trace "Hallo" where it is not number;
        trace [10,20,50,100,70,40,55] where it / 2 is within 30 to 60;
        x := 4711;
        time of x := 1999-09-19;
        // Kopie von x
        y := x;
        time of y := 2022-12-22;
        trace time of x;
        trace time of y;
        trace time of time of y;|}
      in
      (match tokenize input with
       | Ok out -> Stdio.print_endline out
       | Error msg -> Stdio.print_endline ("error " ^ msg));
      [%expect
        {|
        [
          [ "1", "IDENTIFIER", "x" ],
          [ "1", "ASSIGN", ":=" ],
          [ "1", "LSPAR", "[" ],
          [ "1", "STRTOKEN", " \"Hallo Welt\" " ],
          [ "1", "COMMA", "," ],
          [ "1", "NULL", "null" ],
          [ "1", "COMMA", "," ],
          [ "1", "NUMTOKEN", "4711" ],
          [ "1", "COMMA", "," ],
          [ "1", "TIMETOKEN", "2020-01-01T12:30:00" ],
          [ "1", "COMMA", "," ],
          [ "1", "FALSE", "false" ],
          [ "1", "COMMA", "," ],
          [ "1", "NOW", "now" ],
          [ "1", "RSPAR", "]" ],
          [ "1", "SEMICOLON", ";" ],
          [ "2", "TRACE", "trace" ],
          [ "2", "IDENTIFIER", "x" ],
          [ "2", "SEMICOLON", ";" ],
          [ "3", "TRACE", "trace" ],
          [ "3", "IDENTIFIER", "x" ],
          [ "3", "IS", "is" ],
          [ "3", "NUMBER", "number" ],
          [ "3", "SEMICOLON", ";" ],
          [ "4", "TRACE", "trace" ],
          [ "4", "NUMTOKEN", "1" ],
          [ "4", "PLUS", "+" ],
          [ "4", "NUMTOKEN", "2" ],
          [ "4", "TIMES", "*" ],
          [ "4", "NUMTOKEN", "4" ],
          [ "4", "DIVIDE", "/" ],
          [ "4", "NUMTOKEN", "5" ],
          [ "4", "MINUS", "-" ],
          [ "4", "MINUS", "-" ],
          [ "4", "NUMTOKEN", "3" ],
          [ "4", "PLUS", "+" ],
          [ "4", "NUMTOKEN", "4" ],
          [ "4", "POWER", "**" ],
          [ "4", "NUMTOKEN", "3" ],
          [ "4", "POWER", "**" ],
          [ "4", "NUMTOKEN", "2" ],
          [ "4", "SEMICOLON", ";" ],
          [ "5", "TRACE", "trace" ],
          [ "5", "MINUS", "-" ],
          [ "5", "NUMTOKEN", "2" ],
          [ "5", "POWER", "**" ],
          [ "5", "NUMTOKEN", "10" ],
          [ "5", "SEMICOLON", ";" ],
          [ "6", "IDENTIFIER", "y" ],
          [ "6", "ASSIGN", ":=" ],
          [ "6", "LSPAR", "[" ],
          [ "6", "NUMTOKEN", "100" ],
          [ "6", "COMMA", "," ],
          [ "6", "NUMTOKEN", "200" ],
          [ "6", "COMMA", "," ],
          [ "6", "NUMTOKEN", "150" ],
          [ "6", "RSPAR", "]" ],
          [ "6", "SEMICOLON", ";" ],
          [ "7", "TRACE", "trace" ],
          [ "7", "LSPAR", "[" ],
          [ "7", "MAXIMUM", "maximum" ],
          [ "7", "IDENTIFIER", "y" ],
          [ "7", "COMMA", "," ],
          [ "7", "AVERAGE", "average" ],
          [ "7", "IDENTIFIER", "y" ],
          [ "7", "COMMA", "," ],
          [ "7", "INCREASE", "increase" ],
          [ "7", "IDENTIFIER", "y" ],
          [ "7", "RSPAR", "]" ],
          [ "7", "SEMICOLON", ";" ],
          [ "8", "TRACE", "trace" ],
          [ "8", "UPPERCASE", "uppercase" ],
          [ "8", "LSPAR", "[" ],
          [ "8", "STRTOKEN", " \"Hallo\" " ],
          [ "8", "COMMA", "," ],
          [ "8", "STRTOKEN", " \"Welt\" " ],
          [ "8", "COMMA", "," ],
          [ "8", "NUMTOKEN", "4711" ],
          [ "8", "RSPAR", "]" ],
          [ "8", "SEMICOLON", ";" ],
          [ "9", "TRACE", "trace" ],
          [ "9", "SQRT", "sqrt" ],
          [ "9", "IDENTIFIER", "y" ],
          [ "9", "SEMICOLON", ";" ],
          [ "10", "IDENTIFIER", "x" ],
          [ "10", "ASSIGN", ":=" ],
          [ "10", "NUMTOKEN", "1" ],
          [ "10", "RANGE", "..." ],
          [ "10", "NUMTOKEN", "7" ],
          [ "10", "SEMICOLON", ";" ],
          [ "11", "TRACE", "trace" ],
          [ "11", "IDENTIFIER", "x" ],
          [ "11", "SEMICOLON", ";" ],
          [ "12", "TRACE", "trace" ],
          [ "12", "IDENTIFIER", "x" ],
          [ "12", "LT", "<" ],
          [ "12", "NUMTOKEN", "5" ],
          [ "12", "SEMICOLON", ";" ],
          [ "13", "TRACE", "trace" ],
          [ "13", "IDENTIFIER", "x" ],
          [ "13", "IS", "is" ],
          [ "13", "NOT", "not" ],
          [ "13", "WITHIN", "within" ],
          [ "13", "LPAR", "(" ],
          [ "13", "IDENTIFIER", "x" ],
          [ "13", "MINUS", "-" ],
          [ "13", "NUMTOKEN", "1" ],
          [ "13", "RPAR", ")" ],
          [ "13", "TO", "to" ],
          [ "13", "NUMTOKEN", "5" ],
          [ "13", "SEMICOLON", ";" ],
          [ "14", "TRACE", "trace" ],
          [ "14", "STRTOKEN", " \"Hallo\" " ],
          [ "14", "WHERE", "where" ],
          [ "14", "IDENTIFIER", "it" ],
          [ "14", "IS", "is" ],
          [ "14", "NOT", "not" ],
          [ "14", "NUMBER", "number" ],
          [ "14", "SEMICOLON", ";" ],
          [ "15", "TRACE", "trace" ],
          [ "15", "LSPAR", "[" ],
          [ "15", "NUMTOKEN", "10" ],
          [ "15", "COMMA", "," ],
          [ "15", "NUMTOKEN", "20" ],
          [ "15", "COMMA", "," ],
          [ "15", "NUMTOKEN", "50" ],
          [ "15", "COMMA", "," ],
          [ "15", "NUMTOKEN", "100" ],
          [ "15", "COMMA", "," ],
          [ "15", "NUMTOKEN", "70" ],
          [ "15", "COMMA", "," ],
          [ "15", "NUMTOKEN", "40" ],
          [ "15", "COMMA", "," ],
          [ "15", "NUMTOKEN", "55" ],
          [ "15", "RSPAR", "]" ],
          [ "15", "WHERE", "where" ],
          [ "15", "IDENTIFIER", "it" ],
          [ "15", "DIVIDE", "/" ],
          [ "15", "NUMTOKEN", "2" ],
          [ "15", "IS", "is" ],
          [ "15", "WITHIN", "within" ],
          [ "15", "NUMTOKEN", "30" ],
          [ "15", "TO", "to" ],
          [ "15", "NUMTOKEN", "60" ],
          [ "15", "SEMICOLON", ";" ],
          [ "16", "IDENTIFIER", "x" ],
          [ "16", "ASSIGN", ":=" ],
          [ "16", "NUMTOKEN", "4711" ],
          [ "16", "SEMICOLON", ";" ],
          [ "17", "TIME", "time" ],
          [ "17", "OF", "of" ],
          [ "17", "IDENTIFIER", "x" ],
          [ "17", "ASSIGN", ":=" ],
          [ "17", "TIMETOKEN", "1999-09-19" ],
          [ "17", "SEMICOLON", ";" ],
          [ "19", "IDENTIFIER", "y" ],
          [ "19", "ASSIGN", ":=" ],
          [ "19", "IDENTIFIER", "x" ],
          [ "19", "SEMICOLON", ";" ],
          [ "20", "TIME", "time" ],
          [ "20", "OF", "of" ],
          [ "20", "IDENTIFIER", "y" ],
          [ "20", "ASSIGN", ":=" ],
          [ "20", "TIMETOKEN", "2022-12-22" ],
          [ "20", "SEMICOLON", ";" ],
          [ "21", "TRACE", "trace" ],
          [ "21", "TIME", "time" ],
          [ "21", "OF", "of" ],
          [ "21", "IDENTIFIER", "x" ],
          [ "21", "SEMICOLON", ";" ],
          [ "22", "TRACE", "trace" ],
          [ "22", "TIME", "time" ],
          [ "22", "OF", "of" ],
          [ "22", "IDENTIFIER", "y" ],
          [ "22", "SEMICOLON", ";" ],
          [ "23", "TRACE", "trace" ],
          [ "23", "TIME", "time" ],
          [ "23", "OF", "of" ],
          [ "23", "TIME", "time" ],
          [ "23", "OF", "of" ],
          [ "23", "IDENTIFIER", "y" ],
          [ "23", "SEMICOLON", ";" ]
        ]
        |}]
    ;;
  end)
;;
