#include "tokenizer.h"
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  const char *text;
  int type;
} Keyword;

static const Keyword keywords[] = {
    {"any", TOKEN_ANY},
    {"as", TOKEN_AS},
    {"average", TOKEN_AVERAGE},
    {"before", TOKEN_BEFORE},
    {"count", TOKEN_COUNT},
    {"currenttime", TOKEN_CURRENTTIME},
    {"day", TOKEN_DAY},
    {"days", TOKEN_DAY},
    {"do", TOKEN_DO},
    {"earliest", TOKEN_EARLIEST},
    {"else", TOKEN_ELSE},
    {"elseif", TOKEN_ELSEIF},
    {"enddo", TOKEN_ENDDO},
    {"endif", TOKEN_ENDIF},
    {"false", TOKEN_FALSE},
    {"first", TOKEN_FIRST},
    {"for", TOKEN_FOR},
    {"greater", TOKEN_GREATER},
    {"hour", TOKEN_HOURS},
    {"hours", TOKEN_HOURS},
    {"if", TOKEN_IF},
    {"in", TOKEN_IN},
    {"increase", TOKEN_INCREASE},
    {"interval", TOKEN_INTERVAL},
    {"is", TOKEN_IS},
    {"last", TOKEN_LAST},
    {"latest", TOKEN_LATEST},
    {"list", TOKEN_LISTTYPE},
    {"maximum", TOKEN_MAXIMUM},
    {"minimum", TOKEN_MINIMUM},
    {"minute", TOKEN_MINUTES},
    {"minutes", TOKEN_MINUTES},
    {"month", TOKEN_MONTH},
    {"months", TOKEN_MONTH},
    {"not", TOKEN_NOT},
    {"now", TOKEN_NOW},
    {"null", TOKEN_NULL},
    {"number", TOKEN_NUMBERTYPE},
    {"occur", TOKEN_OCCUR},
    {"occurred", TOKEN_OCCUR},
    {"occurs", TOKEN_OCCUR},
    {"of", TOKEN_OF},
    {"range", TOKEN_RANGE},
    {"read", TOKEN_READ},
    {"same", TOKEN_SAME},
    {"second", TOKEN_SECONDS},
    {"seconds", TOKEN_SECONDS},
    {"sqrt", TOKEN_SQRT},
    {"sum", TOKEN_SUM},
    {"than", TOKEN_THAN},
    {"the", TOKEN_THE},
    {"then", TOKEN_THEN},
    {"time", TOKEN_TIME},
    {"to", TOKEN_TO},
    {"trace", TOKEN_TRACE},
    {"true", TOKEN_TRUE},
    {"uppercase", TOKEN_UPPERCASE},
    {"week", TOKEN_WEEK},
    {"weeks", TOKEN_WEEK},
    {"where", TOKEN_WHERE},
    {"within", TOKEN_WITHIN},
    {"write", TOKEN_WRITE},
    {"year", TOKEN_YEAR},
    {"years", TOKEN_YEAR},
};

static int is_identifier_start(unsigned char c) {
  return isalpha(c) || c == '_';
}

static int is_identifier_char(unsigned char c) {
  return isalnum(c) || c == '_';
}

static int token_text_equals_ignore_case(Token token, const char *text) {
  size_t text_len = strlen(text);
  if (token.length != text_len) {
    return 0;
  }

  for (size_t i = 0; i < token.length; i++) {
    unsigned char a = (unsigned char)token.text[i];
    unsigned char b = (unsigned char)text[i];
    if (tolower(a) != tolower(b)) {
      return 0;
    }
  }

  return 1;
}

static Token make_token(Tokenizer *tokenizer, size_t start, size_t length,
                        size_t line, size_t column, int type) {
  return (Token){.text = tokenizer->input + start,
                 .length = length,
                 .column = column,
                 .line = line,
                 .type = type};
}

static void tokenizer_skip_line_comment(Tokenizer *tokenizer) {
  while (tokenizer_peek(tokenizer) != '\0' &&
         tokenizer_peek(tokenizer) != '\n') {
    tokenizer_advance(tokenizer);
  }
}

static void tokenizer_advance_delimiter(Tokenizer *tokenizer) {
  if (tokenizer_peek(tokenizer) != '\0') {
    tokenizer->pos++;
  }
}

static Token tokenizer_parse_string(Tokenizer *tokenizer) {
  size_t start = tokenizer->pos;
  size_t line = tokenizer->line;
  size_t column = tokenizer->column;
  size_t length = 1;
  size_t rows = 0;

  tokenizer_advance_delimiter(tokenizer);
  while (tokenizer_peek(tokenizer) != '\0' &&
         tokenizer_peek(tokenizer) != '"') {
    if (tokenizer_peek(tokenizer) == '\n' ||
        tokenizer_peek(tokenizer) == '\r') {
      rows++;
    }
    tokenizer->pos++;
    length++;
  }

  if (tokenizer_peek(tokenizer) == '"') {
    length++;
    tokenizer_advance_delimiter(tokenizer);
  }

  tokenizer->line += rows;
  tokenizer->column += length;

  return make_token(tokenizer, start, length, line, column, TOKEN_STRTOKEN);
}

int init_tokenizer(Tokenizer *tokenizer, const char *input_file, FILE *file) {
  if (fseek(file, 0, SEEK_END) != 0) {
    fprintf(stderr, "Could not seek file: %s\n", input_file);
    fclose(file);
    return 0;
  }

  long size = ftell(file);
  if (size < 0) {
    fprintf(stderr, "Could not determine file size: %s\n", input_file);
    fclose(file);
    return 0;
  }

  rewind(file);

  char *input = malloc((size_t)size + 1);
  if (!input) {
    fprintf(stderr, "Could not allocate memory for file content\n");
    fclose(file);
    return 0;
  }

  if (fread(input, 1, (size_t)size, file) != (size_t)size) {
    fprintf(stderr, "Could not read file: %s\n", input_file);
    free(input);
    fclose(file);
    return 0;
  }
  fclose(file);

  input[size] = '\0';
  tokenizer->input_file = input_file;
  tokenizer->input = input;
  tokenizer->input_len = (size_t)size;
  tokenizer->pos = 0;
  tokenizer->line = 1;
  tokenizer->column = 1;
  return 1;
}

Token get_next_token(Tokenizer *tokenizer) {
  for (;;) {
    char current = tokenizer_peek(tokenizer);
    if (current == ' ' || current == '\t' || current == '\r') {
      tokenizer_advance(tokenizer);
      continue;
    }

    if (current == '\n') {
      tokenizer_advance(tokenizer);
      continue;
    }

    if (current == '/' && tokenizer->pos + 1 < tokenizer->input_len &&
        tokenizer->input[tokenizer->pos + 1] == '/') {
      tokenizer_skip_line_comment(tokenizer);
      continue;
    }

    break;
  }

  char current = tokenizer_peek(tokenizer);
  if (current == '\0') {
    return make_token(tokenizer, tokenizer->pos, 0, tokenizer->line,
                      tokenizer->column, TOKEN_EOF);
  }

  if (isdigit((unsigned char)current)) {
    return tokenizer_parse_number(tokenizer);
  }

  if (is_identifier_start((unsigned char)current)) {
    return tokenizer_parse_identifier(tokenizer);
  }

  if (current == '"') {
    return tokenizer_parse_string(tokenizer);
  }

  switch (current) {
  case '*':
    if (tokenizer->pos + 1 < tokenizer->input_len &&
        tokenizer->input[tokenizer->pos + 1] == '*') {
      return tokenizer_single_char_token(tokenizer, TOKEN_POWER);
    }
    return tokenizer_single_char_token(tokenizer, TOKEN_TIMES);
  case ':':
    if (tokenizer->pos + 1 < tokenizer->input_len &&
        tokenizer->input[tokenizer->pos + 1] == '=') {
      return tokenizer_single_char_token(tokenizer, TOKEN_ASSIGN);
    }
    break;
  case '.':
    if (tokenizer->pos + 2 < tokenizer->input_len &&
        tokenizer->input[tokenizer->pos + 1] == '.' &&
        tokenizer->input[tokenizer->pos + 2] == '.') {
      return tokenizer_single_char_token(tokenizer, TOKEN_RANGE);
    }
    return tokenizer_single_char_token(tokenizer, TOKEN_DOT);
  case '<':
    if (tokenizer->pos + 1 < tokenizer->input_len) {
      if (tokenizer->input[tokenizer->pos + 1] == '=') {
        return tokenizer_single_char_token(tokenizer, TOKEN_LTEQ);
      }
      if (tokenizer->input[tokenizer->pos + 1] == '>') {
        return tokenizer_single_char_token(tokenizer, TOKEN_NEQ);
      }
    }
    return tokenizer_single_char_token(tokenizer, TOKEN_LT);
  case '>':
    if (tokenizer->pos + 1 < tokenizer->input_len &&
        tokenizer->input[tokenizer->pos + 1] == '=') {
      return tokenizer_single_char_token(tokenizer, TOKEN_GTEQ);
    }
    return tokenizer_single_char_token(tokenizer, TOKEN_GT);
  case '+':
  case '-':
  case '/':
  case '(':
  case ')':
  case '[':
  case ']':
  case ',':
  case '&':
  case ';':
  case '=':
    return tokenizer_single_char_token(tokenizer, current);
  }

  return tokenizer_single_char_token(tokenizer, TOKEN_UNKNOWN);
}

void tokenizer_print_token(Token token) {
  printf("%.*s", (int)token.length, token.text);
}

char tokenizer_peek(Tokenizer *tokenizer) {
  if (tokenizer->pos >= tokenizer->input_len) {
    return '\0';
  }

  return tokenizer->input[tokenizer->pos];
}

char tokenizer_advance(Tokenizer *tokenizer) {
  char current = tokenizer_peek(tokenizer);
  if (current == '\0') {
    return current;
  }

  tokenizer->pos++;
  if (current == '\n') {
    tokenizer->line++;
    tokenizer->column = 1;
  } else {
    tokenizer->column++;
  }

  return tokenizer_peek(tokenizer);
}

Token tokenizer_single_char_token(Tokenizer *tokenizer, int type) {
  size_t start = tokenizer->pos;
  size_t line = tokenizer->line;
  size_t column = tokenizer->column;
  size_t length = 1;

  if (type == TOKEN_ASSIGN || type == TOKEN_POWER || type == TOKEN_LTEQ ||
      type == TOKEN_NEQ || type == TOKEN_GTEQ) {
    length = 2;
  } else if (type == TOKEN_RANGE) {
    length = 3;
  }

  for (size_t i = 0; i < length; i++) {
    tokenizer_advance(tokenizer);
  }

  return make_token(tokenizer, start, length, line, column, type);
}

Token tokenizer_parse_identifier(Tokenizer *tokenizer) {
  size_t start = tokenizer->pos;
  size_t line = tokenizer->line;
  size_t column = tokenizer->column;

  while (is_identifier_char((unsigned char)tokenizer_peek(tokenizer))) {
    tokenizer_advance(tokenizer);
  }

  Token tok = make_token(tokenizer, start, tokenizer->pos - start, line, column,
                         TOKEN_IDENTIFIER);
  for (size_t i = 0; i < sizeof(keywords) / sizeof(keywords[0]); i++) {
    if (token_text_equals_ignore_case(tok, keywords[i].text)) {
      tok.type = keywords[i].type;
      break;
    }
  }

  return tok;
}

Token tokenizer_parse_number(Tokenizer *tokenizer) {
  size_t start = tokenizer->pos;
  size_t line = tokenizer->line;
  size_t column = tokenizer->column;
  int is_time = 0;

  while (isdigit((unsigned char)tokenizer_peek(tokenizer))) {
    tokenizer_advance(tokenizer);
  }

  if (tokenizer_peek(tokenizer) == '.' &&
      tokenizer->pos + 1 < tokenizer->input_len &&
      isdigit((unsigned char)tokenizer->input[tokenizer->pos + 1])) {
    tokenizer_advance(tokenizer);
    while (isdigit((unsigned char)tokenizer_peek(tokenizer))) {
      tokenizer_advance(tokenizer);
    }
  }

  while (tokenizer_peek(tokenizer) == ':' || tokenizer_peek(tokenizer) == '-' ||
         tokenizer_peek(tokenizer) == 'T') {
    is_time = 1;
    tokenizer_advance(tokenizer);
    while (isdigit((unsigned char)tokenizer_peek(tokenizer))) {
      tokenizer_advance(tokenizer);
    }
  }

  return make_token(tokenizer, start, tokenizer->pos - start, line, column,
                    is_time ? TOKEN_TIMETOKEN : TOKEN_NUMTOKEN);
}

char *token_type_to_string(int token_type) {
  switch (token_type) {
  case TOKEN_EOF:
    return "TOKEN_EOF";
  case TOKEN_IDENTIFIER:
    return "TOKEN_IDENTIFIER";

  case TOKEN_PLUS:
    return "TOKEN_PLUS";
  case TOKEN_MINUS:
    return "TOKEN_MINUS";
  case TOKEN_TIMES:
    return "TOKEN_TIMES";
  case TOKEN_DIVIDE:
    return "TOKEN_DIVIDE";
  case TOKEN_LPAR:
    return "TOKEN_LPAR";
  case TOKEN_RPAR:
    return "TOKEN_RPAR";
  case TOKEN_LSPAR:
    return "TOKEN_LSPAR";
  case TOKEN_RSPAR:
    return "TOKEN_RSPAR";
  case TOKEN_COMMA:
    return "TOKEN_COMMA";
  case TOKEN_AMPERSAND:
    return "TOKEN_AMPERSAND";
  case TOKEN_SEMICOLON:
    return "TOKEN_SEMICOLON";
  case TOKEN_EQ:
    return "TOKEN_EQ";
  case TOKEN_DOT:
    return "TOKEN_DOT";
  case TOKEN_LT:
    return "TOKEN_LT";
  case TOKEN_GT:
    return "TOKEN_GT";

  case TOKEN_UNKNOWN:
    return "TOKEN_UNKNOWN";

  case TOKEN_ASSIGN:
    return "TOKEN_ASSIGN";
  case TOKEN_POWER:
    return "TOKEN_POWER";
  case TOKEN_LTEQ:
    return "TOKEN_LTEQ";
  case TOKEN_NEQ:
    return "TOKEN_NEQ";
  case TOKEN_GTEQ:
    return "TOKEN_GTEQ";
  case TOKEN_RANGE:
    return "TOKEN_RANGE";

  case TOKEN_NUMTOKEN:
    return "TOKEN_NUMTOKEN";
  case TOKEN_STRTOKEN:
    return "TOKEN_STRTOKEN";
  case TOKEN_TIMETOKEN:
    return "TOKEN_TIMETOKEN";

  case TOKEN_THE:
    return "TOKEN_THE";
  case TOKEN_AS:
    return "TOKEN_AS";
  case TOKEN_THAN:
    return "TOKEN_THAN";
  case TOKEN_OF:
    return "TOKEN_OF";
  case TOKEN_TO:
    return "TOKEN_TO";
  case TOKEN_SQRT:
    return "TOKEN_SQRT";
  case TOKEN_DAY:
    return "TOKEN_DAY";
  case TOKEN_WHERE:
    return "TOKEN_WHERE";
  case TOKEN_WITHIN:
    return "TOKEN_WITHIN";
  case TOKEN_NOT:
    return "TOKEN_NOT";
  case TOKEN_IS:
    return "TOKEN_IS";
  case TOKEN_SAME:
    return "TOKEN_SAME";
  case TOKEN_LISTTYPE:
    return "TOKEN_LISTTYPE";
  case TOKEN_ANY:
    return "TOKEN_ANY";
  case TOKEN_AVERAGE:
    return "TOKEN_AVERAGE";
  case TOKEN_BEFORE:
    return "TOKEN_BEFORE";
  case TOKEN_COUNT:
    return "TOKEN_COUNT";
  case TOKEN_CURRENTTIME:
    return "TOKEN_CURRENTTIME";
  case TOKEN_DO:
    return "TOKEN_DO";
  case TOKEN_EARLIEST:
    return "TOKEN_EARLIEST";
  case TOKEN_ELSE:
    return "TOKEN_ELSE";
  case TOKEN_ELSEIF:
    return "TOKEN_ELSEIF";
  case TOKEN_ENDDO:
    return "TOKEN_ENDDO";
  case TOKEN_ENDIF:
    return "TOKEN_ENDIF";
  case TOKEN_FALSE:
    return "TOKEN_FALSE";
  case TOKEN_FIRST:
    return "TOKEN_FIRST";
  case TOKEN_FOR:
    return "TOKEN_FOR";
  case TOKEN_GREATER:
    return "TOKEN_GREATER";
  case TOKEN_HOURS:
    return "TOKEN_HOURS";
  case TOKEN_IF:
    return "TOKEN_IF";
  case TOKEN_IN:
    return "TOKEN_IN";
  case TOKEN_INCREASE:
    return "TOKEN_INCREASE";
  case TOKEN_INTERVAL:
    return "TOKEN_INTERVAL";
  case TOKEN_LAST:
    return "TOKEN_LAST";
  case TOKEN_LATEST:
    return "TOKEN_LATEST";
  case TOKEN_MAXIMUM:
    return "TOKEN_MAXIMUM";
  case TOKEN_MINIMUM:
    return "TOKEN_MINIMUM";
  case TOKEN_MINUTES:
    return "TOKEN_MINUTES";
  case TOKEN_NOW:
    return "TOKEN_NOW";
  case TOKEN_NULL:
    return "TOKEN_NULL";
  case TOKEN_OCCUR:
    return "TOKEN_OCCUR";
  case TOKEN_READ:
    return "TOKEN_READ";
  case TOKEN_SECONDS:
    return "TOKEN_SECONDS";
  case TOKEN_SUM:
    return "TOKEN_SUM";
  case TOKEN_THEN:
    return "TOKEN_THEN";
  case TOKEN_TIME:
    return "TOKEN_TIME";
  case TOKEN_TRACE:
    return "TOKEN_TRACE";
  case TOKEN_TRUE:
    return "TOKEN_TRUE";
  case TOKEN_UPPERCASE:
    return "TOKEN_UPPERCASE";
  case TOKEN_WRITE:
    return "TOKEN_WRITE";
  case TOKEN_NUMBERTYPE:
    return "TOKEN_NUMBERTYPE";
  case TOKEN_YEAR:
    return "TOKEN_YEAR";
  case TOKEN_MONTH:
    return "TOKEN_MONTH";
  case TOKEN_WEEK:
    return "TOKEN_WEEK";
  default:
    return "UNKNOWN";
  }
}
