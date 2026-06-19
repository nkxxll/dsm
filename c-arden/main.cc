#include "tokenizer.hh"

#include <cstdio>
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
  init_tokenizer(&tokenizer, input_file, input);

  Token token{};
  while ((token = tokenizer_next_token(&tokenizer)).type != Type::Eof) {
    std::printf("Token: %s '", token_type_to_string(token.type));
    tokenizer_print_token(&tokenizer, token);
    std::printf("' at %zu:%zu\n", token.line, token.column);
  }

  destroy_tokenizer(&tokenizer);
  return 0;
}
