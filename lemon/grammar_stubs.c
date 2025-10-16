#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/custom.h>
#include <caml/fail.h>
#include "grammar.h"

extern char* parse_to_string(char* input);

CAMLprim value ocaml_parse_to_string(value v_input) {
  CAMLparam1(v_input);
  const char *input = String_val(v_input);
  char *result = parse_to_string((char*)input);
  value v_res = caml_copy_string(result);
  free(result);
  CAMLreturn(v_res);
}
