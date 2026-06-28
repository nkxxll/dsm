#include "tokenizer.hh"

#include <cctype>
#include <cstdio>
#include <cstring>
#include <optional>
#include <string>

namespace {

static char tokenizer_peek(Tokenizer &tokenizer);
static char tokenizer_advance(Tokenizer &tokenizer);
static Token tokenizer_single_char_token(Tokenizer &tokenizer, Type type);
static Token tokenizer_parse_number(Tokenizer &tokenizer);
static Token tokenizer_parse_identifier(Tokenizer &tokenizer);
static void tokenizer_advance_to_after_token(Tokenizer &tokenizer,
                                             const Token &token);

struct Keyword {
  std::string text;
  Type type;
};

static const Keyword keywords[] = {
    {"any", Type::Any},
    {"as", Type::As},
    {"average", Type::Average},
    {"before", Type::Before},
    {"count", Type::Count},
    {"currenttime", Type::Currenttime},
    {"day", Type::Day},
    {"days", Type::Day},
    {"do", Type::Do},
    {"earliest", Type::Earliest},
    {"else", Type::Else},
    {"elseif", Type::Elseif},
    {"enddo", Type::Enddo},
    {"endif", Type::Endif},
    {"false", Type::False},
    {"first", Type::First},
    {"for", Type::For},
    {"greater", Type::Greater},
    {"hour", Type::Hours},
    {"hours", Type::Hours},
    {"if", Type::If},
    {"in", Type::In},
    {"increase", Type::Increase},
    {"interval", Type::Interval},
    {"is", Type::Is},
    {"last", Type::Last},
    {"latest", Type::Latest},
    {"list", Type::Listtype},
    {"maximum", Type::Maximum},
    {"minimum", Type::Minimum},
    {"minute", Type::Minutes},
    {"minutes", Type::Minutes},
    {"month", Type::Month},
    {"months", Type::Month},
    {"not", Type::Not},
    {"now", Type::Now},
    {"null", Type::Null},
    {"number", Type::Numbertype},
    {"occur", Type::Occur},
    {"occurred", Type::Occur},
    {"occurs", Type::Occur},
    {"of", Type::Of},
    {"range", Type::Range},
    {"read", Type::Read},
    {"same", Type::Same},
    {"second", Type::Seconds},
    {"seconds", Type::Seconds},
    {"sqrt", Type::Sqrt},
    {"sum", Type::Sum},
    {"than", Type::Than},
    {"the", Type::The},
    {"then", Type::Then},
    {"time", Type::Time},
    {"to", Type::To},
    {"trace", Type::Trace},
    {"true", Type::True},
    {"uppercase", Type::Uppercase},
    {"week", Type::Week},
    {"weeks", Type::Week},
    {"where", Type::Where},
    {"within", Type::Within},
    {"write", Type::Write},
    {"year", Type::Year},
    {"years", Type::Year},
    {"return", Type::Return},
};

static bool is_identifier_start(unsigned char c) {
  return std::isalpha(c) || c == '_';
}

static bool is_identifier_char(unsigned char c) {
  return std::isalnum(c) || c == '_';
}

static bool token_text_equals_ignore_case(const Tokenizer &tokenizer,
                                          const Token &token,
                                          const char *text) {
  std::size_t text_len = std::strlen(text);
  if (token.length != text_len) {
    return false;
  }

  for (std::size_t i = 0; i < token.length; i++) {
    unsigned char a = (unsigned char)tokenizer.input[token.pos + i];
    unsigned char b = (unsigned char)text[i];
    if (std::tolower(a) != std::tolower(b)) {
      return false;
    }
  }

  return true;
}

static Token make_token(std::size_t start, std::size_t length, std::size_t line,
                        std::size_t column, Type type) {
  return Token{.pos = start,
               .length = length,
               .column = column,
               .line = line,
               .type = type};
}

static void tokenizer_skip_line_comment(Tokenizer &tokenizer) {
  while (tokenizer_peek(tokenizer) != '\0' &&
         tokenizer_peek(tokenizer) != '\n') {
    tokenizer_advance(tokenizer);
  }
}

static void tokenizer_advance_delimiter(Tokenizer &tokenizer) {
  if (tokenizer_peek(tokenizer) != '\0') {
    tokenizer.pos++;
  }
}

static Token tokenizer_parse_string(Tokenizer &tokenizer) {
  std::size_t start = tokenizer.pos;
  std::size_t line = tokenizer.line;
  std::size_t column = tokenizer.column;
  std::size_t length = 1;
  std::size_t rows = 0;

  tokenizer_advance_delimiter(tokenizer);
  while (tokenizer_peek(tokenizer) != '\0' &&
         tokenizer_peek(tokenizer) != '"') {
    if (tokenizer_peek(tokenizer) == '\n' ||
        tokenizer_peek(tokenizer) == '\r') {
      rows++;
    }
    tokenizer.pos++;
    length++;
  }

  if (tokenizer_peek(tokenizer) == '"') {
    length++;
    tokenizer_advance_delimiter(tokenizer);
  }

  tokenizer.line += rows;
  tokenizer.column += length;

  return make_token(start, length, line, column, Type::Strtoken);
}

static char tokenizer_peek(Tokenizer &tokenizer) {
  if (tokenizer.pos >= tokenizer.input.size()) {
    return '\0';
  }

  return tokenizer.input[tokenizer.pos];
}

static char tokenizer_advance(Tokenizer &tokenizer) {
  char current = tokenizer_peek(tokenizer);
  if (current == '\0') {
    return current;
  }

  tokenizer.pos++;
  if (current == '\n') {
    tokenizer.line++;
    tokenizer.column = 1;
  } else {
    tokenizer.column++;
  }

  return tokenizer_peek(tokenizer);
}

static void tokenizer_advance_to_after_token(Tokenizer &tokenizer,
                                             const Token &token) {
  tokenizer.pos = token.pos + token.length;
  tokenizer.line = token.line;
  tokenizer.column = token.column + token.length;

  for (std::size_t i = 0; i < token.length; i++) {
    char current = tokenizer.input[token.pos + i];
    if (current == '\n' || current == '\r') {
      tokenizer.line++;
    }
  }
}

static Token tokenizer_single_char_token(Tokenizer &tokenizer, Type type) {
  std::size_t start = tokenizer.pos;
  std::size_t line = tokenizer.line;
  std::size_t column = tokenizer.column;
  std::size_t length = 1;

  if (type == Type::Assign || type == Type::Power || type == Type::Lteq ||
      type == Type::Neq || type == Type::Gteq || type == Type::DoubleColon) {
    length = 2;
  } else if (type == Type::Range) {
    length = 3;
  }

  for (std::size_t i = 0; i < length; i++) {
    tokenizer_advance(tokenizer);
  }

  return make_token(start, length, line, column, type);
}

static Token tokenizer_parse_identifier(Tokenizer &tokenizer) {
  std::size_t start = tokenizer.pos;
  std::size_t line = tokenizer.line;
  std::size_t column = tokenizer.column;

  while (is_identifier_char((unsigned char)tokenizer_peek(tokenizer))) {
    tokenizer_advance(tokenizer);
  }

  Token tok =
      make_token(start, tokenizer.pos - start, line, column, Type::Identifier);
  for (std::size_t i = 0; i < sizeof(keywords) / sizeof(keywords[0]); i++) {
    if (token_text_equals_ignore_case(tokenizer, tok,
                                      keywords[i].text.c_str())) {
      tok.type = keywords[i].type;
      break;
    }
  }

  return tok;
}

static Token tokenizer_parse_number(Tokenizer &tokenizer) {
  std::size_t start = tokenizer.pos;
  std::size_t line = tokenizer.line;
  std::size_t column = tokenizer.column;
  int is_time = 0;

  while (std::isdigit((unsigned char)tokenizer_peek(tokenizer))) {
    tokenizer_advance(tokenizer);
  }

  if (tokenizer_peek(tokenizer) == '.' &&
      tokenizer.pos + 1 < tokenizer.input.size() &&
      std::isdigit((unsigned char)tokenizer.input[tokenizer.pos + 1])) {
    tokenizer_advance(tokenizer);
    while (std::isdigit((unsigned char)tokenizer_peek(tokenizer))) {
      tokenizer_advance(tokenizer);
    }
  }

  while (tokenizer_peek(tokenizer) == ':' || tokenizer_peek(tokenizer) == '-' ||
         tokenizer_peek(tokenizer) == 'T') {
    is_time = 1;
    tokenizer_advance(tokenizer);
    while (std::isdigit((unsigned char)tokenizer_peek(tokenizer))) {
      tokenizer_advance(tokenizer);
    }
  }

  return make_token(start, tokenizer.pos - start, line, column,
                    is_time ? Type::Timetoken : Type::Numtoken);
}
} // namespace

const char *token_type_to_string(Type token_type) {
  switch (token_type) {
  case Type::Eof:
    return "Type::Eof";
  case Type::Identifier:
    return "Type::Identifier";

  case Type::Plus:
    return "Type::Plus";
  case Type::Minus:
    return "Type::Minus";
  case Type::Multipy:
    return "Type::Multipy";
  case Type::Divide:
    return "Type::Divide";
  case Type::Lpar:
    return "Type::Lpar";
  case Type::Rpar:
    return "Type::Rpar";
  case Type::Lspar:
    return "Type::Lspar";
  case Type::Rspar:
    return "Type::Rspar";
  case Type::Comma:
    return "Type::Comma";
  case Type::Ampersand:
    return "Type::Ampersand";
  case Type::DoubleColon:
    return "Type::DoubleColon";
  case Type::Semicolon:
    return "Type::Semicolon";
  case Type::Eq:
    return "Type::Eq";
  case Type::Dot:
    return "Type::Dot";
  case Type::Lt:
    return "Type::Lt";
  case Type::Gt:
    return "Type::Gt";

  case Type::Return:
    return "Type::Return";

  case Type::Unknown:
    return "Type::Unknown";

  case Type::Assign:
    return "Type::Assign";
  case Type::Power:
    return "Type::Power";
  case Type::Lteq:
    return "Type::Lteq";
  case Type::Neq:
    return "Type::Neq";
  case Type::Gteq:
    return "Type::Gteq";
  case Type::Range:
    return "Type::Range";

  case Type::Numtoken:
    return "Type::Numtoken";
  case Type::Strtoken:
    return "Type::Strtoken";
  case Type::Timetoken:
    return "Type::Timetoken";

  case Type::The:
    return "Type::The";
  case Type::As:
    return "Type::As";
  case Type::Than:
    return "Type::Than";
  case Type::Of:
    return "Type::Of";
  case Type::To:
    return "Type::To";
  case Type::Sqrt:
    return "Type::Sqrt";
  case Type::Day:
    return "Type::Day";
  case Type::Where:
    return "Type::Where";
  case Type::Within:
    return "Type::Within";
  case Type::Not:
    return "Type::Not";
  case Type::Is:
    return "Type::Is";
  case Type::Same:
    return "Type::Same";
  case Type::Listtype:
    return "Type::Listtype";
  case Type::Any:
    return "Type::Any";
  case Type::Average:
    return "Type::Average";
  case Type::Before:
    return "Type::Before";
  case Type::Count:
    return "Type::Count";
  case Type::Currenttime:
    return "Type::Currenttime";
  case Type::Do:
    return "Type::Do";
  case Type::Earliest:
    return "Type::Earliest";
  case Type::Else:
    return "Type::Else";
  case Type::Elseif:
    return "Type::Elseif";
  case Type::Enddo:
    return "Type::Enddo";
  case Type::Endif:
    return "Type::Endif";
  case Type::False:
    return "Type::False";
  case Type::First:
    return "Type::First";
  case Type::For:
    return "Type::For";
  case Type::Greater:
    return "Type::Greater";
  case Type::Hours:
    return "Type::Hours";
  case Type::If:
    return "Type::If";
  case Type::In:
    return "Type::In";
  case Type::Increase:
    return "Type::Increase";
  case Type::Interval:
    return "Type::Interval";
  case Type::Last:
    return "Type::Last";
  case Type::Latest:
    return "Type::Latest";
  case Type::Maximum:
    return "Type::Maximum";
  case Type::Minimum:
    return "Type::Minimum";
  case Type::Minutes:
    return "Type::Minutes";
  case Type::Now:
    return "Type::Now";
  case Type::Null:
    return "Type::Null";
  case Type::Occur:
    return "Type::Occur";
  case Type::Read:
    return "Type::Read";
  case Type::Seconds:
    return "Type::Seconds";
  case Type::Sum:
    return "Type::Sum";
  case Type::Then:
    return "Type::Then";
  case Type::Time:
    return "Type::Time";
  case Type::Trace:
    return "Type::Trace";
  case Type::True:
    return "Type::True";
  case Type::Uppercase:
    return "Type::Uppercase";
  case Type::Write:
    return "Type::Write";
  case Type::Numbertype:
    return "Type::Numbertype";
  case Type::Year:
    return "Type::Year";
  case Type::Month:
    return "Type::Month";
  case Type::Week:
    return "Type::Week";
  default:
    return "UNKNOWN";
  }
}

void init_tokenizer(Tokenizer &tokenizer, std::string_view input_file,
                    std::string_view input) {
  tokenizer.input_file = input_file;
  tokenizer.input = input;
  tokenizer.pos = 0;
  tokenizer.line = 1;
  tokenizer.column = 1;
  tokenizer.lookahead_count = 0;
}

static Token tokenizer_read_token(Tokenizer &tokenizer) {
  for (;;) {
    char current = tokenizer_peek(tokenizer);
    if (std::isspace(current)) {
      tokenizer_advance(tokenizer);
      continue;
    }

    //
    // look whether it is a comment
    //
    if (current == '/' && tokenizer.pos + 1 < tokenizer.input.size() &&
        tokenizer.input[tokenizer.pos + 1] == '/') {
      tokenizer_skip_line_comment(tokenizer);
      continue;
    }

    break;
  }

  char current = tokenizer_peek(tokenizer);
  if (current == '\0') {
    return make_token(tokenizer.pos, 0, tokenizer.line, tokenizer.column,
                      Type::Eof);
  }

  Token token;
  if (std::isdigit((unsigned char)current)) {
    token = tokenizer_parse_number(tokenizer);
  } else if (is_identifier_start((unsigned char)current)) {
    token = tokenizer_parse_identifier(tokenizer);
  } else if (current == '"') {
    token = tokenizer_parse_string(tokenizer);
  } else {
    switch (current) {
    case '*':
      if (tokenizer.pos + 1 < tokenizer.input.size() &&
          tokenizer.input[tokenizer.pos + 1] == '*') {
        token = tokenizer_single_char_token(tokenizer, Type::Power);
        break;
      }
      token = tokenizer_single_char_token(tokenizer, Type::Multipy);
      break;
    case ':':
      if (tokenizer.pos + 1 < tokenizer.input.size() &&
          tokenizer.input[tokenizer.pos + 1] == '=') {
        token = tokenizer_single_char_token(tokenizer, Type::Assign);
        break;
      }
      if (tokenizer.pos + 1 < tokenizer.input.size() &&
          tokenizer.input[tokenizer.pos + 1] == ':') {
        token = tokenizer_single_char_token(tokenizer, Type::DoubleColon);
        break;
      }
      token = tokenizer_single_char_token(tokenizer, Type::Unknown);
      break;
    case '.':
      if (tokenizer.pos + 2 < tokenizer.input.size() &&
          tokenizer.input[tokenizer.pos + 1] == '.' &&
          tokenizer.input[tokenizer.pos + 2] == '.') {
        token = tokenizer_single_char_token(tokenizer, Type::Range);
        break;
      }
      token = tokenizer_single_char_token(tokenizer, Type::Dot);
      break;
    case '<':
      if (tokenizer.pos + 1 < tokenizer.input.size()) {
        if (tokenizer.input[tokenizer.pos + 1] == '=') {
          token = tokenizer_single_char_token(tokenizer, Type::Lteq);
          break;
        }
        if (tokenizer.input[tokenizer.pos + 1] == '>') {
          token = tokenizer_single_char_token(tokenizer, Type::Neq);
          break;
        }
      }
      token = tokenizer_single_char_token(tokenizer, Type::Lt);
      break;
    case '>':
      if (tokenizer.pos + 1 < tokenizer.input.size() &&
          tokenizer.input[tokenizer.pos + 1] == '=') {
        token = tokenizer_single_char_token(tokenizer, Type::Gteq);
        break;
      }
      token = tokenizer_single_char_token(tokenizer, Type::Gt);
      break;
    case '+':
    case '-':
    case '/':
    case '(':
    case ')':
    case '[':
    case ']':
    case '{':
    case '}':
    case ',':
    case '&':
    case ';':
    case '=':
      token =
          tokenizer_single_char_token(tokenizer, static_cast<Type>(current));
      break;
    default:
      token = tokenizer_single_char_token(tokenizer, Type::Unknown);
      break;
    }
  }

  return token;
}

Token tokenizer_peek_token(Tokenizer &tokenizer) {
  if (tokenizer.lookahead_count == 0) {
    std::size_t pos = tokenizer.pos;
    std::size_t line = tokenizer.line;
    std::size_t column = tokenizer.column;

    tokenizer.lookahead_tokens[0] = tokenizer_read_token(tokenizer);
    tokenizer.lookahead_count = 1;

    tokenizer.pos = pos;
    tokenizer.line = line;
    tokenizer.column = column;
  }

  return tokenizer.lookahead_tokens[0];
}

Token tokenizer_next_token(Tokenizer &tokenizer) {
  if (tokenizer.lookahead_count > 0) {
    Token token = tokenizer.lookahead_tokens[0];
    tokenizer_advance_to_after_token(tokenizer, token);
    for (std::size_t i = 1; i < tokenizer.lookahead_count; i++) {
      tokenizer.lookahead_tokens[i - 1] = tokenizer.lookahead_tokens[i];
    }
    tokenizer.lookahead_count--;
    return token;
  }

  Token token = tokenizer_read_token(tokenizer);
  return token;
}

std::optional<Token> tokenzier_match_token(Tokenizer &tokenizer, Type type) {
  Token token = tokenizer_peek_token(tokenizer);
  if (token.type != type) {
    return std::nullopt;
  }

  tokenizer_next_token(tokenizer);
  return token;
}

void destroy_tokenizer(Tokenizer &tokenizer) {
  tokenizer.input_file = {};
  tokenizer.input = {};
  tokenizer.pos = 0;
  tokenizer.line = 1;
  tokenizer.column = 1;
  tokenizer.lookahead_count = 0;
}

void tokenizer_print_token(const Tokenizer &tokenizer, Token token) {
  std::printf("%.*s", (int)token.length, tokenizer.input.data() + token.pos);
}
