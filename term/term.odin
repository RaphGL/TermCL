package term

import t ".."
import "../raw"
import "core:fmt"
import os "core:os/os2"
import "core:strings"

@(private)
orig_termstate: Terminal_State

VTABLE :: t.Backend_VTable {
	init_screen    = init_screen,
	destroy_screen = destroy_screen,
	get_term_size  = get_term_size,
	set_term_mode  = set_term_mode,
	blit           = blit,
	read           = read,
	read_blocking  = read_blocking,
}

init_screen :: proc(allocator := context.allocator) -> t.Screen {
	context.allocator = allocator

	termstate, ok := get_terminal_state()
	if !ok {
		panic("failed to get terminal state")
	}
	orig_termstate = termstate

	// TODO: get cursor position from terminal on init
	return t.Screen{winbuf = t.init_window(0, 0, nil, nil, allocator = allocator)}
}

destroy_screen :: proc(screen: ^t.Screen) {
	set_term_mode(screen, .Restored)
	t.destroy_window(&screen.winbuf)
	t.enable_alt_buffer(false)
}

set_term_mode :: proc(screen: ^t.Screen, mode: t.Term_Mode) {
	change_terminal_mode(screen, mode)

	#partial switch mode {
	case .Restored:
		t.enable_alt_buffer(false)
		t.enable_mouse(false)

	case .Raw:
		t.enable_alt_buffer(true)
		raw.enable_mouse(true)
	}

	t.hide_cursor(false)
	// when changing modes some OSes (like windows) might put garbage that we don't care about
	// in stdin potentially causing nonblocking reads to block on the first read, so to avoid this,
	// stdin is always flushed when the mode is changed
	os.flush(os.stdin)
}

blit :: proc(win: ^t.Window) {
	if win.height == 0 || win.width == 0 {
		return
	}

	// this is needed to prevent the window from sharing the same style as the terminal
	// this avoids messing up users' styles from one window to another
	raw.set_fg_color_style(&win.seq_builder, win.curr_styles.fg)
	raw.set_bg_color_style(&win.seq_builder, win.curr_styles.bg)
	raw.set_text_style(&win.seq_builder, win.curr_styles.text)

	curr_styles := win.curr_styles
	// always zero valued
	reset_styles: t.Styles

	for y in 0 ..< win.cell_buffer.height {
		global_pos := t.global_coord_from_window(win, y, 0)
		raw.move_cursor(&win.seq_builder, global_pos.y, global_pos.x)

		for x in 0 ..< win.cell_buffer.width {
			curr_cell := t.cellbuf_get(win.cell_buffer, y, x)
			defer {
				curr_styles = curr_cell.styles
				strings.write_rune(&win.seq_builder, curr_cell.r)
			}

			/* OPTIMIZATION: don't change styles unless they change between cells */{
				if curr_styles != reset_styles && curr_cell.styles == reset_styles {
					raw.reset_styles(&win.seq_builder)
					continue
				}

				if curr_styles.fg != curr_cell.styles.fg {
					raw.set_fg_color_style(&win.seq_builder, curr_cell.styles.fg)
				}

				if curr_styles.bg != curr_cell.styles.bg {
					raw.set_bg_color_style(&win.seq_builder, curr_cell.styles.bg)
				}

				if curr_styles.text != curr_cell.styles.text {
					if curr_cell.styles.text == nil {
						raw.reset_styles(&win.seq_builder)
						raw.set_fg_color_style(&win.seq_builder, curr_cell.styles.fg)
						raw.set_bg_color_style(&win.seq_builder, curr_cell.styles.bg)
					}
					raw.set_text_style(&win.seq_builder, curr_cell.styles.text)
				}
			}
		}
	}
	// we move the cursor back to where the window left it
	// just in case if the user is relying on the terminal drawing the cursor
	raw.move_cursor(&win.seq_builder, win.cursor.y, win.cursor.x)

	fmt.print(strings.to_string(win.seq_builder), flush = true)
	strings.builder_reset(&win.seq_builder)
}
