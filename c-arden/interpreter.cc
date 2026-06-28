#include "interpreter.hh"
#include "parser.hh"
#include <cstddef>
#include <format>
#include <functional>
#include <iostream>
#include <memory>
#include <optional>
#include <stdexcept>
#include <unordered_map>
// https://craftinginterpreters.com/contents.html

RuntimeError::RuntimeError(const std::string &message, const size_t line,
                           const size_t column)
    : std::runtime_error(std::format("{} at {}:{}", message, line, column)) {}

ValuePtr make_unit() { return std::make_shared<Unit>(); };

static std::unordered_map<std::string, FunctionDefinition> functions;

static const std::unordered_map<std::string, BuiltingFnEntry> builtins = {
    {"write",
     {.args_len = 1,
      .function =
          [](Args args, size_t line, size_t column) {
            if (args.size() != 1) {
              throw RuntimeError(
                  std::format(
                      "The write function only expects one argument got {}",
                      args.size()),
                  line, column);
            }
            return write(std::move(args.front()), std::nullopt);
          }}},
    {"is_number",
     {.args_len = 1,
      .function =
          [](Args args, size_t line, size_t column) {
            if (args.size() != 1) {
              throw RuntimeError(
                  std::format(
                      "The is_number function only expects one argument got {}",
                      args.size()),
                  line, column);
            }
            return std::make_shared<Bool>(args.front()->tag ==
                                          ValueTag::Number);
          }}},
    {"is_list",
     {.args_len = 1,
      .function =
          [](Args args, size_t line, size_t column) {
            if (args.size() != 1) {
              throw RuntimeError(
                  std::format(
                      "The is_list function only expects one argument got {}",
                      args.size()),
                  line, column);
            }
            return std::make_shared<Bool>(args.front()->tag == ValueTag::List);
          }}},
    {"trace",
     {.args_len = 1,
      .function =
          [](Args args, size_t line, size_t column) {
            throw RuntimeError(
                std::format(
                    "The trace function only expects one argument got {}",
                    args.size()),
                line, column);
            return write(std::move(args.front()), line);
          }}},
};

static ValuePtr clone_number_or_bool(ValuePtr value) {
  switch (value->tag) {
  case ValueTag::Number: {
    auto *number = dynamic_cast<const Number *>(value.get());
    return std::make_shared<Number>(number->value);
  }
  case ValueTag::Bool: {
    auto *boolean = dynamic_cast<const Bool *>(value.get());
    return std::make_shared<Bool>(boolean->value);
  }
  default:
    return value;
  }
}

ValuePtr write_type(ValuePtr value) {
  switch (value->tag) {
  case ValueTag::Number: {
    auto *number = dynamic_cast<Number *>(value.get());
    std::cout << number->value;
    break;
  }
  case ValueTag::String: {
    auto *string = dynamic_cast<String *>(value.get());
    std::cout << string->value;
    break;
  }
  case ValueTag::Unit: {
    std::cout << "Unit";
    break;
  }
  case ValueTag::Bool: {
    auto *boolean = dynamic_cast<Bool *>(value.get());
    std::cout << (boolean->value ? "true" : "false");
    break;
  }
  default:
    std::cout << "unknown";
  }
  return make_unit();
}

ValuePtr write(ValuePtr value, std::optional<size_t> line) {
  if (line.has_value()) {
    std::cout << "Line " << line.value() << ": ";
  }
  switch (value->tag) {
  case ValueTag::Number: {
    write_type(value);
    break;
  }
  case ValueTag::String: {
    write_type(value);
    break;
  }
  case ValueTag::Unit: {
    write_type(value);
    break;
  }
  case ValueTag::Bool: {
    write_type(value);
    break;
  }
  case ValueTag::List: {
    auto *list = dynamic_cast<List *>(value.get());
    std::cout << "[";
    for (size_t i = 0; i < list->items.size() - 1; i++) {
      auto item = list->items[i];
      write_type(item);
      std::cout << ", ";
    }
    // get the last and do not put a comma after
    auto item = list->items[list->items.size() - 1];
    write_type(item);
    std::cout << "]";
  }
  }
  std::cout << std::endl;
  return make_unit();
}

ValuePtr eval(Environment &env, AstNodePtr node) {
  return eval_node(env, *node);
}

ValuePtr eval_node(Environment &env, AstNode &node) {
  (void)env;

  switch (node.tag) {
  case AstTag::WriteStatement: {
    auto *write_statement = dynamic_cast<WriteStatement *>(&node);
    auto line = write_statement->trace
                    ? std::make_optional(write_statement->line)
                    : std::nullopt;
    return write(eval_node(env, *write_statement->right_hand_side), line);
  }
  case AstTag::NumberLiteral: {
    auto *value = dynamic_cast<NumberLiteral *>(&node);
    return std::make_shared<Number>(value->value);
  }
  case AstTag::StringLiteral: {
    auto *value = dynamic_cast<StringLiteral *>(&node);
    return std::make_shared<String>(value->value);
  }
  case AstTag::BooleanLiteral: {
    auto *value = dynamic_cast<BooleanLiteral *>(&node);
    return std::make_shared<Bool>(value->value);
  }
  case AstTag::Identifier: {
    auto *ident = dynamic_cast<IdentifierExression *>(&node);
    auto it = env.find(std::string(ident->value));
    if (it == env.end()) {
      throw RuntimeError(std::format("{} is not initialized!", ident->value),
                         ident->line, ident->column);
    }
    return it->second;
  }
  case AstTag::StatementBlock: {
    auto *statement_block = dynamic_cast<StatementBlock *>(&node);
    for (auto &statement : statement_block->block) {
      if (statement->tag == AstTag::ReturnStatement) {
        auto *return_statement =
            dynamic_cast<ReturnStatement *>(statement.get());
        //
        // early return when we encounter a return statement
        //
        return eval_node(env, *return_statement->value);
      }
      eval_node(env, *statement);
    }
    return make_unit();
  }
  case AstTag::FunctionCallExpression: {
    std::vector<ValuePtr> args;
    //
    // continue here we need to go through the builtins and call the builtin
    // with
    //
    auto *function_call_expression =
        dynamic_cast<FunctionCallExpression *>(&node);
    auto *identifier = dynamic_cast<IdentifierExression *>(
        function_call_expression->function_name_identifier.get());
    auto identifier_str = std::string(identifier->value);
    auto fit = functions.find(identifier_str);

    // pass args into a better format
    for (auto &arg : function_call_expression->args) {
      auto val = eval_node(env, *arg);
      args.push_back(std::move(val));
    }

    if (fit == functions.end()) {
      auto it = builtins.find(identifier_str);
      if (it == builtins.end()) {
        throw RuntimeError("there is no function (builtin) with this name",
                           identifier->line, identifier->column);
      }
      return it->second.function(std::move(args),
                                 function_call_expression->line,
                                 function_call_expression->column);
    }
    //
    // this is a non-builtin function call
    //
    auto &function_definition = fit->second;
    if (args.size() != function_definition.args.size()) {
      throw RuntimeError(
          std::format("function '{}' expects {} arguments but got {}",
                      identifier_str, function_definition.args.size(),
                      args.size()),
          function_call_expression->line, function_call_expression->column);
    }
    for (size_t i = 0; i < args.size(); i++) {
      auto arg = args[i];
      auto arg_name = function_definition.args[i];
      function_definition.closure[arg_name] = arg;
    }
    auto res =
        eval_node(function_definition.closure, *function_definition.body);
    function_definition.closure.clear();
    return res;
  }
  case AstTag::AssignmentStatement: {
    auto *assign = dynamic_cast<AssignmentStatement *>(&node);
    auto *ident_value =
        dynamic_cast<IdentifierExression *>(assign->ident.get());
    auto right_value = eval_node(env, *assign->expression);
    env[std::string(ident_value->value)] = clone_number_or_bool(right_value);
    return make_unit();
  }
  case AstTag::ListExpression: {
    auto *list_expression = dynamic_cast<ListExpresssion *>(&node);
    std::vector<ValuePtr> value_items;
    for (auto &item : list_expression->items) {
      auto i = eval_node(env, *item);
      value_items.push_back(std::move(i));
    }
    auto list_value = std::make_shared<List>(std::move(value_items));
    return list_value;
  }
  case AstTag::FunctionDefinitionStatement: {
    auto *function_definition_statement =
        dynamic_cast<FunctionDefinitionStatement *>(&node);
    auto *name = dynamic_cast<IdentifierExression *>(
        function_definition_statement->name.get());
    std::unordered_map<std::string, ValuePtr> closure;
    std::vector<std::string> str_args;
    for (const auto &arg : function_definition_statement->args) {
      auto ident = dynamic_cast<IdentifierExression *>(arg.get());
      closure[std::string(ident->value)] = make_unit();
      str_args.push_back(std::string(ident->value));
    }
    auto function_def = FunctionDefinition{
        .args = std::move(str_args),
        .body = std::move(function_definition_statement->body),
        .closure = std::move(closure),
        .line = function_definition_statement->line,
        .column = function_definition_statement->column};
    functions.insert_or_assign(std::string(name->value),
                               std::move(function_def));
    return make_unit();
  }
  case AstTag::ReturnStatement: {
    throw RuntimeError("There should be no return here I think return is only "
                       "handled in the statement block",
                       node.line, node.column);
  }
  case AstTag::InfixExpression:
  case AstTag::PrefixExpression:
  case AstTag::PostfixExpression:
    throw std::runtime_error("eval is not implemented for this AST node");
  }

  throw std::runtime_error("unknown AST node");
}
