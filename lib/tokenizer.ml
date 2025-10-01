open Angstrom

module TokenType = struct
  type t =
    | Plus
    | Minus
    | Times
    | Div
    | Semi
    | Identifier of string
    | If
    | Return
    | Then
    | Write
    | Unknown of string

  let token_type_from_string = function
    | "+" -> Plus
    | "-" -> Minus
    | "*" -> Times
    | "/" -> Div
    | ";" -> Semi
    | "If" -> If
    | "Then" -> Then
    | "Write" -> Write
    | "Return" -> Return
    | other -> Identifier other
  ;;

  let token_type_to_string = function
    | Plus -> "Op +"
    | Minus -> "Op -"
    | Times -> "Op *"
    | Div -> "Op /"
    | Semi -> "End ;"
    | If -> "Key If"
    | Then -> "Key Then"
    | Write -> "Key Write"
    | Return -> "Key Return"
    | Identifier other -> Printf.sprintf "Ident %s" other
    | Unknown other -> Printf.sprintf "Unknown %s" other
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
end

type t =
  { tokens : Token.t list
  ; col : int
  ; row : int
  }

let create () = { col = 0; row = 0; tokens = [] }

let parse_plus tokenizer =
  char '+'
  >>| fun _ ->
  let token =
    { Token.type_ = Plus
    ; literal = "+"
    ; col = tokenizer.col
    ; row = tokenizer.row
    ; length = 1
    }
  in
  { tokenizer with col = tokenizer.col + 1; tokens = token :: tokenizer.tokens }
;;

let parse_minus tokenizer =
  char '-'
  >>| fun _ ->
  let token =
    { Token.type_ = Minus
    ; literal = "-"
    ; col = tokenizer.col
    ; row = tokenizer.row
    ; length = 1
    }
  in
  { tokenizer with col = tokenizer.col + 1; tokens = token :: tokenizer.tokens }
;;

let parse_times tokenizer =
  char '*'
  >>| fun _ ->
  let token =
    { Token.type_ = Times
    ; literal = "*"
    ; col = tokenizer.col
    ; row = tokenizer.row
    ; length = 1
    }
  in
  { tokenizer with col = tokenizer.col + 1; tokens = token :: tokenizer.tokens }
;;

let parse_div tokenizer =
  char '/'
  >>| fun _ ->
  let token =
    { Token.type_ = Div
    ; literal = "/"
    ; col = tokenizer.col
    ; row = tokenizer.row
    ; length = 1
    }
  in
  { tokenizer with col = tokenizer.col + 1; tokens = token :: tokenizer.tokens }
;;

let parse_semi tokenizer =
  char ';'
  >>| fun _ ->
  let token =
    { Token.type_ = Semi
    ; literal = ";"
    ; col = tokenizer.col
    ; row = tokenizer.row
    ; length = 1
    }
  in
  { tokenizer with col = tokenizer.col + 1; tokens = token :: tokenizer.tokens }
;;

let parse_ident tokenizer =
  take_while1 (function
    | 'a' .. 'z' | 'A' .. 'Z' | '-' | '_' -> true
    | _ -> false)
  >>| fun tok ->
  let len = String.length tok in
  let token_type = TokenType.token_type_from_string tok in
  let token =
    { Token.type_ = token_type
    ; literal = tok
    ; col = tokenizer.col
    ; row = tokenizer.row
    ; length = len
    }
  in
  { tokenizer with col = tokenizer.col + len; tokens = token :: tokenizer.tokens }
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
       | '+' -> parse_plus tok >>= loop
       | '-' -> parse_minus tok >>= loop
       | '*' -> parse_times tok >>= loop
       | '/' -> parse_div tok >>= loop
       | ';' -> parse_semi tok >>= loop
       | 'a' .. 'z' | 'A' .. 'Z' | '_' -> parse_ident tok >>= loop
       | _ ->
         take 1
         >>= fun other ->
         let token =
           { Token.type_ = Unknown other
           ; literal = other
           ; length = String.length other
           ; row = tok.row
           ; col = tok.col
           }
         in
         let tz = { tok with col = tok.col + 1 } in
         loop { tz with tokens = token :: tok.tokens })
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
          (fun t ->
             Printf.sprintf
               "Token { type = %s; literal = \"%s\"; length = %d; row = %d; col = %d }"
               (token_type_to_string t.type_)
               t.literal
               t.length
               t.row
               t.col)
          tokens
        |> String.concat "\n"
      in
      print_endline s
    ;;

    let run_test input =
      let tokenizer = create () in
      match exec tokenizer input with
      | Ok tokens -> print_tokens tokens
      | Error msg -> print_endline ("Error: " ^ msg)
    ;;

    let%expect_test "simple operators" =
      run_test "+-*/;";
      [%expect
        {|
        Token { type = Op +; literal = "+"; length = 1; row = 0; col = 0 }
        Token { type = Op -; literal = "-"; length = 1; row = 0; col = 1 }
        Token { type = Op *; literal = "*"; length = 1; row = 0; col = 2 }
        Token { type = Op /; literal = "/"; length = 1; row = 0; col = 3 }
        Token { type = End ;; literal = ";"; length = 1; row = 0; col = 4 }
        |}]
    ;;

    let%expect_test "operators with whitespace" =
      run_test "  + -   * /    ;";
      [%expect
        {|
        Token { type = Op +; literal = "+"; length = 1; row = 0; col = 2 }
        Token { type = Op -; literal = "-"; length = 1; row = 0; col = 4 }
        Token { type = Op *; literal = "*"; length = 1; row = 0; col = 8 }
        Token { type = Op /; literal = "/"; length = 1; row = 0; col = 10 }
        Token { type = End ;; literal = ";"; length = 1; row = 0; col = 15 }
        |}]
    ;;

    let%expect_test "operators with newlines" =
      run_test "+\n-\n\n*";
      [%expect
        {|
        Token { type = Op +; literal = "+"; length = 1; row = 0; col = 0 }
        Token { type = Op -; literal = "-"; length = 1; row = 1; col = 0 }
        Token { type = Op *; literal = "*"; length = 1; row = 3; col = 0 }
        |}]
    ;;

    let%expect_test "identifiers and keywords" =
      run_test "If foo Return bar";
      [%expect
        {|
        Token { type = Key If; literal = "If"; length = 2; row = 0; col = 0 }
        Token { type = Ident foo; literal = "foo"; length = 3; row = 0; col = 3 }
        Token { type = Key Return; literal = "Return"; length = 6; row = 0; col = 7 }
        Token { type = Ident bar; literal = "bar"; length = 3; row = 0; col = 14 }
        |}]
    ;;

    let%expect_test "a mix of everything" =
      run_test "If + foo;\n  Return - bar";
      [%expect
        {|
        Token { type = Key If; literal = "If"; length = 2; row = 0; col = 0 }
        Token { type = Op +; literal = "+"; length = 1; row = 0; col = 3 }
        Token { type = Ident foo; literal = "foo"; length = 3; row = 0; col = 5 }
        Token { type = End ;; literal = ";"; length = 1; row = 0; col = 8 }
        Token { type = Key Return; literal = "Return"; length = 6; row = 1; col = 2 }
        Token { type = Op -; literal = "-"; length = 1; row = 1; col = 9 }
        Token { type = Ident bar; literal = "bar"; length = 3; row = 1; col = 11 }
        |}]
    ;;

    let%expect_test "unknown characters" =
      run_test "+ # @ -";
      [%expect
        {|
        Token { type = Op +; literal = "+"; length = 1; row = 0; col = 0 }
        Token { type = Unknown #; literal = "#"; length = 1; row = 0; col = 2 }
        Token { type = Unknown @; literal = "@"; length = 1; row = 0; col = 4 }
        Token { type = Op -; literal = "-"; length = 1; row = 0; col = 6 }
        |}]
    ;;
  end)
;;

