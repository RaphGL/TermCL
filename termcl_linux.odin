package termcl

import "core:c"
import "core:sys/linux"

get_term_size :: proc() -> Screen_Size {
	winsize :: struct {
		ws_row, ws_col:       c.ushort,
		ws_xpixel, ws_ypixel: c.ushort,
	}

	// right this is supported by all odin platforms
	// but there's a few platforms that have a different value
	// check: https://github.com/search?q=repo%3Atorvalds%2Flinux%20TIOCGWINSZ&type=code
	TIOCGWINSZ :: 0x5413

	w: winsize
	linux.ioctl(linux.STDOUT_FILENO, TIOCGWINSZ, cast(uintptr)&w)

	win := Screen_Size {
		h = uint(w.ws_row),
		w = uint(w.ws_col),
	}

	return win
}

