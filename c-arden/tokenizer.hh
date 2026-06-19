#ifndef TOKENIZER_HH
#define TOKENIZER_HH

#include <cstddef>
#include <cstdio>
#include <string_view>

enum class Type {
  Eof,
  Identifier,

  Plus = '+',
  Minus = '-',
  Multipy = '*',
  Divide = '/',
  Lpar = '(',
  Rpar = ')',
  Lspar = '[',
  Rspar = ']',
  Comma = ',',
  Ampersand = '&',
  Semicolon = ';',
  Eq = '=',
  Dot = '.',
  Lt = '<',
  Gt = '>',

  Unknown = 128,

  Assign = 256,
  Power,
  Lteq,
  Neq,
  Gteq,
  Range,

  Numtoken,
  Strtoken,
  Timetoken,

  The,
  As,
  Than,
  Of,
  To,
  Sqrt,
  Day,
  Where,
  Within,
  Not,
  Is,
  Same,
  Listtype,
  Any,
  Average,
  Before,
  Count,
  Currenttime,
  Do,
  Earliest,
  Else,
  Elseif,
  Enddo,
  Endif,
  False,
  First,
  For,
  Greater,
  Hours,
  If,
  In,
  Increase,
  Interval,
  Last,
  Latest,
  Maximum,
  Minimum,
  Minutes,
  Now,
  Null,
  Occur,
  Read,
  Seconds,
  Sum,
  Then,
  Time,
  Trace,
  True,
  Uppercase,
  Write,
  Numbertype,
  Year,
  Month,
  Week,
};

struct Tokenizer {
  std::string_view input_file;
  std::string_view input;
  std::size_t pos;
  std::size_t line;
  std::size_t column;
};

struct Token {
  std::size_t pos;
  std::size_t length;
  std::size_t column;
  std::size_t line;
  Type type;
};

void init_tokenizer(Tokenizer &tokenizer, std::string_view input_file,
                    std::string_view input);
void destroy_tokenizer(Tokenizer &tokenizer);
Token tokenizer_next_token(Tokenizer &tokenizer);
/*
 * peeks the next token does not change the internal tokenizer state
 */
Token tokenizer_peek_token(Tokenizer &tokenizer);
void tokenizer_print_token(const Tokenizer &tokenizer, Token token);
const char *token_type_to_string(Type token_type);

#endif
