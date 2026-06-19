#include "parser.hh"
#include "tokenizer.hh"

#include <memory>
#include <optional>
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

static SourceSpan token_span(const Token &token) {
  return SourceSpan{.pos = token.pos,
                    .length = token.length,
                    .column = token.column,
                    .line = token.line};
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
    return std::make_unique<NumberLiteral>(token_span(token), value);
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
        token_span(token), std::string_view(p.source).substr(start, length));
  }
  case Type::True:
  case Type::False:
    return std::make_unique<BooleanLiteral>(token_span(token),
                                            token.type == Type::True);
  default:
    throw ParserError("expected literal", token);
  }
}

std::optional<Operator> operator_from_token(Token token) {
  switch (token.type) {
  case (Type::Plus):
    return Operator::Plus;
  case (Type::Minus):
    return Operator::Minus;
  case (Type::Multipy):
    return Operator::Multipy;
  case (Type::Divide):
    return Operator::Divide;
  case (Type::Ampersand):
    return Operator::Ampersand;
  case (Type::Dot):
    return Operator::Dot;
  case (Type::Lt):
    return Operator::Lt;
  case (Type::Gt):
    return Operator::Gt;
  case (Type::Power):
    return Operator::Power;
  case (Type::Lteq):
    return Operator::Lteq;
  case (Type::Neq):
    return Operator::Neq;
  case (Type::Gteq):
    return Operator::Gteq;
  case (Type::Range):
    return Operator::Range;
  default:
    return std::nullopt;
  }
}

bool is_operator(Token token) {
  auto op = operator_from_token(token);
  return op.has_value();
}

bool is_postfix(Operator op) {
  auto _ = op;
  return false;
}

bool is_infix(Operator op) {
  switch (op) {
  case (Operator::Divide):
  case (Operator::Plus):
  case (Operator::Minus):
  case (Operator::Multipy):
  case (Operator::Power):
    return true;
  default:
    return false;
  }
}

bool is_prefix(Operator op) {
  switch (op) {
  case (Operator::Minus):
    return true;
  default:
    return false;
  }
}

int postfix_binding_power(Operator op) {
  auto _ = op;
  return 0;
}

int prefix_binding_power(Operator op) {
  switch (op) {
  case (Operator::Minus):
    return 70;
  default:
    return 0;
  }
}

std::pair<int, int> infix_binding_power(Operator op) {
  switch (op) {
  case (Operator::Minus):
  case (Operator::Plus):
    return std::pair(10, 20);
  case (Operator::Multipy):
  case (Operator::Divide):
    return std::pair(30, 40);
  case (Operator::Power):
    return std::pair(50, 60);
  default:
    return std::pair(0, 0);
  }
}

} // namespace

ParserError::ParserError(const std::string &message, const Token &token)
    : std::runtime_error(parser_error_message(message, token)) {}

AstNodePtr parser_expr_binding_power(Parser &p, int min_binding_power) {
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
    left_hand_side =
        std::make_unique<Identifier>(token_span(token), token_text(p, token));
  }

  for (;;) {
    auto next = tokenizer_peek_token(p.tokenizer);
    if (next.type == Type::Eof) {
      break;
    }
    if (is_operator(token)) {
      //
      // we have to consume the token else we dont move forward but we cant
      // consume it at the start if the token is not handled here like ')',
      // '}', or ']'
      //
      tokenizer_next_token(p.tokenizer);
      auto op = operator_from_token(token).value();
      if (is_postfix(op)) {
        //
        // this is the left hand side binding power because the operator is
        // postfix
        //
        auto postfix_binding_power_value = postfix_binding_power(op);
        if (postfix_binding_power_value < min_binding_power) {
          break;
        }

        auto span = token_span(token);
        span.length = next.pos + next.length;
        left_hand_side = std::make_unique<PostfixExpression>(
            span, op, std::move(left_hand_side));
        continue;
      }
      if (is_infix(op)) {
        auto [left_hand_side_binding_power, right_hand_side_binding_power] =
            infix_binding_power(op);

        if (left_hand_side_binding_power < min_binding_power) {
          break;
        }

        auto right_hand_side =
            parser_expr_binding_power(p, right_hand_side_binding_power);

        auto span = token_span(token);
        span.length = right_hand_side->pos + right_hand_side->length;
        left_hand_side = std::make_unique<InfixExpression>(
            span, op, std::move(left_hand_side), std::move(right_hand_side));
        continue;
      }
    }
    //
    // if the next token is not handled by the current function it has to
    // handled by the caller function call exmaple here is ')' or '}' or ']'
    //
    break;
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
