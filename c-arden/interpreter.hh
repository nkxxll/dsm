#pragma once

#include <string_view>
#include <unordered_map>

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

struct Unit : Value {
  Unit() : Value(ValueTag::Unit) {}
};

struct String : Value {
  String(std::string_view value) : Value(ValueTag::Number), value(value) {}
  std::string_view value;
};

struct Number : Value {
  Number(double value) : Value(ValueTag::Number), value(value) {}
  double value;
};

using Environment = std::unordered_map<std::string, Value>;
