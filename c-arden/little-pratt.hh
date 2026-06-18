#pragma once

#include <cstddef>
#include <memory>
#include <ostream>
#include <string>
#include <utility>
#include <variant>

enum class TokenType {
  Ident,
  Number,
  Op,
  Eof,
};

struct Token {
  TokenType type;
  std::string text;
};

enum class Operator {
  Plus,
  Minus,
  Times,
  Div,
  Dot,
};

enum class AstNodeType {
  Atom,
  Cons,
};

struct Expr;

using ExprPtr = std::unique_ptr<Expr>;

struct BinaryExpression {
  Operator op;
  ExprPtr lhs;
  ExprPtr rhs;
};

struct UnaryExpression {
  Operator op;
  ExprPtr rhs;
};

struct Identifier {
  std::string name;
};

struct NumberLiteral {
  double value;
};

using ExprKind =
    std::variant<UnaryExpression, BinaryExpression, Identifier, NumberLiteral>;

struct Expr {
  Token token;
  ExprKind kind;
};

struct PrintVisitor;
struct Lexer {
  std::string input;
  std::size_t pos;
};

Operator operator_from_char(char c);
std::ostream &operator<<(std::ostream &os, const Operator &op);
std::ostream &operator<<(std::ostream &os, const Expr &a);
Token next_token(Lexer &l);
Lexer create_lexer(std::string input);
std::pair<int, int> infix_binding_power(Operator op);
Token peek_token(Lexer &l);
Expr expr_bp(Lexer &l, int min_bp);
Expr expr(std::string input);

struct PrintVisitor {
  std::ostream &os;
  std::ostream &operator()(const NumberLiteral &n) const {
    return os << n.value;
  }
  std::ostream &operator()(const Identifier &n) const { return os << n.name; }
  std::ostream &operator()(const UnaryExpression &n) const {
    return os << "(" << n.op << " " << *n.rhs << ")";
  }
  std::ostream &operator()(const BinaryExpression &n) const {
    return os << "(" << n.op << " " << *n.lhs << " " << *n.rhs << ")";
  }
};
