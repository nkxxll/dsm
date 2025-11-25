let () =
  let input =
    {|FOR i IN [1, 2, 3, 4, 5] DO
      IF i THEN WRITE i; ENDIF;
    ENDDO;|}
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
  ignore (Dsm.Interpreter.interpret p)
;;
