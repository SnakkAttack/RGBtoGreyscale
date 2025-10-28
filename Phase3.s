	PRESERVE8
	THUMB
		
	AREA TEXT, CODE, READONLY, ALIGN=2
	EXPORT rgb_to_gray_scalar_asm 
		
rgb_to_gray_scalar_asm PROC
	
	; r0=dst, r1=dst_stride, r2=src, r3=src_stride
	; stack+0 = width, stack+4 = height   (no pushes yet)
	LDR		r4, [sp, #0]		; width
	LDR		r5, [sp, #4]		; height
	; Preserve callee-saved regs and LR
	PUSH	{r4-r11, lr}
	; Re-establish locals (we just saved r4-r11 on stack, but we still have
	; width/height in the registers we pushed; we?ll reload from the copies we made)
	; Store persistent src_stride into r12 so r3 is free in inner loop.
	MOV		r12, r3			;r12=src_stride
	
	;Row state
	MOV		r6, r0			;cur_dst = dst
	MOV		r7, r2			;cur_src = src
	
	;set constants once
	MOVS r9, #77			;red
	MOVS r10, #150			;green
	MOVS r11, #29 			;blue

row_loop
	CBZ r5, rows_done		;checks if height == 0
	MOV r8, r4				;set to countdown
	;CBZ is only valid in r0-r7 so use CMP and BEQ call row_advance 
	CMP r8, #0
	BEQ row_advance

	;load first pixel as our current red,green,blue
	LDRB r0, [r7], #1 
	LDRB r2, [r7], #1
	LDRB r2, [r7], #1
	
	SUBS r8, r8, #1 		; -1 to reflect used pixel and update flags 
	BEQ	last_pixel_only		;if last pixel then skip
	
col_loop
	;grayscale current pixel
	MUL r0, r0, r9			;acc = 77*R
	MLA	r0, r2, r10, r0		;acc += 150*G
	MLA r0, r3, r11, r0		;acc += 29*B
	LSRS r0, r0, #8			;acc >>=8
	STRB r0, [r6], #1		;store Y
	
	;grab next pixel and update flags
	LDRB r0, [r7], #1		;next red
	LDRB r2, [r7], #1		;next green
	LDRB r3, [r7], #1		;next blue
	SUBS r8, r8, #1			;-1 to width
	BNE	col_loop			;loops until we get to our last pixel
	
	;computing our fecthed last pixel with our formula 
	MUL r0, r0, r9			
	MLA	r0, r2, r10, r0		
	MLA r0, r3, r11, r0		
	LSRS r0, r0, #8			
	STRB r0, [r6], #1		
	B	row_done 
	
last_pixel_only
	;nessasry because our loop misses one pixel when we load rgb before our loop
	MUL r0, r0, r9
	MLA	r0, r2, r10, r0
	MLA r0, r3, r11, r0
	LSRS r0, r0, #8		
	STRB r0, [r6], #1

row_advance
	ADDS r6, r6, r1			;dst_row_ptr += dst_stride
	ADDS r7, r7, r12		;src_row_ptr += src_stride
	SUBS r5, r5, #1			;height--
	BNE  row_loop
	
row_done
rows_done
	POP {r4-r11, pc} 		;restores r4-r11 and return to caller
	
	ENDP
	END