#include <cstdio>
#include <cstring>
#include <vector>
extern "C" {
#include "tokenizer.h"
}

#include <gtest/gtest.h>

struct TokenExpect {
  int type;
  size_t length;
  size_t column;
  size_t line;
};

static std::vector<Token> tokenize_all(const char *input,
                                       size_t max_tokens = 2048) {
  FILE *f = fmemopen((void *)input, strlen(input), "r");
  Tokenizer tokenizer;
  if (!init_tokenizer(&tokenizer, "test", f)) {
    return {};
  }
  std::vector<Token> tokens;
  tokens.reserve(max_tokens);
  for (size_t i = 0; i < max_tokens; i++) {
    Token t = get_next_token(&tokenizer);
    if (t.type == TOKEN_EOF)
      break;
    tokens.push_back(t);
  }
  return tokens;
}

static void assert_token(const Token &actual, int type, size_t length,
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

TEST(TokenizerTest, InitTokenizer) {
  char input[] = "some identifier +";
  size_t input_len = sizeof(input);
  FILE *f = fmemopen((void *)input, input_len, "r");

  Tokenizer tokenizer;
  if (!init_tokenizer(&tokenizer, "test", f)) {
    FAIL() << "Failed to initialize tokenizer";
  }

  Token token = get_next_token(&tokenizer);
  assert_token(token, TOKEN_IDENTIFIER, 4, 1, 1);
  token = get_next_token(&tokenizer);
  assert_token(token, TOKEN_IDENTIFIER, 10, 6, 1);
  token = get_next_token(&tokenizer);
  assert_token(token, TOKEN_PLUS, 1, 17, 1);

  EXPECT_EQ(token.type, TOKEN_PLUS);
  EXPECT_EQ(token.length, 1u);
}

TEST(TokenizerTest, TokenizeNumber) {
  char input[] = "1234";
  size_t input_len = sizeof(input);
  FILE *f = fmemopen(input, input_len, "r");
  Tokenizer tokenizer;
  if (!init_tokenizer(&tokenizer, "test", f)) {
    FAIL();
  }

  Token token = get_next_token(&tokenizer);
  assert_token(token, TOKEN_NUMTOKEN, 4, 1, 1);
}

TEST(TokenizerTest, ReadsPlusToken) {
  char input[] = "+";
  Tokenizer tokenizer = {.input_file = "test",
                         .input = input,
                         .input_len = sizeof(input) - 1,
                         .pos = 0,
                         .line = 1,
                         .column = 0};

  Token token = get_next_token(&tokenizer);

  EXPECT_EQ(token.type, TOKEN_PLUS);
  EXPECT_EQ(token.length, 1u);
}

TEST(TokenizerTest, PeekDoesNotAdvance) {
  char input[] = "ab";
  Tokenizer tokenizer = {.input_file = "test",
                         .input = input,
                         .input_len = sizeof(input) - 1,
                         .pos = 0,
                         .line = 1,
                         .column = 1};

  EXPECT_EQ(tokenizer_peek(&tokenizer), 'a');
  EXPECT_EQ(tokenizer.pos, 0u);
  EXPECT_EQ(tokenizer.column, 1u);
}

// --- Ported from OCaml expect tests ---

TEST(TokenizerTest, SimpleOperators) {
  check_tokens("+-*/;:=,()[]&<><=>=<>", {
                                            {TOKEN_PLUS, 1, 1, 1},
                                            {TOKEN_MINUS, 1, 2, 1},
                                            {TOKEN_TIMES, 1, 3, 1},
                                            {TOKEN_DIVIDE, 1, 4, 1},
                                            {TOKEN_SEMICOLON, 1, 5, 1},
                                            {TOKEN_ASSIGN, 2, 6, 1},
                                            {TOKEN_COMMA, 1, 8, 1},
                                            {TOKEN_LPAR, 1, 9, 1},
                                            {TOKEN_RPAR, 1, 10, 1},
                                            {TOKEN_LSPAR, 1, 11, 1},
                                            {TOKEN_RSPAR, 1, 12, 1},
                                            {TOKEN_AMPERSAND, 1, 13, 1},
                                            {TOKEN_NEQ, 2, 14, 1},
                                            {TOKEN_LTEQ, 2, 16, 1},
                                            {TOKEN_GTEQ, 2, 18, 1},
                                            {TOKEN_NEQ, 2, 20, 1},
                                        });
}

TEST(TokenizerTest, OperatorsWithWhitespace) {
  check_tokens("  + -   * /    ;", {
                                       {TOKEN_PLUS, 1, 3, 1},
                                       {TOKEN_MINUS, 1, 5, 1},
                                       {TOKEN_TIMES, 1, 9, 1},
                                       {TOKEN_DIVIDE, 1, 11, 1},
                                       {TOKEN_SEMICOLON, 1, 16, 1},
                                   });
}

TEST(TokenizerTest, OperatorsWithNewlines) {
  check_tokens("+\n-\n\n*",
               {
                   {.type = TOKEN_PLUS, .length = 1, .column = 1, .line = 1},
                   {.type = TOKEN_MINUS, .length = 1, .column = 1, .line = 2},
                   {.type = TOKEN_TIMES, .length = 1, .column = 1, .line = 4},
               });
}

TEST(TokenizerTest, IdentifiersAndKeywords) {
  check_tokens("If foo FOR bar", {
                                     {TOKEN_IF, 2, 1, 1},
                                     {TOKEN_IDENTIFIER, 3, 4, 1},
                                     {TOKEN_FOR, 3, 8, 1},
                                     {TOKEN_IDENTIFIER, 3, 12, 1},
                                 });
}

TEST(TokenizerTest, MixOfEverything) {
  check_tokens(
      "IF + foo;\n  WRITE - bar",
      {
          {.type = TOKEN_IF, .length = 2, .column = 1, .line = 1},
          {.type = TOKEN_PLUS, .length = 1, .column = 4, .line = 1},
          {.type = TOKEN_IDENTIFIER, .length = 3, .column = 6, .line = 1},
          {.type = TOKEN_SEMICOLON, .length = 1, .column = 9, .line = 1},
          {.type = TOKEN_WRITE, .length = 5, .column = 3, .line = 2},
          {.type = TOKEN_MINUS, .length = 1, .column = 9, .line = 2},
          {.type = TOKEN_IDENTIFIER, .length = 3, .column = 11, .line = 2},
      });
}

TEST(TokenizerTest, UnknownCharacters) {
  check_tokens("+ # @ -", {
                              {TOKEN_PLUS, 1, 1, 1},
                              {TOKEN_UNKNOWN, 1, 3, 1},
                              {TOKEN_UNKNOWN, 1, 5, 1},
                              {TOKEN_MINUS, 1, 7, 1},
                          });
}

TEST(TokenizerTest, Strings) {
  check_tokens(" \"very cool string\" \"another string\" \"another very cool "
               "string\nthat goes over two lines\" IF",
               {
                   {TOKEN_STRTOKEN, 18, 2, 1},
                   {TOKEN_STRTOKEN, 16, 21, 1},
                   {TOKEN_STRTOKEN, 51, 38, 1},
                   {TOKEN_IF, 2, 90, 2},
               });
}

TEST(TokenizerTest, NumbersAndTime) {
  check_tokens("123 123.45 12:34 12:34:56", {
                                                {TOKEN_NUMTOKEN, 3, 1, 1},
                                                {TOKEN_NUMTOKEN, 6, 5, 1},
                                                {TOKEN_TIMETOKEN, 5, 12, 1},
                                                {TOKEN_TIMETOKEN, 8, 18, 1},
                                            });
}

TEST(TokenizerTest, PowerTimesPowerTimes) {
  check_tokens("WRITE 1 ** 1;\nWRITE 1 * 1;\nWRITE 1 *** 1;",
               {
                   {TOKEN_WRITE, 5, 1, 1},
                   {TOKEN_NUMTOKEN, 1, 7, 1},
                   {TOKEN_POWER, 2, 9, 1},
                   {TOKEN_NUMTOKEN, 1, 12, 1},
                   {TOKEN_SEMICOLON, 1, 13, 1},
                   {TOKEN_WRITE, 5, 1, 2},
                   {TOKEN_NUMTOKEN, 1, 7, 2},
                   {TOKEN_TIMES, 1, 9, 2},
                   {TOKEN_NUMTOKEN, 1, 11, 2},
                   {TOKEN_SEMICOLON, 1, 12, 2},
                   {TOKEN_WRITE, 5, 1, 3},
                   {TOKEN_NUMTOKEN, 1, 7, 3},
                   {TOKEN_POWER, 2, 9, 3},
                   {TOKEN_TIMES, 1, 11, 3},
                   {TOKEN_NUMTOKEN, 1, 13, 3},
                   {TOKEN_SEMICOLON, 1, 14, 3},
               });
}

TEST(TokenizerTest, WeirdKeywordCapitalization) {
  check_tokens("wRite 1 ** 1;\n thEN 1 * 1;\n Identifier 1 *** 1;",
               {
                   {TOKEN_WRITE, 5, 1, 1},
                   {TOKEN_NUMTOKEN, 1, 7, 1},
                   {TOKEN_POWER, 2, 9, 1},
                   {TOKEN_NUMTOKEN, 1, 12, 1},
                   {TOKEN_SEMICOLON, 1, 13, 1},
                   {TOKEN_THEN, 4, 2, 2},
                   {TOKEN_NUMTOKEN, 1, 7, 2},
                   {TOKEN_TIMES, 1, 9, 2},
                   {TOKEN_NUMTOKEN, 1, 11, 2},
                   {TOKEN_SEMICOLON, 1, 12, 2},
                   {TOKEN_IDENTIFIER, 10, 2, 3},
                   {TOKEN_NUMTOKEN, 1, 13, 3},
                   {TOKEN_POWER, 2, 15, 3},
                   {TOKEN_TIMES, 1, 17, 3},
                   {TOKEN_NUMTOKEN, 1, 19, 3},
                   {TOKEN_SEMICOLON, 1, 20, 3},
               });
}

TEST(TokenizerTest, ComplexListExpression) {
  check_tokens(
      "x := [\"Hallo Welt\", null, 4711, 2020-01-01T12:30:00, false, now];",
      {
          {.type = TOKEN_IDENTIFIER, .length = 1, .column = 1, .line = 1},
          {.type = TOKEN_ASSIGN, .length = 2, .column = 3, .line = 1},
          {.type = TOKEN_LSPAR, .length = 1, .column = 6, .line = 1},
          {.type = TOKEN_STRTOKEN, .length = 12, .column = 7, .line = 1},
          {.type = TOKEN_COMMA, .length = 1, .column = 19, .line = 1},
          {.type = TOKEN_NULL, .length = 4, .column = 21, .line = 1},
          {.type = TOKEN_COMMA, .length = 1, .column = 25, .line = 1},
          {.type = TOKEN_NUMTOKEN, .length = 4, .column = 27, .line = 1},
          {.type = TOKEN_COMMA, .length = 1, .column = 31, .line = 1},
          {.type = TOKEN_TIMETOKEN, .length = 19, .column = 33, .line = 1},
          {.type = TOKEN_COMMA, .length = 1, .column = 52, .line = 1},
          {.type = TOKEN_FALSE, .length = 5, .column = 54, .line = 1},
          {.type = TOKEN_COMMA, .length = 1, .column = 59, .line = 1},
          {.type = TOKEN_NOW, .length = 3, .column = 61, .line = 1},
          {.type = TOKEN_RSPAR, .length = 1, .column = 64, .line = 1},
          {.type = TOKEN_SEMICOLON, .length = 1, .column = 65, .line = 1},
      });
}

TEST(TokenizerTest, Comments) {
  check_tokens("1 // comment\n2", {
                                      {TOKEN_NUMTOKEN, 1, 1, 1},
                                      {TOKEN_NUMTOKEN, 1, 1, 2},
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
          {TOKEN_IDENTIFIER, 1, 1, 1},   {TOKEN_ASSIGN, 2, 3, 1},
          {TOKEN_LSPAR, 1, 6, 1},        {TOKEN_STRTOKEN, 12, 7, 1},
          {TOKEN_COMMA, 1, 19, 1},       {TOKEN_NULL, 4, 21, 1},
          {TOKEN_COMMA, 1, 25, 1},       {TOKEN_NUMTOKEN, 4, 27, 1},
          {TOKEN_COMMA, 1, 31, 1},       {TOKEN_TIMETOKEN, 19, 33, 1},
          {TOKEN_COMMA, 1, 52, 1},       {TOKEN_FALSE, 5, 54, 1},
          {TOKEN_COMMA, 1, 59, 1},       {TOKEN_NOW, 3, 61, 1},
          {TOKEN_RSPAR, 1, 64, 1},       {TOKEN_SEMICOLON, 1, 65, 1},
          {TOKEN_TRACE, 5, 1, 2},        {TOKEN_IDENTIFIER, 1, 7, 2},
          {TOKEN_SEMICOLON, 1, 8, 2},    {TOKEN_TRACE, 5, 1, 3},
          {TOKEN_IDENTIFIER, 1, 7, 3},   {TOKEN_IS, 2, 9, 3},
          {TOKEN_NUMBERTYPE, 6, 12, 3},  {TOKEN_SEMICOLON, 1, 18, 3},
          {TOKEN_TRACE, 5, 1, 4},        {TOKEN_NUMTOKEN, 1, 7, 4},
          {TOKEN_PLUS, 1, 9, 4},         {TOKEN_NUMTOKEN, 1, 11, 4},
          {TOKEN_TIMES, 1, 13, 4},       {TOKEN_NUMTOKEN, 1, 15, 4},
          {TOKEN_DIVIDE, 1, 17, 4},      {TOKEN_NUMTOKEN, 1, 19, 4},
          {TOKEN_MINUS, 1, 21, 4},       {TOKEN_MINUS, 1, 23, 4},
          {TOKEN_NUMTOKEN, 1, 24, 4},    {TOKEN_PLUS, 1, 26, 4},
          {TOKEN_NUMTOKEN, 1, 28, 4},    {TOKEN_POWER, 2, 30, 4},
          {TOKEN_NUMTOKEN, 1, 33, 4},    {TOKEN_POWER, 2, 35, 4},
          {TOKEN_NUMTOKEN, 1, 38, 4},    {TOKEN_SEMICOLON, 1, 39, 4},
          {TOKEN_TRACE, 5, 1, 5},        {TOKEN_MINUS, 1, 7, 5},
          {TOKEN_NUMTOKEN, 1, 8, 5},     {TOKEN_POWER, 2, 10, 5},
          {TOKEN_NUMTOKEN, 2, 13, 5},    {TOKEN_SEMICOLON, 1, 15, 5},
          {TOKEN_IDENTIFIER, 1, 1, 6},   {TOKEN_ASSIGN, 2, 3, 6},
          {TOKEN_LSPAR, 1, 6, 6},        {TOKEN_NUMTOKEN, 3, 7, 6},
          {TOKEN_COMMA, 1, 10, 6},       {TOKEN_NUMTOKEN, 3, 11, 6},
          {TOKEN_COMMA, 1, 14, 6},       {TOKEN_NUMTOKEN, 3, 15, 6},
          {TOKEN_RSPAR, 1, 18, 6},       {TOKEN_SEMICOLON, 1, 19, 6},
          {TOKEN_TRACE, 5, 1, 7},        {TOKEN_LSPAR, 1, 7, 7},
          {TOKEN_MAXIMUM, 7, 8, 7},      {TOKEN_IDENTIFIER, 1, 16, 7},
          {TOKEN_COMMA, 1, 17, 7},       {TOKEN_AVERAGE, 7, 19, 7},
          {TOKEN_IDENTIFIER, 1, 27, 7},  {TOKEN_COMMA, 1, 28, 7},
          {TOKEN_INCREASE, 8, 30, 7},    {TOKEN_IDENTIFIER, 1, 39, 7},
          {TOKEN_RSPAR, 1, 40, 7},       {TOKEN_SEMICOLON, 1, 41, 7},
          {TOKEN_TRACE, 5, 1, 8},        {TOKEN_UPPERCASE, 9, 7, 8},
          {TOKEN_LSPAR, 1, 17, 8},       {TOKEN_STRTOKEN, 7, 18, 8},
          {TOKEN_COMMA, 1, 25, 8},       {TOKEN_STRTOKEN, 6, 27, 8},
          {TOKEN_COMMA, 1, 33, 8},       {TOKEN_NUMTOKEN, 4, 35, 8},
          {TOKEN_RSPAR, 1, 39, 8},       {TOKEN_SEMICOLON, 1, 40, 8},
          {TOKEN_TRACE, 5, 1, 9},        {TOKEN_SQRT, 4, 7, 9},
          {TOKEN_IDENTIFIER, 1, 12, 9},  {TOKEN_SEMICOLON, 1, 13, 9},
          {TOKEN_IDENTIFIER, 1, 1, 10},  {TOKEN_ASSIGN, 2, 3, 10},
          {TOKEN_NUMTOKEN, 1, 6, 10},    {TOKEN_RANGE, 3, 8, 10},
          {TOKEN_NUMTOKEN, 1, 12, 10},   {TOKEN_SEMICOLON, 1, 13, 10},
          {TOKEN_TRACE, 5, 1, 11},       {TOKEN_IDENTIFIER, 1, 7, 11},
          {TOKEN_SEMICOLON, 1, 8, 11},   {TOKEN_TRACE, 5, 1, 12},
          {TOKEN_IDENTIFIER, 1, 7, 12},  {TOKEN_LT, 1, 9, 12},
          {TOKEN_NUMTOKEN, 1, 11, 12},   {TOKEN_SEMICOLON, 1, 12, 12},
          {TOKEN_TRACE, 5, 1, 13},       {TOKEN_IDENTIFIER, 1, 7, 13},
          {TOKEN_IS, 2, 9, 13},          {TOKEN_NOT, 3, 12, 13},
          {TOKEN_WITHIN, 6, 16, 13},     {TOKEN_LPAR, 1, 23, 13},
          {TOKEN_IDENTIFIER, 1, 24, 13}, {TOKEN_MINUS, 1, 26, 13},
          {TOKEN_NUMTOKEN, 1, 28, 13},   {TOKEN_RPAR, 1, 29, 13},
          {TOKEN_TO, 2, 31, 13},         {TOKEN_NUMTOKEN, 1, 34, 13},
          {TOKEN_SEMICOLON, 1, 35, 13},  {TOKEN_TRACE, 5, 1, 14},
          {TOKEN_STRTOKEN, 7, 7, 14},    {TOKEN_WHERE, 5, 15, 14},
          {TOKEN_IDENTIFIER, 2, 21, 14}, {TOKEN_IS, 2, 24, 14},
          {TOKEN_NOT, 3, 27, 14},        {TOKEN_NUMBERTYPE, 6, 31, 14},
          {TOKEN_SEMICOLON, 1, 37, 14},  {TOKEN_TRACE, 5, 1, 15},
          {TOKEN_LSPAR, 1, 7, 15},       {TOKEN_NUMTOKEN, 2, 8, 15},
          {TOKEN_COMMA, 1, 10, 15},      {TOKEN_NUMTOKEN, 2, 11, 15},
          {TOKEN_COMMA, 1, 13, 15},      {TOKEN_NUMTOKEN, 2, 14, 15},
          {TOKEN_COMMA, 1, 16, 15},      {TOKEN_NUMTOKEN, 3, 17, 15},
          {TOKEN_COMMA, 1, 20, 15},      {TOKEN_NUMTOKEN, 2, 21, 15},
          {TOKEN_COMMA, 1, 23, 15},      {TOKEN_NUMTOKEN, 2, 24, 15},
          {TOKEN_COMMA, 1, 26, 15},      {TOKEN_NUMTOKEN, 2, 27, 15},
          {TOKEN_RSPAR, 1, 29, 15},      {TOKEN_WHERE, 5, 31, 15},
          {TOKEN_IDENTIFIER, 2, 37, 15}, {TOKEN_DIVIDE, 1, 40, 15},
          {TOKEN_NUMTOKEN, 1, 42, 15},   {TOKEN_IS, 2, 44, 15},
          {TOKEN_WITHIN, 6, 47, 15},     {TOKEN_NUMTOKEN, 2, 54, 15},
          {TOKEN_TO, 2, 57, 15},         {TOKEN_NUMTOKEN, 2, 60, 15},
          {TOKEN_SEMICOLON, 1, 62, 15},  {TOKEN_IDENTIFIER, 1, 1, 16},
          {TOKEN_ASSIGN, 2, 3, 16},      {TOKEN_NUMTOKEN, 4, 6, 16},
          {TOKEN_SEMICOLON, 1, 10, 16},  {TOKEN_TIME, 4, 1, 17},
          {TOKEN_OF, 2, 6, 17},          {TOKEN_IDENTIFIER, 1, 9, 17},
          {TOKEN_ASSIGN, 2, 11, 17},     {TOKEN_TIMETOKEN, 10, 14, 17},
          {TOKEN_SEMICOLON, 1, 24, 17},  {TOKEN_IDENTIFIER, 1, 1, 19},
          {TOKEN_ASSIGN, 2, 3, 19},      {TOKEN_IDENTIFIER, 1, 6, 19},
          {TOKEN_SEMICOLON, 1, 7, 19},   {TOKEN_TIME, 4, 1, 20},
          {TOKEN_OF, 2, 6, 20},          {TOKEN_IDENTIFIER, 1, 9, 20},
          {TOKEN_ASSIGN, 2, 11, 20},     {TOKEN_TIMETOKEN, 10, 14, 20},
          {TOKEN_SEMICOLON, 1, 24, 20},  {TOKEN_TRACE, 5, 1, 21},
          {TOKEN_TIME, 4, 7, 21},        {TOKEN_OF, 2, 12, 21},
          {TOKEN_IDENTIFIER, 1, 15, 21}, {TOKEN_SEMICOLON, 1, 16, 21},
          {TOKEN_TRACE, 5, 1, 22},       {TOKEN_TIME, 4, 7, 22},
          {TOKEN_OF, 2, 12, 22},         {TOKEN_IDENTIFIER, 1, 15, 22},
          {TOKEN_SEMICOLON, 1, 16, 22},  {TOKEN_TRACE, 5, 1, 23},
          {TOKEN_TIME, 4, 7, 23},        {TOKEN_OF, 2, 12, 23},
          {TOKEN_TIME, 4, 15, 23},       {TOKEN_OF, 2, 20, 23},
          {TOKEN_IDENTIFIER, 1, 23, 23}, {TOKEN_SEMICOLON, 1, 24, 23},
      });
}

TEST(TokenizerTest, RangeOperator) {
  check_tokens("x := 1 ... 7;", {
                                    {TOKEN_IDENTIFIER, 1, 1, 1},
                                    {TOKEN_ASSIGN, 2, 3, 1},
                                    {TOKEN_NUMTOKEN, 1, 6, 1},
                                    {TOKEN_RANGE, 3, 8, 1},
                                    {TOKEN_NUMTOKEN, 1, 12, 1},
                                    {TOKEN_SEMICOLON, 1, 13, 1},
                                });
}

TEST(TokenizerTest, DotOperator) {
  check_tokens("123.456", {
                              {TOKEN_NUMTOKEN, 7, 1, 1},
                          });
}
