package widgets

import t ".."

Button_Style :: struct {
	bg, fg:        t.Any_Color,
	text:          bit_set[t.Text_Style],
	padding:       uint,
	width, height: Maybe(uint),
	y, x:          uint,
}

Button :: struct {
	_screen:      ^t.Screen,
	_window:      t.Window,
	_content_box: t.Window,
	content:      string,
	style:        Button_Style,
}

button_init :: proc(screen: ^t.Screen) -> Button {
	return Button {
		_screen = screen,
		_window = t.init_window(0, 0, 0, 0),
		_content_box = t.init_window(0, 0, 0, 0),
	}
}

button_destroy :: proc(btn: ^Button) {
	t.destroy_window(&btn._window)
	t.destroy_window(&btn._content_box)
}

_button_set_layout :: proc(btn: ^Button) {
	btn._window.width = btn.style.width
	btn._window.height = btn.style.height
	btn._window.x_offset = btn.style.x
	btn._window.y_offset = btn.style.y

	y_padding := btn.style.padding * 2
	x_padding := btn.style.padding * 4

	if btn.style.height == nil {
		btn._window.height = y_padding + 1
		btn._content_box.height = 1
	} else {
		btn._content_box.height = btn._window.height.? - y_padding
	}
	box_y_padding_to_center := (btn._window.height.? - btn._content_box.height.?) / 2
	btn._content_box.y_offset = btn._window.y_offset + box_y_padding_to_center

	if btn.style.width == nil {
		// for width padding is doubled because cursor bar is taller than it is wider
		btn._window.width = x_padding + len(btn.content)
		btn._content_box.width = cast(uint)len(btn.content)
	} else {
		btn._content_box.width = btn._window.width.? - x_padding
	}
	box_x_padding_to_center := (btn._window.width.? - btn._content_box.width.?) / 2
	btn._content_box.x_offset = btn._window.x_offset + box_x_padding_to_center
}

button_blit :: proc(btn: ^Button) {
	if len(btn.content) == 0 do return

	_button_set_layout(btn)
	if btn._window.width == nil || btn._window.width == 0 {
		return
	}
	if btn._window.height == nil || btn._window.height == 0 {
		return
	}

	defer {
		t.reset_styles(&btn._window)
		t.blit(&btn._window)
		t.reset_styles(&btn._content_box)
		t.blit(&btn._content_box)
	}

	t.set_color_style(&btn._window, btn.style.fg, btn.style.bg)
	t.set_text_style(&btn._window, btn.style.text)

	t.set_color_style(&btn._content_box, btn.style.fg, btn.style.bg)
	t.set_text_style(&btn._content_box, btn.style.text)

	t.clear(&btn._window, .Everything)
	t.move_cursor(&btn._content_box, 0, 0)
	t.write(&btn._content_box, btn.content)
}

button_hovered :: proc(btn: ^Button) -> bool {
	mouse_input := t.parse_mouse_input(t.Input(btn._screen.input_buf[:])) or_return
	_, in_window := t.window_coord_from_global(
		&btn._window,
		mouse_input.coord.y,
		mouse_input.coord.x,
	)

	return in_window && mouse_input.key == .None
}

button_clicked :: proc(btn: ^Button) -> bool {
	// we avoid using button_hovered here so we don't have to parse input twice
	mouse_input := t.parse_mouse_input(t.Input(btn._screen.input_buf[:])) or_return
	_, in_window := t.window_coord_from_global(
		&btn._window,
		mouse_input.coord.y,
		mouse_input.coord.x,
	)

	return in_window && .Pressed in mouse_input.event && mouse_input.key == .Left
}

