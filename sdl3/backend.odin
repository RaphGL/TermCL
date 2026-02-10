package termcl_sdl3

import t ".."
import "core:c"
import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import "vendor:sdl3"
import "vendor:sdl3/ttf"

Context :: struct {
	window:      ^sdl3.Window,
	renderer:    ^sdl3.Renderer,
	font:        ^ttf.Font,
	text_engine: ^ttf.TextEngine,
	font_cache:  map[rune]^ttf.Text,
}

render_ctx: Context

VTABLE :: t.Backend_VTable {
	init_screen    = init_screen,
	destroy_screen = destroy_screen,
	get_term_size  = get_term_size,
	set_term_mode  = set_term_mode,
	blit           = blit,
	read           = read,
	read_blocking  = read_blocking,
}

// NOTE: Cooked vs Raw modes are pretty much useless on a GUI
// so we do an no-op just here just so that programs don't crash attempting
// to call a non existent function
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

	if !sdl3.CreateWindowAndRenderer(
		"",
		1000,
		800,
		{.RESIZABLE},
		&render_ctx.window,
		&render_ctx.renderer,
	) {
		fmt.eprintln(sdl3.GetError())
		panic("failed to initialize virtual terminal")
	}

	set_font_from_slice(&screen, DEFAULT_FONT_BYTES, 14)

	return screen
}

@(rodata)
DEFAULT_FONT_BYTES := #load("./JetBrainsMono-Regular.ttf")

__init_font_engine :: proc(screen: ^t.Screen, font: ^ttf.Font) -> bool {
	if font == nil do return false
	render_ctx.font = font

	if render_ctx.text_engine == nil {
		render_ctx.text_engine = ttf.CreateRendererTextEngine(render_ctx.renderer)
		if render_ctx.text_engine == nil do return false
	}

	if render_ctx.font_cache == nil {
		render_ctx.font_cache = make(map[rune]^ttf.Text)
	} else {
		clear(&render_ctx.font_cache)
	}

	// NOTE: on sdl3 the window size will be dependent on the font
	// so we can only initialize the window once we know the font size
	if strings.builder_len(screen.seq_builder) == 0 {
		screen.winbuf = t.init_window(0, 0, nil, nil, screen.allocator)
	} else {
		t.resize_window(&screen.winbuf, nil, nil)
	}
	return true
}

set_font_from_slice :: proc(screen: ^t.Screen, font: []byte, size: f32) -> bool {
	font_stream := sdl3.IOFromConstMem(raw_data(font), len(font))
	if font_stream == nil do return false

	props := sdl3.CreateProperties()
	defer sdl3.DestroyProperties(props)
	sdl3.SetPointerProperty(props, ttf.PROP_FONT_CREATE_IOSTREAM_POINTER, font_stream)
	sdl3.SetFloatProperty(props, ttf.PROP_FONT_CREATE_SIZE_FLOAT, size)
	sdl3.SetBooleanProperty(props, ttf.PROP_FONT_CREATE_IOSTREAM_AUTOCLOSE_BOOLEAN, true)

	font := ttf.OpenFontWithProperties(props)
	return __init_font_engine(screen, font)
}

set_font :: proc(screen: ^t.Screen, path: string, size: f32) -> bool {
	path_cstr, path_cstr_err := strings.clone_to_cstring(path)
	if path_cstr_err != .None do return false
	defer delete(path_cstr)

	font := ttf.OpenFont(path_cstr, size)
	return __init_font_engine(screen, font)
}

destroy_screen :: proc(screen: ^t.Screen) {
	for _, text in render_ctx.font_cache {
		ttf.DestroyText(text)
	}
	ttf.CloseFont(render_ctx.font)
	ttf.DestroyRendererTextEngine(render_ctx.text_engine)
	t.destroy_window(&screen.winbuf)
	sdl3.DestroyWindow(render_ctx.window)
	sdl3.DestroyRenderer(render_ctx.renderer)
	sdl3.Quit()
}

get_cell_size :: proc() -> (cell_h, cell_w: uint) {
	cell_width, cell_height: c.int
	ttf.GetStringSize(render_ctx.font, " ", len(" "), &cell_width, &cell_height)
	return cast(uint)cell_height, cast(uint)cell_width
}

get_term_size :: proc() -> t.Window_Size {
	win_w, win_h: c.int
	sdl3.GetWindowSize(render_ctx.window, &win_w, &win_h)
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

	sdl3.SetRenderDrawColor(render_ctx.renderer, 0, 0, 0, 0xFF)
	sdl3.RenderClear(render_ctx.renderer)
	defer sdl3.RenderPresent(render_ctx.renderer)

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

			if curr_cell.r not_in render_ctx.font_cache {
				r, r_len := utf8.encode_rune(curr_cell.r)
				text := ttf.CreateText(
					render_ctx.text_engine,
					render_ctx.font,
					cast(cstring)raw_data(&r),
					cast(uint)r_len,
				)
				render_ctx.font_cache[curr_cell.r] = text
			}

			text := render_ctx.font_cache[curr_cell.r]
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

			sdl3.SetRenderDrawColor(
				render_ctx.renderer,
				bg_color.r,
				bg_color.g,
				bg_color.b,
				bg_color.a,
			)
			sdl3.RenderFillRect(render_ctx.renderer, &rect)
			ttf.SetTextColor(text, fg_color.r, fg_color.g, fg_color.b, fg_color.a)
			ttf.DrawRendererText(text, cast(f32)x_coord, cast(f32)y_coord)
		}
	}
}
