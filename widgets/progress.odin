package widgets

import t ".."
import "core:bytes"
import "core:strconv"

// TODO: implement color gradient in the future

@(rodata)
progression_bar := [?]rune{'▏', '▎', '▍', '▌', '▋', '▊', '▉'}

Progress_Style :: struct {
	description_color: Any_Color,
	bg, fg:            Any_Color,
	text:              bit_set[t.Text_Style],
	width:             Maybe(uint),
	y, x:              uint,
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
	if prog.curr < prog.max do prog.curr += done
}

progress_done :: proc(prog: ^Progress) -> bool {
	return prog.curr >= prog.max
}

// size of ` 100.0%`
@(private)
PROGRESS_PERCENT_SIZE :: 7

// TODO: set height to 1 if no description and 2 if has desc
// set width dependent on len(description) and prog.max 
_progress_set_layout :: proc(prog: ^Progress) {
	prog._window.height = 1 if len(prog.description) == 0 else 2

	progress_width: uint
	if prog.style.width != nil {
		progress_width = prog.style.width.?
	} else {
		DEFAULT_WIDTH :: 15
		progress_width =
			len(prog.description) if len(prog.description) > DEFAULT_WIDTH else DEFAULT_WIDTH
	}

	progress_width += PROGRESS_PERCENT_SIZE
	prog._window.width = progress_width

	prog._window.y_offset = prog.style.y
	prog._window.x_offset = prog.style.x
}

progress_blit :: proc(prog: ^Progress) {
	if prog.max == 0 do return
	_progress_set_layout(prog)
	t.clear(&prog._window, .Everything)
	t.move_cursor(&prog._window, 0, 0)

	percentage := cast(f64)prog.curr / cast(f64)prog.max
	curr_progress_width := uint(cast(f64)(prog._window.width.? - 8) * percentage)

	set_any_color_style(&prog._window, prog.style.fg, prog.style.fg)
	for i in 0 ..< curr_progress_width {
		t.write(&prog._window, progression_bar[len(progression_bar) - 1])
	}

	total_progress_width := prog._window.width.? - PROGRESS_PERCENT_SIZE

	set_any_color_style(&prog._window, prog.style.bg, prog.style.bg)
	for i in 0 ..< total_progress_width - curr_progress_width - 1 {
		t.write(&prog._window, progression_bar[len(progression_bar) - 1])
	}


	set_any_color_style(&prog._window, prog.style.fg, nil)
	t.move_cursor(&prog._window, 0, total_progress_width)
	t.writef(&prog._window, " %1.1f%%", percentage * 100)

	if len(prog.description) != 0 {
		t.move_cursor(&prog._window, 1, 0)
		t.write(&prog._window, prog.description)
	}

	t.reset_styles(&prog._window)
	t.blit(&prog._window)
}

