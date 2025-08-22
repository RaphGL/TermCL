package main

import t "../.."

main :: proc() {
	s := t.init_screen()
	defer t.destroy_screen(&s)
	t.set_term_mode(&s, .Raw)
	t.hide_cursor(true)

	termsize := t.get_term_size()

	msg := "Use WASD or arrow keys to move window and 'q' to quit."
	window := t.init_window(termsize.h / 2, termsize.w / 2 - len(msg) / 2, 3, (uint)(len(msg) + 2))
	defer t.destroy_window(&window)

	main_loop: for {
		t.clear(&window, .Everything)
		defer t.blit(&window)

		t.clear(&s, .Everything)
		defer t.blit(&s)

		t.set_color_style(&window, .Black, .White)
		// this proves that no matter what the window will never be overflowed by moving the cursor
		for i in 0 ..= 10 {
			t.move_cursor(&window, cast(uint)i, 1)
			t.write_string(&window, msg)
		}
		t.reset_styles(&window)

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

