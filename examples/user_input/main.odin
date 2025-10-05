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

		t.move_cursor(&s, 2, 0)

		input := t.read_blocking(&s)

		switch i in input {
		case t.Keyboard_Input:
			t.move_cursor(&s, 4, 0)
			t.write(&s, "Keyboard: ")
			t.writef(&s, "%v", i)
			if i.key == .Escape do return
		case t.Mouse_Input:
			t.move_cursor(&s, 6, 0)
			t.write(&s, "Mouse: ")
			t.writef(&s, "%v", i)
		}
	}
}

