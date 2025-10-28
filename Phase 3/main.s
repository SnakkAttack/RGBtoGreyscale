        PRESERVE8
        THUMB

        IMPORT  rgb_to_gray_scalar_asm
        EXPORT  main
        EXPORT  dst_gray
        EXPORT  src_rgb


; ------------ Constants -------------
W           EQU     8
H           EQU     8
SRC_STRIDE  EQU     (W*3)    ; 24
DST_STRIDE  EQU     (W)      ; 8

        AREA    |.text|, CODE, READONLY, ALIGN=2

main    PROC
        ; r0 = dst, r1 = dst_stride, r2 = src, r3 = src_stride
        LDR     r0, =dst_gray
        MOVS    r1, #DST_STRIDE
        LDR     r2, =src_rgb
        MOVS    r3, #SRC_STRIDE

        ; Push extra args: width and height at [sp,#0] and [sp,#4]
        SUB     sp, sp, #8
        MOVS    r4, #W
        STR     r4, [sp, #0]
        MOVS    r4, #H
        STR     r4, [sp, #4]

        BL      rgb_to_gray_scalar_asm

        ADD     sp, sp, #8

        ; Idle so you can inspect dst_gray in the debugger
        B       .               ; infinite self-branch
        ENDP

        AREA    |.data|, DATA, READWRITE, ALIGN=2

; 8x8 RGB gradient: R = x*32, G = y*32, B = 128
src_rgb
        ; y = 0
        DCB     0,0,128,   32,0,128,   64,0,128,   96,0,128,   128,0,128,  160,0,128,  192,0,128,  224,0,128
        ; y = 1
        DCB     0,32,128,  32,32,128,  64,32,128,  96,32,128,  128,32,128, 160,32,128, 192,32,128, 224,32,128
        ; y = 2
        DCB     0,64,128,  32,64,128,  64,64,128,  96,64,128,  128,64,128, 160,64,128, 192,64,128, 224,64,128
        ; y = 3
        DCB     0,96,128,  32,96,128,  64,96,128,  96,96,128,  128,96,128, 160,96,128, 192,96,128, 224,96,128
        ; y = 4
        DCB     0,128,128, 32,128,128, 64,128,128, 96,128,128, 128,128,128,160,128,128,192,128,128,224,128,128
        ; y = 5
        DCB     0,160,128, 32,160,128, 64,160,128, 96,160,128, 128,160,128,160,160,128,192,160,128,224,160,128
        ; y = 6
        DCB     0,192,128, 32,192,128, 64,192,128, 96,192,128, 128,192,128,160,192,128,192,192,128,224,192,128
        ; y = 7
        DCB     0,224,128, 32,224,128, 64,224,128, 96,224,128, 128,224,128,160,224,128,192,224,128,224,224,128

        ALIGN   2
dst_gray
        SPACE   (W*H)          ; 64 bytes

        END
