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

let unit = { type_ = Unit; time = None }
let value_type_only type_ = { type_; time = None }
let value_time_only time = { type_ = Unit; time }
let value_full type_ time = { type_; time }

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
  | _ -> 0.0
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

type execution_type =
  | ElementWise
  | NotElementWise

let arithmetic_operation (op : 'a -> 'a -> 'a) this other : value =
  match this, other with
  | { type_ = NumberLiteral n; time = this_time }, { type_ = NumberLiteral m; time = _ }
    -> { type_ = NumberLiteral (op n m); time = this_time }
  | _, _ -> unit
;;

let minus_operation this =
  match this with
  | { type_ = NumberLiteral n; _ } -> { this with type_ = NumberLiteral (-.n) }
  | _ -> unit
;;

(* String concatenation operation with mixed type support *)
let concatenation_operation left right : value =
  match left.type_, right.type_ with
  | StringLiteral l, StringLiteral r -> value_type_only (StringLiteral (l ^ r))
  | StringLiteral l, NumberLiteral r -> value_type_only (StringLiteral (l ^ Float.to_string r))
  | NumberLiteral l, StringLiteral r -> value_type_only (StringLiteral (Float.to_string l ^ r))
  | _, _ -> unit
;;

(* String uppercase transformation *)
let string_uppercase_transform value : value =
  match value with
  | { type_ = StringLiteral s; time = value_time } ->
    value_full (StringLiteral (String.uppercase s)) value_time
  | _ -> value
;;

(* Extract numeric values from a list *)
let extract_numbers items : float list =
  List.filter_map items ~f:(fun item ->
    match item.type_ with
    | NumberLiteral n -> Some n
    | _ -> None)
;;

(* Aggregation operation helper *)
let aggregation_operation (op : float list -> float) (item : value) : value =
  match item.type_ with
  | List items ->
    let numbers = extract_numbers items in
    if List.is_empty numbers then unit else value_type_only (NumberLiteral (op numbers))
  | _ -> unit
;;

(* Specific aggregation functions *)
let maximum_op numbers : float =
  match List.max_elt numbers ~compare:Float.compare with
  | Some max_val -> max_val
  | None -> 0.0
;;

let average_op numbers : float =
  match numbers with
  | [] -> 0.0
  | lst ->
    let sum = List.fold lst ~init:0.0 ~f:( +. ) in
    sum /. Float.of_int (List.length lst)
;;

(* INCREASE handler - returns list of differences *)
let increase_handler item : value =
  match item.type_ with
  | List items ->
    let numbers = extract_numbers items in
    (match numbers with
     | [] | [ _ ] -> value_type_only (List [])
     | lst ->
       let diffs =
         List.init
           (List.length lst - 1)
           ~f:(fun i ->
             let curr = List.nth_exn lst (i + 1) in
             let prev = List.nth_exn lst i in
             value_type_only (NumberLiteral (curr -. prev)))
       in
       value_type_only (List diffs))
  | _ -> unit
;;

let rec eval (interp_data : InterpreterData.t) yojson_ast : value =
  (* Binary operation dispatcher *)
  let binary_operation ~execution_type ~(f : value -> value -> value) =
    let args = get_arg_list yojson_ast in
    let first = eval interp_data (List.nth_exn args 0) in
    let second = eval interp_data (List.nth_exn args 1) in
    match execution_type with
    | ElementWise ->
      (match first, second with
       | ( { type_ = List first_list; time = first_time }
         , { type_ = List second_list; time = _second_time } ) ->
         if Int.equal (List.length first_list) (List.length second_list)
         then (
           let combined = List.zip_exn first_list second_list in
           let new_list =
             List.map combined ~f:(fun item ->
               let first, second = item in
               f first second)
           in
           { type_ = List new_list; time = first_time })
         else unit
       | ( { type_ = List first_list; time = _first_time }
         , { type_ = _; time = second_time } ) ->
         { type_ = List (List.map first_list ~f:(fun fa -> f fa second))
         ; time = second_time
         }
       | first_type, { type_ = List second_list; time = second_time } ->
         { type_ = List (List.map second_list ~f:(f first_type)); time = second_time }
       | first_value, second_value -> f first_value second_value)
    | NotElementWise -> f first second
  in
  let unary_operation ~execution_type ~f =
    let arg = get_arg yojson_ast in
    let first = eval interp_data arg in
    match execution_type with
    | ElementWise ->
      (match first with
       | { type_ = List flist; time = ft } ->
         { type_ = List (List.map flist ~f); time = ft }
       | any -> f any)
    | NotElementWise -> f first
  in
  let type_ = get_type yojson_ast in
  match type_ with
  | "STATEMENTBLOCK" ->
    let stmts = get_statements yojson_ast in
    let _ = stmts |> List.map ~f:(eval interp_data) in
    unit
  | "WRITE" ->
    let arg = get_arg yojson_ast in
    eval interp_data arg |> write_value;
    unit
  | "TRACE" ->
    let line = get_line yojson_ast in
    let arg = get_arg yojson_ast in
    let val_ = eval interp_data arg in
    Stdio.printf "Line %s: " line;
    write_value val_;
    unit
  | "ASSIGN" ->
    let ident = get_ident yojson_ast in
    let arg = get_arg yojson_ast in
    let val_ = eval interp_data arg in
    Hashtbl.set interp_data.env ~key:ident ~data:val_;
    unit
  | "TIMEASSIGN" ->
    let ident = get_ident yojson_ast in
    let arg = get_arg yojson_ast in
    let val_ = eval interp_data arg in
    (match val_ with
     | { type_ = TimeLiteral t; _ } ->
       let current =
         Hashtbl.find_or_add interp_data.env ident ~default:(fun () -> unit)
       in
       Hashtbl.set interp_data.env ~key:ident ~data:{ current with time = Some t }
     | _ -> ());
    unit
  | "TIMETOKEN" ->
    let time_str = get_value yojson_ast in
    let time_float = time_string_to_float time_str in
    value_type_only (TimeLiteral time_float)
  | "VARIABLE" ->
    let name = get_name yojson_ast in
    (match Hashtbl.find interp_data.env name with
     | Some v -> v
     | None -> unit)
  | "UNMINUS" -> unary_operation ~execution_type:NotElementWise ~f:minus_operation
  | "PLUS" ->
    binary_operation ~execution_type:ElementWise ~f:(arithmetic_operation ( +. ))
  | "MINUS" ->
    binary_operation ~execution_type:ElementWise ~f:(arithmetic_operation ( -. ))
  | "TIMES" ->
    binary_operation ~execution_type:ElementWise ~f:(arithmetic_operation ( *. ))
  | "DIVIDE" ->
    binary_operation ~execution_type:ElementWise ~f:(arithmetic_operation ( /. ))
  | "AMPERSAND" ->
    binary_operation ~execution_type:ElementWise ~f:concatenation_operation
  | "STRTOKEN" ->
    let v = get_value yojson_ast in
    value_type_only (StringLiteral v)
  | "NUMTOKEN" -> value_type_only (NumberLiteral (Float.of_string (get_value yojson_ast)))
  | "NULL" -> unit
  | "TRUE" -> value_type_only (BoolLiteral true)
  | "FALSE" -> value_type_only (BoolLiteral false)
  | "LIST" ->
    let items = get_items_list yojson_ast in
    let evaluated_items = List.map items ~f:(eval interp_data) in
    value_type_only (List evaluated_items)
  | "NOW" -> value_type_only (TimeLiteral interp_data.now)
  | "TIME" ->
    let arg = get_arg yojson_ast in
    let val_ = eval interp_data arg in
    (match val_.time with
     | Some t -> value_type_only (TimeLiteral t)
     | None -> unit)
  | "CURRENTTIME" -> value_type_only (TimeLiteral (Unix.gettimeofday ()))
  | "UPPERCASE" ->
    unary_operation ~execution_type:ElementWise ~f:string_uppercase_transform
  | "MAXIMUM" ->
    unary_operation ~execution_type:NotElementWise ~f:(aggregation_operation maximum_op)
  | "AVERAGE" ->
    unary_operation ~execution_type:NotElementWise ~f:(aggregation_operation average_op)
  | "INCREASE" ->
    unary_operation ~execution_type:NotElementWise ~f:increase_handler
  | "IF" ->
    let condition = get_condition yojson_ast in
    let thenbranch = get_thenbranch yojson_ast in
    let elsebranch = get_elsebranch yojson_ast in
    let cond_val = eval interp_data condition in
    (match cond_val.type_ with
     | BoolLiteral true -> eval interp_data thenbranch
     | BoolLiteral false -> eval interp_data elsebranch
     | _ -> unit)
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
       unit
     | _ -> unit)
  | _ -> unit

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

    (* let%expect_test "test power with minus" =
      let input = {|TRACE -2 ** 10;|} in
      input |> interpret;
      [%expect {| Line 1:  "foo"  |}]
    ;; *)
  end)
;;
