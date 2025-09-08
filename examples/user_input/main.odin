package main

import t "../.."

main :: proc() {
	s := t.init_screen()
	defer t.destroy_screen(&s)
	t.set_term_mode(&s, .Raw)

	t.clear(&s, .Everything)
	t.move_cursor(&s, 0, 0)
	t.write(&s, "Please type something or move your mouse to start")
	t.blit(&s)

	for {
		t.clear(&s, .Everything)
		defer t.blit(&s)

		input := t.read_blocking(&s) or_continue

		t.move_cursor(&s, 0, 0)
		t.write(&s, "Press `Esc` to exit")

		t.move_cursor(&s, 2, 0)
		t.writef(&s, "Bytes: %v", input)

		kb_input, has_kb_input := t.parse_keyboard_input(input)

		t.move_cursor(&s, 4, 0)
		t.write(&s, "Keyboard: ")
		if has_kb_input && kb_input.key != .None {
			t.writef(&s, "%v", kb_input)
		} else {
			t.write(&s, "None")
		}

		mouse_input, has_mouse_input := t.parse_mouse_input(input)
		t.move_cursor(&s, 6, 0)
		t.write(&s, "Mouse: ")
		if has_mouse_input {
			t.writef(&s, "%v", mouse_input)
		} else {
			t.write(&s, "None")
		}

		if kb_input.key == .Escape do break
	}
}

