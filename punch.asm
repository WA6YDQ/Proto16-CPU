

;***** PAPER TAPE PUNCH *****

punchStatus:	; called from main loop

		load	#$3000,R0	; status code
		load	#$4,R1		; PAPER TAPE PUNCH device code	
		trap
		cmp	#$ff,R0		; returned NOT OPENED
		jz	ps_notOpened
		cmp	#0,R0		; returned opened
		jz	ps_Opened
		; undefined error
		load	@punchUndefined,IX
		call	printf
		call	crlf
		jmp	main

ps_notOpened:	; device is not opened (and available)
		load	@punchNotOpened,IX
		call	printf
		call	crlf
		jmp	main

ps_Opened:	; device is open (and being used)
		load	@punchOpened,IX
		call	printf
		call	crlf
		jmp	main

ps_Closed:	; device is closed
		load	@punchClosed,IX
		call	printf
		call	crlf
		jmp	main

ps_notClosed:	; device can't be closed now
		load	@punchNotClosed,IX
		call	printf
		call	crlf
		jmp	main

ps_fileSaved:	; file was saved OK
		load	@punchFileSaved,IX
		call	printf
		call	crlf
		jmp	main

punchUndefined:	DB "Punch_Device_returned_an_undefined_error" DB EOL

punchNotOpened:	DB "Punch_is_available" DB EOL

punchOpened:	DB "Punch_is_in-use" DB EOL

punchClosed:	DB "Punch_is_closed" DB EOL

punchNotClosed:	DB "Punch_cannot_be_closed_at_this_time" DB EOL

punchFileSaved:	DB "File_saved_to_punch_device" DB EOL


;*** close punch ***
punchClose:	; called from the main loop
		load	#$2000,R0	; close code
		load	#4,R1		; punch device code
		trap
		cmp	#$0,R0		; OK code
		jz	ps_Closed
		cmp	#$ff,R0		; error code
		jz	ps_notClosed
		load    @punchUndefined,IX
		call	printf
		call	crlf
		jmp	main



;*** open punch ***
punchOpen:	; called from main loop

		load	#$1000,R0	; opencode
		load	#$4,R1		; punch device code
		trap
		cmp	#$ff,R0		; error
		jz	ps_notOpened
		cmp	#$0,R0		; opened OK
		jz	ps_Opened
		halt
		; undefined error
		load	@punchUndefined,IX
		call	printf
		call	crlf
		jmp	main

;*** save a file to the punch ***

p_format:	DB "Format_Type:" DB CR DB LF
		DB "1._RIM" DB CR DB LF
		DB "2._BIN" DB CR DB LF
		DB "3._ASCII" DB CR DB LF
		DB "Choice:_" DB EOL

p_startAddrHi:	DB "Starting_Address_High:_" DB EOL
p_startAddrLo:	DB "Starting_Address_Low:_" DB EOL
p_endAddrHi:	DB "Ending_Address_High:_" DB EOL
p_endAddrLo:	DB "Ending_Address_Low:_" DB EOL

;*** storage
StartaddrHi:	DS	2
StartaddrLo:	DS	2
EndaddrHi:	DS	2
EndaddrLo:	DS	2
FileSize:	DS	2

punchSave:	; called from the main loop
		; ask user for format, then get start and end address
		; format types: BIN & RIM (both DEC formats)

		load	@p_format,IX
		call	printf
		call	readline	; get user input
		load	@BUFFER,IX
		load	(IX),R0		; save choice
		push	R0		; for later
		call	crlf
		; now get the start/end addresses
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
		; end address hi
		load	@p_endAddrHi,IX
		call	printf
		call	readhex
		load	R0,EndaddrHi
		call	crlf
		; end address lo
		load	@p_endAddrLo,IX
		call	printf
		call	readhex
		load	R0,EndaddrLo
		call	crlf
		;
		; load start address in IX
		load	StartaddrHi,IX
		load	StartaddrLo,R0
		add	R0,IX
		; load end address in IY
		load	EndaddrHi,IY
		load	EndaddrLo,R0
		add	R0,IY
		; now subtract IX from IY to get file size in IY
		sub	IX,IY
		; save filesize	### NOTE ### Filesize will almost always be 16 bit!
		load	IY,FileSize  ; NO ONE does 65K paper tapes
		;
		load	@FileSize,IX	; get filesize as a single word into R3 (counter)
		inc	IX		; assume MSB will be 0 (filesize < 65536)
		load	(IX),R3		; place filesize in R3 as a counter
		; R3 holds filesize (used as a countdown)
		; load start address in IX
		load	StartaddrHi,IX
		load	StartaddrLo,R0
		add	R0,IX
		; IX now holds start address
		;
		pop	R0		; restore format choice
		cmp	#'1',R0
		jz	psave_rim	; save in RIM format
		cmp	#'2',R0	
		jz	psave_bin	; save in BIN format
		cmp	#'3',R0
		jz	psave_ascii




p_saveRim:	DB "Saving_data_in_RIM_format" DB CR DB LF
psave_rim:	halt

p_saveBin:	DB "Saving_data_in_BIN_format" DB CR DB LF
psave_bin:	halt

p_saveAscii:	DB "Saving_data_in_ASCII_format" DB CR DB LF
psave_ascii:	push	IX		;; save start address
		call	crlf
		load	@p_saveAscii,IX
		call	printf
		;pop	IX		; restore start address
		;
		; open punch
		load	#$1000,R0	; opencode
		load	#$4,R1		; punch device code
		trap
		cmp	#$ff,R0		; error
		jz	ps_notOpened	; abort on error
		;
		load	#20,R4		; leader counter
		load	#4,R1		; punch device ID
psave_a1:	load	#$80,R0		; leader code
		or	#$4000,R0	; or with write code
		trap			; write leader
		dec	R4
		jnz	psave_a1	; loop till done
		;
		; now save the data as an ascii block
		pop	IX		; restore start address, R3 holds the count
psave_a2:	load	(IX),R0		; get word
		swap	R0		; put MSB in lower byte
		and	#$00ff,R0		; mask off MSB
		or	#$4000,R0	; tack on write code
		trap			; write MSB
		load	(IX),R0		; get word
		and	#$00ff,R0		; mask off MSB
		or	#$4000,R0	; tack on write code
		trap			; write LSB
		inc	IX		; point to next address
		dec	R3		; 
		jnz	psave_a2	; continue until all data is written
		; 
		; data is all written
		load	@punchFileSaved,IX
		call	printf
		call	crlf
		; close punch
		jmp	punchClose

		

		
		
