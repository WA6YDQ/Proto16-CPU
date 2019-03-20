

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

