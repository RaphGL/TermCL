package main

import t "../../"

Brush :: struct {
	color: t.Color_8,
	size:  uint,
}

PAINT_BUFFER_WIDTH :: 80
PAINT_BUFFER_HEIGHT :: 30

Paint_Buffer :: struct {
	buffer: [PAINT_BUFFER_HEIGHT][PAINT_BUFFER_WIDTH]Maybe(t.Color_8),
	screen: ^t.Screen,
	window: t.Window,
}

paint_buffer_init :: proc(s: ^t.Screen) -> Paint_Buffer {
	return Paint_Buffer {
		screen = s,
		window = t.init_window(0, 0, PAINT_BUFFER_HEIGHT, PAINT_BUFFER_WIDTH),
	}
}

paint_buffer_destroy :: proc(pbuf: ^Paint_Buffer) {
	t.clear(&pbuf.window, .Everything)
	t.blit(&pbuf.window)
	t.destroy_window(&pbuf.window)
}

paint_buffer_to_screen :: proc(pbuf: ^Paint_Buffer) {
	termsize := t.get_window_size(pbuf.screen)
	pbuf.window.x_offset = termsize.w / 2 - PAINT_BUFFER_WIDTH / 2
	pbuf.window.y_offset = termsize.h / 2 - PAINT_BUFFER_HEIGHT / 2

	t.set_color_style(&pbuf.window, .White, .White)
	t.clear(&pbuf.window, .Everything)

	defer {
		t.reset_styles(&pbuf.window)
		t.blit(&pbuf.window)
	}

	for y in 0 ..< PAINT_BUFFER_HEIGHT {
		for x in 0 ..< PAINT_BUFFER_WIDTH {
			t.move_cursor(&pbuf.window, uint(y), uint(x))
			color := pbuf.buffer[y][x]
			if color == nil do continue
			t.set_color_style(&pbuf.window, color.?, color.?)
			t.write(&pbuf.window, ' ')
		}
	}
}

paint_buffer_set_cell :: proc(pbuf: ^Paint_Buffer, y, x: uint, color: Maybe(t.Color_8)) {
	pbuf.buffer[y][x] = color
}

main :: proc() {
	s := t.init_screen()
	defer t.destroy_screen(&s)
	t.set_term_mode(&s, .Raw)
	t.hide_cursor(true)

	t.clear(&s, .Everything)
	t.blit(&s)

	pbuf := paint_buffer_init(&s)
	defer paint_buffer_destroy(&pbuf)

	for {
		defer {
			t.blit(&s)
			paint_buffer_to_screen(&pbuf)
		}

		termsize := t.get_window_size(&s)

		help_msg := "Draw (Right Click) / Delete (Left Click) / Quit (Q or CTRL + C)"
		t.move_cursor(&s, termsize.h - 2, termsize.w / 2 - len(help_msg) / 2)
		t.write(&s, help_msg)

		if termsize.w <= PAINT_BUFFER_WIDTH || termsize.w <= PAINT_BUFFER_WIDTH {
			t.clear(&s, .Everything)
			size_small_msg := "Size is too small, increase size to continue or press 'q' to exit"
			t.move_cursor(&s, termsize.h / 2, termsize.w / 2 - len(size_small_msg) / 2)
			t.write(&s, size_small_msg)
			continue
		}


		input := t.read(&s)
		switch i in input {
		case t.Keyboard_Input:
			if (i.mod == .Ctrl && i.key == .C) || i.key == .Q {
				return
			}
		case t.Mouse_Input:
			win_cursor := t.window_coord_from_global(
				&pbuf.window,
				i.coord.y,
				i.coord.x,
			) or_continue

			#partial switch i.key {
			case .Left:
				if i.mod == nil && .Pressed in i.event {
					paint_buffer_set_cell(&pbuf, win_cursor.y, win_cursor.x, .Black)
				}
			case .Right:
				if i.mod == nil && .Pressed in i.event {
					paint_buffer_set_cell(&pbuf, win_cursor.y, win_cursor.x, nil)
				}
			}
		}
	}
}

