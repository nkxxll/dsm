open Base
module Binding = Binding

let parse tokens_str =
  tokens_str |> Binding.parse |> Yojson.Safe.from_string |> Yojson.Safe.pretty_to_string
;;

let%test_module "Tokenizer Tests" =
  (module struct
    let%expect_test "parse simple" =
      let input =
        {|[[ "1", "WRITE", "wRite" ],
            [ "1", "NUMTOKEN", "1" ],
            [ "1", "POWER", "**" ],
            [ "1", "NUMTOKEN", "1" ],
            [ "1", "SEMICOLON", ";" ]]|}
      in
      parse input |> Stdio.print_endline;
      [%expect {| |}]
    ;;
  end)
;;
