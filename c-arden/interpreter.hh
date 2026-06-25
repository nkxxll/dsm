#pragma once

#include "parser.hh"

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
  Unit,
};

struct Value {
  Value(ValueTag tag) : tag(tag) {}
  ValueTag tag;
  virtual ~Value() = default;
};

using ValuePtr = std::unique_ptr<Value>;

struct Unit : Value {
  Unit() : Value(ValueTag::Unit) {}
};

struct String : Value {
  String(std::string_view value) : Value(ValueTag::String), value(value) {}
  std::string_view value;
};

struct Number : Value {
  Number(double value) : Value(ValueTag::Number), value(value) {}
  double value;
};

using ValuePtr = std::unique_ptr<Value>;
using Environment = std::unordered_map<std::string, ValuePtr>;

ValuePtr eval(Environment &env, AstNodePtr node);
