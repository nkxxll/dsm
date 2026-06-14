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
  TOKEN_MINUS = '-',
  TOKEN_MULTIPLY = '*',
  TOKEN_TIMES = TOKEN_MULTIPLY,
  TOKEN_DIVIDE = '/',
  TOKEN_LPAR = '(',
  TOKEN_RPAR = ')',
  TOKEN_LSPAR = '[',
  TOKEN_RSPAR = ']',
  TOKEN_COMMA = ',',
  TOKEN_AMPERSAND = '&',
  TOKEN_SEMICOLON = ';',
  TOKEN_EQ = '=',
  TOKEN_DOT = '.',
  TOKEN_LT = '<',
  TOKEN_GT = '>',

  TOKEN_UNKNOWN = 128,

  TOKEN_ASSIGN = 256,
  TOKEN_POWER,
  TOKEN_LTEQ,
  TOKEN_NEQ,
  TOKEN_GTEQ,
  TOKEN_RANGE,

  TOKEN_NUMTOKEN,
  TOKEN_STRTOKEN,
  TOKEN_TIMETOKEN,

  TOKEN_THE,
  TOKEN_AS,
  TOKEN_THAN,
  TOKEN_OF,
  TOKEN_TO,
  TOKEN_SQRT,
  TOKEN_DAY,
  TOKEN_WHERE,
  TOKEN_WITHIN,
  TOKEN_NOT,
  TOKEN_IS,
  TOKEN_SAME,
  TOKEN_LISTTYPE,
  TOKEN_ANY,
  TOKEN_AVERAGE,
  TOKEN_BEFORE,
  TOKEN_COUNT,
  TOKEN_CURRENTTIME,
  TOKEN_DO,
  TOKEN_EARLIEST,
  TOKEN_ELSE,
  TOKEN_ELSEIF,
  TOKEN_ENDDO,
  TOKEN_ENDIF,
  TOKEN_FALSE,
  TOKEN_FIRST,
  TOKEN_FOR,
  TOKEN_GREATER,
  TOKEN_HOURS,
  TOKEN_IF,
  TOKEN_IN,
  TOKEN_INCREASE,
  TOKEN_INTERVAL,
  TOKEN_LAST,
  TOKEN_LATEST,
  TOKEN_MAXIMUM,
  TOKEN_MINIMUM,
  TOKEN_MINUTES,
  TOKEN_NOW,
  TOKEN_NULL,
  TOKEN_OCCUR,
  TOKEN_READ,
  TOKEN_SECONDS,
  TOKEN_SUM,
  TOKEN_THEN,
  TOKEN_TIME,
  TOKEN_TRACE,
  TOKEN_TRUE,
  TOKEN_UPPERCASE,
  TOKEN_WRITE,
  TOKEN_NUMBERTYPE,
  TOKEN_YEAR,
  TOKEN_MONTH,
  TOKEN_WEEK,
};

int init_tokenizer(Tokenizer *tokenizer, const char *input_file, FILE *file);
Token get_next_token(Tokenizer *tokenizer);
void tokenizer_print_token(Token token);
char tokenizer_peek(Tokenizer *tokenizer);
char tokenizer_advance(Tokenizer *tokenizer);
Token tokenizer_single_char_token(Tokenizer *tokenizer, int type);
Token tokenizer_parse_number(Tokenizer *tokenizer);
Token tokenizer_parse_identifier(Tokenizer *tokenizer);

#endif
