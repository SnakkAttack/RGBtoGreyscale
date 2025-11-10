/*
================================================================================
 File:        test_bench.c
 Project:     Phase 4 — Optimization & Testing (CS 2400)
 Team:        Gage, Joel, Trayia
 Target:      Cortex-M (Keil ARMCLANG/ARMCC)

 Purpose:
   Automated micro-benchmark + correctness harness for the RGB888   Grayscale8
   assembly routine `rgb_to_gray_scalar_asm`. For each image size it:
     • Generates a deterministic RGB test pattern
     • Computes a reference grayscale in C (oracle)
     • Runs the assembly kernel for TRIALS iterations
     • Verifies byte-exact correctness after each trial
     • Records averaged performance in cycles-per-pixel (CPP)

 How to use (Keil uVision):
   1) Build and load as usual.
   2) Set a breakpoint on the line containing: SIZE_DONE_BREAK();
   3) Press Run (F5). The program stops once *per size* after it finishes all
      trials and computes averages. Press Run again for the next size.
   4) In the Watch window, add:
        g_w[0..3], g_h[0..3]
        g_cpp_avg[0..3], g_cpp_x256_avg[0..3], g_ticks_avg[0..3]
        g_failures[0..3]
      (Optionally: g_last_ticks, g_last_pixels, g_last_cpp_x256)

 Test matrix (NSIZES = 4):
   [0] 32×32   [1] 64×64   [2] 128×64   [3] 128×128
 Trials per size: TRIALS = 10

 Timing:
   • Prefers DWT_CYCCNT on Cortex-M3/M4/M7 (cycle-accurate).
================================================================================
*/

#include <stdint.h>
#include <string.h>

/* ---------------------------------------------------------------------------
   Fallback for __NOP() if CMSIS headers aren't included.
   (Used to place a convenient breakpoint at the end of each size group.)
--------------------------------------------------------------------------- */
#ifndef __NOP
static inline void __NOP(void){ __asm volatile ("nop"); }
#endif

/* Breakpoint hook: expand to a single NOP instruction. */
#define SIZE_DONE_BREAK() __NOP()

/* ---------------------------------------------------------------------------
   External symbols
   - rgb_to_gray_scalar_asm: assembly kernel under test (baseline or optimized)
   - rgb_to_gray_ref:       C reference used as a correctness oracle
--------------------------------------------------------------------------- */
extern void rgb_to_gray_scalar_asm(uint8_t* dst, int dst_stride,
                                   const uint8_t* src, int src_stride,
                                   int width, int height);
void rgb_to_gray_ref(uint8_t* dst, int dst_stride,
                     const uint8_t* src, int src_stride,
                     int width, int height);

/* ---------------------------------------------------------------------------
   Public globals (debug/Watch-friendly):
   One entry per size (indices 0..NSIZES-1) in the order shown above.
--------------------------------------------------------------------------- */
#define NSIZES 4
#define TRIALS 10

static volatile int      g_w[NSIZES]         = {0};
static volatile int      g_h[NSIZES]         = {0};
static volatile uint32_t g_ticks_avg[NSIZES] = {0};      /* average ticks per image */
static volatile uint32_t g_cpp_x256_avg[NSIZES] = {0};   /* average CPP * 256 */
static volatile float    g_cpp_avg[NSIZES]   = {0.0f};   /* average CPP (float) */
static volatile uint32_t g_failures[NSIZES]  = {0};      /* mismatched trials */

/* Last-trial snapshots (optional, useful while tuning) */
static volatile uint32_t g_last_ticks        = 0;
static volatile uint32_t g_last_pixels       = 0;
static volatile uint32_t g_last_cpp_x256     = 0;

/* ---------------------------------------------------------------------------
   Timing source selection:
   - Use DWT_CYCCNT on Cortex-M3/M4/M7
   - Fallback to SysTick on M0/M0+
--------------------------------------------------------------------------- */
#if defined(__CORTEX_M) && (__CORTEX_M >= 3)
#define HAS_DWT 1
#else
#define HAS_DWT 0
#endif

#if HAS_DWT
/* DWT (Data Watchpoint & Trace) cycle counter registers */
#define DEMCR       (*(volatile uint32_t*)0xE000EDFCu)
#define DWT_CTRL    (*(volatile uint32_t*)0xE0001000u)
#define DWT_CYCCNT  (*(volatile uint32_t*)0xE0001004u)
#define DEMCR_TRCENA (1u << 24)

static inline void timer_init(void){
    DEMCR |= DEMCR_TRCENA;
    DWT_CYCCNT = 0;
    DWT_CTRL  |= 1u;      /* enable cycle counter */
}
static inline void timer_start(void){ DWT_CYCCNT = 0; }
static inline uint32_t timer_stop(void){ return DWT_CYCCNT; }

#else
/* SysTick fallback (coarser but adequate for relative comparisons) */
#define SYST_CSR (*(volatile uint32_t*)0xE000E010u)
#define SYST_RVR (*(volatile uint32_t*)0xE000E014u)
#define SYST_CVR (*(volatile uint32_t*)0xE000E018u)

static inline void timer_init(void){
    SYST_CSR = 0;
    SYST_RVR = 0xFFFFFFu;
    SYST_CVR = 0;
    SYST_CSR = (1u<<0) | (1u<<2);   /* enable | core clock */
}
static inline void timer_start(void){ SYST_CVR = 0; }
static inline uint32_t timer_stop(void){ return (0xFFFFFFu - SYST_CVR); }
#endif

/* ---------------------------------------------------------------------------
   Test buffers (static to keep stack small)
--------------------------------------------------------------------------- */
#define MAX_W 128
#define MAX_H 128
static uint8_t src_rgb[MAX_H][MAX_W * 3];
static uint8_t dst_asm[MAX_H][MAX_W];
static uint8_t dst_ref[MAX_H][MAX_W];

/* ---------------------------------------------------------------------------
   Test pattern generator:
   Produces a deterministic, non-trivial gradient so all channels vary.
--------------------------------------------------------------------------- */
static void fill_pattern(int w, int h){
    for (int y = 0; y < h; ++y){
        for (int x = 0; x < w; ++x){
            uint8_t R = (uint8_t)((x * 37u + y * 13u) & 0xFF);
            uint8_t G = (uint8_t)((x * 11u + y * 71u) & 0xFF);
            uint8_t B = (uint8_t)((x * 5u  + y * 3u ) & 0xFF);
            src_rgb[y][3*x + 0] = R;
            src_rgb[y][3*x + 1] = G;
            src_rgb[y][3*x + 2] = B;
        }
    }
}

/* Byte-exact correctness check against the C oracle */
static int check_equal(int w, int h){
    for (int y = 0; y < h; ++y){
        for (int x = 0; x < w; ++x){
            if (dst_asm[y][x] != dst_ref[y][x]) return 0;
        }
    }
    return 1;
}

/* ---------------------------------------------------------------------------
   MAIN — runs TRIALS iterations per size, publishes averages, and pauses
   once per size (via SIZE_DONE_BREAK) so results are easy to read in Watch.
--------------------------------------------------------------------------- */
int main(void){
    timer_init();

    const int sizes[NSIZES][2] = { {32,32}, {64,64}, {128,64}, {128,128} };

    for (int s = 0; s < NSIZES; ++s){
        int W = sizes[s][0], H = sizes[s][1];
        int src_stride = W * 3;
        int dst_stride = W;

        g_w[s] = W; g_h[s] = H;

        /* Prepare input & reference output once per size */
        fill_pattern(W, H);
        rgb_to_gray_ref(&dst_ref[0][0], dst_stride, &src_rgb[0][0], src_stride, W, H);

        uint64_t sum_ticks = 0;
        uint64_t sum_cpp_x256 = 0;
        uint32_t failures = 0;

        /* Optional cache/pipeline warm-up (not included in timing) */
        rgb_to_gray_scalar_asm(&dst_asm[0][0], dst_stride, &src_rgb[0][0], src_stride, W, H);

        for (int t = 0; t < TRIALS; ++t){
            timer_start();
            rgb_to_gray_scalar_asm(&dst_asm[0][0], dst_stride, &src_rgb[0][0], src_stride, W, H);
            uint32_t ticks = timer_stop();

            int ok = check_equal(W, H);
            if (!ok) failures++;

            uint32_t pixels = (uint32_t)W * (uint32_t)H;
            uint32_t cpp_x256 = (ticks << 8) / (pixels   pixels : 1);

            sum_ticks    += ticks;
            sum_cpp_x256 += cpp_x256;

            /* Snapshot of last trial (handy while tuning) */
            g_last_ticks    = ticks;
            g_last_pixels   = pixels;
            g_last_cpp_x256 = cpp_x256;
        }

        /* Averages for this size (exposed via globals for easy reading) */
        uint32_t avg_ticks    = (uint32_t)(sum_ticks / TRIALS);
        uint32_t avg_cpp_x256 = (uint32_t)(sum_cpp_x256 / TRIALS);
        float    avg_cpp      = (float)avg_cpp_x256 / 256.0f;

        g_ticks_avg[s]    = avg_ticks;
        g_cpp_x256_avg[s] = avg_cpp_x256;
        g_cpp_avg[s]      = avg_cpp;
        g_failures[s]     = failures;

        /* BREAKPOINT: stop once per size so you can record the averages */
        SIZE_DONE_BREAK();
    }

    /* Park the core to keep results visible in the debugger */
    while (1){ __asm volatile ("nop"); }
}

