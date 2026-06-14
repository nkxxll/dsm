#include "tokenizer.h"
#include <stdio.h>
#include <stdlib.h>

int init_tokenizer(Tokenizer *tokenizer, const char *input_file, FILE *file) {
  // Move to end of file
  fseek(file, 0, SEEK_END);

  // Get file size
  long size = ftell(file);

  // Go back to beginning
  rewind(file);

  // Allocate memory for file content
  char *input = malloc(size + 1);
  if (!input) {
    fprintf(stderr, "Could not allocate memory for file content\n");
    fclose(file);
    return 0;
  }

  if (fread(input, 1, size, file) != size) {
    fprintf(stderr, "Could not read file: %s\n", input_file);
    free(input);
    fclose(file);
    return 0;
  }
  input[size] = '\0';
  tokenizer->input_file = input_file;
  tokenizer->input = input;
  tokenizer->input_len = size;
  tokenizer->pos = 0;
  tokenizer->line = 1;
  return 1;
}
Token get_next_token(Tokenizer *tokenizer) {
  char current;
start:
  current = tokenizer->input[tokenizer->pos];
  switch (current) {
  case '\0':
    return (Token){.text = tokenizer->input + tokenizer->pos,
                   .length = 0,
                   .line = tokenizer->line,
                   .column = tokenizer->column,
                   .type = TOKEN_EOF};
  case ' ':
    tokenizer->pos++;
    goto start;
  case '\n':
    tokenizer->line++;
    tokenizer->column = 0;
    tokenizer->pos++;
    goto start;
  case '*':
    tokenizer->pos++;
    return (Token){.text = tokenizer->input + tokenizer->pos - 1,
                   .length = 1,
                   .line = tokenizer->line,
                   .column = tokenizer->column,
                   .type = '*'};
  case '+':
    tokenizer->pos++;
    return (Token){.text = tokenizer->input + tokenizer->pos - 1,
                   .length = 1,
                   .line = tokenizer->line,
                   .column = tokenizer->column,
                   .type = '+'};
  case '-':
    tokenizer->pos++;
    return (Token){.text = tokenizer->input + tokenizer->pos - 1,
                   .length = 1,
                   .line = tokenizer->line,
                   .column = tokenizer->column,
                   .type = '-'};
  case '/':
    tokenizer->pos++;
    return (Token){.text = tokenizer->input + tokenizer->pos - 1,
                   .length = 1,
                   .line = tokenizer->line,
                   .column = tokenizer->column,
                   .type = '/'};
  default:
    if (current <= '9' && current >= '0') {
      return tokenizer_parse_number(tokenizer);
    }
    if ((current >= 'a' && current <= 'z') ||
        (current >= 'A' && current <= 'Z') || current == '_') {
      return tokenizer_parse_identifier(tokenizer);
    }
  }
  return (Token){.text = tokenizer->input + tokenizer->pos,
                 .length = 1,
                 .line = tokenizer->line,
                 .column = tokenizer->column,
                 .type = TOKEN_UNKNOWN};
}
void tokenizer_print_token(Tokenizer *tokenizer, Token token) {
  printf("%.*s", (int)token.length, token.text);
};
char tokenizer_advance(Tokenizer *tokenizer) {
  if (tokenizer->pos <= tokenizer->input_len) {
    tokenizer->pos++;
    tokenizer->column++;
  }
  return tokenizer->input[tokenizer->pos];
}
Token tokenizer_parse_identifier(Tokenizer *tokenizer) {
  char current = tokenizer->input[tokenizer->pos];
  Token tok = {.text = tokenizer->input + tokenizer->pos,
               .length = 0,
               .line = tokenizer->line,
               .column = tokenizer->column,
               .type = TOKEN_IDENTIFIER};
  while (current >= 'a' && current <= 'z' || current >= 'A' && current <= 'Z' ||
         current == '_') {
    current = tokenizer_advance(tokenizer);
    tok.length++;
  }
  return tok;
}
Token tokenizer_parse_number(Tokenizer *tokenizer) {
  char current = tokenizer->input[tokenizer->pos];
  Token tok = {.text = tokenizer->input + tokenizer->pos,
               .length = 0,
               .line = tokenizer->line,
               .column = tokenizer->column,
               .type = TOKEN_IDENTIFIER};
  while (current >= '0' && current <= '9' || current == '.') {
    current = tokenizer_advance(tokenizer);
    tok.length++;
  }
  return tok;
}
