open Base

type operation =
  | PLUS
  | MINUS
  | TIMES
  | DIVIDE

type value =
  | NumberLiteral of float
  | StringLiteral of string
  | BoolLiteral of bool
  | Unit

let get_arg node =
  let open Yojson.Safe.Util in
  node |> member "arg"
;;

let get_arg_list node =
  let open Yojson.Safe.Util in
  node |> member "arg" |> to_list
;;

let get_statements node =
  let open Yojson.Safe.Util in
  node |> member "statements" |> to_list
;;

let get_type node =
  let open Yojson.Safe.Util in
  node |> member "type" |> to_string
;;

let get_value node =
  let open Yojson.Safe.Util in
  node |> member "value" |> to_string
;;

let rec eval (env : (string, value) Hashtbl.t) yojson_ast : value =
  let type_ = get_type yojson_ast in
  match type_ with
  | "STATEMENTBLOCK" ->
    let stmts = get_statements yojson_ast in
    let _ = stmts |> List.map ~f:(eval env) in
    Unit
  | "WRITE" ->
    let arg = get_arg yojson_ast in
    eval env arg |> write_value
  | "PLUS" ->
    let args = get_arg_list yojson_ast in
    let lval = List.nth_exn args 0 |> eval env in
    let rval = List.nth_exn args 1 |> eval env in
    (match rval, lval with
     | NumberLiteral r, NumberLiteral l -> NumberLiteral (l +. r)
     | _, _ -> failwith "should never happen")
  | "MINUS" ->
    let args = get_arg_list yojson_ast in
    let lval = List.nth_exn args 0 |> eval env in
    let rval = List.nth_exn args 1 |> eval env in
    (match rval, lval with
     | NumberLiteral r, NumberLiteral l -> NumberLiteral (l -. r)
     | _, _ -> failwith "should never happen")
  | "TIMES" ->
    let args = get_arg_list yojson_ast in
    let lval = List.nth_exn args 0 |> eval env in
    let rval = List.nth_exn args 1 |> eval env in
    (match rval, lval with
     | NumberLiteral r, NumberLiteral l -> NumberLiteral (l *. r)
     | _, _ -> failwith "should never happen")
  | "DIVIDE" ->
    let args = get_arg_list yojson_ast in
    let lval = List.nth_exn args 0 |> eval env in
    let rval = List.nth_exn args 1 |> eval env in
    (match rval, lval with
     | NumberLiteral r, NumberLiteral l -> NumberLiteral (l /. r)
     | _, _ -> failwith "should never happen")
  | "AMPERSAND" ->
    let args = get_arg_list yojson_ast in
    let lval = List.nth_exn args 0 |> eval env in
    let rval = List.nth_exn args 1 |> eval env in
    (match rval, lval with
     | StringLiteral r, StringLiteral l -> StringLiteral (l ^ r)
     | _, _ -> failwith "should never happen")
  | "STRTOKEN" ->
    let v = get_value yojson_ast in
    StringLiteral v
  | "NUMTOKEN" -> NumberLiteral (Float.of_string (get_value yojson_ast))
  | "NULL" -> Unit
  | "TRUE" -> BoolLiteral true
  | "FALSE" -> BoolLiteral false
  | _ -> failwith "not implemented yet"

and write_value (expr : value) =
  match expr with
  | NumberLiteral number ->
    Stdio.print_endline (Float.to_string number);
    Unit
  | StringLiteral str ->
    Stdio.print_endline str;
    Unit
  | BoolLiteral b ->
    Stdio.print_endline (Bool.to_string b);
    Unit
  | Unit ->
    Stdio.print_endline "null";
    Unit
;;

let%test_module "Parser tests" =
  (module struct
    let%expect_test "test interpretation simple write" =
      let input =
        {|WRITE "Hello world";
    WRITE (1 + 5) / 2.5 * 2.3;
    WRITE "Hello " & "World";|}
      in
      let env = Hashtbl.create (module String) in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p ->
         (* Yojson.Safe.pretty_to_string p |> Stdio.print_endline; *)
         ignore (eval env p)
       | Error err -> Stdio.print_endline err);
      [%expect
        {|
       "Hello world"
      5.52
       "Hello "  "World"
      |}]
    ;;

    let%expect_test "test interpretation null" =
      let input = {|WRITE null;|} in
      let env = Hashtbl.create (module String) in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (eval env p)
       | Error err -> Stdio.print_endline err);
      [%expect {| null |}]
    ;;

    let%expect_test "test interpretation booleans" =
      let input = {|WRITE true; WRITE false;|} in
      let env = Hashtbl.create (module String) in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (eval env p)
       | Error err -> Stdio.print_endline err);
      [%expect
        {|
        true
        false
        |}]
    ;;
  end)
;;
