#include <stdint.h>

// Declare the assembly routine so C knows it exists
extern void rgb_to_gray_scalar_asm(uint8_t* dst, int dst_stride,
                                   const uint8_t* src, int src_stride,
                                   int width, int height);

// --- Test input: 4 pixels (1 row) ---
// Format: RGBRGBRGBRGB (interleaved)
static const uint8_t src[] = {
    255, 0,   0,   // red
    0,   255, 0,   // green
    0,   0,   255, // blue
    128, 128, 128  // gray
};

// Output array for grayscale results
static uint8_t dst[4];

int main(void) {
    const int width  = 4;
    const int height = 1;

    // Use full row strides (bytes to advance between rows)
    const int dst_stride = width * 1;  // 4
    const int src_stride = width * 3;  // 12

    rgb_to_gray_scalar_asm(dst, dst_stride, src, src_stride, width, height);

    // Expect roughly: [76, 149, 28, 128]
    while (1) { /* Inspect dst in debugger */ }
}
