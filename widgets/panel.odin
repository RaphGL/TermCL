package widgets

import t ".."

Panel_Item_Position :: enum {
	None,
	Left,
	Right,
	Center,
}

Panel_Item :: struct {
	position: Panel_Item_Position,
	content:  string,
}

Panel_Color :: union {
	t.RGB_Color,
	t.Color_8,
}

Panel :: struct {
	window:        t.Window,
	items:         []Panel_Item,
	bg_color:      Panel_Color,
	fg_color:      Panel_Color,
	space_between: uint,
}

panel_init :: proc(screen: ^t.Screen, space_between: uint) -> Panel {
	termsize := t.get_term_size(screen)
	return Panel {
		window = t.init_window(termsize.h - 1, 0, 1, termsize.w),
		space_between = space_between,
	}
}

panel_destroy :: proc(panel: ^Panel) {
	t.destroy_window(&panel.window)
}

panel_blit :: proc(panel: ^Panel) {
	// sadly this is the only way I found to allow either RGB or 8 color palette colors
	// without having to make the user cast into union types
	if panel.fg_color != nil && panel.bg_color != nil {
		fg_rgb, has_fg_rgb := panel.fg_color.(t.RGB_Color)
		bg_rgb, has_bg_rgb := panel.bg_color.(t.RGB_Color)

		fg_8, has_fg_8 := panel.fg_color.(t.Color_8)
		bg_8, has_bg_8 := panel.bg_color.(t.Color_8)

		if (has_fg_8 || has_bg_8) && (has_fg_rgb || has_bg_rgb) {
			panic("both fg and bg have to be the same color type or nil")
		}

		if has_fg_8 || has_bg_8 {
			t.set_color_style(&panel.window, fg_8, bg_8)
		}

		if has_fg_rgb || has_bg_rgb {
			t.set_color_style(&panel.window, fg_rgb, bg_rgb)
		}

	}

	t.clear(&panel.window, .Everything)

	cursor_on_left := t.Cursor_Position {
		x = 1,
		y = 0,
	}
	cursor_on_right := t.Cursor_Position {
		x = panel.window.width.? - 1,
		y = 0,
	}

	t.move_cursor(&panel.window, 0, 1)
	center_items := make([dynamic]Panel_Item)
	defer delete(center_items)

	drawing_panel: for item in panel.items {
		switch item.position {
		case .None:
			continue drawing_panel

		case .Left:
			t.move_cursor(&panel.window, cursor_on_left.y, cursor_on_left.x)
			t.write(&panel.window, item.content)
			cursor_pos := t.get_cursor_position(&panel.window)
			cursor_pos.x += panel.space_between
			cursor_on_left = cursor_pos

		case .Right:
			t.move_cursor(&panel.window, cursor_on_right.y, cursor_on_right.x - len(item.content))
			cursor_on_right.x -= len(item.content) + panel.space_between
			t.write(&panel.window, item.content)

		case .Center:
			append(&center_items, item)
		}
	}

	// the space in between each item will always be num_of_items - 1
	center_items_width: uint = (len(center_items) - 1) * panel.space_between
	for item in center_items {
		center_items_width += len(item.content)
	}

	panel_width := panel.window.width.?
	t.move_cursor(&panel.window, 0, panel_width / 2 - center_items_width / 2)
	for item in center_items {
		t.write(&panel.window, item.content)
		cursor_pos := t.get_cursor_position(&panel.window)
		cursor_pos.x += panel.space_between
		t.move_cursor(&panel.window, cursor_pos.y, cursor_pos.x)
	}

	t.reset_styles(&panel.window)
	t.blit(&panel.window)
}

