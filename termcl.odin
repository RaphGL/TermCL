package termcl

import "base:runtime"
import "core:fmt"
import "core:strings"

Screen :: struct {
	allocator: runtime.Allocator,
	code_seq:  string,
	failed:    bool,
}

init_screen :: proc(allocator := context.temp_allocator) -> Screen {
	return Screen{allocator = allocator, code_seq = ""}
}

blit_screen :: proc(screen: ^Screen) {
	fmt.println(screen.code_seq)
}

// control sequence introducer
CSI :: "\x1b["

Direction :: enum {
	Up,
	Down,
	Left,
	Right,
}

// changes the cursor's position relative to the current position
step_cursor :: proc(screen: ^Screen, dir: bit_set[Direction], steps: uint) {
	MOVE_CURSOR_UP :: CSI + "%dA"
	MOVE_CURSOR_DOWN :: CSI + "%dB"
	MOVE_CURSOR_RIGHT :: CSI + "%dC"
	MOVE_CURSOR_LEFT :: CSI + "%dD"

	escape_seq, err := strings.join(
		[]string {
			screen.code_seq,
			fmt.tprintf(MOVE_CURSOR_UP, steps) if .Up in dir else "",
			fmt.tprintf(MOVE_CURSOR_DOWN, steps) if .Down in dir else "",
			fmt.tprintf(MOVE_CURSOR_LEFT, steps) if .Left in dir else "",
			fmt.tprintf(MOVE_CURSOR_RIGHT, steps) if .Right in dir else "",
		},
		"",
		allocator = screen.allocator,
	)
	if err != .None do screen.failed = true

	screen.code_seq = escape_seq
}

// changes the cursor's absolute position
move_cursor :: proc(screen: ^Screen, y, x: uint) {
	CURSOR_POSITION :: CSI + "%d;%dH"

	escape_seq, err := strings.join(
		[]string{screen.code_seq, fmt.tprintf(CURSOR_POSITION, y, x)},
		"",
		allocator = screen.allocator,
	)
	if err != .None do screen.failed = true
	screen.code_seq = escape_seq
}

Text_Style :: enum {
	Bold,
	Italic,
	Underline,
	Crossed,
	Inverted,
	Dim,
}

set_text_style :: proc(screen: ^Screen, styles: bit_set[Text_Style]) {
	SGR_BOLD :: CSI + "1m"
	SGR_DIM :: CSI + "2m"
	SGR_ITALIC :: CSI + "3m"
	SGR_UNDERLINE :: CSI + "4m"
	SGR_INVERTED :: CSI + "7m"
	SGR_CROSSED :: CSI + "9m"

	escape_seq, err := strings.join(
		[]string {
			screen.code_seq,
			SGR_BOLD if .Bold in styles else "",
			SGR_DIM if .Dim in styles else "",
			SGR_ITALIC if .Italic in styles else "",
			SGR_UNDERLINE if .Underline in styles else "",
			SGR_INVERTED if .Inverted in styles else "",
			SGR_CROSSED if .Crossed in styles else "",
		},
		"",
		allocator = screen.allocator,
	)

	screen.code_seq = escape_seq
}

Color_8 :: enum {
	Black,
	Red,
	Green,
	Yellow,
	Blue,
	Magenta,
	Cyan,
	White,
}

// sets colors based from the original 8 color palette
set_color_style_8 :: proc(screen: ^Screen, fg: Color_8, bg: Maybe(Color_8)) {
	SGR_COLOR :: CSI + "%dm"

	get_color_code :: proc(c: Color_8, is_bg: bool) -> uint {
		code: uint
		switch c {
		case .Black:
			code = 30
		case .Red:
			code = 31
		case .Green:
			code = 32
		case .Yellow:
			code = 33
		case .Blue:
			code = 34
		case .Magenta:
			code = 35
		case .Cyan:
			code = 36
		case .White:
			code = 37
		}

		if is_bg do code += 10
		return code
	}

	context.allocator = screen.allocator
	final_seq := strings.join(
		[]string {
			screen.code_seq,
			fmt.tprintf(SGR_COLOR, get_color_code(fg, false)),
			fmt.tprintf(SGR_COLOR, get_color_code(bg.?, true) if bg != nil else 49), // 49 == default background,
		},
		"",
	)

	screen.code_seq = final_seq
}

RGB_Color :: struct {
	r, g, b: u8,
}

set_color_style_rgb :: proc(screen: ^Screen, fg: RGB_Color, bg: Maybe(RGB_Color)) {
	RGB_FG_COLOR :: CSI + "38;2;%d;%d;%dm"
	RGB_BG_COLOR :: CSI + "48;2;%d;%d;%dm"
	context.allocator = screen.allocator

	fg_seq, err := strings.join(
		[]string{screen.code_seq, fmt.tprintf(RGB_FG_COLOR, fg.r, fg.g, fg.b)},
		"",
	)
	if err != .None do screen.failed = true
	bg := bg.?
	final_seq: string
	final_seq, err = strings.join(
		[]string{fg_seq, fmt.tprintf(RGB_BG_COLOR, bg.r, bg.g, bg.b)},
		"",
	)
	if err != .None do screen.failed = true

	screen.code_seq = final_seq
}

reset_styles :: proc(screen: ^Screen) {
	seq, err := strings.join(
		[]string{screen.code_seq, CSI + "0m"},
		"",
		allocator = screen.allocator,
	)
	if err != .None do screen.failed = true
	screen.code_seq = seq
}

clear_screen :: proc(screen: ^Screen) {
	seq, err := strings.join(
		[]string{screen.code_seq, CSI + "2J"},
		"",
		allocator = screen.allocator,
	)
	if err != .None do screen.failed = true
	screen.code_seq = seq
}

write :: proc(screen: ^Screen, str: string) {
	seq, err := strings.join([]string{screen.code_seq, str}, "", allocator = screen.allocator)
	screen.code_seq = seq
}

