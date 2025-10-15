let () =
      let input =
        {|[[ "1", "WRITE", "wRite" ],
            [ "1", "NUMTOKEN", "1" ],
            [ "1", "POWER", "**" ],
            [ "1", "NUMTOKEN", "1" ],
            [ "1", "SEMICOLON", ";" ]]|}
      in
      Dsm.Parser.parse input |> Stdio.print_endline;
