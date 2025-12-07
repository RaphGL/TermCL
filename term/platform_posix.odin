#+build linux, darwin, netbsd, freebsd, openbsd
package term

import t ".."
import os "core:os/os2"
import "core:sys/posix"

Terminal_State :: struct {
	state: posix.termios,
}

get_terminal_state :: proc() -> (Terminal_State, bool) {
	termstate: posix.termios
	ok := posix.tcgetattr(posix.STDIN_FILENO, &termstate) == .OK
	return Terminal_State{state = termstate}, ok
}

change_terminal_mode :: proc(screen: ^t.Screen, mode: t.Term_Mode) {
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
		raw = orig_termstate.state
	}

	if posix.tcsetattr(posix.STDIN_FILENO, .TCSAFLUSH, &raw) != .OK {
		panic("failed to set new terminal state")
	}
}

raw_read :: proc(buf: []byte) -> (user_input: []byte, has_input: bool) {
	stdin_pollfd := posix.pollfd {
		fd     = posix.STDIN_FILENO,
		events = {.IN},
	}

	if posix.poll(&stdin_pollfd, 1, 8) > 0 {
		bytes_read, err := os.read_ptr(os.stdin, raw_data(buf), len(buf))
		if err != nil {
			panic("failing to get user input")
		}
		return buf[:bytes_read], true
	}

	return {}, false
}
