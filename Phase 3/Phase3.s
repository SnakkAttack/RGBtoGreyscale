        PRESERVE8
        THUMB

        AREA    TEXT, CODE, READONLY, ALIGN=2
        EXPORT  rgb_to_gray_scalar_asm

rgb_to_gray_scalar_asm PROC
        ; Load width/height before we change SP
        LDR     r4, [sp, #0]        ; width
        LDR     r5, [sp, #4]        ; height

        ; Preserve callee-saved regs and LR
        PUSH    {r4-r11, lr}

        ; Keep src_stride in r12 so r3 is free inside the loop
        MOV     r12, r3             ; r12 = src_stride

        ; Row state
        MOV     r6, r0              ; cur_dst = dst
        MOV     r7, r2              ; cur_src = src

        ; Set constants once
        MOVS    r9,  #77            ; red   coeff
        MOVS    r10, #150           ; green coeff
        MOVS    r11, #29            ; blue  coeff

row_loop
        CBZ     r5, rows_done       ; if (height == 0) break
        MOV     r8, r4              ; r8 = width (countdown)

        ; If width == 0, advance rows
        CMP     r8, #0
        BEQ     row_advance

        ; ---- Prefetch first pixel (R,G,B) ----
        LDRB    r0, [r7], #1        ; R
        LDRB    r2, [r7], #1        ; G
        LDRB    r3, [r7], #1        ; B   ; <-- FIXED (was overwriting r2)

        SUBS    r8, r8, #1          ; consumed 1 pixel
        BEQ     last_pixel_only     ; width == 1 case

col_loop
        ; Convert current pixel in r0/r2/r3
        MUL     r0, r0, r9          ; acc = 77*R
        MLA     r0, r2, r10, r0     ; acc += 150*G
        MLA     r0, r3, r11, r0     ; acc += 29*B
        LSRS    r0, r0, #8          ; acc >>= 8
        STRB    r0, [r6], #1        ; *dst++ = Y

        ; Load next pixel (prefetch)
        LDRB    r0, [r7], #1        ; next R
        LDRB    r2, [r7], #1        ; next G
        LDRB    r3, [r7], #1        ; next B

        SUBS    r8, r8, #1
        BNE     col_loop            ; loop until last pixel is prefetched

        ; Compute final fetched pixel
        MUL     r0, r0, r9
        MLA     r0, r2, r10, r0
        MLA     r0, r3, r11, r0
        LSRS    r0, r0, #8
        STRB    r0, [r6], #1
        B       row_done

last_pixel_only
        ; width == 1: we already have R,G,B in r0,r2,r3
        MUL     r0, r0, r9
        MLA     r0, r2, r10, r0
        MLA     r0, r3, r11, r0
        LSRS    r0, r0, #8
        STRB    r0, [r6], #1

row_advance
        ADDS    r6, r6, r1          ; dst_row_ptr += dst_stride
        ADDS    r7, r7, r12         ; src_row_ptr += src_stride
        SUBS    r5, r5, #1          ; height--
        BNE     row_loop

row_done
rows_done
        POP     {r4-r11, pc}        ; restore and return
        ENDP

        END
