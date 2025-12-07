package termcl

import "base:runtime"
import "core:fmt"
import "core:strings"
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

Backend_VTable :: struct {
	init_screen:    proc(allocator: runtime.Allocator) -> Screen,
	destroy_screen: proc(screen: ^Screen),
	get_term_size:  proc() -> Window_Size,
	set_term_mode:  proc(screen: ^Screen, mode: Term_Mode),
	blit:           proc(win: ^Window),
	read:           proc(screen: ^Screen) -> Input,
	read_blocking:  proc(screen: ^Screen) -> Input,
}

@(private)
backend_vtable: Backend_VTable

/*
Initializes the terminal screen and creates a backup of the state the terminal
was in when this function was called.

Note: A screen **OUGHT** to be destroyed before exitting the program.
Destroying the screen causes the terminal to be restored to its previous state.
If the state is not restored your terminal might start misbehaving.
*/
init_screen :: proc(backend: Backend_VTable, allocator := context.allocator) -> Screen {
	set_backend(backend)
	return backend_vtable.init_screen(allocator)
}

/*
Restores the terminal to its original state and frees all memory allocated by the `t.Screen`
*/
destroy_screen :: proc(screen: ^Screen) {
	backend_vtable.destroy_screen(screen)
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
	backend_vtable.set_term_mode(screen, mode)
}

get_term_size :: proc() -> Window_Size {
	return backend_vtable.get_term_size()
}

/*
Sends instructions to terminal

**Inputs**
- `win`: A pointer to a window

*/
blit :: proc(win: ^Window) {
	backend_vtable.blit(win)

	// we need to keep the internal buffers in sync with the terminal size
	// so that we can render things correctly
	termsize := get_term_size()
	win_h, win_h_ok := win.height.?
	win_w, win_w_ok := win.width.?

	if !win_h_ok || !win_w_ok {
		if !win_h_ok do win_h = termsize.h
		if !win_w_ok do win_w = termsize.w

		if win.cell_buffer.height != win_h && win.cell_buffer.width != win_w {
			cellbuf_resize(&win.cell_buffer, win_h, win_w)
		}
	}
}

read :: proc(screen: ^Screen) -> Input {
	return backend_vtable.read(screen)
}

/*
Reads input from the terminal.
The read blocks execution until a value is read.
If you want it to not block, use `read` instead.
*/
read_blocking :: proc(screen: ^Screen) -> Input {
	return backend_vtable.read_blocking(screen)
}

/*
Set the current rendering backend

This sets the VTable for the functions that are in charge of dealing
with anything that is related with displaying the TUI to the screen.
*/
set_backend :: proc(backend: Backend_VTable) {
	if backend.set_term_mode == nil do panic("missing `set_term_mode` implementation")
	if backend.read_blocking == nil do panic("missing `read_blocking` implementation")
	if backend.read == nil do panic("missing `read` implementation")
	if backend.init_screen == nil do panic("missing `init_screen` implementation")
	if backend.get_term_size == nil do panic("missing `get_term_size` implementation")
	if backend.destroy_screen == nil do panic("missing `destroy_screen` implementation")
	if backend.blit == nil do panic("missing `blit` implementation")
	backend_vtable = backend
}

Cell :: struct {
	r:      rune,
	styles: Styles,
}

/*
used internally to store cells in before they're blitted to the screen
doing this allows us to reduce the amount of escape codes sent to the terminal
by inspecting state and only sending the states that changed
*/
Cell_Buffer :: struct {
	cells:         [dynamic]Cell,
	width, height: uint,
}

cellbuf_init :: proc(height, width: uint, allocator := context.allocator) -> Cell_Buffer {
	cb := Cell_Buffer {
		height = height,
		width  = width,
		cells  = make([dynamic]Cell, allocator),
	}

	cb_len := height * width
	resize(&cb.cells, cb_len)
	return cb
}

cellbuf_destroy :: proc(cb: ^Cell_Buffer) {
	delete(cb.cells)
	cb.height = 0
	cb.width = 0
}

cellbuf_resize :: proc(cb: ^Cell_Buffer, height, width: uint) {
	if cb.height == height && cb.width == width do return
	cb_len := height * width
	cb.height = height
	cb.width = width
	resize(&cb.cells, cb_len)
}

cellbuf_get :: proc(cb: Cell_Buffer, y, x: uint) -> Cell {
	constrained_x := x % cb.width
	constrained_y := y % cb.height
	return cb.cells[constrained_x + constrained_y * cb.width]
}

cellbuf_set :: proc(cb: ^Cell_Buffer, y, x: uint, cell: Cell) {
	constrained_x := x % cb.width
	constrained_y := y % cb.height
	cb.cells[constrained_x + constrained_y * cb.width] = cell
}

Styles :: struct {
	text: bit_set[Text_Style],
	fg:   Any_Color,
	bg:   Any_Color,
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
	y_offset, x_offset: uint,
	width, height:      Maybe(uint),
	cursor:             Cursor_Position,

	/*
	these styles are guaranteed because they're always the first thing
	pushed to the `seq_builder` after a `blit`
	 */
	curr_styles:        Styles,
	/*
	Double buffer used to store the cells in the terminal.
	The double buffer allows diffing between current and previous frames to reduce work required by the terminal.
	*/
	cell_buffer:        Cell_Buffer,
}

/*
Initialize a window.

**Inputs**
- `x`, `y`: offsets from (0, 0) coordinates of the terminal
- `height`, `width`: size in cells of the window

**Returns**
Initialized window. Window is freed with `destroy_window`

Note:
- A height or width with size zero makes so that nothing happens when the window is blitted
- A height or width of size nil makes it stretch to terminal length on that axis
*/
init_window :: proc(
	y, x: uint,
	height, width: Maybe(uint),
	allocator := context.allocator,
) -> Window {
	h, h_ok := height.?
	w, w_ok := width.?
	termsize := backend_vtable.get_term_size()
	cell_buffer := cellbuf_init(h if h_ok else termsize.h, w if w_ok else termsize.w, allocator)

	return Window {
		seq_builder = strings.builder_make(allocator = allocator),
		y_offset = y,
		x_offset = x,
		height = height,
		width = width,
		cell_buffer = cell_buffer,
	}
}

/*
Destroys all memory allocated by the window
*/
destroy_window :: proc(win: ^Window) {
	strings.builder_destroy(&win.seq_builder)
	cellbuf_destroy(&win.cell_buffer)
}

/*
Changes the size of the window.

**Inputs**
- `height`, `width`: size in cells of the window

NOTE:
- A height or width with size zero makes so that nothing happens when the window is blitted
- A height or width of size nil makes it stretch to terminal length on that axis
*/
resize_window :: proc(win: ^Window, height, width: Maybe(uint)) {
	if type_of(win) == ^Screen {
		win.height = nil
		win.width = nil
	} else {
		win.height = height
		win.width = width
	}

	h, h_ok := height.?
	w, w_ok := width.?

	termsize := backend_vtable.get_term_size()
	cellbuf_resize(&win.cell_buffer, h if h_ok else termsize.h, w if w_ok else termsize.w)
}

Window_Size :: struct {
	h, w: uint,
}

/*
Get the window size.

**Inputs**
- `screen`: the terminal screen

**Returns**
The screen size, where both the width and height are measured
by the number of terminal cells.
*/
get_window_size :: proc(win: ^Window) -> Window_Size {
	return Window_Size{h = win.cell_buffer.height, w = win.cell_buffer.width}
}

/*
Screen is a window for the entire terminal screen. It is a superset of `Window` and can be used anywhere a window can.
*/
Screen :: struct {
	using winbuf: Window,
	input_buf:    [512]byte,
	size:         Window_Size,
}

/*
Converts window coordinates to the global terminal coordinates
*/
global_coord_from_window :: proc(win: ^Window, y, x: uint) -> Cursor_Position {
	cursor_pos := Cursor_Position {
		x = x,
		y = y,
	}

	cursor_pos.y = (y % win.cell_buffer.height) + win.y_offset
	cursor_pos.x = (x % win.cell_buffer.width) + win.x_offset
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
	height := win.cell_buffer.height
	width := win.cell_buffer.width

	if height == 0 || width == 0 {
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
move_cursor :: proc(win: ^Window, y, x: uint) {
	win.cursor = {
		x = x,
		y = y,
	}
}

/*
Clear the screen.

**Inputs**
- `win`: the window whose contents will be cleared
- `mode`: how the clearing will be done
*/
clear :: proc(win: ^Window, mode: Clear_Mode) {
	height := win.cell_buffer.height
	width := win.cell_buffer.width

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

clear_line :: proc(win: ^Window, mode: Clear_Mode) {
	from, to: uint
	switch mode {
	case .After_Cursor:
		from = win.cursor.x + 1
		to = win.cell_buffer.width
	case .Before_Cursor:
		from = 0
		to = win.cursor.x - 1
	case .Everything:
		from = 0
		to = win.cell_buffer.width
	}

	for x in from ..< to {
		move_cursor(win, win.cursor.y, x)
		write_rune(win, ' ')
	}
}

// This is used internally to figure out and update where the cursor will be after a rune is written to the terminal
_get_cursor_pos_from_rune :: proc(win: ^Window, r: rune) -> [2]uint {
	height := win.cell_buffer.height
	width := win.cell_buffer.width

	new_pos := [2]uint{win.cursor.x + 1, win.cursor.y}
	if new_pos.x >= width {
		new_pos.x = 0
		new_pos.y += 1
	}

	if new_pos.y >= height {
		new_pos.y = 0
		new_pos.x = 0
	}
	return new_pos
}

/*
Writes a rune to the terminal
*/
write_rune :: proc(win: ^Window, r: rune) {
	curr_cell := Cell {
		r      = r,
		styles = win.curr_styles,
	}
	cellbuf_set(&win.cell_buffer, win.cursor.y, win.cursor.x, curr_cell)
	// the new cursor position has to be calculated after writing the rune
	// otherwise the rune will be misplaced when blitted to terminal
	new_pos := _get_cursor_pos_from_rune(win, r)
	move_cursor(win, new_pos.y, new_pos.x)
}

/*
Writes a string to the terminal
*/
write_string :: proc(win: ^Window, str: string) {
	// the string is written in chunks so that it doesn't overflow the
	// window in which it is contained
	for r in str {
		write_rune(win, r)
	}
}

/*
Write a formatted string to the window.
*/
writef :: proc(win: ^Window, format: string, args: ..any) {
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

set_text_style :: proc(win: ^Window, styles: bit_set[Text_Style]) {
	win.curr_styles.text = styles
}

set_color_style :: proc(win: ^Window, fg: Any_Color, bg: Any_Color) {
	win.curr_styles.fg = fg
	win.curr_styles.bg = bg
}

reset_styles :: proc(win: ^Window) {
	win.curr_styles = {}
}

Cursor_Position :: struct {
	y, x: uint,
}

/*
Get the current cursor position.
*/
get_cursor_position :: #force_inline proc(win: ^Window) -> Cursor_Position {
	return win.cursor
}
