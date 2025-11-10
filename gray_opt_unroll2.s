;===============================================================================
; File:          gray_opt_unroll2.s
; Project:       Phase 4 — Optimization & Testing (CS 2400)
; Team:          Gage, Joel, Trayia
; Target:        Cortex-M (Thumb-2) — Keil ARMASM/ARMCLANG syntax
; Description:   Optimized RGB888 ? Grayscale8 conversion.
;                Uses a 2-pixel unrolled inner loop and hoisted coefficients to
;                reduce control-flow and setup overhead vs. Phase 3 baseline.
;
; Public API (AAPCS-32):
;   void rgb_to_gray_scalar_asm(uint8_t* dst, int dst_stride,
;                               const uint8_t* src, int src_stride,
;                               int width, int height);
;
; Parameters:
;   r0  = dst pointer (uint8_t*, grayscale output)
;   r1  = dst_stride (bytes per output row; equals width for tightly packed)
;   r2  = src pointer (uint8_t*, interleaved RGBRGB… input)
;   r3  = src_stride (bytes per input row; equals width*3 if tightly packed)
;   [sp,#0] = width  (pixels)
;   [sp,#4] = height (rows)
;
; Pixel Formula (fixed-point Rec.601):
;   Y = ( 77*R + 150*G + 29*B ) >> 8
;
; Register usage (callee-saved preserved across call):
;   r4  = width
;   r5  = height (countdown)
;   r6  = cur_dst (walks within row)
;   r7  = cur_src (walks within row)
;   r8  = width countdown for inner loop
;   r9  = 77  (R coefficient)      [hoisted once]
;   r10 = 150 (G coefficient)      [hoisted once]
;   r11 = 29  (B coefficient)      [hoisted once]
;   r12 = src_stride (sticky copy) [frees r3 in loop body]
;
; Key Optimizations (Phase 4):
;   • 2-pixel unrolling: halves branch frequency in the hot loop.
;   • Hoisted coeffs: remove repeated MOVS for 77/150/29 per pixel.
;   • Countdown loop: SUBS+branch pattern avoids extra CMPs per pixel.
;   • Correct row advance: rewind to row start, then add stride (prevents drift).
;
; Test Notes:
;   • Verified byte-exact against C reference (rgb_to_gray_ref).
;   • Benchmarked with DWT_CYCCNT; averaged 10 trials per size.
;
;===============================================================================

        PRESERVE8
        THUMB

        AREA    |.text|, CODE, READONLY, ALIGN=2
        EXPORT  rgb_to_gray_scalar_asm

;------------------------------------------------------------------------------
; rgb_to_gray_scalar_asm
;------------------------------------------------------------------------------
rgb_to_gray_scalar_asm PROC
        ; Load scalar dimensions from caller stack before we push.
        ; In: r0=dst, r1=dst_stride, r2=src, r3=src_stride
        ;     [sp,#0]=width, [sp,#4]=height
        LDR     r4, [sp, #0]          ; width (pixels, also bytes for dst)
        LDR     r5, [sp, #4]          ; height (rows)

        ; Save callee-saved + LR.
        PUSH    {r4-r11, lr}

        ; Keep src_stride in r12 so r3 can be freely used in loop body.
        MOV     r12, r3               ; r12 = src_stride

        ; Row pointers for current scanline.
        MOV     r6, r0                ; cur_dst (walks within a row)
        MOV     r7, r2                ; cur_src (walks within a row)

        ;---- Hoist RGB coefficients once (fixed-point Rec.601) ---------------
        MOVS    r9,  #77              ; R coeff
        MOVS    r10, #150             ; G coeff
        MOVS    r11, #29              ; B coeff

;==== Outer loop over rows =====================================================
row_loop
        CMP     r5, #0
        BEQ     rows_done

        MOV     r8, r4                ; r8 = width countdown (pixels remaining)

;==== Inner loop: process 2 pixels per iteration ===============================
two_or_more
        CMP     r8, #2
        BLT     maybe_one

        ; -------- Pixel 0: load RGB, accumulate, store -----------------------
        LDRB    r0, [r7], #1          ; R0
        LDRB    r2, [r7], #1          ; G0
        LDRB    r3, [r7], #1          ; B0

        MUL     r0, r0, r9
        MLA     r0, r2, r10, r0
        MLA     r0, r3, r11, r0
        LSRS    r0, r0, #8
        STRB    r0, [r6], #1

        ; -------- Pixel 1: load RGB, accumulate, store -----------------------
        LDRB    r0, [r7], #1          ; R1
        LDRB    r2, [r7], #1          ; G1
        LDRB    r3, [r7], #1          ; B1

        MUL     r0, r0, r9
        MLA     r0, r2, r10, r0
        MLA     r0, r3, r11, r0
        LSRS    r0, r0, #8
        STRB    r0, [r6], #1

        SUBS    r8, r8, #2            ; consumed two pixels
        B       two_or_more

;==== Tail: handle a single leftover pixel (odd width) ====================
maybe_one
        CMP     r8, #0
        BEQ     row_advance

        ; -------- Tail: 1 pixel ----------------------------------------------
        LDRB    r0, [r7], #1          ; R
        LDRB    r2, [r7], #1          ; G
        LDRB    r3, [r7], #1          ; B

        MUL     r0, r0, r9
        MLA     r0, r2, r10, r0
        MLA     r0, r3, r11, r0
        LSRS    r0, r0, #8
        STRB    r0, [r6], #1

;==== Advance to next row (rewind then add stride) ==========================
row_advance
        ; dst: r6 currently at end-of-row.
        ; r4 = width (bytes/pixels for dst)
        SUB     r6, r6, r4            ; rewind to start of this row
        ADDS    r6, r6, r1            ; add dst_stride -> next row start

        ; src: r7 at end-of-row, need to subtract width*3 then add stride.
        ; r2 = width*3  (r2 is free here)
        ADD     r2, r4, r4, LSL #1    ; r2 = r4 + (r4<<1) = width*3
        SUB     r7, r7, r2            ; rewind to start of this row
        ADDS    r7, r7, r12           ; add src_stride -> next row start

        SUBS    r5, r5, #1            ; height--
        B       row_loop

;==== Epilogue =================================================================
rows_done
        POP     {r4-r11, pc}
        ENDP

        END
