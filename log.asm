


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


