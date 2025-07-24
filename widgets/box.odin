package widgets

import t ".."

Box_Style :: struct {
	bg, fg:        Maybe(t.Any_Color),
	y, x:          uint,
	height, width: uint,
	vertical:      rune,
	horizontal:    rune,
	top_left:      rune,
	top_right:     rune,
	bottom_left:   rune,
	bottom_right:  rune,
}

Box :: struct {
	_screen: ^t.Screen,
	_window: t.Window,
}

box_init :: proc(screen: ^t.Screen) -> Box {
	return Box{_screen = screen, _window = t.init_window(0, 0, 0, 0)}
}

box_destroy :: proc(b: ^Box) {
	t.destroy_window(&b._window)
}

Box_Border_Style :: enum {}
// allow to choose from premade border styles
box_set_style :: proc() {}

_box_set_layout :: proc() {}
box_blit :: proc() {}

