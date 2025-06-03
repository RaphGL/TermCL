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

Panel :: struct {
	_screen:       ^t.Screen,
	_window:       t.Window,
	items:         []Panel_Item,
	bg_color:      Any_Color,
	fg_color:      Any_Color,
	space_between: uint,
}

panel_init :: proc(screen: ^t.Screen, space_between: uint) -> Panel {
	termsize := t.get_term_size(screen)
	return Panel {
		_screen = screen,
		_window = t.init_window(0, 0, 1, 0),
		space_between = space_between,
	}
}

_panel_set_layout :: proc(panel: ^Panel) {
	termsize := t.get_term_size(panel._screen)
	panel._window.y_offset = termsize.h
	panel._window.width = termsize.w
}

panel_destroy :: proc(panel: ^Panel) {
	t.destroy_window(&panel._window)
}

panel_blit :: proc(panel: ^Panel) {
	_panel_set_layout(panel)

	defer t.reset_styles(&panel._window)
	set_any_color_style(&panel._window, panel.fg_color, panel.bg_color)
	t.clear(&panel._window, .Everything)

	cursor_on_left := t.Cursor_Position {
		x = 1,
		y = 0,
	}
	cursor_on_right := t.Cursor_Position {
		x = panel._window.width.? - 1,
		y = 0,
	}

	t.move_cursor(&panel._window, 0, 1)
	center_items := make([dynamic]Panel_Item)
	defer delete(center_items)

	drawing_panel: for item in panel.items {
		switch item.position {
		case .None:
			continue drawing_panel

		case .Left:
			t.move_cursor(&panel._window, cursor_on_left.y, cursor_on_left.x)
			t.write(&panel._window, item.content)
			cursor_pos := t.get_cursor_position(&panel._window)
			cursor_pos.x += panel.space_between
			cursor_on_left = cursor_pos

		case .Right:
			t.move_cursor(&panel._window, cursor_on_right.y, cursor_on_right.x - len(item.content))
			cursor_on_right.x -= len(item.content) + panel.space_between
			t.write(&panel._window, item.content)

		case .Center:
			append(&center_items, item)
		}
	}

	// the space in between each item will always be num_of_items - 1
	center_items_width: uint = (len(center_items) - 1) * panel.space_between
	for item in center_items {
		center_items_width += len(item.content)
	}

	panel_width := panel._window.width.?
	t.move_cursor(&panel._window, 0, panel_width / 2 - center_items_width / 2)
	for item in center_items {
		t.write(&panel._window, item.content)
		cursor_pos := t.get_cursor_position(&panel._window)
		cursor_pos.x += panel.space_between
		t.move_cursor(&panel._window, cursor_pos.y, cursor_pos.x)
	}

	t.blit(&panel._window)
}

