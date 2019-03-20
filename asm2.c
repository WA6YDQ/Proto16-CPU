/* assembler written for the proto 16 cpu */
/* (C) k theis 2/2019 */

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <ctype.h>
#include <stdint.h>
#include "cpu.h"


#define WORDLEN 128	// max line length
#define MAXWORDS 15000	// max words read in
#define MAXLABELS 3500	// max labels
#define FILENAMELEN 40	// max length of filename

/* arguement storage */
char word[MAXWORDS][WORDLEN];
int wordcount = 0;

/* label storage */
char label[MAXLABELS][WORDLEN];
int labelcount=0;
int labeladdress[MAXLABELS];

/* 32 bit address storage */
uint32_t longaddress, longaddress2; 

FILE *infile, *outfile, *prnfile;

/* define routines */
extern char **split_line(char *line);


/***************/
/*** HEX2DEC ***/
/***************/

int hex2dec(char hexchar[16]) {            // input hex value, return decimal
char tbyte[16];
int n;
      if (hexchar[0]=='$') {  // hexchar will always have a $ as char 0
            for (n=0; n<strlen(hexchar); n++) tbyte[n]=hexchar[n+1];
            return (strtol(tbyte, NULL, 16));
      }

      return(atoi(hexchar));
     
}



/****************/
/***** MAIN *****/
/****************/

int main(int argc, char **argv) {
char line[WORDLEN-1];		// read in from file
char readline[WORDLEN-1];	// stripped of comments etc
char basename[FILENAMELEN-1];	// filename for later
char **args;		// split line into args
int n, i, ct, value, address;
uint16_t *mem;
mem = malloc(65536 * sizeof(uint16_t));
if (mem == NULL) {
	fprintf(stderr,"Error allocating memory\n");
	exit(1);
}



	if (argc == 2) {		// open a file
		infile = fopen(argv[1],"r");
		if (infile == NULL) {
			fprintf(stderr,"error opening file %s\n",argv[1]);
			exit(1);
		}
	}

	memset(basename,0,FILENAMELEN-1);
	/* get basename of file */
	for (ct=0; argv[1][ct]!='.';ct++) basename[ct]=argv[1][ct];
	strcat(basename,".bin");
	fprintf(stdout,"Output name is %s\n",basename);
	outfile = fopen(basename,"w");
	if (outfile == NULL) {
		fprintf(stderr,"Error opening %s\n",basename);
		exit(1);
	}
	memset(basename,0,FILENAMELEN-1);

	/* get basename for print file */
	for (ct=0; argv[1][ct]!='.';ct++) basename[ct]=argv[1][ct];
	strcat(basename,".prn");
	fprintf(stdout,"Print file is %s\n",basename);
	prnfile = fopen(basename,"w");
	if (prnfile == NULL) {
		fprintf(stderr,"Error opening prn.out\n");
		exit(1);
	}
	memset(basename,0,FILENAMELEN-1);



	/**************/
	/*** PASS 1 ***/
	/**************/

	/* read a line, ignore comments, split into words, save words, close file */

	while (1) {
		memset(line,0,WORDLEN-1);
		memset(readline,0,WORDLEN-1);			// initialize readline
		ct = 0;
		fgets(line, WORDLEN-1, infile);
		if (feof(infile)) break;
		while (ct <strlen(line))  { 		// save until ; (comment)
			if (line[ct] == ';') break;
			//if (ct == strlen(line)) break;
			readline[ct]=line[ct];
			ct++;
		}
		if (ct == 0) continue;
		if (readline[ct] != '\0')
			readline[ct] = '\0';			// tack on EOL
		args = split_line(readline);
		i = 0;
		while (args[i] != NULL) {
			if (strlen(args[i])> 73) printf("pass1: arglen %d of %s\n",strlen(args[i]),args[i]);
			strcpy(word[wordcount++],args[i++]);
		}
		free(args);
		
	}

	fclose(infile);



	/* DEBUG: show the words read in */
	//for (i=0; i<wordcount; i++) printf("[%s]\n",word[i]);

	fprintf(prnfile,"\nPASS 1: Words read: %d\n",wordcount);
	printf("Words read: %d\n",wordcount);   // keep this in: when you get strange overflow errors, it's 
						// because your file is too large.

	/**************/
	/*** PASS 2 ***/
	/**************/
	/* read labels, look for opcodes, assign addresses */
	i = 0;
	address = 0;
	labelcount = 0;
	while (i < wordcount) {
pass2loop:
		if (strlen(word[i])==0) continue;

		/* test ORG */
		if ((strcmp(word[i],"ORG"))==0) {
			address = hex2dec(word[i+1]);
			i+=2;
			goto pass2loop;
		}

		/* test EQU */
		if ((strcmp(word[i],"EQU"))==0) {
			strcpy(label[labelcount],word[i-1]);
			labeladdress[labelcount] = hex2dec(word[i+1]);
			labelcount++;
			i += 2;
			goto pass2loop;
		}

		/* test label: */
		if (word[i][strlen(word[i])-1] == ':') {
			word[i][strlen(word[i])-1] = '\0';	// strip ':' 
			labeladdress[labelcount] = address;
			strcpy(label[labelcount],word[i]);
			labelcount++;
			i+=1;
			goto pass2loop;
		}

		/* test opcode */
		for (n=0; n<256; n++) {
			if ((strcmp(word[i],opcodes[n]))==0) {	// word[i] is an opcode
				
				if (opcodesize[n] == 0) {
					printf("Error - invalid opcode %s\n",word[i]);
					exit(1);
				}

				if (opcodesize[n] == 1) {
					address += 1;
					i += 1;
					goto pass2loop;
				}

				if (opcodesize[n] == 2) {
					int FLAG=0;
					address += 1;	
					switch(word[i+1][0]) {
						case '#':
							address += 1;
							break;
						case '[': case '@':
							address += 2;
							break;
						default:
							for (ct=0; ct<16; ct++) {
								if ((strcmp(reg[ct],word[i+1]))==0) {
									FLAG=1;	// ignore registers
								}
							}
							for (ct=0; ct<8; ct++) {
								if ((strcmp(flags[ct],word[i+1]))==0) {
									FLAG=1;	// ignore registers
								}
							}
							if (FLAG) break;
							// not a register or flag - must be a label (memory)
							address += 2;
							break;
					}
							
					i += 2;
					goto pass2loop;
				}

				if (opcodesize[n] == 3) {
				int FLAG = 0;
					address += 1;	// always for 3 byte (opcode)
					switch(word[i+1][0]) {
						case '#':
							address += 1;
							break;
						case '[': case '@':
							address += 2;
							break;
						default:
							for (ct=0; ct<16; ct++) {
								if ((strcmp(reg[ct],word[i+1]))==0) {
									FLAG=1;	// ignore registers
								}
							}
							if (FLAG) break;
							// not a register - must be a label
							address += 2;
							break;
					}
					FLAG = 0;
					switch(word[i+2][0]) {
						case '[': case '@':
							address += 2;
							break;
						default:
							for (ct=0; ct<16; ct++) {
								if ((strcmp(reg[ct],word[i+2]))==0) {
									FLAG=1;	// ignore registers
								}
							}
							if (FLAG) break;
							// not a register, must be a label
							address += 2;
							break;
					}

					i += 3;
					goto pass2loop;
				}
				
				if (opcodesize[n] == 4) {	// JUMP/CALL only
					address += 3;
					i += 2;
					goto pass2loop;
				}
				
						
			}
		}



		


		/* test DB */
		if ((strcmp(word[i],"DB"))==0) {
			if (word[i+1][0]=='"') {
				address += (strlen(word[i+1])-2);	// don't count quotes
			} else {
				address += 1;
			}
			i+=2;
			goto pass2loop;
		}

	
		/* test DS */
		if ((strcmp(word[i],"DS"))==0) {
			address += hex2dec(word[i+1]);
			i+=2;
			goto pass2loop;
		}

		i++;

	}

	fprintf(prnfile,"PASS 2: Labels: %d\n",labelcount);

    /* uncomment for debugging */
	//for (ct=0; ct<labelcount; ct++) printf("%s %06X\n",label[ct],labeladdress[ct]);

    /* used for debugging, but duplicated later on down */
	//printf("\nLabeladdresses that equil 0: \n");
	//for (ct=0; ct<labelcount; ct++) if (labeladdress[ct]==0) printf("%s %06X\n",label[ct],labeladdress[ct]);

 

	/**************/
	/*** PASS 3 ***/
	/**************/

	/* scan all words, assign values to opcodes from labels, direct and single chars */
	i = 0;
	address = 0;	

	fprintf(prnfile,"PASS 3: Assembled Code:\n\n");

	while (i < wordcount) {
pass3loop:
		// If label matches current address, display it
		for (ct=0; ct<labelcount; ct++) if ((labeladdress[ct]==address) && (address != 0))
			if (strlen(label[ct]) > 0)
				fprintf(prnfile,"%06X\t[%s]\n",address,label[ct]);

	
		if (strlen(word[i])==0) continue;	

		/* test ORG */
		if ((strcmp(word[i],"ORG"))==0) {
			address = hex2dec(word[i+1]);
			i += 2;
			goto	pass3loop;
		}

		/* test if opcode */
		/* test opcode */
		for (n=0; n<256; n++) {
			if ((strcmp(word[i],opcodes[n]))==0) {	// word[i] is an opcode

				/*** Code 1 OPCODE ***/
				if (opcodesize[n] == 1) {
					uint16_t opcodeval;
					opcodeval = n << 8;		// shift into MSB for word
					fprintf(prnfile,"%06X  %04X\t%s\n",address,opcodeval,word[i]);
					mem[address++] = opcodeval;	// save single word value in mem
					i += 1;
					goto pass3loop;
				}


				/*** Code 4 (JUMP/CALL) ***/
				if (opcodesize[n] == 4) {
					int cnt, FLAG=0, jaddress;
					for (cnt=0;cnt<256;cnt++) {	// test if byte 2 is an opcode (is a mistake)
						if ((strcmp(word[i+1],opcodes[cnt]))==0) {
							printf("Error: byte 2 of %s is opcode %s\n",word[i],word[i+1]);
							exit(1);
						}
					}
					if ((word[i+1][0]=='[') || (word[i+1][0]=='#') || (word[i+1][0]=='@')) {  // ERROR bad address
							printf("Error: byte 2 of %s is bad address %s\n",word[i],word[i+1]);
							exit(1);
					}
					for (ct=0;ct<labelcount;ct++) {  // test if byte 2 is a label
							if ((strcmp(word[i+1],label[ct]))==0) {
								jaddress = labeladdress[ct];
								FLAG = 1;
							}
					}
					// assume it's an address
					// JUMP/CALL, no LSB assigned
					if (FLAG) {
						fprintf(prnfile,"%06X  %04X\t%s\t%s [%06X]\n",address,n<<8,word[i],word[i+1],jaddress);
						mem[address++] = n << 8;
						mem[address++] = (jaddress & 0xffff0000) >> 16;
						mem[address++] = jaddress & 0x0000ffff;
					} else {
						jaddress = hex2dec(word[i+1]);
						fprintf(prnfile,"%06X  %04X\t%s\t%s [%06X]\n",address,n<<8,word[i],word[i+1],jaddress);
						mem[address++] = n << 8;
						mem[address++] = (jaddress & 0xffff0000) >> 16;
						mem[address++] = jaddress & 0x0000ffff;
					}
					if (jaddress==0) printf("Warning: address of label %s is 0\n",word[i+1]);
					i += 2;
					goto pass3loop;
				}
				


				/*** Code 2 OPCODE ***/
				if (opcodesize[n] == 2) {	// format: opcode destination. If dest is anything but a register or label it's wrong
					uint16_t opcodeval;
	
					opcodeval = n << 8;	// shift into MSB
					// get byte 2
					int cnt;
					for (cnt=0;cnt<256;cnt++) {	// test if byte 2 is an opcode (is a mistake)
						if ((strcmp(word[i+1],opcodes[cnt]))==0) {
							printf("Error: byte 2 of %s is opcode %s\n",word[i],word[i+1]);
							exit(1);
						}
					}

					if ((word[i+1][0] == '#') || (word[i+1][0] == '@')) {  // error - no immediate values allowed
						printf("Error: byte 2 of %s is an immediate value. %s\n",word[i],word[i+1]);
						exit(1);
					}

					for (cnt=0; cnt<16; cnt++) {	// test if register
						if ((strcmp(reg[cnt],word[i+1]))==0) { // dest is a register
							opcodeval |= cnt;	// combine them
							mem[address] = opcodeval;
							if (opcodeval == 0) printf("\nPASS3: 2BYTE opcode %s value=%d\n",word[i+1],opcodeval);
							fprintf(prnfile,"%06X  %04X\t%s\t%s\n",address,opcodeval,word[i],word[i+1]);
							i += 2; address += 1;
							goto pass3loop;
						}
					}

					for (cnt=0; cnt<8; cnt++) {	// test if flags
						if ((strcmp(flags[cnt],word[i+1]))==0) {  // dest is a flag
							opcodeval |= (1 << cnt);
							mem[address] = opcodeval;
							if (opcodeval == 0) printf("\nPASS3: 2BYTE opcode %s value=%d\n",word[i+1],opcodeval);
							fprintf(prnfile,"%06X  %04X\t%s\t%s\n",address,opcodeval,word[i],word[i+1]);
							i += 2; address += 1;
							goto pass3loop;
						}
					}

				

					// test for label
					for (ct=0; ct<labelcount;ct++) {
						if ((strcmp(label[ct],word[i+1]))==0) {	// label match
					fprintf(prnfile,"%06X  %04X\t%s\t%s [%06X]\n",address,opcodeval,word[i],word[i+1],labeladdress[ct]);
							mem[address++] = opcodeval |= 1;  // assign memory command to opcode destination (source is 0)
							mem[address++] = labeladdress[ct] >> 16;
							mem[address++] = labeladdress[ct] & 0x0000ffff;
							if (labeladdress == 0) printf("Warning: label %s has address 0\n",label[ct]);
							i += 2;
							goto pass3loop;
						}
					}
					

				}

				/*** 3 BYTE OPCODE ***/
				if (opcodesize[n] == 3) {  // format:  opcode #,MEM  opcode #/@,REG  opcode MEM,REG  opcode REG,REG
					uint32_t longword, adval;
					uint16_t opcodeval, word2Hi, opcodeLo, word2Lo, immedval; int cnt;
					int IMFLAG=0; int LWFLAG=0; int ADFLAG=0; int REGFLAG=0; int BYTE3FLAG=0;

					opcodeval = n << 8;	// shift into MSB
					fprintf(prnfile,"%06X  ",address);

					/*** BYTE 2 ***/
					
					// test for label (source is memory - use value in memory)
					for (ct=0; ct<labelcount;ct++) {
						if ((strcmp(label[ct],word[i+1]))==0) {	// label match - NOT valid
							adval = labeladdress[ct];
							if (adval==0) printf("Warning: address of label %s is 0\n",word[i+1]);
							ADFLAG = 1; opcodeLo = 1 << 4;	// memory
							goto pass3byte3;
						}
					}

					// test for direct address (source is memory - use value in memory)
					if (word[i+1][0]=='[') {
						char testword[80];
						for (cnt=1; word[i+1][cnt]!=']'; cnt++) testword[cnt-1]=word[i+1][cnt];
						testword[cnt]='\0';
						adval = hex2dec(testword);
						ADFLAG = 1; opcodeLo = 1 << 4;
						goto pass3byte3;
					}




					for (cnt=0; cnt<16; cnt++) {	// test if register
						if ((strcmp(reg[cnt],word[i+1]))==0) { // source is a register
							cnt = cnt << 4;		// shift into position
							opcodeLo = cnt;		// save 
							REGFLAG = 1;
							goto pass3byte3;
						}
					}
					
					if (word[i+1][0] == '#') {	// immediate as byte 2
						int ct; char testword[80];  int FLAG=0;
						ct = 1; while (word[i+1][ct] != '\0') testword[ct-1]=word[i+1][ct++]; testword[ct-1]='\0';

						// see if testword is a label ie: load @store,IX w/store is defined by "store: DS 10"
						for (ct=0;ct<labelcount;ct++) { 
							if ((strcmp(testword,label[ct]))==0) {
								immedval = labeladdress[ct];
								FLAG = 1;
							}
						}

						// see if immed value is single char ('$')
						if ((testword[0]=='\'') && (testword[2]=='\'')) {
							immedval = testword[1]; FLAG = 1;
						}
		
						if (!FLAG)
							immedval = hex2dec(testword); 

						opcodeLo = 0;	// immed=0
						IMFLAG=1;
						goto pass3byte3;
					}


					if (word[i+1][0] == '@') { 	// 32 bit value for SP,IX,IY,PC
						int ct; char testword[80]; int FLAG=0;
						ct = 1; while (word[i+1][ct] != '\0') testword[ct-1]=word[i+1][ct++]; testword[ct-1]='\0';
						// see if testword is a label ie: load @store,IX w/store is defined by "store: DS 10"
						for (ct=0;ct<labelcount;ct++) { 
							if ((strcmp(testword,label[ct]))==0) {
								longword = labeladdress[ct];
								FLAG = 1;
							}
						}
						if (!FLAG)
							longword = hex2dec(testword);					
						opcodeLo = 0;	// immed=0
						LWFLAG=1;
						goto pass3byte3;
					}

					// error - nothing matched byte 2
					printf("Error - byte 2 of %s %s %s is unrecognized: %s\n",word[i],word[i+1],word[i+2],word[i+1]);
					exit(1);


					pass3byte3:
	
					/*** BYTE 3 of 3 ***/	// Byte 3 will always be a register, a label or an [address]

					for (cnt=0; cnt<16; cnt++) {	// test if register
						if ((strcmp(reg[cnt],word[i+2]))==0) { // dest is a register
							opcodeval |= (opcodeLo |cnt);
							mem[address++] = opcodeval;
							fprintf(prnfile,"%04X\t%s\t%s,%s",opcodeval,word[i],word[i+1],word[i+2]);
							if (IMFLAG) {		// write immed/address value as word #2
								mem[address++] = immedval;
								fprintf(prnfile," [%04X]\n",immedval);
								i += 3;
								goto pass3loop;
							}
							if (ADFLAG) {		// write address
								mem[address++] = adval >> 16;
								mem[address++] = adval & 0x0000ffff;
								fprintf(prnfile," [%06X] %d\n",adval,adval);
								i += 3;
								goto pass3loop;
							}
							if (LWFLAG) {		// write longword as word2 and 3
								mem[address++] = longword >> 16;
								mem[address++] = longword & 0x0000ffff;
								fprintf(prnfile," [%06X]\n",longword);
								i += 3;
								goto pass3loop;
							}
							// byte 3 is only a register
							i += 3;
							fprintf(prnfile,"\n");
							goto	pass3loop;
						}
					}

					// test if byte 3 is a label
					for (cnt=0; cnt<labelcount; cnt++) {
						if ((strcmp(label[cnt],word[i+2]))==0) {	// label match
							opcodeval |= (opcodeLo |1);	// 1 for memory
							mem[address++] = opcodeval;
							fprintf(prnfile,"%04X\t%s\t%s,%s",opcodeval,word[i],word[i+1],word[i+2]);
							if (IMFLAG) {		// write immed/address value as word #2
								mem[address++] = immedval;
								fprintf(prnfile," [%04X]",immedval);
							}
							if (ADFLAG) {		// write address
								mem[address++] = adval >> 16;
								mem[address++] = adval & 0x0000ffff;
								fprintf(prnfile," [%06X] %d",adval,adval);
							}
							if (LWFLAG) {		// write longword as word2 and 3
								mem[address++] = longword >> 16;
								mem[address++] = longword & 0x0000ffff;
								fprintf(prnfile," [%06X]",longword);
							}
							// now write word 3 (label address)
							if (labeladdress[cnt]==0) printf("Warning: address of label %s is 0\n",word[i+2]);
							mem[address++] = labeladdress[cnt] >> 16;
							mem[address++] = labeladdress[cnt] & 0x0000ffff;
							fprintf(prnfile,"[%06X]\n",labeladdress[cnt]);
							i += 2;
							goto pass3loop;
						}
					}



					if (word[i+2][0] == '[') {	// test for address
						int ct; uint32_t wordval;  char testword[80];
						ct = 1; while (word[i+2][ct] != ']') testword[ct-1]=word[i+2][ct++]; testword[ct-1]='\0';
						// test for label
						for (ct=0; ct<labelcount;ct++) {  // see if testword is a label [label]
							if ((strcmp(label[ct],testword))==0) {	// label match
								wordval = labeladdress[ct];
								BYTE3FLAG = 1;
							}
						}
						if (!BYTE3FLAG)
							wordval = hex2dec(testword); 

						if (REGFLAG)
							opcodeval |= opcodeLo;
						opcodeval |= 1;		// mem is dest 1 (need to ignore for jump/call)
						mem[address++] = opcodeval;
						fprintf(prnfile,"%04X\t%s\t%s,%s",opcodeval,word[i],word[i+1],word[i+2]);
						if (IMFLAG) {
							mem[address++] = immedval;
							fprintf(prnfile," [%04X]",immedval);
						}
						if (ADFLAG) {		// write address
							//fprintf(prnfile,"%06X\t",adval);
							mem[address++] = adval >> 16;
							mem[address++] = adval & 0x0000ffff;
							fprintf(prnfile," [%06X]",adval);
							}
						mem[address++] = wordval >> 16;
						mem[address++] = wordval & 0x0000ffff;
						//fprintf(prnfile,"\n");
						fprintf(prnfile," [%06X]\n",wordval);
						i += 2;
						goto pass3loop;
					}

					// error - nothing matched byte 3
					printf("Error - byte 3 of %s %s %s is unrecognized: %s\n",word[i],word[i+1],word[i+2],word[i+2]);
					exit(1);

				}
				
						
			}
		}
		



		/* not an opcode */
		

		if ((strcmp(word[i],"DS"))==0) {	// assign storage
			value = hex2dec(word[i+1]);
			fprintf(prnfile,"%04X		%s\t$%04X\n",address,word[i],value);
			for (ct=0; ct<value; ct++) mem[address++] = 0;	// set mem to 0
			i += 2;
			goto pass3loop;
		}


		if ((strcmp(word[i],"DB"))==0) {	// write data to mem
			if (word[i+1][0] == '"') {	// save everything between quotes 
				fprintf(prnfile,"%04X		%s	%s\n",address,word[i],word[i+1]);
				ct=1;
				while (word[i+1][ct] != '"') mem[address++] = word[i+1][ct++];
				i += 2;
				goto pass3loop;
			}
			/* word after DB is a label? */
			for (ct=0; ct<labelcount; ct++) {
				if ((strcmp(word[i+1],label[ct]))==0) {	// match to a label
					fprintf(prnfile,"%04X		%s	%s	%04X\n",address,word[i],word[i+1],labeladdress[ct]);
					mem[address++] = labeladdress[ct];
					i += 2;
					goto pass3loop;
				}
			}
			/* word after DB is unknown */
			//printf("Warning: word after DB is %s\n",word[i+1]);
			fprintf(prnfile,"%04X		%s	%s	%04X\n",address,word[i],word[i+1],hex2dec(word[i+1]));
			mem[address++] = hex2dec(word[i+1]);
			i += 2;
			goto pass3loop;
		}
		
		// symbol in word[i] isn't an opcode - test for something else, report an error if not found		
		
		// test symbols
		if ((strcmp(word[i+1],"EQU"))==0) {
			i+=3;
			goto pass3loop;
		}

		// test for labels
		for (ct=0; ct<labelcount; ct++) {
			if ((strcmp(word[i],label[ct]))==0) {
				i+=1;
				goto pass3loop;
			}
		}


		printf("Unknown symbol %s\n",word[i]);
		printf("surrounded by: %s %s [%s] %s %s\n",word[i-2],word[i-1],word[i],word[i+1],word[i+2]);
		i += 1;
		continue;
	}


	fprintf(prnfile,"\nLast Address Used: $%06X (decimal %d)\n",address-1,address-1);


	// show labels/addresses
	fprintf(prnfile,"\nLabels Defined\n");
	for (ct=0; ct<labelcount; ct++) 
		fprintf(prnfile,"%-15s\t$%06X\n",label[ct],labeladdress[ct]);


	// write memory contents into outfile
	for (n=0; n<address; n++) {
		fprintf(outfile,"%c",(mem[n] & 0xff00)>>8);	// output MSB
		fprintf(outfile,"%c",mem[n] & 0x00ff);
	}
	fflush(outfile);
	fclose(outfile);	
	


	printf("Final Address $%04X  %d (decimal)\n", address-1,address-1);

	/*
	printf("Found %d labels\n",labelcount);
	for (i=0; i<labelcount; i++)
		printf("%s $%04X\n",label[i],labeladdress[i]); 
	*/
	
	free(mem);
	exit(0);
}




/****************/
/*** TOKENIZE ***/
/****************/
	
#define MPE_TOK_BUFSIZE 64
#define MPE_TOK_DELIM " \t\r\n\a,"
char **split_line(char *line) {

int bufsize = MPE_TOK_BUFSIZE, position = 0;
char **tokens = malloc(bufsize * sizeof(char*));
char *token;

      if (!tokens) {
            fprintf(stdout, "token parse: allocation error\n");
            exit(EXIT_FAILURE);
      }

      token = strtok(line, MPE_TOK_DELIM);
      while (token != NULL) {
            tokens[position] = token;
            position++;

            if (position >= bufsize) {
                  bufsize += MPE_TOK_BUFSIZE;
                  tokens = realloc(tokens, bufsize * sizeof(char*));
                  if (!tokens) {
                        fprintf(stdout, "token parse: allocation error\n");
                        exit(EXIT_FAILURE);
                  }
            }

            token = strtok(NULL, MPE_TOK_DELIM);
      }
      tokens[position] = NULL;
      return tokens;
}


	
