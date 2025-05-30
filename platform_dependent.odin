package termcl

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/linux"
import "core:sys/posix"
import "core:sys/windows"

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
} else when ODIN_OS == .Windows {
	Terminal_State :: struct {
		mode:            windows.DWORD,
		input_codepage:  windows.CODEPAGE,
		input_mode:      windows.DWORD,
		output_codepage: windows.CODEPAGE,
		output_mode:     windows.DWORD,
	}
} else {
	Terminal_State :: struct {}
}

@(private)
get_terminal_state :: proc() -> (Terminal_State, bool) {
	when ODIN_OS in VALID_POSIX_OSES {
		termstate: posix.termios
		ok := posix.tcgetattr(posix.STDIN_FILENO, &termstate) == .OK
		return Terminal_State{state = termstate}, ok
	} else when ODIN_OS == .Windows {
		termstate: Terminal_State
		windows.GetConsoleMode(windows.HANDLE(os.stdout), &termstate.output_mode)
		termstate.output_codepage = windows.GetConsoleOutputCP()

		windows.GetConsoleMode(windows.HANDLE(os.stdin), &termstate.input_mode)
		termstate.input_codepage = windows.GetConsoleCP()

		return termstate, true
	} else {
		return {}, false
	}
}

@(private)
change_terminal_mode :: proc(screen: ^Screen, mode: Term_Mode) {
	termstate, ok := get_terminal_state()
	if !ok {
		panic("failed to get terminal state")
	}

	when ODIN_OS in VALID_POSIX_OSES {
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

		if posix.tcsetattr(posix.STDIN_FILENO, .TCSAFLUSH, &raw) != .OK {
			panic("failed to set new terminal state")
		}
	} else when ODIN_OS == .Windows {
		switch mode {
		case .Raw:
			termstate.output_mode |= windows.DISABLE_NEWLINE_AUTO_RETURN
			termstate.output_mode |= windows.ENABLE_VIRTUAL_TERMINAL_PROCESSING
			termstate.output_mode |= windows.ENABLE_PROCESSED_OUTPUT

			termstate.input_mode &= ~windows.ENABLE_PROCESSED_INPUT
			termstate.input_mode &= ~windows.ENABLE_ECHO_INPUT
			termstate.input_mode &= ~windows.ENABLE_LINE_INPUT
			termstate.input_mode |= windows.ENABLE_VIRTUAL_TERMINAL_INPUT

		case .Cbreak:
			termstate.output_mode |= windows.ENABLE_PROCESSED_OUTPUT
			termstate.output_mode |= windows.ENABLE_VIRTUAL_TERMINAL_PROCESSING

			termstate.input_mode |= windows.ENABLE_VIRTUAL_TERMINAL_INPUT
			termstate.input_mode &= ~windows.ENABLE_LINE_INPUT
			termstate.input_mode &= ~windows.ENABLE_ECHO_INPUT

		case .Restored:
			termstate = screen.original_termstate
		}

		if !windows.SetConsoleMode(windows.HANDLE(os.stdout), termstate.output_mode) ||
		   !windows.SetConsoleMode(windows.HANDLE(os.stdin), termstate.input_mode) {
			panic("failed to set new terminal state")
		}

		if mode != .Restored {
			windows.SetConsoleOutputCP(.UTF8)
			windows.SetConsoleCP(.UTF8)
		} else {
			windows.SetConsoleOutputCP(termstate.output_codepage)
			windows.SetConsoleCP(termstate.input_codepage)
		}

	}
}

get_term_size_via_syscall :: proc() -> (Screen_Size, bool) {
	when ODIN_OS == .Linux {
		winsize :: struct {
			ws_row, ws_col:       c.ushort,
			ws_xpixel, ws_ypixel: c.ushort,
		}

		// right now this is supported by all odin platforms
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
	} else when ODIN_OS == .Windows {
		sbi: windows.CONSOLE_SCREEN_BUFFER_INFO

		if !windows.GetConsoleScreenBufferInfo(windows.HANDLE(os.stdout), &sbi) {
			return {}, false
		}

		screen_size := Screen_Size {
			w = uint(sbi.srWindow.Right - sbi.srWindow.Left) + 1,
			h = uint(sbi.srWindow.Bottom - sbi.srWindow.Top) + 1,
		}

		return screen_size, true
	} else {
		return {}, false
	}
}

// Reads input from the terminal.
// The read blocks execution until a value is read.  
// If you want it to not block, use `read` instead.
read_blocking :: proc(screen: ^Screen) -> (user_input: Input, has_input: bool) {
	bytes_read, err := os.read_ptr(os.stdin, &screen.input_buf, len(screen.input_buf))
	if err != nil {
		fmt.eprintln("failing to get user input")
		os.exit(1)
	}

	return Input(screen.input_buf[:bytes_read]), bytes_read > 0
}


// Reads input from the terminal
// Reading is nonblocking, if you want it to block, use `read_blocking`
//
// The Input returned is a slice of bytes returned from the terminal.
// If you want to read a single character, you could just handle it directly without
// having to parse the input.
//
// example:
// ```odin
// input := read(&screen)
// if len(input) == 1 do switch input[0] {
//   case 'a':
//   case 'b': 
// }
// ```
read :: proc(screen: ^Screen) -> (user_input: Input, has_input: bool) {
	when ODIN_OS in VALID_POSIX_OSES {
		stdin_pollfd := posix.pollfd {
			fd     = posix.STDIN_FILENO,
			events = {.IN},
		}

		if posix.poll(&stdin_pollfd, 1, 8) > 0 {
			return read_blocking(screen)
		}
	} else when ODIN_OS == .Windows {
		num_events: u32
		if !windows.GetNumberOfConsoleInputEvents(windows.HANDLE(os.stdin), &num_events) {
			error_id := windows.GetLastError()
			error_msg: ^u16

			strsize := windows.FormatMessageW(
				windows.FORMAT_MESSAGE_ALLOCATE_BUFFER |
				windows.FORMAT_MESSAGE_FROM_SYSTEM |
				windows.FORMAT_MESSAGE_IGNORE_INSERTS,
				nil,
				error_id,
				windows.MAKELANGID(windows.LANG_NEUTRAL, windows.SUBLANG_DEFAULT),
				cast(^u16)&error_msg,
				0,
				nil,
			)
			windows.WriteConsoleW(windows.HANDLE(os.stdout), error_msg, strsize, nil, nil)
			windows.LocalFree(error_msg)
			panic("Failed to get console input events")
		}

		if num_events > 0 {
			return read_blocking(screen)
		}
	} else {
		#panic("nonblocking read is not supported in the target platform")
	}

	return
}

