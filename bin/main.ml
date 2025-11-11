let () =
  let input =
    {|x := 10;
    WRITE x;
    |}
  in
  let res = Dsm.Tokenizer.tokenize input in
  match res with
  | Ok r -> Dsm.Parser.parse_to_yojson_pretty_string r |> Stdio.print_endline
  | Error err -> Stdio.print_endline err
;;
