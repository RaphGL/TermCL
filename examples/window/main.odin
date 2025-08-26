package main

import t "../.."

main :: proc() {
	s := t.init_screen()
	defer t.destroy_screen(&s)
	t.set_term_mode(&s, .Raw)
	t.hide_cursor(true)

	termsize := t.get_term_size()

	msg := "Use WASD or arrow keys to move window and 'q' to quit. As you can see if I can writing eventually the text is going to wrap around."


	window := t.init_window(termsize.h / 2, termsize.w / 2 - len(msg) / 2, 6, 55)
	defer t.destroy_window(&window)

	main_loop: for {
		t.clear(&s, .Everything)
		defer t.blit(&window)
		defer t.blit(&s)

		t.set_color_style(&window, .Black, .White)
		t.clear(&window, .Everything)
		// this proves that no matter what the window will never be overflowed by moving the cursor
		t.move_cursor(&window, 0, 0)
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

