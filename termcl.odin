package termcl

import "base:runtime"
import "core:encoding/ansi"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"

// Sends instructions to terminal
blit :: proc(win: $T/^Window) {
	fmt.print(strings.to_string(win.seq_builder))
	strings.builder_reset(&win.seq_builder)
	os.flush(os.stdout)
}

Window :: struct {
	seq_builder:        strings.Builder,
	y_offset, x_offset: uint,
	width, height:      Maybe(uint),
	cursor:             Cursor_Position,
}

init_window :: proc(y, x: uint, height, width: Maybe(uint)) -> Window {
	return Window {
		seq_builder = strings.builder_make(),
		y_offset = y,
		x_offset = x,
		height = height,
		width = width,
	}
}

destroy_window :: proc(win: ^Window) {
	strings.builder_destroy(&win.seq_builder)
}

// Screen is a special derivate of Window, so it can mostly be used anywhere a Window can be used
Screen :: struct {
	using winbuf:       Window,
	allocator:          runtime.Allocator,
	original_termstate: Terminal_State,
	input_buf:          [512]byte,
}

// Initializes screen and saves terminal state
init_screen :: proc(allocator := context.allocator) -> Screen {
	context.allocator = allocator

	termstate, ok := get_terminal_state()
	if !ok {
		panic("failed to get terminal state")
	}

	return Screen {
		allocator = allocator,
		original_termstate = termstate,
		winbuf = init_window(0, 0, nil, nil),
	}
}

// Restores terminal settings and does necessary memory cleanup
destroy_screen :: proc(screen: ^Screen) {
	set_term_mode(screen, .Restored)
	destroy_window(&screen.winbuf)
}

// resolves coordinates from window coordinates to the global terminal coordinate
resolve_coordinates :: proc(win: $T/^Window, y, x: uint) -> (resolved_y, resolved_x: uint) {
	resolved_x = x
	resolved_y = y

	when type_of(win) == ^Screen {
		term_size := get_term_size(win)
		height := term_size.h
		width := term_size.w
	} else {
		height, h_ok := win.height.?
		width, w_ok := win.width.?

		if !w_ok && !h_ok {
			// this just makes the mod return the num passed to it
			height = x + 1
			width = y + 1
		}
	}

	resolved_y = (y % height) + win.y_offset
	resolved_x = (x % width) + win.x_offset
	return
}

// Changes the cursor's absolute position
move_cursor :: proc(win: $T/^Window, y, x: uint) {
	CURSOR_POSITION :: ansi.CSI + "%d;%dH"

	win.cursor = {
		x = x,
		y = y,
	}

	resolved_y, resolved_x := resolve_coordinates(win, y, x)
	// x and y are shifted by one position so that programmers can keep using 0 based indexing
	strings.write_string(
		&win.seq_builder,
		fmt.tprintf(CURSOR_POSITION, resolved_y + 1, resolved_x + 1),
	)
}

Text_Style :: enum {
	Bold,
	Italic,
	Underline,
	Crossed,
	Inverted,
	Dim,
}

// Hides the terminal cursor
hide_cursor :: proc(hide: bool) {
	SHOW_CURSOR :: ansi.CSI + "?25h"
	HIDE_CURSOR :: ansi.CSI + "?25l"
	fmt.print(HIDE_CURSOR if hide else SHOW_CURSOR)
}

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

// Sets background and foreground colors based on the original 8 color palette
set_color_style_8 :: proc(win: $T/^Window, fg: Maybe(Color_8), bg: Maybe(Color_8)) {
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
		&win.seq_builder,
		fmt.tprintf(SGR_COLOR, get_color_code(fg.?, false) if fg != nil else 39),
	) // 39 == default foreground
	strings.write_string(
		&win.seq_builder,
		fmt.tprintf(SGR_COLOR, get_color_code(bg.?, true) if bg != nil else 49), // 49 == default background
	)
}

RGB_Color :: struct {
	r, g, b: u8,
}

// Sets background and foreground colors based on the RGB values.
// The terminal has to support true colors for it to work.
set_color_style_rgb :: proc(win: $T/^Window, fg: RGB_Color, bg: Maybe(RGB_Color)) {
	RGB_FG_COLOR :: ansi.CSI + "38;2;%d;%d;%dm"
	RGB_BG_COLOR :: ansi.CSI + "48;2;%d;%d;%dm"

	strings.write_string(&win.seq_builder, fmt.tprintf(RGB_FG_COLOR, fg.r, fg.g, fg.b))
	if bg != nil {
		bg := bg.?
		strings.write_string(&win.seq_builder, fmt.tprintf(RGB_BG_COLOR, bg.r, bg.g, bg.b))
	}
}

// Sets foreground and background colors
set_color_style :: proc {
	set_color_style_8,
	set_color_style_rgb,
}

// Resets all styles previously set.
// It is good practice to reset after being done with a style as to prevent styles to be applied erroneously.
reset_styles :: proc(win: $T/^Window) {
	strings.write_string(&win.seq_builder, ansi.CSI + "0m")
}

Clear_Mode :: enum {
	Before_Cursor,
	After_Cursor,
	Everything,
}

// Clears screen starting from current line.
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
			move_cursor(win, 0, 0)
			space_num = width * height
		}

		for i in 0 ..< space_num {
			write_rune(win, ' ')
		}

		move_cursor(win, curr_pos.y, curr_pos.x)

	}
}

// Only clears the line the cursor is in
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

// Ring terminal bell. (potentially annoying to users :P)
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

// Writes a rune to the terminal
write_rune :: proc(win: $T/^Window, r: rune) {
	r_bytes, r_len := utf8.encode_rune(r)
	r_str := string(r_bytes[:r_len])
	new_pos := _get_cursor_pos_from_string(win, r_str)
	move_cursor(win, new_pos.y, new_pos.x)
	strings.write_rune(&win.seq_builder, r)
}

// Writes a string to the terminal
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

// Write a formatted string to the terminal
writef :: proc(win: $T/^Window, format: string, args: ..any) {
	str_start := strings.builder_len(win.seq_builder)
	str := fmt.sbprintf(&win.seq_builder, format, ..args)[str_start:]
	write_string(win, str)
}

// Write to the terminal
write :: proc {
	write_string,
	write_rune,
}


Term_Mode :: enum {
	// Raw mode, prevents the terminal from preprocessing inputs
	Raw,
	// Restores the mode the terminal was in before program started
	Restored,
	// A sort of "soft" raw mode that allows interrupts to still work
	Cbreak,
}

// Change terminal mode.
// 
// This changes how the terminal processes inputs.
// By default the terminal will process inputs, preventing you to have full access to user input.
// Changing the terminal mode will your program to process every input.
set_term_mode :: proc(screen: ^Screen, mode: Term_Mode) {
	change_terminal_mode(screen, mode)
	enable_mouse(mode == .Raw || mode == .Cbreak)
	hide_cursor(false)
	// when changing modes some OSes (like windows) might put garbage that we don't care about 
	// in stdin potentially causing nonblocking reads to block on the first read, so to avoid this,
	// stdin is always flushed when the mode is changed
	os.flush(os.stdin)
}

Screen_Size :: struct {
	h, w: uint,
}

// Get the terminal screen size.
//
// The width and height are measured in number of cells not pixels.
// Aka the same value you use with `move_mouse` and other functions.
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

// Enable mouse to be able to respond to mouse inputs.
// 
// It's enabled by default. This is here so you can opt-out of it or control when to enable or disable it.
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

// Get the current cursor position.
get_cursor_position :: #force_inline proc(win: $T/^Window) -> Cursor_Position {
	return win.cursor
}

