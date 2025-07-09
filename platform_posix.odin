#+build linux, darwin, netbsd, freebsd, openbsd
package termcl

import "core:sys/posix"

Terminal_State :: struct {
	state: posix.termios,
}

@(private)
get_terminal_state :: proc() -> (Terminal_State, bool) {
	termstate: posix.termios
	ok := posix.tcgetattr(posix.STDIN_FILENO, &termstate) == .OK
	return Terminal_State{state = termstate}, ok
}

@(private)
change_terminal_mode :: proc(screen: ^Screen, mode: Term_Mode) {
	termstate, ok := get_terminal_state()
	if !ok {
		panic("failed to get terminal state")
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

	if posix.tcsetattr(posix.STDIN_FILENO, .TCSAFLUSH, &raw) != .OK {
		panic("failed to set new terminal state")
	}
}

read :: proc(screen: ^Screen) -> (user_input: Input, has_input: bool) {
	stdin_pollfd := posix.pollfd {
		fd     = posix.STDIN_FILENO,
		events = {.IN},
	}

	if posix.poll(&stdin_pollfd, 1, 8) > 0 {
		return read_blocking(screen)
	}

	return {}, false
}

