module NVTXColorsExt

import NVTX, Colors

NVTX._normalize_color(x::Colors.Colorant) = Colors.ARGB32(x).color

end
