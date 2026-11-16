# Third-party notices

`@kama/graphics` is licensed MIT OR Apache-2.0 (`LICENSE-MIT`, `LICENSE-APACHE`). This file holds the notices of other
people's work that the library carries, which travel with every copy of a program built on it.

## three.js

`src/dfg.kama` holds three.js r187's DFG table, its `src/nodes/functions/BSDF/DFGLUT.js` (16 x 16 texels of two half
floats, the scale and bias of a surface's specular reflectance), copied as it is. The direct light reads it as three.js's
does. The text below is three.js r187's `LICENSE`, verbatim.

```
The MIT License

Copyright © 2010-2026 three.js authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```
