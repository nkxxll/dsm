open Ctypes
open Foreign

let lib = Dl.dlopen ~filename:"lemon/grammar.so" ~flags:[Dl.RTLD_NOW]

(* parses a "json" list of tokens to a json structure of a program *)
let parse = foreign ~from:lib "parse_to_string" (string @-> returning string)
