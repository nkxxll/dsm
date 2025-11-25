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

let get_line node =
  let open Yojson.Safe.Util in
  node |> member "line" |> to_string
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

let get_condition node =
  let open Yojson.Safe.Util in
  node |> member "condition"
;;

let get_thenbranch node =
  let open Yojson.Safe.Util in
  node |> member "thenbranch"
;;

let get_elsebranch node =
  let open Yojson.Safe.Util in
  node |> member "elsebranch"
;;

let get_varname node =
  let open Yojson.Safe.Util in
  node |> member "varname" |> to_string
;;

let get_expression node =
  let open Yojson.Safe.Util in
  node |> member "expression"
;;

let get_statements_block node =
  let open Yojson.Safe.Util in
  node |> member "statements"
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
  | "TRACE" ->
    let line = get_line yojson_ast in
    let arg = get_arg yojson_ast in
    let val_ = eval interp_data arg in
    Stdio.printf "Line %s: " line;
    write_value val_;
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
  | "UPPERCASE" ->
    let arg = get_arg yojson_ast in
    let val_ = eval interp_data arg in
    (match val_.type_ with
     | StringLiteral s -> { type_ = StringLiteral (String.uppercase s); time = None }
     | List items ->
       let uppercased =
         List.map items ~f:(fun item ->
           match item.type_ with
           | StringLiteral s -> { item with type_ = StringLiteral (String.uppercase s) }
           | _ -> item)
       in
       { type_ = List uppercased; time = None }
     | _ -> failwith "UPPERCASE expects a string or (nonempty) list of strings")
  | "MAXIMUM" ->
    let arg = get_arg yojson_ast in
    let val_ = eval interp_data arg in
    (match val_.type_ with
     | List items ->
       let numbers =
         List.filter_map items ~f:(fun item ->
           match item.type_ with
           | NumberLiteral n -> Some n
           | _ -> None)
       in
       (match List.max_elt numbers ~compare:Float.compare with
        | Some max_val -> { type_ = NumberLiteral max_val; time = None }
        | None -> failwith "MAXIMUM requires a non-empty list of numbers")
     | _ -> failwith "MAXIMUM expects a list")
  | "AVERAGE" ->
    let arg = get_arg yojson_ast in
    let val_ = eval interp_data arg in
    (match val_.type_ with
     | List items ->
       let numbers =
         List.filter_map items ~f:(fun item ->
           match item.type_ with
           | NumberLiteral n -> Some n
           | _ -> None)
       in
       (match numbers with
        | [] -> failwith "AVERAGE requires a non-empty list of numbers"
        | lst ->
          let sum = List.fold lst ~init:0.0 ~f:( +. ) in
          let avg = sum /. Float.of_int (List.length lst) in
          { type_ = NumberLiteral avg; time = None })
     | _ -> failwith "AVERAGE expects a list")
  | "IF" ->
    let condition = get_condition yojson_ast in
    let thenbranch = get_thenbranch yojson_ast in
    let elsebranch = get_elsebranch yojson_ast in
    let cond_val = eval interp_data condition in
    (match cond_val.type_ with
     | BoolLiteral true -> eval interp_data thenbranch
     | BoolLiteral false -> eval interp_data elsebranch
     | _ -> failwith "IF condition must evaluate to a boolean")
  | "FOR" ->
    let varname = get_varname yojson_ast in
    let expression = get_expression yojson_ast in
    let statements_block = get_statements_block yojson_ast in
    let iter_val = eval interp_data expression in
    (match iter_val.type_ with
     | List items ->
       let _ =
         List.map items ~f:(fun item ->
           Hashtbl.set interp_data.env ~key:varname ~data:item;
           eval interp_data statements_block)
       in
       { type_ = Unit; time = None }
     | _ -> failwith "FOR loop requires a list to iterate over")
  | "INCREASE" ->
    let arg = get_arg yojson_ast in
    let val_ = eval interp_data arg in
    (match val_.type_ with
     | List items ->
       let numbers =
         List.filter_map items ~f:(fun item ->
           match item.type_ with
           | NumberLiteral n -> Some n
           | _ -> None)
       in
       (match numbers with
        | [] | [ _ ] -> { type_ = List []; time = None }
        | lst ->
          let diffs =
            List.init
              (List.length lst - 1)
              ~f:(fun i ->
                let curr = List.nth_exn lst (i + 1) in
                let prev = List.nth_exn lst i in
                { type_ = NumberLiteral (curr -. prev); time = None })
          in
          { type_ = List diffs; time = None })
     | _ -> failwith "INCREASE expects a list")
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

let interpret_parsed yojson_ast : value =
  let interp_data = InterpreterData.create () in
  eval interp_data yojson_ast
;;

let interpret input : unit =
  let res = input |> Tokenizer.tokenize |> Result.bind ~f:Parser.parse in
  res |> Result.iter_error ~f:Stdio.print_endline;
  res |> Result.iter ~f:(fun p -> ignore (interpret_parsed p))
;;

let%test_module "Parser tests" =
  (module struct
    let%expect_test "test interpretation simple write" =
      let input =
        {|WRITE "Hello world";
    WRITE (1 + 5) / 2.5 * 2.3;
    WRITE "Hello " & "World";|}
      in
      input |> interpret;
      [%expect
        {|
       "Hello world"
      5.52
       "Hello "  "World"
      |}]
    ;;

    let%expect_test "test interpretation null" =
      let input = {|WRITE null;|} in
      input |> interpret;
      [%expect {| null |}]
    ;;

    let%expect_test "test interpretation booleans" =
      let input = {|WRITE true; WRITE false;|} in
      input |> interpret;
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
      input |> interpret;
      [%expect {| 42. |}]
    ;;

    let%expect_test "test assignment with string and variable read" =
      let input =
        {|msg := "Hello";
    WRITE msg;|}
      in
      input |> interpret;
      [%expect {| "Hello" |}]
    ;;

    let%expect_test "test assignment with arithmetic expression" =
      let input =
        {|result := 10 + 5 * 2;
     WRITE result;|}
      in
      input |> interpret;
      [%expect {| 20. |}]
    ;;

    let%expect_test "test string concatenation with number (string & number)" =
      let input = {|WRITE "Value: " & 42;|} in
      input |> interpret;
      [%expect {| "Value: " 42. |}]
    ;;

    let%expect_test "test string concatenation with number (number & string)" =
      let input = {|WRITE 42 & " is the answer";|} in
      input |> interpret;
      [%expect {| 42. " is the answer" |}]
    ;;

    let%expect_test "test string concatenation with multiple numbers" =
      let input = {|WRITE "Result: " & 10 + 5 & " total";|} in
      input |> interpret;
      [%expect {| "Result: " 15. " total" |}]
    ;;

    let%expect_test "test the write and expression thing" =
      let input =
        {|x := 1447 + 2;
         Write x + 100;|}
      in
      input |> interpret;
      [%expect {| 1549. |}]
    ;;

    let%expect_test "test list interpretation" =
      let input =
        {|
          x := "hello";
          WRITE [1, 2, 3, x];
         WRITE ["a", "b"];|}
      in
      input |> interpret;
      [%expect
        {|
        [1., 2., 3.,  "hello" ]
        [ "a" ,  "b" ]
        |}]
    ;;

    let censor_digits s = String.map s ~f:(fun c -> if Char.is_digit c then 'X' else c)

    let%expect_test "test now write" =
      let input = {| write now; |} in
      input |> interpret;
      [%expect.output] |> censor_digits |> Stdio.print_endline;
      [%expect {| XXXX-XX-XXTXX:XX:XXZ |}]
    ;;

    let%expect_test "test currenttime write" =
      let input = {| write currenttime; |} in
      input |> interpret;
      [%expect.output] |> censor_digits |> Stdio.print_endline;
      [%expect {| XXXX-XX-XXTXX:XX:XXZ |}]
    ;;

    let%expect_test "test time literal parsing" =
      let input = {| write 12:34; |} in
      input |> interpret;
      [%expect.output] |> censor_digits |> Stdio.print_endline;
      [%expect {| XXXX-XX-XXTXX:XX:XXZ |}]
    ;;

    let%expect_test "test time literal with seconds" =
      let input = {| write 12:34:56; |} in
      input |> interpret;
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
      input |> interpret;
      [%expect.output] |> censor_digits |> Stdio.print_endline;
      [%expect {| XXXX-XX-XXTXX:XX:XXZ |}]
    ;;

    let%expect_test "test time in list" =
      let input =
        {|
          write [10:15, 20:45:30, "meeting"];
        |}
      in
      input |> interpret;
      [%expect.output] |> censor_digits |> Stdio.print_endline;
      [%expect {| [XXXX-XX-XXTXX:XX:XXZ, XXXX-XX-XXTXX:XX:XXZ,  "meeting" ] |}]
    ;;

    let%expect_test "test now in list" =
      let input =
        {|
          write [now, "timestamp"];
        |}
      in
      input |> interpret;
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
      input |> interpret;
      [%expect.output] |> censor_digits |> Stdio.print_endline;
      [%expect
        {|
        XXXX-XX-XXTXX:XX:XXZ
        XXXX-XX-XXTXX:XX:XXZ
        |}]
    ;;

    let%expect_test "test time assign" =
      let input =
        {|
          x := 5;
          time x := 17:30:45;
          write time x;
        |}
      in
      input |> interpret;
      [%expect.output] |> censor_digits |> Stdio.print_endline;
      [%expect {| XXXX-XX-XXTXX:XX:XXZ |}]
    ;;

    let%expect_test "test zwischenstand von prof" =
      let input =
        {|x := 4711;
          time x := now;

          write x;
          write time x;

          write uppercase "Hallo";
          write uppercase ["Wer", "wagt","gewinnt"];

          y := [100,200,150];
          write maximum y;
          write average y;
          write increase y;|}
      in
      input |> interpret;
      [%expect.output] |> censor_digits |> Stdio.print_endline;
      [%expect
        {|
        XXXX.
        XXXX-XX-XXTXX:XX:XXZ
         "HALLO"
        [ "WER" ,  "WAGT" ,  "GEWINNT" ]
        XXX.
        XXX.
        [XXX., -XX.]
        |}]
    ;;

    let%expect_test "test if statement with true condition" =
      let input = {|IF true THEN WRITE "yes"; ENDIF;|} in
      input |> interpret;
      [%expect {| "yes" |}]
    ;;

    let%expect_test "test if statement with false condition" =
      let input = {|IF false THEN WRITE "yes"; ENDIF;|} in
      input |> interpret;
      [%expect {| |}]
    ;;

    let%expect_test "test if statement with else branch" =
      let input = {|IF false THEN WRITE "yes"; ELSE WRITE "no"; ENDIF;|} in
      input |> interpret;
      [%expect {| "no" |}]
    ;;

    let%expect_test "test if statement with variable condition" =
      let input =
        {|x := 42;
          IF true THEN WRITE "x is truthy"; ENDIF;|}
      in
      input |> interpret;
      [%expect {| "x is truthy" |}]
    ;;

    let%expect_test "test for loop with list" =
      let input =
        {|FOR i IN [1, 2, 3] DO
          WRITE i;
        ENDDO;|}
      in
      input |> interpret;
      [%expect
        {|
        1.
        2.
        3.
        |}]
    ;;

    let%expect_test "test for loop with string list" =
      let input =
        {|FOR name IN ["Alice", "Bob", "Charlie"] DO
          WRITE name;
        ENDDO;|}
      in
      input |> interpret;
      [%expect
        {|
        "Alice"
        "Bob"
        "Charlie"
        |}]
    ;;

    let%expect_test "test for loop with accumulation" =
      let input =
        {|num := 0;
          FOR i IN [10, 20, 30] DO
            num := num + i;
          ENDDO;
          WRITE num;|}
      in
      input |> interpret;
      [%expect {| 60. |}]
    ;;

    let%expect_test "test nested if statements" =
      let input =
        {|IF true THEN
            IF true THEN WRITE "nested"; ENDIF;
          ENDIF;|}
      in
      input |> interpret;
      [%expect {| "nested" |}]
    ;;

    let%expect_test "test for loop with if statement inside" =
      let input =
        {|FOR i IN [1, 2, 3, 4, 5] DO
          IF true THEN WRITE i; ENDIF;
        ENDDO;|}
      in
      input |> interpret;
      [%expect
        {|
        1.
        2.
        3.
        4.
        5.
        |}]
    ;;

    let%expect_test "test trace" =
      let input = {|TRACE "foo";|} in
      input |> interpret;
      [%expect {| Line 1:  "foo"  |}]
    ;;
  end)
;;
