#include "parser.hh"
#include "tokenizer.hh"
#include <vector>

#include <gtest/gtest.h>

struct TokenExpect {
  Type type;
  size_t length;
  size_t column;
  size_t line;
};

static std::vector<Token> tokenize_all(const char *input,
                                       size_t max_tokens = 2048) {
  Tokenizer tokenizer;
  init_tokenizer(tokenizer, "test", input);
  std::vector<Token> tokens;
  tokens.reserve(max_tokens);
  for (size_t i = 0; i < max_tokens; i++) {
    Token t = tokenizer_next_token(tokenizer);
    if (t.type == Type::Eof)
      break;
    tokens.push_back(t);
  }
  return tokens;
}

static void assert_token(const Token &actual, Type type, size_t length,
                         size_t column, size_t line) {
  EXPECT_EQ(actual.type, type)
      << " type mismatch" << token_type_to_string(actual.type)
      << "!=" << token_type_to_string(type);
  EXPECT_EQ(actual.length, length)
      << " length mismatch at type=" << token_type_to_string(type);
  EXPECT_EQ(actual.column, column)
      << " column mismatch at type=" << token_type_to_string(type);
  EXPECT_EQ(actual.line, line)
      << " line mismatch at type=" << token_type_to_string(type);
}

static void check_tokens(const char *input,
                         std::initializer_list<TokenExpect> expected) {
  auto tokens = tokenize_all(input);
  ASSERT_EQ(tokens.size(), expected.size());
  size_t i = 0;
  for (const auto &exp : expected) {
    assert_token(tokens[i], exp.type, exp.length, exp.column, exp.line);
    i++;
  }
}

static AstNodePtr parse_test_expr(std::string &input) {
  Tokenizer tokenizer;
  init_tokenizer(tokenizer, "test", input);
  Parser parser = make_parser(input, tokenizer);
  return parser_expr(parser);
}

TEST(ParserTest, ParsesAtomExpressions) {
  std::string number_input = "123.45";
  auto number_node = parse_test_expr(number_input);
  ASSERT_EQ(number_node->tag, AstTag::NumberLiteral);
  auto *number = dynamic_cast<NumberLiteral *>(number_node.get());
  ASSERT_NE(number, nullptr);
  EXPECT_DOUBLE_EQ(number->value, 123.45);

  std::string string_input = "\"hello\"";
  auto string_node = parse_test_expr(string_input);
  ASSERT_EQ(string_node->tag, AstTag::StringLiteral);
  auto *string = dynamic_cast<StringLiteral *>(string_node.get());
  ASSERT_NE(string, nullptr);
  EXPECT_EQ(string->value, "hello");

  std::string bool_input = "true";
  auto bool_node = parse_test_expr(bool_input);
  ASSERT_EQ(bool_node->tag, AstTag::BooleanLiteral);
  auto *boolean = dynamic_cast<BooleanLiteral *>(bool_node.get());
  ASSERT_NE(boolean, nullptr);
  EXPECT_TRUE(boolean->value);

  std::string identifier_input = "patient_age";
  auto identifier_node = parse_test_expr(identifier_input);
  ASSERT_EQ(identifier_node->tag, AstTag::Identifier);
  auto *identifier = dynamic_cast<Identifier *>(identifier_node.get());
  ASSERT_NE(identifier, nullptr);
  EXPECT_EQ(identifier->value, "patient_age");
}

TEST(ParserTest, RejectsEmptyExpression) {
  std::string input;
  EXPECT_THROW(parse_test_expr(input), ParserError);
}

TEST(TokenizerTest, InitTokenizer) {
  char input[] = "some identifier +";

  Tokenizer tokenizer;
  init_tokenizer(tokenizer, "test", input);

  Token token = tokenizer_next_token(tokenizer);
  assert_token(token, Type::Identifier, 4, 1, 1);
  token = tokenizer_next_token(tokenizer);
  assert_token(token, Type::Identifier, 10, 6, 1);
  token = tokenizer_next_token(tokenizer);
  assert_token(token, Type::Plus, 1, 17, 1);

  EXPECT_EQ(token.type, Type::Plus);
  EXPECT_EQ(token.length, 1u);
}

TEST(TokenizerTest, TokenizeNumber) {
  char input[] = "1234";
  Tokenizer tokenizer;
  init_tokenizer(tokenizer, "test", input);

  Token token = tokenizer_next_token(tokenizer);
  assert_token(token, Type::Numtoken, 4, 1, 1);
}

TEST(TokenizerTest, ReadsPlusToken) {
  char input[] = "+";
  Tokenizer tokenizer = {.input_file = "test",
                         .input = input,
                         .pos = 0,
                         .line = 1,
                         .column = 0};

  Token token = tokenizer_next_token(tokenizer);

  EXPECT_EQ(token.type, Type::Plus);
  EXPECT_EQ(token.length, 1u);
}

TEST(TokenizerTest, NextTokenAdvancesPosition) {
  char input[] = "ab";
  Tokenizer tokenizer = {.input_file = "test",
                         .input = input,
                         .pos = 0,
                         .line = 1,
                         .column = 1};

  Token token = tokenizer_next_token(tokenizer);

  EXPECT_EQ(token.type, Type::Identifier);
  EXPECT_EQ(tokenizer.pos, 2u);
  EXPECT_EQ(tokenizer.column, 3u);
}

// --- Ported from OCaml expect tests ---

TEST(TokenizerTest, SimpleOperators) {
  check_tokens("+-*/;:=,()[]&<><=>=<>", {
                                            {Type::Plus, 1, 1, 1},
                                            {Type::Minus, 1, 2, 1},
                                            {Type::Multipy, 1, 3, 1},
                                            {Type::Divide, 1, 4, 1},
                                            {Type::Semicolon, 1, 5, 1},
                                            {Type::Assign, 2, 6, 1},
                                            {Type::Comma, 1, 8, 1},
                                            {Type::Lpar, 1, 9, 1},
                                            {Type::Rpar, 1, 10, 1},
                                            {Type::Lspar, 1, 11, 1},
                                            {Type::Rspar, 1, 12, 1},
                                            {Type::Ampersand, 1, 13, 1},
                                            {Type::Neq, 2, 14, 1},
                                            {Type::Lteq, 2, 16, 1},
                                            {Type::Gteq, 2, 18, 1},
                                            {Type::Neq, 2, 20, 1},
                                        });
}

TEST(TokenizerTest, OperatorsWithWhitespace) {
  check_tokens("  + -   * /    ;", {
                                       {Type::Plus, 1, 3, 1},
                                       {Type::Minus, 1, 5, 1},
                                       {Type::Multipy, 1, 9, 1},
                                       {Type::Divide, 1, 11, 1},
                                       {Type::Semicolon, 1, 16, 1},
                                   });
}

TEST(TokenizerTest, OperatorsWithNewlines) {
  check_tokens("+\n-\n\n*",
               {
                   {.type = Type::Plus, .length = 1, .column = 1, .line = 1},
                   {.type = Type::Minus, .length = 1, .column = 1, .line = 2},
                   {.type = Type::Multipy, .length = 1, .column = 1, .line = 4},
               });
}

TEST(TokenizerTest, IdentifiersAndKeywords) {
  check_tokens("If foo FOR bar", {
                                     {Type::If, 2, 1, 1},
                                     {Type::Identifier, 3, 4, 1},
                                     {Type::For, 3, 8, 1},
                                     {Type::Identifier, 3, 12, 1},
                                 });
}

TEST(TokenizerTest, MixOfEverything) {
  check_tokens(
      "IF + foo;\n  WRITE - bar",
      {
          {.type = Type::If, .length = 2, .column = 1, .line = 1},
          {.type = Type::Plus, .length = 1, .column = 4, .line = 1},
          {.type = Type::Identifier, .length = 3, .column = 6, .line = 1},
          {.type = Type::Semicolon, .length = 1, .column = 9, .line = 1},
          {.type = Type::Write, .length = 5, .column = 3, .line = 2},
          {.type = Type::Minus, .length = 1, .column = 9, .line = 2},
          {.type = Type::Identifier, .length = 3, .column = 11, .line = 2},
      });
}

TEST(TokenizerTest, UnknownCharacters) {
  check_tokens("+ # @ -", {
                              {Type::Plus, 1, 1, 1},
                              {Type::Unknown, 1, 3, 1},
                              {Type::Unknown, 1, 5, 1},
                              {Type::Minus, 1, 7, 1},
                          });
}

TEST(TokenizerTest, Strings) {
  check_tokens(" \"very cool string\" \"another string\" \"another very cool "
               "string\nthat goes over two lines\" IF",
               {
                   {Type::Strtoken, 18, 2, 1},
                   {Type::Strtoken, 16, 21, 1},
                   {Type::Strtoken, 51, 38, 1},
                   {Type::If, 2, 90, 2},
               });
}

TEST(TokenizerTest, NumbersAndTime) {
  check_tokens("123 123.45 12:34 12:34:56", {
                                                {Type::Numtoken, 3, 1, 1},
                                                {Type::Numtoken, 6, 5, 1},
                                                {Type::Timetoken, 5, 12, 1},
                                                {Type::Timetoken, 8, 18, 1},
                                            });
}

TEST(TokenizerTest, PowerTimesPowerTimes) {
  check_tokens("WRITE 1 ** 1;\nWRITE 1 * 1;\nWRITE 1 *** 1;",
               {
                   {Type::Write, 5, 1, 1},
                   {Type::Numtoken, 1, 7, 1},
                   {Type::Power, 2, 9, 1},
                   {Type::Numtoken, 1, 12, 1},
                   {Type::Semicolon, 1, 13, 1},
                   {Type::Write, 5, 1, 2},
                   {Type::Numtoken, 1, 7, 2},
                   {Type::Multipy, 1, 9, 2},
                   {Type::Numtoken, 1, 11, 2},
                   {Type::Semicolon, 1, 12, 2},
                   {Type::Write, 5, 1, 3},
                   {Type::Numtoken, 1, 7, 3},
                   {Type::Power, 2, 9, 3},
                   {Type::Multipy, 1, 11, 3},
                   {Type::Numtoken, 1, 13, 3},
                   {Type::Semicolon, 1, 14, 3},
               });
}

TEST(TokenizerTest, WeirdKeywordCapitalization) {
  check_tokens("wRite 1 ** 1;\n thEN 1 * 1;\n Identifier 1 *** 1;",
               {
                   {Type::Write, 5, 1, 1},
                   {Type::Numtoken, 1, 7, 1},
                   {Type::Power, 2, 9, 1},
                   {Type::Numtoken, 1, 12, 1},
                   {Type::Semicolon, 1, 13, 1},
                   {Type::Then, 4, 2, 2},
                   {Type::Numtoken, 1, 7, 2},
                   {Type::Multipy, 1, 9, 2},
                   {Type::Numtoken, 1, 11, 2},
                   {Type::Semicolon, 1, 12, 2},
                   {Type::Identifier, 10, 2, 3},
                   {Type::Numtoken, 1, 13, 3},
                   {Type::Power, 2, 15, 3},
                   {Type::Multipy, 1, 17, 3},
                   {Type::Numtoken, 1, 19, 3},
                   {Type::Semicolon, 1, 20, 3},
               });
}

TEST(TokenizerTest, ComplexListExpression) {
  check_tokens(
      "x := [\"Hallo Welt\", null, 4711, 2020-01-01T12:30:00, false, now];",
      {
          {.type = Type::Identifier, .length = 1, .column = 1, .line = 1},
          {.type = Type::Assign, .length = 2, .column = 3, .line = 1},
          {.type = Type::Lspar, .length = 1, .column = 6, .line = 1},
          {.type = Type::Strtoken, .length = 12, .column = 7, .line = 1},
          {.type = Type::Comma, .length = 1, .column = 19, .line = 1},
          {.type = Type::Null, .length = 4, .column = 21, .line = 1},
          {.type = Type::Comma, .length = 1, .column = 25, .line = 1},
          {.type = Type::Numtoken, .length = 4, .column = 27, .line = 1},
          {.type = Type::Comma, .length = 1, .column = 31, .line = 1},
          {.type = Type::Timetoken, .length = 19, .column = 33, .line = 1},
          {.type = Type::Comma, .length = 1, .column = 52, .line = 1},
          {.type = Type::False, .length = 5, .column = 54, .line = 1},
          {.type = Type::Comma, .length = 1, .column = 59, .line = 1},
          {.type = Type::Now, .length = 3, .column = 61, .line = 1},
          {.type = Type::Rspar, .length = 1, .column = 64, .line = 1},
          {.type = Type::Semicolon, .length = 1, .column = 65, .line = 1},
      });
}

TEST(TokenizerTest, Comments) {
  check_tokens("1 // comment\n2", {
                                      {Type::Numtoken, 1, 1, 1},
                                      {Type::Numtoken, 1, 1, 2},
                                  });
}

TEST(TokenizerTest, FullProgram) {
  check_tokens(
      "x := [\"Hallo Welt\", null, 4711, 2020-01-01T12:30:00, false, now];\n"
      "trace x;\n"
      "trace x is number;\n"
      "trace 1 + 2 * 4 / 5 - -3 + 4 ** 3 ** 2;\n"
      "trace -2 ** 10;\n"
      "y := [100,200,150];\n"
      "trace [maximum y, average y, increase y];\n"
      "trace uppercase [\"Hallo\", \"Welt\", 4711];\n"
      "trace sqrt y;\n"
      "x := 1 ... 7;\n"
      "trace x;\n"
      "trace x < 5;\n"
      "trace x is not within (x - 1) to 5;\n"
      "trace \"Hallo\" where it is not number;\n"
      "trace [10,20,50,100,70,40,55] where it / 2 is within 30 to 60;\n"
      "x := 4711;\n"
      "time of x := 1999-09-19;\n"
      "// Kopie von x\n"
      "y := x;\n"
      "time of y := 2022-12-22;\n"
      "trace time of x;\n"
      "trace time of y;\n"
      "trace time of time of y;",
      {
          {Type::Identifier, 1, 1, 1},   {Type::Assign, 2, 3, 1},
          {Type::Lspar, 1, 6, 1},        {Type::Strtoken, 12, 7, 1},
          {Type::Comma, 1, 19, 1},       {Type::Null, 4, 21, 1},
          {Type::Comma, 1, 25, 1},       {Type::Numtoken, 4, 27, 1},
          {Type::Comma, 1, 31, 1},       {Type::Timetoken, 19, 33, 1},
          {Type::Comma, 1, 52, 1},       {Type::False, 5, 54, 1},
          {Type::Comma, 1, 59, 1},       {Type::Now, 3, 61, 1},
          {Type::Rspar, 1, 64, 1},       {Type::Semicolon, 1, 65, 1},
          {Type::Trace, 5, 1, 2},        {Type::Identifier, 1, 7, 2},
          {Type::Semicolon, 1, 8, 2},    {Type::Trace, 5, 1, 3},
          {Type::Identifier, 1, 7, 3},   {Type::Is, 2, 9, 3},
          {Type::Numbertype, 6, 12, 3},  {Type::Semicolon, 1, 18, 3},
          {Type::Trace, 5, 1, 4},        {Type::Numtoken, 1, 7, 4},
          {Type::Plus, 1, 9, 4},         {Type::Numtoken, 1, 11, 4},
          {Type::Multipy, 1, 13, 4},       {Type::Numtoken, 1, 15, 4},
          {Type::Divide, 1, 17, 4},      {Type::Numtoken, 1, 19, 4},
          {Type::Minus, 1, 21, 4},       {Type::Minus, 1, 23, 4},
          {Type::Numtoken, 1, 24, 4},    {Type::Plus, 1, 26, 4},
          {Type::Numtoken, 1, 28, 4},    {Type::Power, 2, 30, 4},
          {Type::Numtoken, 1, 33, 4},    {Type::Power, 2, 35, 4},
          {Type::Numtoken, 1, 38, 4},    {Type::Semicolon, 1, 39, 4},
          {Type::Trace, 5, 1, 5},        {Type::Minus, 1, 7, 5},
          {Type::Numtoken, 1, 8, 5},     {Type::Power, 2, 10, 5},
          {Type::Numtoken, 2, 13, 5},    {Type::Semicolon, 1, 15, 5},
          {Type::Identifier, 1, 1, 6},   {Type::Assign, 2, 3, 6},
          {Type::Lspar, 1, 6, 6},        {Type::Numtoken, 3, 7, 6},
          {Type::Comma, 1, 10, 6},       {Type::Numtoken, 3, 11, 6},
          {Type::Comma, 1, 14, 6},       {Type::Numtoken, 3, 15, 6},
          {Type::Rspar, 1, 18, 6},       {Type::Semicolon, 1, 19, 6},
          {Type::Trace, 5, 1, 7},        {Type::Lspar, 1, 7, 7},
          {Type::Maximum, 7, 8, 7},      {Type::Identifier, 1, 16, 7},
          {Type::Comma, 1, 17, 7},       {Type::Average, 7, 19, 7},
          {Type::Identifier, 1, 27, 7},  {Type::Comma, 1, 28, 7},
          {Type::Increase, 8, 30, 7},    {Type::Identifier, 1, 39, 7},
          {Type::Rspar, 1, 40, 7},       {Type::Semicolon, 1, 41, 7},
          {Type::Trace, 5, 1, 8},        {Type::Uppercase, 9, 7, 8},
          {Type::Lspar, 1, 17, 8},       {Type::Strtoken, 7, 18, 8},
          {Type::Comma, 1, 25, 8},       {Type::Strtoken, 6, 27, 8},
          {Type::Comma, 1, 33, 8},       {Type::Numtoken, 4, 35, 8},
          {Type::Rspar, 1, 39, 8},       {Type::Semicolon, 1, 40, 8},
          {Type::Trace, 5, 1, 9},        {Type::Sqrt, 4, 7, 9},
          {Type::Identifier, 1, 12, 9},  {Type::Semicolon, 1, 13, 9},
          {Type::Identifier, 1, 1, 10},  {Type::Assign, 2, 3, 10},
          {Type::Numtoken, 1, 6, 10},    {Type::Range, 3, 8, 10},
          {Type::Numtoken, 1, 12, 10},   {Type::Semicolon, 1, 13, 10},
          {Type::Trace, 5, 1, 11},       {Type::Identifier, 1, 7, 11},
          {Type::Semicolon, 1, 8, 11},   {Type::Trace, 5, 1, 12},
          {Type::Identifier, 1, 7, 12},  {Type::Lt, 1, 9, 12},
          {Type::Numtoken, 1, 11, 12},   {Type::Semicolon, 1, 12, 12},
          {Type::Trace, 5, 1, 13},       {Type::Identifier, 1, 7, 13},
          {Type::Is, 2, 9, 13},          {Type::Not, 3, 12, 13},
          {Type::Within, 6, 16, 13},     {Type::Lpar, 1, 23, 13},
          {Type::Identifier, 1, 24, 13}, {Type::Minus, 1, 26, 13},
          {Type::Numtoken, 1, 28, 13},   {Type::Rpar, 1, 29, 13},
          {Type::To, 2, 31, 13},         {Type::Numtoken, 1, 34, 13},
          {Type::Semicolon, 1, 35, 13},  {Type::Trace, 5, 1, 14},
          {Type::Strtoken, 7, 7, 14},    {Type::Where, 5, 15, 14},
          {Type::Identifier, 2, 21, 14}, {Type::Is, 2, 24, 14},
          {Type::Not, 3, 27, 14},        {Type::Numbertype, 6, 31, 14},
          {Type::Semicolon, 1, 37, 14},  {Type::Trace, 5, 1, 15},
          {Type::Lspar, 1, 7, 15},       {Type::Numtoken, 2, 8, 15},
          {Type::Comma, 1, 10, 15},      {Type::Numtoken, 2, 11, 15},
          {Type::Comma, 1, 13, 15},      {Type::Numtoken, 2, 14, 15},
          {Type::Comma, 1, 16, 15},      {Type::Numtoken, 3, 17, 15},
          {Type::Comma, 1, 20, 15},      {Type::Numtoken, 2, 21, 15},
          {Type::Comma, 1, 23, 15},      {Type::Numtoken, 2, 24, 15},
          {Type::Comma, 1, 26, 15},      {Type::Numtoken, 2, 27, 15},
          {Type::Rspar, 1, 29, 15},      {Type::Where, 5, 31, 15},
          {Type::Identifier, 2, 37, 15}, {Type::Divide, 1, 40, 15},
          {Type::Numtoken, 1, 42, 15},   {Type::Is, 2, 44, 15},
          {Type::Within, 6, 47, 15},     {Type::Numtoken, 2, 54, 15},
          {Type::To, 2, 57, 15},         {Type::Numtoken, 2, 60, 15},
          {Type::Semicolon, 1, 62, 15},  {Type::Identifier, 1, 1, 16},
          {Type::Assign, 2, 3, 16},      {Type::Numtoken, 4, 6, 16},
          {Type::Semicolon, 1, 10, 16},  {Type::Time, 4, 1, 17},
          {Type::Of, 2, 6, 17},          {Type::Identifier, 1, 9, 17},
          {Type::Assign, 2, 11, 17},     {Type::Timetoken, 10, 14, 17},
          {Type::Semicolon, 1, 24, 17},  {Type::Identifier, 1, 1, 19},
          {Type::Assign, 2, 3, 19},      {Type::Identifier, 1, 6, 19},
          {Type::Semicolon, 1, 7, 19},   {Type::Time, 4, 1, 20},
          {Type::Of, 2, 6, 20},          {Type::Identifier, 1, 9, 20},
          {Type::Assign, 2, 11, 20},     {Type::Timetoken, 10, 14, 20},
          {Type::Semicolon, 1, 24, 20},  {Type::Trace, 5, 1, 21},
          {Type::Time, 4, 7, 21},        {Type::Of, 2, 12, 21},
          {Type::Identifier, 1, 15, 21}, {Type::Semicolon, 1, 16, 21},
          {Type::Trace, 5, 1, 22},       {Type::Time, 4, 7, 22},
          {Type::Of, 2, 12, 22},         {Type::Identifier, 1, 15, 22},
          {Type::Semicolon, 1, 16, 22},  {Type::Trace, 5, 1, 23},
          {Type::Time, 4, 7, 23},        {Type::Of, 2, 12, 23},
          {Type::Time, 4, 15, 23},       {Type::Of, 2, 20, 23},
          {Type::Identifier, 1, 23, 23}, {Type::Semicolon, 1, 24, 23},
      });
}

TEST(TokenizerTest, RangeOperator) {
  check_tokens("x := 1 ... 7;", {
                                    {Type::Identifier, 1, 1, 1},
                                    {Type::Assign, 2, 3, 1},
                                    {Type::Numtoken, 1, 6, 1},
                                    {Type::Range, 3, 8, 1},
                                    {Type::Numtoken, 1, 12, 1},
                                    {Type::Semicolon, 1, 13, 1},
                                });
}

TEST(TokenizerTest, DotOperator) {
  check_tokens("123.456", {
                              {Type::Numtoken, 7, 1, 1},
                          });
}
