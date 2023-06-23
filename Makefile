
ASM_FLAGS := -felf64 -mamd64
LIB_NAME := memory_alloc.o
EXE_NAME := memory_alloc_test

debug: ASM_FLAGS := ${ASM_FLAGS} -g dwarf2 -D DEBUG
debug: LIB_NAME  := ${LIB_NAME}_debug
debug: EXE_NAME  := ${EXE_NAME}_debug
debug: all executable

all: library

library:
	@yasm ${ASM_FLAGS} ./memory_alloc.asm -o ${LIB_NAME}

executable: ${LIB_NAME}
	@yasm ${ASM_FLAGS} ./memory_alloc_test.asm -o ./memory_alloc_test.o
	@ld ${LIB_NAME} ../libs/print.o ./memory_alloc_test.o -o ${EXE_NAME}
	

