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
