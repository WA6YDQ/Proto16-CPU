/* trap decoder for 16 bit proto cpu */
/* (C) k theis 2/2019 */

/* input/output device drivers for proto 16 cpu */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>

extern uint16_t *mem;

FILE *PUNCH, *READER;	// paper tape punch and reader
FILE *TAPE;		        // TAPE unit
FILE *LOGFILE;          // logfile

int trap (uint16_t word, uint16_t device) {
int RC;	            // return code	
char tapename[40];	// pulled from memory
int n;



	/* When calling these routines, R0 holds the data/control word */
	/* and R1 holds the device address. IE: R1 = 0, driver is CONOUT */


	switch (device) {

		/************ CONOUT ***********/
		case	0x00:
			fprintf(stdout,"%c",word);
			RC = 0;
			break;



		/************ CONIN ***********/
		case	0x01: {
			int buf;
			system("stty raw -echo");
			buf = getchar();
			RC = (uint32_t) buf;
			system("stty sane");
			break;
		}
			
		/*********** PRINT DECIMAL *********/
		case	0x02: 
			fprintf(stdout,"%d",word);
			RC = 0;
			break;



		/************ TAPE ****************/
		case	0x03: { // tape drivers
			for (n=0; n!=20; n++) tapename[n]=mem[n+0x20];
			//fprintf(stdout,"tape filename %s\n",tapename);
			/* tapename set in mem[0x20], null terminated */
	
			if (word == 0x1000) { // open file for write
				TAPE = fopen(tapename,"r+");
				if (TAPE == NULL) return 0xff;	// error code
				if (TAPE != NULL) return 0;	// OK
				return 0xa5a5;			// unknown error
				break;
			}
			if (word == 0x1100) {	// rewind tape
				if (TAPE == NULL) return 0xff;	// not open
				if (TAPE != NULL) {
					rewind(TAPE);
					return 0;
				}
				return 0x5a5a;
			}
			if (word == 0x2000) { // close file
				if (TAPE == NULL) return 0xff;	// already closed
				if (TAPE != NULL) {
					fclose(TAPE);
					TAPE = NULL;
					return 0;
					break;
				}
			}
			if (word == 0x3000) {	// return status
				if (TAPE == NULL) return 0xff;	// closed
				if (TAPE != NULL) return 0;	// opened
				return 0xa5a5;
				break;
			}
			if ((word & 0xff00) == 0x4000) {	// write lower byte to tape
				if (TAPE==NULL) fprintf(stderr,"tape not open\n");
				if (TAPE == NULL) return 0xff;	// error - tape closed
	//fprintf(stderr,"wrote %c\n",word&0x00ff);
				if (TAPE != NULL) {
					fprintf(TAPE,"%c",word & 0x00ff);
					return 0;
				}
				return 0x5a5a;
			}
			if (word == 0x8000) {	// read/return a byte from tape
				RC = fgetc(TAPE);
	//fprintf(stderr,"read a tape byte: %02X\n",RC);
				return RC;
			}

			if (word == 0x9000) {	// rewind tape 1 position
				RC = fseek(TAPE,(-1),SEEK_CUR);
				return RC;
			}
		}


		/****** PAPER TAPE PUNCH ********/
		case	0x04: {	// paper tape punch
			if (word == 0x1000) { // open file for write
				PUNCH = fopen("papertape","w");
				if (PUNCH == NULL) return 0xff;	// error code
				if (PUNCH != NULL) return 0x00;	// OK code
				return 0xa5a5;
				break;
			}
			if (word == 0x2000) { // close file
				if (PUNCH == NULL) return 0xff;	// already closed
				if (PUNCH != NULL) {
					fclose(PUNCH);
					PUNCH = NULL;
					return 0x00;		// OK code
					break;
				}
			}
			if (word == 0x3000) { // return status of punch
				if (PUNCH == NULL) return 0xff;	// closed
				if (PUNCH != NULL) return 0x00;	// OK code
				return 0xa5a5;
				break;
			}
			if ((word & 0xff00) == 0x4000) {	// write lower byte to device
				if (PUNCH == NULL) return 0xff;	// error - not open
				if (PUNCH != NULL) { 
					fprintf(PUNCH,"%c",word&0x00ff);
					return 0x00;	// OK code
				}
				return 0xa5a5;
				break;
			}
		}  // done with punch


		/****** PAPER TAPE READER *********/
		case	0x05: { // paper tape reader
			if (word == 0x1000) {  // open file for read
				READER = fopen("papertape","r");
				if (READER == NULL) return 0xff;  //error code
				if (READER != NULL) return 0x00;  // OK code
				return 0xa5a5;
			}
			if (word == 0x2000) { // close file
				if (READER == NULL) return 0xff;  // already closed
				if (READER != NULL) {
					fclose(READER);
					READER = NULL;
					return 0x00;		// OK code
				}
			}
			if (word == 0x3000) {  // return status of reader
				if (READER == NULL) return 0xff;  // closed
				if (READER != NULL) return 0x00;  // OK code
				return 0xa5a5;
			}
			if (word == 0x4000) {	// read/return byte in LSB of word
				int retval = 0;
				retval = fgetc(READER);
				if (feof(READER)) return 0xaaaa;	// End of File Marker
				return retval;
			}
		} // done with reader

        /******* LOGFILE *******/
        case    0x06: { //log file for CPU op sys 
            if (word == 0x1000) { // open log file
                LOGFILE = fopen("syslog.txt","a");
                if (LOGFILE == NULL) return 0xff;   // error code
                if (LOGFILE != NULL) return 0x00;   // OK code
                return 0xa5a5;
            }
            if ((word & 0xff00) == 0x2000) {  // write to logfile
                if (LOGFILE == NULL) return 0xff;  // error code
                if (LOGFILE != NULL) {
                    fprintf(LOGFILE,"%c",word&0x00ff);
                    fflush(LOGFILE);
                    return 0;   // OK code
                }
            }
            if (word == 0x3000) { // close logfile
                if (LOGFILE == NULL) return 0;
                if (LOGFILE != NULL) {
                    fflush(LOGFILE);
                    fclose(LOGFILE);
                    return 0;
                }
            }
        }

		default:
			RC = 0;

	}

	return RC;
}

