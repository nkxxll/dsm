#include "parser.hh"
#include "tokenizer.hh"

#include <memory>
#include <stdexcept>
#include <string>
#include <string_view>

namespace {

static std::string parser_error_message(const std::string &message,
                                        const Token &token) {
  return message + " at " + std::to_string(token.line) + ":" +
         std::to_string(token.column);
}

static std::string_view token_text(Parser &p, const Token &token) {
  return std::string_view(p.source).substr(token.pos, token.length);
}

static bool is_literal(const Token &token) {
  return token.type == Type::Numtoken || token.type == Type::Strtoken ||
         token.type == Type::True || token.type == Type::False;
}

static AstNodePtr parse_literal(Parser &p, const Token &token) {
  switch (token.type) {
  case Type::Numtoken: {
    std::string text(token_text(p, token));
    std::size_t parsed = 0;
    double value = std::stod(text, &parsed);
    if (parsed != text.size()) {
      throw ParserError("invalid number literal", token);
    }
    return std::make_unique<NumberLiteral>(value);
  }
  case Type::Strtoken: {
    std::size_t start = token.pos;
    std::size_t length = token.length;
    if (length >= 2 && p.source[start] == '"' &&
        p.source[start + length - 1] == '"') {
      start++;
      length -= 2;
    }
    return std::make_unique<StringLiteral>(
        std::string_view(p.source).substr(start, length));
  }
  case Type::True:
  case Type::False:
    return std::make_unique<BooleanLiteral>(token.type == Type::True);
  default:
    throw ParserError("expected literal", token);
  }
}

} // namespace

ParserError::ParserError(const std::string &message, const Token &token)
    : std::runtime_error(parser_error_message(message, token)) {}

AstNodePtr parser_expr_bp(Parser &p, int min_binding_power) {
  auto token = tokenizer_next_token(p.tokenizer);
  AstNodePtr left_hand_side;

  //
  // At this point when we try to parse an expression we dont want no Eof
  //
  if (token.type == Type::Eof) {
    throw ParserError("did not expect EOF here", token);
  }

  if (is_literal(token)) {
    left_hand_side = parse_literal(p, token);
  }

  if (token.type == Type::Identifier) {
    left_hand_side = std::make_unique<Identifier>(token_text(p, token));
  }

  for (;;) {
    auto next = tokenizer_peek_token(p.tokenizer);
    if (next.type == Type::Eof) {
      break;
    }
    if (is_operator(token)) {
      if (is_postfix(token)) {
        //
        //this is the left hand side binding power because the operator is postfix
        //
        auto postfix_binding_power = postfix_binding_power(token);
        if (postfix_binding_power < min_binding_power) {
          break;
        }
        lhs = std::make_unique<PostfixExpression>()
      }
    }
  }

  return left_hand_side;
}

Parser make_parser(std::string &source, Tokenizer &tokenizer) {
  return Parser{.source = source, .tokenizer = tokenizer};
}

AstNodePtr parser_expr(Parser &p) {
  auto ast = parser_expr_bp(p);
  auto next = tokenizer_next_token(p.tokenizer);
  if (next.type != Type::Eof) {
    throw ParserError("unexpected token after expression", next);
  }
  return ast;
}
