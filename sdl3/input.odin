package termcl_sdl3

import t ".."
import os "core:os/os2"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"
import "vendor:sdl3"

read_raw :: proc(screen: ^t.Screen) -> (input: cstring, ok: bool) {
	e: sdl3.Event
	for sdl3.PollEvent(&e) {
		#partial switch e.type {
		case .QUIT:
			os.exit(0)
		case .TEXT_INPUT:
			return e.text.text, true
		}
	}

	return
}

read_raw_blocking :: proc(screen: ^t.Screen) -> (input: cstring, ok: bool) {
	for {
		input, input_ok := read_raw(screen)
		if input_ok {
			return input, true
		}
	}
	return
}

read :: proc(screen: ^t.Screen) -> t.Input {
	e: sdl3.Event
	for sdl3.PollEvent(&e) {
		// TODO: consider other approach for quitting? idk
		if e.type == .QUIT {
			os.exit(0)
		}

		mouse_input, mouse_ok := parse_mouse_input(&e)
		if mouse_ok do return mouse_input
		keyboard_input, keyboard_ok := parse_keyboard_input(&e)
		if keyboard_ok do return keyboard_input
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

parse_mouse_input :: proc(event: ^sdl3.Event) -> (mouse_input: t.Mouse_Input, has_input: bool) {
	if event.type != .MOUSE_BUTTON_DOWN &&
	   event.type != .MOUSE_BUTTON_UP &&
	   event.type != .MOUSE_WHEEL &&
	   event.type != .MOUSE_MOTION {
		return {}, false
	}

	mouse: t.Mouse_Input
	// TODO: convert to cell based coordinates
	mouse.coord.x = cast(uint)event.motion.x
	mouse.coord.y = cast(uint)event.motion.y

	if event.wheel.y > 0 {
		mouse.key = .Scroll_Up
	} else if event.wheel.y < 0 {
		mouse.key = .Scroll_Down
	}

	#partial switch event.type {
	case .MOUSE_BUTTON_UP:
		mouse.event = {.Released}
	case .MOUSE_BUTTON_DOWN:
		mouse.event = {.Pressed}
	}

	switch event.button.button {
	case sdl3.BUTTON_RIGHT:
		mouse.key = .Right
	case sdl3.BUTTON_LEFT:
		mouse.key = .Left
	case sdl3.BUTTON_MIDDLE:
		mouse.key = .Middle
	}

	/* MODIFIERS */{
		if (event.key.mod & {.LCTRL, .RCTRL}) != {} {
			mouse.mod += {.Ctrl}
		}
		if (event.key.mod & {.LALT, .RALT}) != {} {
			mouse.mod += {.Alt}
		}
		if (event.key.mod & {.LSHIFT, .RSHIFT}) != {} {
			mouse.mod += {.Shift}
		}
	}

	return mouse, true
}

parse_keyboard_input :: proc(
	event: ^sdl3.Event,
) -> (
	keyboard_input: t.Keyboard_Input,
	has_input: bool,
) {
	kb: t.Keyboard_Input

	mod := sdl3.GetModState()
	if mod & {.LSHIFT, .RSHIFT} != {} {
		kb.mod = .Shift
	} else if mod & {.LCTRL, .RCTRL} != {} {
		kb.mod = .Ctrl
	} else if mod & {.LALT, .RALT} != {} {
		kb.mod = .Ctrl
	}

	#partial switch event.type {
	case .KEY_DOWN:
		switch event.key.key {
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
		case sdl3.K_APOSTROPHE:
			kb.key = .Single_Quote
		case sdl3.K_DBLAPOSTROPHE:
			kb.key = .Double_Quote
		case sdl3.K_PERIOD:
			kb.key = .Period
		case sdl3.K_ASTERISK:
			kb.key = .Asterisk
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
		case sdl3.K_GRAVE:
			kb.key = .Backtick
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

	case .TEXT_INPUT:
		if len(event.text.text) == 0 do return

		r := cast(rune)string(event.text.text)[0]


		switch r {
		case '\'':
			kb.key = .Single_Quote
		case '"':
			kb.key = .Double_Quote
		case '´':
			kb.key = .Tick
		case 'A', 'a':
			kb.key = .A
		case 'B', 'b':
			kb.key = .B
		case 'C', 'c':
			kb.key = .C
		case 'D', 'd':
			kb.key = .D
		case 'E', 'e':
			kb.key = .E
		case 'F', 'f':
			kb.key = .F
		case 'G', 'g':
			kb.key = .G
		case 'H', 'h':
			kb.key = .H
		case 'I', 'i':
			kb.key = .I
		case 'J', 'j':
			kb.key = .J
		case 'K', 'k':
			kb.key = .K
		case 'L', 'l':
			kb.key = .L
		case 'M', 'm':
			kb.key = .M
		case 'N', 'n':
			kb.key = .N
		case 'O', 'o':
			kb.key = .O
		case 'P', 'p':
			kb.key = .P
		case 'Q', 'q':
			kb.key = .Q
		case 'R', 'r':
			kb.key = .R
		case 'S', 's':
			kb.key = .S
		case 'T', 't':
			kb.key = .T
		case 'U', 'u':
			kb.key = .U
		case 'V', 'v':
			kb.key = .V
		case 'W', 'w':
			kb.key = .W
		case 'X', 'x':
			kb.key = .X
		case 'Y', 'y':
			kb.key = .Y
		case 'Z', 'z':
			kb.key = .Z
		case '0':
			kb.key = .Num_0
		case '1':
			kb.key = .Num_1
		case '2':
			kb.key = .Num_2
		case '3':
			kb.key = .Num_3
		case '4':
			kb.key = .Num_4
		case '5':
			kb.key = .Num_5
		case '6':
			kb.key = .Num_6
		case '7':
			kb.key = .Num_7
		case '8':
			kb.key = .Num_8
		case '9':
			kb.key = .Num_9
		case '-':
			kb.key = .Minus
		case '+':
			kb.key = .Plus
		case '=':
			kb.key = .Equal
		case '(':
			kb.key = .Open_Paren
		case ')':
			kb.key = .Close_Paren
		case '{':
			kb.key = .Open_Curly_Bracket
		case '}':
			kb.key = .Close_Curly_Bracket
		case '[':
			kb.key = .Open_Square_Bracket
		case ']':
			kb.key = .Close_Square_Bracket
		case ':':
			kb.key = .Colon
		case ';':
			kb.key = .Semicolon
		case '/':
			kb.key = .Slash
		case '\\':
			kb.key = .Backslash
		case '.':
			kb.key = .Period
		case '*':
			kb.key = .Asterisk
		case ' ':
			kb.key = .Space
		case '$':
			kb.key = .Dollar
		case '!':
			kb.key = .Exclamation
		case '#':
			kb.key = .Hash
		case '%':
			kb.key = .Percent
		case '&':
			kb.key = .Ampersand
		case '_':
			kb.key = .Underscore
		case '^':
			kb.key = .Caret
		case ',':
			kb.key = .Comma
		case '|':
			kb.key = .Pipe
		case '@':
			kb.key = .At
		case '~':
			kb.key = .Tilde
		case '<':
			kb.key = .Less_Than
		case '>':
			kb.key = .Greater_Than
		case '?':
			kb.key = .Question_Mark
		case '`':
			kb.key = .Backtick
		}
	}

	if kb.key != .None {
		return kb, true
	}

	return
}
