#pragma once

#include "compiler.hh"

#include <cstddef>
#include <functional>
#include <optional>
#include <span>
#include <string>
#include <unordered_map>
#include <vector>

using VmError = Diagnostic;

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
  std::string name;
  Arity arity;
  VmBuiltinFn function;
};

using VmBuiltins = std::vector<VmBuiltin>;

using VmFunction = BytecodeFunction;
using VmFunctions = std::span<const VmFunction>;

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
  VmFunctions functions;
  VmBuiltins builtins;
};

Vm make_vm(const BytecodeProgram &program);
Vm make_vm(const BytecodeProgram &program, VmGlobals globals,
           VmBuiltins builtins);
VmBuiltins make_default_vm_builtins();

VmResult run(Vm &vm);
VmResult run_program(const BytecodeProgram &program);
VmResult run_program(const BytecodeProgram &program, VmGlobals globals,
                     VmBuiltins builtins);

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
VmResult vm_load_local(Vm &vm, const Chunk &chunk,
                        const Instruction &instruction);
VmResult vm_store_local(Vm &vm, const Chunk &chunk,
                         const Instruction &instruction);
VmResult vm_load_global(Vm &vm, const Chunk &chunk,
                        const Instruction &instruction);
VmResult vm_store_global(Vm &vm, const Chunk &chunk,
                         const Instruction &instruction);
VmResult vm_binary(Vm &vm, const Instruction &instruction);
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
VmResult vm_call_function(Vm &vm, const Instruction &instruction, int pc);
VmResult vm_pop(Vm &vm, const Instruction &instruction);
VmResult vm_return(Vm &vm, const Instruction &instruction);
