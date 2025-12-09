let () =
  if Array.length Sys.argv < 2
  then (
    Stdio.print_endline "Usage: dsm <filename>";
    exit 1);
  let filename = Sys.argv.(1) in
  let input = Stdio.In_channel.read_all filename in
  Stdio.print_endline "=== INPUT ===";
  Stdio.print_endline input;
  Stdio.print_endline "";
  let res = Dsm.Tokenizer.tokenize input in
  Stdio.print_endline "=== TOKENIZER OUTPUT ===";
  (match res with
   | Ok r -> Stdio.print_endline r
   | Error err -> Stdio.printf "Tokenizer error: %s\n" err);
  Stdio.print_endline "";
  let p =
    match res with
    | Ok r ->
      let parsed = Dsm.Parser.parse r in
      (match parsed with
       | Ok _ast ->
         Stdio.print_endline "=== PARSER OUTPUT ===";
         Stdio.print_endline (Dsm.Parser.parse_to_yojson_pretty_string r);
         Stdio.print_endline ""
       | Error err ->
         Stdio.printf "Parser error: %s\n" err;
         Stdio.print_endline "");
      parsed
    | Error err ->
      Stdio.printf "Tokenizer error: %s\n" err;
      Error err
  in
  match p with
  | Ok parsed ->
    Stdio.print_endline "=== INTERPRETER OUTPUT ===";
    ignore (Dsm.Interpreter.interpret_parsed parsed)
  | Error error -> Stdio.printf "Error: %s\n" error
;;
