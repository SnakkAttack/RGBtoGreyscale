#include <stdint.h>

// Declare the assembly routine so C knows it exists
extern void rgb_to_gray_scalar_asm(uint8_t* dst, int dst_stride,
                                   const uint8_t* src, int src_stride,
                                   int width, int height);

// --- Test input: 4 pixels (1 row) ---
// Format: RGBRGBRGBRGB (interleaved)
static const uint8_t src[] = {
    255, 0, 0,      // red
    0, 255, 0,      // green
    0, 0, 255,      // blue
    128, 128, 128   // gray
};

// Output array for grayscale results
static uint8_t dst[4];

int main(void) {
    // Call your assembly function
    // dst_stride = 1 byte/pixel, src_stride = 3 bytes/pixel
    // width = 4 pixels, height = 1 row
    rgb_to_gray_scalar_asm(dst, 1, src, 3, 4, 1);

    // Infinite loop: stop here so you can inspect memory in debugger
    while (1);
}
