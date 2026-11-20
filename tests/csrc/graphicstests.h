// graphicstests.h: what the tests ask the page, on the web (tests/js/graphicstests.js). Declares and never defines (kama
// emits each extern header into one shared header).
#ifndef GRAPHICSTESTS_H
#define GRAPHICSTESTS_H

#include <stdint.h>

// The canvas `sel` names, as the page would show it now, read back through a 2D canvas's drawImage into `dst`, 8-bit
// RGBA, top row first, at most `capacity` bytes; its size in pixels into `width` and `height`. The texels read, or -1
// when no canvas matches `sel`, -2 when `capacity` is too small.
int32_t graphicstests_canvas_read(const char *sel, uint8_t *dst, int32_t capacity, int32_t *width, int32_t *height);

#endif
