let () =
  let input =
    {|sum_num := 0;
              FOR i IN [10, 20, 30] DO
                sum_num := sum_num + i;
              ENDDO;
              WRITE sum_num;|}
  in
  let res = Dsm.Tokenizer.tokenize input in
  let p =
    match res with
    | Ok r ->
      Dsm.Parser.parse_to_yojson_pretty_string r |> Stdio.print_endline;
      Dsm.Parser.parse r
    | Error err ->
      Stdio.print_endline err;
      failwith "nonnon"
  in
  match p with
  | Ok parsed -> ignore (Dsm.Interpreter.interpret_parsed parsed)
  | Error error -> Stdio.print_endline error
;;
