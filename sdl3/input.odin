package termcl_sdl3

import t ".."
import os "core:os/os2"
import "vendor:sdl3"

read :: proc(screen: ^t.Screen) -> t.Input {
	e: sdl3.Event
	for sdl3.PollEvent(&e) {
		// TODO: consider other approach for quitting? idk
		if e.type == .QUIT {
			os.exit(0)
		}

		#partial switch e.type {
		case .KEY_DOWN:
			kb: t.Keyboard_Input
			/* MODIFIERS */{
				if (e.key.mod & {.LCTRL, .RCTRL}) != {} {
					kb.mod = .Ctrl
				}
				if (e.key.mod & {.LALT, .RALT}) != {} {
					kb.mod = .Alt
				}
				if (e.key.mod & {.LSHIFT, .RSHIFT}) != {} {
					kb.mod = .Shift
				}
			}

			switch e.key.key {
			case sdl3.K_LEFT:
				kb.key = .Arrow_Left
			case sdl3.K_RIGHT:
				kb.key = .Arrow_Right
			case sdl3.K_UP:
				kb.key = .Arrow_Up
			case sdl3.K_DOWN:
				kb.key = .Arrow_Down
			case sdl3.K_PAGEUP:
				kb.key = .Page_Up
			case sdl3.K_PAGEDOWN:
				kb.key = .Page_Down
			case sdl3.K_HOME:
				kb.key = .Home
			case sdl3.K_END:
				kb.key = .End
			case sdl3.K_INSERT:
				kb.key = .Insert
			case sdl3.K_DELETE:
				kb.key = .Delete
			case sdl3.K_F1:
				kb.key = .F1
			case sdl3.K_F2:
				kb.key = .F2
			case sdl3.K_F3:
				kb.key = .F3
			case sdl3.K_F4:
				kb.key = .F4
			case sdl3.K_F5:
				kb.key = .F5
			case sdl3.K_F6:
				kb.key = .F6
			case sdl3.K_F7:
				kb.key = .F7
			case sdl3.K_F8:
				kb.key = .F8
			case sdl3.K_F9:
				kb.key = .F9
			case sdl3.K_F10:
				kb.key = .F10
			case sdl3.K_F11:
				kb.key = .F11
			case sdl3.K_F12:
				kb.key = .F12
			case sdl3.K_ESCAPE:
				kb.key = .Escape
			case sdl3.K_0:
				kb.key = .Num_0
			case sdl3.K_1:
				kb.key = .Num_1
			case sdl3.K_2:
				kb.key = .Num_2
			case sdl3.K_3:
				kb.key = .Num_3
			case sdl3.K_4:
				kb.key = .Num_4
			case sdl3.K_5:
				kb.key = .Num_5
			case sdl3.K_6:
				kb.key = .Num_6
			case sdl3.K_7:
				kb.key = .Num_7
			case sdl3.K_8:
				kb.key = .Num_8
			case sdl3.K_9:
				kb.key = .Num_9
			case sdl3.K_RETURN:
				kb.key = .Enter
			case sdl3.K_TAB:
				kb.key = .Tab
			case sdl3.K_BACKSPACE:
				kb.key = .Backspace
			case sdl3.K_A:
				kb.key = .A
			case sdl3.K_B:
				kb.key = .B
			case sdl3.K_C:
				kb.key = .C
			case sdl3.K_D:
				kb.key = .D
			case sdl3.K_E:
				kb.key = .E
			case sdl3.K_F:
				kb.key = .F
			case sdl3.K_G:
				kb.key = .G
			case sdl3.K_H:
				kb.key = .H
			case sdl3.K_I:
				kb.key = .I
			case sdl3.K_J:
				kb.key = .J
			case sdl3.K_K:
				kb.key = .K
			case sdl3.K_L:
				kb.key = .L
			case sdl3.K_M:
				kb.key = .M
			case sdl3.K_N:
				kb.key = .N
			case sdl3.K_O:
				kb.key = .O
			case sdl3.K_P:
				kb.key = .P
			case sdl3.K_Q:
				kb.key = .Q
			case sdl3.K_R:
				kb.key = .R
			case sdl3.K_S:
				kb.key = .S
			case sdl3.K_T:
				kb.key = .T
			case sdl3.K_U:
				kb.key = .U
			case sdl3.K_V:
				kb.key = .V
			case sdl3.K_W:
				kb.key = .W
			case sdl3.K_X:
				kb.key = .X
			case sdl3.K_Y:
				kb.key = .Y
			case sdl3.K_Z:
				kb.key = .Z
			case sdl3.K_MINUS:
				kb.key = .Minus
			case sdl3.K_PLUS:
				kb.key = .Plus
			case sdl3.K_EQUALS:
				kb.key = .Equal
			case sdl3.K_LEFTPAREN:
				kb.key = .Open_Paren
			case sdl3.K_RIGHTPAREN:
				kb.key = .Close_Paren
			case sdl3.K_LEFTBRACE:
				kb.key = .Open_Curly_Bracket
			case sdl3.K_RIGHTBRACE:
				kb.key = .Close_Curly_Bracket
			case sdl3.K_LEFTBRACKET:
				kb.key = .Open_Square_Bracket
			case sdl3.K_RIGHTBRACKET:
				kb.key = .Close_Square_Bracket
			case sdl3.K_COLON:
				kb.key = .Colon
			case sdl3.K_SEMICOLON:
				kb.key = .Semicolon
			case sdl3.K_SLASH:
				kb.key = .Slash
			case sdl3.K_BACKSLASH:
				kb.key = .Backslash
			// TODO
			// case:
			// 	kb.key = .Single_Quote
			// TODO
			// case:
			// kb.key = .Double_Quote
			case sdl3.K_PERIOD:
				kb.key = .Period
			case sdl3.K_ASTERISK:
				kb.key = .Asterisk
			// 	 TODO
			// case:
			// 	kb.key = .Backtick
			case sdl3.K_SPACE:
				kb.key = .Space
			case sdl3.K_DOLLAR:
				kb.key = .Dollar
			case sdl3.K_EXCLAIM:
				kb.key = .Exclamation
			case sdl3.K_HASH:
				kb.key = .Hash
			case sdl3.K_PERCENT:
				kb.key = .Percent
			case sdl3.K_AMPERSAND:
				kb.key = .Ampersand
			// 	// TODO
			// case:
			// 	kb.key = .Tick
			case sdl3.K_UNDERSCORE:
				kb.key = .Underscore
			case sdl3.K_CARET:
				kb.key = .Caret
			case sdl3.K_COMMA:
				kb.key = .Comma
			case sdl3.K_PIPE:
				kb.key = .Pipe
			case sdl3.K_AT:
				kb.key = .At
			case sdl3.K_TILDE:
				kb.key = .Tilde
			case sdl3.K_LESS:
				kb.key = .Less_Than
			case sdl3.K_GREATER:
				kb.key = .Greater_Than
			case sdl3.K_QUESTION:
				kb.key = .Question_Mark
			case:
				kb.key = .None
			}

			return kb

		case .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP, .MOUSE_WHEEL, .MOUSE_MOTION:
			mouse: t.Mouse_Input
			// TODO: convert to cell based coordinates
			mouse.coord.x = cast(uint)e.motion.x
			mouse.coord.y = cast(uint)e.motion.y

			if e.wheel.y > 0 {
				mouse.key = .Scroll_Up
			} else if e.wheel.y < 0 {
				mouse.key = .Scroll_Down
			}

			#partial switch e.type {
			case .MOUSE_BUTTON_UP:
				mouse.event = {.Released}
			case .MOUSE_BUTTON_DOWN:
				mouse.event = {.Pressed}
			}

			switch e.button.button {
			case sdl3.BUTTON_RIGHT:
				mouse.key = .Right
			case sdl3.BUTTON_LEFT:
				mouse.key = .Left
			case sdl3.BUTTON_MIDDLE:
				mouse.key = .Middle
			}

			/* MODIFIERS */{
				if (e.key.mod & {.LCTRL, .RCTRL}) != {} {
					mouse.mod += {.Ctrl}
				}
				if (e.key.mod & {.LALT, .RALT}) != {} {
					mouse.mod += {.Alt}
				}
				if (e.key.mod & {.LSHIFT, .RSHIFT}) != {} {
					mouse.mod += {.Shift}
				}
			}

			return mouse
		}
	}

	return nil
}

read_blocking :: proc(screen: ^t.Screen) -> t.Input {
	for {
		i := read(screen)
		if i != nil {
			return i
		}
	}
}
