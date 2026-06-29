#include "compiler.hh"
#include "parser.hh"
#include <algorithm>
#include <array>
#include <optional>
#include <string>
#include <unordered_map>

namespace {

constexpr std::array<std::string_view, 4> builtin_names = {
    "write", "trace", "is_number", "is_list"};

std::string identifier_name(const AstNode &root) {
  auto *ident = dynamic_cast<const IdentifierExression *>(&root);
  if (ident == nullptr) {
    return {};
  }
  return std::string(ident->value);
}

std::optional<std::size_t> find_index(const std::vector<std::string> &values,
                                      const std::string &value) {
  auto it = std::find(values.begin(), values.end(), value);
  if (it == values.end()) {
    return std::nullopt;
  }
  return static_cast<std::size_t>(std::distance(values.begin(), it));
}

std::optional<BuiltinIndex> find_builtin_index(const std::string &value) {
  auto it = std::find(builtin_names.begin(), builtin_names.end(), value);
  if (it == builtin_names.end()) {
    return std::nullopt;
  }
  return static_cast<BuiltinIndex>(std::distance(builtin_names.begin(), it));
}

void add_unsupported_operator_error(CompilerResult &result,
                                    const AstNode &root) {
  result.errors.push_back(
      {"unsupported operator", BytecodeSourceLocation(root)});
}

void add_function_definition(CompilerContext &context,
                             const FunctionDefinitionStatement &definition) {
  auto name = identifier_name(*definition.name);
  if (name.empty()) {
    context.result.errors.push_back(
        {"expected function name", BytecodeSourceLocation(definition)});
    return;
  }

  if (context.function_indexes.find(name) != context.function_indexes.end()) {
    return;
  }

  auto index =
      static_cast<FunctionIndex>(context.result.program.functions.size());
  context.function_indexes.emplace(name, index);
  context.result.program.functions.push_back(BytecodeFunction{
      .name = std::move(name),
      .parameters = {},
      .chunk = {},
      .location = BytecodeSourceLocation(definition),
  });
}

void predeclare_statement_block_functions(CompilerContext &context,
                                          const StatementBlock &block) {
  for (const auto &statement : block.block) {
    if (statement->tag != AstTag::FunctionDefinitionStatement) {
      continue;
    }
    auto *definition =
        dynamic_cast<const FunctionDefinitionStatement *>(statement.get());
    if (definition != nullptr) {
      add_function_definition(context, *definition);
    }
  }
}

} // namespace

void add_number_literal(CompilerContext &context, const AstNode &root) {
  auto *num = dynamic_cast<const NumberLiteral *>(&root);
  if (num == nullptr) {
    context.result.errors.push_back(
        {"expected number literal", BytecodeSourceLocation(root)});
    return;
  }
  auto value = num->value;
  auto const_index = context.chunk.add_constant(VmValue::number(value));
  context.chunk.emit(OpCode::PushConstant, BytecodeSourceLocation(root),
                     const_index);
}

void add_number_literal(CompilerResult &result, const AstNode &root) {
  std::unordered_map<std::string, FunctionIndex> function_indexes;
  CompilerContext context{.result = result,
                          .chunk = result.program.main,
                          .function_indexes = function_indexes,
                          .locals = {},
                          .in_function = false};
  add_number_literal(context, root);
}

void add_string_literal(CompilerContext &context, const AstNode &root) {
  auto *str = dynamic_cast<const StringLiteral *>(&root);
  if (str == nullptr) {
    context.result.errors.push_back(
        {"expected string literal", BytecodeSourceLocation(root)});
    return;
  }
  auto value = str->value;
  auto const_index =
      context.chunk.add_constant(VmValue::string(std::string(value)));
  context.chunk.emit(OpCode::PushConstant, BytecodeSourceLocation(root),
                     const_index);
}

void add_bool_literal(CompilerContext &context, const AstNode &root) {
  auto *boolean = dynamic_cast<const BooleanLiteral *>(&root);
  if (boolean == nullptr) {
    context.result.errors.push_back(
        {"expected boolean literal", BytecodeSourceLocation(root)});
    return;
  }
  auto value = boolean->value;
  auto const_index = context.chunk.add_constant(VmValue::boolean(value));
  context.chunk.emit(OpCode::PushConstant, BytecodeSourceLocation(root),
                     const_index);
}

void identifier_expression(CompilerContext &context, const AstNode &root) {
  auto *ident = dynamic_cast<const IdentifierExression *>(&root);
  if (ident == nullptr) {
    context.result.errors.push_back(
        {"expected identifier", BytecodeSourceLocation(root)});
    return;
  }
  auto value = std::string(ident->value);
  if (auto local_index = find_index(context.locals, value)) {
    context.chunk.emit(OpCode::LoadLocal, BytecodeSourceLocation(root),
                       static_cast<NameIndex>(*local_index));
    return;
  }

  auto &names = context.chunk.names;
  auto ident_index = std::find(names.begin(), names.end(), value);
  if (ident_index == names.end()) {
    context.result.errors.push_back(
        {"unknown global name", BytecodeSourceLocation(root)});
    return;
  }
  context.chunk.emit(
      OpCode::LoadGlobal, BytecodeSourceLocation(root),
      static_cast<NameIndex>(std::distance(names.begin(), ident_index)));
}

void infix_expression(CompilerContext &context, const AstNode &root) {
  auto *infix = dynamic_cast<const InfixExpression *>(&root);
  if (infix == nullptr) {
    context.result.errors.push_back(
        {"expected infix expression", BytecodeSourceLocation(root)});
    return;
  }
  //
  // eval left -> left is on the stack now
  // eval right -> right is on the stack now
  // pop -> right
  // pop -> left
  // push left + right
  //
  compile_node(context, *infix->left_hand_side);
  compile_node(context, *infix->right_hand_side);
  switch (infix->op) {
  case Operator::Plus:
    context.chunk.emit(OpCode::Add, BytecodeSourceLocation(root));
    break;
  case Operator::Minus:
    context.chunk.emit(OpCode::Subtract, BytecodeSourceLocation(root));
    break;
  case Operator::Multipy:
    context.chunk.emit(OpCode::Multiply, BytecodeSourceLocation(root));
    break;
  case Operator::Divide:
    context.chunk.emit(OpCode::Divide, BytecodeSourceLocation(root));
    break;
  case Operator::Power:
    context.chunk.emit(OpCode::Power, BytecodeSourceLocation(root));
    break;
  default:
    add_unsupported_operator_error(context.result, root);
    break;
  }
}

void prefix_expression(CompilerContext &context, const AstNode &root) {
  auto *prefix = dynamic_cast<const PrefixExpression *>(&root);
  if (prefix == nullptr) {
    context.result.errors.push_back(
        {"expected prefix expression", BytecodeSourceLocation(root)});
    return;
  }

  compile_node(context, *prefix->right_hand_side);
  switch (prefix->op) {
  case Operator::Minus:
    context.chunk.emit(OpCode::Negate, BytecodeSourceLocation(root));
    break;
  default:
    add_unsupported_operator_error(context.result, root);
    break;
  }
}

void postfix_expression(CompilerContext &context, const AstNode &root) {
  auto *postfix = dynamic_cast<const PostfixExpression *>(&root);
  if (postfix == nullptr) {
    context.result.errors.push_back(
        {"expected postfix expression", BytecodeSourceLocation(root)});
    return;
  }

  compile_node(context, *postfix->left_hand_side);
  switch (postfix->op) {
  case Operator::Year:
    context.chunk.emit(OpCode::ToYears, BytecodeSourceLocation(root));
    break;
  case Operator::Month:
    context.chunk.emit(OpCode::ToMonths, BytecodeSourceLocation(root));
    break;
  case Operator::Week:
    context.chunk.emit(OpCode::ToWeeks, BytecodeSourceLocation(root));
    break;
  case Operator::Day:
    context.chunk.emit(OpCode::ToDays, BytecodeSourceLocation(root));
    break;
  case Operator::Hours:
    context.chunk.emit(OpCode::ToHours, BytecodeSourceLocation(root));
    break;
  case Operator::Minutes:
    context.chunk.emit(OpCode::ToMinutes, BytecodeSourceLocation(root));
    break;
  case Operator::Seconds:
    context.chunk.emit(OpCode::ToSeconds, BytecodeSourceLocation(root));
    break;
  default:
    add_unsupported_operator_error(context.result, root);
    break;
  }
}

void list_expression(CompilerContext &context, const AstNode &root) {
  auto *list = dynamic_cast<const ListExpresssion *>(&root);
  if (list == nullptr) {
    context.result.errors.push_back(
        {"expected list expression", BytecodeSourceLocation(root)});
    return;
  }
  for (const auto &item : list->items) {
    compile_node(context, *item);
  }
  context.chunk.emit(OpCode::MakeList, BytecodeSourceLocation(root),
                     static_cast<std::uint32_t>(list->items.size()));
}

void assignment_statement(CompilerContext &context, const AstNode &root) {
  auto *assignment = dynamic_cast<const AssignmentStatement *>(&root);
  if (assignment == nullptr) {
    context.result.errors.push_back(
        {"expected assignment statement", BytecodeSourceLocation(root)});
    return;
  }

  auto name = identifier_name(*assignment->ident);
  compile_node(context, *assignment->expression);
  if (auto local_index = find_index(context.locals, name)) {
    context.chunk.emit(OpCode::StoreLocal, BytecodeSourceLocation(root),
                       static_cast<NameIndex>(*local_index));
    return;
  }

  if (context.in_function) {
    context.locals.push_back(name);
    context.chunk.emit(OpCode::StoreLocal, BytecodeSourceLocation(root),
                       static_cast<NameIndex>(context.locals.size() - 1));
    return;
  }

  auto name_index = context.chunk.add_name(name);
  context.chunk.emit(OpCode::StoreGlobal, BytecodeSourceLocation(root),
                     name_index);
}

void function_call_expression(CompilerContext &context, const AstNode &root) {
  auto *call = dynamic_cast<const FunctionCallExpression *>(&root);
  if (call == nullptr) {
    context.result.errors.push_back(
        {"expected function call", BytecodeSourceLocation(root)});
    return;
  }

  auto name = identifier_name(*call->function_name_identifier);
  auto function = context.function_indexes.find(name);
  if (function == context.function_indexes.end()) {
    auto builtin = find_builtin_index(name);
    if (!builtin.has_value()) {
      context.result.errors.push_back(
          {"unknown function name", BytecodeSourceLocation(root)});
      return;
    }

    for (const auto &arg : call->args) {
      compile_node(context, *arg);
    }
    context.chunk.emit(OpCode::CallBuiltin, BytecodeSourceLocation(root),
                       *builtin, static_cast<std::uint32_t>(call->args.size()));
    return;
  }

  for (const auto &arg : call->args) {
    compile_node(context, *arg);
  }
  context.chunk.emit(OpCode::CallFunction, BytecodeSourceLocation(root),
                     function->second,
                     static_cast<std::uint32_t>(call->args.size()));
}

void return_statement(CompilerContext &context, const AstNode &root) {
  auto *return_node = dynamic_cast<const ReturnStatement *>(&root);
  if (return_node == nullptr) {
    context.result.errors.push_back(
        {"expected return statement", BytecodeSourceLocation(root)});
    return;
  }
  //
  // puts down the return on top of the stack
  //
  compile_node(context, *return_node->value);
  context.chunk.emit(OpCode::Return, BytecodeSourceLocation(root));
}

void write_statement(CompilerContext &context, const AstNode &root) {
  auto *write = dynamic_cast<const WriteStatement *>(&root);
  if (write == nullptr) {
    context.result.errors.push_back(
        {"expected write statement", BytecodeSourceLocation(root)});
    return;
  }

  compile_node(context, *write->right_hand_side);
  context.chunk.emit(OpCode::CallBuiltin, BytecodeSourceLocation(root),
                     write->trace ? 1 : 0, 1);
}

void function_definition_statement(CompilerContext &context,
                                   const AstNode &root) {
  auto *definition = dynamic_cast<const FunctionDefinitionStatement *>(&root);
  if (definition == nullptr) {
    context.result.errors.push_back(
        {"expected function definition", BytecodeSourceLocation(root)});
    return;
  }
  add_function_definition(context, *definition);

  auto name = identifier_name(*definition->name);
  auto function_index = context.function_indexes.find(name);
  // @warning this is a ai-ism just not overwrite somethign that is defined
  // later this is not how things work normally
  if (function_index == context.function_indexes.end()) {
    return;
  }

  auto &function = context.result.program.functions[function_index->second];
  function.chunk = {};
  function.parameters.clear();
  for (const auto &arg : definition->args) {
    auto arg_name = identifier_name(*arg);
    if (arg_name.empty()) {
      context.result.errors.push_back(
          {"expected parameter name", BytecodeSourceLocation(*arg)});
      continue;
    }
    function.parameters.push_back(std::move(arg_name));
  }

  CompilerContext function_context{.result = context.result,
                                   .chunk = function.chunk,
                                   .function_indexes = context.function_indexes,
                                   .locals = function.parameters,
                                   .in_function = true};
  compile_node(function_context, *definition->body);
  if (function.chunk.instructions.empty() ||
      function.chunk.instructions.back().op != OpCode::Return) {
    function.chunk.emit(OpCode::PushUnit, BytecodeSourceLocation(root));
    function.chunk.emit(OpCode::Return, BytecodeSourceLocation(root));
  }
}

void compile_if_statement(CompilerContext &context, const AstNode &root) {
  auto *if_statement = dynamic_cast<const IfStatement *>(&root);
  if (if_statement == nullptr) {
    context.result.errors.push_back(
        {"expected if statement", BytecodeSourceLocation(root)});
    return;
  }
  std::vector<int> jumps;
  for (const auto &ex_block_pair : if_statement->if_else) {
    auto &expression = ex_block_pair.first;
    auto &block = ex_block_pair.second;
    compile_node(context, *expression);
    auto pos = context.chunk.emit(OpCode::JumpIfFalse,
                                  BytecodeSourceLocation(*expression));
    compile_node(context, *block);
    jumps.push_back(
        context.chunk.emit(OpCode::Jump, BytecodeSourceLocation(*expression)));
    context.chunk.instructions[pos].operand = context.chunk.instructions.size();
  }
  if (if_statement->else_statement.has_value()) {
    auto &else_stmt = if_statement->else_statement.value();
    compile_node(context, *else_stmt);
  }
  for (auto jump : jumps) {
    context.chunk.instructions[jump].operand =
        context.chunk.instructions.size();
  }
}

void statement_block(CompilerContext &context, const AstNode &root) {
  auto *block = dynamic_cast<const StatementBlock *>(&root);
  if (block == nullptr) {
    context.result.errors.push_back(
        {"expected statement block", BytecodeSourceLocation(root)});
    return;
  }

  predeclare_statement_block_functions(context, *block);
  for (const auto &statement : block->block) {
    compile_node(context, *statement);
  }
}

void compile_for_statement(CompilerContext &context, const AstNode &root) {
  // todo
}

void compile_node(CompilerContext &context, const AstNode &root) {
  switch (root.tag) {
  case AstTag::NumberLiteral: {
    add_number_literal(context, root);
    break;
  }
  case AstTag::StringLiteral: {
    add_string_literal(context, root);
    break;
  }
  case AstTag::BooleanLiteral: {
    add_bool_literal(context, root);
    break;
  }
  case AstTag::Identifier: {
    identifier_expression(context, root);
    break;
  }
  case AstTag::InfixExpression: {
    infix_expression(context, root);
    break;
  }
  case AstTag::PrefixExpression: {
    prefix_expression(context, root);
    break;
  }
  case AstTag::PostfixExpression: {
    postfix_expression(context, root);
    break;
  }
  case AstTag::FunctionCallExpression: {
    function_call_expression(context, root);
    break;
  }
  case AstTag::AssignmentStatement: {
    assignment_statement(context, root);
    break;
  }
  case AstTag::StatementBlock: {
    statement_block(context, root);
    break;
  }
  case AstTag::ListExpression: {
    list_expression(context, root);
    break;
  }
  case AstTag::FunctionDefinitionStatement: {
    function_definition_statement(context, root);
    break;
  }
  case AstTag::ReturnStatement: {
    return_statement(context, root);
    break;
  }
  case AstTag::WriteStatement: {
    write_statement(context, root);
    break;
  }
  case AstTag::IfStatement: {
    compile_if_statement(context, root);
    break;
  }
  case AstTag::ForStatement:
    compile_for_statement(context, root);
    break;
  }
}

void compile_program(CompilerResult &result, const AstNode &root) {
  std::unordered_map<std::string, FunctionIndex> function_indexes;
  CompilerContext context{.result = result,
                          .chunk = result.program.main,
                          .function_indexes = function_indexes,
                          .locals = {},
                          .in_function = false};
  compile_node(context, root);
}
