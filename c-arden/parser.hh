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

/*
 * this needs to be forward declared because the other expression and statement
 * types need to use this as abstraction
 */
enum class AstTag {
  NumberLiteral,
  StringLiteral,
  BooleanLiteral,
  Identifier,
};

struct AstNode {
  AstNode(AstTag tag, const Token &token)
      : tag(tag), pos(token.pos), length(token.length), column(token.column),
        line(token.line) {}
  AstTag tag;
  std::size_t pos;
  std::size_t length;
  std::size_t column;
  std::size_t line;
  virtual ~AstNode() = default;
};

using AstNodePtr = std::unique_ptr<AstNode>;

struct NumberLiteral : AstNode {
  NumberLiteral(const Token &token, double value)
      : AstNode(AstTag::NumberLiteral, token), value(value) {}
  double value;
};

/*
 * this should be a string view into the source what we do with it can the
 * interpreter decide
 */
struct StringLiteral : AstNode {
  StringLiteral(const Token &token, std::string_view value)
      : AstNode(AstTag::StringLiteral, token), value(value) {}
  std::string_view value;
};

/*
 * this should be a string view into the source what we do with it can the
 * interpreter decide
 */
struct Identifier : AstNode {
  Identifier(const Token &token, std::string_view value)
      : AstNode(AstTag::Identifier, token), value(value) {}
  std::string_view value;
};

/*
 * this should be a string view into the source what we do with it can the
 * interpreter decide
 */
struct BooleanLiteral : AstNode {
  BooleanLiteral(const Token &token, bool value)
      : AstNode(AstTag::BooleanLiteral, token), value(value) {}
  bool value;
};

Parser make_parser(std::string &source, Tokenizer &tokenizer);
AstNodePtr parser_expr(Parser &p);
AstNodePtr parser_expr_bp(Parser &p);
