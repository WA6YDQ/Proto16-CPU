/* instruction decoder for 16 bit proto cpu */
/* (C) k theis 2/2019 */

#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

#define	PC	REG[15]
#define	SP	REG[14]
#define R0	REG[2]
#define R1	REG[3]


#define	Z	0x01
#define	CY	0x02
#define	S	0x04
#define	OV	0x08
#define	INTF	0x10
#define	INTE	0x20
#define	K	0x40


#define BIT(n)			( 1<<(n) )
#define BIT_SET(y,mask)		( y |=  (mask) )
#define BIT_CLEAR(y, mask)	( y &= ~(mask) )


/**** PUSH PC ****/
void pushpc(void) {
extern uint16_t *mem;
extern uint32_t REG[];

	mem[SP] = (PC & 0xffff0000) >> 16;
	SP -= 1;
	mem[SP] = (PC & 0x0000ffff);
	SP -= 1;
	return;
}

/**** POP PC ****/
void poppc(void) {
extern uint16_t *mem;
extern uint32_t REG[];

	SP += 1;
	PC = mem[SP];
	SP += 1;
	PC += mem[SP] * 65536;
	PC += 1;	// point to next address
	return;
}



/****************/
/**** DECODE ****/
/****************/

int decode(uint16_t opcode) {

extern uint16_t *mem;
extern uint32_t REG[];
extern int monitor(void);
extern void show_mstime(void);
extern int trap(uint16_t,uint16_t);
extern void regtest(uint32_t);
extern uint8_t FLAGS;
uint16_t instruction, flags, condition, source, destination;

int RC = 0;		// return code, normally 0, set to 1 if we don't want to increment the PC on return


	// extract the fields
	instruction = opcode & 0xff00;		// 1st eight bits (includes conditions)
	flags = opcode & 0x00ff;
	source = opcode & 0x00f0;
	destination = opcode & 0x000f;

	// shift to LSB
	instruction = instruction >> 8;
	condition = instruction & 0x07;		// and same for the condition
	instruction &= 0xf8;                      // remove the conditions/flags
	source = source >> 4;

	/*
	printf("opcode: 	%04X\n",opcode);
	printf("instruction: 	%02X\n",instruction);
	printf("source:		%02X\n",source);
	printf("destination:	%02X\n",destination);
	printf("flags:		%02X\n",flags);
	printf("condition:	%02X\n",condition);
	fflush(stdout);
	fgetc(stdin);
	*/

	RC = 0;	// normal op - inc PC on return (1 if not, ie jumps, call, ret, etc)

	switch (instruction) {
		uint16_t retcode; // for trap

		case	0x00:		// NOP
			break;

		case	0x08:		// SET FLAG
			BIT_SET(FLAGS,flags);
			break;

		case	0x10:		// CLEAR FLAG
			BIT_CLEAR(FLAGS,flags);
			break;

		case	0x18:		// TRAP (I/O processor)
			retcode = trap(R0,R1);	// R0=word sent, R1=device
			R0 = retcode; //fprintf(stderr,"trap returned %d\n",R0);
			break;

		case	0x20:		// HALT
			show_mstime();	// show elapsed time since start
			RC = monitor();
			show_mstime();	// show time at start
			break;

		case	0x28:		// RESET
			PC = 0;
			FLAGS = 0;
			RC = 1;	// don't inc the PC on return
			break;

		case	0x30:		// (UNASSIGNED)
			break;



		/*********************************************/
		case	0x38:	{	// LOAD
				uint32_t srcvar, address;

			if (destination == 0) break;		// can't save to immed

			// SOURCE IMMED, DEST MEM
			if ((source == 0) && (destination == 1 )) {
				uint16_t immed, addrHi, addrLo;
				immed = mem[++PC];
				addrHi = mem[++PC]; addrLo = mem[++PC];
				mem[addrHi*65536 + addrLo] = immed;
				break;
			}


			// SOURCE IMMED, DEST R0-7 (16 bit -> 16 bit)
			if ((source == 0) && ((destination > 1) && (destination < 10))) {
				REG[destination] = mem[++PC];	
				break;
			}


			// SOURCE IMMED, DEST (IX/IY)
			if ((source == 0) && ((destination == 10) || (destination == 11))) {
				mem[REG[destination+2]] = mem[++PC];
				break;
			}

			// SOURCE IMMED 32 bit, DEST PC, SP, IX, IY (32 bit source)
			if ((source == 0) && (destination > 11)) {
				uint16_t immedHi, immedLo;
				immedHi = mem[++PC];  immedLo = mem[++PC];
				REG[destination] = immedHi*65536 + immedLo;
				break;
			}

			// SOURCE MEM, DEST MEM
			if ((source == 1) && (destination == 1)) {
				uint16_t addr1Hi, addr1Lo, addr2Hi, addr2Lo;
				addr1Hi = mem[++PC]; addr1Lo = mem[++PC];
				addr2Hi = mem[++PC]; addr2Lo = mem[++PC];
				mem[addr2Hi*65536+addr2Lo] = mem[addr1Hi*65536+addr1Lo];
				break;
			}

			// SOURCE MEM, DEST R0-7
			if ((source == 1) && ((destination > 1) && (destination < 10))) {
				uint16_t addrHi, addrLo;
				addrHi = mem[++PC];  addrLo = mem[++PC];
				REG[destination] = mem[addrHi*65536 + addrLo];
				break;
			}

			// SOURCE MEM, DEST PC, SP, IX, IY (32 bit -> 32 bit)
			if ((source == 1) && (destination > 11)) {
				uint16_t addr1, addr2, address;
				addr1 = mem[++PC]*65536;  addr2 = mem[++PC]; address = addr1+addr2;
				REG[destination] = (mem[address]) << 16;
				REG[destination] |= mem[address+1];
				break;	
			}

			// SOURCE R0-7 (16 bit source), DEST MEM
			if (((source > 1) && (source < 10)) && (destination == 1)) {
				uint16_t addrHi, addrLo;
				addrHi = mem[++PC];  addrLo = mem[++PC];
				mem[addrHi*65536 + addrLo] = REG[source];
				break;
			}

			// SOURCE R0-7 (16 bit source), DEST R0-7
			if (((source > 1) && (source < 10)) && ((destination > 1) && (destination < 10))) {
				REG[destination] = REG[source];
				break;
			}

			// SOURCE R0-7 (16 bit source), DEST (IX) or (IY)
			if (((source > 1) && (source < 10)) && ((destination == 10)  || (destination == 11))) {
				mem[REG[destination+2]] = REG[source];
				break;
			}

			// SOURCE PC, SP, IX, IY (32 bit source), DEST MEM
			if ((source > 11)  && (destination == 1)) {
				// save a 32 bit value in 2 consecutive 16 bit memories
				uint16_t addrHi, addrLo;
				addrHi = mem[++PC];  addrLo = mem[++PC]; address = addrHi*65536 + addrLo;
				srcvar = REG[source];
				mem[address] = srcvar >> 16;	   // save MSB
				mem[address+1] = srcvar & 0xffff;  // save LSB
				break;
			} 
			
			// SOURCE PC, SP, IX, IY, DEST PC, SP, IX, IY
			if ((source > 11) && (destination > 11)) {
				REG[destination] = REG[source];
				break;
			}
	
			// SOURCE (IX) or (IY), DEST = R0-7
			if (((source == 10 ) || (source == 11)) && ((destination > 1) && (destination < 10))) {
				REG[destination] = mem[REG[source+2]];
				break;
			}

			// SOURCE (IX/IY), DEST (IX/IY) {
			if (((source == 10) || (source == 11)) && ((destination == 10) || (destination == 11))) {
				mem[REG[destination+2]] = mem[REG[source+2]];
				break;
			}

		} 






		/*****************************************/
		case	0x40:		// AND (always 16 bit)
			
			// IMMED & R0-7 -> R0-7
			if ((source == 0) && ((destination > 1) && (destination < 10))) {
				REG[destination] &= mem[++PC];
				regtest(REG[destination]);
				break;
			}
		
			// MEM & R0-7 -> R0-7
			if ((source == 1) && ((destination > 1) && (destination < 10))) {
				uint16_t addrHi, addrLo;
				addrHi = mem[++PC]; addrLo = mem[++PC];
				REG[destination] &= mem[addrHi*65536 + addrLo];
				regtest(REG[destination]);
				break;
			}

			// R0-7 & R0-7 -> R0-7
			if (((source > 1) && (source < 10)) && ((destination > 1) && (destination < 10))) {
				REG[destination] &= REG[source];
				regtest(REG[destination]);
				break;
			}

			// (IX) or (IY) & R0-7 -> R0-7
			if (((source == 10) || (source == 11)) && ((destination > 1) && (destination < 10))) {
				REG[destination] &= mem[REG[source+2]];
				regtest(REG[destination]);
				break;
			}






		/*******************************************/
		case	0x48:		// OR (always 16 bit)

			// IMMED | R0-7 -> R0-7
			if ((source == 0) && ((destination > 1) && (destination < 10))) {
				REG[destination] |= mem[++PC];
				regtest(REG[destination]);
				break;
			}
		
			// MEM | R0-7 -> R0-7
			if ((source == 1) && ((destination > 1) && (destination < 10))) {
				uint16_t addrHi, addrLo;
				addrHi = mem[++PC]; addrLo = mem[++PC];
				REG[destination] |= mem[addrHi*65536 + addrLo];
				regtest(REG[destination]);
				break;
			}

			// R0-7 | R0-7 -> R0-7
			if (((source > 1) && (source < 10)) && ((destination > 1) && (destination < 10))) {
				REG[destination] |= REG[source];
				regtest(REG[destination]);
				break;
			}

			// (IX) or (IY) | R0-7 -> R0-7
			if (((source == 10) || (source == 11)) && ((destination > 1) && (destination < 10))) {
				REG[destination] |= mem[REG[source+2]];
				regtest(REG[destination]);
				break;
			}
			
			
			






		/*****************************************************/
		case	0x50:		// XOR (always 16 bit)

			// IMMED ^ R0-7 -> R0-7
			if ((source == 0) && ((destination > 1) && (destination < 10))) {
				REG[destination] ^= mem[++PC];
				regtest(REG[destination]);
				break;
			}
		
			// MEM ^ R0-7 -> R0-7
			if ((source == 1) && ((destination > 1) && (destination < 10))) {
				uint16_t addrHi, addrLo;
				addrHi = mem[++PC]; addrLo = mem[++PC];
				REG[destination] ^= mem[addrHi*65536 + addrLo];
				regtest(REG[destination]);
				break;
			}

			// R0-7 ^ R0-7 -> R0-7
			if (((source > 1) && (source < 10)) && ((destination > 1) && (destination < 10))) {
				REG[destination] ^= REG[source];
				regtest(REG[destination]);
				break;
			}

			// (IX) or (IY) ^ R0-7 -> R0-7
			if (((source == 10) || (source == 11))&& ((destination > 1) && (destination < 10))) {
				REG[destination] ^= mem[REG[source+2]];
				regtest(REG[destination]);
				break;
			}
			
			
			


		/********************************************/
		case	0x58:		// SHIFT LEFT DEST (16 bit only)
					
			// (MEM << 1) -> MEM
			if (destination == 1) {
				uint16_t addrHi, addrLo, address;
				addrHi = mem[++PC];  addrLo = mem[++PC];
				address = addrHi*65536 + addrLo;
				mem[address] = mem[address] << 1;
				regtest(mem[address]);
				break;
			}

			// (RO-7 << 1) -> R0-7
			if ((destination > 1) && (destination < 10)) {
				REG[destination] = REG[destination] << 1;
				regtest(REG[destination]);
				REG[destination] &= 0xffff;	// keep 16 bit
				break;
			}

			// (IX) or (IY) << 1  -> (IX) or (IY)
			if ((destination == 10) || (destination == 11)) {
				mem[REG[destination+2]] = mem[REG[destination+2]] << 1;
				regtest(mem[REG[destination+2]]);
				break;
			}





		/**********************************************/
		case	0x60:		// SHIFT RIGHT DEST (16 bit only)

			// (MEM >> 1) -> MEM
			if (destination == 1) {
				uint16_t addrHi, addrLo, address;
				addrHi = mem[++PC];  addrLo = mem[++PC];
				address = addrHi*65536 + addrLo;
				mem[address] = mem[address] >> 1;
				regtest(mem[address]);
				break;
			}

			// (RO-7 >> 1) -> R0-7
			if ((destination > 1) && (destination < 10)) {
				REG[destination] = REG[destination] >> 1;
				regtest(REG[destination]);
				REG[destination] &= 0xffff;	// keep 16 bit
				break;
			}

			// (IX) or (IY) >> 1  -> (IX) or (IY)
			if ((destination == 10) || (destination == 11)) {
				mem[REG[destination+2]] = mem[REG[destination+2]] >> 1;
				regtest(mem[REG[destination+2]]);
				break;
			}
		




		/***********************************************************/
		case	0x68:		// COMPLIMENT DESTINATION

			if (destination == 0) break;        // can't move to immed
		
			// COMPLIMENT MEM
			if (destination == 1) {       // compliment memory
				uint16_t addrHi, addrLo, address;
				addrHi = mem[++PC]; addrLo = mem[++PC]; address = addrHi*65536 + addrLo;
				mem[address] = ~mem[address];
				regtest(mem[address]);
				break;
			}

			// COMPLIMENT R0-7
			if ((destination > 1) && (destination < 10)) {
				REG[destination] = ~REG[destination];
				regtest(REG[destination]);
				REG[destination] &= 0xffff;
				break;
			}


			// COMPLIMENT (IX) or (IY)
			if ((destination == 10) || (destination == 11)) {
				mem[REG[destination+2]] = ~mem[REG[destination+2]];
				regtest(mem[REG[destination+2]]);
				break;
			}





		/******************************************************************/
		case	0x70:		// ADD w/CY  src + CY + dest = dest
			
			// IMMED + R0-7 + CY -> R0-7
			if ((source == 0) && ((destination > 1) && (destination < 10))) {
				if (FLAGS & CY) REG[destination] += 1;
				REG[destination] += mem[++PC];
				regtest(REG[destination]);
				REG[destination] &= 0xffff;	// keep 16 bit
				break;
			}

			// MEM + R0-7 + CY -> R0-7
			if ((source == 1) && ((destination > 1) && (destination < 10))) {
				uint16_t addrHi, addrLo;
				addrHi = mem[++PC]; addrLo = mem[++PC];
				if (FLAGS & CY) REG[destination] += 1;
				REG[destination] += mem[addrHi*65536 + addrLo];
				regtest(REG[destination]);
				REG[destination] &= 0xffff;	// keep 16 bit
				break;
			}

			// R0-7 + R0-7 + CY -> R0-7
			if (((source > 1) && (source < 10)) && ((destination > 1) && (destination < 10))) {
				if (FLAGS & CY) REG[destination] += 1;
				REG[destination] += REG[source];
				regtest(REG[destination]);
				REG[destination] &= 0xffff;	// keep 16 bit
				break;
			}

			// (IX/IY) + R0-7 + CY -> R0-7
			if (((source == 11) || (source == 12)) && ((destination > 1) && (destination < 10))) {
				if (FLAGS & CY) REG[destination] += 1;
				REG[destination] += mem[REG[source+2]];
				regtest(REG[destination]);
				REG[destination] &= 0xffff;	// keep 16 bit
				break;
			}

			// R0-7 + IX/IY (no CY) -> IX/IY
			if (((source > 1) && (source < 10)) && ((destination == 12) || (destination == 13))) {
				REG[destination] += REG[source];
				regtest(REG[destination]);
				break;
			}


			// IX/IY + IX/IY (no (CY) -> IX/IY (32 bit)
			if (((source == 12) || (source == 13)) && ((destination == 12) || (destination == 13))) {
				REG[destination] += REG[source];
				// regtest is 16 bit only
				break;
			}	
			

			



		/*************************************************************/
		case	0x78:		// SUB w/CY  src + CY - dest = dest
			
			// R0-7 + CY - IMMED  -> R0-7
			if ((source == 0) && ((destination > 1) && (destination < 10))) {
				if (FLAGS & CY) REG[destination] += 1;
				REG[destination] -= mem[++PC];
				regtest(REG[destination]);
				REG[destination] &= 0xffff;	// keep 16 bit
				break;
			}

			// R0-7 + CY - MEM -> R0-7
			if ((source == 1) && ((destination > 1) && (destination < 10))) {
				uint16_t addrHi, addrLo;
				addrHi = mem[++PC]; addrLo = mem[++PC];
				if (FLAGS & CY) REG[destination] += 1;
				REG[destination] -= mem[addrHi*65536 + addrLo];
				regtest(REG[destination]);
				REG[destination] &= 0xffff;	// keep 16 bit
				break;
			}

			// R0-7 + CY - R0-7 -> R0-7
			if (((source > 1) && (source < 10)) && ((destination > 1) && (destination < 10))) {
				if (FLAGS & CY) REG[destination] += 1;
				REG[destination] -= REG[source];
				regtest(REG[destination]);
				REG[destination] &= 0xffff;	// keep 16 bit
				break;
			}

			//  R0-7 + CY - (IX/IY) -> R0-7
			if (((source == 10) || (source == 11)) && ((destination > 1) && (destination < 10))) {
				if (FLAGS & CY) REG[destination] += 1;
				REG[destination] -= mem[REG[source+2]];
				regtest(REG[destination]);
				REG[destination] &= 0xffff;	// keep 16 bit
				break;
			}

			// IX/IY - R0-7 (no CY) -> IX/IY
			if (((source > 1) && (source < 10)) && ((destination == 12) || (destination == 13))) {
				REG[destination] -= REG[source];
				regtest(REG[destination]);
				break;
			}
			
			// IX/IY + IX/IY (no (CY) -> IX/IY (32 bit)
			if (((source == 12) || (source == 13)) && ((destination == 12) || (destination == 13))) {
				REG[destination] -= REG[source];
				// regtest is 16 bit only
				break;
			}


		/***************************************************************/
		case	0x80:		// MULTIPLY source, destination
			
			// R0-7 + CY * IMMED  -> R0-7
			if ((source == 0) && ((destination > 1) && (destination < 10))) {
				if (FLAGS & CY) REG[destination] += 1;
				REG[destination] *= mem[++PC];
				regtest(REG[destination]);
				REG[destination] &= 0xffff;	// keep 16 bit
				break;
			}

			// R0-7 + CY * MEM -> R0-7
			if ((source == 1) && ((destination > 1) && (destination < 10))) {
				uint16_t addrHi, addrLo;
				addrHi = mem[++PC]; addrLo = mem[++PC];
				if (FLAGS & CY) REG[destination] += 1;
				REG[destination] *= mem[addrHi*65536 + addrLo];
				regtest(REG[destination]);
				REG[destination] &= 0xffff;	// keep 16 bit
				break;
			}

			// R0-7 + CY * R0-7 -> R0-7
			if (((source > 1) && (source < 10)) && ((destination > 1) && (destination < 10))) {
				if (FLAGS & CY) REG[destination] += 1;
				REG[destination] *= REG[source];
				regtest(REG[destination]);
				REG[destination] &= 0xffff;	// keep 16 bit
				break;
			}

			//  R0-7 + CY * (IX/IY) -> R0-7
			if (((source == 10) || (source == 11)) && ((destination > 1) && (destination < 10))) {
				if (FLAGS & CY) REG[destination] += 1;
				REG[destination] *= mem[REG[source+2]];
				regtest(REG[destination]);
				REG[destination] &= 0xffff;	// keep 16 bit
				break;
			}

			// IX/IY + IX/IY (no (CY) -> IX/IY (32 bit)
			if (((source == 12) || (source == 13)) && ((destination == 12) || (destination == 13))) {
				REG[destination] *= REG[source];
				// regtest is 16 bit only
				break;
			}



		/**********************************************************************/
		case	0x88:		// DIVIDE destination from source -> destination

			// R0-7 + CY / IMMED  -> R0-7
			if ((source == 0) && ((destination > 1) && (destination < 10))) {
				if (FLAGS & CY) REG[destination] += 1;
				REG[destination] /= mem[++PC];
				regtest(REG[destination]);
				REG[destination] &= 0xffff;	// keep 16 bit
				break;
			}

			// R0-7 + CY / MEM -> R0-7
			if ((source == 1) && ((destination > 1) && (destination < 10))) {
				uint16_t addrHi, addrLo;
				addrHi = mem[++PC]; addrLo = mem[++PC];
				if (FLAGS & CY) REG[destination] += 1;
				REG[destination] /= mem[addrHi*65536 + addrLo];
				regtest(REG[destination]);
				REG[destination] &= 0xffff;	// keep 16 bit
				break;
			}

			// R0-7 + CY / R0-7 -> R0-7
			if (((source > 1) && (source < 10)) && ((destination > 1) && (destination < 10))) {
				if (FLAGS & CY) REG[destination] += 1;
				REG[destination] /= REG[source];
				regtest(REG[destination]);
				REG[destination] &= 0xffff;	// keep 16 bit
				break;
			}

			//  R0-7 + CY / (IX/IY) -> R0-7
			if (((source == 10) || (source == 11)) && ((destination > 1) && (destination < 10))) {
				if (FLAGS & CY) REG[destination] += 1;
				REG[destination] /= mem[REG[source+2]];
				regtest(REG[destination]);
				REG[destination] &= 0xffff;	// keep 16 bit
				break;
			}

			// IX/IY + IX/IY (no (CY) -> IX/IY (32 bit)
			if (((source == 12) || (source == 13)) && ((destination == 12) || (destination == 13))) {
				REG[destination] /= REG[source];
				// regtest is 16 bit only
				break;
			}


		/********************************************************/
		case	0x90:	{	// COMPARE source, destination
			uint32_t srcvar=0, destvar=0;

			// COMPARE IMMEDIATE
			if (source == 0) 
				srcvar = mem[++PC];	
			
			// COMPARE MEMORY
			if (source == 1) {
				uint16_t addrHi, addrLo;
				addrHi = mem[++PC];
				addrLo = mem[++PC];
				srcvar = mem[(addrHi*65536)+addrLo];
			}
			
			// COMPARE R0-7
			if ((source > 1) && (source < 10)) 
				srcvar = REG[source];

			// COMPARE (IX) and (IY)
			if ((source == 10) || (source == 11)) 
				srcvar = mem[REG[source+2]];
			
			// DEST MEM?
			if (destination == 1) {
				uint16_t addrHi, addrLo;
				addrHi = mem[++PC];
				addrLo = mem[++PC];
				destvar = mem[(addrHi*65536)+addrLo];
			}
			
			// DEST R0-7?
			if ((destination > 1) && (destination <10)) 
				destvar = REG[destination];

			// DEST (IX) and (IY)
			if ((destination == 10) || (destination == 11))
				destvar = mem[REG[destination+2]];

			// not testing PC, SP, IX, IY
			
			regtest(destvar-srcvar);
			break;
		}

			

		/*****************************************************************/
		case	0x98:	{	// TEST destination (ex: after a LOAD)
			uint16_t tempvar=0;

			// TEST MEM
			if (destination == 1) {
				uint16_t addrHi, addrLo;
				addrHi = mem[++PC];
				addrLo = mem[++PC];
				tempvar = mem[(addrHi*65536)+addrLo];
			}

			if ((destination > 1) && (destination < 14))
				tempvar = REG[destination];

			// TEST (IX) and (IY)
			if ((destination == 10) || (destination == 11)) 
				tempvar = mem[REG[destination+2]];
			
			regtest(tempvar);
			break;

		} 


		/***********************************************************/
		case	0xa0:		// SWAP destination
			
			// SWAP R0-7
			if ((destination > 1) && (destination < 10)) {
				uint16_t temp;
				temp = REG[destination];
				REG[destination] = REG[destination] >> 8;
				temp = temp << 8;
				REG[destination] |= temp;
				break;
			}

			// SWAP IX or IY
			if ((destination == 12) || (destination == 13)) {
				uint32_t temp;
				temp = REG[destination] & 0x0000ffff;		// save LSB
				REG[destination] = (REG[destination] >> 16);	// shift MSB to LSB
				REG[destination] |= (temp << 16);		// place LSB in MSB position
				break;
			}

		/***********************************************************/
		case	0xb0:		// INC destination
			// INC MEM
			if (destination == 1) {		// increment memory
				uint16_t addrHi, addrLo;
				addrHi = mem[++PC];
				addrLo = mem[++PC];
				mem[(addrHi*65536)+addrLo] += 1;
				regtest(mem[(addrHi*65536)+addrLo]);
				break;
			}
			// INC R0-7
			if ((destination  > 1) && (destination < 10)) {
				REG[destination] += 1;
				regtest(REG[destination]);
				REG[destination] &= 0xffff;
				break;
			}
		

			// INC SP-IY
			if (destination > 11) {
				REG[destination] += 1;
				regtest(REG[destination]);
				break;
			}
			// INC (IX), (IY)
			if ((destination == 10) || (destination == 11)) {
				mem[REG[destination+2]] += 1;
				regtest(mem[REG[destination+2]]);
				break;
			}



		/******************************************************/
		case	0xb8:		// DEC destination
			// DEC MEM
			if (destination == 1) {		// decrement memory
				uint16_t addrHi, addrLo;
				addrHi = mem[++PC];
				addrLo = mem[++PC];
				mem[(addrHi*65536)+addrLo] -= 1;
				regtest(mem[(addrHi*65536)+addrLo]);
				break;
			}
			// DEC R0-7
			if ((destination  > 1) && (destination < 10)) {
				REG[destination] -= 1;
				regtest(REG[destination]);
				REG[destination] &= 0xffff;
				break;
			}
			

			// DEC SP-IY
			if (destination > 11) {
				REG[destination] -= 1;
				regtest(REG[destination]);
				break;
			}
			// DEC (IX), (IY)
			if ((destination == 10) || (destination == 11)) {
				mem[REG[destination+2]] -= 1;
				regtest(mem[REG[destination+2]]);
				break;
			}



		/*******************************************/
		case	0xc0:		// PUSH destination

			// PUSH 16 bit R0-7
			if ((destination > 1) && (destination < 10)) {
				mem[SP] = REG[destination];
				SP -= 1;
				break;
			}

			// PUSH 32 bit IX/IY
			if (destination == 12 || destination == 13) {
				mem[SP] = (REG[destination] & 0xffff0000) >> 16;
				SP -= 1;
				mem[SP] = (REG[destination] & 0x0000ffff);
				SP -= 1;
				break;
			}



		/********************************************/
		case	0xc8:		// POP destination

			// POP 16 bit R0-7
			if ((destination > 1) && (destination < 10)) {
				SP += 1;
				REG[destination] = mem[SP];
				break;
			}


			// POP 32 bit IX/IY
			if (destination == 12 || destination == 13) {
				SP += 1;
				REG[destination] = mem[SP];		// LSB
				SP += 1;
				REG[destination] += (mem[SP] * 65536);	// MSB
				break;
			}			

		
		/*********************************************/
		case 0xd0:	{	// JMP condition

			// always do this
			uint16_t address, addrHi, addrLo;
			addrHi = mem[++PC];  addrLo = mem[++PC];  // always skip past the 2 address bytes
			address = 65536*addrHi + addrLo;
			RC = 1;
			
			// Z set
			if ((condition == 1) && (FLAGS & Z)) { 
				PC = address;
				break;
			}
			// Z clear (not zero)
			if ((condition == 2) && (!(FLAGS & Z))) {
				PC = address;
				break;
			}
			
			// CY set
			if ((condition == 3) && (FLAGS & CY)) {
				PC = address;
				break;
			}
			// CY clear
			if ((condition == 4) && (!(FLAGS & CY))) {
				PC = address;
				break;
			}

			// SIGN set (minus)
			if ((condition == 5) && (FLAGS & S)) {
				PC = address;
				break;
			}
			// SIGN clear (plus)
			if ((condition == 6) && (!(FLAGS & S))) {
				PC = address;
				break;
			}

			// OVERFLOW set
			if ((condition == 7) && (FLAGS&OV)) {
				PC = address;
				break;
			}

			// IMMEDIATE
			if (condition == 0) {
				PC = address;
				break;
			}
			// failed - bypass
			RC = 0;	// let CPU increment the PC - we didn't change it
			break;
		}	// braces needed because of uint_ define above



		/*********************************************/
		case 0xe0:	{	// CALL condition

			// always do this
			uint16_t address, addrHi, addrLo;
			addrHi = mem[++PC];  addrLo = mem[++PC];  // always skip past the 2 address bytes
			address = 65536*addrHi + addrLo;
			RC = 1;
			
			// Z set
			if ((condition == 1) && (FLAGS & Z)) { 
				pushpc();
				PC = address;
				break;
			}
			// Z clear (not zero)
			if ((condition == 2) && (!(FLAGS & Z))) {
				pushpc();
				PC = address;
				break;
			}
			
			// CY set
			if ((condition == 3) && (FLAGS & CY)) {
				pushpc();
				PC = address;
				break;
			}
			// CY clear
			if ((condition == 4) && (!(FLAGS & CY))) {
				pushpc();
				PC = address;
				break;
			}

			// SIGN set (minus)
			if ((condition == 5) && (FLAGS & S)) {
				pushpc();
				PC = address;
				break;
			}
			// SIGN clear (plus)
			if ((condition == 6) && (!(FLAGS & S))) {
				pushpc();
				PC = address;
				break;
			}

			// OVERFLOW set
			if ((condition == 7) && (FLAGS&OV)) {
				pushpc();
				PC = address;
				break;
			}

			// IMMEDIATE
			if (condition == 0) {
				pushpc();
				PC = address;
				break;
			}
			// failed - bypass
			RC = 0;	// let CPU increment the PC - we didn't change it
			break;
		}	// braces needed because of uint_ define above


		/*********************************************/
		case 0xf0:		// RETURN condition

			RC = 1;
			
			// Z set
			if ((condition == 1) && (FLAGS & Z)) { 
				poppc();
				break;
			}
			// Z clear (not zero)
			if ((condition == 2) && (!(FLAGS & Z))) {
				poppc();
				break;
			}
			
			// CY set
			if ((condition == 3) && (FLAGS & CY)) {
				poppc();
				break;
			}
			// CY clear
			if ((condition == 4) && (!(FLAGS & CY))) {
				poppc();
				break;
			}

			// SIGN set (minus)
			if ((condition == 5) && (FLAGS & S)) {
				poppc();
				break;
			}
			// SIGN clear (plus)
			if ((condition == 6) && (!(FLAGS & S))) {
				poppc();
				break;
			}

			// OVERFLOW set
			if ((condition == 7) && (FLAGS&OV)) {
				poppc();
				break;
			}

			// IMMEDIATE
			if (condition == 0) {
				poppc();
				break;
			}
			// failed - bypass
			RC = 0;	// let CPU increment the PC - we didn't change it
			break;



		/************************************************/
		default:
			printf("unknown opcode %04X at PC %06X\n",opcode,PC);
			RC = monitor();
			break;

	} // end of switch

	return RC;
}

		
