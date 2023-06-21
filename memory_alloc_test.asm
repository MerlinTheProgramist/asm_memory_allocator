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

section .data
zdanie: dd "ALA MA KOTA I PSA!",10

section .text

_start:
    
    %define n 8
    %define m 20
    call heap_init

    ; first alloc
    mov  rdi, n
    call heap_alloc     ; rax = malloc()

    mov  DWORD[rax], "SUCC"
    mov  DWORD[rax+4], "ESS!"
    mov  [first], rax

    mov  rdi, rax       ; rdi = rax
    call heap_header_debug

    mov rdi, m
    call heap_alloc
    push rax ; second alloc

    mov DWORD[rax], "ALA "
    mov DWORD[rax+4], "MA K"
    mov DWORD[rax+8], "OTA "
    mov DWORD[rax+12], "I PS"
    mov DWORD[rax+16], "A !"

    ; third alloc
    mov rdi, 4
    call heap_alloc

    mov DWORD[rax], "%%%%"
    
    mov [last], rax
    
    pop rdi ; second alloc
    ; push rdi
    ; free second
    call heap_free
    call heap_header_debug

    ; ; reallocate to existing mem
    ; mov rdi, 1
    ; call heap_alloc

    ; mov rdi, rax
    ; call heap_header_debug

    ; mov BYTE[rax], 0    
    ; ; one more in the same spot
    ; mov rdi, 1
    ; call heap_alloc
    
    mov rdi, rax
    call heap_header_debug
    

    ; read first and last 
    mov rdi, [first]
    call heap_header_debug


    mov rdi, [last]
    call heap_header_debug

    ; pop rdi
    ; call heap_free
    ; add rdi, 10
    ; call heap_free

    %define M 16
    .reall
    ; realloc
    mov rdi, [first]
    mov rsi, M
    call heap_realloc

    mov DWORD[rax+7], "FUL "
    mov DWORD[rax+11], "COPY"
    mov BYTE[rax+15], 10

    mov rdi, rax

    .end
    call heap_header_debug
    
    add rdi, 16+9
    call heap_header_debug

    sys_exit

section .bss
    number: resb 1