#include "parser.hh"
#include "tokenizer.hh"

#include <format>
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

static SourceSpan node_span(const AstNode &node) {
  return SourceSpan{.pos = node.pos,
                    .length = node.length,
                    .column = node.column,
                    .line = node.line};
}

static SourceSpan span_of(const Token &token) { return token_span(token); }

static SourceSpan span_of(const std::optional<Token> &token) {
  return token_span(token.value());
}

static SourceSpan span_of(const AstNode &node) { return node_span(node); }

static SourceSpan span_of(const AstNodePtr &node) { return node_span(*node); }

template <typename First, typename Last>
static SourceSpan span_from(const First &first, const Last &last) {
  auto first_span = span_of(first);
  auto last_span = span_of(last);
  return SourceSpan{.pos = first_span.pos,
                    .length = last_span.pos + last_span.length - first_span.pos,
                    .column = first_span.column,
                    .line = first_span.line};
}

static bool is_literal(const Token &token) {
  return token.type == Type::Numtoken || token.type == Type::Strtoken ||
         token.type == Type::True || token.type == Type::False;
}

static AstNodePtr parse_literal(Parser &parser, const Token &token) {
  switch (token.type) {
  case Type::Numtoken: {
    std::string text(token_text(parser, token));
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
    if (length >= 2 && parser.source[start] == '"' &&
        parser.source[start + length - 1] == '"') {
      start++;
      length -= 2;
    }
    return std::make_unique<StringLiteral>(
        token_span(token),
        std::string_view(parser.source).substr(start, length));
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
  case (Type::Year):
    return Operator::Year;
  case (Type::Month):
    return Operator::Month;
  case (Type::Week):
    return Operator::Week;
  case (Type::Day):
    return Operator::Day;
  case (Type::Hours):
    return Operator::Hours;
  case (Type::Minutes):
    return Operator::Minutes;
  case (Type::Seconds):
    return Operator::Seconds;
  default:
    return std::nullopt;
  }
}

bool is_operator(Token token) {
  auto op = operator_from_token(token);
  return op.has_value();
}

bool is_postfix(Operator op) {
  switch (op) {
  case (Operator::Year):
  case (Operator::Month):
  case (Operator::Week):
  case (Operator::Day):
  case (Operator::Hours):
  case (Operator::Minutes):
  case (Operator::Seconds):
    return true;
  default:
    return false;
  }
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

bool statement_can_omit_semicolon(const AstNode &statement) {
  return statement.tag == AstTag::FunctionDefinitionStatement ||
         statement.tag == AstTag::StatementBlock;
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
  switch (op) {
  case (Operator::Year):
  case (Operator::Month):
  case (Operator::Week):
  case (Operator::Day):
  case (Operator::Hours):
  case (Operator::Minutes):
  case (Operator::Seconds):
    return 80;
  default:
    return 0;
  }
}

int prefix_binding_power(Operator op) {
  switch (op) {
  case (Operator::Minus):
    return 45;
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

Token expect_token(Tokenizer &tokenizer, Type type) {
  if (auto token = tokenzier_match_token(tokenizer, type)) {
    return *token;
  }

  auto next_token = tokenizer_peek_token(tokenizer);
  throw ParserError(
      std::format("Expected token of type {} but got token of type {}",
                  token_type_to_string(type),
                  token_type_to_string(next_token.type)),
      next_token);
}

} // namespace

ParserError::ParserError(const std::string &message, const Token &token)
    : std::runtime_error(parser_error_message(message, token)) {}

AstNodePtr parse_statement_block(Parser &parser) {
  std::vector<AstNodePtr> sb;
  auto next = tokenizer_peek_token(parser.tokenizer);
  if (next.type == Type::Rbrac || next.type == Type::Eof) {
    throw ParserError("expected statement",
                      tokenizer_peek_token(parser.tokenizer));
  }
  for (;;) {
    auto statement = parse_statement(parser);
    sb.push_back(std::move(statement));
    if (tokenzier_match_token(parser.tokenizer, Type::Semicolon).has_value()) {
      auto next = tokenizer_peek_token(parser.tokenizer);
      if (next.type == Type::Rbrac || next.type == Type::Eof) {
        break;
      }
      continue;
    }
    auto next = tokenizer_peek_token(parser.tokenizer);
    if (next.type != Type::Rbrac && next.type != Type::Eof &&
        statement_can_omit_semicolon(*sb.back())) {
      continue;
    }
    break;
  }
  auto span = span_from(sb.front(), sb.back());
  return std::make_unique<StatementBlock>(span, std::move(sb));
}

std::vector<AstNodePtr> parse_list(Parser &parser) {
  std::vector<AstNodePtr> items;
  auto next_peek = tokenizer_peek_token(parser.tokenizer);
  if (next_peek.type == Type::Rspar || next_peek.type == Type::Eof) {
    return items;
  }
  for (;;) {
    auto item = parser_expr_binding_power(parser, 0);
    items.push_back(std::move(item));
    if (tokenzier_match_token(parser.tokenizer, Type::Comma)) {
      continue;
    }
    break;
  }
  return items;
}

AstNodePtr parse_expression_tail(Parser &parser, AstNodePtr left_hand_side,
                                 int min_binding_power) {
  for (;;) {
    auto next = tokenizer_peek_token(parser.tokenizer);
    if (next.type == Type::Eof) {
      break;
    }
    if (is_operator(next)) {
      auto op = operator_from_token(next).value();
      if (is_postfix(op)) {
        auto postfix_binding_power_value = postfix_binding_power(op);
        if (postfix_binding_power_value < min_binding_power) {
          break;
        }

        tokenizer_next_token(parser.tokenizer);

        auto span = span_from(*left_hand_side, next);
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

        tokenizer_next_token(parser.tokenizer);

        auto right_hand_side =
            parser_expr_binding_power(parser, right_hand_side_binding_power);

        auto span = span_from(*left_hand_side, *right_hand_side);
        left_hand_side = std::make_unique<InfixExpression>(
            span, op, std::move(left_hand_side), std::move(right_hand_side));
        continue;
      }
    }
    break;
  }

  return left_hand_side;
}

AstNodePtr parse_identifier_expression(Parser &parser, Token token) {
  AstNodePtr left_hand_side = std::make_unique<IdentifierExression>(
      token_span(token), token_text(parser, token));

  if (tokenzier_match_token(parser.tokenizer, Type::Lpar)) {
    auto args = parse_function_args(parser);
    auto next_token = expect_token(parser.tokenizer, Type::Rpar);
    auto span = span_from(*left_hand_side, next_token);
    left_hand_side = std::make_unique<FunctionCallExpression>(
        span, std::move(left_hand_side), std::move(args));
  }

  return left_hand_side;
}

AstNodePtr parser_expr_binding_power(Parser &parser, int min_binding_power) {
  auto token = tokenizer_next_token(parser.tokenizer);
  AstNodePtr left_hand_side;

  //
  // At this point when we try to parse an expression we dont want no Eof
  //
  if (token.type == Type::Eof) {
    throw ParserError("did not expect EOF here", token);
  }

  if (token.type == Type::Lspar) {
    auto items = parse_list(parser);
    auto closing = tokenzier_match_token(parser.tokenizer, Type::Rspar);
    if (!closing.has_value()) {
      throw ParserError("expected closing ] for list after t:", token);
    }
    auto span = span_from(token, closing.value());
    left_hand_side = std::make_unique<ListExpresssion>(span, std::move(items));
  }

  if (is_literal(token)) {
    left_hand_side = parse_literal(parser, token);
  }

  if (token.type == Type::Lpar) {
    left_hand_side = parser_expr_binding_power(parser, 0);
    expect_token(parser.tokenizer, Type::Rpar);
  }

  if (is_operator(token)) {
    auto op = operator_from_token(token).value();
    if (!is_prefix(op)) {
      throw ParserError("did not expect this token here", token);
    }
    auto right_hand_side_binding_power = prefix_binding_power(op);

    //
    // this is right hand side because prefix binds to the right hand side of
    // the token so here we have to watch out that left_hand_side is not
    // initialized yet this is kind of a c / cpp problem or a me problem how you
    // see it but this is important else SEG_FAULT
    //
    auto right_hand_side =
        parser_expr_binding_power(parser, right_hand_side_binding_power);
    auto span = span_from(token, *right_hand_side);
    left_hand_side = std::make_unique<PrefixExpression>(
        span, op, std::move(right_hand_side));
  }

  if (token.type == Type::Identifier) {
    left_hand_side = parse_identifier_expression(parser, token);
  }

  if (left_hand_side == nullptr) {
    throw ParserError("expected expression", token);
  }

  return parse_expression_tail(parser, std::move(left_hand_side),
                               min_binding_power);
}

std::vector<AstNodePtr> parse_function_args(Parser &parser) {
  std::vector<AstNodePtr> args;
  if (tokenizer_peek_token(parser.tokenizer).type == Type::Rpar) {
    return args;
  }

  for (;;) {
    auto arg = parser_expr_binding_power(parser, 0);
    args.push_back(std::move(arg));
    if (tokenzier_match_token(parser.tokenizer, Type::Comma)) {
      continue;
    }
    break;
  }
  return args;
}

Parser make_parser(std::string &source, Tokenizer &tokenizer) {
  return Parser{.source = source, .tokenizer = tokenizer};
}

AstNodePtr parser_expr(Parser &p) {
  auto ast = parser_expr_binding_power(p, 0);
  auto next = tokenizer_next_token(p.tokenizer);
  if (next.type != Type::Eof) {
    throw ParserError("unexpected token after expression", next);
  }
  return ast;
}

std::vector<AstNodePtr> parse_function_definition_args(Parser &parser) {
  std::vector<AstNodePtr> args;
  if (tokenizer_peek_token(parser.tokenizer).type == Type::Rpar) {
    return args;
  }

  for (;;) {
    auto next = tokenizer_next_token(parser.tokenizer);
    if (next.type != Type::Identifier) {
      throw ParserError("expected an identifier in the function arguments",
                        next);
    }
    auto ident_span = token_span(next);
    auto ident_expression = std::make_unique<IdentifierExression>(
        ident_span, token_text(parser, next));

    args.push_back(std::move(ident_expression));
    if (tokenzier_match_token(parser.tokenizer, Type::Comma)) {
      continue;
    }
    break;
  }
  return args;
}

AstNodePtr parse_function_definition(Parser &parser, Token ident) {
  auto ident_span = token_span(ident);
  auto ident_expression = std::make_unique<IdentifierExression>(
      ident_span, token_text(parser, ident));
  auto lpar = tokenizer_next_token(parser.tokenizer);
  if (lpar.type != Type::Lpar) {
    throw ParserError("expected <ident> :: >(< but found", lpar);
  }
  auto args = parse_function_definition_args(parser);
  auto rpar = tokenizer_next_token(parser.tokenizer);
  if (rpar.type != Type::Rpar) {
    throw ParserError("expected <ident> :: (args...>)< but found", rpar);
  }
  auto l_brac = tokenizer_next_token(parser.tokenizer);
  if (l_brac.type != Type::Lbrac) {
    throw ParserError("expected <ident> :: (args...) >{< found", l_brac);
  }

  auto body = parse_statement_block(parser);

  auto r_brac = tokenizer_next_token(parser.tokenizer);
  if (r_brac.type != Type::Rbrac) {
    throw ParserError("expected <ident> :: (args...) { ...body >}< found",
                      r_brac);
  }
  auto span = span_from(ident, r_brac);
  auto function_definition_statement =
      std::make_unique<FunctionDefinitionStatement>(
          span, std::move(args), std::move(ident_expression), std::move(body));
  return function_definition_statement;
}

AstNodePtr parse_return_statment(Parser &parser, Token return_token) {
  auto value = parser_expr_binding_power(parser, 0);
  auto span = span_from(return_token, value);
  auto return_statement =
      std::make_unique<ReturnStatement>(span, std::move(value));
  return return_statement;
}

AstNodePtr parse_statement(Parser &parser) {
  if (auto maybe_return_token =
          tokenzier_match_token(parser.tokenizer, Type::Return)) {
    return parse_return_statment(parser, maybe_return_token.value());
  }
  if (auto open_brace = tokenzier_match_token(parser.tokenizer, Type::Lbrac)) {
    auto sb = parse_statement_block(parser);
    if (auto close_brace =
            tokenzier_match_token(parser.tokenizer, Type::Rbrac)) {
      return sb;
    }
    throw ParserError("expected closing brace and got this",
                      tokenizer_next_token(parser.tokenizer));
  }
  if (tokenizer_peek_token(parser.tokenizer).type == Type::Identifier) {
    auto ident = tokenizer_next_token(parser.tokenizer);
    if (auto assign = tokenzier_match_token(parser.tokenizer, Type::Assign)) {
      auto ident_span = token_span(ident);
      auto ident_expression = std::make_unique<IdentifierExression>(
          ident_span, token_text(parser, ident));
      auto expression = parser_expr_binding_power(parser, 0);
      auto span = span_from(ident, expression);
      return std::make_unique<AssignmentStatement>(
          span, std::move(ident_expression), std::move(expression));
    }
    if (tokenzier_match_token(parser.tokenizer, Type::DoubleColon)) {
      return parse_function_definition(parser, ident);
    }
    auto expression = parse_identifier_expression(parser, ident);
    return parse_expression_tail(parser, std::move(expression), 0);
  }
  if (auto write = tokenzier_match_token(parser.tokenizer, Type::Trace)) {
    auto right_hand_side = parser_expr_binding_power(parser, 0);
    auto span = SourceSpan{
        .pos = write->pos,
        .length = right_hand_side->pos + right_hand_side->length - write->pos,
        .column = write->column,
        .line = write->line,
    };
    return std::make_unique<WriteStatement>(span, std::move(right_hand_side),
                                            true);
  }
  if (auto write = tokenzier_match_token(parser.tokenizer, Type::Write)) {
    auto right_hand_side = parser_expr_binding_power(parser, 0);
    auto span = SourceSpan{
        .pos = write->pos,
        .length = right_hand_side->pos + right_hand_side->length - write->pos,
        .column = write->column,
        .line = write->line,
    };
    return std::make_unique<WriteStatement>(span, std::move(right_hand_side),
                                            false);
  }

  return parser_expr_binding_power(parser, 0);
}
