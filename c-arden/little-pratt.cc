// https://matklad.github.io/2020/04/13/simple-but-powerful-pratt-parsing.html#Minimal-Pratt-Parser

#include "little-pratt.hh"
#include <cctype>
#include <charconv>
#include <cstddef>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <string_view>

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
  case ('.'):
    return Operator::Dot;
  }
  throw std::invalid_argument("An operator has to be +-*/.");
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
  case (Operator::Dot):
    return os << ".";
  default:
    throw std::runtime_error("There is one operator missing here");
  }
}

std::ostream &operator<<(std::ostream &os, const Expr &a) {
  return std::visit(PrintVisitor{os}, a.kind);
}

std::ostream &operator<<(std::ostream &os, const Token &t) {
  switch (t.type) {
  case (TokenType::Ident):
    return os << "Token{type=Ident" << ",value=" << t.text << "}";
  case (TokenType::Number):
    return os << "Token{type=Number" << ",value=" << t.text << "}";
  case (TokenType::Op):
    return os << "Token{type=Op" << ",value=" << t.text << "}";
  case (TokenType::Eof):
    return os << "Token{type=Eof}";
  default:
    throw std::runtime_error(
        "There is a token type not implemented here that should be.");
  }
}

Lexer create_lexer(std::string input) {
  return Lexer{.input = std::move(input), .pos = 0};
}

Token next_token(Lexer &l) {
  Token token = Token{.type = TokenType::Eof, .text = ""};

  while (l.pos < l.input.length() &&
         std::isspace(static_cast<unsigned char>(l.input[l.pos]))) {
    l.pos++;
  }

  if (l.pos >= l.input.length()) {
    return token;
  }

  size_t start = l.pos;
  unsigned char current = static_cast<unsigned char>(l.input[l.pos]);

  if (std::isalpha(current)) {
    while (l.pos < l.input.length() &&
           std::isalnum(static_cast<unsigned char>(l.input[l.pos]))) {
      l.pos++;
    }
    token.type = TokenType::Ident;
  } else if (std::isdigit(current)) {
    while (l.pos < l.input.length() &&
           std::isdigit(static_cast<unsigned char>(l.input[l.pos]))) {
      l.pos++;
    }
    token.type = TokenType::Number;
  } else if (l.input[l.pos] == '+' || l.input[l.pos] == '-' ||
             l.input[l.pos] == '*' || l.input[l.pos] == '/' ||
             l.input[l.pos] == '.') {
    l.pos++;
    token.type = TokenType::Op;
  } else {
    throw std::runtime_error("unexpected character: " +
                             std::string(1, l.input[l.pos]));
  }

  token.text = l.input.substr(start, l.pos - start);
  return token;
}

std::pair<int, int> infix_binding_power(Operator op) {
  switch (op) {
  case (Operator::Plus):
  case (Operator::Minus):
    //
    // left associative less binding than left associative times and div
    //
    return std::pair{1, 2};
  case (Operator::Div):
  case (Operator::Times):
    //
    // left associative more binding than plus and minus any time
    //
    return std::pair{3, 4};
  case (Operator::Dot):
    return std::pair{6, 5};
  default:
    throw std::runtime_error("There is an operator type missing here");
  }
}

Token peek_token(Lexer &l) {
  size_t pos = l.pos;
  Token peek = next_token(l);
  l.pos = pos;
  return peek;
}

std::pair<double, bool> string_view_to_double(std::string_view sv) {
  double value;
  auto [ptr, ec] = std::from_chars(sv.data(), sv.data() + sv.size(), value);

  if (ec == std::errc{} && ptr == sv.data() + sv.size()) {
    return std::pair{value, true};
  }
  return std::pair{0, false};
}

ExprKind make_ident_or_number(Token token) {
  if (token.type == TokenType::Number) {
    auto [value, ok] = string_view_to_double(token.text);
    if (!ok) {
      throw std::runtime_error("could not convert string to double: " +
                               token.text);
    }
    return NumberLiteral{.value = value};
  } else if (token.type == TokenType::Ident) {
    return Identifier{.name = token.text};
  } else {
    throw std::runtime_error("expected number or ident");
  }
}

/*
 * @param l Lexer
 * @param min_bp is the minimal binding power to recurse if the binding power
 * is under this we return one scope up. This builds the tree structure
 * recursively without wasting resources like a recursive descent parser.
 * @return left hand lide of the tree
 */
Expr expr_bp(Lexer &l, int min_bp) {
  auto next = next_token(l);
  if (next.type == TokenType::Eof) {
    throw std::runtime_error("expected number or ident");
  }
  auto lhs = Expr{.token = next, .kind = make_ident_or_number(next)};

  for (;;) {
    next = peek_token(l);
    if (next.type == TokenType::Eof) {
      break;
    }

    if (next.type != TokenType::Op) {
      break;
    }

    auto op = operator_from_char(next.text.at(0));
    auto [l_bp, r_bp] = infix_binding_power(op);

    if (l_bp < min_bp) {
      break;
    }
    next_token(l);
    auto rhs = expr_bp(l, r_bp);

    // build the new lhs here
    lhs = Expr{.token = next,
               .kind = BinaryExpression{
                   .op = op,
                   .lhs = std::make_unique<Expr>(std::move(lhs)),
                   .rhs = std::make_unique<Expr>(std::move(rhs)),
               }};
  };
  return lhs;
}

Expr expr(std::string input) {
  Lexer l = create_lexer(std::move(input));
  auto ast = expr_bp(l, 0);
  auto next = next_token(l);
  if (next.type != TokenType::Eof) {
    throw std::runtime_error("unexpected token after expression: " + next.text);
  }
  return ast;
}

int main(void) {
  try {
    std::string input;
    std::getline(std::cin, input);
    auto cons = expr(input);
    std::cout << cons << std::endl;
  } catch (const std::exception &e) {
    std::cerr << e.what() << std::endl;
    return 1;
  }
}
