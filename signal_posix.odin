#+build linux, darwin, netbsd, freebsd, openbsd
#+private
package termcl

import "base:runtime"
import "core:sys/posix"

_set_signal_handlers :: proc(set_sigcont := true) {
	// resets signal to default and raises it
	raise_default_signal_handler :: proc(signal: posix.Signal) {
		default_sigaction := posix.sigaction_t {
			sa_handler = auto_cast posix.SIG_DFL,
		}
		posix.sigaction(signal, &default_sigaction, nil)
		posix.raise(signal)
	}

	// restores terminal to its default state without destroying screen,
	// in case that job control is being used and the program is started again
	default_terminal_state :: proc "c" (signal: posix.Signal) {
		context = runtime.default_context()
		set_term_mode(&g_screen, .Restored)
		raise_default_signal_handler(signal)
	}

	// TODO: find out why restoring signal stops working the second time
	// restores the termcl screen configuration with all of its signal handlers
	restore_terminal_state :: proc "c" (signal: posix.Signal) {
		context = runtime.default_context()
		_set_signal_handlers(false)
		set_term_mode(&g_screen, g_screen.mode)
	}

	default_handler := posix.sigaction_t {
		sa_handler = default_terminal_state,
	}

	restore_handler := posix.sigaction_t {
		sa_handler = restore_terminal_state,
	}

	signals :: []posix.Signal{.SIGINT, .SIGTERM, .SIGQUIT, .SIGABRT, .SIGTSTP}
	for sig in signals {
		posix.sigaction(sig, &default_handler, nil)
	}

	if set_sigcont {
		posix.sigaction(.SIGCONT, &restore_handler, nil)
	}
}
