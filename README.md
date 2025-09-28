# Vectorized-Image-Processing
Comp Org 2 - Vectorized Image Processing

## Team
- Gage — 
- Joel — 
- Trayia — 
- Nate — 


# ARM Assembly & HPC Project

Group Term Project for Assembly & HPC concepts.  
We design and implement an ARM assembly program and integrate HPC techniques across multiple phases.  

---

## Project Overview
- **Objective:** Explore ARM assembly programming and high-performance computing (HPC) through practical implementations.
- **Phases:**
  1. Proposal & Design (Week 3)
  2. Assembly Component (Week 6)
  3. HPC Integration (Week 9)
  4. Optimization & Testing (Week 12)
  5. Final Submission & Presentation (Week 15)

---

## Phase 1 — Proposal & Design

## Phase 2 — ARM Assembly Component

### Goal
Implement a working **RGB → Grayscale conversion** in ARM assembly (Cortex-M3, Thumb-2), demonstrating correct data handling, calling conventions, and pixel-level operations.

### Function Signature
```c
void rgb_to_gray_scalar_asm(uint8_t* dst, int dst_stride,
                            const uint8_t* src, int src_stride,
                            int width, int height);
```

- **dst**: pointer to Gray8 buffer (output)
- **dst_stride**: bytes per row of Gray8
- **src**: pointer to RGB buffer (input, interleaved)
- **src_stride**: bytes per row of RGB (3 × width typical)
- **width, height**: image dimensions

### Implementation Notes
- Formula: `Y = (77*R + 150*G + 29*B) >> 8`  
  - Fixed-point Rec.601 approximation  
  - Uses only integer multiply/accumulate instructions  
- Calling convention: AAPCS-32 (r0–r3, then stack)  
- Registers planned for row/col loops and stride handling  
- `MLA` used for efficient multiply-accumulate  
- Strides allow handling of padded or subimage rows

### Test Method
- **Input**: 8×8 gradient RGB test image (R = x*32, G = y*32, B = 128)
- **Output**: 8×8 grayscale buffer in `dst_gray`
- **Verification**:
  - Inspect `dst_gray` in Keil Memory window after execution
  - Spot-check values vs formula
  - Example: Pixel (x=4,y=3) → R=128, G=96, B=128  
    `Y=(77*128 + 150*96 + 29*128)>>8 = 109 (0x6D)`

### Basic Results
- Row 0: `0E 18 21 2B 35 3E 48 51`
- Row 1: `21 2A 34 3E 47 51 5B 64`
- Row 3 (x=4): `0x6D` as expected

### Challenges
- Register pressure: preserving `src_stride` while reusing r3 inside loop
- Ensuring 8-byte stack alignment (AAPCS compliance)
- Avoiding CMSIS/extra DSP dependencies in Keil project

### Lessons Learned
- Clear **register plan** prevents clobbering arguments
- Stride-based design makes function reusable on real image buffers
- Scalar baseline sets up later HPC optimizations (word loads, unrolling, cache-aware access)

---

## Next Steps (Phase 3)
- Explore HPC concepts: SIMD simulation, memory bandwidth, parallel scheduling
- Optimize scalar baseline (unrolling, word loads)
- Begin report on throughput (pixels/sec using DWT_CYCCNT)

---