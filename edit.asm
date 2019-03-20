

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
