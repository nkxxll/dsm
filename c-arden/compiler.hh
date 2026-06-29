#pragma once

#include "parser.hh"

#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>
#include <utility>
#include <variant>
#include <vector>

struct BytecodeSourceLocation {
  std::size_t line;
  std::size_t column;

  BytecodeSourceLocation(const AstNode &node)
      : line(node.line), column(node.column) {}
};

enum class BytecodeValueTag {
  Number,
  String,
  Bool,
  Unit,
};

struct BytecodeValue {
  BytecodeValueTag tag;
  std::variant<double, std::string, bool> data;

  static BytecodeValue number(double value) {
    return BytecodeValue{.tag = BytecodeValueTag::Number, .data = value};
  }

  static BytecodeValue string(std::string value) {
    return BytecodeValue{.tag = BytecodeValueTag::String,
                         .data = std::move(value)};
  }

  static BytecodeValue boolean(bool value) {
    return BytecodeValue{.tag = BytecodeValueTag::Bool, .data = value};
  }

  static BytecodeValue unit() {
    return BytecodeValue{.tag = BytecodeValueTag::Unit, .data = false};
  }
};

using ConstantIndex = std::uint32_t;
using NameIndex = std::uint32_t;
using FunctionIndex = std::uint32_t;
using InstructionOffset = std::uint32_t;
using Arity = std::uint16_t;

enum class OpCode : std::uint8_t {
  PushConstant,
  PushUnit,
  LoadGlobal,
  StoreGlobal,
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
  std::vector<BytecodeValue> constants;
  std::vector<std::string> names;

  ConstantIndex add_constant(BytecodeValue value) {
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

struct CompilerError {
  std::string message;
  BytecodeSourceLocation location;
};

struct CompilerResult {
  BytecodeProgram program;
  std::vector<CompilerError> errors;

  bool ok() const { return errors.empty(); }
};

void compile_program(CompilerResult &result, const AstNode &root);
void add_number_literal(CompilerResult &result, const AstNode &root);
