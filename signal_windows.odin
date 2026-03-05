#+private
package termcl

import "base:runtime"
import win "core:sys/windows"

_set_signal_handlers :: proc() {
	console_ctrl_handler :: proc "system" (ctrl_type: win.DWORD) -> win.BOOL {
		switch ctrl_type {
		case win.CTRL_C_EVENT, win.CTRL_CLOSE_EVENT, win.CTRL_BREAK_EVENT:
			context = runtime.default_context()
			destroy_screen(&g_screen)
		}
		return win.FALSE
	}

	win.SetConsoleCtrlHandler(console_ctrl_handler, win.TRUE)
}
