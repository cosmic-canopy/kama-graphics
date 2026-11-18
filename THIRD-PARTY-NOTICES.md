# Third-party notices

`@kama/graphics` is licensed MIT OR Apache-2.0 (`LICENSE-MIT`, `LICENSE-APACHE`). This file holds the notices of other
people's work that the library carries, which travel with every copy of a program built on it.

## three.js

`src/dfg.kama` holds three.js r187's DFG table, its `src/nodes/functions/BSDF/DFGLUT.js` (16 x 16 texels of two half
floats, the scale and bias of a surface's specular reflectance), copied as it is. The direct light reads it as
three.js's does. `src/physical.kama` ports r187's physical lighting: its `src/nodes/functions/PhysicalLightingModel.js`,
the BSDFs in `src/nodes/functions/BSDF/` (`BRDF_Lambert`, `F_Schlick`, `V_GGX_SmithCorrelated`, `D_GGX`, `BRDF_GGX`) and
`src/nodes/functions/material/getRoughness.js`. `src/output.kama`'s `AgX` is r187's AgX tone mapping, its
`src/nodes/display/ToneMappingFunctions.js` (`agxToneMapping`, `agxDefaultContrastApprox` and its Rec.2020 matrices),
under the same licence. The text below is three.js r187's `LICENSE`, verbatim.

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

## Blender's AgX: EaryChow's AgX, Troy Sobotka's AgX and colour-science

`src/agx.kama` makes the table Blender 5.3 shows its AgX view through on an sRGB display (`AgX_Base_sRGB.cube`), from the
formulas of the script that made Blender's table: EaryChow's AgX_LUT_Gen (<https://github.com/EaryChow/AgX_LUT_Gen>,
`AgXBasesRGB.py`, `AgXBaseRec2020.py`, `luminance_compenstation_bt2020.py` and `luminance_compenstation_srgb.py` as of
commit `ab7415e`, 2023-09-07), "based on original AgX by Troy Sobotka" (<https://github.com/sobotka/AgX>,
<https://github.com/sobotka/SB2383-Configuration-Generation>), its sigmoid Troy Sobotka's `sigmoid.py`, and Blender's
lower guard rails "modified from script shared by Sakari Kapanen". Its code is the library's own, written from those
formulas; the matrices and the curve's parameters are theirs. The generator states no licence: its author has been
asked for one, and the library is not published before the answer. `src/output.kama` reads the table with the constants
Blender's `release/datafiles/colormanagement/config.ocio` states (its E-Gamut matrix and lg2 allocation).

The formulas call colour-science's functions (<https://www.colour-science.org>, `log_encoding_Log2`,
`exponent_function_basic`, `RGB_to_HSV`, `HSV_to_RGB`, `linstep_function`, `sdiv`), which `src/agx.kama` follows as
colour-science 0.4.3 defines them. The text below is colour-science 0.4.3's `LICENSE`, verbatim.

```
Copyright 2013 Colour Developers

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE
```
