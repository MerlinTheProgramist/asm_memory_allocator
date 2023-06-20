global _start

extern heap_init
extern heap_free
extern heap_alloc
extern heap_realloc
extern heap_header_debug

extern print_endl
extern print_num

%include "../libs/macros.asm"

section .bss
first: dq 0
last: dq 0

section .text

_start:
    
    %define n 8
    %define m 20
    call heap_init

    ; first alloc
    mov  rdi, n
    call heap_alloc     ; rax = malloc()

    mov  DWORD[rax], "SUCC"
    mov  DWORD[rax+4], "ESS"
    mov  BYTE[rax+7], 10
    print rax, n
    mov  [first], rax

    mov  rdi, rax       ; rdi = rax
    call heap_header_debug
    call print_num
    call print_endl

    mov rdi, m
    call heap_alloc
    push rax ; second alloc

    ; third alloc
    mov rdi, 4
    call heap_alloc

    mov DWORD[rax], "%%%"
    mov DWORD[rax+3], 10
    
    print rax, 4
    mov [last], rax
    
    pop rdi ; second alloc

    ; free second
    call heap_free
    call heap_header_debug

    mov rax, rdi
    call print_num  ; rax
    call print_endl

    ; reallocate to existing mem
    mov rdi, 1
    call heap_alloc

    mov rdi, rax
    call heap_header_debug
    call print_num  ; rax
    call print_endl

    mov BYTE[rax], 0    
    ; one more in the same spot
    mov rdi, 1
    call heap_alloc
    
    mov rdi, rax
    call heap_header_debug
    call print_num
    call print_endl
    
    mov BYTE[rax], 0

    
    ; read first and last 
    mov rdi, [first]
    call heap_header_debug
    print rdi, 8

    mov rdi, [last]
    call heap_header_debug
    print rdi, 4
    
    %define M 16
    .reall
    ; realloc
    call print_endl
    mov rdi, [first]
    mov rsi, M
    call heap_realloc

    mov DWORD[rax+7], "FUL "
    mov DWORD[rax+11], "COPY"
    mov BYTE[rax+15], 10

    print rax, M
    mov rdi, rax

    call heap_header_debug
    sys_exit

section .bss
    number: resb 1