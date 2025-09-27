package termcl_sdl3

import t ".."
import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:unicode/utf8"
import "vendor:sdl3"
import "vendor:sdl3/ttf"

@(private)
g_window: ^sdl3.Window
@(private)
g_renderer: ^sdl3.Renderer
@(private)
g_font: ^ttf.Font
@(private)
g_text_engine: ^ttf.TextEngine
@(private)
g_font_cache: map[rune]^ttf.Text

set_backend :: proc() {
	t.set_backend(
		t.Render_VTable {
			init_screen = init_screen,
			destroy_screen = destroy_screen,
			get_term_size = get_term_size,
			set_term_mode = set_term_mode,
			blit = blit,
			read = read,
			read_blocking = read_blocking,
		},
	)
}

// we don't do anything. for a GUI raw vs cooked doesn't make a different
set_term_mode :: proc(screen: ^t.Screen, mode: t.Term_Mode) {}

init_screen :: proc(allocator := context.allocator) -> t.Screen {
	if !sdl3.InitSubSystem({.VIDEO, .EVENTS}) {
		fmt.eprintln(sdl3.GetError())
		panic("failed to initialize virtual terminal")
	}

	if !ttf.Init() {
		fmt.eprintln(sdl3.GetError())
		panic("failed to load font")
	}

	screen: t.Screen
	screen.allocator = allocator

	if !sdl3.CreateWindowAndRenderer("", 1000, 800, {.RESIZABLE}, &g_window, &g_renderer) {
		fmt.eprintln(sdl3.GetError())
		panic("failed to initialize virtual terminal")
	}

	// TODO: dont hardcode font
	g_font = ttf.OpenFont("/usr/share/fonts/TTF/JetBrainsMono-Regular.ttf", 15)
	g_text_engine = ttf.CreateRendererTextEngine(g_renderer)
	if g_text_engine == nil {
		fmt.eprintln(sdl3.GetError())
		panic("failed to initialize text renderer engine")
	}
	g_font_cache = make(map[rune]^ttf.Text)

	screen.winbuf = t.init_window(0, 0, nil, nil)
	return screen
}

destroy_screen :: proc(screen: ^t.Screen) {
	for _, text in g_font_cache {
		ttf.DestroyText(text)
	}
	ttf.CloseFont(g_font)
	ttf.DestroyRendererTextEngine(g_text_engine)
	t.destroy_window(&screen.winbuf)
	sdl3.DestroyWindow(g_window)
	sdl3.DestroyRenderer(g_renderer)
	sdl3.Quit()
}

get_cell_size :: proc() -> (cell_h, cell_w: uint) {
	cell_width, cell_height: c.int
	ttf.GetStringSize(g_font, " ", len(" "), &cell_width, &cell_height)
	return cast(uint)cell_height, cast(uint)cell_width
}

get_term_size :: proc() -> t.Window_Size {
	win_w, win_h: c.int
	sdl3.GetWindowSize(g_window, &win_w, &win_h)
	cell_h, cell_w := get_cell_size()

	return t.Window_Size{h = uint(f32(win_h) / f32(cell_h)), w = uint(f32(win_w) / f32(cell_w))}
}

blit :: proc(win: ^t.Window) {
	get_sdl_color :: proc(color: t.Any_Color) -> sdl3.Color {
		sdl_color: sdl3.Color
		switch c in color {
		case t.Color_RGB:
			sdl_color.rgb = c.rgb
			sdl_color.a = 0xFF

		case t.Color_8:
			switch c {
			case .Black:
				sdl_color = {0x28, 0x2A, 0x36, 0xFF}
			case .Blue:
				sdl_color = {0x62, 0x72, 0xA4, 0xFF}
			case .Cyan:
				sdl_color = {0x8B, 0xE9, 0xFD, 0xFF}
			case .Green:
				sdl_color = {0x50, 0xFA, 0x7B, 0xFF}
			case .Magenta:
				sdl_color = {0xFF, 0x79, 0xC6, 0xFF}
			case .Red:
				sdl_color = {0xFF, 0x55, 0x55, 0xFF}
			case .White:
				sdl_color = {0xF8, 0xF8, 0xF2, 0xFF}
			case .Yellow:
				sdl_color = {0xF1, 0xFA, 0x8C, 0xFF}
			}
		}
		return sdl_color
	}

	sdl3.SetRenderDrawColor(g_renderer, 0, 0, 0, 0xFF)
	sdl3.RenderClear(g_renderer)
	defer sdl3.RenderPresent(g_renderer)

	cell_h, cell_w := get_cell_size()
	x_coord, y_coord: uint
	for y in 0 ..< win.cell_buffer.height {
		y_coord = cell_h * y + cell_h * win.y_offset
		for x in 0 ..< win.cell_buffer.width {
			x_coord = cell_w * x + cell_w * win.x_offset
			curr_cell := t.cellbuf_get(win.cell_buffer, y, x)
			if curr_cell.r == {} {
				curr_cell.r = ' '
			}

			if curr_cell.r not_in g_font_cache {
				r, r_len := utf8.encode_rune(curr_cell.r)
				text := ttf.CreateText(
					g_text_engine,
					g_font,
					cast(cstring)raw_data(&r),
					cast(uint)r_len,
				)
				g_font_cache[curr_cell.r] = text
			}

			text := g_font_cache[curr_cell.r]
			rect := sdl3.FRect {
				x = cast(f32)x_coord,
				y = cast(f32)y_coord,
				w = cast(f32)cell_w,
				h = cast(f32)cell_h,
			}
			fg_color := get_sdl_color(
				curr_cell.styles.fg if curr_cell.styles.fg != nil else .White,
			)
			bg_color := get_sdl_color(
				curr_cell.styles.bg if curr_cell.styles.bg != nil else .Black,
			)

			sdl3.SetRenderDrawColor(g_renderer, bg_color.r, bg_color.g, bg_color.b, bg_color.a)
			sdl3.RenderFillRect(g_renderer, &rect)
			ttf.SetTextColor(text, fg_color.r, fg_color.g, fg_color.b, fg_color.a)
			ttf.DrawRendererText(text, cast(f32)x_coord, cast(f32)y_coord)
		}
	}
}

