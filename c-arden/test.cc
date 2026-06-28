#include "interpreter.hh"
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

static AstNodePtr parse_test_statement_block(std::string &input) {
  Tokenizer tokenizer;
  init_tokenizer(tokenizer, "test", input);
  Parser parser = make_parser(input, tokenizer);
  return parse_statement_block(parser);
}

static AstNodePtr parse_test_statement(std::string &input) {
  Tokenizer tokenizer;
  init_tokenizer(tokenizer, "test", input);
  Parser parser = make_parser(input, tokenizer);
  return parse_statement(parser);
}

static NumberLiteral *expect_number(AstNode *node, double value) {
  EXPECT_EQ(node->tag, AstTag::NumberLiteral);
  auto *number = dynamic_cast<NumberLiteral *>(node);
  EXPECT_NE(number, nullptr);
  if (number != nullptr) {
    EXPECT_DOUBLE_EQ(number->value, value);
  }
  return number;
}

static IdentifierExression *expect_identifier(AstNode *node,
                                              std::string_view value) {
  EXPECT_EQ(node->tag, AstTag::Identifier);
  auto *identifier = dynamic_cast<IdentifierExression *>(node);
  EXPECT_NE(identifier, nullptr);
  if (identifier != nullptr) {
    EXPECT_EQ(identifier->value, value);
  }
  return identifier;
}

static FunctionCallExpression *
expect_function_call(AstNode *node, std::string_view name, size_t arg_count) {
  EXPECT_EQ(node->tag, AstTag::FunctionCallExpression);
  auto *function_call = dynamic_cast<FunctionCallExpression *>(node);
  EXPECT_NE(function_call, nullptr);
  if (function_call != nullptr) {
    expect_identifier(function_call->function_name_identifier.get(), name);
    EXPECT_EQ(function_call->args.size(), arg_count);
  }
  return function_call;
}

static InfixExpression *expect_infix(AstNode *node, Operator op) {
  EXPECT_EQ(node->tag, AstTag::InfixExpression);
  auto *infix = dynamic_cast<InfixExpression *>(node);
  EXPECT_NE(infix, nullptr);
  if (infix != nullptr) {
    EXPECT_EQ(infix->op, op);
  }
  return infix;
}

static PrefixExpression *expect_prefix(AstNode *node, Operator op) {
  EXPECT_EQ(node->tag, AstTag::PrefixExpression);
  auto *prefix = dynamic_cast<PrefixExpression *>(node);
  EXPECT_NE(prefix, nullptr);
  if (prefix != nullptr) {
    EXPECT_EQ(prefix->op, op);
  }
  return prefix;
}

static PostfixExpression *expect_postfix(AstNode *node, Operator op) {
  EXPECT_EQ(node->tag, AstTag::PostfixExpression);
  auto *postfix = dynamic_cast<PostfixExpression *>(node);
  EXPECT_NE(postfix, nullptr);
  if (postfix != nullptr) {
    EXPECT_EQ(postfix->op, op);
  }
  return postfix;
}

TEST(ParserTest, ParsesAtomExpressions) {
  std::string number_input = "123.45";
  auto number_node = parse_test_expr(number_input);
  ASSERT_EQ(number_node->tag, AstTag::NumberLiteral);
  EXPECT_EQ(number_node->pos, 0u);
  EXPECT_EQ(number_node->length, 6u);
  EXPECT_EQ(number_node->column, 1u);
  EXPECT_EQ(number_node->line, 1u);
  auto *number = dynamic_cast<NumberLiteral *>(number_node.get());
  ASSERT_NE(number, nullptr);
  EXPECT_DOUBLE_EQ(number->value, 123.45);

  std::string string_input = "\"hello\"";
  auto string_node = parse_test_expr(string_input);
  ASSERT_EQ(string_node->tag, AstTag::StringLiteral);
  EXPECT_EQ(string_node->pos, 0u);
  EXPECT_EQ(string_node->length, 7u);
  EXPECT_EQ(string_node->column, 1u);
  EXPECT_EQ(string_node->line, 1u);
  auto *string = dynamic_cast<StringLiteral *>(string_node.get());
  ASSERT_NE(string, nullptr);
  EXPECT_EQ(string->value, "hello");

  std::string bool_input = "true";
  auto bool_node = parse_test_expr(bool_input);
  ASSERT_EQ(bool_node->tag, AstTag::BooleanLiteral);
  EXPECT_EQ(bool_node->pos, 0u);
  EXPECT_EQ(bool_node->length, 4u);
  EXPECT_EQ(bool_node->column, 1u);
  EXPECT_EQ(bool_node->line, 1u);
  auto *boolean = dynamic_cast<BooleanLiteral *>(bool_node.get());
  ASSERT_NE(boolean, nullptr);
  EXPECT_TRUE(boolean->value);

  std::string identifier_input = "patient_age";
  auto identifier_node = parse_test_expr(identifier_input);
  ASSERT_EQ(identifier_node->tag, AstTag::Identifier);
  EXPECT_EQ(identifier_node->pos, 0u);
  EXPECT_EQ(identifier_node->length, 11u);
  EXPECT_EQ(identifier_node->column, 1u);
  EXPECT_EQ(identifier_node->line, 1u);
  expect_identifier(identifier_node.get(), "patient_age");
}

TEST(ParserTest, ParsesFunctionCallWithoutArguments) {
  std::string input = "foo()";
  auto node = parse_test_expr(input);

  auto *function_call = expect_function_call(node.get(), "foo", 0);
  ASSERT_NE(function_call, nullptr);
  EXPECT_EQ(function_call->pos, 0u);
  EXPECT_EQ(function_call->length, 5u);
  EXPECT_EQ(function_call->column, 1u);
  EXPECT_EQ(function_call->line, 1u);
}

TEST(ParserTest, ParsesFunctionCallWithOneArgument) {
  std::string input = "foo(4)";
  auto node = parse_test_expr(input);

  auto *function_call = expect_function_call(node.get(), "foo", 1);
  ASSERT_NE(function_call, nullptr);
  expect_number(function_call->args[0].get(), 4.0);
}

TEST(ParserTest, ParsesFunctionCallWithMultipleArguments) {
  std::string input = "foo(1, 2 + 3, patient_age)";
  auto node = parse_test_expr(input);

  auto *function_call = expect_function_call(node.get(), "foo", 3);
  ASSERT_NE(function_call, nullptr);
  expect_number(function_call->args[0].get(), 1.0);

  auto *addition = expect_infix(function_call->args[1].get(), Operator::Plus);
  ASSERT_NE(addition, nullptr);
  expect_number(addition->left_hand_side.get(), 2.0);
  expect_number(addition->right_hand_side.get(), 3.0);

  expect_identifier(function_call->args[2].get(), "patient_age");
}

TEST(ParserTest, ParsesFunctionCallBeforeInfixOperators) {
  std::string input = "foo(4) + 1";
  auto node = parse_test_expr(input);

  auto *addition = expect_infix(node.get(), Operator::Plus);
  ASSERT_NE(addition, nullptr);
  expect_number(addition->right_hand_side.get(), 1.0);

  auto *function_call =
      expect_function_call(addition->left_hand_side.get(), "foo", 1);
  ASSERT_NE(function_call, nullptr);
  expect_number(function_call->args[0].get(), 4.0);
}

TEST(ParserTest, ParsesInfixOperatorExpression) {
  std::string input = "1 + 2 * 3";
  auto node = parse_test_expr(input);

  auto *addition = expect_infix(node.get(), Operator::Plus);
  ASSERT_NE(addition, nullptr);
  expect_number(addition->left_hand_side.get(), 1.0);

  auto *multiplication =
      expect_infix(addition->right_hand_side.get(), Operator::Multipy);
  ASSERT_NE(multiplication, nullptr);
  expect_number(multiplication->left_hand_side.get(), 2.0);
  expect_number(multiplication->right_hand_side.get(), 3.0);
}

TEST(ParserTest, ParsesPostfixOperatorExpression) {
  std::string input = "23 minutes";
  auto node = parse_test_expr(input);

  auto *duration = expect_postfix(node.get(), Operator::Minutes);
  ASSERT_NE(duration, nullptr);
  expect_number(duration->left_hand_side.get(), 23.0);
}

TEST(ParserTest, ParsesPrefixOperatorExpression) {
  std::string input = "-2";
  auto node = parse_test_expr(input);

  auto *negation = expect_prefix(node.get(), Operator::Minus);
  ASSERT_NE(negation, nullptr);
  expect_number(negation->right_hand_side.get(), 2.0);
}

TEST(ParserTest, ParsesLeftAssociativeAdditiveOperators) {
  std::string input = "1 + 2 - 3";
  auto node = parse_test_expr(input);

  auto *subtraction = expect_infix(node.get(), Operator::Minus);
  ASSERT_NE(subtraction, nullptr);
  expect_number(subtraction->right_hand_side.get(), 3.0);

  auto *addition =
      expect_infix(subtraction->left_hand_side.get(), Operator::Plus);
  ASSERT_NE(addition, nullptr);
  expect_number(addition->left_hand_side.get(), 1.0);
  expect_number(addition->right_hand_side.get(), 2.0);
}

TEST(ParserTest, ParsesParenthesesBeforeEverythingElse) {
  std::string input = "(1 + 2) ** 3";
  auto node = parse_test_expr(input);

  auto *power = expect_infix(node.get(), Operator::Power);
  ASSERT_NE(power, nullptr);
  expect_number(power->right_hand_side.get(), 3.0);

  auto *addition = expect_infix(power->left_hand_side.get(), Operator::Plus);
  ASSERT_NE(addition, nullptr);
  expect_number(addition->left_hand_side.get(), 1.0);
  expect_number(addition->right_hand_side.get(), 2.0);
}

TEST(ParserTest, ParsesParenthesesOnRightHandSideBeforeMultiplication) {
  std::string input = "1 * (2 + 3)";
  auto node = parse_test_expr(input);

  auto *multiplication = expect_infix(node.get(), Operator::Multipy);
  ASSERT_NE(multiplication, nullptr);
  expect_number(multiplication->left_hand_side.get(), 1.0);

  auto *addition =
      expect_infix(multiplication->right_hand_side.get(), Operator::Plus);
  ASSERT_NE(addition, nullptr);
  expect_number(addition->left_hand_side.get(), 2.0);
  expect_number(addition->right_hand_side.get(), 3.0);
}

TEST(ParserTest, ParsesNestedParenthesesBeforeOuterOperators) {
  std::string input = "1 + (2 * (3 + 4))";
  auto node = parse_test_expr(input);

  auto *addition = expect_infix(node.get(), Operator::Plus);
  ASSERT_NE(addition, nullptr);
  expect_number(addition->left_hand_side.get(), 1.0);

  auto *multiplication =
      expect_infix(addition->right_hand_side.get(), Operator::Multipy);
  ASSERT_NE(multiplication, nullptr);
  expect_number(multiplication->left_hand_side.get(), 2.0);

  auto *nested_addition =
      expect_infix(multiplication->right_hand_side.get(), Operator::Plus);
  ASSERT_NE(nested_addition, nullptr);
  expect_number(nested_addition->left_hand_side.get(), 3.0);
  expect_number(nested_addition->right_hand_side.get(), 4.0);
}

TEST(ParserTest, ParsesParenthesizedPrefixBeforePowerOperator) {
  std::string input = "(-2) ** 10";
  auto node = parse_test_expr(input);

  auto *power = expect_infix(node.get(), Operator::Power);
  ASSERT_NE(power, nullptr);
  expect_number(power->right_hand_side.get(), 10.0);

  auto *negation = expect_prefix(power->left_hand_side.get(), Operator::Minus);
  ASSERT_NE(negation, nullptr);
  expect_number(negation->right_hand_side.get(), 2.0);
}

TEST(ParserTest, ParsesPostfixAfterParenthesizedExpression) {
  std::string input = "(1 + 2) minutes";
  auto node = parse_test_expr(input);

  auto *minutes = expect_postfix(node.get(), Operator::Minutes);
  ASSERT_NE(minutes, nullptr);

  auto *addition = expect_infix(minutes->left_hand_side.get(), Operator::Plus);
  ASSERT_NE(addition, nullptr);
  expect_number(addition->left_hand_side.get(), 1.0);
  expect_number(addition->right_hand_side.get(), 2.0);
}

TEST(ParserTest, ParsesMultiplicativeBeforeAdditiveOperators) {
  std::string input = "1 + 2 * 4 / 5";
  auto node = parse_test_expr(input);

  auto *addition = expect_infix(node.get(), Operator::Plus);
  ASSERT_NE(addition, nullptr);
  expect_number(addition->left_hand_side.get(), 1.0);

  auto *division =
      expect_infix(addition->right_hand_side.get(), Operator::Divide);
  ASSERT_NE(division, nullptr);
  expect_number(division->right_hand_side.get(), 5.0);

  auto *multiplication =
      expect_infix(division->left_hand_side.get(), Operator::Multipy);
  ASSERT_NE(multiplication, nullptr);
  expect_number(multiplication->left_hand_side.get(), 2.0);
  expect_number(multiplication->right_hand_side.get(), 4.0);
}

TEST(ParserTest, ParsesPrefixBeforeAdditiveOperators) {
  std::string input = "1 - -3";
  auto node = parse_test_expr(input);

  auto *subtraction = expect_infix(node.get(), Operator::Minus);
  ASSERT_NE(subtraction, nullptr);
  expect_number(subtraction->left_hand_side.get(), 1.0);

  auto *negation =
      expect_prefix(subtraction->right_hand_side.get(), Operator::Minus);
  ASSERT_NE(negation, nullptr);
  expect_number(negation->right_hand_side.get(), 3.0);
}

TEST(ParserTest, ParsesPowerBeforePrefixOperator) {
  std::string input = "-2 ** 10";
  auto node = parse_test_expr(input);

  auto *negation = expect_prefix(node.get(), Operator::Minus);
  ASSERT_NE(negation, nullptr);

  auto *power = expect_infix(negation->right_hand_side.get(), Operator::Power);
  ASSERT_NE(power, nullptr);
  expect_number(power->left_hand_side.get(), 2.0);
  expect_number(power->right_hand_side.get(), 10.0);
}

TEST(ParserTest, ParsesPostfixBeforeMultiplicativeOperators) {
  std::string input = "2 hours / 5 minutes";
  auto node = parse_test_expr(input);

  auto *division = expect_infix(node.get(), Operator::Divide);
  ASSERT_NE(division, nullptr);

  auto *hours = expect_postfix(division->left_hand_side.get(), Operator::Hours);
  ASSERT_NE(hours, nullptr);
  expect_number(hours->left_hand_side.get(), 2.0);

  auto *minutes =
      expect_postfix(division->right_hand_side.get(), Operator::Minutes);
  ASSERT_NE(minutes, nullptr);
  expect_number(minutes->left_hand_side.get(), 5.0);
}

TEST(ParserTest, ParsesDurationArithmeticFromExamples) {
  std::string input = "23 minutes - 12 seconds";
  auto node = parse_test_expr(input);

  auto *subtraction = expect_infix(node.get(), Operator::Minus);
  ASSERT_NE(subtraction, nullptr);

  auto *minutes =
      expect_postfix(subtraction->left_hand_side.get(), Operator::Minutes);
  ASSERT_NE(minutes, nullptr);
  expect_number(minutes->left_hand_side.get(), 23.0);

  auto *seconds =
      expect_postfix(subtraction->right_hand_side.get(), Operator::Seconds);
  ASSERT_NE(seconds, nullptr);
  expect_number(seconds->left_hand_side.get(), 12.0);
}

TEST(ParserTest, RejectsEmptyExpression) {
  std::string input;
  EXPECT_THROW(parse_test_expr(input), ParserError);
}

TEST(ParserTest, RejectsMissingSemicolonBetweenStatements) {
  std::string input = "WRITE 1\nWRITE 2;";
  EXPECT_THROW(parse_test_statement_block(input), ParserError);
}

TEST(InterpreterTest, InterpretsTraceStatement) {
  Environment env;

  std::string number_input = "Trace 11";
  testing::internal::CaptureStdout();
  auto number_result = eval(env, parse_test_statement(number_input));
  EXPECT_EQ(testing::internal::GetCapturedStdout(), "Line 1: 11\n");
  ASSERT_NE(number_result, nullptr);
  EXPECT_EQ(number_result->tag, ValueTag::Unit);
}

TEST(InterpreterTest, InterpretsASimpleBuiltinFunctionTrace) {
  Environment env;

  std::string number_input = "trace(11)";
  testing::internal::CaptureStdout();
  auto number_result = eval(env, parse_test_statement(number_input));
  EXPECT_EQ(testing::internal::GetCapturedStdout(), "Line 1: 11\n");
  ASSERT_NE(number_result, nullptr);
  EXPECT_EQ(number_result->tag, ValueTag::Unit);
}

TEST(InterpreterTest, InterpretsASimpleBuiltinFunctionWrite) {
  Environment env;

  std::string number_input = "write(11)";
  testing::internal::CaptureStdout();
  auto number_result = eval(env, parse_test_statement(number_input));
  EXPECT_EQ(testing::internal::GetCapturedStdout(), "11\n");
  ASSERT_NE(number_result, nullptr);
  EXPECT_EQ(number_result->tag, ValueTag::Unit);
}

TEST(InterpreterTest, InterpretsASimpleStatementBlock) {
  Environment env;

  std::string number_input = "WRITE \"hello\";\n{\nWRITE 123.45;\n}";
  testing::internal::CaptureStdout();
  auto number_result = eval(env, parse_test_statement_block(number_input));
  EXPECT_EQ(testing::internal::GetCapturedStdout(), "hello\n123.45\n");
  ASSERT_NE(number_result, nullptr);
  EXPECT_EQ(number_result->tag, ValueTag::Unit);
}

TEST(InterpreterTest, InterpretsWriteNumberAndStringStatements) {
  Environment env;

  std::string number_input = "WRITE 123.45";
  testing::internal::CaptureStdout();
  auto number_result = eval(env, parse_test_statement(number_input));
  EXPECT_EQ(testing::internal::GetCapturedStdout(), "123.45\n");
  ASSERT_NE(number_result, nullptr);
  EXPECT_EQ(number_result->tag, ValueTag::Unit);

  std::string string_input = "WRITE \"hello\"";
  testing::internal::CaptureStdout();
  auto string_result = eval(env, parse_test_statement(string_input));
  EXPECT_EQ(testing::internal::GetCapturedStdout(), "hello\n");
  ASSERT_NE(string_result, nullptr);
  EXPECT_EQ(string_result->tag, ValueTag::Unit);
}

TEST(InterpreterTest, InterpretsListAssignmentAndPrintsIt) {
  Environment env;

  testing::internal::CaptureStdout();
  std::string assign_input = "a := [1, 2, 3, 4];\nwrite(a);";
  auto assign_result = eval(env, parse_test_statement_block(assign_input));
  ASSERT_NE(assign_result, nullptr);
  EXPECT_EQ(assign_result->tag, ValueTag::Unit);

  EXPECT_EQ(testing::internal::GetCapturedStdout(), "[1, 2, 3, 4]\n");
}

TEST(InterpreterTest, InterpretsFunctionDefinition) {
  Environment env;

  std::string assign_input =
      "new_function :: (a, b, c) {\nreturn a + b + c;\n}";
  auto function_definition =
      eval(env, parse_test_statement_block(assign_input));
  ASSERT_NE(function_definition, nullptr);
  EXPECT_EQ(function_definition->tag, ValueTag::Unit);
}

TEST(InterpreterTest, InterpretsFunctionDefinitionAndCall) {
  Environment env;

  std::string assign_input =
      "new_function :: () {\nreturn 123;\n};\nwrite(new_function());";
  testing::internal::CaptureStdout();
  auto function_definition =
      eval(env, parse_test_statement_block(assign_input));
  ASSERT_NE(function_definition, nullptr);
  EXPECT_EQ(function_definition->tag, ValueTag::Unit);
  EXPECT_EQ(testing::internal::GetCapturedStdout(), "123\n");
}

TEST(InterpreterTest, InterpretsFunctionDefinitionFollowedByCallStatements) {
  Environment env;

  std::string input =
      "hello_world :: (name) {\n"
      "    write(\"Hello World\");\n"
      "    write(name);\n"
      "}\n"
      "\n"
      "hello_world(\"tom\");\n"
      "hello_world(\"jane\");\n"
      "hello_world(\"carmen\");\n";
  testing::internal::CaptureStdout();
  auto result = eval(env, parse_test_statement_block(input));

  ASSERT_NE(result, nullptr);
  EXPECT_EQ(result->tag, ValueTag::Unit);
  EXPECT_EQ(testing::internal::GetCapturedStdout(),
            "Hello World\n"
            "tom\n"
            "Hello World\n"
            "jane\n"
            "Hello World\n"
            "carmen\n");
}

TEST(InterpreterTest, FunctionCallArgCountMustMatchDefinition) {
  Environment env;

  std::string input =
      "arity_mismatch :: (a, b) {\n"
      "return a;\n"
      "};\n"
      "write(arity_mismatch(1));";

  try {
    eval(env, parse_test_statement_block(input));
    FAIL() << "expected RuntimeError";
  } catch (const RuntimeError &error) {
    std::string message = error.what();
    EXPECT_NE(message.find("function 'arity_mismatch' expects 2 arguments but "
                           "got 1"),
              std::string::npos);
  }
}

TEST(InterpreterTest, FunctionDefinitionsCurrentlyUseOnlyArgsAndLocals) {
  Environment env;

  // Function calls currently evaluate with the function's own environment only.
  // That environment starts with the declared arguments and can be extended by
  // assignments made inside the body; it does not capture globals or expose its
  // locals back to the caller.
  std::string uses_args_and_locals =
      "function_env_args_and_locals :: (arg) {\n"
      "local_value := arg;\n"
      "return local_value;\n"
      "};\n"
      "write(function_env_args_and_locals(123));";
  testing::internal::CaptureStdout();
  auto function_result = eval(env, parse_test_statement_block(uses_args_and_locals));
  ASSERT_NE(function_result, nullptr);
  EXPECT_EQ(function_result->tag, ValueTag::Unit);
  EXPECT_EQ(testing::internal::GetCapturedStdout(), "123\n");

  std::string cannot_read_outer =
      "outer_value := 7;\n"
      "function_env_no_capture :: () {\n"
      "return outer_value;\n"
      "};\n"
      "write(function_env_no_capture());";
  EXPECT_THROW(eval(env, parse_test_statement_block(cannot_read_outer)),
               RuntimeError);

  std::string local_does_not_leak =
      "function_env_hidden_local :: () {\n"
      "hidden_local := 42;\n"
      "return hidden_local;\n"
      "};\n"
      "write(function_env_hidden_local());\n"
      "write(hidden_local);";
  testing::internal::CaptureStdout();
  EXPECT_THROW(eval(env, parse_test_statement_block(local_does_not_leak)),
               RuntimeError);
  EXPECT_EQ(testing::internal::GetCapturedStdout(), "42\n");
}

TEST(InterpreterTest, AssignmentValueCanBeWrittenMoreThanOnce) {
  Environment env;

  std::string assign_input = "a := 123.45";
  auto assign_result = eval(env, parse_test_statement(assign_input));
  ASSERT_NE(assign_result, nullptr);
  EXPECT_EQ(assign_result->tag, ValueTag::Unit);

  testing::internal::CaptureStdout();
  std::string first_write = "WRITE a";
  auto first_result = eval(env, parse_test_statement(first_write));
  std::string second_write = "WRITE a";
  auto second_result = eval(env, parse_test_statement(second_write));

  EXPECT_EQ(testing::internal::GetCapturedStdout(), "123.45\n123.45\n");
  ASSERT_NE(first_result, nullptr);
  EXPECT_EQ(first_result->tag, ValueTag::Unit);
  ASSERT_NE(second_result, nullptr);
  EXPECT_EQ(second_result->tag, ValueTag::Unit);
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
  Tokenizer tokenizer = {
      .input_file = "test", .input = input, .pos = 0, .line = 1, .column = 0};

  Token token = tokenizer_next_token(tokenizer);

  EXPECT_EQ(token.type, Type::Plus);
  EXPECT_EQ(token.length, 1u);
}

TEST(TokenizerTest, NextTokenAdvancesPosition) {
  char input[] = "ab";
  Tokenizer tokenizer = {
      .input_file = "test", .input = input, .pos = 0, .line = 1, .column = 1};

  Token token = tokenizer_next_token(tokenizer);

  EXPECT_EQ(token.type, Type::Identifier);
  EXPECT_EQ(tokenizer.pos, 2u);
  EXPECT_EQ(tokenizer.column, 3u);
}

// --- Ported from OCaml expect tests ---

TEST(TokenizerTest, SimpleOperators) {
  check_tokens("+-*/;:=,()[]{}&<><=>=<>", {
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
                                              {Type::Lbrac, 1, 13, 1},
                                              {Type::Rbrac, 1, 14, 1},
                                              {Type::Ampersand, 1, 15, 1},
                                              {Type::Neq, 2, 16, 1},
                                              {Type::Lteq, 2, 18, 1},
                                              {Type::Gteq, 2, 20, 1},
                                              {Type::Neq, 2, 22, 1},
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
          {Type::Multipy, 1, 13, 4},     {Type::Numtoken, 1, 15, 4},
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
