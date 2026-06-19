#pragma once

#include "tokenizer.hh"

#include <string>

struct Parser {
  std::string &source;
  Tokenizer &tokenizer;
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

struct NumberLiteral {
  double value;
};

struct AstNode {
  AstTag tag;
  virtual ~AstNode() = default;
};

/*
 * this should be a string view into the source what we do with it can the
 * interpreter decide
 */
struct StringLiteral : AstNode {
  std::string_view value;
};

/*
 * this should be a string view into the source what we do with it can the
 * interpreter decide
 */
struct Identifier : AstNode {
  std::string_view value;
};

/*
 * this should be a string view into the source what we do with it can the
 * interpreter decide
 */
struct BooleanLiteral : AstNode {
  bool value;
};

Parser make_parser(std::string &source, Tokenizer &tokenizer);
AstNode parser_expr(Parser &p);
AstNode parser_expr_bp(Parser &p);
