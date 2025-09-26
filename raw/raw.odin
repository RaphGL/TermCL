package raw

import "core:fmt"
import "core:strings"
import "core:terminal/ansi"

Text_Style :: enum {
	None,
	Bold,
	Italic,
	Underline,
	Crossed,
	Inverted,
	Dim,
}

/*
Colors from the original 8-color palette.
These should be supported everywhere this library is supported.
*/
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

/*
RGB color. This is should be supported by every modern terminal.
In case you need to support an older terminals, use `Color_8` instead
*/
Color_RGB :: [3]u8

Any_Color :: union {
	Color_8,
	Color_RGB,
}

/*
Indicates how to clear the window. 
*/
Clear_Mode :: enum {
	// Clear everything before the cursor
	Before_Cursor,
	// Clear everything after the cursor
	After_Cursor,
	// Clear the whole screen/window
	Everything,
}

/*
Move the cursor with 0-based index
*/
move_cursor :: proc(sb: ^strings.Builder, y, x: uint) {
	CURSOR_POSITION :: ansi.CSI + "%d;%dH"
	strings.write_string(sb, ansi.CSI)
	// x and y are shifted by one position so that programmers can keep using 0 based indexing
	strings.write_uint(sb, y + 1)
	strings.write_rune(sb, ';')
	strings.write_uint(sb, x + 1)
	strings.write_rune(sb, 'H')
}

/*
Hides the cursor so that it's not showed in the terminal
*/
hide_cursor :: proc(hide: bool) {
	SHOW_CURSOR :: ansi.CSI + "?25h"
	HIDE_CURSOR :: ansi.CSI + "?25l"
	fmt.print(HIDE_CURSOR if hide else SHOW_CURSOR)
}

/*
Sets the style used by the window.

**Inputs**
- `win`: the window whose text style will be changed
- `styles`: the styles that will be applied

Note: It is good practice to `reset_styles` when the styles are not needed anymore.
*/
set_text_style :: proc(sb: ^strings.Builder, styles: bit_set[Text_Style]) {
	SGR_BOLD :: ansi.CSI + ansi.BOLD + "m"
	SGR_DIM :: ansi.CSI + ansi.FAINT + "m"
	SGR_ITALIC :: ansi.CSI + ansi.ITALIC + "m"
	SGR_UNDERLINE :: ansi.CSI + ansi.UNDERLINE + "m"
	SGR_INVERTED :: ansi.CSI + ansi.INVERT + "m"
	SGR_CROSSED :: ansi.CSI + ansi.STRIKE + "m"

	if .Bold in styles do strings.write_string(sb, SGR_BOLD)
	if .Dim in styles do strings.write_string(sb, SGR_DIM)
	if .Italic in styles do strings.write_string(sb, SGR_ITALIC)
	if .Underline in styles do strings.write_string(sb, SGR_UNDERLINE)
	if .Inverted in styles do strings.write_string(sb, SGR_INVERTED)
	if .Crossed in styles do strings.write_string(sb, SGR_CROSSED)
}

@(private)
_set_color_8 :: proc(builder: ^strings.Builder, color: uint) {
	SGR_COLOR :: ansi.CSI + "%dm"
	strings.write_string(builder, ansi.CSI)
	strings.write_uint(builder, color)
	strings.write_rune(builder, 'm')
}

@(private)
_get_color_8_code :: proc(c: Color_8, is_bg: bool) -> uint {
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

@(private)
_set_color_rgb :: proc(builder: ^strings.Builder, color: Color_RGB, is_bg: bool) {
	strings.write_string(builder, ansi.CSI)
	strings.write_uint(builder, 48 if is_bg else 38)
	strings.write_string(builder, ";2;")
	strings.write_uint(builder, cast(uint)color.r)
	strings.write_rune(builder, ';')
	strings.write_uint(builder, cast(uint)color.g)
	strings.write_rune(builder, ';')
	strings.write_uint(builder, cast(uint)color.b)
	strings.write_rune(builder, 'm')
}

/*
Sets background and foreground colors based on the original 8-color palette

**Inputs**
- `win`: the window that will use the colors set
- `fg`: the foreground color, if the color is nil the default foreground color will be used 
*/
set_fg_color_style :: proc(sb: ^strings.Builder, fg: Any_Color) {
	DEFAULT_FG :: 39
	switch fg_color in fg {
	case Color_8:
		_set_color_8(sb, _get_color_8_code(fg_color, false))
	case Color_RGB:
		_set_color_rgb(sb, fg_color, false)
	case:
		_set_color_8(sb, DEFAULT_FG)
	}
}

/*
Sets background and foreground colors based on the original 8-color palette

**Inputs**
- `win`: the window that will use the colors set
- `bg`: the foreground color, if the color is nil the default foreground color will be used 
*/
set_bg_color_style :: proc(sb: ^strings.Builder, bg: Any_Color) {
	DEFAULT_BG :: 49
	switch bg_color in bg {
	case Color_8:
		_set_color_8(sb, _get_color_8_code(bg_color, true))
	case Color_RGB:
		_set_color_rgb(sb, bg_color, true)
	case:
		_set_color_8(sb, DEFAULT_BG)
	}
}

reset_styles :: proc(bg: ^strings.Builder) {
	strings.write_string(bg, ansi.CSI + "0m")
}

clear :: proc(sb: ^strings.Builder, mode: Clear_Mode) {
	switch mode {
	case .After_Cursor:
		strings.write_string(sb, ansi.CSI + "0J")
	case .Before_Cursor:
		strings.write_string(sb, ansi.CSI + "1J")
	case .Everything:
		strings.write_string(sb, ansi.CSI + "H" + ansi.CSI + "2J")
	}
}

/*
Clear the current line the cursor is in.

**Inputs**
- `win`: the window whose current line will be cleared
- `mode`: how the window will be cleared
*/
clear_line :: proc(sb: ^strings.Builder, mode: Clear_Mode) {
	switch mode {
	case .After_Cursor:
		strings.write_string(sb, ansi.CSI + "0K")
	case .Before_Cursor:
		strings.write_string(sb, ansi.CSI + "1K")
	case .Everything:
		strings.write_string(sb, ansi.CSI + "2K")
	}
}

/*
Ring the terminal bell. (potentially annoying to users :P)

Note: this rings the bell as soon as this procedure is called.
*/
ring_bell :: proc() {
	fmt.print("\a")
}

/*
Enable mouse to be able to respond to mouse inputs.

Note: Mouse is enabled by default if you're in raw mode.
*/
enable_mouse :: proc(enable: bool) {
	ANY_EVENT :: "\x1b[?1003"
	SGR_MOUSE :: "\x1b[?1006"

	if enable {
		fmt.print(ANY_EVENT + "h", SGR_MOUSE + "h")
	} else {
		fmt.print(ANY_EVENT + "l", SGR_MOUSE + "l")
	}
}

/*
Enables alternative screen buffer

This allows one to draw to the screen and then recover the screen the user had 
before the program started. Useful for TUI programs.
*/
enable_alt_buffer :: proc(enable: bool) {
	if enable {
		fmt.print("\x1b[?1049h")
	} else {
		fmt.print("\x1b[?1049l")
	}
}

