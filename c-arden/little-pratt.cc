// https://matklad.github.io/2020/04/13/simple-but-powerful-pratt-parsing.html#Minimal-Pratt-Parser

#include <cctype>
#include <csignal>
#include <cstddef>
#include <iostream>
#include <stdexcept>
#include <string>
#include <variant>
#include <vector>

enum class AstNodeType {
  Atom,
  Cons,
};

struct AstNode;

struct Cons {
  char lhs;
  std::vector<AstNode> rhs;
};

struct AstNode {
  AstNodeType type;
  std::variant<char, Cons> value;
};

std::ostream &operator<<(std::ostream &os, const AstNode &a) {
  switch (a.type) {
  case (AstNodeType::Atom):
    return os << std::get<char>(a.value);
  case (AstNodeType::Cons):
    const auto &cons = std::get<Cons>(a.value);
    os << "(" << cons.lhs;
    for (const auto &c : cons.rhs) {
      os << c;
    }
    return os << ")";
  }
}

enum class TokenType {
  Atom,
  Op,
  Eof,
};

enum class Operator {
  Plus,
  Minus,
  Times,
  Div,
};

Operator operator_from_char(char c) {
  switch (c) {
  case ('+'):
    return Operator::Plus;
  case ('-'):
    return Operator::Minus;
  case ('/'):
    return Operator::Div;
  case ('*'):
    return Operator::Times;
  }
  throw std::invalid_argument("An operator has to be +-*/");
}

std::ostream &operator<<(std::ostream &os, const Operator &op) {
  switch (op) {
  case (Operator::Plus):
    return os << "+";
  case (Operator::Minus):
    return os << "-";
  case (Operator::Div):
    return os << "/";
  case (Operator::Times):
    return os << "*";
  }
}

struct Token {
  TokenType type;
  std::variant<char, Operator> value;
};

std::ostream &operator<<(std::ostream &os, const Token &t) {
  switch (t.type) {
  case (TokenType::Atom):
    return os << "Token{type=Atom" << ",value=" << std::get<char>(t.value)
              << "}";
  case (TokenType::Op):
    return os << "Token{type=Op" << ",value=" << std::get<Operator>(t.value)
              << "}";
  case (TokenType::Eof):
    return os << "Token{type=Eof}";
  }
}

struct Lexer {
  std::string input;
  std::size_t pos;
};

Lexer create_lexer(std::string input) {
  return Lexer{.input = std::move(input), .pos = 0};
}

Token next_token(Lexer &l) {
  Token token = Token{.type = TokenType::Eof, .value = '\0'};
  if (l.pos >= l.input.length()) {
    return token;
  }
  while (std::isspace(l.input[l.pos])) {
    if (l.pos >= l.input.length()) {
      return token;
    }
    l.pos++;
  }
  char current = l.input[l.pos];
  if (std::isalnum(current)) {
    token.type = TokenType::Atom;
    token.value = current;
  } else {
    token.type = TokenType::Op;
    token.value = operator_from_char(current);
  }
  l.pos++;
  return token;
}

std::pair<int, int> infix_binding_power(Operator op) {
  switch (op) {
  case (Operator::Plus):
  case (Operator::Minus):
    //
    // right associative less binding than right associative times and div
    //
    return std::pair(1, 2);
  case (Operator::Div):
  case (Operator::Times):
    //
    // right associative more binding than plus and minus any time
    //
    return std::pair(3, 4);
  }
}

AstNode expr_bp(Lexer &l) {
  auto next = next_token(l);
  auto lhs =
      AstNode{.type = AstNodeType::Atom, .value = std::get<char>(next.value)};

  for (;;) {
    next = next_token(l);
    if (next.type == TokenType::Eof) {
      break;
    }
    //
    // next has to be an operator here else we have a problem
    //

    auto [l_bp, r_bp] = infix_binding_power(std::get<Operator>(next.value));
  }

  throw std::runtime_error("expected atom");
}

AstNode expr(std::string input) {
  Lexer l = create_lexer(std::move(input));
  return expr_bp(l);
}

int main(void) {
  std::string input = "1 + 2 * 3";
  Lexer l = create_lexer(input);
  Token t = next_token(l);
  while (t.type != TokenType::Eof) {
    std::cout << t << std::endl;
    t = next_token(l);
  }
}
