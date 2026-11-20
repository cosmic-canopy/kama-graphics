// tests/js/graphicstests.js: what the tests program asks the page, on the web (tests/src/window_web.kama). It reads the
// window's canvas back the way a page can: drawn onto a 2D canvas with drawImage and read with getImageData. A browser
// lets a page read a WebGPU canvas exactly while the task that drew it runs, before its frame is presented (Chrome for
// Testing and Edge read zeros after; kyoten's .scratch/s40/probe-canvas), so the tests read it in the tick that rendered.
//
// The gate builds it in a release build too, which runs Closure over it (kama 0.9.966, KR-289): the option key the
// browser reads is quoted.
mergeInto(LibraryManager.library, {
  graphicstests_canvas_read__deps: ['$UTF8ToString'],
  graphicstests_canvas_read: function (sel, dst, capacity, width, height) {
    var canvas = document.querySelector(UTF8ToString(sel));
    if (!canvas) return -1;
    var w = canvas.width, h = canvas.height;
    HEAP32[width >> 2] = w;
    HEAP32[height >> 2] = h;
    if (w * h * 4 > capacity) return -2;
    var two = document.createElement('canvas');
    two.width = w;
    two.height = h;
    var g = two.getContext('2d', { 'willReadFrequently': true });
    g.drawImage(canvas, 0, 0);
    HEAPU8.set(g.getImageData(0, 0, w, h).data, dst);
    return w * h;
  },
});
