#include "compiler.hh"
#include "parser.hh"
#include <algorithm>

namespace {

void add_unsupported_operator_error(CompilerResult &result,
                                    const AstNode &root) {
  result.errors.push_back(
      {"unsupported operator", BytecodeSourceLocation(root)});
}

} // namespace

void add_number_literal(CompilerResult &result, const AstNode &root) {
  auto *num = dynamic_cast<const NumberLiteral *>(&root);
  if (num == nullptr) {
    result.errors.push_back(
        {"expected number literal", BytecodeSourceLocation(root)});
    return;
  }
  auto value = num->value;
  auto const_index =
      result.program.main.add_constant(BytecodeValue::number(value));
  result.program.main.emit(OpCode::PushConstant, BytecodeSourceLocation(root),
                           const_index);
}

void add_string_literal(CompilerResult &result, const AstNode &root) {
  auto *str = dynamic_cast<const StringLiteral *>(&root);
  if (str == nullptr) {
    result.errors.push_back(
        {"expected string literal", BytecodeSourceLocation(root)});
    return;
  }
  auto value = str->value;
  auto const_index = result.program.main.add_constant(
      BytecodeValue::string(std::string(value)));
  result.program.main.emit(OpCode::PushConstant, BytecodeSourceLocation(root),
                           const_index);
}

void add_bool_literal(CompilerResult &result, const AstNode &root) {
  auto *boolean = dynamic_cast<const BooleanLiteral *>(&root);
  if (boolean == nullptr) {
    result.errors.push_back(
        {"expected boolean literal", BytecodeSourceLocation(root)});
    return;
  }
  auto value = boolean->value;
  auto const_index =
      result.program.main.add_constant(BytecodeValue::boolean(value));
  result.program.main.emit(OpCode::PushConstant, BytecodeSourceLocation(root),
                           const_index);
}

void identifier_expression(CompilerResult &result, const AstNode &root) {
  auto *ident = dynamic_cast<const IdentifierExression *>(&root);
  if (ident == nullptr) {
    result.errors.push_back(
        {"expected identifier", BytecodeSourceLocation(root)});
    return;
  }
  auto value = ident->value;
  auto &names = result.program.main.names;
  auto ident_index = std::find(names.begin(), names.end(), value);
  if (ident_index == names.end()) {
    result.errors.push_back(
        {"unknown global name", BytecodeSourceLocation(root)});
    return;
  }
  result.program.main.emit(
      OpCode::LoadGlobal, BytecodeSourceLocation(root),
      static_cast<NameIndex>(std::distance(names.begin(), ident_index)));
}

void infix_expression(CompilerResult &result, const AstNode &root) {
  auto *infix = dynamic_cast<const InfixExpression *>(&root);
  if (infix == nullptr) {
    result.errors.push_back(
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
  compile_program(result, *infix->left_hand_side);
  compile_program(result, *infix->right_hand_side);
  switch (infix->op) {
  case Operator::Plus:
    result.program.main.emit(OpCode::Add, BytecodeSourceLocation(root));
    break;
  case Operator::Minus:
    result.program.main.emit(OpCode::Subtract, BytecodeSourceLocation(root));
    break;
  case Operator::Multipy:
    result.program.main.emit(OpCode::Multiply, BytecodeSourceLocation(root));
    break;
  case Operator::Divide:
    result.program.main.emit(OpCode::Divide, BytecodeSourceLocation(root));
    break;
  case Operator::Power:
    result.program.main.emit(OpCode::Power, BytecodeSourceLocation(root));
    break;
  default:
    add_unsupported_operator_error(result, root);
    break;
  }
}

void prefix_expression(CompilerResult &result, const AstNode &root) {
  auto *prefix = dynamic_cast<const PrefixExpression *>(&root);
  if (prefix == nullptr) {
    result.errors.push_back(
        {"expected prefix expression", BytecodeSourceLocation(root)});
    return;
  }

  compile_program(result, *prefix->right_hand_side);
  switch (prefix->op) {
  case Operator::Minus:
    result.program.main.emit(OpCode::Negate, BytecodeSourceLocation(root));
    break;
  default:
    add_unsupported_operator_error(result, root);
    break;
  }
}

void postfix_expression(CompilerResult &result, const AstNode &root) {
  auto *postfix = dynamic_cast<const PostfixExpression *>(&root);
  if (postfix == nullptr) {
    result.errors.push_back(
        {"expected postfix expression", BytecodeSourceLocation(root)});
    return;
  }

  compile_program(result, *postfix->left_hand_side);
  switch (postfix->op) {
  case Operator::Year:
    result.program.main.emit(OpCode::ToYears, BytecodeSourceLocation(root));
    break;
  case Operator::Month:
    result.program.main.emit(OpCode::ToMonths, BytecodeSourceLocation(root));
    break;
  case Operator::Week:
    result.program.main.emit(OpCode::ToWeeks, BytecodeSourceLocation(root));
    break;
  case Operator::Day:
    result.program.main.emit(OpCode::ToDays, BytecodeSourceLocation(root));
    break;
  case Operator::Hours:
    result.program.main.emit(OpCode::ToHours, BytecodeSourceLocation(root));
    break;
  case Operator::Minutes:
    result.program.main.emit(OpCode::ToMinutes, BytecodeSourceLocation(root));
    break;
  case Operator::Seconds:
    result.program.main.emit(OpCode::ToSeconds, BytecodeSourceLocation(root));
    break;
  default:
    add_unsupported_operator_error(result, root);
    break;
  }
}

void compile_program(CompilerResult &result, const AstNode &root) {
  switch (root.tag) {
  case AstTag::NumberLiteral: {
    add_number_literal(result, root);
    break;
  }
  case AstTag::StringLiteral: {
    add_string_literal(result, root);
    break;
  }
  case AstTag::BooleanLiteral: {
    add_bool_literal(result, root);
    break;
  }
  case AstTag::Identifier: {
    identifier_expression(result, root);
    break;
  }
  case AstTag::InfixExpression: {
    infix_expression(result, root);
    break;
  }
  case AstTag::PrefixExpression: {
    prefix_expression(result, root);
    break;
  }
  case AstTag::PostfixExpression: {
    postfix_expression(result, root);
    break;
  }
  case AstTag::FunctionCallExpression:
  case AstTag::WriteStatement:
  case AstTag::AssignmentStatement:
  case AstTag::StatementBlock:
  case AstTag::ListExpression:
  case AstTag::FunctionDefinitionStatement:
  case AstTag::ReturnStatement:
    break;
  }
}
