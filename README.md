Compiled with yasm
```bash
  make all  # make no debug
  make debug # make with debug with test
```

# heap_init ()
  Initialize heap
# heap_alloc (size_t size) -> void*
  allocate `size` and return pointer to the start
# heap_free (void* addr) 
  free memory at `addr` 
# heap_realloc (void* addr, size_t new_size) -> void*
  allocate more memory for `addr` to `new_size` 
  updated memory address is returned

## note 
this project is compatible with standard x86 ABI,   
hence all functions can be called from any other binary.
This is presented with C/C++ header included