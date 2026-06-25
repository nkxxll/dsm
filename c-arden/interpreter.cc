#include "interpreter.hh"
#include "parser.hh"
#include <format>
#include <iostream>
#include <memory>
#include <stdexcept>

RuntimeError::RuntimeError(const std::string &message, const size_t line,
                           const size_t column)
    : std::runtime_error(
          std::format("{} at {}:{}", message, line, column)) {}

ValuePtr make_unit() { return std::make_unique<Value>(Unit()); };

static ValuePtr clone_value(const Value &value) {
  switch (value.tag) {
  case ValueTag::Number: {
    auto *number = dynamic_cast<const Number *>(&value);
    return std::make_unique<Number>(number->value);
  }
  case ValueTag::String: {
    auto *string = dynamic_cast<const String *>(&value);
    return std::make_unique<String>(string->value);
  }
  case ValueTag::Unit:
    return make_unit();
  }

  throw std::runtime_error("unknown value");
}

ValuePtr write(ValuePtr value) {
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
  }
  std::cout << std::endl;
  return make_unit();
}

// https://craftinginterpreters.com/contents.html
ValuePtr eval(Environment &env, AstNodePtr node) {
  (void)env;

  switch (node->tag) {
  case AstTag::WriteStatement: {
    auto *write_statement = dynamic_cast<WriteStatement *>(node.get());
    auto right_hand_side = std::move(write_statement->right_hand_side);
    return write(eval(env, std::move(right_hand_side)));
  }
  case AstTag::NumberLiteral: {
    auto *value = dynamic_cast<NumberLiteral *>(node.get());
    return std::make_unique<Number>(value->value);
  }
  case AstTag::StringLiteral: {
    auto *value = dynamic_cast<StringLiteral *>(node.get());
    return std::make_unique<String>(value->value);
  }
  case AstTag::BooleanLiteral:
  case AstTag::Identifier: {
    auto *ident = dynamic_cast<IdentifierExression *>(node.get());
    auto it = env.find(std::string(ident->value));
    if (it == env.end()) {
      throw RuntimeError(std::format("{} is not initialized!", ident->value),
                         ident->line, ident->column);
    }
    return clone_value(*it->second);
  }
  case AstTag::InfixExpression:
  case AstTag::PrefixExpression:
  case AstTag::PostfixExpression:
  case AstTag::AssignmentStatement: {
    auto *assign = dynamic_cast<AssignmentStatement *>(node.get());
    auto *ident_value =
        dynamic_cast<IdentifierExression *>(assign->ident.get());
    auto right_value = eval(env, std::move(assign->expression));
    env[std::string(ident_value->value)] = std::move(right_value);
    return make_unit();
  }
  case AstTag::FunctionCallExpression:
    throw std::runtime_error("eval is not implemented for this AST node");
  case AstTag::StatementBlock:
    break;
  }

  throw std::runtime_error("unknown AST node");
}
