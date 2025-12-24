package main

import t "../.."
import tb "../../term"

PAINT_BUFFER_HEIGHT :: 26
PAINT_BUFFER_WIDTH :: 70
PAINT_BUFFER_BG_COLOR :: t.Color_8.White

Paint_Buffer :: struct {
	win:          t.Window,
	active_color: t.Color_8,
}

paint_buffer_fit_terminal :: proc(pb: ^Paint_Buffer) {
	termsize := t.get_term_size()
	y := termsize.h / 2 - PAINT_BUFFER_HEIGHT / 2
	x := termsize.w / 2 - PAINT_BUFFER_WIDTH / 2
	pb.win.y_offset = y
	pb.win.x_offset = x
	t.blit(&pb.win)
}

paint_buffer_init :: proc() -> Paint_Buffer {
	win := t.init_window(0, 0, PAINT_BUFFER_HEIGHT, PAINT_BUFFER_WIDTH)

	t.set_color_style(&win, PAINT_BUFFER_BG_COLOR, PAINT_BUFFER_BG_COLOR)
	t.clear(&win, .Everything)
	t.reset_styles(&win)

	pb := Paint_Buffer {
		win          = win,
		active_color = .Blue,
	}
	paint_buffer_fit_terminal(&pb)
	return pb
}

paint_buffer_handle_mouse_input :: proc(pb: ^Paint_Buffer, i: t.Mouse_Input) {
	if .Pressed not_in i.event do return
	if i.mod != {} do return

	mouse_pos, in_paint_buffer := t.window_coord_from_global(&pb.win, i.coord.y, i.coord.x)
	if !in_paint_buffer do return
	t.move_cursor(&pb.win, mouse_pos.y, mouse_pos.x)

	defer if i.key != .None {
		t.blit(&pb.win)
	}

	active_color_idx := cast(uint)pb.active_color

	#partial switch i.key {
	case .Left:
		t.set_color_style(&pb.win, pb.active_color, pb.active_color)
		t.write(&pb.win, ' ')

	case .Right:
		t.set_color_style(&pb.win, PAINT_BUFFER_BG_COLOR, PAINT_BUFFER_BG_COLOR)
		t.write(&pb.win, ' ')

	case .Scroll_Up:
		active_color_idx += 1
	case .Scroll_Down:
		active_color_idx -= 1
	}

	pb.active_color = t.Color_8(active_color_idx % len(t.Color_8))
	if pb.active_color == PAINT_BUFFER_BG_COLOR {
		pb.active_color = .Black
	}

	t.reset_styles(&pb.win)
}

draw_hud :: proc(hud: ^t.Window, pb: ^Paint_Buffer) {
	winsize := t.get_window_size(hud)
	help_msg :: "Quit (Esc or CTRL + C) / Draw (Left Click) / Erase (Right Click) / Brush Colors (Scroll Wheel)"
	t.move_cursor(hud, 0, winsize.w / 2 - len(help_msg) / 2)
	t.write(hud, help_msg)

	curr_brush :: "Current Brush Color: |"
	t.move_cursor(hud, 1, winsize.w / 2 - (len(curr_brush) + 2) / 2)
	t.write(hud, curr_brush)
	t.set_color_style(hud, nil, pb.active_color)
	t.write(hud, ' ')
	t.reset_styles(hud)
	t.write(hud, '|')
	t.blit(hud)
}

main :: proc() {
	s := t.init_screen(tb.VTABLE)
	defer t.destroy_screen(&s)
	t.set_term_mode(&s, .Cbreak)
	t.hide_cursor(true)
	// on cooked mode mouse is not enabled by default so we have to enable it
	t.enable_mouse(true)

	pb := paint_buffer_init()
	defer t.destroy_window(&pb.win)

	hud := t.init_window(0, 0, 2, nil)
	defer t.destroy_window(&hud)

	t.clear(&s, .Everything)
	t.blit(&s)
	t.blit(&pb.win)
	draw_hud(&hud, &pb)

	defer {
		t.clear(&s, .Everything)
		t.blit(&s)
	}

	prev_termsize := t.get_term_size()
	for {
		curr_termsize := t.get_term_size()
		if curr_termsize != prev_termsize {
			t.clear(&s, .Everything)
			t.blit(&s)

			paint_buffer_fit_terminal(&pb)
			draw_hud(&hud, &pb)
			prev_termsize = curr_termsize
		}

		input := t.read(&s)
		switch v in input {
		case t.Mouse_Input:
			draw_hud(&hud, &pb)
			paint_buffer_handle_mouse_input(&pb, v)

		case t.Keyboard_Input:
			if v.key == .Escape do return
		}
	}
}
