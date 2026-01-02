open Core

type operation =
  | PLUS
  | MINUS
  | TIMES
  | DIVIDE

type value =
  { type_ : value_union
  ; time : float option
  }

and value_union =
  | List of value list
  | NumberLiteral of float
  | StringLiteral of string
  | BoolLiteral of bool
  | TimeLiteral of float
  | Unit

type value_type =
  | ListType
  | NumberType
  | StringType
  | BoolType
  | UnitType
  | TimeType

let value_type_eq this other =
  match this, other with
  | ListType, ListType -> true
  | NumberType, NumberType -> true
  | StringType, StringType -> true
  | BoolType, BoolType -> true
  | UnitType, UnitType -> true
  | TimeType, TimeType -> true
  | _, _ -> false
;;

let type_of value =
  match value.type_ with
  | NumberLiteral _ -> NumberType
  | StringLiteral _ -> StringType
  | BoolLiteral _ -> BoolType
  | TimeLiteral _ -> TimeType
  | List _ -> ListType
  | Unit -> UnitType
;;

let unit = { type_ = Unit; time = None }
let value_type_only type_ = { type_; time = None }
let value_time_only time = { type_ = Unit; time }
let value_full type_ time = { type_; time }

module InterpreterData = struct
  type t =
    { now : float
    ; env : (string, value) Hashtbl.t
    }

  let create () =
    { now = Caml_unix.gettimeofday () *. 1000.0; env = Hashtbl.create (module String) }
  ;;
end

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

let is_type value_type value =
  if value_type_eq (type_of value) value_type
  then value_type_only (BoolLiteral true)
  else value_type_only (BoolLiteral false)
;;

let is_not_type value_type value =
  if value_type_eq (type_of value) value_type
  then value_type_only (BoolLiteral false)
  else value_type_only (BoolLiteral true)
;;

(* String concatenation operation with mixed type support *)
let concatenation_operation left right : value =
  match left.type_, right.type_ with
  | StringLiteral l, StringLiteral r -> value_type_only (StringLiteral (l ^ r))
  | StringLiteral l, NumberLiteral r ->
    value_type_only (StringLiteral (l ^ Float.to_string r))
  | NumberLiteral l, StringLiteral r ->
    value_type_only (StringLiteral (Float.to_string l ^ r))
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

let minimum_op numbers : float =
  match List.min_elt numbers ~compare:Float.compare with
  | Some min_val -> min_val
  | None -> 0.0
;;

let average_op numbers : float =
  match numbers with
  | [] -> 0.0
  | lst ->
    let sum = List.fold lst ~init:0.0 ~f:( +. ) in
    sum /. Float.of_int (List.length lst)
;;

(* COUNT handler - returns the count of items in a list *)
let count_handler item : value =
  match item.type_ with
  | List items -> value_type_only (NumberLiteral (Float.of_int (List.length items)))
  | _ -> unit
;;

(* ANY handler - returns true if any item in list is true *)
let any_handler item : value =
  match item.type_ with
  | List items ->
    let has_true =
      List.exists items ~f:(fun v ->
        match v.type_ with
        | BoolLiteral true -> true
        | _ -> false)
    in
    value_type_only (BoolLiteral has_true)
  | BoolLiteral b -> value_type_only (BoolLiteral b)
  | _ -> unit
;;

(* FIRST handler - returns the first item in a list *)
let first_handler item : value =
  match item.type_ with
  | List items ->
    (match items with
     | first :: _ -> first
     | [] -> unit)
  | _ -> item
;;

(* LATEST handler - returns the value with the latest primary time in a list *)
let latest_handler item : value =
  match item.type_ with
  | List items ->
    (* Filter items that have a primary time *)
    let items_with_time =
      List.filter_map items ~f:(fun v ->
        match v.time with
        | Some t -> Some (v, t)
        | None -> None)
    in
    (match items_with_time with
     | [] -> unit
     | items_with_time ->
       (* Find the item with the maximum time *)
       let latest, _ =
         List.max_elt items_with_time ~compare:(fun (_, t1) (_, t2) ->
           Float.compare t1 t2)
         |> Option.value_exn
       in
       latest)
  | _ -> item
;;

(* EARLIEST handler - returns the value with the earliest primary time in a list *)
let earliest_handler item : value =
  match item.type_ with
  | List items ->
    (* Filter items that have a primary time *)
    let items_with_time =
      List.filter_map items ~f:(fun v ->
        match v.time with
        | Some t -> Some (v, t)
        | None -> None)
    in
    (match items_with_time with
     | [] -> unit
     | items_with_time ->
       (* Find the item with the minimum time *)
       let earliest, _ =
         List.min_elt items_with_time ~compare:(fun (_, t1) (_, t2) ->
           Float.compare t1 t2)
         |> Option.value_exn
       in
       earliest)
  | _ -> item
;;

let unary_math_op op value =
  match value.type_ with
  | NumberLiteral n -> value_full (NumberLiteral (op n)) value.time
  | _ -> unit
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

  (* INTERVAL handler - returns list of time differences between successive items *)
  let interval_handler item : value =
  match item.type_ with
  | List items ->
   let times =
     List.filter_map items ~f:(fun v ->
       match v.time with
       | Some t -> Some t
       | None -> None)
   in
   (match times with
    | [] | [ _ ] -> value_type_only (List [])
    | lst ->
      let intervals =
        List.init
          (List.length lst - 1)
          ~f:(fun i ->
            let curr = List.nth_exn lst (i + 1) in
            let prev = List.nth_exn lst i in
            (* Convert milliseconds to days for readability *)
            let diff_ms = curr -. prev in
            let diff_days = diff_ms /. (1000.0 *. 60.0 *. 60.0 *. 24.0) in
            value_type_only (NumberLiteral diff_days))
      in
      value_type_only (List intervals))
  | _ -> unit
  ;;

  (* Duration operators - convert numbers to durations *)
  (* YEAR: converts number to months duration (1 year = 12 months) *)
  let duration_year_handler item : value =
  match item.type_ with
  | NumberLiteral n -> value_type_only (NumberLiteral (n *. 12.0))
  | List items ->
    let converted = List.map items ~f:(fun v ->
      match v.type_ with
      | NumberLiteral n -> value_type_only (NumberLiteral (n *. 12.0))
      | _ -> v)
    in
    value_type_only (List converted)
  | _ -> unit
  ;;

  (* MONTH: keeps as months duration *)
  let duration_month_handler item : value =
  match item.type_ with
  | NumberLiteral n -> value_type_only (NumberLiteral n)
  | List items ->
    let converted = List.map items ~f:(fun v ->
      match v.type_ with
      | NumberLiteral n -> value_type_only (NumberLiteral n)
      | _ -> v)
    in
    value_type_only (List converted)
  | _ -> unit
  ;;

  (* WEEK: converts to seconds duration (1 week = 604800 seconds) *)
  let duration_week_handler item : value =
  match item.type_ with
  | NumberLiteral n -> value_type_only (NumberLiteral (n *. 604800.0))
  | List items ->
    let converted = List.map items ~f:(fun v ->
      match v.type_ with
      | NumberLiteral n -> value_type_only (NumberLiteral (n *. 604800.0))
      | _ -> v)
    in
    value_type_only (List converted)
  | _ -> unit
  ;;

  (* DAY: converts to seconds duration (1 day = 86400 seconds) *)
  let duration_day_handler item : value =
  match item.type_ with
  | NumberLiteral n -> value_type_only (NumberLiteral (n *. 86400.0))
  | List items ->
    let converted = List.map items ~f:(fun v ->
      match v.type_ with
      | NumberLiteral n -> value_type_only (NumberLiteral (n *. 86400.0))
      | _ -> v)
    in
    value_type_only (List converted)
  | _ -> unit
  ;;

  (* HOURS: converts to seconds duration (1 hour = 3600 seconds) *)
  let duration_hours_handler item : value =
  match item.type_ with
  | NumberLiteral n -> value_type_only (NumberLiteral (n *. 3600.0))
  | List items ->
    let converted = List.map items ~f:(fun v ->
      match v.type_ with
      | NumberLiteral n -> value_type_only (NumberLiteral (n *. 3600.0))
      | _ -> v)
    in
    value_type_only (List converted)
  | _ -> unit
  ;;

  (* MINUTES: converts to seconds duration (1 minute = 60 seconds) *)
  let duration_minutes_handler item : value =
  match item.type_ with
  | NumberLiteral n -> value_type_only (NumberLiteral (n *. 60.0))
  | List items ->
    let converted = List.map items ~f:(fun v ->
      match v.type_ with
      | NumberLiteral n -> value_type_only (NumberLiteral (n *. 60.0))
      | _ -> v)
    in
    value_type_only (List converted)
  | _ -> unit
  ;;

  (* SECONDS: returns as seconds duration *)
  let duration_seconds_handler item : value =
  match item.type_ with
  | NumberLiteral n -> value_type_only (NumberLiteral n)
  | List items ->
    let converted = List.map items ~f:(fun v ->
      match v.type_ with
      | NumberLiteral n -> value_type_only (NumberLiteral n)
      | _ -> v)
    in
    value_type_only (List converted)
  | _ -> unit
  ;;

  let range start end_range =
  if start > end_range
  then failwith "start has to be smaller than end_range"
  else List.init (end_range - start + 1) ~f:(fun i -> start + i)
  ;;

  let range_operator first second =
  match first, second with
  | { type_ = NumberLiteral first_number; _ }, { type_ = NumberLiteral second_number; _ }
    ->
    value_full
      (List
         (List.map
            (range (Float.to_int first_number) (Float.to_int second_number))
            ~f:(fun item -> value_type_only (NumberLiteral (Int.to_float item)))))
      None
  | _, _ -> unit
;;

let is_within first second third =
  let ( <= ) = Float.( <= ) in
  let ( >= ) = Float.( >= ) in
  match first, second, third with
  | ( { type_ = NumberLiteral first; _ }
    , { type_ = NumberLiteral second; _ }
    , { type_ = NumberLiteral third; _ } )
    when first >= second && first <= third -> value_type_only (BoolLiteral true)
  | ( { type_ = NumberLiteral _; _ }
    , { type_ = NumberLiteral _; _ }
    , { type_ = NumberLiteral _; _ } ) -> value_type_only (BoolLiteral false)
  | _, _, _ -> unit
;;

let is_not_within first second third =
  match is_within first second third with
  | { type_ = BoolLiteral true_or_false; time = bool_time } ->
    value_full (BoolLiteral (not true_or_false)) bool_time
  | _ -> unit
;;

(* WHERE operator: filters left argument based on right argument boolean values *)

let less_than first second =
  let ( < ) = Float.( < ) in
  match first, second with
  | { type_ = NumberLiteral first; _ }, { type_ = NumberLiteral second; _ } ->
    value_type_only (BoolLiteral (first < second))
  | _, _ -> unit
;;

let greater_than first second =
  let ( > ) = Float.( > ) in
  match first, second with
  | { type_ = NumberLiteral first; _ }, { type_ = NumberLiteral second; _ } ->
    value_type_only (BoolLiteral (first > second))
  | _, _ -> unit
;;

(* IS BEFORE operator - checks if left time is strictly before right time *)
let is_before first second =
  let ( < ) = Float.( < ) in
  match first.type_, second.type_ with
  | TimeLiteral first_time, TimeLiteral second_time ->
    value_type_only (BoolLiteral (first_time < second_time))
  | _, _ -> unit
;;

let is_not_before first second =
  let ( < ) = Float.( < ) in
  match first.type_, second.type_ with
  | TimeLiteral first_time, TimeLiteral second_time ->
    value_type_only (BoolLiteral (not (first_time < second_time)))
  | _, _ -> unit
;;

(* OCCUR operators - compare primary time of left argument with right argument *)
let occur_equal first second =
  (* Use primary time of left argument *)
  match first.time, second.type_ with
  | Some left_time, TimeLiteral right_time ->
    value_type_only (BoolLiteral (Float.equal left_time right_time))
  | Some left_time, NumberLiteral right_time ->
    value_type_only (BoolLiteral (Float.equal left_time right_time))
  | _, _ -> unit
;;

let occur_before first second =
  let ( < ) = Float.( < ) in
  match first.time, second.type_ with
  | Some left_time, TimeLiteral right_time ->
    value_type_only (BoolLiteral (left_time < right_time))
  | Some left_time, NumberLiteral right_time ->
    value_type_only (BoolLiteral (left_time < right_time))
  | _, _ -> unit
;;

let occur_after first second =
  let ( > ) = Float.( > ) in
  match first.time, second.type_ with
  | Some left_time, TimeLiteral right_time ->
    value_type_only (BoolLiteral (left_time > right_time))
  | Some left_time, NumberLiteral right_time ->
    value_type_only (BoolLiteral (left_time > right_time))
  | _, _ -> unit
;;

let occur_within first second third =
  let ( <= ) = Float.( <= ) in
  let ( >= ) = Float.( >= ) in
  match first.time, second.type_, third.type_ with
  | Some first_time, TimeLiteral second_time, TimeLiteral third_time ->
    if first_time >= second_time && first_time <= third_time
    then value_type_only (BoolLiteral true)
    else value_type_only (BoolLiteral false)
  | Some first_time, NumberLiteral second_time, NumberLiteral third_time ->
    if first_time >= second_time && first_time <= third_time
    then value_type_only (BoolLiteral true)
    else value_type_only (BoolLiteral false)
  | Some first_time, TimeLiteral second_time, NumberLiteral third_time ->
    if first_time >= second_time && first_time <= third_time
    then value_type_only (BoolLiteral true)
    else value_type_only (BoolLiteral false)
  | Some first_time, NumberLiteral second_time, TimeLiteral third_time ->
    if first_time >= second_time && first_time <= third_time
    then value_type_only (BoolLiteral true)
    else value_type_only (BoolLiteral false)
  | _, _, _ -> unit
;;

let occur_same_day_as first second =
  (* Extract day from timestamp (milliseconds since epoch) *)
  (* Day boundary is 86400000 milliseconds (24 hours) *)
  let day_ms = 86400000.0 in
  match first.time, second.time with
  | Some first_time, Some second_time ->
    let first_day = Float.to_int (first_time /. day_ms) in
    let second_day = Float.to_int (second_time /. day_ms) in
    value_type_only (BoolLiteral (Int.equal first_day second_day))
  | _, _ -> unit
;;

let read_csv first =
  match first.type_ with
  | StringLiteral file ->
    let list : value list =
      In_channel.read_lines file
      |> List.map ~f:(String.split ~on:',')
      |> List.map ~f:(fun line ->
        let value = List.nth_exn line 0 in
        let time = List.nth_exn line 1 in
        NumberLiteral (Float.of_string value), Helper.time_string_to_float time)
      |> List.fold ~init:[] ~f:(fun acc (value, time) ->
        value_full value (Some time) :: acc)
    in
    value_type_only (List (List.rev list))
  | _ -> unit
;;

let rec eval (interp_data : InterpreterData.t) yojson_ast : value =
  (* Binary operation dispatcher *)
  let where_operation () : value =
    let args = get_arg_list yojson_ast in
    let left = eval interp_data (List.nth_exn args 0) in
    Hashtbl.set interp_data.env ~key:"it" ~data:left;
    Hashtbl.set interp_data.env ~key:"they" ~data:left;
    let right = eval interp_data (List.nth_exn args 1) in
    let res =
      match left.type_, right.type_ with
      (* Both are lists - filter left based on right *)
      | List left_list, List right_list ->
        if Int.equal (List.length left_list) (List.length right_list)
        then (
          let filtered =
            List.zip_exn left_list right_list
            |> List.filter_map ~f:(fun (item, cond) ->
              match cond.type_ with
              | BoolLiteral true -> Some item
              | _ -> None)
          in
          value_full (List filtered) left.time)
        else unit
      (* Left is a list, right is a single item - keep all if true, empty if not *)
      | List left_list, _ ->
        (match right.type_ with
         | BoolLiteral true -> value_full (List left_list) left.time
         | _ -> value_full (List []) left.time)
      (* Left is a single item, right is a list - replicate left for each true in right *)
      | _, List right_list ->
        let filtered =
          List.filter_map right_list ~f:(fun cond ->
            match cond.type_ with
            | BoolLiteral true -> Some left
            | _ -> None)
        in
        value_full (List filtered) left.time
      (* Both are scalars - return left if right is true, empty list if not *)
      | _, _ ->
        (match right.type_ with
         | BoolLiteral true -> left
         | _ -> value_full (List []) left.time)
    in
    Hashtbl.remove interp_data.env "it";
    Hashtbl.remove interp_data.env "they";
    res
  in
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
  let ternary_operation ~execution_type ~(f : value -> value -> value -> value) =
    let args = get_arg_list yojson_ast in
    let first = eval interp_data (List.nth_exn args 0) in
    let second = eval interp_data (List.nth_exn args 1) in
    let third = eval interp_data (List.nth_exn args 2) in
    let get_list_length v =
      match v.type_ with
      | List lst -> Some (List.length lst)
      | _ -> None
    in
    let max_len =
      [ get_list_length first; get_list_length second; get_list_length third ]
      |> List.filter_map ~f:Fn.id
      |> List.max_elt ~compare:Int.compare
    in
    match execution_type with
    | ElementWise ->
      (match max_len with
       | None -> f first second third
       | Some n ->
         let expand_to_list v n =
           match v.type_ with
           | List lst when List.length lst = n ->
             Some lst (* if its a list with the max length then everything is fine *)
           | List _ ->
             None
             (* if its not a list with the max length then it is a list with a wrong length we have to return null *)
           | _ -> Some (List.init n ~f:(fun _ -> v))
         in
         let first_list = expand_to_list first n in
         let second_list = expand_to_list second n in
         let third_list = expand_to_list third n in
         (match first_list, second_list, third_list with
          | Some first_list, Some second_list, Some third_list ->
            let combined =
              List.zip_exn (List.zip_exn first_list second_list) third_list
            in
            let new_list = List.map combined ~f:(fun ((a, b), c) -> f a b c) in
            let time =
              match first.time, second.time, third.time with
              | Some t, _, _ -> Some t
              | _, Some t, _ -> Some t
              | _, _, Some t -> Some t
              | _, _, _ -> None
            in
            { type_ = List new_list; time }
          | _, _, _ -> unit))
    | NotElementWise -> f first second third
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
  | "RANGE" -> binary_operation ~execution_type:NotElementWise ~f:range_operator
  | "READ" -> unary_operation ~execution_type:NotElementWise ~f:read_csv
  | "TRACE" ->
    let line = get_line yojson_ast in
    let arg = get_arg yojson_ast in
    let val_ = eval interp_data arg in
    Stdio.printf "Line %s: " line;
    write_value val_;
    unit
  | "LT" -> binary_operation ~execution_type:ElementWise ~f:less_than
  | "ISGREATERT" -> binary_operation ~execution_type:ElementWise ~f:greater_than
  | "OCCUREQUAL" -> binary_operation ~execution_type:ElementWise ~f:occur_equal
  | "OCCURBEFORE" -> binary_operation ~execution_type:ElementWise ~f:occur_before
  | "OCCURAFTER" -> binary_operation ~execution_type:ElementWise ~f:occur_after
  | "OCCURWITHIN" -> ternary_operation ~execution_type:ElementWise ~f:occur_within
  | "OCCURSAMEDAYAS" -> binary_operation ~execution_type:ElementWise ~f:occur_same_day_as
  | "WHERE" -> where_operation ()
  | "ISNUMBER" -> unary_operation ~execution_type:ElementWise ~f:(is_type NumberType)
  | "ISNOTNUMBER" ->
    unary_operation ~execution_type:ElementWise ~f:(is_not_type NumberType)
  | "ISLIST" -> unary_operation ~execution_type:NotElementWise ~f:(is_type ListType)
  | "ISNOTLIST" ->
    unary_operation ~execution_type:NotElementWise ~f:(is_not_type ListType)
  | "ISWITHIN" -> ternary_operation ~execution_type:ElementWise ~f:is_within
  | "ISNOTWITHIN" -> ternary_operation ~execution_type:ElementWise ~f:is_not_within
  | "ISBEFORE" -> binary_operation ~execution_type:ElementWise ~f:is_before
  | "ISNOTBEFORE" -> binary_operation ~execution_type:ElementWise ~f:is_not_before
  | "ASSIGN" ->
    let ident = get_ident yojson_ast in
    let arg = get_arg yojson_ast in
    let val_ = eval interp_data arg in
    Hashtbl.set interp_data.env ~key:ident ~data:val_;
    unit
  | "SQRT" -> unary_operation ~execution_type:ElementWise ~f:(unary_math_op Float.sqrt)
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
    let time_float = Helper.time_string_to_float time_str in
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
  | "POWER" ->
    binary_operation ~execution_type:ElementWise ~f:(arithmetic_operation ( **. ))
  | "AMPERSAND" -> binary_operation ~execution_type:ElementWise ~f:concatenation_operation
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
     | Some t -> value_full (TimeLiteral t) (Some t)
     | None -> unit)
  | "CURRENTTIME" -> value_type_only (TimeLiteral (Caml_unix.gettimeofday ()))
  | "UPPERCASE" ->
    unary_operation ~execution_type:ElementWise ~f:string_uppercase_transform
  | "MAXIMUM" ->
    unary_operation ~execution_type:NotElementWise ~f:(aggregation_operation maximum_op)
  | "MINIMUM" ->
    unary_operation ~execution_type:NotElementWise ~f:(aggregation_operation minimum_op)
  | "AVERAGE" ->
    unary_operation ~execution_type:NotElementWise ~f:(aggregation_operation average_op)
  | "COUNT" -> unary_operation ~execution_type:NotElementWise ~f:count_handler
  | "ANY" -> unary_operation ~execution_type:NotElementWise ~f:any_handler
  | "FIRST" -> unary_operation ~execution_type:NotElementWise ~f:first_handler
  | "LATEST" -> unary_operation ~execution_type:NotElementWise ~f:latest_handler
  | "EARLIEST" -> unary_operation ~execution_type:NotElementWise ~f:earliest_handler
  | "INCREASE" -> unary_operation ~execution_type:NotElementWise ~f:increase_handler
  | "INTERVAL" -> unary_operation ~execution_type:NotElementWise ~f:interval_handler
  | "YEAR" -> unary_operation ~execution_type:ElementWise ~f:duration_year_handler
  | "MONTH" -> unary_operation ~execution_type:ElementWise ~f:duration_month_handler
  | "WEEK" -> unary_operation ~execution_type:ElementWise ~f:duration_week_handler
  | "DAY" -> unary_operation ~execution_type:ElementWise ~f:duration_day_handler
  | "HOURS" -> unary_operation ~execution_type:ElementWise ~f:duration_hours_handler
  | "MINUTES" -> unary_operation ~execution_type:ElementWise ~f:duration_minutes_handler
  | "SECONDS" -> unary_operation ~execution_type:ElementWise ~f:duration_seconds_handler
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
        | { type_ = TimeLiteral t; _ } -> Helper.timestamp_to_iso_string t)
      |> String.concat ~sep:", "
    in
    Stdio.print_endline ("[" ^ formatted ^ "]");
    ()
  | TimeLiteral t ->
    Stdio.print_endline Helper.(timestamp_to_iso_string t);
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

    let%expect_test "list binary operator like plus" =
      let input = {|TRACE [1, 2, 3, 4] + 5;|} in
      input |> interpret;
      [%expect {| Line 1: [6., 7., 8., 9.] |}]
    ;;

    let%expect_test "test power with minus" =
      let input = {|TRACE -2 ** 10;|} in
      input |> interpret;
      [%expect {| Line 1: -1024. |}]
    ;;

    let%expect_test "test first small part of the studienleistung" =
      let input =
        {|x := ["Hallo Welt", null, 4711, 2020-01-01T12:30:00, false, now];
      trace x;
      trace x is number;
      trace x is list;|}
      in
      input |> interpret;
      [%expect.output] |> censor_digits |> Stdio.print_endline;
      [%expect
        {|
        Line X: [ "Hallo Welt" , null, XXXX., XXXX-XX-XXTXX:XX:XXZ, false, XXXX-XX-XXTXX:XX:XXZ]
        Line X: [false, false, true, false, false, false]
        Line X: true
        |}]
    ;;

    let%expect_test "test second small part of the studienleistung" =
      let input =
        {|trace 1 + 2 * 4 / 5 - -3 + 4 ** 3 ** 2;
        trace -2 ** 10;|}
      in
      input |> interpret;
      [%expect
        {|
        Line 1: 262149.6
        Line 2: -1024.
        |}]
    ;;

    let%expect_test "test third small part of the studienleistung" =
      let input =
        {|y := [100,200,150];
        trace [maximum y, average y, increase y];
        trace uppercase ["Hallo", "Welt", 4711];
        trace sqrt y;|}
      in
      input |> interpret;
      [%expect
        {|
        Line 2: [200., 150., [...]]
        Line 3: [ "HALLO" ,  "WELT" , 4711.]
        Line 4: [10., 14.142135623730951, 12.24744871391589]
        |}]
    ;;

    let%expect_test "test minimum operator" =
      let input =
        {|y := [100, 200, 150];
        trace minimum y;|}
      in
      input |> interpret;
      [%expect
        {|
        Line 2: 100.
        |}]
    ;;

    let%expect_test "test fourth small part of the studienleistung" =
      let input =
        {|x := 1 ... 7;
        trace x;
        trace x < 5;
        trace x is not within (x - 1) to 5;|}
      in
      input |> interpret;
      [%expect
        {|
        Line 2: [1., 2., 3., 4., 5., 6., 7.]
        Line 3: [true, true, true, true, false, false, false]
        Line 4: [false, false, false, false, false, true, true]
        |}]
    ;;

    let%expect_test "test five small part of the studienleistung" =
      let input =
        {|x := 4711;
        time x := 1999-09-19;
        y := x;
        time y := 2022-12-22;
        trace time of x;
        trace time y;
        trace time of time of y;|}
      in
      input |> interpret;
      [%expect
        {|
        Line 5: 1999-09-19T00:00:00Z
        Line 6: 2022-12-22T00:00:00Z
        Line 7: 2022-12-22T00:00:00Z
        |}]
    ;;

    let%expect_test "test where with matching list lengths" =
      let input = {|trace [10,20,30,40] where [true,false,true,false];|} in
      input |> interpret;
      [%expect {| Line 1: [10., 30.] |}]
    ;;

    let%expect_test "test where with left list and single boolean true" =
      let input = {|trace [10,20,30] where true;|} in
      input |> interpret;
      [%expect {| Line 1: [10., 20., 30.] |}]
    ;;

    let%expect_test "test where with left list and single boolean false" =
      let input = {|trace [10,20,30] where false;|} in
      input |> interpret;
      [%expect {| Line 1: [] |}]
    ;;

    let%expect_test "test where with single item left and list of booleans" =
      let input = {|trace 1 where [true,false,true];|} in
      input |> interpret;
      [%expect {| Line 1: [1., 1.] |}]
    ;;

    let%expect_test "test where with both scalars true" =
      let input = {|trace 1 where true;|} in
      input |> interpret;
      [%expect {| Line 1: 1. |}]
    ;;

    let%expect_test "test where with both scalars false" =
      let input = {|trace 1 where false;|} in
      input |> interpret;
      [%expect {| Line 1: [] |}]
    ;;

    let%expect_test "test where filters non-true values" =
      let input = {|trace [1,2,3,4,5] where [true,true,false,null,3];|} in
      input |> interpret;
      [%expect {| Line 1: [1., 2.] |}]
    ;;

    let%expect_test "test where with the studienleistungs test" =
      let input =
        {|trace "Hallo" where it is not number;
      trace [10,20,50,100,70,40,55] where it / 2 is within 30 to 60;|}
      in
      input |> interpret;
      [%expect
        {|
        Line 1:  "Hallo"
        Line 2: [100., 70.]
        |}]
    ;;

    let%expect_test "test is before operator - strictly before" =
      let input = {|trace 1990-03-07T00:00:00 is before 1990-03-08T00:00:00;|} in
      input |> interpret;
      [%expect {| Line 1: true |}]
    ;;

    let%expect_test "test is before operator - not before (later date)" =
      let input = {|trace 1990-03-08T00:00:00 is before 1990-03-07T00:00:00;|} in
      input |> interpret;
      [%expect {| Line 1: false |}]
    ;;

    let%expect_test "test is before operator - not before (same date)" =
      let input = {|trace 1990-03-08T00:00:00 is before 1990-03-08T00:00:00;|} in
      input |> interpret;
      [%expect {| Line 1: false |}]
    ;;

    let%expect_test "test is not before operator" =
      let input = {|trace 1990-03-08T00:00:00 is not before 1990-03-07T00:00:00;|} in
      input |> interpret;
      [%expect {| Line 1: true |}]
    ;;

    let%expect_test "test is not before operator - same date" =
      let input = {|trace 1990-03-08T00:00:00 is not before 1990-03-08T00:00:00;|} in
      input |> interpret;
      [%expect {| Line 1: true |}]
    ;;

    let%expect_test "test is not before operator - earlier date" =
      let input = {|trace 1990-03-07T00:00:00 is not before 1990-03-08T00:00:00;|} in
      input |> interpret;
      [%expect {| Line 1: false |}]
    ;;
  end)
;;
