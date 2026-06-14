#include "tokenizer.h"
#include <stdio.h>

int main(int argc, char *argv[]) {
  if (argc < 2) {
    fprintf(stderr, "Usage: %s <input_file>\n", argv[0]);
    return 1;
  }

  const char *input_file = argv[1];
  Tokenizer tokenizer;
  FILE *file = fopen(input_file, "r");
  if (!file) {
    fprintf(stderr, "Could not open file: %s\n", input_file);
    return 1;
  }
  if (!init_tokenizer(&tokenizer, input_file, file)) {
    fprintf(stderr, "Failed to initialize tokenizer with file: %s\n",
            input_file);
    return 1;
  };

  Token token;
  while ((token = get_next_token(&tokenizer)).type != TOKEN_EOF) {
    printf("Token: ");
    tokenizer_print_token(&tokenizer, token);
  }

  return 0;
}
