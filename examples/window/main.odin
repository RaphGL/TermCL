package main

import t "../.."

main :: proc() {
	s := t.init_screen()
	defer t.destroy_screen(&s)
	t.set_term_mode(&s, .Raw)
	t.hide_cursor(true)


	msg := "As you can see here, if the text continues, it will eventually wrap around instead of going outside the bounds of the window"
	termsize := t.get_term_size()

	window := t.init_window(termsize.h / 2 - 3, termsize.w / 2 - 26 / 2, 6, 26)
	defer t.destroy_window(&window)

	main_loop: for {
		t.clear(&s, .Everything)
		defer t.blit(&window)
		defer t.blit(&s)

		t.set_text_style(&s, {.Bold})
		t.set_color_style(&s, .Red, nil)
		t.move_cursor(&s, 0, 0)
		t.write(&s, "Press 'Q' to exit")
		t.move_cursor(&s, 1, 0)

		t.reset_styles(&s)
		t.set_color_style(&s, nil, nil)
		t.write(&s, msg)

		t.set_color_style(&window, .Black, .White)
		t.clear(&window, .Everything)
		// this proves that no matter what the window will never be overflowed by moving the cursor
		t.move_cursor(&window, 2, 0)
		t.write_string(&window, msg)

		input := t.read(&s) or_continue
		kb_input := t.parse_keyboard_input(input) or_continue

		#partial switch kb_input.key {
		case .Arrow_Left, .A:
			window.x_offset -= 1
		case .Arrow_Right, .D:
			window.x_offset += 1
		case .Arrow_Up, .W:
			window.y_offset -= 1
		case .Arrow_Down, .S:
			window.y_offset += 1

		case .Q:
			break main_loop
		}
	}
}

