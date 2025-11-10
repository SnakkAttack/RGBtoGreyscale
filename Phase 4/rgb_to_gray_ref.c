#include <stdint.h>

void rgb_to_gray_ref(uint8_t* dst, int dst_stride,
                     const uint8_t* src, int src_stride,
                     int width, int height)
{
    for (int y = 0; y < height; ++y) {
        uint8_t* d = dst;
        const uint8_t* s = src;
        for (int x = 0; x < width; ++x) {
            uint32_t R = s[0], G = s[1], B = s[2];
            uint32_t Y = (77*R + 150*G + 29*B) >> 8;
            d[x] = (uint8_t)Y;
            s += 3;
        }
        dst += dst_stride;
        src += src_stride;
    }
}
