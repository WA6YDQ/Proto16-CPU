/* cpu engine for 16 bit proto cpu */
/* (C) k theis 2/2019  */


#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <inttypes.h>
#include <math.h>
#include <sys/time.h>
#include <string.h>
#include "cpu.h"

#define MEMSIZE	65536*256

// FLAGS
#define 	Z 	0x01		// Zero
#define 	CY 	0x02		// Carry
#define 	S	0x04		// Sign (1=neg, 0=pos)
#define		OV	0x08		// overflow
#define		INTE	0x10		// Interrupt enable (1=enab)
#define		INTF	0x20		// interrupt flag (1=in progress)
#define		K	0x40		// kernal/user flag (1/0)


#define	PC 	REG[15]
#define	SP	REG[14]

/* define registers 
 * 0000	immed	16/32 bit
 * 0001	mem	16 bit
 * 0010	R0	16 bit
 * 0011	R1	16 bit
 * 0100	R2	16 bit
 * 0101	R3	16 bit
 * 0110	R4	16 bit
 * 0111	R5	16 bit
 * 1000	R6	16 bit
 * 1001	R7	16 bit
 * 1010	(IX)	16 bit
 * 1011	(IY)	16 bit
 * 1100	IX	32 bit
 * 1101	IY	32 bit
 * 1110	SP	32 bit (memory)
 * 1111	PC	32 bit (memory)
*/
uint32_t REG[16];


/* define memory 16 bit unsigned */
uint16_t *mem;

/* define FLAGS reg */
uint8_t FLAGS;



/**** SHOW_MSTIME ****/
void show_mstime(void) {
	/* show system time in msec */
	struct timeval te;
	gettimeofday(&te, NULL);	// get current time
	long long msec = te.tv_sec*1000LL + te.tv_usec/1000;
	printf("\nRuntime: %lld (msec)\n",msec);
}


/**** QUIT ****/
int quit(void) {
extern uint16_t *mem;
	printf("stopping: PC address: %06X \n",PC);
	free(mem);
	exit(0);
}

/**** SHOWREG ****/
void showreg(void) {

	printf("R0	%04X		R1	%04X\n",REG[2],REG[3]);
	printf("R2	%04X		R3	%04X\n",REG[4],REG[5]);
	printf("R4	%04X		R5	%04X\n",REG[6],REG[7]);
	printf("R6	%04X		R7	%04X\n",REG[8],REG[9]);
	printf("PC	%06X		SP	%06X\n",REG[15],REG[14]);
	printf("IX	%06X		IY	%06X\n",REG[12],REG[13]);
	printf("(IX)	%04X		(IY)	%04X\n",mem[REG[12]],mem[REG[13]]);
	printf("FLAGS	");
	printf("Z %d\t",FLAGS&Z?1:0);
	printf("CY %d\t",FLAGS&CY?1:0);
	printf("S %d\t",FLAGS&S?1:0);
	printf("OV %d\n",FLAGS&OV?1:0);
	printf("SYSTEM FLAGS\t");
	printf("K %d\t",FLAGS&K?1:0);
	printf("INTF %d\t",FLAGS&INTF?1:0);
	printf("INTE %d\n",FLAGS&INTE?1:0);
	printf("\n");
	return;
}


/**** REGTEST ****/
void regtest(uint32_t value) {		// test value, set flags
	
	if (value > 0xffff) { 
		FLAGS |= CY;
	} else {
		FLAGS &= ~CY;
	}

	value &= 0xffff;

	if (value == 0) {
		FLAGS |= Z;
	} else {
		FLAGS &= ~Z;
	}

	if (value & 0x8000) {
		FLAGS |= S;
	} else {
		FLAGS &= ~S;
	}

	return;
}
	



/**************/
/**** MAIN ****/
/**************/

int main(int argc, char **argv) {
FILE *bootfile;

int BOOTFLAG = 0;
int RC = 0;		// return code from decode (0=inc PC, 1=don't inc PC)
int n=0;
uint16_t opcode;

/* external routines */
extern int monitor(void);
extern int decode(uint16_t);
extern int trap(uint16_t,uint16_t);
extern void bootrom(void);
extern void print_mstime(void);

	/* define main memory */
	mem = malloc(MEMSIZE * sizeof(uint16_t));
	if (mem == NULL) {
		fprintf(stderr,"Error - cannot allocate memory\n");
		exit(1);
	}



	/**** initialize registers ****/
	for (n=0; n<16; n++) {
		REG[n] = 0;
	}



	PC = 0;
	SP = 0xffff;
	FLAGS = 0;

	/**** load binary file ****/
	if (argc == 2) {
		uint32_t addr=0;
		bootfile = fopen(argv[1],"r");
		if (bootfile != NULL) {		// load it
			while (!(feof(bootfile))) {
				mem[addr] = fgetc(bootfile) << 8;
				mem[addr++] |= fgetc(bootfile);
			}
		}
		fclose(bootfile);
		BOOTFLAG = 1;
	}
	
	/* load the bootrom if no file loaded */
	if (!BOOTFLAG) bootrom();


	/**** start timer ****/
	show_mstime();


	/************* MAIN LOOP *************/
	/**** fetch, decode, process loop ****/
	/*************************************/

	while (1) {

		/* fetch */
		opcode = mem[PC];

		/* decode and process */
		RC = decode(opcode);

		if (RC) continue;	// if RC=1, don't increment the PC (ie jumps, call, etc)
		PC++;
		continue;
	}



	quit();
	return 0;
}

