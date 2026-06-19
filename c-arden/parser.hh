#pragma once

#include "tokenizer.hh"

#include <memory>
#include <stdexcept>
#include <string>
#include <string_view>

struct Parser {
  std::string &source;
  Tokenizer &tokenizer;
};

struct ParserError : std::runtime_error {
  ParserError(const std::string &message, const Token &token);
};

enum class Operator {
  Plus,
  Minus,
  Multipy,
  Divide,
  Ampersand,
  Dot,
  Lt,
  Gt,
  Power,
  Lteq,
  Neq,
  Gteq,
  Range,
  Year,
  Month,
  Week,
  Day,
  Hours,
  Minutes,
  Seconds,
};

/*
 * this needs to be forward declared because the other expression and statement
 * types need to use this as abstraction
 */
enum class AstTag {
  NumberLiteral,
  StringLiteral,
  BooleanLiteral,
  Identifier,
  InfixExpression,
  PrefixExpression,
  PostfixExpression,
};

struct SourceSpan {
  std::size_t pos;
  std::size_t length;
  std::size_t column;
  std::size_t line;
};

struct AstNode {
  AstNode(AstTag tag, SourceSpan span)
      : tag(tag), pos(span.pos), length(span.length), column(span.column),
        line(span.line) {}
  AstTag tag;
  std::size_t pos;
  std::size_t length;
  std::size_t column;
  std::size_t line;
  virtual ~AstNode() = default;
};

using AstNodePtr = std::unique_ptr<AstNode>;

struct InfixExpression : AstNode {
  InfixExpression(SourceSpan span, Operator op, AstNodePtr left_hand_side,
                  AstNodePtr right_hand_side)
      : AstNode(AstTag::InfixExpression, span), op(op),
        left_hand_side(std::move(left_hand_side)),
        right_hand_side(std::move(right_hand_side)) {}
  Operator op;
  AstNodePtr left_hand_side;
  AstNodePtr right_hand_side;
};

struct PostfixExpression : AstNode {
  PostfixExpression(SourceSpan span, Operator op, AstNodePtr left_hand_side)
      : AstNode(AstTag::PostfixExpression, span), op(op),
        left_hand_side(std::move(left_hand_side)) {}
  Operator op;
  AstNodePtr left_hand_side;
};

struct PrefixExpression : AstNode {
  PrefixExpression(SourceSpan span, Operator op, AstNodePtr right_hand_side)
      : AstNode(AstTag::PrefixExpression, span), op(op),
        right_hand_side(std::move(right_hand_side)) {}
  Operator op;
  AstNodePtr right_hand_side;
};

struct NumberLiteral : AstNode {
  NumberLiteral(SourceSpan span, double value)
      : AstNode(AstTag::NumberLiteral, span), value(value) {}
  double value;
};

/*
 * this should be a string view into the source what we do with it can the
 * interpreter decide
 */
struct StringLiteral : AstNode {
  StringLiteral(SourceSpan span, std::string_view value)
      : AstNode(AstTag::StringLiteral, span), value(value) {}
  std::string_view value;
};

/*
 * this should be a string view into the source what we do with it can the
 * interpreter decide
 */
struct Identifier : AstNode {
  Identifier(SourceSpan span, std::string_view value)
      : AstNode(AstTag::Identifier, span), value(value) {}
  std::string_view value;
};

/*
 * this should be a string view into the source what we do with it can the
 * interpreter decide
 */
struct BooleanLiteral : AstNode {
  BooleanLiteral(SourceSpan span, bool value)
      : AstNode(AstTag::BooleanLiteral, span), value(value) {}
  bool value;
};

Parser make_parser(std::string &source, Tokenizer &tokenizer);
AstNodePtr parser_expr(Parser &p);
AstNodePtr parser_expr_bp(Parser &p);
