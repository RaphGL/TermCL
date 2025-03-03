package termcl

import "core:fmt"
import "core:strings"

// control sequence introducer
CSI :: "\x1b["

Direction :: enum {
	Up,
	Down,
	Left,
	Right,
}

// changes the cursor's position relative to the current position
cursor_step :: proc(dir: bit_set[Direction], steps: uint) -> (seq: string, success: bool) {
	MOVE_CURSOR_UP :: CSI + "%dA"
	MOVE_CURSOR_DOWN :: CSI + "%dB"
	MOVE_CURSOR_RIGHT :: CSI + "%dC"
	MOVE_CURSOR_LEFT :: CSI + "%dD"

	escape_seq, err := strings.join(
		[]string {
			fmt.tprintf(MOVE_CURSOR_UP, steps) if .Up in dir else "",
			fmt.tprintf(MOVE_CURSOR_DOWN, steps) if .Down in dir else "",
			fmt.tprintf(MOVE_CURSOR_LEFT, steps) if .Left in dir else "",
			fmt.tprintf(MOVE_CURSOR_RIGHT, steps) if .Right in dir else "",
		},
		"",
		allocator = context.temp_allocator,
	)

	return escape_seq, err == .None
}

// changes the cursor's absolute position
cursor_move :: proc(y, x: uint) -> (seq: string) {
	CURSOR_POSITION :: CSI + "%d;%dH"

	escape_seq := fmt.tprintf(CURSOR_POSITION, y, x)
	return escape_seq
}

Text_Style :: enum {
	Bold,
	Italic,
	Underline,
	Crossed,
	Inverted,
	Dim,
}

set_text_style :: proc(styles: bit_set[Text_Style]) -> (seq: string, success: bool) {
	SGR_BOLD :: CSI + "1m"
	SGR_DIM :: CSI + "2m"
	SGR_ITALIC :: CSI + "3m"
	SGR_UNDERLINE :: CSI + "4m"
	SGR_INVERTED :: CSI + "7m"
	SGR_CROSSED :: CSI + "9m"

	escape_seq, err := strings.join(
		[]string {
			SGR_BOLD if .Bold in styles else "",
			SGR_DIM if .Dim in styles else "",
			SGR_ITALIC if .Italic in styles else "",
			SGR_UNDERLINE if .Underline in styles else "",
			SGR_INVERTED if .Inverted in styles else "",
			SGR_CROSSED if .Crossed in styles else "",
		},
		"",
		allocator = context.temp_allocator,
	)

	return escape_seq, err == .None
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
set_color_style_8 :: proc(fg: Color_8, bg: Maybe(Color_8)) -> (seq: string, success: bool) {
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

	fg_seq := fmt.tprintf(SGR_COLOR, get_color_code(fg, false))
	if bg == nil do return fg_seq, true


	full_color_seq, err := strings.join(
		[]string{fg_seq, fmt.tprintf(SGR_COLOR, get_color_code(bg.?, true))},
		"",
		allocator = context.temp_allocator,
	)

	return full_color_seq, err == .None
}

RGB_Color :: struct {
	r, g, b: u8,
}

set_color_style_rgb :: proc(fg: RGB_Color, bg: Maybe(RGB_Color)) -> (seq: string, success: bool) {
	RGB_FG_COLOR :: CSI + "38;2;%d;%d;%dm"
	RGB_BG_COLOR :: CSI + "48;2;%d;%d;%dm"

	fg_seq := fmt.tprintf(RGB_FG_COLOR, fg.r, fg.g, fg.b)
	if bg == nil do return fg_seq, true

	bg := bg.?
	final_seq, err := strings.join(
		[]string{fg_seq, fmt.tprintf(RGB_BG_COLOR, bg.r, bg.g, bg.b)},
		"",
		allocator = context.temp_allocator,
	)

	return final_seq, err == .None
}

set_color_style :: proc {
	set_color_style_rgb,
	set_color_style_8,
}

reset_styles :: proc() -> (seq: string) {
	return CSI + "0m"
}

clear_screen :: proc() -> (seq: string) {
	return CSI + "2J"
}

main :: proc() {
	seq0 := clear_screen()
	color, _ := set_color_style(
		RGB_Color{r = 0xFF, g = 0xFF, b = 0xF8},
		RGB_Color{r = 0xFF, b = 0xAB, g = 0x08},
	)
	seq := cursor_move(30, 23)
	seq1, _ := set_text_style({.Bold, .Italic, .Crossed})
	seq2 := reset_styles()
	fmt.println(seq0, seq, seq1, color, "hello world", seq2, "end of styles")
}

