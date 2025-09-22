package termcl_sdl3

import t ".."
import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import "vendor:sdl3"

@(private)
g_window: ^sdl3.Window
@(private)
g_renderer: ^sdl3.Renderer

init_screen :: proc(allocator := context.allocator) -> t.Screen {
	if !sdl3.InitSubSystem({.VIDEO, .EVENTS}) {
		fmt.eprintln(sdl3.GetError())
		panic("failed to initialize virtual terminal")
	}

	screen: t.Screen
	screen.allocator = allocator

	if !sdl3.CreateWindowAndRenderer("", 800, 600, {.RESIZABLE}, &g_window, &g_renderer) {
		fmt.eprintln(sdl3.GetError())
		panic("failed to initialize virtual terminal")
	}

	screen.winbuf = init_window(0, 0, nil, nil)
	return screen
}

destroy_screen :: proc(screen: ^t.Screen) {
	destroy_window(cast(^t.Window)screen)
	sdl3.DestroyWindow(g_window)
	sdl3.DestroyRenderer(g_renderer)
	sdl3.Quit()
}

init_window :: proc(
	y, x: uint,
	height, width: Maybe(uint),
	allocator := context.allocator,
) -> t.Window {
	h, h_ok := height.?
	w, w_ok := width.?
	win_w, win_h: c.int
	if !sdl3.GetWindowSize(g_window, &win_w, &win_h) {
		fmt.eprintln(sdl3.GetError())
		panic("failed to initialize window")
	}

	cell_buffer := t.cellbuf_init(h if h_ok else cast(uint)win_h, w if w_ok else cast(uint)win_w)

	return t.Window {
		y_offset = y,
		x_offset = x,
		height = height,
		width = width,
		cell_buffer = cell_buffer,
	}
}

destroy_window :: proc(win: ^t.Window) {
	t.cellbuf_destroy(&win.cell_buffer)
}

blit :: proc(win: ^t.Window) {
	// TODO: fix subtype check
	// if type_of(win) == ^t.Screen {
	// 	panic("only `t.Screen` is supported for now")
	// }

	sdl3.SetRenderDrawColor(g_renderer, 0, 0, 0, 0xFF)
	sdl3.RenderClear(g_renderer)
	defer sdl3.RenderPresent(g_renderer)

	win_w, win_h: c.int
	sdl3.GetWindowSize(g_window, &win_w, &win_h)

	x_coord, y_coord: f32
	// TODO: make cell size change depending on font instead
	cell_width: f32 = 10
	cell_height: f32 = 16
	t.cellbuf_resize(
		&win.cell_buffer,
		uint(f32(win_h) / f32(cell_height)),
		uint(f32(win_w) / f32(cell_width)),
	)

	for y in 0 ..< win.cell_buffer.height {
		y_coord = cell_height * f32(y)
		for x in 0 ..< win.cell_buffer.width {
			x_coord = cell_width * f32(x)
			curr_cell := t.cellbuf_get(win.cell_buffer, y, x)
			#partial switch color in curr_cell.styles.bg {
			case t.Color_RGB:
				sdl3.SetRenderDrawColor(g_renderer, color.r, color.g, color.b, 0xFF)
			}
			rect := sdl3.FRect {
				x = x_coord,
				y = y_coord,
				w = f32(cell_width),
				h = f32(cell_height),
			}
			sdl3.RenderFillRect(g_renderer, &rect)

		}
	}
}

main :: proc() {
	s := init_screen()
	defer destroy_screen(&s)

	for {
		defer blit(&s)
		input := read(&s)
		switch i in input {
		case t.Keyboard_Input:
			if i.key == .Q {
				return
			}
		case t.Mouse_Input:
		}
	}
}

