#include "vm.hh"
#include "compiler.hh"

#include <cassert>
#include <cmath>
#include <iostream>
#include <optional>
#include <sstream>
#include <utility>
#include <variant>

namespace {

VmResult vm_wrong_arity(const char *name, std::size_t expected,
                        std::size_t actual, BytecodeSourceLocation location) {
  return vm_error(std::string("The ") + name + " function only expects " +
                      std::to_string(expected) + " argument got " +
                      std::to_string(actual),
                  location);
}

void vm_write_type(const VmValue &value) {
  switch (value.tag) {
  case VmValueTag::Number:
    std::cout << std::get<double>(value.data);
    break;
  case VmValueTag::String:
    std::cout << std::get<std::string>(value.data);
    break;
  case VmValueTag::Unit:
    std::cout << "Unit";
    break;
  case VmValueTag::Bool:
    std::cout << (std::get<bool>(value.data) ? "true" : "false");
    break;
  case VmValueTag::List:
    std::cout << "unknown";
    break;
  }
}

VmResult vm_write_value(const VmValue &value, std::optional<std::size_t> line) {
  if (line.has_value()) {
    std::cout << "Line " << *line << ": ";
  }

  if (value.tag == VmValueTag::List) {
    const auto &items = std::get<VmListPtr>(value.data)->items;
    std::cout << "[";
    for (std::size_t i = 0; i < items.size(); i++) {
      if (i != 0) {
        std::cout << ", ";
      }
      vm_write_type(items[i]);
    }
    std::cout << "]";
  } else {
    vm_write_type(value);
  }

  std::cout << std::endl;
  return vm_success(VmValue::unit());
}

} // namespace

Vm make_vm(const BytecodeProgram &program) {
  return make_vm(program, {}, make_default_vm_builtins());
}

VmBuiltins make_default_vm_builtins() {
  return VmBuiltins{
      VmBuiltin{.name = "write",
                .arity = 1,
                .function =
                    [](Vm &, std::span<const VmValue> args,
                       BytecodeSourceLocation location) {
                      if (args.size() != 1) {
                        return vm_wrong_arity("write", 1, args.size(),
                                              location);
                      }
                      return vm_write_value(args.front(), std::nullopt);
                    }},
      VmBuiltin{.name = "trace",
                .arity = 1,
                .function =
                    [](Vm &, std::span<const VmValue> args,
                       BytecodeSourceLocation location) {
                      if (args.size() != 1) {
                        return vm_wrong_arity("trace", 1, args.size(),
                                              location);
                      }
                      return vm_write_value(args.front(), location.line);
                    }},
      VmBuiltin{.name = "is_number",
                .arity = 1,
                .function =
                    [](Vm &, std::span<const VmValue> args,
                       BytecodeSourceLocation location) {
                      if (args.size() != 1) {
                        return vm_wrong_arity("is_number", 1, args.size(),
                                              location);
                      }
                      return vm_success(VmValue::boolean(args.front().tag ==
                                                         VmValueTag::Number));
                    }},
      VmBuiltin{.name = "is_list",
                .arity = 1,
                .function =
                    [](Vm &, std::span<const VmValue> args,
                       BytecodeSourceLocation location) {
                      if (args.size() != 1) {
                        return vm_wrong_arity("is_list", 1, args.size(),
                                              location);
                      }
                      return vm_success(VmValue::boolean(args.front().tag ==
                                                         VmValueTag::List));
                    }},
  };
}

Vm make_vm(const BytecodeProgram &program, VmGlobals globals,
           VmBuiltins builtins) {
  return Vm{.program = &program,
            .stack = {},
            .frames = {},
            .globals = std::move(globals),
            .functions = program.functions,
            .builtins = std::move(builtins)};
}

VmResult type_error(std::string type_string_expected,
                    BytecodeSourceLocation location) {
  return VmResult{
      .value = std::nullopt,
      .errors = {VmError{.message = "type is not correct should be " +
                                    type_string_expected,
                         .location = location}}};
}

VmResult vm_binary(Vm &vm, const Instruction &instruction) {
  auto op = instruction.op;
  auto &stack = vm.stack;
  size_t sp = stack.size() - 1;
  auto right = vm.stack[sp];
  auto left = vm.stack[sp - 1];
  if (!std::holds_alternative<double>(right.data)) {
    return type_error("double", instruction.location);
  }
  if (!std::holds_alternative<double>(left.data)) {
    return type_error("double", instruction.location);
  }
  stack.pop_back();
  switch (op) {
  case OpCode::Add: {
    vm.stack[sp - 1] =
        VmValue(VmValueTag::Number,
                std::get<double>(left.data) + std::get<double>(right.data));
    break;
  }
  case OpCode::Subtract: {
    vm.stack[sp - 1] =
        VmValue(VmValueTag::Number,
                std::get<double>(left.data) - std::get<double>(right.data));
    break;
  }
  case OpCode::Multiply: {
    vm.stack[sp - 1] =
        VmValue(VmValueTag::Number,
                std::get<double>(left.data) * std::get<double>(right.data));
    break;
  }
  case OpCode::Divide: {
    vm.stack[sp - 1] =
        VmValue(VmValueTag::Number,
                std::get<double>(left.data) / std::get<double>(right.data));
    break;
  }
  case OpCode::Power: {
    vm.stack[sp - 1] =
        VmValue(VmValueTag::Number, std::pow(std::get<double>(left.data),
                                             std::get<double>(right.data)));
    break;
  }
  default: {
    return VmResult{.value = std::nullopt,
                    .errors = {VmError{.message = "is not an infix operation",
                                       .location = instruction.location}}};
  }
  }
  return VmResult{.value = std::nullopt, .errors = {}};
}

VmResult vm_negate(Vm &vm, const Instruction &instruction) {
  if (vm.stack.empty()) {
    return VmResult{.value = std::nullopt,
                    .errors = {VmError{.message = "stack was empty on negate",
                                       .location = instruction.location}}};
  }

  auto &value = vm.stack.back();
  if (!std::holds_alternative<double>(value.data)) {
    return type_error("double", instruction.location);
  }

  value = VmValue::number(-std::get<double>(value.data));
  return VmResult{.value = std::nullopt, .errors = {}};
}

static VmResult vm_scale_number(Vm &vm, const Instruction &instruction,
                                double factor, const char *operation) {
  if (vm.stack.empty()) {
    return VmResult{
        .value = std::nullopt,
        .errors = {
            VmError{.message = std::string("stack was empty on ") + operation,
                    .location = instruction.location}}};
  }

  auto &value = vm.stack.back();
  if (!std::holds_alternative<double>(value.data)) {
    return type_error("double", instruction.location);
  }

  value = VmValue::number(std::get<double>(value.data) * factor);
  return VmResult{.value = std::nullopt, .errors = {}};
}

VmResult vm_to_years(Vm &vm, const Instruction &instruction) {
  return vm_scale_number(vm, instruction, 365.0 * 24.0 * 60.0 * 60.0,
                         "to years");
}

VmResult vm_to_months(Vm &vm, const Instruction &instruction) {
  return vm_scale_number(vm, instruction, 30.0 * 24.0 * 60.0 * 60.0,
                         "to months");
}

VmResult vm_to_weeks(Vm &vm, const Instruction &instruction) {
  return vm_scale_number(vm, instruction, 7.0 * 24.0 * 60.0 * 60.0, "to weeks");
}

VmResult vm_to_days(Vm &vm, const Instruction &instruction) {
  return vm_scale_number(vm, instruction, 24.0 * 60.0 * 60.0, "to days");
}

VmResult vm_to_hours(Vm &vm, const Instruction &instruction) {
  return vm_scale_number(vm, instruction, 60.0 * 60.0, "to hours");
}

VmResult vm_to_minutes(Vm &vm, const Instruction &instruction) {
  return vm_scale_number(vm, instruction, 60.0, "to minutes");
}

VmResult vm_to_seconds(Vm &vm, const Instruction &instruction) {
  return vm_scale_number(vm, instruction, 1.0, "to seconds");
}

VmResult vm_load_local(Vm &vm, const Chunk &, const Instruction &instruction) {
  if (vm.frames.empty()) {
    return VmResult{
        .value = std::nullopt,
        .errors = {VmError{.message = "no active call frame for local load",
                           .location = instruction.location}}};
  }

  auto index = vm.frames.back().stack_base + instruction.operand;
  if (index >= vm.stack.size()) {
    return VmResult{
        .value = std::nullopt,
        .errors = {VmError{.message = "local load index out of bounds",
                           .location = instruction.location}}};
  }

  vm.stack.push_back(vm.stack[index]);
  return VmResult{.value = std::nullopt, .errors = {}};
}

VmResult vm_store_local(Vm &vm, const Chunk &, const Instruction &instruction) {
  if (vm.frames.empty()) {
    return VmResult{
        .value = std::nullopt,
        .errors = {VmError{.message = "no active call frame for local store",
                           .location = instruction.location}}};
  }
  if (vm.stack.empty()) {
    return VmResult{
        .value = std::nullopt,
        .errors = {VmError{.message = "stack was empty on local store",
                           .location = instruction.location}}};
  }

  auto value = vm.stack.back();
  vm.stack.pop_back();

  auto index = vm.frames.back().stack_base + instruction.operand;
  if (index >= vm.stack.size()) {
    vm.stack.resize(index + 1, VmValue::unit());
  }
  vm.stack[index] = value;
  return VmResult{.value = std::nullopt, .errors = {}};
}

VmResult vm_store_global(Vm &vm, const Chunk &chunk,
                         const Instruction &instruction) {
  const auto &name = chunk.names[instruction.operand];
  if (vm.stack.size() == 0) {
    return VmResult{.value = std::nullopt,
                    .errors = {VmError{
                        .message = "stack was empty on store global of" + name,
                        .location = instruction.location}}};
  }
  auto value = vm.stack[vm.stack.size() - 1];
  vm.stack.pop_back();
  vm.globals[name] = value;
  return VmResult{.value = std::nullopt, .errors = {}};
}

VmResult vm_load_global(Vm &vm, const Chunk &chunk,
                        const Instruction &instruction) {
  const auto &name = chunk.names[instruction.operand];
  auto global = vm.globals.find(name);
  if (global == vm.globals.end()) {
    return VmResult{.value = std::nullopt,
                    .errors = {VmError{.message = "unknown global: " + name,
                                       .location = instruction.location}}};
  }

  vm.stack.push_back(global->second);
  return VmResult{.value = std::nullopt, .errors = {}};
}

VmResult vm_call_function(Vm &vm, const Instruction &instruction, int pc) {
  auto function_index = instruction.operand;
  auto arg_count = instruction.operand2;

  if (function_index >= vm.program->functions.size()) {
    return VmResult{.value = std::nullopt,
                    .errors = {{.message = "function index out of bounds",
                                .location = instruction.location}}};
  }

  const auto &func = vm.program->functions[function_index];

  if (arg_count != func.parameters.size()) {
    return VmResult{.value = std::nullopt,
                    .errors = {{.message = "wrong number of arguments",
                                .location = instruction.location}}};
  }

  if (vm.stack.size() < arg_count) {
    return VmResult{.value = std::nullopt,
                    .errors = {{.message = "stack underflow on function call",
                                .location = instruction.location}}};
  }

  vm.frames.push_back(VmCallFrame{
      .chunk = &vm.program->main,
      .instruction_pointer = static_cast<InstructionOffset>(pc + 1),
      .stack_base = vm.stack.size() - arg_count,
      .function_index = function_index,
  });

  return VmResult{.value = std::nullopt, .errors = {}};
}

VmResult vm_make_list(Vm &vm, const Instruction &instruction) {
  auto item_count = instruction.operand;
  if (vm.stack.size() < item_count) {
    return VmResult{.value = std::nullopt,
                    .errors = {{.message = "stack underflow on list creation",
                                .location = instruction.location}}};
  }

  auto first = std::prev(vm.stack.end(), item_count);
  std::vector<VmValue> items(first, vm.stack.end());
  vm.stack.erase(first, vm.stack.end());
  vm.stack.push_back(VmValue::list(std::move(items)));
  return VmResult{.value = std::nullopt, .errors = {}};
}

VmResult vm_call_builtin(Vm &vm, const Chunk &,
                         const Instruction &instruction) {
  auto function_index = instruction.operand;
  auto args_count = instruction.operand2;

  if (function_index >= vm.builtins.size()) {
    return VmResult{.value = std::nullopt,
                    .errors = {{.message = "builtin index out of bounds",
                                .location = instruction.location}}};
  }
  if (vm.stack.size() < args_count) {
    return VmResult{.value = std::nullopt,
                    .errors = {{.message = "stack underflow on builtin call",
                                .location = instruction.location}}};
  }

  auto builtin = vm.builtins[function_index];
  if (args_count != builtin.arity) {
    return VmResult{.value = std::nullopt,
                    .errors = {{.message = "wrong number of builtin arguments",
                                .location = instruction.location}}};
  }

  auto args = std::span(std::prev(vm.stack.end(), args_count), vm.stack.end());

  auto result = builtin.function(vm, args, instruction.location);
  if (!result.errors.empty()) {
    return result;
  }

  vm.stack.resize(vm.stack.size() - args_count);
  if (result.value.has_value()) {
    vm.stack.push_back(*result.value);
  }
  return VmResult{.value = std::nullopt, .errors = {}};
}

VmResult run(Vm &vm) {
  size_t pc = 0;
  const Chunk *chunk = &vm.program->main;
  auto &stack = vm.stack;
  for (;;) {
    auto &constants = chunk->constants;
    auto &instructions = chunk->instructions;
    if (pc >= instructions.size()) {
      if (vm.stack.empty()) {
        return vm_success(VmValue::unit());
      }
      return vm_success(vm.stack.back());
    }
    auto instruction = instructions[pc];
    switch (instruction.op) {
    case OpCode::PushConstant: {
      auto const_value = constants[instruction.operand];
      stack.push_back(const_value);
      break;
    }
    case OpCode::PushUnit: {
      stack.push_back(VmValue::unit());
      break;
    }
    case OpCode::LoadGlobal: {
      auto result = vm_load_global(vm, *chunk, instruction);
      if (!result.errors.empty()) {
        return result;
      }
      break;
    }
    case OpCode::StoreGlobal: {
      auto result = vm_store_global(vm, *chunk, instruction);
      if (!result.errors.empty()) {
        return result;
      }
      break;
    }
    case OpCode::LoadLocal: {
      auto result = vm_load_local(vm, *chunk, instruction);
      if (!result.errors.empty()) {
        return result;
      }
      break;
    }
    case OpCode::StoreLocal: {
      auto result = vm_store_local(vm, *chunk, instruction);
      if (!result.errors.empty()) {
        return result;
      }
      break;
    }
    case OpCode::Add:
    case OpCode::Subtract:
    case OpCode::Multiply:
    case OpCode::Divide:
    case OpCode::Power: {

      auto result = vm_binary(vm, instruction);
      if (!result.errors.empty()) {
        return result;
      }
      break;
    }
    case OpCode::Negate: {
      auto result = vm_negate(vm, instruction);
      if (!result.errors.empty()) {
        return result;
      }
      break;
    }
    case OpCode::ToYears: {
      auto result = vm_to_years(vm, instruction);
      if (!result.errors.empty()) {
        return result;
      }
      break;
    }
    case OpCode::ToMonths: {
      auto result = vm_to_months(vm, instruction);
      if (!result.errors.empty()) {
        return result;
      }
      break;
    }
    case OpCode::ToWeeks: {
      auto result = vm_to_weeks(vm, instruction);
      if (!result.errors.empty()) {
        return result;
      }
      break;
    }
    case OpCode::ToDays: {
      auto result = vm_to_days(vm, instruction);
      if (!result.errors.empty()) {
        return result;
      }
      break;
    }
    case OpCode::ToHours: {
      auto result = vm_to_hours(vm, instruction);
      if (!result.errors.empty()) {
        return result;
      }
      break;
    }
    case OpCode::ToMinutes: {
      auto result = vm_to_minutes(vm, instruction);
      if (!result.errors.empty()) {
        return result;
      }
      break;
    }
    case OpCode::ToSeconds: {
      auto result = vm_to_seconds(vm, instruction);
      if (!result.errors.empty()) {
        return result;
      }
      break;
    }
    case OpCode::MakeList: {
      auto result = vm_make_list(vm, instruction);
      if (!result.errors.empty()) {
        return result;
      }
      break;
    }
    case OpCode::CallBuiltin: {
      auto result = vm_call_builtin(vm, *chunk, instruction);
      if (!result.errors.empty()) {
        return result;
      }
      break;
    }
    case OpCode::CallFunction: {
      auto result = vm_call_function(vm, instruction, pc);
      if (!result.errors.empty()) {
        return result;
      }
      chunk = &vm.program->functions[instruction.operand].chunk;
      pc = 0;
      continue;
    }
    case OpCode::Pop: {
      vm.stack.pop_back();
      break;
    }
    case OpCode::Return: {
      if (vm.frames.empty()) {
        return VmResult{
            .value = std::nullopt,
            .errors = {VmError{.message = "return without call frame",
                               .location = instruction.location}}};
      }
      if (vm.stack.empty()) {
        return VmResult{
            .value = std::nullopt,
            .errors = {VmError{.message = "stack was empty on return",
                               .location = instruction.location}}};
      }

      auto return_val = vm.stack.back();
      auto frame = vm.frames.back();
      vm.frames.pop_back();

      auto bp = frame.stack_base;
      if (bp >= vm.stack.size()) {
        return VmResult{
            .value = std::nullopt,
            .errors = {VmError{.message = "return stack base out of bounds",
                               .location = instruction.location}}};
      }

      vm.stack.resize(bp + 1);
      vm.stack[bp] = return_val;

      chunk = frame.chunk;
      pc = frame.instruction_pointer;
      continue;
    }
    case OpCode::JumpIfFalse: {
      if (vm.stack.empty()) {
        return VmResult{.value = std::nullopt,
                        .errors = {VmError{.message = "stack was empty on jump",
                                           .location = instruction.location}}};
      }
      auto boolean = stack.back();
      stack.pop_back();
      if (std::holds_alternative<bool>(boolean.data)) {
        if (std::get<bool>(boolean.data)) {
          break;
        } else {
          pc = instruction.operand;
          continue;
        }
      } else {
        return VmResult{
            .value = std::nullopt,
            .errors = {VmError{.message = "condition is not a boolean value",
                               .location = instruction.location}}};
      }
    }
    case OpCode::Jump: {
      pc = instruction.operand;
      continue;
    }
    }
    pc++;
  }
}

bool VmResult::ok() const { return errors.empty(); }

VmResult run_program(const BytecodeProgram &program) {
  auto vm = make_vm(program);
  return run(vm);
}

VmResult run_program(const BytecodeProgram &program, VmGlobals globals,
                     VmBuiltins builtins) {
  auto vm = make_vm(program, std::move(globals), std::move(builtins));
  return run(vm);
}

bool vm_is_truthy(const VmValue &value) {
  if (value.tag == VmValueTag::Bool) {
    return std::get<bool>(value.data);
  }
  if (value.tag == VmValueTag::Unit) {
    return false;
  }
  return true;
}

std::string vm_value_to_string(const VmValue &value) {
  std::ostringstream out;
  switch (value.tag) {
  case VmValueTag::Number:
    out << std::get<double>(value.data);
    break;
  case VmValueTag::String:
    out << std::get<std::string>(value.data);
    break;
  case VmValueTag::Bool:
    out << (std::get<bool>(value.data) ? "true" : "false");
    break;
  case VmValueTag::Unit:
    out << "Unit";
    break;
  case VmValueTag::List: {
    const auto &items = std::get<VmListPtr>(value.data)->items;
    out << "[";
    for (std::size_t i = 0; i < items.size(); i++) {
      if (i != 0) {
        out << ", ";
      }
      out << vm_value_to_string(items[i]);
    }
    out << "]";
    break;
  }
  }
  return out.str();
}

VmResult vm_error(std::string message, BytecodeSourceLocation location) {
  return VmResult{
      .value = std::nullopt,
      .errors = {VmError{.message = std::move(message), .location = location}}};
}

VmResult vm_success(VmValue value) {
  return VmResult{.value = std::move(value), .errors = {}};
}
