

;********** TAPE ***************

; tape format:
; 
; LEADER
; AAAA		Start of Data
; FFFF or FEFE	Start of Block (FFFF-block free, FEFE-block used)
;
; 0000		End of Block marker
; FFFF or FEFE  Next block...
;  :
;  :
; 0000

;-------------------------------

;********** BLOCK ***************

; FEFE		Start of block
; XXXX		File Start Address (MSB)
; YYYY		File Start Address (LSB)
; NNNN		File Size
; 16 bytes	File Name
; 1 byte	File Attributes
; 3 bytes	M/D/Y Orig Date
; 3 bytes	M/D/Y Modify Date
; 1 byte	Owner ID
; 1 byte	Group ID
; 1 byte	File Protection
; undef bytes	File proper
; 0000		Block End

;-------------------------------

;*** Tape Messages ***

tape_msg1:	DB "Could_not_close_tape_unit" DB EOL
tape_msg2:	DB "Tape_unit_closed" DB EOL
tape_msg3:	DB "Tape_unit_could_not_be_opened" DB EOL
tape_msg4:	DB "Tape_unit_opened" DB EOL
tape_msg5:	DB "Tape_formatted_successfully" DB EOL
tape_msg6:	DB "Tape_Write_Error_-_stopping" DB EOL
tape_msg7:	DB "Unexpected_data_byte:_Tape_corrupted?" DB EOL
tape_msg8:	DB "End_of_tape_reached" DB EOL
tape_msg9:	DB "Filename?_" DB EOL
tape_msg10:	DB "size_" DB EOL
tape_msg11:	DB "Files_found_" DB EOL
tape_msg12:	DB "This_will_erase_all_data!_Are_you_sure?_(y/n)_" DB EOL
tape_msg13: DB "Rewinding_Tape" DB CR DB LF DB EOL

file_counter:	DS	1



;**** REWIND ****
rewind: load    #TAPE,R1        ; select device
        load    #$1100,R0       ; send rewind command
        trap                    ; send command to tape unit
        load    @tape_msg13,IX
        call    writelog        ; show on log
        ret



;************************
;******** FORMAT ********
;************************

tape_format:	; this is a stand-alone program (not a subroutine)
		call	crlf
		load	@tape_msg12,IX
		call	printf
		call	readline	; ask if the user really wants this
		load	@BUFFER,IX
		cmp	#'y',(IX)	; y is only option
		jz	t_fmt0
		call	crlf
		jmp	main

t_fmt0:		; Open the tape device
		load	#TAPE,R1	; select tape device
		load	#$1000,R0	; open for write
		trap
		cmp	#0,R0		; test return code ff=error, 0=OK
		jnz	tape_openErr

		; Rewind the tape
        call    rewind
		;load	#TAPE,R1
		;load	#$1100,R0	; rewind tape
		;trap

		; Write leader to front of tape
		load	#TAPE,R1
		load	#80,R2		; write 80 bytes
t_fmt1:		load	#$4000,R0	; write leader
		or	#$80,R0		; leader code $80
		trap
		cmp	#$ff,R0
		jz	t_fmt3		; write error
		dec	R2
		jnz	t_fmt1		; loop until all is written

		; Write start of tape marker
		load	#TAPE,R1
		load	#$40aa,R0	; start of tape marker
		trap
		load	#$40aa,R0
		trap

		; Write Block Empty marker 
		load	#TAPE,R1
		load	#$40ff,R0
		trap
		load	#$40ff,R0
		trap

		; write 00's filling out the tape
		load	#$8000,R0	; read a byte, test for EOF
		trap
		cmp	#$ff,R0
		jz	t_fmt2a		; must be EOF - close
		load	#$9000,R0	; rewind 1 byte
t_fmt2:		load	#$4000,R0	; write a 0
		trap
		dec	R3
		jnz	t_fmt2

t_fmt2a:	; Close the tape
		; done
		load	#$2000,R0	; close tape unit
		trap
		cmp	#0,R0
		jz	tape_fmt2	; success

		; failed closing
		load	@tape_msg1,IX	; failed to close
		call	printf
		call	crlf
		jmp	main

tape_fmt2:	call	crlf
		load	@tape_msg5,IX	; formatted OK
		call	printf
		call	crlf
		jmp	main

t_fmt3:		; write error - abort
		load	@tape_msg6,IX
		call	printf
		call	crlf
		jmp	main

tape_openErr:	load	@tape_msg3,IX
		call	printf
		call	crlf
		jmp	main



;********************
;******* FIND *******

t_findStore:	DS	16
t_findfmsg1:	DB "File_not_found" DB EOL

tape_findf:	
        ; find a tape file, put start address in IX, 
		; word count in R4, exit w/0 in R0 pointing
		; at the start of the file on tape.
		; return 0xff in R0 if not found

		; open the tape
		load	#TAPE,R1
		load	#$1000,R0
		trap	
		cmp	#0,R0
		jnz	tape_openErr	; abort on error

		; get the filename to test
		load	@tape_msg9,IX
		call	printf
		call	readline	; note: changes R1
		; filename in BUFFER
		call	crlf

		; rewind the tape
		;load	#TAPE,R1
		;load	#$1100,R0
		;trap
        ;load    @tape_msg13,IX
        ;call    writelog
        call    rewind

		; scroll past the leader
		load	#TAPE,R1
t_ff1:		load	#$8000,R0	; read a byte
		trap
		cmp	#$80,R0
		jz	t_ff1		; loop past header

		cmp	#$aa,R0		; test for start of tape marker
		jnz	tape_wrErr	; no? abort
		load	#$8000,R0
		trap
		cmp	#$aa,R0
		jnz	tape_wrErr	; not at header. abort

t_ff2:		; finished reading header - pointing at #ffff/#fefe
		load	#$8000,R0
		trap
		cmp	#$ff,R0		; empty block? done reading tape.
		jz	t_ff_notfound
		; read next byte - should be $fe
		load	#$8000,R0
		trap
		cmp	#$fe,R0		; good block?
		jnz	t_ff_notfound	; nope. abort
		; at start of full block - temp load file start and filesize
		
		; read next 2 words (start address)
		load	#$8000,R0	; MSB hi
		trap
		swap	R0		; put in MSB
		load	R0,R3		; save
		load	#$8000,R0
		trap			; MSB lo
		or	R0,R3		; full MSB in R3
		; get LSB
		load	#$8000,R0	; LSB hi
		trap
		swap	R0		; put in MSB slot
		load	R0,R4		; save
		load	#$8000,R0
		trap			; LSB lo
		or	R0,R4		; save
		; now put in IX
		push	R3
		push	R4		; put on stack
		pop	IX		; address now on IX
		push	IX		; save for later
	
		; now get filesize, save in R4
		load	#TAPE,R1
		load	#$8000,R0
		trap
		swap	R0
		load	R0,R4		; get MSB
		load	#$8000,R0
		trap
		or	R0,R4		; combine, done

		load	@t_findStore,IY	; pointer to filename storage
		load	#16,R3		; filename counter
		load	#TAPE,R1
t_ff3:		load	#$8000,R0	; read a byte from tape
		trap
		load	R0,(IY)
		inc	IY
		dec	R3		; save, dec counter
		jnz	t_ff3		; and loop
		; filename stored

		load	@t_findStore,IX
		call	strcmp		; test filename against BUFFER
		cmp	#0,R0
		jz	t_ffMatch	; match!

		; no match. skip past file, jump to next block start pos
		sll	R4		; filesize x2 (words, not bytes)
		add	#12,R4		; add misc bytes to file counter
		load	#TAPE,R1
t_ff3a:		load	#$8000,R0
		trap
		dec	R4
		jnz	t_ff3a		; looppast file to start block
 		pop	IX		; get rid of previous file start 
		jmp	t_ff2		; and test next block


t_ffMatch:	; filename matches. skip past misc file bytes, point to file
		load	#10,R3
		load	#TAPE,R1
t_ffM1:		load	#$8000,R0
		trap			; read a byte
		dec	R3
		jnz	t_ffM1
		; now pointing to start of file, R4 holds start of file
		pop	IX		; IX holds start of file address
		load	#0,R0		; tape still open, positioned at data start
		ret
	

t_ff_notfound:	;show file not found, abort w/ff in R0
		call	crlf
		load	@t_findfmsg1,IX
		call	printf
		call	crlf
		; now close the tape unit
		load	#TAPE,R1
		load	#$2000,R0
		trap			; tape closed
		load	#$ff,R0
		ret			; done










;*******************
;****** DIR ********

tape_dir:	; read and display tape directory
		load	#0,file_counter
		call	crlf
		; open the tape
		load	#TAPE,R1
		load	#$1000,R0	; open codeword
		trap
		cmp	#0,R0
		jnz	tape_openErr	; abort on error
		
		; rewind the tape
		;load	#TAPE,R1
		;load	#$1100,R0
		;trap
        ;load    @tape_msg13,IX
        ;call    writelog
        call    rewind


		; scroll past leader
		load	#TAPE,R1
tape_d1:	load	#$8000,R0	; read a byte
		trap
		cmp	#$80,R0
		jz	tape_d1		; loop until past the leader

		cmp	#$aa,R0		; test for start of tape marker
		jnz	tape_wrErr	; abort on failure
		load	#$8000,R0	; get next marker byte
		trap
		cmp	#$aa,R0
		jnz	tape_wrErr	; abort on error

tape_d1a:	; finished reading header, pointing at start of a block
		load	#$8000,R0	; read the start of block char
		trap
		cmp	#$ff,R0		; empty block - done
		jz	tape_dir_done
		load	#$8000,R0	; read 2nd start of block header
		trap
		cmp	#$fe,R0
		jnz	tape_wrErr	; unexpected - abort

		inc	file_counter	; running counter of valif files

		; read next 2 words of start address
		load	#$8000,R0	; MSB hi
		trap
		load	#$8000,R0	; MSB lo
		trap
		load	#$8000,R0	; LSB hi
		trap
		load	#$8000,R0	; LSB lo
		trap

		; now read file size
		load	#TAPE,R1
		load	#$8000,R0
		trap
		load	R0,R3		; MSB in R3
		swap	R3		; move MSB to upper byte
		load	#$8000,R0
		trap			; LSB in R0
		or	R3,R0		; R0 holds filesize
		load	R0,R3		; R3 holds 16 bit filesize
 
		; now read/display the filename
		load	#16,R4		; filename counter
tape_d2:	load	#TAPE,R1
		load	#$8000,R0	; read a byte
		trap
		load	#CONOUT,R1
		trap			; print it
		dec	R4
		jnz	tape_d2

		; now show filesize
		load	#$20,R0
		load	#CONOUT,R1
		trap
		load	@tape_msg10,IX
		call	printf
		load	R3,R0
		call	printdec
		call	crlf

		; skip past the rest of the file (11 reads + filesize)
		load	#12,R4		; R3 holds filesize
		sll	R3		; mult filesize x2 (words to bytes)
		add	R3,R4		; R4 holds # of reads to get to next block
		load	#TAPE,R1
tape_d3:	load	#$8000,R0
		trap
		dec	R4
		jnz	tape_d3
 
		; pointing at next block
		jmp	tape_d1a




tape_dir_done:	call	crlf
		load	@tape_msg11,IX
		call	printf
		load	file_counter,R0
		call	printdec
		call	crlf
		jmp	main			; finished


;****** WRITE *******   (subroutine)
tape_write:	; write to the tape
		; IX points to start of the file
		; IY points to end of the file

		call	crlf

		; open the tape unit
		load	#TAPE,R1
		load	#$1000,R0	; open code
		trap
		cmp	#0,R0
		jnz	tape_openErr

		; rewind the tape
		;load	#TAPE,R1
		;load	#$1100,R0
		;trap
        call    rewind


		; skip leader
		load	#TAPE,R1	; select device
tape_wr1:	load	#$8000,R0
		trap			; read a byte
		cmp	#$80,R0		; look for leader
		jz	tape_wr1	; loop past leader
	
		cmp	#$aa,R0
		jnz	tape_wrErr	; abort on error
		load	#$8000,R0	; read next byte
		trap
		cmp	#$aa,R0		; abort on error
		jnz	tape_wrErr

		; finished header, now search for an empty block
tape_wr2:
		load	#TAPE,R1	; select device
		load	#$8000,R0	; read a byte
		trap
		cmp	#$ff,R0		; free block
		jz	tape_wr_free

		cmp	#$fe,R0		; busy block
		jz	tape_wr_skpbusy
	
		; not FE or FF - corrupted?
		load	@tape_msg7,IX
		call	printf
		call	crlf
		
		; close the tape
		load	#$2000,R0
		trap
		ret			; done - aborted

tape_wr_skpbusy:	; tape block is used. skip past, try again

		load	#$8000,R0	; get 2nd block header byte
		trap
		load	#$8000,R0	; get MSB(H) of start address
		trap
		load	#$8000,R0	; get MSB(LO) of start address
		trap
		load	#$8000,R0	; get LSB(HI) of start address
		trap
		load	#$8000,R0	; get LSB(LO) of start address
		trap

		; now get 16 bits of file size and store them
		load	#$8000,R0
		trap
		load	R0,R3		; MSB
		load	#$8000,R0
		trap
		load	R0,R4

		; skip next 26 header bytes
		load	#26,R2
t_wr_skp1:	load	#$8000,R0
		trap
		dec	R2
		jnz	t_wr_skp1	; loop until done

		; get filesize
		load	R3,R0
		swap	R0		; put in MSB
		or	R4,R0
		load	R0,R3		; R3 holds filesize

		; read/discard file data
t_wr_skp2:	load	#$8000,R0	; read MSB
		trap
		load	#$8000,R0	; read LSB
		trap
		dec	R3
		jnz	t_wr_skp2	; loop until done

		; read EOFile ($0000)
		load	#$8000,R0
		trap
		cmp	#0,R0
		jnz	t_wr_skp3	; bad byte - abort
		load	#$8000,R0
		trap
		cmp	#0,R0
		jnz	t_wr_skp3	; bad byte - abort

		; finished reading block - jump up and do again looking for free blk
		jmp	tape_wr2

tape_wrErr:
t_wr_skp3:	; got bad end of block bytes - abort
		load	@tape_msg7,IX
		call	printf
		call	crlf
		ret			; done here	
	

		;--------------------

tape_wr_free:	; IX holds start address, IY holds end address
		; need to derive filesize, get filename from user
		; and write misc header bits

		load	#TAPE,R1	; set device
		; backup 1 byte, write $fe - then again
		load	#$9000,R0
		trap

		; now write $FEFE (start of busy block)
		load	#$40fe,R0
		trap
		load	#$40fe,R0
		trap			; write 2 fe's to tape

		; now write start address
		push	IX		; get start address, write to tape
		pop	R3		; LSB
		pop	R0		; MSB
		push	R0
		swap	R0		; we want the MSB of the MSB of IX
		and	#$00ff,R0	; mask out high 
		or	#$4000,R0	; combine with write command
		trap
		pop	R0		; get the LSB of the MSB of IX
		and	#$00ff,R0	; mask out high
		or	#$4000,R0
		trap			; write lsb of MSB

		load	R3,R0
		swap	R0		; get MSB of LSB
		and	#$00ff,R0	; mask out high
		or	#$4000,R0	; save LSB
		trap
		load	R3,R0		; get LSB of LSB
		and	#$00ff,R0	; mask out high
		or	#$4000,R0
		trap			; save it
		
		; now derive filesize
		sub	IX,IY		; filesize is in IY
		push	IY
		pop	R3		; LSB
		load	R3,R5		; save for later
		pop	R0		; MSB - will never be > 16 bits - discard
		load	R3,R0
		swap	R0		; put in byte location
		and	#$00ff,R0		; mask out high
		or	#$4000,R0
		trap			; write MSB of filesize
		load	R3,R0
		and	#$00ff,R0		; mask out high
		or	#$4000,R0
		trap			; write LSB of filesize

		; get and write 16 byte filename
		load	@tape_msg9,IX
		call	printf
		call	readline

		; save 16 bytes of filename
		load	#TAPE,R1
		load	#16,R3
		load	@BUFFER,IX
tape_wr_f1:	load	(IX),R0
		and	#$00ff,R0	; mask high
		or	#$4000,R0	; assign write command to it
		trap			; write char to tape
		inc	IX		; next char
		dec	R3
		jnz	tape_wr_f1	; do all 16 bytes

		load	#TAPE,R1	
		; save file attributes
		load	#$40dd,R0
		trap

		; save 3 bytes of orig date
		load	#$4001,R0
		trap
		load	#$4002,R0
		trap
		load	#$4003,R0
		trap

		; and 3 bytes of mod date
		load	#$4004,R0
		trap
		load	#$4005,R0
		trap
		load	#$4006,R0
		trap

		; save 1 byte of owner ID
		load	#$4001,R0
		trap

		; and 1 byte of group ID
		load	#$4001,R0
		trap

		; save protection ID
		load	#$4044,R0
		trap

		; now save the file
		; filesize in R5
		load	@USERSTART,IY
tape_wr_f2:	load	(IY),R0		; get a byte
		swap	R0		; save MSB first
		and	#$00ff,R0	; mask off high (text, shouldn't be any)
		or	#$4000,R0	; add command
		trap
		load	(IY),R0
		and	#$00ff,R0	; save LSB
		or	#$4000,R0
		trap
		;
		inc	IY
		dec	R5
		jnz	tape_wr_f2	; loop intil written

		; file saved, now write 0000 end of block
		load	#$4000,R0
		trap
		load	#$4000,R0
		trap

		; and write $ffff for next block
		load	#$40ff,R0
		trap
		load	#$40ff,R0
		trap

		; done. close the device
		load	#$2000,R0
		trap
		ret		; fin


		halt
