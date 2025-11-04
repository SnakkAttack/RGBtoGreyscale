;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Part1.s - Shared Memory Communication
; Lab 5 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


	AREA Part1, CODE, READONLY
	EXPORT main
	EXPORT core1_task
	EXPORT core2_task
		
	PRESERVE8


core1_task
        PUSH    {LR}  ; save return address on the stack

        MOVS     R2, #20  ; R2 := 20 (producer value)
        STR     R2, [R1]   ; *(R1 + 0) = 10  sharedData[0] = 10
		
		DMB		;order data write before flag
		
		LDR		R3, [R1, #8]	;increment r1 flag by 8 
		ADDS	R3, R3, #1		;add 1 to r3
		STR		R3, [R1, #8]	;shareddata =r3
		
        POP     {LR} ; restore return address
        BX      LR  ; return

core2_task
        PUSH    {R4,LR}  ; save return address

spin
		LDR		R2, [R1, #8] ;load flag sharedData
		CMP		R2, #1		;compares flag to 1
		BCC		spin
		
		DMB		;sees flag>=1 order loads waiting
		
		LDR		R3, [R1,#0]		; x = sharedData[0]
		LSLS	R3, R3, #2		;multiply by 4
		STR		R3, [R1, #4] 	;sharedData[1] =x

        STR     R2, [R1, #12]     ; sharedData[3] = flag observed 

        POP     {R4,LR}     ; restore return address
        BX      LR    ; return

main
		PUSH	{LR}
		LDR		R1, =sharedData
		BL		core1_task   ; producer: sharedData[0] = 10
        LDR     R1, =sharedData  ; reload base address
        BL      core2_task    ; consumer: sharedData[1] = 20

		POP		{LR}
		BX		LR
		
		AREA	Part1_Data, DATA, READWRITE, ALIGN=2
		EXPORT  sharedData
			
sharedData
		DCD		0,0
			
		END
