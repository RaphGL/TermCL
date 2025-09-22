package term

import t ".."
import "core:os"
import "core:sys/windows"

Terminal_State :: struct {
	mode:            windows.DWORD,
	input_codepage:  windows.CODEPAGE,
	input_mode:      windows.DWORD,
	output_codepage: windows.CODEPAGE,
	output_mode:     windows.DWORD,
}

get_terminal_state :: proc() -> (Terminal_State, bool) {
	termstate: Terminal_State
	windows.GetConsoleMode(windows.HANDLE(os.stdout), &termstate.output_mode)
	termstate.output_codepage = windows.GetConsoleOutputCP()

	windows.GetConsoleMode(windows.HANDLE(os.stdin), &termstate.input_mode)
	termstate.input_codepage = windows.GetConsoleCP()

	return termstate, true
}

change_terminal_mode :: proc(screen: ^t.Screen, mode: t.Term_Mode) {
	termstate, ok := get_terminal_state()
	if !ok {
		panic("failed to get terminal state")
	}

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

/*
Get terminal size

NOTE: this functional does syscalls to figure out the size of the terminal.
For most use cases, passing `t.Screen` to `get_window_size` achieves the same result
and doesn't need to do any system calls.

You should only use this function if you don't have access to `t.Screen` and still somehow
need to figure out the terminal size. Otherwise this function might or might not cause
your program to slow down a bit due to OS context switching.
*/
get_term_size :: proc() -> t.Window_Size {
	sbi: windows.CONSOLE_SCREEN_BUFFER_INFO

	if !windows.t.GetConsoleScreenBufferInfo(windows.HANDLE(os.stdout), &sbi) {
		panic("Failed to get terminal size")
	}

	screen_size := t.Window_Size {
		w = uint(sbi.srWindow.Right - sbi.srWindow.Left) + 1,
		h = uint(sbi.srWindow.Bottom - sbi.srWindow.Top) + 1,
	}

	return screen_size
}

raw_read :: proc(screen: ^t.Screen) -> (user_input: Input, has_input: bool) {
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
		bytes_read, err := os.read_ptr(os.stdin, &screen.input_buf, len(screen.input_buf))
		if err != nil {
			panic("failing to get user input")
		}
		return screen.input_buf[:bytes_read], true
	}

	return
}

