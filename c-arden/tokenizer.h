#ifndef TOKENIZER_H
#define TOKENIZER_H

#include <stddef.h>
#include <stdio.h>

typedef struct {
  const char *input_file;
  char *input;
  size_t input_len;
  size_t pos;
  size_t line;
  size_t column;
} Tokenizer;

typedef struct {
  const char *text;
  size_t length;
  size_t column;
  size_t line;
  int type;
} Token;

enum Type {
  TOKEN_EOF,
  TOKEN_NUMBER,
  TOKEN_IDENTIFIER,
  TOKEN_PLUS = '+',
  TOKEN_MULTIPLY = '*',
  TOKEN_MINUS = '-',
  TOKEN_DIVIDE = '/',
  TOKEN_UNKNOWN,
};

int init_tokenizer(Tokenizer *tokenizer, const char *input_file, FILE *file);
Token get_next_token(Tokenizer *tokenizer);
void tokenizer_print_token(Tokenizer *tokenizer, Token token);
Token tokenizer_parse_number(Tokenizer *tokenizer);
Token tokenizer_parse_identifier(Tokenizer *tokenizer);

#endif
