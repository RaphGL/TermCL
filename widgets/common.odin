package widgets

import t ".."

Any_Color :: union {
	t.RGB_Color,
	t.Color_8,
}

set_any_color_style :: proc(win: $T/^t.Window, fg: Any_Color, bg: Any_Color) {
	// sadly this is the only way I found to allow either RGB or 8 color palette colors
	// without having to make the user cast into union types
	if fg != nil && bg != nil {
		fg_rgb, has_fg_rgb := fg.(t.RGB_Color)
		bg_rgb, has_bg_rgb := bg.(t.RGB_Color)

		fg_8, has_fg_8 := fg.(t.Color_8)
		bg_8, has_bg_8 := bg.(t.Color_8)

		if (has_fg_8 || has_bg_8) && (has_fg_rgb || has_bg_rgb) {
			panic("both fg and bg have to be the same color type or nil")
		}

		if has_fg_8 || has_bg_8 {
			t.set_color_style(win, fg_8, bg_8)
		}

		if has_fg_rgb || has_bg_rgb {
			t.set_color_style(win, fg_rgb, bg_rgb)
		}

	}
}

