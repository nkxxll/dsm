// https://matklad.github.io/2020/04/13/simple-but-powerful-pratt-parsing.html#Minimal-Pratt-Parser
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Forward declarations
struct Cons;

// An enum to act as our "tag"
typedef enum { S_ATOM, S_CONS } NodeType;

// The Tagged Union
typedef struct S {
  NodeType type; // This keeps track of what is active!
  union {
    char atom;
    struct Cons *cons;
  } data;
} S;

// The Cons struct
typedef struct Cons {
  S lhs;
  S rhs;
} Cons;

enum Token_Type {
  TOKEN_ATOM,
  TOKEN_OP,
  TOKEN_EOF,
};

typedef struct {
  int type;
  char value;
} Token;

typedef struct {
  Token **tokens;
  size_t pos;
} Lexer;

Token *token_create() {
  Token *t = malloc(sizeof(Token));
  if (!t) {
    perror("token");
    exit(1);
  }
  return t;
}

void token_new(Token *t, int type, char value) {
  t->type = type;
  t->value = value;
}

Token *lexer_next(Lexer *l) { return l->tokens[l->pos++]; }

void lexer_new(Lexer *l, char *input, size_t len) {
  Token **buffer = malloc(126); // ohhh yeah constants
  size_t buffer_index = 0;
  for (size_t index = 0; index < len; index++) {
    char c = input[index];

    if (isalnum(c)) {
      Token *t = token_create();
      token_new(t, TOKEN_ATOM, c);
      buffer[buffer_index++] = t;
    } else {
      Token *t = token_create();
      token_new(t, TOKEN_OP, c);
      buffer[buffer_index++] = t;
    }
  }
  Token *t = token_create();
  token_new(t, TOKEN_EOF, 0);
  buffer[buffer_index++] = t;

  l->tokens = buffer;
}

void print_token(Token t) {
  printf("type: %s, value: %c\n", t.type == TOKEN_ATOM ? "ATOM" : "OP",
         t.value);
}

char cons_head(S *s) { return s->data.cons->lhs.data.atom; }
S cons_tail(S *s) { return s->data.cons->rhs; }

void s_print(S *s) {
  if (s->type == S_ATOM) {
    printf("%c", s->data.atom);
  } else {
    printf("(%c", cons_head(s));

  }
}

int main(void) {
  Lexer l;
  char *input = "5+6*2";
  lexer_new(&l, input, strlen(input));
  while (1) {
    Token *t = lexer_next(&l);
    if (t->type == TOKEN_EOF) {
      break;
    }
    print_token(*t);
  }
}
