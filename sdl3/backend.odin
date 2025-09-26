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

	// TODO: dont hardcode font
	g_font = ttf.OpenFont("/usr/share/fonts/TTF/JetBrainsMono-Regular.ttf", 15)

	if !sdl3.CreateWindowAndRenderer("", 1000, 800, {.RESIZABLE}, &g_window, &g_renderer) {
		fmt.eprintln(sdl3.GetError())
		panic("failed to initialize virtual terminal")
	}

	screen.winbuf = t.init_window(0, 0, nil, nil)
	return screen
}

destroy_screen :: proc(screen: ^t.Screen) {
	ttf.CloseFont(g_font)
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

	termsize := get_term_size()
	x_coord, y_coord: uint

	text_textures := make(map[t.Styles]map[rune]^sdl3.Texture, context.temp_allocator)
	defer {
		for _, cell in text_textures {
			for _, texture in cell {
				sdl3.DestroyTexture(texture)
			}
		}
		free_all(context.temp_allocator)
	}

	cell_h, cell_w := get_cell_size()
	for y in 0 ..< win.cell_buffer.height {
		y_coord = cast(uint)cell_h * y
		for x in 0 ..< win.cell_buffer.width {
			x_coord = cast(uint)cell_w * x
			curr_cell := t.cellbuf_get(win.cell_buffer, y, x)

			if curr_cell.styles not_in text_textures {
				text_textures[curr_cell.styles] = make(
					map[rune]^sdl3.Texture,
					context.temp_allocator,
				)
			}
			if curr_cell.r not_in text_textures[curr_cell.styles] {
				fg_color := get_sdl_color(
					curr_cell.styles.fg if curr_cell.styles.fg != nil else .White,
				)
				bg_color := get_sdl_color(
					curr_cell.styles.bg if curr_cell.styles.bg != nil else .Black,
				)

				rune_surface := ttf.RenderGlyph_Shaded(
					g_font,
					cast(u32)curr_cell.r,
					fg_color,
					bg_color,
				)
				rune_texture := sdl3.CreateTextureFromSurface(g_renderer, rune_surface)
				sdl3.DestroySurface(rune_surface)
				runes_map := &text_textures[curr_cell.styles]
				runes_map[curr_cell.r] = rune_texture
			}

			cell := text_textures[curr_cell.styles][curr_cell.r]
			rect := sdl3.FRect {
				x = cast(f32)x_coord,
				y = cast(f32)y_coord,
				w = cast(f32)cell_w,
				h = cast(f32)cell_h,
			}
			sdl3.RenderTexture(g_renderer, cell, nil, &rect)
		}
	}
}

main :: proc() {
	set_backend()
	s := init_screen()
	defer destroy_screen(&s)

	for {
		t.set_color_style(&s, nil, nil)
		t.clear(&s, .Everything)
		defer blit(&s)
		input := read(&s)
		switch i in input {
		case t.Keyboard_Input:
			if i.key == .Q {
				return
			}
		case t.Mouse_Input:
		}

		t.move_cursor(&s, 0, 0)
		t.set_color_style(&s, t.Color_RGB{0xff, 0xff, 0xff}, t.Color_RGB{0xff, 0, 0})
		t.write(&s, "Hello World")
	}
}

