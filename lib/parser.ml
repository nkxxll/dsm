open Base
module Binding = Binding

let parse_to_yojson_pretty_string tokens_str =
  tokens_str |> Binding.parse |> Yojson.Safe.from_string |> Yojson.Safe.pretty_to_string
;;

let is_error json =
  let open Yojson.Safe.Util in
  match json |> member "error" with
  | `Null -> false
  | _ -> true
;;

let get_error_message json =
  let open Yojson.Safe.Util in
  json |> member "message" |> to_string
;;

let parse tokens_str : (Yojson.Safe.t, string) Result.t =
  let json = tokens_str |> Binding.parse |> Yojson.Safe.from_string in
  if is_error json then Error (get_error_message json) else Ok json
;;

let%test_module "Parser tests" =
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
      [%expect
        {|
        {
          "type": "STATEMENTBLOCK",
          "statements": [
            {
              "type": "WRITE",
              "arg": {
                "type": "POWER",
                "arg": [
                  { "type": "NUMTOKEN", "value": "1" },
                  { "type": "NUMTOKEN", "value": "1" }
                ]
              }
            }
          ]
        }
        |}]
    ;;

    let%expect_test "parse some other stuff" =
      let input =
        {|WRITE "hello";
        WRITE 1 + 1;
      WRITE 1 - 1;
        WRITE 1 * 1;
      |}
      in
      let output = Tokenizer.tokenize input in
      let res =
        match output with
        | Ok out -> parse_to_yojson_pretty_string out
        | Error err -> err
      in
      Stdio.print_endline res;
      [%expect
        {|
        {
          "type": "STATEMENTBLOCK",
          "statements": [
            {
              "type": "WRITE",
              "arg": { "type": "STRTOKEN", "value": " \"hello\" " }
            },
            {
              "type": "WRITE",
              "arg": {
                "type": "PLUS",
                "arg": [
                  { "type": "NUMTOKEN", "value": "1" },
                  { "type": "NUMTOKEN", "value": "1" }
                ]
              }
            },
            {
              "type": "WRITE",
              "arg": {
                "type": "MINUS",
                "arg": [
                  { "type": "NUMTOKEN", "value": "1" },
                  { "type": "NUMTOKEN", "value": "1" }
                ]
              }
            },
            {
              "type": "WRITE",
              "arg": {
                "type": "TIMES",
                "arg": [
                  { "type": "NUMTOKEN", "value": "1" },
                  { "type": "NUMTOKEN", "value": "1" }
                ]
              }
            }
          ]
        }
        |}]
    ;;

    let%expect_test "parse null" =
      let input = {|WRITE null;|} in
      let output = Tokenizer.tokenize input in
      let res =
        match output with
        | Ok out -> parse_to_yojson_pretty_string out
        | Error err -> err
      in
      Stdio.print_endline res;
      [%expect
        {|
        {
          "type": "STATEMENTBLOCK",
          "statements": [ { "type": "WRITE", "arg": { "type": "NULL" } } ]
        }
        |}]
    ;;

    let%expect_test "parse booleans" =
      let input =
        {|WRITE true;
        WRITE false;|}
      in
      let output = Tokenizer.tokenize input in
      let res =
        match output with
        | Ok out -> parse_to_yojson_pretty_string out
        | Error err -> err
      in
      Stdio.print_endline res;
      [%expect
        {|
        {
          "type": "STATEMENTBLOCK",
          "statements": [
            { "type": "WRITE", "arg": { "type": "TRUE" } },
            { "type": "WRITE", "arg": { "type": "FALSE" } }
          ]
        }
        |}]
    ;;

    let%expect_test "parse lists" =
      let input =
        {|WRITE [1, 2, 3];
        WRITE ["a", "b"];
        Write [];|}
      in
      let output = Tokenizer.tokenize input in
      let res =
        match output with
        | Ok out -> parse_to_yojson_pretty_string out
        | Error err -> err
      in
      Stdio.print_endline res;
      [%expect
        {|
        {
          "type": "STATEMENTBLOCK",
          "statements": [
            {
              "type": "WRITE",
              "arg": {
                "type": "LIST",
                "items": [
                  { "type": "NUMTOKEN", "value": "1" },
                  { "type": "NUMTOKEN", "value": "2" },
                  { "type": "NUMTOKEN", "value": "3" }
                ]
              }
            },
            {
              "type": "WRITE",
              "arg": {
                "type": "LIST",
                "items": [
                  { "type": "STRTOKEN", "value": " \"a\" " },
                  { "type": "STRTOKEN", "value": " \"b\" " }
                ]
              }
            },
            { "type": "WRITE", "arg": { "type": "EMPTYLIST" } }
          ]
        }
        |}]
    ;;

    let%expect_test "parse trace" =
      let input = {|TRACE "foo";|} in
      let output = Tokenizer.tokenize input in
      let res =
        match output with
        | Ok out -> parse_to_yojson_pretty_string out
        | Error err -> err
      in
      Stdio.print_endline res;
      [%expect
        {|
        {
          "type": "STATEMENTBLOCK",
          "statements": [
            {
              "type": "TRACE",
              "line": "1",
              "arg": { "type": "STRTOKEN", "value": " \"foo\" " }
            }
          ]
        }
        |}]
    ;;

    let%expect_test "with tokenize keyword capitalization" =
      let input =
        {|trace "Hallo" where it is not number;
      trace [10,20,50,100,70,40,55] where it / 2 is within 30 to 60;|}
      in
      let output = Tokenizer.tokenize input in
      let res =
        match output with
        | Ok out -> parse_to_yojson_pretty_string out
        | Error err -> err
      in
      Stdio.print_endline res;
      [%expect {|
        {
          "type": "STATEMENTBLOCK",
          "statements": [
            {
              "type": "TRACE",
              "line": "1",
              "arg": {
                "type": "WHERE",
                "arg": [
                  { "type": "STRTOKEN", "value": " \"Hallo\" " },
                  {
                    "type": "ISNOTNUMBER",
                    "arg": { "type": "VARIABLE", "name": "it", "line": "1" }
                  }
                ]
              }
            },
            {
              "type": "TRACE",
              "line": "2",
              "arg": {
                "type": "WHERE",
                "arg": [
                  {
                    "type": "LIST",
                    "items": [
                      { "type": "NUMTOKEN", "value": "10" },
                      { "type": "NUMTOKEN", "value": "20" },
                      { "type": "NUMTOKEN", "value": "50" },
                      { "type": "NUMTOKEN", "value": "100" },
                      { "type": "NUMTOKEN", "value": "70" },
                      { "type": "NUMTOKEN", "value": "40" },
                      { "type": "NUMTOKEN", "value": "55" }
                    ]
                  },
                  {
                    "type": "ISWITHIN",
                    "arg": [
                      {
                        "type": "DIVIDE",
                        "arg": [
                          { "type": "VARIABLE", "name": "it", "line": "2" },
                          { "type": "NUMTOKEN", "value": "2" }
                        ]
                      },
                      { "type": "NUMTOKEN", "value": "30" },
                      { "type": "NUMTOKEN", "value": "60" }
                    ]
                  }
                ]
              }
            }
          ]
        }
        |}]
    ;;
  end)
;;
