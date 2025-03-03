package termcl

import "base:runtime"
import "core:encoding/ansi"
import "core:fmt"
import "core:strings"

Screen :: struct {
	allocator:   runtime.Allocator,
	seq_builder: strings.Builder,
}

init_screen :: proc(allocator := context.temp_allocator) -> Screen {
	context.allocator = allocator
	return Screen{allocator = allocator, seq_builder = strings.builder_make()}
}

blit_screen :: proc(screen: ^Screen) {
	fmt.println(strings.to_string(screen.seq_builder))
}

Direction :: enum {
	Up,
	Down,
	Left,
	Right,
}

// changes the cursor's position relative to the current position
step_cursor :: proc(screen: ^Screen, dir: bit_set[Direction], steps: uint) {
	MOVE_CURSOR_UP :: ansi.CSI + "%dA"
	MOVE_CURSOR_DOWN :: ansi.CSI + "%dB"
	MOVE_CURSOR_RIGHT :: ansi.CSI + "%dC"
	MOVE_CURSOR_LEFT :: ansi.CSI + "%dD"

	if .Up in dir {
		strings.write_string(&screen.seq_builder, fmt.tprintf(MOVE_CURSOR_UP, steps))
	}
	if .Down in dir {
		strings.write_string(&screen.seq_builder, fmt.tprintf(MOVE_CURSOR_DOWN, steps))
	}
	if .Left in dir {
		strings.write_string(&screen.seq_builder, fmt.tprintf(MOVE_CURSOR_LEFT, steps))
	}
	if .Right in dir {
		strings.write_string(&screen.seq_builder, fmt.tprintf(MOVE_CURSOR_RIGHT, steps))
	}
}

// changes the cursor's absolute position
move_cursor :: proc(screen: ^Screen, y, x: uint) {
	CURSOR_POSITION :: ansi.CSI + "%d;%dH"
	strings.write_string(&screen.seq_builder, fmt.tprintf(CURSOR_POSITION, y, x))
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
	SGR_BOLD :: ansi.CSI + ansi.BOLD + "m"
	SGR_DIM :: ansi.CSI + ansi.FAINT + "m"
	SGR_ITALIC :: ansi.CSI + ansi.ITALIC + "m"
	SGR_UNDERLINE :: ansi.CSI + ansi.UNDERLINE + "m"
	SGR_INVERTED :: ansi.CSI + ansi.INVERT + "m"
	SGR_CROSSED :: ansi.CSI + ansi.STRIKE + "m"

	if .Bold in styles do strings.write_string(&screen.seq_builder, SGR_BOLD)
	if .Dim in styles do strings.write_string(&screen.seq_builder, SGR_DIM)
	if .Italic in styles do strings.write_string(&screen.seq_builder, SGR_ITALIC)
	if .Underline in styles do strings.write_string(&screen.seq_builder, SGR_UNDERLINE)
	if .Inverted in styles do strings.write_string(&screen.seq_builder, SGR_INVERTED)
	if .Crossed in styles do strings.write_string(&screen.seq_builder, SGR_CROSSED)
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
set_color_style_8 :: proc(screen: ^Screen, fg: Maybe(Color_8), bg: Maybe(Color_8)) {
	SGR_COLOR :: ansi.CSI + "%dm"

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

	strings.write_string(
		&screen.seq_builder,
		fmt.tprintf(SGR_COLOR, get_color_code(fg.?, false) if fg != nil else 39),
	) // 39 == default foreground
	strings.write_string(
		&screen.seq_builder,
		fmt.tprintf(SGR_COLOR, get_color_code(bg.?, true) if bg != nil else 49), // 49 == default background
	)
}

RGB_Color :: struct {
	r, g, b: u8,
}

set_color_style_rgb :: proc(screen: ^Screen, fg: RGB_Color, bg: Maybe(RGB_Color)) {
	RGB_FG_COLOR :: ansi.CSI + "38;2;%d;%d;%dm"
	RGB_BG_COLOR :: ansi.CSI + "48;2;%d;%d;%dm"

	strings.write_string(&screen.seq_builder, fmt.tprintf(RGB_FG_COLOR, fg.r, fg.g, fg.b))
	if bg != nil {
		bg := bg.?
		strings.write_string(&screen.seq_builder, fmt.tprintf(RGB_BG_COLOR, bg.r, bg.g, bg.b))
	}
}

reset_styles :: proc(screen: ^Screen) {
	strings.write_string(&screen.seq_builder, ansi.CSI + "0m")
}

clear_screen :: proc(screen: ^Screen) {
	strings.write_string(&screen.seq_builder, ansi.CSI + "2J")
}

write :: proc(screen: ^Screen, str: string) {
	strings.write_string(&screen.seq_builder, str)
}

