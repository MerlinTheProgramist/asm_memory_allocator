global _start

extern heap_init
extern heap_free
extern heap_alloc
extern heap_header_debug

extern print_endl
extern print_num

%include "../libs/macros.asm"

section .text

_start:
    %define n 8
    call heap_init

    ; first alloc
    mov  rdi, n
    call heap_alloc     ; rax = malloc()

    mov  DWORD[rax], "SUCC"
    mov  DWORD[rax+4], "ESS"
    mov  BYTE[rax+7], 10
    print rax, n

    mov  rdi, rax       ; rdi = rax
    call heap_header_debug
    
    push rax ; first alloc

    ; second alloc
    mov rdi, 1
    call heap_alloc

    mov BYTE[rax], "!"
    
    print rax, 1
    call print_endl

    pop rdi ; first alloc
    push rax ; second alloc

    ; free first 
    call heap_free
    call heap_header_debug

    mov rax, rdi
    call print_num  ; rax
    call print_endl

    ; reallocate to existing mem
    mov rdi, 8
    call heap_alloc
    mov rdi, rax
    call heap_header_debug

    call print_num ;rax
    call print_endl

    pop rax
    print rax, 1
    call print_endl

    mov rdi, 10
    call heap_alloc
    call print_num
    call print_endl
    
    sys_exit

section .bss
    number: resb 1