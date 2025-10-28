open Base
module Binding = Binding

let parse_to_yojson_pretty_string tokens_str =
  tokens_str |> Binding.parse |> Yojson.Safe.from_string |> Yojson.Safe.pretty_to_string
;;

let parse tokens_str =
  tokens_str |> Binding.parse |> Yojson.Safe.from_string
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
      parse_to_yojson_pretty_string input |> Stdio.print_endline;
      [%expect {|
        {
          "type": "STATEMENTBLOCK",
          "statements": [
            {
              "type": "WRITE",
              "arg": {
                "type": "POWER",
                "arg": [
                  { "type": "NUMBER", "value": "1" },
                  { "type": "NUMBER", "value": "1" }
                ]
              }
            }
          ]
        }
        |}]
    ;;
  end)
;;
