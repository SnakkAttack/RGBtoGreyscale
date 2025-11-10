        ;------------------------------------------------------------
        ; gray_scalar.s  ? RGB -> Gray8 (scalar) for Cortex-M (Thumb-2)
        ; Keil ARMASM/ARMCLANG armasm syntax
        ;
        ; Signature (AAPCS-32):
        ;   void rgb_to_gray_scalar_asm(uint8_t* dst, int dst_stride,
        ;                               const uint8_t* src, int src_stride,
        ;                               int width, int height);
        ;
        ; Pixel formula (fixed-point Rec.601):
        ;   Y = (77*R + 150*G + 29*B) >> 8
        ;
        ; Registers (callee-saved r4-r11 used for loop state):
        ;   r0: dst                      (arg)
        ;   r1: dst_stride               (arg)
        ;   r2: src                      (arg)
        ;   r3: src_stride (moved to r12 at entry; r3 reused as temp)
        ;   r4: width
        ;   r5: height
        ;   r6: cur_dst (row pointer)
        ;   r7: cur_src (row pointer)
        ;   r8: y (row index)
        ;   r9: x (col index)
        ;   r10: dst_row_ptr (byte*)
        ;   r11: src_row_ptr (byte*)
        ;   r12: src_stride (persist)
        ;
        ; Notes:
        ; - Load width/height from stack BEFORE pushing any registers.
        ; - We never call other functions, so caller saved clobber is fine for r0-r3,r12.
        ;------------------------------------------------------------

        PRESERVE8
        THUMB

        AREA    |.text|, CODE, READONLY, ALIGN=2
        EXPORT  rgb_to_gray_scalar_asm

rgb_to_gray_scalar_asm PROC

        ; r0=dst, r1=dst_stride, r2=src, r3=src_stride
        ; stack+0 = width, stack+4 = height   (no pushes yet)
        LDR     r4, [sp, #0]          ; width
        LDR     r5, [sp, #4]          ; height

        ; Preserve callee-saved regs and LR
        PUSH    {r4-r11, lr}

        ; Re-establish locals (we just saved r4-r11 on stack, but we still have
        ; width/height in the registers we pushed; we?ll reload from the copies we made)
        ; Store persistent src_stride into r12 so r3 is free in inner loop.
        MOV     r12, r3               ; r12 = src_stride

        ; Row state
        MOV     r6, r0                ; cur_dst = dst
        MOV     r7, r2                ; cur_src = src
        MOVS    r8, #0                ; y = 0

row_loop
        CMP     r8, r5                ; y < height ?
        BGE     rows_done

        ; Column init
        MOVS    r9, #0                ; x = 0
        MOV     r10, r6               ; dst_row_ptr = cur_dst
        MOV     r11, r7               ; src_row_ptr = cur_src

col_loop
        CMP     r9, r4                ; x < width ?
        BGE     row_done

        ; Load RGB bytes (interleaved)
        LDRB    r0, [r11], #1         ; R
        LDRB    r1, [r11], #1         ; G
        LDRB    r2, [r11], #1         ; B

        ; acc = 77*R + 150*G + 29*B
        ; Use r3 as temp, r0 will hold the accumulator
        MOVS    r3, #77
        MUL     r0, r0, r3            ; r0 = 77*R

        MOVS    r3, #150
        MLA     r0, r1, r3, r0        ; r0 += 150*G

        MOVS    r3, #29
        MLA     r0, r2, r3, r0        ; r0 += 29*B

        LSRS    r0, r0, #8            ; >> 8

        STRB    r0, [r10], #1         ; store Y

        ADDS    r9, r9, #1            ; x++
        B       col_loop

row_done
        ; Advance to next row
        ADDS    r6, r6, r1            ; cur_dst += dst_stride
        ADDS    r7, r7, r12           ; cur_src += src_stride

        ADDS    r8, r8, #1            ; y++
        B       row_loop

rows_done
        POP     {r4-r11, pc}

        ENDP
        END