package termcl

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:terminal/ansi"
import "core:unicode/utf8"
import "raw"

Text_Style :: raw.Text_Style
Color_8 :: raw.Color_8
Color_RGB :: raw.Color_RGB
Any_Color :: raw.Any_Color
Clear_Mode :: raw.Clear_Mode

ring_bell :: raw.ring_bell
enable_mouse :: raw.enable_mouse
hide_cursor :: raw.hide_cursor
enable_alt_buffer :: raw.enable_alt_buffer

Cell :: struct {
	r:    rune,
	fg:   Any_Color,
	bg:   Any_Color,
	text: bit_set[Text_Style],
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
	// where the ascii escape sequence is stored
	seq_builder:        strings.Builder,
	curr_cells:         [dynamic]Cell,
	prev_cells:         [dynamic]Cell,
	y_offset, x_offset: uint,
	width, height:      Maybe(uint),
	cursor:             Cursor_Position,

	/*
	these styles are guaranteed because they're always the first thing
	pushed to the `seq_builder` after a `blit`
	 */
	curr_styles:        struct {
		text: bit_set[Text_Style],
		fg:   Any_Color,
		bg:   Any_Color,
	},
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
	cell_buf_size: uint
	// TODO: handle when only one of these are nil aka they should be the same size as terminal screen
	if height != nil && width != nil {
		cell_buf_size = height.? * width.?
	}

	prev_cells := make([dynamic]Cell, allocator)
	reserve(&prev_cells, cell_buf_size)
	curr_cells := make([dynamic]Cell, allocator)
	reserve(&curr_cells, cell_buf_size)

	return Window {
		seq_builder = strings.builder_make(allocator = allocator),
		y_offset = y,
		x_offset = x,
		height = height,
		width = width,
		prev_cells = prev_cells,
		curr_cells = curr_cells,
	}
}

/*
Destroys all memory allocated by the window
*/
destroy_window :: proc(win: ^Window) {
	strings.builder_destroy(&win.seq_builder)
	delete(win.curr_cells)
	delete(win.prev_cells)
}

/*
Sends instructions to terminal

**Inputs**
- `win`: A pointer to a window 

*/
blit :: proc(win: $T/^Window) {
	if win.height == 0 || win.width == 0 {
		return
	}
	fmt.print(strings.to_string(win.seq_builder))
	strings.builder_reset(&win.seq_builder)
	os.flush(os.stdout)

	// this is needed to prevent the window from sharing the same style as the terminal
	// this avoids messing up users' styles from one window to another
	set_text_style(win, win.curr_styles.text)
	set_color_style(win, win.curr_styles.fg, win.curr_styles.bg)
}

/*
Screen is a window for the entire terminal screen. It is a superset of `Window` and can be used anywhere a window can.
*/
Screen :: struct {
	using winbuf:       Window,
	original_termstate: Terminal_State,
	input_buf:          [512]byte,
	size:               Screen_Size,
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
	enable_alt_buffer(false)
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

	if width == 0 || height == 0 {
		return {}
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

	if !w_ok && !h_ok && (height == 0 || width == 0) {
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
	next := Cursor_Position {
		x = x,
		y = y,
	}
	if win.cursor == next {
		return
	}

	win.cursor = {
		x = x,
		y = y,
	}

	global_pos := global_coord_from_window(win, y, x)
	raw.move_cursor(&win.seq_builder, global_pos.y, global_pos.x)
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

	if !h_ok && !w_ok {
		raw.clear(&win.seq_builder, mode)
	} else {
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

		for _ in 0 ..< space_num {
			write_rune(win, ' ')
		}

		move_cursor(win, curr_pos.y, curr_pos.x)
	}
}

clear_line :: proc(win: $T/^Window, mode: Clear_Mode) {
	// TODO: implement clear line for windows with width and height not nil
	raw.clear_line(&win.seq_builder, mode)
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

		if str_slice_end == str_slice_start {
			break
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
		enable_alt_buffer(false)
		enable_mouse(false)

	case .Raw:
		enable_alt_buffer(true)
		raw.enable_mouse(true)
	}

	hide_cursor(false)
	// when changing modes some OSes (like windows) might put garbage that we don't care about 
	// in stdin potentially causing nonblocking reads to block on the first read, so to avoid this,
	// stdin is always flushed when the mode is changed
	os.flush(os.stdin)
}

set_text_style :: proc(win: $T/^Window, styles: bit_set[Text_Style]) {
	if styles != win.curr_styles.text {
		raw.set_text_style(&win.seq_builder, styles)
		win.curr_styles.text = styles
	}
}

set_color_style :: proc(win: $T/^Window, fg: Any_Color, bg: Any_Color) {
	if fg != win.curr_styles.fg {
		raw.set_fg_color_style(&win.seq_builder, fg)
		win.curr_styles.fg = fg
	}

	if bg != win.curr_styles.bg {
		raw.set_bg_color_style(&win.seq_builder, bg)
		win.curr_styles.bg = bg
	}
}

reset_styles :: proc(win: $T/^Window) {
	raw.reset_styles(&win.seq_builder)
	win.curr_styles = {}
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
	termsize, ok := get_term_size_via_syscall()
	if !ok {
		panic(
			`Failed to fetch terminal size. Your platform is probably not support
			Please create an issue: https://github.com/RaphGL/TermCL/issues`,
		)
	}

	return termsize
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

