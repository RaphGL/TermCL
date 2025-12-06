package main

import t "../.."
import tb "../../term"

main :: proc() {
	s := t.init_screen(tb.VTABLE)
	defer t.destroy_screen(&s)
	t.set_term_mode(&s, .Raw)

	t.clear(&s, .Everything)
	t.move_cursor(&s, 0, 0)
	t.write(&s, "Please type something or move your mouse to start")
	t.blit(&s)

	for {
		t.clear(&s, .Everything)
		defer t.blit(&s)

		t.move_cursor(&s, 0, 0)
		t.write(&s, "Press `Esc` to exit")

		raw_input := tb.read_raw_blocking(&s) or_continue
		t.move_cursor(&s, 2, 0)
		t.writef(&s, "Raw: %v", raw_input)

		kb_input, kb_has_input := tb.parse_keyboard_input(raw_input)
		if kb_has_input {
			t.move_cursor(&s, 4, 0)
			t.write(&s, "Keyboard: ")
			t.writef(&s, "%v", kb_input)
			if kb_input.key == .Escape do return
		}

		mouse_input, mouse_has_input := tb.parse_mouse_input(raw_input)
		if mouse_has_input {
			t.move_cursor(&s, 6, 0)
			t.write(&s, "Mouse: ")
			t.writef(&s, "%v", mouse_input)
		}
	}
}
