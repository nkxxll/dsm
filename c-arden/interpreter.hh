#pragma once

#include "parser.hh"

#include <functional>
#include <memory>
#include <string>
#include <string_view>
#include <unordered_map>

struct RuntimeError : std::runtime_error {
  RuntimeError(const std::string &message, const size_t line,
               const size_t column);
};

enum class ValueTag {
  Number,
  String,
  Bool,
  List,
  Unit,
};

struct Value {
  Value(ValueTag tag) : tag(tag) {}
  ValueTag tag;
  virtual ~Value() = default;
};

using ValuePtr = std::shared_ptr<Value>;
using Environment = std::unordered_map<std::string, ValuePtr>;

using Args = std::vector<ValuePtr>;
using BuiltinFn =
    std::function<ValuePtr(Args args, size_t line, size_t column)>;
struct BuiltingFnEntry {
  size_t args_len;
  BuiltinFn function;
};

struct FunctionDefinition {
  std::vector<std::string> args;
  AstNodePtr body;
  Environment closure;
  size_t line;
  size_t column;
};

struct List : Value {
  List(std::vector<ValuePtr> items)
      : Value(ValueTag::List), items(std::move(items)) {}
  std::vector<ValuePtr> items;
};

struct Unit : Value {
  Unit() : Value(ValueTag::Unit) {}
};

struct String : Value {
  String(std::string_view value) : Value(ValueTag::String), value(value) {}
  std::string_view value;
};

struct Bool : Value {
  Bool(bool value) : Value(ValueTag::Bool), value(value) {}
  bool value;
};

struct Number : Value {
  Number(double value) : Value(ValueTag::Number), value(value) {}
  double value;
};

ValuePtr eval(Environment &env, AstNodePtr node);
ValuePtr write(ValuePtr value, std::optional<size_t> line);
ValuePtr eval_node(Environment &env, AstNode &node);
