#include "interpreter.hh"
#include "parser.hh"
#include "tokenizer.hh"

#include <cstdio>
#include <exception>
#include <fstream>
#include <iterator>
#include <string>

int main(int argc, char *argv[]) {
  if (argc < 2) {
    std::fprintf(stderr, "Usage: %s <input_file>\n", argv[0]);
    return 1;
  }

  const char *input_file = argv[1];
  std::ifstream file(input_file, std::ios::binary);
  if (!file) {
    std::fprintf(stderr, "Could not open file: %s\n", input_file);
    return 1;
  }

  std::string input((std::istreambuf_iterator<char>(file)),
                    std::istreambuf_iterator<char>());
  Tokenizer tokenizer{};
  init_tokenizer(tokenizer, input_file, input);

  try {
    Parser parser = make_parser(input, tokenizer);
    auto ast = parse_statement_block(parser);
    auto next = tokenizer_next_token(tokenizer);
    if (next.type != Type::Eof) {
      throw ParserError("unexpected token after statement block", next);
    }

    Environment env;
    eval(env, std::move(ast));
  } catch (const ParserError &error) {
    std::fprintf(stderr, "Parse error: %s\n", error.what());
    destroy_tokenizer(tokenizer);
    return 1;
  } catch (const RuntimeError &error) {
    std::fprintf(stderr, "Runtime error: %s\n", error.what());
    destroy_tokenizer(tokenizer);
    return 1;
  } catch (const std::exception &error) {
    std::fprintf(stderr, "Error: %s\n", error.what());
    destroy_tokenizer(tokenizer);
    return 1;
  }

  destroy_tokenizer(tokenizer);
  return 0;
}
