package widgets

import t ".."

Selector_Item :: struct($T: typeid) {
	content: string,
	value:   T,
}

Selector_Style :: struct {
	bg, fg: t.Any_Color,
	active: t.Any_Color,
	width:  Maybe(uint),
	x, y:   uint,
}

Selector :: struct($T: typeid) {
	_screen: ^t.Screen,
	_window: t.Window,
	_curr:   uint,
	items:   []Selector_Item(T),
	style:   Selector_Style,
}

selector_init :: proc(screen: ^t.Screen, $Value: typeid) -> Selector(Value) {
	sel := Selector(Value) {
		_screen = screen,
		_window = t.init_window(0, 0, nil, nil),
		style = {fg = .White, active = .Green},
	}

	return sel
}

selector_destroy :: proc(selector: ^Selector($T)) {
	t.destroy_window(&selector._window)
}

Select_Action :: enum {
	Next,
	Prev,
}

selector_do :: proc(selector: ^Selector($T), action: Select_Action) {
	switch action {
	case .Next:
		if len(selector.items) != 0 && selector._curr >= len(selector.items) - 1 {
			selector._curr = 0
		} else {
			selector._curr += 1
		}
	case .Prev:
		if selector._curr == 0 {
			selector._curr = len(selector.items) - 1
		} else {
			selector._curr -= 1
		}
	}
}

selector_curr :: proc(selector: ^Selector($T)) -> T {
	return selector.items[selector._curr].value
}

_selector_set_layout :: proc(selector: ^Selector($T)) {
	selector._window.x_offset = selector.style.x
	selector._window.y_offset = selector.style.y

	width, has_width := selector.style.width.?
	if has_width {
		selector._window.width = width
	} else {
		largest: uint
		for item in selector.items {
			if largest < len(item.content) do largest = len(item.content)
		}
		selector._window.width = largest + 1
	}

	// TODO set height based on selector.items
	// knowing how many lines a string will span starting from a cursor position
	// seems to be a common occurrence in this widget library so we should probably 
	// create something to do that for us in common.odin
	// PS: just using _get_cursor_pos_from_string might be enough
	height: uint = 50
	for item in selector.items {

	}

	selector._window.height = height
}

selector_blit :: proc(selector: ^Selector($T)) {
	_selector_set_layout(selector)

	for item, idx in selector.items {
		is_curr := selector._curr == uint(idx)

		set_any_color_style(
			&selector._window,
			selector.style.active if is_curr else selector.style.fg,
			selector.style.bg,
		)

		t.move_cursor(&selector._window, uint(idx), 0)
		t.write(&selector._window, '>' if is_curr else ' ')
		t.write(&selector._window, item.content)
	}

	t.reset_styles(&selector._window)
	t.blit(&selector._window)
}

