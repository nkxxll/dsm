#pragma once

#include "parser.hh"

#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>
#include <string_view>
#include <unordered_map>
#include <utility>
#include <variant>
#include <vector>

struct BytecodeSourceLocation {
  std::size_t line;
  std::size_t column;

  BytecodeSourceLocation(const AstNode &node)
      : line(node.line), column(node.column) {}
};

enum class VmValueTag {
  Number,
  String,
  Bool,
  List,
  Unit,
};

struct VmList;
using VmListPtr = std::shared_ptr<VmList>;

struct VmValue {
  VmValueTag tag;
  std::variant<std::monostate, double, std::string, bool, VmListPtr> data;

  static VmValue number(double value) {
    return VmValue{.tag = VmValueTag::Number, .data = value};
  }

  static VmValue string(std::string value) {
    return VmValue{.tag = VmValueTag::String, .data = std::move(value)};
  }

  static VmValue boolean(bool value) {
    return VmValue{.tag = VmValueTag::Bool, .data = value};
  }

  static VmValue list(std::vector<VmValue> items);

  static VmValue unit() {
    return VmValue{.tag = VmValueTag::Unit, .data = std::monostate{}};
  }
};

struct VmList {
  std::vector<VmValue> items;
};

inline VmValue VmValue::list(std::vector<VmValue> items) {
  return VmValue{.tag = VmValueTag::List,
                 .data = std::make_shared<VmList>(VmList{std::move(items)})};
}

using ConstantIndex = std::uint32_t;
using NameIndex = std::uint32_t;
using BuiltinIndex = std::uint32_t;
using FunctionIndex = std::uint32_t;
using InstructionOffset = std::uint32_t;
using Arity = std::uint16_t;

enum class OpCode : std::uint8_t {
  PushConstant,
  PushUnit,
  LoadGlobal,
  StoreGlobal,
  LoadLocal,
  StoreLocal,
  Add,
  Subtract,
  Multiply,
  Divide,
  Power,
  Negate,
  ToYears,
  ToMonths,
  ToWeeks,
  ToDays,
  ToHours,
  ToMinutes,
  ToSeconds,
  MakeList,
  CallBuiltin,
  CallFunction,
  Pop,
  JumpIfFalse,
  Jump,
  Return,
};

struct Instruction {
  OpCode op;
  std::uint32_t operand = 0;
  std::uint32_t operand2 = 0;
  BytecodeSourceLocation location;
};

struct Chunk {
  std::vector<Instruction> instructions;
  std::vector<VmValue> constants;
  std::vector<std::string> names;

  ConstantIndex add_constant(VmValue value) {
    constants.push_back(std::move(value));
    return static_cast<ConstantIndex>(constants.size() - 1);
  }

  NameIndex add_name(std::string_view name) {
    names.emplace_back(name);
    return static_cast<NameIndex>(names.size() - 1);
  }

  InstructionOffset emit(OpCode op, BytecodeSourceLocation location,
                         std::uint32_t operand = 0,
                         std::uint32_t operand2 = 0) {
    instructions.push_back(Instruction{.op = op,
                                       .operand = operand,
                                       .operand2 = operand2,
                                       .location = location});
    return static_cast<InstructionOffset>(instructions.size() - 1);
  }
};

struct BytecodeFunction {
  std::string name;
  std::vector<std::string> parameters;
  Chunk chunk;
  BytecodeSourceLocation location;
};

struct BytecodeProgram {
  Chunk main;
  std::vector<BytecodeFunction> functions;
};

struct Diagnostic {
  std::string message;
  BytecodeSourceLocation location;
};

using CompilerError = Diagnostic;

struct CompilerResult {
  BytecodeProgram program;
  std::vector<CompilerError> errors;

  bool ok() const { return errors.empty(); }
};

struct CompilerContext {
  CompilerResult &result;
  Chunk &chunk;
  std::unordered_map<std::string, FunctionIndex> &function_indexes;
  std::vector<std::string> locals;
  bool in_function;
};

void compile_program(CompilerResult &result, const AstNode &root);
void add_number_literal(CompilerResult &result, const AstNode &root);
void compile_if_statement(CompilerContext &context, const AstNode &root);
void compile_for_statement(CompilerContext &context, const AstNode &root);
void compile_node(CompilerContext &context, const AstNode &root);
