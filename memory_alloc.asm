global _start

global heap_init
global heap_alloc
global heap_free
global heap_realloc

%ifdef DEBUG
global heap_header_debug
extern print_str
extern print_num
extern print_endl
extern print_char
%endif

%define BRK 12

%define FREE 01111111b
%define FULL 11111111b

%define MIN_BRK 100; in bytes

; for now all of these macros operate when,
; *addr is pointing to START OF THE HEADER (not the pointer returned by heap_alloc)
%define SET_SIZE(addr,size) mov QWORD[addr + Header.size], size
%define SET_FULL(addr)      mov BYTE[addr + Header.full], FULL
%define SET_FREE(addr)      mov BYTE[addr + Header.full], FREE

%define GET_SIZE(addr) QWORD[addr + Header.size]
%define GET_FULL(addr) BYTE[addr + Header.full]

%define ADD_SIZE(addr,size) add QWORD[addr + Header.size], size
%define CHECK_FULL(addr) cmp BYTE[addr + Header.full], FULL

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

        mov  QWORD[heap_end], rax

    pop rax
    pop rdi
    pop rsi
    pop rdx
    pop rcx
ret 

; rdi = size
; out:
; rax = addr
; TODO: check if this is last one (next is size 0)
;       then we can shift break 
heap_alloc:
    push rbx
    push rdi
    push rcx


    ; if size == 0: then do nothing
    test rdi, rdi
    jnz .input_valid
        xor rax, rax             ; return 0x0 (invalid mem address)
        jmp .ret                 ; size was 0
    .input_valid:

    mov   rax, QWORD[heap_begin] ; load heap_begin address
    mov   rcx, rax

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
        
        sub     rbx, rdi            ; what is left for the next chunk, after allocating this

        ; if rdi rbx - Header_size <= 0 ; if 0 then it couldnt contain any data and would be interpreted as last header
        ; then we cant construct next header, we have to allocate more that requested
        cmp     rbx, Header_size+1  ; compare to minimum block size Head+1
        jge .create_next_head       ; if left-overs are greater than minimum block size
            add rax, Header_size    ; (RETURN) 
            jmp .ret
        .create_next_head:
        SET_SIZE(rax, rdi)
        add     rax, Header_size    
        push    rax                 ; save rax for *addr return
        add     rax, rdi            ; set to end of alocated block, to setup the next header
        sub     rbx, Header_size    ; calculate leaft-overs real size
        SET_SIZE(rax, rbx)          ; set next header
        SET_FREE(rax)              
        pop     rax                 ; restore return value *addr 
    jmp .ret

    .check_next_block
    mov     rcx, rax            ; save as *prev  
    add     rax, rbx
    add     rax, Header_size    ; increment to next block
    jmp .block_check

    .last_block ; this is the last block, has size 0
                ; so we need to request more memory from kernel and then our last will  
    
    ; check if previous was free, and not same as this 
    cmp rcx, rax
    je .prev_full
    cmp GET_FULL(rcx), FULL
    je .prev_full
        ; *prev is free
        sub rdi, GET_SIZE(rcx) ; rdi = left to alloc
        add rax, Header_size*2    
        add rax, rdi           
        push rdi
        mov rdi, rax
        ; |<RAX> last H 0| <RAX> new DATA | new last H 0| <RAX>
        call sys_brk
        pop rdi

        SET_FULL(rcx)
        add GET_SIZE(rcx), rdi      ; add to desired
        ; create new ending header
        sub rax, Header_size
        SET_FREE(rax)
        SET_SIZE(rax, 0)
        jmp .ret
    .prev_full  ; allocate entirely new region

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
    pop rcx
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
    push rax    
    push rsi    ; total size
    push rdi    ; beggining addr 
    
    sub rdi, Header_size    ;|<RDI> this H| this DATA |
    mov rsi, GET_SIZE(rdi)  ; set base size

    call find_prev_block    ; rax = prev header
    cmp GET_FULL(rax), FULL ; if *prev is full
    je .check_next                 ; return

    ; *prev is free
    ;
    ; | <*rax>      PREV HEAD | PREV | <*rdi>  FREED HEAD | FREED <*end_free> |
    ; new_size = *end_free - rax - Header_size 
    ;          = *rdi + FREED_SIZE - rax
    ; | <*rax> NEW_BLOCK HEAD |              NEW_BLOCK                        |
    ;
    mov rdi, rax             ; change beggining addr
    add rsi, GET_SIZE(rdi)   ; add size of previous
    add rsi, Header_size        
    
    .check_next:            ; now we check if next is free
    mov rbx, rdi          
    add rbx, Header_size  
    add rbx, rsi            ;| this HEAD | this DATA | <RBX> next HEAD | next DATA |

    ; check if *next is last : size == 0
    cmp GET_SIZE(rbx), 0
    jz .ret
    cmp GET_FULL(rbx), FULL
    je .ret

    ; is zero : set main size to main + size
    add rsi, GET_SIZE(rbx)
    add rsi, Header_size

    .ret:
    SET_SIZE(rdi, rsi)      ; its already free, we checked for it
    SET_FREE(rdi)           
    pop rdi
    pop rsi
    pop rax
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
    push rbx
    push rdi
    push rsi

    mov rax, rdi            ; (RETURN) if(this is sufficient)
    mov rdx, rdi            ; rdi will come handy on relocation
    mov rbx, GET_SIZE(rdx - Header_size)  ; rbx = current size
    cmp rbx, rsi            ; check if size is enough already
    jae .ret                ; size was sufficient
        ; size was not sufficient
        ; now check if next block is empty
        add rdx, rbx               ; rdx = next header *addr
        cmp GET_FULL(rdx), FULL
        je .relocation              
            ; next is empty
            ; check if next block would complete desired size
            add rbx, GET_SIZE(rdx) 
            add rbx, Header_size   ; max local size (this + Header + next)
            cmp rbx, rsi
            jb .relocation
                ; this is sufficient
                sub     rbx, rsi            ; get  left-over size
                cmp     rbx, Header_size+1  ; compare to minimum block size Head+1
                jge .create_next_head       ; allocate all to this
                    add rbx, rsi                        ; revert to local max block size
                    SET_SIZE(rax - Header_size, rbx)    ; update this header size    
                    jmp .ret
                .create_next_head:          ; left-overs are greater than minimum block size

                SET_SIZE(rax - Header_size, rsi)
                push    rax                 ; save rax for *addr return
                add     rax, rsi            ; set to end of alocated block, to setup the next header
                sub     rbx, Header_size    ; calculate leaft-overs real size
                SET_SIZE(rax, rbx)          ; set next header
                SET_FREE(rax)              
                pop     rax                 ; restore (RETURn) value *addr 
                jmp .ret
        .relocation     ; next is full or insufficient, 
                        ; we need to copy data
        call heap_free  ; free this mem *rdi

        push rdi        ; save rdi
        mov  rdi, rsi   ; set size param for heap_alloc
        call heap_alloc ; rax = *new[new_size] (RETURN)
        
        pop rdi         ; rdi : *src (I told u it will be needed :v)
        mov rcx, rsi    ; rcx ; size
        mov rsi, rax    ; rsi : *dst
        call mem_cpy
        ; (RETURN) rax is *dst
    .ret:
    pop rsi
    pop rdi
    pop rbx
ret

; copy DATA from *scr to *dst on the heap
;
; rdi : *src  (data region)
; rsi : *dst  (data region)
; rcx ; size
mem_cpy:
    push rax
    push rdi
    push rsi
    push rcx

    ; SIZE via argument
    ; mov rcx, GET_SIZE(rdi - Header_size) 
    sub rcx, 1 ; <size-1, 1>
    .loop:
        mov al, BYTE[rdi + rcx] ; temp
        mov BYTE[rsi + rcx], al ; to dst
    loop .loop

    ; index zero
    mov al, BYTE[rdi] ; temp
    mov BYTE[rsi], al ; to dst

    pop rcx
    pop rsi
    pop rdi
    pop rax
ret

%ifdef DEBUG
; rdi = addr (returned by malloc)
heap_header_debug:
    push rax
    push rdi
    push rsi

    call print_num

    mov rax, ':'
    call print_char

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

    mov rax, ':'
    call print_char

    mov rsi, rdi
    mov rdi, GET_SIZE(rsi - Header_size)
    call print_str 

    call print_endl

    pop rsi
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