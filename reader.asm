

;***** PAPER TAPE READER *****

readerStatus:	; called from main loop

		load	#$3000,R0	; status code
		load	#$5,R1		; PAPER TAPE READER device
		trap
		cmp	#$ff,R0		; returned NOT OPENED
		jz	rs_notOpened
		cmp	#0,R0
		jz	rs_Opened
		; undefined erro
		load	@readerUndefined,IX
		call	printf
		call	crlf
		jmp	main

rs_notOpened:	; device not opened
		load	@readerNotOpened,IX
		call	printf
		call	crlf
		jmp	main

rs_Opened:	; device is open
		load	@readerOpened,IX
		call	printf
		call	crlf
		jmp	main

punchCount:	DS	1

readerUndefined: DB "Reader_Device_returned_an_undefined_error" DB EOL

readerNotOpened: DB "Reader_is_available" DB EOL

readerOpened:	 DB "Reader_is_in-use" DB EOL

readerFinished:	 DB "File_Loaded_Successfully." DB CR DB LF 
		 DB "Words_read_" DB EOL

punchLoad:	; open the reader 
		load	#$1000,R0		; command to open reader
		load	#5,R1			; device number
		trap
		cmp	#$ff,R0			; test for error
		jz	rs_notOpened		; abort on error
		cmp	#0,R0
		jz	p_load1
		load	@readerUndefined,IX	; undefined error
		call	printf
		call	crlf
		jmp	main
		


p_load1:	load	#0,punchCount		; save word counter
		; get the start/end addresses
		load	@p_startAddrHi,IX	; ask for start address
		call	printf
		call	readhex			; get 4 hex digits in R0
		load	R0,StartaddrHi		; save high address
		call	crlf
		; low start address
		load	@p_startAddrLo,IX
		call	printf
		call	readhex
		load	R0,StartaddrLo
		call	crlf
		
		; load start address in IX
		load	StartaddrHi,IX
		load	StartaddrLo,R0
		add	R0,IX
		;
		
p_load2:	; read/discard the leader (0x80)
		load	#5,R1			; set the device
		load	#$4000,R0		; command to read a byte
		trap
		cmp	#$80,R0
		jz	p_load2			; loop past the leader

		cmp	#$aaaa,R0	
		jz	p_loadEOF		; reached EOF
		cmp	#$ffff,R0
		jz	p_loadEOF		; alt form of EOF
		
		; convert the byte to a word
		swap	R0			; put into MSB
		load	R0,R3
		load	#$4000,R0		; read next byte
		trap
		cmp	#$aaaa,R0
		jz	p_loadEOF		; reached EOF
		cmp	#$ffff,R0
		jz	rs_notOpened		; something failed
		or	R3,R0			; word now in R0
		load	R0,(IX)			; save to memory
		inc	IX			; point to next word
		inc	punchCount		; increment counter
		jmp	p_load2
		;
p_loadEOF:	; file read complete
		inc	IX			; skip past EOL
		load	#EOL,(IX)
		load	IX,BUFFEREND		; save end position
		
		load	@readerFinished,IX	; show completion message
		call	printf
		load	punchCount,R0		; get word counter
		call	printhex
		call	crlf
		
		; close the reader
		load	#10,R2			; counter
p_cls:		load	#5,R1			; set the device
		load	#$2000,R0
		trap				; send close signal
		cmp	#0,R0
		jz	main			; closed OK
		dec	R2			; keep trying up to 10 times
		jnc	p_cls			; loop until closed
		jmp	main


				 
