# Proto16-CPU
Development files for a custom 16 bit CPU

I am developing a custom 16 bit CPU. These files are part of the development process.

OPCODES - the opcode names, hex code and wordsize

CPU.C  - the cpu (simulated) 

CPU.H  - header files for the simulated CPU

DECODE.C  - instruction decoder

ASM2.C  - assembler (compiler) for the instruction set

DOIT  - concat the *.asm files for a rudimentary shell and BASIC interpreter

shell.asm 
punch.asm
reader.asm
edit.asm
tape.asm
basic.asm
log.asm

These files constitute a small shell program for testing the CPU
The output is sys.bin (all assembled files from the assembler end in .bin).

make will compile the cpu files
make asm will compile the asm2 assembler

tape01 and tape02 are simulated tape drives.

The proto16 cpu will be build into an FPGA (currently is, actually). The simulated files
help to test the opcodes and debug the design.

