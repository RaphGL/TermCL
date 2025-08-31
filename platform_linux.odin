package termcl

import "core:c"
import "core:sys/linux"

/*
Get terminal size

NOTE: this functional does syscalls to figure out the size of the terminal.
For most use cases, passing `Screen` to `get_window_size` achieves the same result
and doesn't need to do any system calls.

You should only use this function if you don't have access to `Screen` and still somehow
need to figure out the terminal size. Otherwise this function might or might not cause
your program to slow down a bit due to OS context switching.
*/
get_term_size :: proc() -> Window_Size {
	winsize :: struct {
		ws_row, ws_col:       c.ushort,
		ws_xpixel, ws_ypixel: c.ushort,
	}

	w: winsize
	if linux.ioctl(linux.STDOUT_FILENO, linux.TIOCGWINSZ, cast(uintptr)&w) != 0 {
		panic("Failed to get terminal size")
	}

	win := Window_Size {
		h = uint(w.ws_row),
		w = uint(w.ws_col),
	}

	return win
}

