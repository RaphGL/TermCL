package termcl

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import "core:sys/linux"
import "core:sys/posix"

VALID_POSIX_OSES :: bit_set[runtime.Odin_OS_Type] {
	.Linux,
	.Haiku,
	.Darwin,
	.FreeBSD,
	.NetBSD,
	.OpenBSD,
}

when ODIN_OS in VALID_POSIX_OSES {
	Terminal_State :: struct {
		state: posix.termios,
	}
}


@(private)
get_terminal_state :: proc() -> (Terminal_State, bool) {
	when ODIN_OS in VALID_POSIX_OSES {
		termstate: posix.termios
		ok := posix.tcgetattr(posix.STDIN_FILENO, &termstate) == .OK
		return Terminal_State{state = termstate}, ok
	} else {
		return {}, false
	}
}

@(private)
change_terminal_mode :: proc(screen: ^Screen, mode: Term_Mode) {
	when ODIN_OS in VALID_POSIX_OSES {
		termstate, ok := get_terminal_state()
		if !ok {
			fmt.eprintln(#procedure, "failed:", "tcgetattr returned an error")
			os.exit(1)
		}

		raw := termstate.state

		switch mode {
		case .Raw:
			raw.c_lflag -= {.ECHO, .ICANON, .ISIG, .IEXTEN}
			raw.c_iflag -= {.ICRNL, .IXON}
			raw.c_oflag -= {.OPOST}

			// probably meaningless on modern terminals but apparently it's good practice
			raw.c_iflag -= {.BRKINT, .INPCK, .ISTRIP}
			raw.c_cflag |= {.CS8}

		case .Cbreak:
			raw.c_lflag -= {.ECHO, .ICANON}

		case .Restored:
			raw = screen.original_termstate.state
		}

		if mode == .Raw || mode == .Cbreak {
			// timeout for reads
			raw.c_cc[.VMIN] = 0
			raw.c_cc[.VTIME] = 1 // 100 ms

		}

		if posix.tcsetattr(posix.STDIN_FILENO, .TCSAFLUSH, &raw) != .OK {
			fmt.eprintln(#procedure, "failed:", "tcsetattr returned an error")
			os.exit(1)
		}
	}
}

get_term_size_via_syscall :: proc() -> (Screen_Size, bool) {
	when ODIN_OS == .Linux {
		winsize :: struct {
			ws_row, ws_col:       c.ushort,
			ws_xpixel, ws_ypixel: c.ushort,
		}

		// right this is supported by all odin platforms
		// but there's a few platforms that have a different value
		// check: https://github.com/search?q=repo%3Atorvalds%2Flinux%20TIOCGWINSZ&type=code
		TIOCGWINSZ :: 0x5413

		w: winsize
		if linux.ioctl(linux.STDOUT_FILENO, TIOCGWINSZ, cast(uintptr)&w) != 0 do return {}, false

		win := Screen_Size {
			h = uint(w.ws_row),
			w = uint(w.ws_col),
		}

		return win, true
	} else {
		return {}, false
	}
}

