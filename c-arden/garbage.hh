#pragma once
#include <cstddef>
#include <cstdint>
#include <vector>

using ObjRef = uint32_t;

struct GarbageCollection {
  std::vector<std::byte> from_space;
  std::vector<std::byte> to_space;

  size_t capacity;
};

struct Obj;

void *allocate_obj(GarbageCollection &gc, Obj obj, size_t size);
void collet_garbage(GarbageCollection &gc, Obj obj, size_t size);
