#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#define 	PC	REG[15]
#define	SP	REG[14]


extern void showreg(void);
extern int quit(void);

extern uint32_t REG[];
extern uint16_t *mem;

int monitor(void) {		// called with halt instruction
uint16_t address = 0;
char line[80];


	showreg();
	printf("\n");
	
	while (1) {
		
		/* show address, value */
		printf("%04X   %04X :",address,mem[address]);
		fgets(line,40,stdin);
		if (line[0] == 'x') {
			printf("\n");
			return 1;
		}

		// QUIT		
		if (line[0] == 'q') {
			quit();
		}

		// NEXT
		if (line[0] == '\n') {
			address++;
			continue;
		}

		// BACK 1
		if (line[0] == 'b') {
			address--;
			continue;
		}

		// SHOW REGISTERS
		if (line[0] == 'r') {
			showreg();
			continue;
		}

		// CHANGE ADDRESS
		if (line[0] == 'm') {
			int n;
			unsigned int word;
			char tmp[20];
			memset(tmp,0,8);
                  for (n=0; n<strlen(line); n++) tmp[n] = line[n+1];
                  sscanf(tmp,"%x",&word);
                  address = word;
                  continue;
            }

		// CHANGE MEMORY CONTENTS
		if (line[0] == '.') {
			char tmp[8];
			unsigned int word;
			int n;
			memset(tmp,0,8);
                  for (n=0; n<strlen(line); n++) tmp[n] = line[n+1];
                  sscanf(tmp,"%04x",&word);
                  mem[address] = word;
                  address++;
                  continue;
            }

		// GOTO ADDRESS
		if (line[0] == 'g') {
			char tmp[8];
			int n;
			unsigned int word;
			memset(tmp,0,8);
                  for (n=0; n<strlen(line); n++) tmp[n] = line[n+1];
                  sscanf(tmp,"%x",&word);
                  PC = word;
	printf("starting at %04X\n",PC);
                  return 1;		// RC=1 - don't increment PC
		}
		

	}
	return 0;
}
