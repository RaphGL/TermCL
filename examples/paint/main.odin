package main

import t "../../"

Brush :: struct {
	color: t.Color_8,
	size:  uint,
}

PAINT_BUFFER_WIDTH :: 100
PAINT_BUFFER_HEIGHT :: 40

Paint_Buffer :: struct {
	x, y:   uint,
	buffer: [PAINT_BUFFER_HEIGHT][PAINT_BUFFER_WIDTH]Maybe(t.Color_8),
}

paint_buffer_to_screen :: proc(pbuf: Paint_Buffer, s: ^t.Screen) {
	defer t.reset_styles(s)

	for y in 0 ..< PAINT_BUFFER_HEIGHT {
		for x in 0 ..< PAINT_BUFFER_WIDTH {
			if y == PAINT_BUFFER_HEIGHT - 1 || y == 0 || x == 0 || x == PAINT_BUFFER_WIDTH - 1 {
				computed_x := uint(x) + pbuf.x
				computed_y := uint(y) + pbuf.y
				if y == 0 do computed_y -= 1
				if y == PAINT_BUFFER_HEIGHT - 1 do computed_y += 1
				if x == 0 do computed_x -= 1
				if x == PAINT_BUFFER_WIDTH - 1 do computed_x += 1

				t.move_cursor(s, computed_y, computed_x)
				t.set_color_style_8(s, .Black, .Black)
				t.write(s, ' ')
			}

			t.move_cursor(s, uint(y) + pbuf.y, uint(x) + pbuf.x)
			color := pbuf.buffer[y][x]
			t.set_color_style_8(s, color, color)
			t.write(s, ' ')
		}
	}
}

paint_buffer_set_cell :: proc(
	s: ^t.Screen,
	pbuf: ^Paint_Buffer,
	y, x: uint,
	color: Maybe(t.Color_8),
) {
	y_max := PAINT_BUFFER_HEIGHT + pbuf.y
	x_max := PAINT_BUFFER_WIDTH + pbuf.x

	if (y < pbuf.y || y >= y_max) || (x < pbuf.x || x >= x_max) {
		return
	}

	computed_y := y - pbuf.y
	computed_x := x - pbuf.x

	pbuf.buffer[computed_y][computed_x] = color
}

main :: proc() {
	s := t.init_screen()
	defer t.destroy_screen(&s)
	t.set_term_mode(&s, .Raw)
	t.hide_cursor(true)

	brush := Brush {
		color = .White,
		size  = 1,
	}

	pbuf: Paint_Buffer

	for {
		t.clear(&s, .Everything)
		defer t.blit(&s)
		defer paint_buffer_to_screen(pbuf, &s)

		termsize := t.get_term_size(&s)

		if termsize.w <= PAINT_BUFFER_WIDTH && termsize.w <= PAINT_BUFFER_WIDTH {
			t.clear(&s, .Everything)
			size_small_msg := "Size is too small, increase size to continue or press 'q' to exit"
			t.move_cursor(&s, termsize.h / 2, termsize.w / 2 - len(size_small_msg) / 2)
			t.write(&s, size_small_msg)
			t.blit(&s)
		}

		pbuf.x = termsize.w / 2 - PAINT_BUFFER_WIDTH / 2
		pbuf.y = termsize.h / 2 - PAINT_BUFFER_HEIGHT / 2

		help_msg := "Draw (Right Click) / Delete (Left Click)"
		t.move_cursor(&s, termsize.h - 2, termsize.w / 2 - len(help_msg) / 2)
		t.write(&s, help_msg)

		input, _ := t.read(&s)

		mouse, has_input := t.parse_mouse_input(input)
		if has_input {
			#partial switch mouse.key {
			case .Left:
				if mouse.mod == nil && .Pressed in mouse.event {
					paint_buffer_set_cell(&s, &pbuf, mouse.coord.y, mouse.coord.x, brush.color)
				}
			case .Right:
				if mouse.mod == nil && .Pressed in mouse.event {
					paint_buffer_set_cell(&s, &pbuf, mouse.coord.y, mouse.coord.x, nil)
				}
			}
		}

		keyboard, kb_has_input := t.parse_keyboard_input(input)
		if kb_has_input && (keyboard.mod == .Ctrl && keyboard.key == .C) || keyboard.key == .Q {
			break
		}
	}
}

