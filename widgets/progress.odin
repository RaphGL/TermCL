package widgets

import t ".."

// TODO: implement gradient in the future

@(rodata)
progression_bar := [?]rune{'▏', '▎', '▍', '▌', '▋', '▊', '▉'}

Progress_Style :: struct {
	bg, fg: Any_Color,
	text:   bit_set[t.Text_Style],
	width:  Maybe(uint),
	y, x:   uint,
}

Progress :: struct {
	_screen:     ^t.Screen,
	_window:     t.Window,
	max, curr:   uint,
	description: string,
	style:       Progress_Style,
}

progress_init :: proc(s: ^t.Screen) -> Progress {
	return Progress{_screen = s, _window = t.init_window(0, 0, 0, 0)}
}

progress_destroy :: proc(prog: ^Progress) {
	t.destroy_window(&prog._window)
}

progress_add :: proc(prog: ^Progress, done: uint) {
	prog.curr += done
}

progress_done :: proc(prog: ^Progress) -> bool {
	return prog.curr >= prog.max
}

// TODO: set height to 1 if no description and 2 if has desc
// set width dependent on len(description) and prog.max 
_progress_set_layout :: proc(prog: ^Progress) {
}

progress_blit :: proc(prog: ^Progress) {
	_progress_set_layout(prog)
	t.clear(&prog._window, .Everything)
	t.move_cursor(&prog._window, 0, 0)

	remainder := prog.curr % len(progression_bar)
	full_bars := prog.curr - remainder
	set_any_color_style(&prog._window, prog.style.fg, prog.style.bg)
	for i in 0 ..< full_bars {
		t.write(&prog._window, progression_bar[len(progression_bar) - 1])
	}
	t.write(&prog._window, progression_bar[remainder])
	t.reset_styles(&prog._window)

	t.write(&prog._window, ' ')
	t.writef(&prog._window, "%d%%", prog.curr / prog.max)

	if len(prog.description) != 0 {
		t.move_cursor(&prog._window, 1, 0)
		t.write(&prog._window, prog.description)
	}

	t.blit(&prog._window)
}

