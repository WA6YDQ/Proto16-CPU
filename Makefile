all	:	cpu.o decode.o  monitor.o bootrom.o trap.o
	cc -o cpu cpu.o decode.o monitor.o bootrom.o trap.o -lasan -lpthread -lpigpio -lrt
asm	:	asm2.o
	cc -o asm asm2.o -lasan


FLAGS = -mcpu=cortex-a53 -mfpu=neon-vfpv4 -O2 -Wall -Werror -fsanitize=address -g 
FLAG2 = -mcpu=cortex-a53 -mfpu=neon-vfpv4 -O2 -fsanitize=address -g

cpu.o	:	cpu.c
	cc -c ${FLAGS} cpu.c

decode.o	:	decode.c
	cc -c ${FLAGS} decode.c

bootrom.o	:	bootrom.c
	cc -c ${FLAGS} bootrom.c

procio.o	:	procio.c
	cc -c ${FLAGS} procio.c

monitor.o	:	monitor.c
	cc -c ${FLAGS} monitor.c

trap.o	:	trap.c
	cc -c ${FLAGS} trap.c

asm2.o	:	asm2.c
	cc -c ${FLAG2} asm2.c
