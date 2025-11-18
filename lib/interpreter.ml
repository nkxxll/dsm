open Base

type operation =
  | PLUS
  | MINUS
  | TIMES
  | DIVIDE

type value =
  { type_ : value_type
  ; time : float option
  }

and value_type =
  | List of value list
  | NumberLiteral of float
  | StringLiteral of string
  | BoolLiteral of bool
  | TimeLiteral of float
  | Unit

module InterpreterData = struct
  type t =
    { now : float
    ; env : (string, value) Hashtbl.t
    }

  let create () = { now = Unix.gettimeofday (); env = Hashtbl.create (module String) }
end

let timestamp_to_iso_string time_float =
  let sec = time_float /. 1000.0 in
  let tm = Unix.gmtime sec in
  Printf.sprintf
    "%04d-%02d-%02dT%02d:%02d:%02dZ"
    (tm.tm_year + 1900)
    (tm.tm_mon + 1)
    tm.tm_mday
    tm.tm_hour
    tm.tm_min
    tm.tm_sec
;;

(* Convert HH:MM or HH:MM:SS time string to unix timestamp (today's date) *)
let time_string_to_float time_str =
  let parts = String.split_on_chars time_str ~on:[ ':' ] in
  match List.map parts ~f:Int.of_string with
  | [ hours; minutes ] ->
    let now = Unix.gettimeofday () in
    let tm = Unix.localtime now in
    let new_tm = { tm with tm_hour = hours; tm_min = minutes; tm_sec = 0 } in
    fst (Unix.mktime new_tm)
  | [ hours; minutes; seconds ] ->
    let now = Unix.gettimeofday () in
    let tm = Unix.localtime now in
    let new_tm = { tm with tm_hour = hours; tm_min = minutes; tm_sec = seconds } in
    fst (Unix.mktime new_tm)
  | _ -> failwith ("Invalid time format: " ^ time_str)
;;

let get_arg node =
  let open Yojson.Safe.Util in
  node |> member "arg"
;;

let get_arg_list node =
  let open Yojson.Safe.Util in
  node |> member "arg" |> to_list
;;

let get_items_list node =
  let open Yojson.Safe.Util in
  node |> member "items" |> to_list
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

let get_ident node =
  let open Yojson.Safe.Util in
  node |> member "ident" |> to_string
;;

let get_name node =
  let open Yojson.Safe.Util in
  node |> member "name" |> to_string
;;

let rec eval (interp_data : InterpreterData.t) yojson_ast : value =
  let type_ = get_type yojson_ast in
  match type_ with
  | "STATEMENTBLOCK" ->
    let stmts = get_statements yojson_ast in
    let _ = stmts |> List.map ~f:(eval interp_data) in
    { type_ = Unit; time = None }
  | "WRITE" ->
    let arg = get_arg yojson_ast in
    eval interp_data arg |> write_value;
    { type_ = Unit; time = None }
  | "ASSIGN" ->
    let ident = get_ident yojson_ast in
    let arg = get_arg yojson_ast in
    let val_ = eval interp_data arg in
    Hashtbl.set interp_data.env ~key:ident ~data:val_;
    { type_ = Unit; time = None }
  | "TIMEASSIGN" ->
    let ident = get_ident yojson_ast in
    let arg = get_arg yojson_ast in
    let val_ = eval interp_data arg in
    (match val_ with
     | { type_ = TimeLiteral t; _ } ->
       let current =
         Hashtbl.find_or_add interp_data.env ident ~default:(fun () ->
           { type_ = Unit; time = None })
       in
       Hashtbl.set interp_data.env ~key:ident ~data:{ current with time = Some t }
     | _ -> failwith "You have to call time with a timestamp");
    { type_ = Unit; time = None }
  | "TIMETOKEN" ->
    let time_str = get_value yojson_ast in
    let time_float = time_string_to_float time_str in
    { type_ = TimeLiteral time_float; time = None }
  | "VARIABLE" ->
    let name = get_name yojson_ast in
    (match Hashtbl.find interp_data.env name with
     | Some v -> v
     | None -> failwith ("Undefined variable: " ^ name))
  | "PLUS" ->
    let args = get_arg_list yojson_ast in
    let lval = List.nth_exn args 0 |> eval interp_data in
    let rval = List.nth_exn args 1 |> eval interp_data in
    (match rval.type_, lval.type_ with
     | NumberLiteral r, NumberLiteral l -> { type_ = NumberLiteral (l +. r); time = None }
     | _, _ -> failwith "should never happen")
  | "MINUS" ->
    let args = get_arg_list yojson_ast in
    let lval = List.nth_exn args 0 |> eval interp_data in
    let rval = List.nth_exn args 1 |> eval interp_data in
    (match rval.type_, lval.type_ with
     | NumberLiteral r, NumberLiteral l -> { type_ = NumberLiteral (l -. r); time = None }
     | _, _ -> failwith "should never happen")
  | "TIMES" ->
    let args = get_arg_list yojson_ast in
    let lval = List.nth_exn args 0 |> eval interp_data in
    let rval = List.nth_exn args 1 |> eval interp_data in
    (match rval.type_, lval.type_ with
     | NumberLiteral r, NumberLiteral l -> { type_ = NumberLiteral (l *. r); time = None }
     | _, _ -> failwith "should never happen")
  | "DIVIDE" ->
    let args = get_arg_list yojson_ast in
    let lval = List.nth_exn args 0 |> eval interp_data in
    let rval = List.nth_exn args 1 |> eval interp_data in
    (match rval.type_, lval.type_ with
     | NumberLiteral r, NumberLiteral l -> { type_ = NumberLiteral (l /. r); time = None }
     | _, _ -> failwith "should never happen")
  | "AMPERSAND" ->
    let args = get_arg_list yojson_ast in
    let lval = List.nth_exn args 0 |> eval interp_data in
    let rval = List.nth_exn args 1 |> eval interp_data in
    (match rval.type_, lval.type_ with
     | StringLiteral r, StringLiteral l -> { type_ = StringLiteral (l ^ r); time = None }
     | NumberLiteral r, StringLiteral l ->
       { type_ = StringLiteral (l ^ Float.to_string r); time = None }
     | StringLiteral r, NumberLiteral l ->
       { type_ = StringLiteral (Float.to_string l ^ r); time = None }
     | _, _ -> failwith "should never happen")
  | "STRTOKEN" ->
    let v = get_value yojson_ast in
    { type_ = StringLiteral v; time = None }
  | "NUMTOKEN" ->
    { type_ = NumberLiteral (Float.of_string (get_value yojson_ast)); time = None }
  | "NULL" -> { type_ = Unit; time = None }
  | "TRUE" -> { type_ = BoolLiteral true; time = None }
  | "FALSE" -> { type_ = BoolLiteral false; time = None }
  | "LIST" ->
    let items = get_items_list yojson_ast in
    let evaluated_items = List.map items ~f:(eval interp_data) in
    { type_ = List evaluated_items; time = None }
  | "NOW" -> { type_ = TimeLiteral interp_data.now; time = None }
  | "TIME" ->
    let arg = get_arg yojson_ast in
    let val_ = eval interp_data arg in
    (match val_.time with
     | Some t -> { type_ = TimeLiteral t; time = None }
     | None -> { type_ = Unit; time = None })
  | "CURRENTTIME" -> { type_ = TimeLiteral (Unix.gettimeofday ()); time = None }
  | _ -> failwith "not implemented yet"

and write_value (expr : value) =
  match expr.type_ with
  | NumberLiteral number ->
    Stdio.print_endline (Float.to_string number);
    ()
  | StringLiteral str ->
    Stdio.print_endline str;
    ()
  | BoolLiteral b ->
    Stdio.print_endline (Bool.to_string b);
    ()
  | Unit ->
    Stdio.print_endline "null";
    ()
  | List items ->
    let formatted =
      items
      |> List.map ~f:(function
        | { type_ = NumberLiteral n; _ } -> Float.to_string n
        | { type_ = StringLiteral s; _ } -> s
        | { type_ = BoolLiteral b; _ } -> Bool.to_string b
        | { type_ = Unit; _ } -> "null"
        | { type_ = List _; _ } -> "[...]"
        | { type_ = TimeLiteral t; _ } -> timestamp_to_iso_string t)
      |> String.concat ~sep:", "
    in
    Stdio.print_endline ("[" ^ formatted ^ "]");
    ()
  | TimeLiteral t ->
    Stdio.print_endline (timestamp_to_iso_string t);
    ()
;;

let timestamp_to_iso_string ts =
  let tm = Unix.gmtime ts in
  Printf.sprintf
    "%04d-%02d-%02dT%02d:%02d:%02dZ"
    (tm.tm_year + 1900)
    (tm.tm_mon + 1)
    tm.tm_mday
    tm.tm_hour
    tm.tm_min
    tm.tm_sec
;;

let interpret yojson_ast : value =
  let interp_data = InterpreterData.create () in
  eval interp_data yojson_ast
;;

let%test_module "Parser tests" =
  (module struct
    let%expect_test "test interpretation simple write" =
      let input =
        {|WRITE "Hello world";
    WRITE (1 + 5) / 2.5 * 2.3;
    WRITE "Hello " & "World";|}
      in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p ->
         (* Yojson.Safe.pretty_to_string p |> Stdio.print_endline; *)
         ignore (interpret p)
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
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (interpret p)
       | Error err -> Stdio.print_endline err);
      [%expect {| null |}]
    ;;

    let%expect_test "test interpretation booleans" =
      let input = {|WRITE true; WRITE false;|} in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (interpret p)
       | Error err -> Stdio.print_endline err);
      [%expect
        {|
        true
        false
        |}]
    ;;

    let%expect_test "test assignment and variable read" =
      let input =
        {|x := 42;
    WRITE x;|}
      in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (interpret p)
       | Error err -> Stdio.print_endline err);
      [%expect {| 42. |}]
    ;;

    let%expect_test "test assignment with string and variable read" =
      let input =
        {|msg := "Hello";
    WRITE msg;|}
      in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (interpret p)
       | Error err -> Stdio.print_endline err);
      [%expect {| "Hello" |}]
    ;;

    let%expect_test "test assignment with arithmetic expression" =
      let input =
        {|result := 10 + 5 * 2;
     WRITE result;|}
      in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (interpret p)
       | Error err -> Stdio.print_endline err);
      [%expect {| 20. |}]
    ;;

    let%expect_test "test string concatenation with number (string & number)" =
      let input = {|WRITE "Value: " & 42;|} in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (interpret p)
       | Error err -> Stdio.print_endline err);
      [%expect {| "Value: " 42. |}]
    ;;

    let%expect_test "test string concatenation with number (number & string)" =
      let input = {|WRITE 42 & " is the answer";|} in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (interpret p)
       | Error err -> Stdio.print_endline err);
      [%expect {| 42. " is the answer" |}]
    ;;

    let%expect_test "test string concatenation with multiple numbers" =
      let input = {|WRITE "Result: " & 10 + 5 & " total";|} in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (interpret p)
       | Error err -> Stdio.print_endline err);
      [%expect {| "Result: " 15. " total" |}]
    ;;

    let%expect_test "test the write and expression thing" =
      let input =
        {|x := 1447 + 2;
         Write x + 100;|}
      in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (interpret p)
       | Error err -> Stdio.print_endline err);
      [%expect {| 1549. |}]
    ;;

    let%expect_test "test list interpretation" =
      let input =
        {|
          x := "hello";
          WRITE [1, 2, 3, x];
         WRITE ["a", "b"];|}
      in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (interpret p)
       | Error err -> Stdio.print_endline err);
      [%expect
        {|
        [1., 2., 3.,  "hello" ]
        [ "a" ,  "b" ]
        |}]
    ;;

    let censor_digits s = String.map s ~f:(fun c -> if Char.is_digit c then 'X' else c)

    let%expect_test "test now write" =
      let input = {| write now; |} in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (interpret p)
       | Error err -> Stdio.print_endline err);
      [%expect.output] |> censor_digits |> Stdio.print_endline;
      [%expect {| XXXX-XX-XXTXX:XX:XXZ |}]
    ;;

    let%expect_test "test currenttime write" =
      let input = {| write currenttime; |} in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (interpret p)
       | Error err -> Stdio.print_endline err);
      [%expect.output] |> censor_digits |> Stdio.print_endline;
      [%expect {| XXXX-XX-XXTXX:XX:XXZ |}]
    ;;

    let%expect_test "test time literal parsing" =
      let input = {| write 12:34; |} in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (interpret p)
       | Error err -> Stdio.print_endline err);
      [%expect.output] |> censor_digits |> Stdio.print_endline;
      [%expect {| XXXX-XX-XXTXX:XX:XXZ |}]
    ;;

    let%expect_test "test time literal with seconds" =
      let input = {| write 12:34:56; |} in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (interpret p)
       | Error err -> Stdio.print_endline err);
      [%expect.output] |> censor_digits |> Stdio.print_endline;
      [%expect {| XXXX-XX-XXTXX:XX:XXZ |}]
    ;;

    let%expect_test "test time variable assignment" =
      let input =
        {|
          t := 14:30;
          write t;
        |}
      in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (interpret p)
       | Error err -> Stdio.print_endline err);
      [%expect.output] |> censor_digits |> Stdio.print_endline;
      [%expect {| XXXX-XX-XXTXX:XX:XXZ |}]
    ;;

    let%expect_test "test time in list" =
      let input =
        {|
          write [10:15, 20:45:30, "meeting"];
        |}
      in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (interpret p)
       | Error err -> Stdio.print_endline err);
      [%expect.output] |> censor_digits |> Stdio.print_endline;
      [%expect {| [XXXX-XX-XXTXX:XX:XXZ, XXXX-XX-XXTXX:XX:XXZ,  "meeting" ] |}]
    ;;

    let%expect_test "test now in list" =
      let input =
        {|
          write [now, "timestamp"];
        |}
      in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (interpret p)
       | Error err -> Stdio.print_endline err);
      [%expect.output] |> censor_digits |> Stdio.print_endline;
      [%expect {| [XXXX-XX-XXTXX:XX:XXZ,  "timestamp" ] |}]
    ;;

    let%expect_test "test multiple times" =
      let input =
        {|
          t1 := 09:00;
          t2 := 17:30:45;
          write t1;
          write t2;
        |}
      in
      let parsed = input |> Tokenizer.tokenize |> Result.map ~f:Parser.parse in
      (match parsed with
       | Ok p -> ignore (interpret p)
       | Error err -> Stdio.print_endline err);
      [%expect.output] |> censor_digits |> Stdio.print_endline;
      [%expect
        {|
        XXXX-XX-XXTXX:XX:XXZ
        XXXX-XX-XXTXX:XX:XXZ
        |}]
    ;;
  end)
;;
