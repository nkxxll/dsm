#include "parser.hh"
#include "tokenizer.hh"

#include <stdexcept>
#include <string>

AstNode parser_expr_bp(Parser &p) {
  AstNode left_hand_side;
  auto token = tokenizer_next_token(&p.tokenizer);

  //
  // At this point when we try to parse an expression we dont want no Eof
  //
  if (token.type == Type::Eof) {
    // @todo custom error type
    throw std::runtime_error(
        "Did not expect Eof here" /* @todo add the position here */);
  }

  if (is_literal()) {
  }

  return node;
}

Parser make_parser(std::string &source, Tokenizer &tokenizer) {
  return Parser{.source = source, .tokenizer = tokenizer};
}

AstNode parser_expr(Parser &p) {
  auto ast = parser_expr_bp(p);
  auto next = tokenizer_next_token(&p.tokenizer);
  if (next.type != Type::Eof) {
    throw std::runtime_error(
        "unexpected token after expression: " +
        std::string(p.source.substr(next.pos, next.length)));
  }
  return ast;
}
