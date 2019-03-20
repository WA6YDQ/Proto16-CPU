;; sys.asm 
;; (c) k theis 2/2019 
;; command shell written for the proto 16 cpu

CR	EQU	13
LF	EQU	10
TAB	EQU	9
EOL	EQU	0		    ; end of line marker
ESC	EQU	$1b
BS	EQU	$7f
EOF	EQU	$ffff		; end of file marker

CONIN	EQU	1
CONOUT	EQU	0
TAPE	EQU	3

; define memory space pointers
STACK		EQU	$00ffff
USERSTART	EQU	$2000
USEREND		EQU	$F000
TAPENAME	EQU	$20

ORG	$0000

coldstart:
start:	
    load	@STACK,SP
	load	@intromsg,IX
	call	printf
	load	#0,MODE		; set mode to normal
	; now set the user space to ffff (EOF)
	call	filluser
	load	@USERSTART,IY
	load	IY,BUFFEREND
	;
    ; initialize the logfile
    call    openlog
    ;
	jmp	warmstart

; Page 0 address 20 (dec) holds the tapename
ORG $20
tapename: DB "tape01" DB EOL	; initial value



;*****************
;*** MAIN LOOP ***
;*****************


ORG	$100
warmstart:

main:	; main loop

	load	#'>',R0
	load	#CONOUT,R1
	trap			    ; show cursor
	call	readline	; get a line into BUFFER
	call	crlf
	load	BUFFER,R0	; test 1st char of BUFFER
	cmp	#EOL,R0		    ; <cr> entered? (will convert to EOL)
	jz	main		    ; do nothing

	; test commands vs buffer contents

	load	@com_punchStatus,IX	; show status of the punch
	call	strcmp
	cmp	    #0,R0
	jz	    punchStatus

	load	@com_readerStatus,IX	; show status of the reader
	call	strcmp
	cmp	    #0,R0
	jz	    readerStatus

	load	@com_punchSave,IX	; save a file to the punch
	call	strcmp
	cmp	    #0,R0
	jz	    punchSave

	load	@com_punchLoad,IX	; load a file from the punch/reader
	call	strcmp
	cmp	    #0,R0
	jz	    punchLoad

	load	@com_dump,IX		; dump (display) a page of memory
	call	strcmp
	cmp	    #0,R0
	jz	    dump

	load	@com_type,IX		; show a files contents
	call	strcmp
	cmp	    #0,R0
	jz	    type

	load	@com_edit,IX		; line editor
	call	strcmp
	cmp	    #0,R0
	jz	    edit

	load	@com_basic,IX		; basic interpreter
	call	strcmp
	cmp	    #0,R0
	jz	    basic

	load	@com_mem,IX		; show user memory stats
	call	strcmp
	cmp	    #0,R0
	jz	    mem

	load	@com_tapeFormat,IX	; format the tape on the tape drive
	call	strcmp
	cmp	    #0,R0
	jz	    tape_format

	load	@com_tapeDir,IX		; show directory of tape files
	call	strcmp
	cmp	    #0,R0
	jz	    tape_dir

	load	@com_tapename,IX	; show/get name of the tape
	call	strcmp
	cmp	    #0,R0
	jz	    tapename

	load	@com_cls,IX		; clear the screen
	call	strcmp
	cmp	    #0,R0
	jz	    cls

	load	@com_quit,IX		; quit to hardware monitor
	call	strcmp
	cmp	    #0,R0
	jz	    mon

	load	@com_reset,IX		; reset the computer
	call	strcmp
	cmp	    #0,R0
	jz	    coldstart

	; last command (allows followthru to err message)
	load	@com_help,IX	; test "help"
	call	strcmp
	cmp	    #0,R0
	jnz	    err		; not help - show error
	call	help
	jmp	    main
	
err:	load	@errmsg,IX
	call	printf
	jmp	    main



;**** MON ****
mon:	halt		; exit to monitor
	nop		; re-entrant
	jmp	0


;**** MESSAGES ***

intromsg:       DB      "Proto16_Shell" DB CR DB LF DB EOL
errmsg:         DB      "EH?" DB CR DB LF DB EOL

helpmsg:	DB	"Command_List:" DB CR DB LF
		DB	"cls________Clear_the_screen" DB CR DB LF
		DB	"mon________Start_the_hardware_monitor" DB CR DB LF
		DB	"help_______Print_this_message" DB CR DB LF
		DB	"edit_______Line_editor" DB CR DB LF 
		DB	"run________Start_BASIC_program" DB CR DB LF
		DB	"reset______Reset_the_Computer" DB CR DB LF
		DB	"dump_______Display_a_page_of_memory" DB CR DB LF
		DB	"pstatus____Show_status_of_the_paper_tape_punch" DB CR DB LF
		DB	"rstatus____Show_status_of_the_paper_tape_reader" DB CR DB LF
		DB	"psave______Save_a_file_to_the_paper_tape_punch" DB CR DB LF
		DB	"pload______Load_a_file_from_the_paper_tape_reader" DB CR DB LF
		DB	"dir________Show_tape_directory" DB CR DB LF
		DB	"format_____Format_the_tape" DB CR DB LF
		DB	"mem________Show_User_Memory_Statistics" DB CR DB LF
		DB	"type_______Show_file_contents" DB CR DB LF
		DB	"tapename___Set_name_of_the_tape_to_use" DB CR DB LF
		DB EOL


;*** COMMAND LIST ***
com_cls:		    DB	"cls"		DB EOL	; clear the screen
com_help:		    DB	"help"		DB EOL	; help
com_quit:		    DB	"mon"		DB EOL	; monitor
com_edit:		    DB	"edit"		DB EOL	; line editor
com_basic:		    DB	"run"		DB EOL	; BASIC interpreter
com_reset:		    DB	"reset"		DB EOL	; reset the computer
com_punchStatus: 	DB	"pstatus" 	DB EOL  ; show punch status
com_readerStatus: 	DB	"rstatus" 	DB EOL  ; show reader status
com_punchSave:		DB	"psave"		DB EOL	; save a file to the paper tape punch
com_punchLoad:		DB	"pload" 	DB EOL	; read a file from the paper tape reader
com_dump:		    DB	"dump"		DB EOL	; dump (display) a page of memory
com_tapeFormat:		DB	"format"	DB EOL	; tape format
com_tapeDir:		DB	"dir"		DB EOL	; tape directory
com_mem:		    DB	"mem"		DB EOL	; show mem stats
com_type:		    DB	"type"		DB EOL	; show a files contents
com_tapename:		DB	"tapename"	DB EOL	; set tape name


;***********************
;***** SUBROUTINES *****
;***********************


;**** TAPENAME ****
tname_msg1:	DB "New_tapename:_" DB EOL
tname_msg2:	DB "Current_tapename:_" DB EOL

tapename:	; set name of tape to use
		load	@tname_msg2,IX
		call	printf			; show current tapename
		load	@TAPENAME,IX
		call	printf
		call	crlf
		;
		load	@tname_msg1,IX		; now ask for new name
		call	printf
		call	readline		; get tape name
		load	@BUFFER,IX
		cmp	#EOL,(IX)		; look for EOL (<cr>)
		jz	tname2			; nothing entered
		load	@TAPENAME,IY
tname1:		load	(IX),(IY)		; copy name from buffer to TAPENAME
		inc	IX
		inc	IY
		cmp	#EOL,(IX)
		jnz	tname1			; loop until done
		call	crlf
		jmp	main			; done

tname2:		call	crlf
		jmp	main



;**** TYPE ****
type:		; show file contents from named file
		call	crlf
		call	tape_findf
		cmp	#0,R0
		jz	type1		; found a file
		; no file found - close tape and edit
		jmp	main
		
		; tape positioned to file start, R4 holds filesize, IX holds address
type1:		
		load	#TAPE,R1
		load	#$8000,R0
		trap			; read a byte
		swap	R0		; push into MSB slot
		load	R0,R3		; save MSB
		load	#$8000,R0
		trap
		or	R0,R3
		load	R3,R0
		cmp	#EOL,R0		; show crlf on match
		jnz	type2
		call	crlf
		dec	R4
		jnz	type1		; next byte
		jmp	type3		; done. exit
type2:		load	#CONOUT,R1
		trap			; print a byte
		dec	R4
		jnz	type1

type3:		; done printing
		load	#TAPE,R1
		load	#$2000,R0	; close the tape
		trap
		call	crlf			
		jmp	main		; done



;**** FILLUSER ****
filluser:	; initialize user memory to EOF (ffff)
		load	@USERSTART,IX
		load	@USEREND,IY
		sub	IX,IY		; (IY=IY-IX) IY holds mem size
		push	IY
		pop	R3		; MSB in R3 - counter
		pop	R0		; throw away value
fillu_1:	load	#EOF,(IX)	; fill memory
		inc	IX
		dec	R3		; counter
		jnz	fillu_1		; continue
		; set pointers
		load	@USERSTART,IX
		load	IX, BUFFEREND
		ret



;**** MEM ****

mem_msg1:	DB "Start/End_of_User_Memory_$" DB EOL
mem_msg2:	DB "User_Memory_in_use_" DB EOL
mem_msg3:	DB "Available_User_Memory_" DB EOL
mem_msg4:	DB "_bytes" DB EOL

mem:		; show memory details

		; show start, end of memory
		load	@mem_msg1,IX
		call	printf
		load	@USERSTART,IX
		push	IX
		pop	R3		; LSB
		pop	R0		; MSB
		call	printhex
		load	R3,R0
		call	printhex
		load	#CONOUT,R1
		load	#'-',R0
		trap
	
		; show end of user memory
		load	@USEREND,IX
		push	IX
		pop	R3		; LSB
		pop	R0		; MSB
		call	printhex
		load	R3,R0
		call	printhex
		call	crlf

		; show user memory in use (BUFFEREND-USERSTART)
		load	@mem_msg2,IX
		call	printf
		load	@USERSTART,IX
		load	BUFFEREND,IY
		sub	IX,IY		; value in IY
		push	IY
		pop	R0		; LSB
		load	#2,R1		; show decimal number
		trap
		load	@mem_msg4,IX
		call	printf
		call	crlf

		; show available user memory
		load	@mem_msg3,IX
		call	printf
		load	BUFFEREND,IX
		load	@USEREND,IY
		sub	IX,IY
		push	IY
		pop	R0		; LSB
		load	#2,R1
		trap			; show decimal number
		pop	R0		; throwaway MSB
		load	@mem_msg4,IX
		call	printf
		call	crlf
		jmp	main


;**** PRINTDEC ****
printdec:	; print value in R0 as decimal
		push 	R0
		push 	R1
		load	#2,R1
		trap
		pop	R1
		pop	R0
		ret


;*** PRINTF ***
printf:
	        load	#0,R1		; conout
	        load	(IX),R0
	        cmp	#EOL,R0
	        rz
	        cmp	#'_',R0
	        jnz	pf_1
	        load	#$20,R0		; convert _ to ' '
pf_1:	
            trap			    ; send char
	        inc	IX
	        jmp	printf



;*** CRLF ***
crlf:	    load	#CONOUT,R1
	        load	#CR,R0
	        trap
	        load	#LF,R0
	        trap
	        ret



;*** CLS ***
cls:		load	#60,cls_temp
cls_1:		call	crlf
		    dec	cls_temp
		    jnz	cls_1
		    jmp	main
cls_temp:	DS	1



;*** HELP ***
help:		load	@helpmsg,IX
		    call	printf
		    call	crlf
		    ret



;*** PRINTHEX ***
printhex:	; value in R0, print as ascii hex
	load	R0,b2h_STORE	; save value in R0
	and	#$f000,R0
	swap	R0
	srl  	R0
	srl  	R0
	srl  	R0
	srl	R0	; shift to right nibble
	call	b2h		; return digit in R0
	load	#CONOUT,R1
	trap			; display it
	; get 2nd digit
	load	b2h_STORE,R0
	and	#$0f00,R0
	swap	R0
	call	b2h
	trap			; display it
	; get 3rd digit
	load	b2h_STORE,R0
	and	#$f0,R0
	srl	R0
	srl	R0
	srl	R0
	srl	R0
	call	b2h
	trap			; display it
	; get 4th digit
	load	b2h_STORE,R0
	and	#$f,R0
	call	b2h
	trap
	ret			; done

b2h:	add	#'0',R0
	clr	CY
	cmp	#$3a,R0
	jc	b2h_1
	add	#7,R0
b2h_1:	ret

b2h_STORE:	DS	1

	

;*** READLINE ***

readline:	; read a line from conin, store in BUFFER
		; uses IX, R0, R1, R2
		load	@BUFFER,IX
		load	#80,R2		; size of buffer
rl_clr:		
        load	#EOL,(IX)	; clear buffer before use
		inc	IX
		dec	R2
		jnz	rl_clr		; loop thru beginning
		; start reading chars into buffer
		load	@BUFFER,IX
		load	#80,R2		; char count (max)	
rl_loop:	load	#CONIN,R1	; read a char from conin
		trap
		; compare with special chars
		cmp	#$5,R0		; test for ctrl-E
		jz	mon		    ; exit shell

        cmp #$3,R0      ; cntl-C
        jz  main

		cmp	#ESC,R0		; escape key
		jz	rl_esc		; immediate escape, save EOL
		
		cmp	#BS,R0		; test for backspace
		jz	rl_BS

rl0a:		cmp	#CR,R0
		jz	rl_end

		jmp	rl1		; save char, keep reading

rl_esc:		; set mode to 0, exit to main loop
		load	#0,MODE
		load	#ESC,R0
		ret			; return


rl_end:		load	#EOL,(IX)
		ret

rl1:		cmp	#0,R2
		jz	rl_loop		; if countdown=0, don't print or save
		load	R0,(IX)		; save conin char
		load	#CONOUT,R1
		trap			; echo char
		inc	IX
		dec	R2
		jmp	rl_loop

rl_BS:		; backspace
		cmp	#80,R2		; see if we're already at the beginning
		jz	rl_loop		; yep - ignore BS
		inc	R2		; 
		dec	IX		; point to last char in buffer
		load	#CONOUT,R1
		load	(IX),R0		; print char being deleted
		trap
		load	#'\',R0
		trap			; show BS char
		jmp	rl_loop		; continue

BUFFER:		DS	82		;; buffer storage +2
MODE:		DS	2		; holds MODE 0=normal, 1=edit


;*** STRCMP ***

str_buf:	DS	1	; temp byte storage
strcmp:		; compare index and string
		; (IX) points to string to test
		; (IY) points to BUFFER

		load	@BUFFER,IY
cstrcmp:	; custom jump point
strcmp_0:	cmp	#EOL,(IY)	; get 1st char of test buffer
		jz	strcmp_3

strcmp_1:	; test buffer for space
		cmp	#$20,(IY)
		jnz	strcmp_2

strcmp_3:	; line buffer ended
		cmp	#EOL,(IX)
		jnz	strcmp_fail
		jmp	strcmp_pass
strcmp_2:	cmp	(IX),(IY)
		jnz	strcmp_fail
		inc	IX
		inc	IY
		jmp	strcmp_0

strcmp_fail:	; no match, return 0
		load	#$ff,R0
		ret
strcmp_pass:	load	#0,R0		; exit routine leaving IY pointing at space after test word
		ret


;*** READADDRESS ***
readaddress:	; read 32 bits (8 chars), store on stack (MSB:LSB)
		call	readhex
		push	R0		; MSB
		call	readhex
		push	R0		; LSB
		ret	




;*** READHEX ***

readhex:	; call readline, get 4 hex chars, convert, return in R0
		call	readline
		load	@BUFFER, IX

		load	#0,R0
		load	R0,h2b_store	; initialize result
		load	#$30,R0
		load	R0,h2b_temp
		;
		load	(IX),R0		; get 1st char
		call	h2b
		swap	R0
		sll  	R0
		sll  	R0
		sll	R0  
		sll	R0	; shift left
		load	R0,h2b_store	; save it
		;
		inc	IX		; point to next
		load	(IX),R0
		call	h2b
		swap	R0
		or	h2b_store,R0
		load	R0,h2b_store
		;
		inc	IX		; point to next
		load	(IX),R0
		call	h2b
		sll	R0
		sll	R0
		sll	R0
		sll	R0		; shift left
		or	h2b_store,R0
		load	R0,h2b_store
		;
		inc	IX		; point to last
		load	(IX),R0
		call	h2b
		or	h2b_store,R0
		ret			; return w/hex word in R0

h2b:		clr	CY		; ascii to hex
		sub	h2b_temp,R0
		cmp	#$a,R0
		jc	h2b_1
		and	#$df,R0		; if letter, convert to UPPER CASE
		sub	#7,R0
h2b_1:		ret

h2b_store:	DS	1
h2b_temp:	DS	1



;***** DUMP *****
dump_addr:	DS	2
dump_msg:	DB "Start_Address:_" DB EOL

dump:		; display a page of memory (currently only on zero page)
		load	@dump_msg,IX
		call	printf
		call	readhex		; put 4 hex digits in R0
		load	@0,IX
		add	R0,IX		; IX now holds start address

		load	#$100,R2	; counter (word)
		load	#16,R3		; counter (line)

		call	crlf
		push	IX		; 1st show address
		pop	R0		; get LSB
		call	printhex	; display it
		pop	R0		; throw away MSB
		load	#':',R0		; print space
		load	#CONOUT,R1
		trap
dump_1:		load	(IX),R0
		call	printhex	; show word
		load	#$20,R0		; print a space
		load	#CONOUT,R1
		trap			; show space
		inc	IX
		dec	R3
		jnz	dump_2
		call	crlf		; show a CRLF every 16 words
		push	IX		; get current address
		pop	R0		; read LSB
		call	printhex	; print it
		pop	R0		; throw MSB away
		load	#':',R0
		trap			; print space
		load	#16,R3		; reset counter
dump_2:		dec	R2
		jnz	dump_1		; continue
		; done
		call	crlf
		jmp	main




;**** DEC2HEX ****
d2h_CNT:	DS	1	; digit counter
d2h_CD:		DS	1	; count down
d2h_RES:	DS	1	; result

dec2hex:	; call readline, input decimal number, return binary value in R0. Uses R4, R0, IX
		call	readline
d2h_entry:	load	@BUFFER,IX
		load	#0,d2h_CNT	; initialize exponent to 0
		load	#0,R4		; initialize holding var
		load	#0,d2h_RES	; initialize result
d2h_1:		load	(IX),R0		; look for EOL, inc exponent while !EOF
		cmp	#EOL,R0
		jz	d2h_2		; got it
		inc	d2h_CNT
		inc	IX
		jmp	d2h_1		; loop until EOF
d2h_2:		; d2h_CNT holds exponent
		load	@BUFFER,IX	; point to start of decimal number
d2h_2a:		load	d2h_CNT,R0	; get exponent
		load	R0,d2h_CD
		load	#1,R0		; initialize
d2h_3:		dec	d2h_CD
		jz	d2h_4		; if only 1 digit, don't mult by 10
		mul	#10,R0		; multiply 1x10
		jmp	d2h_3		; keep it up until 1 digit remains	
d2h_4:		load	R0,R4		; save exp^10 d2h_TMP
		load	(IX),R0		; get digit from buffer
		clr	CY
		sub	#$30,R0		; convert from ascii char to binary
		mul	R4,R0		; multiply exp^10 * 1st digit d2h_TMP,R0
		add	d2h_RES,R0
		load	R0,d2h_RES	; save it
		inc	IX		; next digit
		dec	d2h_CNT	; dec exponent counter
		jnz	d2h_2a
		; done - result in d2h_RES
		load	d2h_RES,R0
		ret			; return with result in R0


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


				 


;*** EDIT ***

; This is a line editor

BUFFEREND:	DS	2	; hold address of end of buffer
InsertPos:	DS	2	; holds insert position in buffer 


edit:	
		
edit_loop:	call	crlf
		load	#CONOUT,R1
		load	#'#',R0
		trap				; show command cursor

		call	readline		; get a command
		load	@BUFFER,IX		; point to start of line just entered

		cmp	#EOL,(IX)		; <cr>
		jz	edit_loop

		cmp	#'x',(IX)		; exit the editor?
		jz	edit_exit

		cmp	#'l',(IX)		; list the buffer
		jz	edit_list

		cmp	#'d',(IX)		; delete a line
		jz	edit_delete

		cmp	#'w',(IX)		; write file to tape
		jz	edit_save

		cmp	#'r',(IX)		; read file from tape
		jz	edit_read

		cmp	#'b',(IX)		; run a basic program
		jz	basic
	
		cmp	#'i',(IX)		; insert a line
		jz	edit_insert

		cmp	#'p',(IX)		; print a range of lines 
		jz	edit_print

		cmp	#'?',(IX)		; show command summary?
		jz	edit_help

		cmp	#'a',(IX)		; append mode?
		jz	edit_append

		cmp	#'m',(IX)		; show memory locations
		jz	edit_mem

		cmp	#'c',(IX)		; clear the buffer
		jz	edit_clear

		load	#'?',R0			; none of the above
		load	#CONOUT,R1
		trap				; show error
		jmp	edit_loop		; and continue loop


edit_exit:	call	crlf
		jmp	main

edit_save:	; save file to tape from edit buffer
		load	@USERSTART,IX
		load	BUFFEREND,IY
		call	tape_write
		jmp	edit_loop


edit_read:	; read a file from tape to edit buffer
		call	crlf
		call	tape_findf
		cmp	#0,R0
		jz	e_read1
		jmp	edit_loop

e_read1:	; copy file from tape
		push	IX
		push	R4
		call	filluser	; 1st clear the edit buffer
		pop	R4
		pop	IX
e_read1a: 
		load	#TAPE,R1
		load	#$8000,R0
		trap			; read byte from tape
		swap	R0
		load	R0,R3		; move MSB
		load	#$8000,R0
		trap
		or	R0,R3		; merge bytes
		load	R3,(IX)		; save to memory
		inc	IX
		dec	R4		; filesize counter
		jnz	e_read1a	; continue

		; file read in
		load	IX,BUFFEREND
		load	#TAPE,R1
		load	#$2000,R0
		trap			; close the tape
		jmp	edit_loop




;*** HELP ***
edithelp_msg:	DB "Editor_command_summary" DB CR DB LF
		DB "x_____Exit" DB CR DB LF
		DB "?_____Show_this_message" DB CR DB LF
		DB "a_____Append_text_to_the_end_of_the_buffer" DB CR DB LF
		DB "i[n]__Insert_text_at_start_of_line_n" DB CR DB LF
		DB "d[n]__Delete_line_n" DB CR DB LF
		DB "l_____List_the_buffer" DB CR DB LF
		DB "m_____Show_memory_pointers" DB CR DB LF
		DB "w_____Write_file_to_tape_device" DB CR DB LF
		DB "r_____Read_a_file_from_tape_device" DB CR DB LF
		DB "ESC_stops_current_action_and_returns_to_command_prompt" DB CR DB LF
		DB EOL

edit_help:	; show command summary
		load	@edithelp_msg,IX
		call	printf
		jmp	edit_loop


;*** MEM ***
edit_mem:	call	crlf
		load 	@e_memmsg1,IX
		call	printf
		load	@USERSTART,IX
		call	edit_mem1
		call	crlf
		load	@e_memmsg2,IX
		call	printf
		load	BUFFEREND,IX
		call	edit_mem1
		call	crlf
		jmp	edit_loop

edit_mem1:	; show value of IX
		push	IX
		pop	R2		; get LSB
		pop	R0		; get MSB
		call	printhex	; show LSB
		load	R2,R0		; put LSB in buffer
		call	printhex	; show lsb
		ret

e_memmsg1:	DB "Current_buffer_start_$" DB EOL
e_memmsg2:	DB "Current_buffer_end___$" DB EOL




;*** APPEND ***
edit_append:	; get a line, append to the edit buffer

		load	BUFFEREND,IY
edit_append1:	call	crlf
		load	#CONOUT,R1
		load	#':',R0
		trap				; show cursor

		call	readline

		cmp	#ESC,R0
		jz	edit_appendEnd		; esc? back to command mode

		load	@BUFFER,IX
edit_app1:	load	(IX),(IY)		; save buffer chars
		inc	IY

		cmp	#EOL,(IX)
		jz	edit_append1		; stop insert on EOL

		inc	IX
		jmp	edit_app1		; continue filling buffer from readline buffer

		
edit_appendEnd:	load	IY,BUFFEREND
		jmp	edit_loop





;*** LIST ***
edit_list:	; list the buffer
		load	#24,R3			; screen length counter
		load	@USERSTART,IX
		load	#0,R7			; current line #

edit_l0:	call	crlf
		inc	R7			; inc line number
		load	R7,R0
		call	printdec		; show decimal line number
		load	#$20,R0			; show space
		trap

edit_l1:	load	(IX),R0
		cmp	#EOF,R0
		jz	edit_listend
		cmp	#EOL,R0
		jnz	edit_l2			; show crlf
		;***
		dec	R3			; line counter - at 24 pause
		jnz	edit_l1a
		load	#24,R3			; reload counter
		call	crlf			; pause the screen after 24 lines
		push	IX
		load	@edit_continuemsg,IX
		call	printf
		call	readline		; get cr
		cmp	#ESC,R0
		jz	edit_loop
		pop	IX			; and restore pointer
		;***
edit_l1a:	inc	IX
		jmp	edit_l0

edit_l2:	load	#CONOUT,R1
		trap
		inc	IX
		jmp	edit_l1			; continue

edit_listend:	load	#CR,R0			; delete the last line number
		trap
		load	@edit_blankline,IX
		call	printf
		jmp	edit_loop

edit_blankline: DB "__________________________________" DB EOL
edit_continuemsg:  DB "Press_<cr>_to_continue" DB EOL

;*** CLEAR ***

edit_clear:	; clear the buffer
		
		call	crlf
		load	@edit_clrMSG,IX		; clear the buffer message
		call	printf
		call	readline
		load	@BUFFER,IX
		cmp	#'y',(IX)		; yes?
		jnz	edit_loop

		; clear the buffer
		call	crlf
		call	filluser
		load	@edit_clr_DONE,IX
		call	printf
		load	@USERSTART,IY
		load	IY,BUFFEREND		; set pointers
		jmp	edit_loop

edit_clrMSG:	DB "Clearing_the_buffer._Are_you_sure_(y/n)_" DB EOL
edit_clr_DONE:	DB "Buffer_cleared." DB EOL



;*** DELETE ***

edit_delete:	; delete a line
		
		load	@BUFFER,IX	; get the line number to delete
ed_d1:		inc	IX		; point past the 'd'
		cmp	#EOL,(IX)
		jz	ed_d2
		load	(IX),R0
		dec	IX
		load	R0,(IX)		; shift the number over by 1
		inc	IX
		jmp	ed_d1		; continue until EOL

ed_d2:		load	(IX),R0		; get EOL char
		dec	IX
		load	R0,(IX)		; save past last number

		call	d2h_entry	; convert decimal, return in R0
		push	R0
		pop	R3		; save line # in R3
		load	#1,R2		; R2 is the running counter
		
		load	@USERSTART,IX	; point to start of memory

		cmp	R2,R3		; test if line #'s match
		jz	ed_d5

ed_d3:		cmp	#EOF,(IX)
		jz	edit_loop	; nothing to delete
		cmp	#EOL,(IX)
		jz	ed_d4
		inc	IX
		jmp	ed_d3

ed_d4:		; at EOL - add 1 to R2 (running counter), see if match
		inc	R2
		cmp	R2,R3
		jz	ed_d5
		inc	IX
		jmp	ed_d3		; continue looping

ed_d5:		; line numbers match
		;inc	IX		; point past the EOL
		push	IX		; save location
		pop	IY		; and load IY with upper index
		
ed_d6:		inc	IY
		cmp	#EOL,(IY)
		jnz	ed_d6		; count up to next EOL

		; IY points to next EOL
ed_d7:		cmp	#1,R3
		jnz	ed_d7a
		inc	IY	
		;
ed_d7a:		load	(IY),(IX)	; now shift everything down until IX=EOF
		cmp	#EOF,(IX)
		jz	ed_d8
		inc	IX
		inc	IY
		jmp	ed_d7a

ed_d8:		; done
		load	IX,BUFFEREND
		jmp	edit_loop




;*** INSERT ***

edit_insert:	; insert a line at position n, stop when ESC pressed

		load    @BUFFER,IX      ; get the line number to insert
ed_i1:          inc     IX              ; point past the 'i'
                cmp     #EOL,(IX)
                jz      ed_i2
                load    (IX),R0
                dec     IX
                load    R0,(IX)         ; shift the number over by 1
                inc     IX
                jmp     ed_i1           ; continue until EOL

ed_i2:          load    (IX),R0         ; get EOL char
                dec     IX
                load    R0,(IX)         ; save past last number

                call    d2h_entry       ; convert decimal, return in R0
                push    R0
                pop     R3              ; save line # in R3
                load    #1,R2           ; R2 is the running counter

                load    @USERSTART,IX   ; point to start of memory

                cmp     R2,R3           ; test if line #'s match
                jz      ed_i5

ed_i3:          cmp     #EOF,(IX)
                jz      edit_loop       ; nothing to delete
                cmp     #EOL,(IX)
                jz      ed_i4
                inc     IX
                jmp     ed_i3

ed_i4:          ; at EOL - add 1 to R2 (running counter), see if match
                inc     R2
                cmp     R2,R3
                jz      ed_i5
                inc     IX
                jmp     ed_i3           ; continue looping

ed_i5:          ; line numbers match ********
		cmp	#1,R3
		jnz	ed_i5a
		dec	IX

ed_i5a:         inc     IX              ; point past the EOL
                push    IX              ; save insert position
		load	IX,InsertPos

ed_insLoop:		;***
		call 	crlf		; get a line of input 
		load	#CONOUT,R1
		load	#':',R0
		trap			; show insert cursor
		call	readline
		cmp	#ESC,R0
		jz	ed_insExit	; exit on escape
		;***

		; see how long the buffer is
		load	@BUFFER,IX
		load	#0,R3
ed_i6:		cmp	#EOL,(IX)
		jz	ed_i7
		inc	IX
		inc	R3
		jmp	ed_i6		; loop and count

ed_i7:		; buffer size in R3
		inc	R3		; *****
		load	BUFFEREND,IY	; find size of chars to move
		load	InsertPos,IX
		sub	IX,IY		; IY holds char count to mode
		push	IY
		pop	R4		; now R4 holds char count
		pop	R0		; throw away MSB
		load	BUFFEREND,IY	; point to end
		add	R3,IY		; get offset
		load	BUFFEREND,IX
		load	IY,BUFFEREND	; save new bufferend

		; now shift buffer up by R3 chars (insert length)
		; count down by R4
		inc	R4		;*********
ed_i8:		load	(IX),(IY)	; shift up
		dec	IX
		dec	IY
		dec	R4		; R4 is the number of chars to shift
		jnz	ed_i8

		; all chars shifted
		load	@BUFFER,IX	; point to readline buffer
		load	InsertPos,IY
		; IY points to insert point
ed_i9:		load	(IX),(IY)
		inc	IX
		inc	IY
		cmp	#EOL,(IX)
		jnz	ed_i9		; loop loading all chars
		load	(IX),(IY)	; save the terminating EOL
		inc	IY		; point past term EOL
		load	IY,InsertPos	; save the new insert point	
		jmp	ed_insLoop	;*** 
		; done
ed_insExit:	load	BUFFEREND,IY
		jmp	edit_loop



;*** PRINT ***

ep_STARTPOS:	DS	6	; start and end for printing
ep_ENDPOS:	DS	6	; uses numbers after p command
ep_TEMP:	DS	6	; temp storage	

edit_print:	; print a range of lines

		load	@BUFFER,IX
		inc	IX		; point past 'p'

		cmp	#EOL,(IX)	; just EOL
		jz	ed_print	; print from start to end

		; get a number. end char is EOL or comma
		; ie p1,20[EOL]  p1[EOL]  p1,[EOL] p,20[EOL]

		load	#5,R3		; initialize TEMP w/0
		load	@ep_TEMP,IY
ed_p0a:		load	#0,(IY)
		inc	IY
		dec	R3
		jnz	ed_p0a
		load	#EOL,(IY)	; save EOL at end
		dec	IY		; 1st slot avail

		; retrieve 1st number from BUFFER
ed_p1:		cmp	#$2c,(IX)	; $2C is a comma
		jz	ed_p2
		cmp	#EOL,(IX)
		jz	ed_p4
		load	(IX),(IY)	; save number it TEMP
		dec	IY		; point to next higher pos
		inc	IX
		jmp	ed_p1

ed_p2:		; got a comma
		; save TEMP in STARTPOS
		
		push 	IX		; save BUFFER pos

		; position IX
		load	@ep_STARTPOS,IX
		load	#5,R3
ed_p21:		inc	IX
		dec	R3
		jnz	ed_p21

ed_p2a:		load	(IY),(IX)	; IY points at MSB in TEMP
		dec	IX
		inc	IY
		cmp	#EOL,(IY)
		jnz	ed_p2a

		; clear TEMP, STARTPOS holds initial number
		load	#5,R3
		load	@ep_TEMP,IY
ed_p2b:		load	#0,(IY)
		inc	IY
		dec	R3
		jnz	ed_p2b
		load	#EOL,(IY)	; EOL at end of TEMP
		dec	IY		; 1st slot avail

		; saved start pos. now get end pos
		pop	IX		; restore IX to BUFFER pos at comma
		inc	IX		; point to after comma
ed_p2c:		cmp	#EOL,(IX)
		jz	ed_p4		; got EOL
		load	(IX),(IY)
		dec	IY
		inc	IX
		jmp	ed_p2c		; continue
		
ed_p4:		
ed_print:	halt	


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


;*** BASIC INTERPRETER ***



;*** VARIABLE STORAGE ***
NUMVAR:		DS	26		; 26 (A-Z) 16 bit numeric variables
STRING: 	DS	80		; 80 char string placeholder
CURLINE: 	DS	1		; current line number in binary
FOREND:     DS  1       ; end value of FOR/NEXT (start val in var a-z)
FORADDR:    DS  2       ; address /IY/ of instruction after FOR command
BASETEMPIY:  DS  2       ; temp storage of line counter


;*** KEYWORDS ***
basic_rem:	    DB "rem"	DB EOL
basic_print:	DB "print"	DB EOL
basic_input:	DB "input"	DB EOL
basic_end:	    DB "end"	DB EOL
basic_let:	    DB "let"	DB EOL
basic_goto:	    DB "goto"	DB EOL
basic_if:       DB "if"     DB EOL
basic_then:     DB "then"   DB EOL
basic_for:      DB "for"    DB EOL
basic_next:     DB "next"   DB EOL


;*** ROUTINES ***


basicQuit:	;
		    jmp	edit



;*************
;*** isnum ***
;*************
isnum:		; char in R0, return ff is not a number, or number in R0
		    cmp	    #'0',R0
		    jc	    isnum_0		; less than 0
		    cmp	    #$3a,R0
		    jnc	    isnum_0		; greater than 0
		    clr	    CY
		    ret		; return w/number in R0
isnum_0:	load	#$ff,R0
		    ret





;*************
;*** isvar ***
;*************
isvar:		; char in R0, return ff if not a-z (inclusive), or char in R0
		    cmp	    #'a',R0
		    jc	    isvar_0		; less than 'a'
		    cmp	    #$7b,R0
		    jnc	    isvar_0		; greated than 'z'
		    clr	    CY
		    ret
isvar_0:	load	#$ff,R0
		    ret




;**************
;*** clrbuf ***
;**************
clrbuf:		; clear the BUFFER
		push	IX
		push	R0
		load	@BUFFER,IX
		load	#10,R0
clrbuf1:	load	#0,(IX)
		inc	IX
		dec	R0
		jnz	clrbuf1
		pop	R0
		pop	IX
		ret




;**************
;*** clrvar ***
;**************
clrvar:		; clear all numeric vars
		load	@NUMVAR,IX
		load	#26,R0
clrvar1:	load	#0,(IX)
		inc	IX
		dec	R0
		jnz	clrvar1
		ret





;****************
;*** TESTEXPR ***
;****************
testexpr:	; IY points to the start of an expression
		call	clrbuf
		load	#0,R0
		load	#0,R2
		load	#0,R3
		load	@BUFFER,IX

		; test char in (IY)
test_ex1:	
        cmp	#$20,(IY)	; test for space
		jz	test_Math	; end on space (and EOL)
        cmp #$2c,(IY)   ; comma (used in PRINT)
        jz  test_Math
        cmp #$3b,(IY)   ; semi-colon (used in PRINT)
        jz  test_Math
		cmp	#EOL,(IY)
		jz	test_Math	; tests final char before returning
		
		load	(IY),R0		
		call	isnum
		cmp	#$ff,R0
		jnz	test_exNum	; it's a number (0-9)

		load	(IY),R0
		call	isvar
		cmp	#$ff,R0
		jnz	test_exLet	; it's a letter (a-z)

		load	(IY),R2	; it's a math symbol - save it
        	
test_ex0:	
        inc	IY
		jmp	test_ex1	; must be a sign - save in R2, continue
		
test_exNum:	
        load	(IY),R0		; get number
		load	R0,(IX)		; put in BUFFER
		inc	IX		; point to next buffer slot
		inc	IY		; point to next char
 		load	(IY),R0
		call	isnum		; test
		cmp	#$ff,R0
		jnz	test_exNum	; if num, continue loading
		; not a number - convert number from ascii to binary
		call	d2h_entry	; convert BUFFER to binary number, in R0
		call	clrbuf		; clear the buffer
		load	@BUFFER,IX	; reset the buffer pointer
test_sign:	
        cmp	#0,R2		; test if previous expression is (+ - * / ^)
		jnz	test_Math	; there was a prior expression - do calc on current and prior #
		; R2=0, no expression - save R0 in R3
		load	R0,R3
		jmp	test_ex1	; test next char

test_end:	
        load	R3,R0		; reached EOL and no current pending math expression
		ret
		

test_exLet:	; (IY) is a var (letter a-z). Get value into R3
		load	(IY),R0
		clr	CY
		sub	#'a',R0         ; change to number from 0-25 (a-z)
		push	IX
		load	@NUMVAR,IX  ; point to start of var location
		add	R0,IX           ; add offset
		load	(IX),R0     ; load value of var in R0
		pop	IX
		inc	IY              ; point to next char in buffer
		jmp	test_sign       ; done


test_Math:	    ; R2 holds a math symbol - test and apply it
        cmp	#'+',R2
		jz	test_mathAdd
		cmp	#'-',R2
		jz	test_mathSub
		cmp	#'*',R2
		jz	test_mathMul
		cmp	#'/',R2
		jz	test_mathDiv
		cmp	#'^',R2
		jz	test_mathExp
		cmp	#0,R2		; usually when EOL is in (IY)
		jz	test_end
        cmp #$2c,R2     ; comma, used in PRINT
        jz  test_end
        cmp #$3b,R2     ; semi-colon, used in PRINT
        jz  test_end
		jmp	syntax

test_mathAdd:	
        add	R0,R3
		load	#0,R2
		cmp	#EOL,(IY)
		jz	test_end
		jmp	test_ex1

test_mathSub:	
        sub	R0,R3
		load	#0,R2
		cmp	#EOL,(IY)
		jz	test_end
		jmp	test_ex1

test_mathMul:	
        mul	R0,R3
		load	#0,R2
		cmp	#EOL,(IY)
		jz	test_end
		jmp	test_ex1

test_mathDiv:	
        div	R0,R3
		load	#0,R2
		cmp	#EOL,(IY)
		jz	test_end
		jmp	test_ex1

test_mathExp:	; ^ Exponent: multiply (R3*R3) * (R0-1)
		load	R3,R4		; get base number
		dec	R0		        ; exp=exp-1 for right answer
test_mExp:	
        mul	R4,R3
		dec	R0
		jnz	test_mExp
		load	#0,R4
		cmp	#EOL,(IY)
		jz	test_end
		jmp	test_ex1

;*** End of Expression Tests ***
;*******************************




;*************
;*** BASIC ***
;*************
basic:	; start of BASIC interpreter

	call	crlf	
	call	clrvar
	load	@USERSTART,IY	; start of edit buffer
	dec	IY


;*** BASIC LOOP ***
basiccmdloop:
	inc	IY
	cmp	#EOF,(IY)	; end of buffer - done
	jz	basicQuit

	cmp	#EOL,(IY)
	jz	basiccmdloop	; ignore <cr>'s

	cmp	#$20,(IY)
	jz	basiccmdloop	; ignore spaces

	load	(IY),R0
	call	isnum		; test if number, $ff if not
	cmp	#$ff,R0
	jnz	basiccmdloop


	; now pointing to a non-numeric, non-space character
	; test keywords
    load    IY,BASETEMPIY

	load	@basic_rem,IX       ; REM keyword
	call	cstrcmp
	cmp	    #0,R0
	jz	    basicRem 

    
    load    BASETEMPIY,IY
	load	@basic_let,IX       ; LET keyword 
	call	cstrcmp
	cmp	    #0,R0
	jz	    basicLet

    
    load    BASETEMPIY,IY
    load    @basic_for,IX       ; FOR keyword
    call    cstrcmp
    cmp     #0,R0
    jz      basicFor

    
    load    BASETEMPIY,IY
    load    @basic_next,IX      ; NEXT keyword
    call    cstrcmp
    cmp     #0,R0
    jz      basicNext

    load    BASETEMPIY,IY
    load    @basic_if,IX        ; IF keyword
    call    cstrcmp
    cmp     #0,R0
    jz      basicIf


    load    BASETEMPIY,IY
    load    @basic_then,IX      ; THEN keyword (dummy)
    call    cstrcmp
    cmp     #0,R0
    jz      basicThen

    load    BASETEMPIY,IY
	load	@basic_print,IX		; PRINT keyword
	call	cstrcmp
	cmp	    #0,R0
	jz	    basicPrint


    load    BASETEMPIY,IY
    load    @basic_input,IX     ; INPUT keyword
    call    cstrcmp
    cmp     #0,R0
    jz      basicInput


    load    BASETEMPIY,IY
	load	@basic_goto,IX		; GOTO keyword
	call	cstrcmp
	cmp	    #0,R0
	jz	    basicGoto
	

    load    BASETEMPIY,IY
	load	@basic_end,IX		; END keyword
	call	cstrcmp
	cmp	    #0,R0
	jz	    basicEnd

    load    BASETEMPIY,IY
	jmp	    basiccmdloop

;*** END OF BASIC LOOP ***
;*************************


;*** IF ***
basicIf:    ; process IF keyword
            ; examples:  if a=10 then print a
            ; if c=b end
            ; if a>25*10+a then goto 100


            load    #0,R5
            load    #0,R6           ; init storage to 0
            load    #0,R7
            
basicIf0:            
            cmp     #$20,(IY)
            jz      basIf1

            cmp     #EOF,(IY)
            jz      basicQuit

            cmp     #EOL,(IY)
            jz      basiccmdloop

            ; test the left side of the equasion
            load    (IY),R0
            call    isvar
            cmp     #$ff,R0
            jnz     basIf2          ; is a variable      
            
            jmp     basIf1          ; ignore the rest

basIf1:     inc     IY
            jmp     basicIf0

basIf2:     ; variable in R0
            clr     CY
            sub     #'a',R0
            load    @NUMVAR,IX
            add     R0,IX
            load    (IX),R5         ; value of var in R5
            ; next char must be '=', '<', '>'
            inc     IY
            cmp     #'=',(IY)
            jz      basIf3      ; equil test
            cmp     #'<',(IY)
            jz      basIf3      ; less than test
            cmp     #'>',(IY)
            jz      basIf3      ; greater than
            jmp     syntax      ; all else is error

basIf3:     load    (IY),R6       ; save test char
            
            ; now get a value from expr
            inc     IY
            call    testexpr    ; return value in R0
            load    R0,R7       ; left test in R5, right test in R7
            ; test value in R5
            cmp     #'=',R6
            jz      basIf_eq    ; test if R5 = R7
            cmp     #'<',R6
            jz      basIf_lt    ; test if R5 < R7
            cmp     #'>',R6
            jz      basIf_gt    ; test if R5 > R7
            ; nothing else
            jmp     syntax

basIf_eq:   cmp     R5,R7
            jz      basIf_true
            jmp     basIf_false

basIf_lt:   cmp     R5,R7
            jz      basIf_false     ; test eq 1st
            jnc     basIf_true
            jmp     basIf_false

basIf_gt:   cmp     R5,R7
            jc     basIf_true
            jmp     basIf_false

basIf_true:     ; comparison is true. exec inline statement
            jmp     basiccmdloop


basIf_false:    ; comparison is false. go to EOL for next line
            inc     IY          ; loop thru EOL
            cmp     #EOL,(IY)
            jnz     basIf_false
            jmp     basiccmdloop



;****** THEN ******
basicThen:  ; process THEN keyword
        
        ; ignore the keyword since the actual keyword
        ; follows anyway if true, or skip to EOL if false
        jmp     basiccmdloop






;******* FOR *******
basicFor:   ; process the FOR keyword
            ; example: for n=1 to 100

        cmp     #$20,(IY)
        jz      basFor1

        cmp     #EOF,(IY)
        jz      basicQuit

        cmp     #EOL,(IY)
        jz      basFor2

        load    (IY),R0
        call    isvar
        cmp     #$ff,R0     ; variable?
        jz      syntax      ; no. show syntax error

        clr     CY
        sub     #'a',R0     ; get abs number for var
        load    @NUMVAR,IX
        add     R0,IX       ; point to variable number
        push    IX          ; save the location

        inc     IY          ; point to '='
        cmp     #'=',(IY)
        jnz     basForex    ; not an '=', show error

        inc     IY
        call    testexpr    ; get expression value in R0
        pop     IX
        load    R0,(IX)     ; store number in variable

basFor0:
        inc     IY
        cmp     #$20,(IY)
        jz      basFor0     ; skip spaces

        cmp     #'t',(IY)   ; look for 'to'
        jnz     syntax
        inc     IY
        cmp     #'o',(IY)
        jnz     syntax
basFor0a:
        inc     IY
        cmp     #$20,(IY)
        jz      basFor0a    ; after 'to', skip spaces

        call    testexpr    ; get the ending value in R0
        load    R0,FOREND   ; save in mem

        jmp     basicFor    ; continue to EOL/EOF

basFor1:    
        inc     IY
        jmp     basicFor        


basFor2:
        inc     IY
        load    IY,FORADDR  ; save address to return to of instr after
                            ; the for line
        jmp     basiccmdloop

basForex:
        pop     IX
        jmp     syntax



;******* NEXT *******
basicNext:      ; get variable (next n), increment it, compare to FOREND
                ; if var < FOREND load IY to FORADDR and continue
                ; else go to EOL concontinue

        cmp     #$20,(IY)
        jz      basNext1

        cmp     #EOL,(IY)
        jz      basiccmdloop

        load    (IY),R0         ; char is a variable
        call    isvar
        cmp     #$ff,R0
        jz      basNext1        ; no - continue to EOL

        clr     CY
        sub     #'a',R0
        load    @NUMVAR,IX
        add     R0,IX           ; point to variable
        load    (IX),R0         ; get that var
        inc     R0
        load    R0,(IX)         ; add 1 and save it

        load    FOREND,R1       ; get test value
        inc     R1              ; equil test when FOREND+1
        cmp     R0,R1           ; else it stops at FOREND-1
        jnz     basNext2        ; not yet - loop back

basNx1: ; at end of loop
        inc     IY
        cmp     #EOL,(IY)
        jnz     basNx1
        jmp     basiccmdloop       ; loop until EOL


basNext1:       
        inc     IY
        jmp     basicNext


basNext2:
        load    FORADDR,IY
        jmp     basiccmdloop




;******* PRINT *********
basicPrint:	; process PRINT keyword
            ; examples:   print a,b;c
            ; print "a=";a,"b=";c
            ; print 1+2+3+4+5, a+b*10

		cmp	#$20,(IY)
		jz	basP5		; skip spaces		

		cmp	#EOF,(IY)   ; stop at end of file
		jz	basP7

		cmp	#$2c,(IY)	; comma (3 spaces)
		jz	basP6

		cmp	#$3b,(IY)	; semi-colon (no spaces)
		jz	basP5

		cmp	#'"',(IY)	; double quotes
		jz	basP1

		cmp	#EOL,(IY)	; end of line (cr)
		jz	basP7

		load	(IY),R0		; test for letters a-z inclusive
		call	isvar
		cmp	    #$ff,R0
		jnz	    basP3       ; yes, it's a var

		load	(IY),R0
		call	isnum		; test (IY) for number
		cmp	    #$ff,R0
		jz	    basP5		; nope
		push	IX
		call	testexpr	; yep - processes as an expression, return an EOL
		push	IY
		call	printdec	; R0 holds result of expression
		pop	    IY		
		pop	    IX
		;jmp	    basP7
        jmp     basicPrint

basP5:	; found space or semicolon	
        inc	    IY
		jmp	    basicPrint	; back to loop 

basP6:		; found a comma - print 3 spaces
		load	#CONOUT,R1
		load	#$20,R0
		trap
		load	#$20,R0
		trap
		load	#$20,R0
		trap
		jmp	    basP5

basP7:	; at end of line w/print statement	
        call	crlf
		jmp	    basiccmdloop	



		; found start quotes
basP1:		
        inc	IY		; get char after quotes
		cmp	#'"',(IY)	; look for end quotes
		jz	basP2		; found it - 
		load	#CONOUT,R1
		load	(IY),R0
		trap
		jmp	basP1		; print everything between quotes		
basP2:		; found end quotes
		jmp	basP5



basP3:	; found a letter (variable) - print value

		; (IY) is a var - see if char after is +-*/
		inc	IY          ; look at char after variable
		cmp	#'+',(IY)   ; but 1st test if it's part of an expression
		jz	basP3x
		cmp	#'-',(IY)
		jz	basP3x
		cmp	#'*',(IY)
		jz	basP3x
		cmp	#'/',(IY)
		jz	basP3x
		cmp	#'^',(IY)
		jz	basP3x
		jmp	basP3a		    ; no math in print, just show var

basP3x:		
        dec	IY		; yes - math after var, restore position (IY)
		push	IX
		call	testexpr    ; yep - processes as an expression, return an EOL
		push	IY
		call	printdec    ; R0 holds result of expression
		pop	    IY
		pop	    IX
        cmp #EOL,(IY)       ; coming back from expr test, point to:
        jz      basP7       ; EOL - do line feed
        cmp #$2c, (IY)      ; comma - do 3 spaces
        jz      basicPrint
        cmp #$3b, (IY)      ; semi-colon - no nothing
        jz      basicPrint
        inc     IY          ; else get next char
        jmp     basicPrint  ; and continue

basP3a:	    ; no math after var	
        dec	    IY		    ; restore (from test above in basP3)
		load	(IY),R0		; get the variable
		clr	    CY
		sub	    #'a',R0		; now a value between 0 and 25
		load	@NUMVAR,IX
		clr	    CY
		add	    R0,IX		; point to offset
		load	(IX),R0
		push	IY
 		call	printdec	; print the number
		pop	    IY
		jmp	    basP5		; loop


;********** INPUT *********
basicInput:     ; process INPUT keyword

            cmp     #$20,(IY)
            jz      basIn1

            cmp     #EOF,(IY)
            jz      basicQuit

            cmp     #EOL,(IY)
            jz      basInx          ; print crlf and get next cmd

            cmp     #$2c,(IY)       ; comma - print 3 spaces
            jz      basIn3

            cmp     #'"',(IY)       ; print something
            jz      basIn2

            load    (IY),R0
            call    isvar
            cmp     #$ff,R0
            jz      basIn1          ; not a variable, ignore it
            ; char is a variable - input a decimal #
            load    @NUMVAR,IX
            clr     CY
            sub     #'a',R0         ; get abs value 
            add R0,IX               ; point to offset
            ; IX holds address to var
            push    IX
            call    dec2hex
            pop     IX              ; restore adderss
            load    R0,(IX)         ; save number in var
            jmp     basIn1


basIn1:     inc     IY
            jmp     basicInput        
        
basIn2:     ; print all between quotes
            inc     IY
            cmp     #'"',(IY)
            jz      basIn1          ; back to loop
            load    #CONOUT,R1
            load    (IY),R0
            trap    ; print char
            jmp     basIn2        

basIn3:     ; got a comma, print 3 spaces
            load    #CONOUT,R1
            load    #$20,R0
            trap
            load    #$20,R0
            trap
            load    #$20,R0
            trap
            jmp     basIn1


basInx:     call    crlf
            jmp     basiccmdloop


;********** REM ************
remMsg:		DB "REM" DB CR DB LF DB EOL

basicRem:	; process REM keyword

basR1:		
            inc	    IY
            cmp     #EOF,(IY)
            jz      basicQuit  
		    cmp	    #EOL,(IY)
		    jnz	    basR1
		    jmp	    basiccmdloop



		
;********** END *************
endMsg:		DB "END" DB CR DB LF DB EOL
basicEnd:	; process END keyword

		load	@endMsg,IX
		call	printf
		jmp	basicQuit





;***** GOTO ******

basicGoto:	; goto line number

		; get the line number first
		call	clrbuf
		load	@BUFFER,IX

basicGoto0:	cmp	#$20,(IY)
		jz	basicGoto1	; skip spaces

		cmp	#EOL,(IY)
		jz	basicGoto0a	; end of line, line number in BUFFER

		load	(IY),R0
		call	isnum
		cmp	#$ff,R0
		jz	basicGoto1	; skip non-numeric chars
		; is a number
		load	R0,(IX)
		inc	IX		; save number on buffer
		inc	IY
		jmp	basicGoto0


basicGoto0a:	; convert number in BUFFER to binary number
		call	d2h_entry	; convert number
		load	R0,CURLINE	; save it


		; now search for the line number in the file
		load	@USERSTART,IY
		call	clrbuf
		load	@BUFFER,IX	; storage for line number

basicGoto0b:	cmp	#$20,(IY)	; test space
		jz	basicGoto1a	; skip initial space

basicGoto0c:	cmp	#EOF,(IY)
		jz	basGo_badline

		load	(IY),R0
		call	isnum
		cmp	#$ff,R0
		jz	basicGoto1a	; not a number
		load	R0,(IX)
		inc	IX
		inc	IY		; is a num - save, loop until space
		cmp	#$20,(IY)	; space after number
		jz	basicGoto0d
		jmp	basicGoto0c

basicGoto0d:	; space after number - convert number in BUFFER, compare to CURLINE
		call	d2h_entry	; convert, number in R0
		cmp	CURLINE,R0
		jz	basicGoto0e
		; not a match - try next line
		call	clrbuf
		load	@BUFFER,IX	; clear buffer, reset pointers for number storage
basgo_skip:	inc	IY
		cmp	#EOF,(IY)
		jz	basGo_badline	; stop at end of file
		cmp	#EOL,(IY)
		jnz	basgo_skip	; blow past until EOL
		jmp	basicGoto0b	; back to the loop

basicGoto0e:	 ; line numbers match - jump to address in IY to continue
		dec	IY 	; (IY is incremented when we jump)
		jmp	basiccmdloop
		



basicGoto1:	inc	IY
		jmp	basicGoto0

basicGoto1a:	inc	IY
		jmp	basicGoto0b


bgoMsg1:	DB "Bad_line_number_after_GOTO" DB EOL
basGo_badline:	; bad line number - show error and abort
		load	@bgoMsg1,IX
		call	printf
		call	crlf
		jmp	basicQuit




;******* LET *************
letMsg:		DB "LET" DB CR DB LF DB EOL
basicLet:
		; assign a variable

		cmp	#EOL,(IY)
		jz	basiccmdloop

		cmp	#EOF,(IY)
		jz	basicQuit

		cmp	#$20,(IY)
		jz	basL0		; skip spaces

		;cmp	#'a',(IY)	; test 'a' - 'z' inclusive
		;jc	basL0
		;cmp	#$7b,(IY)
		;jc	basL1

		load	(IY),R0
		call	isvar		; test if var a-z
		cmp	#$ff,R0
		jnz	basL1		; it's a variable

basL0:		
        inc	IY
		jmp	basicLet

basL1:		; it's a letter
		load	(IY),R2		; save letter
		clr	CY
		sub	#'a',R2		; now 0-25
		load	@NUMVAR,IX
		add	R2,IX		; now an offset to 0
		; IX holds address of variable

basL1a:		
        inc	IY		; skip past spaces
		cmp	#$20,(IY)
		jz	basL1a
		cmp	#EOL,(IY)
		jz	syntax
		cmp	#EOF,(IY)
		jz	syntax

		cmp	#'=',(IY)
		jnz	syntax		; not an =
basL1b:		
        inc	IY		; get value after =
		cmp	#$20,(IY)	; skip spaces etc
		jz	basL1b
		cmp	#EOL,(IY)
		jz	syntax
		cmp	#EOF,(IY)
		jz	syntax

		; now look at char after '='

		load	(IY),R0		; EXPRESSION TEST HERE: IY points to rest of expression
 		push	IX
		call	testexpr	; test expression, value returned in R0
		pop	IX
 		load	R0,(IX)		; save value in var
basL2:	
		cmp	#EOL,(IY)
		jz	basiccmdloop
		inc	IY
		jmp	basL2


;******** SYNTAX ERROR *********

synMsg:	DB "Syntax_Error" DB CR DB LF DB EOL
syntax:	
        call    crlf	
        load	@synMsg,IX
		call	printf
		call	crlf
		jmp	basicQuit		; program error - don't go any farther




;******** LOG ***********


log_msg1:   DB "Proto16_Startup" DB CR DB LF DB EOL
log_msg2:   DB "Unable_to_open_the_logfile" DB CR DB LF EOL

openlog:    ; initialize the logfile

            load    #6,R1       ; set the log writer
            load    #$1000,R0
            trap
            cmp     #$ff,R0     ; test for error
            jz      openlogFail

            load    @log_msg1,IX
writelog:
op_log0:    load    #6,R1
            load    (IX),R0
            cmp     #EOL,R0
            jz      op_log1
            or      #$2000,R0
            trap                ; write char to logfile
            inc     IX
            jmp     op_log0
op_log1:    ret


openlogFail:    ; could not open the logfile
            load    @log_msg2,IX
            call    printf
            ret



closelog:   load    #6,R1
            load    #$3000,R0   ; close the file
            trap
            ret


