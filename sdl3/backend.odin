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

set_backend :: proc() {
	t.set_backend(
		t.Render_VTable {
			init_screen = init_screen,
			destroy_screen = destroy_screen,
			get_term_size = get_term_size,
			set_term_mode = set_term_mode,
			blit = blit,
			read = read,
		},
	)
}

// we don't do anything. for a GUI raw vs cooked doesn't make a different
// TODO: consider how to handle close window button pressed
set_term_mode :: proc(screen: ^t.Screen, mode: t.Term_Mode) {}

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

	screen.winbuf = t.init_window(0, 0, nil, nil)
	return screen
}

destroy_screen :: proc(screen: ^t.Screen) {
	t.destroy_window(&screen.winbuf)
	sdl3.DestroyWindow(g_window)
	sdl3.DestroyRenderer(g_renderer)
	sdl3.Quit()
}

// TODO: implement properly
// TODO: make cell size change depending on font instead
get_term_size :: proc() -> t.Window_Size {
	cell_width: f32 = 10
	cell_height: f32 = 16
	win_w, win_h: c.int
	sdl3.GetWindowSize(g_window, &win_w, &win_h)
	return t.Window_Size {
		h = uint(f32(win_h) / f32(cell_height)),
		w = uint(f32(win_w) / f32(cell_width)),
	}
}

blit :: proc(win: ^t.Window) {
	// TODO: fix subtype check
	// if type_of(win) == ^t.Screen {
	// 	panic("only `t.Screen` is supported for now")
	// }

	sdl3.SetRenderDrawColor(g_renderer, 0, 0, 0, 0xFF)
	sdl3.RenderClear(g_renderer)
	defer sdl3.RenderPresent(g_renderer)

	termsize := get_term_size()
	x_coord, y_coord: uint
	t.cellbuf_resize(&win.cell_buffer, termsize.h, termsize.w)

	for y in 0 ..< win.cell_buffer.height {
		y_coord = termsize.h * y
		for x in 0 ..< win.cell_buffer.width {
			x_coord = termsize.w * x
			curr_cell := t.cellbuf_get(win.cell_buffer, y, x)
			#partial switch color in curr_cell.styles.bg {
			case t.Color_RGB:
				sdl3.SetRenderDrawColor(g_renderer, color.r, color.g, color.b, 0xFF)
			}

			rect := sdl3.FRect {
				x = cast(f32)x_coord,
				y = cast(f32)y_coord,
				w = cast(f32)termsize.w,
				h = cast(f32)termsize.h,
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

