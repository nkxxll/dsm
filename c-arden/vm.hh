#pragma once

#include "compiler.hh"

#include <cstddef>
#include <functional>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <unordered_map>
#include <variant>
#include <vector>

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
};

struct VmList {
  std::vector<VmValue> items;
};

struct VmError {
  std::string message;
  BytecodeSourceLocation location;
};

struct VmResult {
  std::optional<VmValue> value;
  std::vector<VmError> errors;

  bool ok() const;
};

using VmGlobals = std::unordered_map<std::string, VmValue>;

struct Vm;
using VmBuiltinFn = std::function<VmResult(Vm &, std::span<const VmValue>,
                                           BytecodeSourceLocation)>;

struct VmBuiltin {
  Arity arity;
  VmBuiltinFn function;
};

using VmBuiltins = std::unordered_map<std::string, VmBuiltin>;

struct VmCallFrame {
  const Chunk *chunk;
  InstructionOffset instruction_pointer;
  std::size_t stack_base;
  FunctionIndex function_index;
};

struct Vm {
  const BytecodeProgram *program;
  std::vector<VmValue> stack;
  std::vector<VmCallFrame> frames;
  VmGlobals globals;
  VmBuiltins builtins;
};

Vm make_vm(const BytecodeProgram &program);
Vm make_vm(const BytecodeProgram &program, VmGlobals globals,
           VmBuiltins builtins);

VmResult run(Vm &vm);
VmResult run_program(const BytecodeProgram &program);
VmResult run_program(const BytecodeProgram &program, VmGlobals globals,
                     VmBuiltins builtins);

VmValue vm_number(double value);
VmValue vm_string(std::string value);
VmValue vm_bool(bool value);
VmValue vm_list(std::vector<VmValue> items);
VmValue vm_unit();

VmValue bytecode_value_to_vm_value(const BytecodeValue &value);

bool vm_is_truthy(const VmValue &value);
std::string vm_value_to_string(const VmValue &value);

VmResult vm_error(std::string message, BytecodeSourceLocation location);
VmResult vm_success(VmValue value);

VmResult execute_chunk(Vm &vm, const Chunk &chunk);
VmResult execute_instruction(Vm &vm, const Chunk &chunk,
                             const Instruction &instruction);

VmResult vm_push_constant(Vm &vm, const Chunk &chunk,
                          const Instruction &instruction);
VmResult vm_push_unit(Vm &vm, const Instruction &instruction);
VmResult vm_load_global(Vm &vm, const Chunk &chunk,
                        const Instruction &instruction);
VmResult vm_store_global(Vm &vm, const Chunk &chunk,
                         const Instruction &instruction);
VmResult vm_binary_add(Vm &vm, const Instruction &instruction);
VmResult vm_binary_subtract(Vm &vm, const Instruction &instruction);
VmResult vm_binary_multiply(Vm &vm, const Instruction &instruction);
VmResult vm_binary_divide(Vm &vm, const Instruction &instruction);
VmResult vm_binary_power(Vm &vm, const Instruction &instruction);
VmResult vm_negate(Vm &vm, const Instruction &instruction);
VmResult vm_to_years(Vm &vm, const Instruction &instruction);
VmResult vm_to_months(Vm &vm, const Instruction &instruction);
VmResult vm_to_weeks(Vm &vm, const Instruction &instruction);
VmResult vm_to_days(Vm &vm, const Instruction &instruction);
VmResult vm_to_hours(Vm &vm, const Instruction &instruction);
VmResult vm_to_minutes(Vm &vm, const Instruction &instruction);
VmResult vm_to_seconds(Vm &vm, const Instruction &instruction);
VmResult vm_make_list(Vm &vm, const Instruction &instruction);
VmResult vm_call_builtin(Vm &vm, const Chunk &chunk,
                         const Instruction &instruction);
VmResult vm_call_function(Vm &vm, const Instruction &instruction);
VmResult vm_pop(Vm &vm, const Instruction &instruction);
VmResult vm_return(Vm &vm, const Instruction &instruction);
