#pragma once

#include "tokenizer.hh"

#include <memory>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

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
  FunctionCallExpression,
  WriteStatement,
  AssignmentStatement,
  StatementBlock,
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

struct StatementBlock : AstNode {
  StatementBlock(SourceSpan span, std::vector<AstNodePtr> block)
      : AstNode(AstTag::StatementBlock, span), block(std::move(block)) {}
  std::vector<AstNodePtr> block;
};

struct AssignmentStatement : AstNode {
  AssignmentStatement(SourceSpan span, AstNodePtr ident, AstNodePtr expression)
      : AstNode(AstTag::AssignmentStatement, span), ident(std::move(ident)),
        expression(std::move(expression)) {}
  AstNodePtr ident;
  AstNodePtr expression;
};

struct WriteStatement : AstNode {
  WriteStatement(SourceSpan span, AstNodePtr right_hand_side)
      : AstNode(AstTag::WriteStatement, span),
        right_hand_side(std::move(right_hand_side)) {}
  AstNodePtr right_hand_side;
};

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
struct IdentifierExression : AstNode {
  IdentifierExression(SourceSpan span, std::string_view value)
      : AstNode(AstTag::Identifier, span), value(value) {}
  std::string_view value;
};

struct FunctionCallExpression : AstNode {
  FunctionCallExpression(SourceSpan span, AstNodePtr function_name,
                         std::vector<AstNodePtr> args)
      : AstNode(AstTag::FunctionCallExpression, span),
        function_name_identifier(std::move(function_name)),
        args(std::move(args)) {}
  AstNodePtr function_name_identifier;
  std::vector<AstNodePtr> args;
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
AstNodePtr parser_expr(Parser &parser);
AstNodePtr parser_expr_bp(Parser &parser);
std::vector<AstNodePtr> parse_function_args(Parser &parser);
AstNodePtr parse_statement_block(Parser &parser);
AstNodePtr parse_statement(Parser &parser);
