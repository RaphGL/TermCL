package termcl

import "core:c"
import "core:sys/linux"

get_term_size_via_syscall :: proc() -> (Screen_Size, bool) {
	winsize :: struct {
		ws_row, ws_col:       c.ushort,
		ws_xpixel, ws_ypixel: c.ushort,
	}

	w: winsize
	if linux.ioctl(linux.STDOUT_FILENO, linux.TIOCGWINSZ, cast(uintptr)&w) != 0 do return {}, false

	win := Screen_Size {
		h = uint(w.ws_row),
		w = uint(w.ws_col),
	}

	return win, true
}

