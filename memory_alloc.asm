global _start

global heap_init
global heap_alloc
global heap_free
global heap_header_debug

%include "../libs/macros.asm"

%ifdef DEBUG
extern print
%endif
extern print_num
extern print_endl
extern print_char

%define BRK 12

; %define TRUE  1
; %define FALSE 0

%define FREE 01111111b
%define FULL 11111111b

%define MIN_BRK 100; in bytes


; for now all of these macros operate when,
; *addr is pointing to START OF THE HEADER (not the pointer returned by heap_alloc)
; COULD CHANGE THAT LATER, but idk if its worth it
%define SET_SIZE(addr,size) mov QWORD[addr + Header.size], size
%define SET_FULL(addr)      mov BYTE[addr + Header.full], FULL
%define SET_FREE(addr)      mov BYTE[addr + Header.full], FREE

%define GET_SIZE(addr) QWORD[addr + Header.size]
%define GET_FULL(addr) BYTE[addr + Header.full]

%define ADD_SIZE(addr,size) add QWORD[addr + Header.size], size
%define CHECK_FULL(addr) cmp BYTE[addr + Header.full], FULL

; rdi : new *brk
sys_brk:
    push rcx
    push rdx
    push rsi
    push rdi
    push rax
        
        ; add  rdi, [heap_begin]      ; add begin to input size
        mov rax, BRK
        syscall     ; rax, rdi, rsi, rdx, rcx, r8, r9, r10, r11 are modified

        %ifdef DEBUG
        cmp rax, QWORD[heap_begin]
        jne .nominal
            print error_brk, [error_brk_len]
            sys_exit
        .nominal:
        %endif

        mov  QWORD[heap_end], rax

    pop rax
    pop rdi
    pop rsi
    pop rdx
    pop rcx
ret 

; memory block headrer
struc Header
    .size: resq 1 ; could change to DWORD, because <4GB is still a LOT
    .full: resb 1
endstruc

section .bss
    heap_begin: resq 1 ; start of heap
    ; heap_tot_size: resq 1
    heap_end: resq 1   ; end of heap

section .data
    %ifdef DEBUG
    error_brk: db "BRK FAILED AND RETURNED 0"
    error_brk_len: equ $-error_brk
    %endif

section .text 

; rdi = size
; out:
; rax = addr
heap_alloc:
    push rbx
    push rdi

    ; if size == 0: then do nothing
    test rdi, rdi
    jnz .input_valid
        xor rax, rax             ; return 0x0 (invalid mem address)
        jmp .ret                 ; size was 0
    .input_valid:

    mov   rax, QWORD[heap_begin] ; load heap_begin address

    .block_check:
    mov   rbx, GET_SIZE(rax)

    cmp GET_FULL(rax), FULL      ; if full then check next
    je    .check_next_block

    test   rbx, rbx          
    jz    .last_block       ; if zero then request more memory
    cmp   rbx, rdi
    jl    .check_next_block ; if too small, then check next

    .allocate:
    ; greater or equal than our desire, so we can allocate it
    SET_FULL(rax)  
    

    sub     rbx, rdi            ; what is left to the next chunk
    sub     rbx, Header_size    ; sub next block header_size, to only have its true size

    ; if rdi rbx - Header_size <= 0 ; if 0 then it couldnt contain any data and would be interpreted as last header
    ; then we cant construct next header
    cmp     rbx,0 
    jg .create_next_head        ; signed greater
        add rbx, Header_size    ; get the left-overs
        add rdi, rbx            ; add the left-overs to the size
        SET_SIZE(rax, rdi)
        jmp .ret
    .create_next_head:
    SET_SIZE(rax, rdi)
    add     rax, rdi
    add     rax, Header_size    ; set to start of allocated block (addr to return) 
    SET_FREE(rax)
    SET_SIZE(rax, rbx)
jmp .ret
    .check_next_block
    add     rax, rbx
    add     rax, Header_size
    jmp .block_check

    .last_block ; this is the last block, has size 0
                ; so we need to request more memory from kernel and then our last will  
    
    ; override this header
    SET_FULL(rax)
    SET_SIZE(rax, rdi)

    add rax, Header_size    ; |this H| <RAX> this DATA |next H| (this is the return value)
    add rdi, rax            ; |this H| this DATA |<RDI> next H|
    mov rbx, rdi

    add rdi, Header_size
    call sys_brk           ; + space for ending header

    ; new ending header ending
    SET_FREE(rbx)           
    SET_SIZE(rbx, 0)

    .ret:
    pop rdi
    pop rbx
ret

; rdi = addr of this block begin (header)
; ret:
; rax = prev block begin (header)
; 1 FOR ERROR (because 0 is a valid header *addr), means that this is the first block, and there is no *prev
find_prev_block:
    push rbx

    cmp rdi, [heap_begin] ; first check the edge case, where its the first block 
    jne .not_first
        mov rax, [heap_begin]
        jmp .ret
    .not_first:

    mov rbx, [heap_begin]
    .check_next:
        mov rax, rbx
        
        add rbx, GET_SIZE(rbx) ; move to next header
        add rbx, Header_size    

        cmp rbx, rdi
    jne .check_next ; if the same addr, so rbx is the prev

    .ret:
    pop rbx
ret


; rdi = addr 
; no return
heap_free:
    push rdi

    sub rdi, Header_size    ;|<RDI> this H| this DATA |

    call find_prev_block    ; rax

    cmp GET_FULL(rax), FREE ; if *prev is free
    je .free
    .full:                  ; if *pref is full
        SET_FREE(rdi)       ; just set freed to free 
        jmp .ret
    .free:                  ; *prev is free
    ;
    ; | <*rax>      PREV HEAD | PREV | <*rdi>  FREED HEAD | FREED <*end_free> |
    ; new_size = *end_free - rax - Header_size 
    ;          = *rdi + FREED_SIZE - rax
    ; | <*rax> NEW_BLOCK HEAD |              NEW_BLOCK                        |
    ;
    add rdi, GET_SIZE(rdi)      
    sub rdi, rax            ; size of NEW_BLOCK
    ; sub rdi, Header_size    

    SET_SIZE(rax, rdi)      ; its already free, we checked for it
    
    .ret:
    pop rdi
ret

; request to resize region of *addr, to new_size.
; if its not legal then copy data to new allocated region
; return pointer to either old region or new
;
; rdi = addr
; rsi = new_size
; ret:
; rax = new_addr
heap_realloc:

ret

%ifdef DEBUG
; rdi = addr (returned by malloc)
heap_header_debug:
    push rax
    push rdi

    mov rax, GET_SIZE(rdi - Header_size)
    call print_num 

    mov al, GET_FULL(rdi - Header_size)
    cmp al, FREE
    je .free
        mov rax, 'F'
        call print_char
        jmp .ret
    .free
        mov rax, 'E'
        call print_char
    .ret

    call print_endl

    pop rdi
    pop rax
ret
%endif

heap_init:
    ; get initial break position, or `_end` from linker
    add rdi, 0
    mov rax, BRK
    syscall
    ; save to data
    mov [heap_begin], rax

    ; first the system_call 
    mov  rdi, rax
    add  rdi, Header_size ; reserve first Header
    call sys_brk       

    ; then write to heap, to avoid sigsegv
    mov rax, [heap_begin]
    SET_FREE(rax)
    SET_SIZE(rax, 0)
ret


; _start:
;     %define n 25
;     call heap_init

;     mov  rdi, n
;     call heap_alloc     ; rax = malloc()

;     mov  rdi, rax       ; rdi = rax
;     call heap_header_debug   

;     ; mov rdi, 1
;     ; call heap_alloc

;     mov rdi, rax
;     call heap_header_debug

;     ; mov  rcx, n + 3
;     ; .loop:
;     ; push rcx

;     ; mov rbx, rcx
;     ; add bl, 'A'
;     ; mov BYTE[rax + rcx], bl

;     ; loop .loop

;     print rax, n

;     sys_exit