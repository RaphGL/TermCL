package termcl

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:terminal/ansi"
import "core:unicode/utf8"

/*
Sends instructions to terminal

**Inputs**
- `win`: A pointer to a window 

*/
blit :: proc(win: $T/^Window) {
	fmt.print(strings.to_string(win.seq_builder))
	strings.builder_reset(&win.seq_builder)
	os.flush(os.stdout)
}

/*
A bounded "drawing" box in the terminal.

**Fields**
- `allocator`: the allocator used by the window 
- `seq_builder`: where the escape sequences are stored
- `x_offset`, `y_offset`: offsets from (0, 0) coordinates of the terminal
- `width`, `height`: sizes for the window
- `cursor`: where the cursor was last when this window was interacted with 
*/
Window :: struct {
	allocator:          runtime.Allocator,
	seq_builder:        strings.Builder,
	y_offset, x_offset: uint,
	width, height:      Maybe(uint),
	cursor:             Cursor_Position,
}

/*
Initialize a window.

**Inputs**
- `x`, `y`: offsets from (0, 0) coordinates of the terminal
- `height`, `width`: size of the window

**Returns**
Initialized window. Window is freed with `destroy_window`

Note:
You should never init a window with size zero unless you're going to assign the sizes later.
using a window with width and height of zero will result in a division by zero.
*/
init_window :: proc(
	y, x: uint,
	height, width: Maybe(uint),
	allocator := context.allocator,
) -> Window {
	return Window {
		seq_builder = strings.builder_make(allocator = allocator),
		y_offset = y,
		x_offset = x,
		height = height,
		width = width,
	}
}

/*
Destroys all memory allocated by the window
*/
destroy_window :: proc(win: ^Window) {
	strings.builder_destroy(&win.seq_builder)
}

/*
Screen is a window for the entire terminal screen. It is a superset of `Window` and can be used anywhere a window can.
*/
Screen :: struct {
	using winbuf:       Window,
	original_termstate: Terminal_State,
	input_buf:          [512]byte,
}

/*
Initializes the terminal screen and creates a backup of the state the terminal
was in when this function was called.

Note: A screen **OUGHT** to be destroyed before exitting the program.
Destroying the screen causes the terminal to be restored to its previous state.
If the state is not restored your terminal might start misbehaving.
*/
init_screen :: proc(allocator := context.allocator) -> Screen {
	context.allocator = allocator

	termstate, ok := get_terminal_state()
	if !ok {
		panic("failed to get terminal state")
	}

	return Screen {
		original_termstate = termstate,
		winbuf = init_window(0, 0, nil, nil, allocator = allocator),
	}
}

/*
Restores the terminal to its original state and frees all memory allocated by the `Screen`
*/
destroy_screen :: proc(screen: ^Screen) {
	set_term_mode(screen, .Restored)
	destroy_window(&screen.winbuf)
	fmt.print("\x1b[?1049l")
}

/*
Converts window coordinates to the global terminal coordinates
*/
global_coord_from_window :: proc(win: $T/^Window, y, x: uint) -> Cursor_Position {
	cursor_pos := Cursor_Position {
		x = x,
		y = y,
	}

	when type_of(win) == ^Screen {
		term_size := get_term_size(win)
		height := term_size.h
		width := term_size.w
	} else {
		height, h_ok := win.height.?
		width, w_ok := win.width.?

		if !w_ok && !h_ok {
			return cursor_pos
		}
	}

	cursor_pos.y = (y % height) + win.y_offset
	cursor_pos.x = (x % width) + win.x_offset
	return cursor_pos
}

/*
Converts from global coordinates to window coordinates
*/
window_coord_from_global :: proc(
	win: ^Window,
	y, x: uint,
) -> (
	cursor_pos: Cursor_Position,
	in_window: bool,
) {
	height, h_ok := win.height.?
	width, w_ok := win.width.?

	if !w_ok && !h_ok {
		return
	}

	if y < win.y_offset || y >= win.y_offset + height {
		return
	}

	if x < win.x_offset || x >= win.x_offset + width {
		return
	}

	cursor_pos.y = (y - win.y_offset) % height
	cursor_pos.x = (x - win.x_offset) % width
	in_window = true
	return
}

/*
Changes the position of the window cursor
*/
move_cursor :: proc(win: $T/^Window, y, x: uint) {
	win.cursor = {
		x = x,
		y = y,
	}

	global_cursor_pos := global_coord_from_window(win, y, x)
	CURSOR_POSITION :: ansi.CSI + "%d;%dH"
	strings.write_string(&win.seq_builder, ansi.CSI)
	// x and y are shifted by one position so that programmers can keep using 0 based indexing
	strings.write_uint(&win.seq_builder, global_cursor_pos.y + 1)
	strings.write_rune(&win.seq_builder, ';')
	strings.write_uint(&win.seq_builder, global_cursor_pos.x + 1)
	strings.write_rune(&win.seq_builder, 'H')
}

Text_Style :: enum {
	Bold,
	Italic,
	Underline,
	Crossed,
	Inverted,
	Dim,
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
set_text_style :: proc(win: $T/^Window, styles: bit_set[Text_Style]) {
	SGR_BOLD :: ansi.CSI + ansi.BOLD + "m"
	SGR_DIM :: ansi.CSI + ansi.FAINT + "m"
	SGR_ITALIC :: ansi.CSI + ansi.ITALIC + "m"
	SGR_UNDERLINE :: ansi.CSI + ansi.UNDERLINE + "m"
	SGR_INVERTED :: ansi.CSI + ansi.INVERT + "m"
	SGR_CROSSED :: ansi.CSI + ansi.STRIKE + "m"

	if .Bold in styles do strings.write_string(&win.seq_builder, SGR_BOLD)
	if .Dim in styles do strings.write_string(&win.seq_builder, SGR_DIM)
	if .Italic in styles do strings.write_string(&win.seq_builder, SGR_ITALIC)
	if .Underline in styles do strings.write_string(&win.seq_builder, SGR_UNDERLINE)
	if .Inverted in styles do strings.write_string(&win.seq_builder, SGR_INVERTED)
	if .Crossed in styles do strings.write_string(&win.seq_builder, SGR_CROSSED)
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
Sets background and foreground colors based on the original 8-color palette

**Inputs**
- `win`: the window that will use the colors set
- `fg`: the foreground color, if the color is nil the default foreground color will be used 
- `bg`: the background color, if the color is nil the default background color will be used 
*/
set_color_style_8 :: proc(win: $T/^Window, fg: Maybe(Color_8), bg: Maybe(Color_8)) {
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

	SGR_COLOR :: ansi.CSI + "%dm"
	set_color :: proc(builder: ^strings.Builder, color: uint) {
		strings.write_string(builder, ansi.CSI)
		strings.write_uint(builder, color)
		strings.write_rune(builder, 'm')
	}

	DEFAULT_FG :: 39
	DEFAULT_BG :: 49
	set_color(&win.seq_builder, get_color_code(fg.?, false) if fg != nil else DEFAULT_FG)
	set_color(&win.seq_builder, get_color_code(bg.?, true) if bg != nil else DEFAULT_BG)
}

/*
RGB color. This is should be supported by every modern terminal.
In case you need to support an older terminals, use `Color_8` instead
*/
RGB_Color :: struct {
	r, g, b: u8,
}

/*
Sets background and foreground colors based on the RGB values.

**Inputs**
- `win`: the window that will use the colors set
- `fg`: the foreground color, if the color is nil the default foreground color will be used 
- `bg`: the background color, if the color is nil the default background color will be used 

Note: The terminal has to support true colors for it to work.
*/
set_color_style_rgb :: proc(win: $T/^Window, fg: Maybe(RGB_Color), bg: Maybe(RGB_Color)) {
	RGB_FG_COLOR :: ansi.CSI + "38;2;%d;%d;%dm"
	RGB_BG_COLOR :: ansi.CSI + "48;2;%d;%d;%dm"

	set_color :: proc(builder: ^strings.Builder, is_fg: bool, color: RGB_Color) {
		strings.write_string(builder, ansi.CSI)
		strings.write_uint(builder, 38 if is_fg else 48)
		strings.write_string(builder, ";2;")
		strings.write_uint(builder, cast(uint)color.r)
		strings.write_rune(builder, ';')
		strings.write_uint(builder, cast(uint)color.g)
		strings.write_rune(builder, ';')
		strings.write_uint(builder, cast(uint)color.b)
		strings.write_rune(builder, 'm')
	}

	fg_color, has_fg := fg.?
	bg_color, has_bg := bg.?

	if !has_fg || !has_bg {
		set_color_style_8(win, nil, nil)
	}

	if has_fg do set_color(&win.seq_builder, true, fg_color)
	if has_bg do set_color(&win.seq_builder, false, bg_color)

}

/*
Sets background and foreground colors.

**Inputs**
- `win`: the window that will use the colors set
- `fg`: the foreground color, if the color is nil the default foreground color will be used 
- `bg`: the background color, if the color is nil the default background color will be used 
*/
set_color_style :: proc {
	set_color_style_8,
	set_color_style_rgb,
}

/*
Resets all styles previously set.
It is good practice to reset after being done with a style as to prevent styles to be applied erroneously.

**Inputs**
- `win`: the window whose styles will be reset
*/
reset_styles :: proc(win: $T/^Window) {
	strings.write_string(&win.seq_builder, ansi.CSI + "0m")
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
Clear the screen.

**Inputs**
- `win`: the window whose contents will be cleared
- `mode`: how the clearing will be done
*/
clear :: proc(win: $T/^Window, mode: Clear_Mode) {
	height, h_ok := win.height.?
	width, w_ok := win.width.?

	if !h_ok && !w_ok do switch mode {
	case .After_Cursor:
		strings.write_string(&win.seq_builder, ansi.CSI + "0J")
	case .Before_Cursor:
		strings.write_string(&win.seq_builder, ansi.CSI + "1J")
	case .Everything:
		strings.write_string(&win.seq_builder, ansi.CSI + "H" + ansi.CSI + "2J")
		win.cursor = {0, 0}
	}
	else {
		// we compute the number of spaces required to clear a window and then
		// let the write_rune function take care of properly moving the cursor
		// through its own window isolation logic
		space_num: uint
		curr_pos := get_cursor_position(win)

		switch mode {
		case .After_Cursor:
			space_in_same_line := width - (win.cursor.x + 1)
			space_after_same_line := width * (height - ((win.cursor.y + 1) % height))
			space_num = space_in_same_line + space_after_same_line
			move_cursor(win, curr_pos.y, curr_pos.x + 1)
		case .Before_Cursor:
			space_num = win.cursor.x + 1 + win.cursor.y * width
			move_cursor(win, 0, 0)
		case .Everything:
			space_num = (width + 1) * height
			move_cursor(win, 0, 0)
		}

		for i in 0 ..< space_num {
			write_rune(win, ' ')
		}

		move_cursor(win, curr_pos.y, curr_pos.x)

	}
}

/*
Clear the current line the cursor is in.

**Inputs**
- `win`: the window whose current line will be cleared
- `mode`: how the window will be cleared
*/
clear_line :: proc(win: $T/^Window, mode: Clear_Mode) {
	switch mode {
	case .After_Cursor:
		strings.write_string(&win.seq_builder, ansi.CSI + "0K")
	case .Before_Cursor:
		strings.write_string(&win.seq_builder, ansi.CSI + "1K")
	case .Everything:
		strings.write_string(&win.seq_builder, ansi.CSI + "2K")
	}
}

/*
Ring the terminal bell. (potentially annoying to users :P)

Note: this rings the bell as soon as this procedure is called.
*/
ring_bell :: proc() {
	fmt.print("\a")
}

// This is used internally to figure out and update where the cursor will be after a string is written to the terminal
_get_cursor_pos_from_string :: proc(win: $T/^Window, str: string) -> [2]uint {
	calculate_cursor_pos :: proc(
		cursor: ^Cursor_Position,
		height, width: uint,
		str: string,
	) -> [2]uint {
		new_pos := [2]uint{cursor.x, cursor.y}
		for r in str {
			if new_pos.y >= height && r == '\n' {
				new_pos.x = 0
				continue
			}

			if new_pos.x >= width || r == '\n' {
				new_pos.y += 1
				new_pos.x = 0
			} else {
				new_pos.x += 1
			}
		}
		return new_pos
	}

	when type_of(win) == ^Screen {
		term_size := get_term_size(win)
		height := term_size.h
		width := term_size.w
		return calculate_cursor_pos(&win.cursor, height, width, str)
	} else {
		height, h_ok := win.height.?
		width, w_ok := win.width.?

		if h_ok && w_ok {
			return calculate_cursor_pos(&win.cursor, height, width, str)
		} else {
			return [2]uint{win.cursor.x, win.cursor.y}
		}
	}
}

/*
Writes a rune to the terminal
*/
write_rune :: proc(win: $T/^Window, r: rune) {
	strings.write_rune(&win.seq_builder, r)
	// the new cursor position has to be calculated after writing the rune
	// otherwise the rune will be misplaced when blitted to terminal
	r_bytes, r_len := utf8.encode_rune(r)
	r_str := string(r_bytes[:r_len])
	new_pos := _get_cursor_pos_from_string(win, r_str)
	move_cursor(win, new_pos.y, new_pos.x)
}

/*
Writes a string to the terminal
*/
write_string :: proc(win: $T/^Window, str: string) {
	when type_of(win) == ^Screen {
		term_size := get_term_size(win)
		win_width := term_size.w
	} else {
		win_width, w_ok := win.width.?
		if !w_ok {
			strings.write_string(&win.seq_builder, str)
			return
		}
	}

	// the string is written in chunks so that it doesn't overflow the  
	// window in which it is contained
	str_slice_start: uint
	for str_slice_start < len(str) {
		chunk_len := win_width - win.cursor.x
		str_slice_end := str_slice_start + chunk_len
		if str_slice_end > cast(uint)len(str) {
			str_slice_end = len(str)
		}

		str_slice := str[str_slice_start:str_slice_end]
		strings.write_string(&win.seq_builder, str_slice)

		str_slice_start = str_slice_end

		new_pos := _get_cursor_pos_from_string(win, str_slice)
		win.cursor.x = new_pos.x
		win.cursor.y = new_pos.y
		// we try an empty string so that we can compute starting from the next character 
		// that's going to be inserted
		new_pos = _get_cursor_pos_from_string(win, " ")
		move_cursor(win, new_pos.y, new_pos.x)
	}
}

/*
Write a formatted string to the window.
*/
writef :: proc(win: $T/^Window, format: string, args: ..any) {
	str_builder: strings.Builder
	_, err := strings.builder_init(&str_builder, allocator = win.allocator)
	if err != nil {
		panic("Failed to get more memory for format string")
	}
	defer strings.builder_destroy(&str_builder)
	str := fmt.sbprintf(&str_builder, format, ..args)
	write_string(win, str)
}

/*
Write to the window.
*/
write :: proc {
	write_string,
	write_rune,
}


// A terminal mode. This changes how the terminal will preprocess inputs and handle signals.
Term_Mode :: enum {
	// Raw mode, prevents the terminal from preprocessing inputs and handling signals
	Raw,
	// Restores the terminal to the state it was in before program started
	Restored,
	// A sort of "soft" raw mode that still allows the terminal to handle signals
	Cbreak,
}

/*
Change terminal mode.

This changes how the terminal behaves.
By default the terminal will preprocess inputs and handle handle signals,
preventing you to have full access to user input.

**Inputs**
- `screen`: the terminal screen
- `mode`: how terminal should behave from now on
*/
set_term_mode :: proc(screen: ^Screen, mode: Term_Mode) {
	change_terminal_mode(screen, mode)

	#partial switch mode {
	case .Restored:
		// enables main screen buffer
		fmt.print("\x1b[?1049l")
		enable_mouse(false)

	case:
		// enables alternate screen buffer
		fmt.print("\x1b[?1049h")
		enable_mouse(true)
	}

	hide_cursor(false)
	// when changing modes some OSes (like windows) might put garbage that we don't care about 
	// in stdin potentially causing nonblocking reads to block on the first read, so to avoid this,
	// stdin is always flushed when the mode is changed
	os.flush(os.stdin)
}

Screen_Size :: struct {
	h, w: uint,
}

/*
Get the terminal screen size.

**Inputs**
- `screen`: the terminal screen

**Returns**
The screen size, where both the width and height are measured
by the number of terminal cells.
*/
get_term_size :: proc(screen: ^Screen) -> Screen_Size {
	win, ok := get_term_size_via_syscall()
	if ok do return win

	curr_pos := get_cursor_position(screen)

	MAX_CURSOR_POSITION :: ansi.CSI + "9999;9999H"
	fmt.print(MAX_CURSOR_POSITION)
	pos := get_cursor_position(screen)

	// restore cursor position
	fmt.printf(ansi.CSI + "%d;%dH", curr_pos.y, curr_pos.x)

	return Screen_Size{w = pos.x, h = pos.y}
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

Cursor_Position :: struct {
	y, x: uint,
}

/*
Get the current cursor position.
*/
get_cursor_position :: #force_inline proc(win: $T/^Window) -> Cursor_Position {
	return win.cursor
}

