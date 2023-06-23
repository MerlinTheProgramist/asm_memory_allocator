#pragma once

#include "stdlib.h"

extern "C" void heap_init();
extern "C" [[nodiscard]] void* heap_alloc(size_t size);
extern "C" void heap_free(void* addr);
extern "C" void* heap_realloc(void* addr, size_t new_size);
