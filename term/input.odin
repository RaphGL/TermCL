package term

import t ".."
import os "core:os"
import "core:strconv"
import "core:unicode"

read :: proc(screen: ^t.Screen) -> t.Input {
	input, has_input := raw_read(screen.input_buf[:])
	if !has_input do return nil

	mouse_input, mouse_ok := parse_mouse_input(input[:])
	if mouse_ok {
		return mouse_input
	}

	kb_input, kb_ok := parse_keyboard_input(input[:])
	if kb_ok {
		return kb_input
	}

	return nil
}

read_raw :: proc(screen: ^t.Screen) -> (input: []byte, ok: bool) {
	return raw_read(screen.input_buf[:])
}

read_raw_blocking :: proc(screen: ^t.Screen) -> (input: []byte, ok: bool) {
	bytes_read, err := os.read(os.stdin, screen.input_buf[:])
	if err != nil {
		panic("failing to get user input")
	}

	return screen.input_buf[:bytes_read], bytes_read > 0
}

read_blocking :: proc(screen: ^t.Screen) -> t.Input {
	input, input_ok := read_raw_blocking(screen)
	if !input_ok do return nil

	mouse_input, mouse_ok := parse_mouse_input(input)
	if mouse_ok {
		return mouse_input
	}

	kb_input, kb_ok := parse_keyboard_input(input)
	if kb_ok {
		return kb_input
	}

	return nil
}


/*
Parses the raw bytes sent by the terminal in `Input`.

**Inputs**
- `input`: bytes received from terminal stdin

**Returns**
- `keyboard_input`: parsed keyboard input
- `has_input`: true if has input

Note: the terminal processes some inputs making them be treated the same
so if you're checking for a certain input and it's never true,
check what value it is processed into.

For example, `.Escape` is either Esc, Ctrl + [ and Ctrl + 3 to the terminal.
*/
parse_keyboard_input :: proc(
	input: []byte,
) -> (
	keyboard_input: t.Keyboard_Input,
	has_input: bool,
) {
	_alnum_to_key :: proc(b: byte) -> (key: t.Key, ok: bool) {
		switch b {
		case '\x1b':
			key = .Escape
		case '1':
			key = .Num_1
		case '2':
			key = .Num_2
		case '3':
			key = .Num_3
		case '4':
			key = .Num_4
		case '5':
			key = .Num_5
		case '6':
			key = .Num_6
		case '7':
			key = .Num_7
		case '8':
			key = .Num_8
		case '9':
			key = .Num_9
		case '0':
			key = .Num_0
		case '\r', '\n':
			key = .Enter
		case '\t':
			key = .Tab
		case 8, 127:
			key = .Backspace
		case 'a', 'A':
			key = .A
		case 'b', 'B':
			key = .B
		case 'c', 'C':
			key = .C
		case 'd', 'D':
			key = .D
		case 'e', 'E':
			key = .E
		case 'f', 'F':
			key = .F
		case 'g', 'G':
			key = .G
		case 'h', 'H':
			key = .H
		case 'i', 'I':
			key = .I
		case 'j', 'J':
			key = .J
		case 'k', 'K':
			key = .K
		case 'l', 'L':
			key = .L
		case 'm', 'M':
			key = .M
		case 'n', 'N':
			key = .N
		case 'o', 'O':
			key = .O
		case 'p', 'P':
			key = .P
		case 'q', 'Q':
			key = .Q
		case 'r', 'R':
			key = .R
		case 's', 'S':
			key = .S
		case 't', 'T':
			key = .T
		case 'u', 'U':
			key = .U
		case 'v', 'V':
			key = .V
		case 'w', 'W':
			key = .W
		case 'x', 'X':
			key = .X
		case 'y', 'Y':
			key = .Y
		case 'z', 'Z':
			key = .Z
		case ',':
			key = .Comma
		case ':':
			key = .Colon
		case ';':
			key = .Semicolon
		case '-':
			key = .Minus
		case '+':
			key = .Plus
		case '=':
			key = .Equal
		case '{':
			key = .Open_Curly_Bracket
		case '}':
			key = .Close_Curly_Bracket
		case '(':
			key = .Open_Paren
		case ')':
			key = .Close_Paren
		case '[':
			key = .Open_Square_Bracket
		case ']':
			key = .Close_Square_Bracket
		case '/':
			key = .Slash
		case '\'':
			key = .Single_Quote
		case '"':
			key = .Double_Quote
		case '.':
			key = .Period
		case '*':
			key = .Asterisk
		case '`':
			key = .Backtick
		case '\\':
			key = .Backslash
		case ' ':
			key = .Space
		case '$':
			key = .Dollar
		case '!':
			key = .Exclamation
		case '#':
			key = .Hash
		case '%':
			key = .Percent
		case '&':
			key = .Ampersand
		case '´':
			key = .Tick
		case '_':
			key = .Underscore
		case '^':
			key = .Caret
		case '|':
			key = .Pipe
		case '@':
			key = .At
		case '~':
			key = .Tilde
		case '<':
			key = .Less_Than
		case '>':
			key = .Greater_Than
		case '?':
			key = .Question_Mark
		case:
			ok = false
			return
		}

		ok = true
		return
	}

	input := input
	seq: t.Keyboard_Input

	if len(input) == 0 do return

	if len(input) == 1 {
		input_rune := cast(rune)input[0]
		if unicode.is_upper(input_rune) {
			seq.mod = .Shift
		}

		if unicode.is_control(input_rune) {
			switch input_rune {
			case '\r',
			     '\n',
			     '\b',
			     127, /* backspace */
			     '\t',
			     '\x1b':
			case:
				seq.mod = .Ctrl
				input[0] += 64
			}
		}

		key, ok := _alnum_to_key(input[0])
		if !ok do return {}, false
		seq.key = key
		return seq, true
	}

	if input[0] != '\x1b' do return

	if len(input) > 3 {
		input_len := len(input)

		if input[input_len - 3] == ';' {
			switch input[input_len - 2] {
			case '2':
				seq.mod = .Shift
			case '3':
				seq.mod = .Alt
			case '5':
				seq.mod = .Ctrl

			}
		}
	}

	if len(input) >= 2 {
		switch input[len(input) - 1] {
		case 'P':
			seq.key = .F1
		case 'Q':
			seq.key = .F2
		case 'R':
			seq.key = .F3
		case 'S':
			seq.key = .F4

		}

		if input[1] == 'O' do return seq, true
	}

	if input[1] == '[' {
		input = input[2:]

		if len(input) > 2 && input[0] == '1' && input[1] == ';' {
			switch input[2] {
			case '2':
				seq.mod = .Shift
			case '3':
				seq.mod = .Alt
			case '5':
				seq.mod = .Ctrl
			}

			input = input[3:]
		}


		if len(input) == 1 {
			switch input[0] {
			case 'H':
				seq.key = .Home
			case 'F':
				seq.key = .End
			case 'A':
				seq.key = .Arrow_Up
			case 'B':
				seq.key = .Arrow_Down
			case 'C':
				seq.key = .Arrow_Right
			case 'D':
				seq.key = .Arrow_Left
			case 'Z':
				seq.key = .Tab
				seq.mod = .Shift
			}
		}


		if len(input) >= 2 {
			switch input[0] {
			case 'O':
				switch input[1] {
				case 'H':
					seq.key = .Home
				case 'F':
					seq.key = .End
				}
			case '1':
				switch input[1] {
				case 'P':
					seq.key = .F1
				case 'Q':
					seq.key = .F2
				case 'R':
					seq.key = .F3
				case 'S':
					seq.key = .F4
				}
			}
		}


		if input[len(input) - 1] == '~' {
			switch input[0] {
			case '1', '7':
				seq.key = .Home
			case '2':
				seq.key = .Insert
			case '3':
				seq.key = .Delete
			case '4', '8':
				seq.key = .End
			case '5':
				seq.key = .Page_Up
			case '6':
				seq.key = .Page_Down
			}

			switch input[0] {
			case '1':
				switch input[1] {
				case '1':
					seq.key = .F1
				case '2':
					seq.key = .F2
				case '3':
					seq.key = .F3
				case '4':
					seq.key = .F4
				case '5':
					seq.key = .F5
				case '7':
					seq.key = .F6
				case '8':
					seq.key = .F7
				case '9':
					seq.key = .F8
				}

			case '2':
				switch input[1] {
				case '0':
					seq.key = .F9
				case '1':
					seq.key = .F10
				case '3':
					seq.key = .F11
				case '4':
					seq.key = .F12
				}
			}
		}

		return seq, true
	}

	// alt is ESC + <char>
	if len(input) == 2 {
		key, ok := _alnum_to_key(input[1])
		if ok {
			seq.mod = .Alt
			seq.key = key
			return seq, true
		}
	}

	return
}

/*
Parses the raw bytes sent by the terminal in `Input`

**Returns**
- `mouse_input`: parsed mouse input
- `has_input`: true there was valid mouse input

Note: mouse input is not always guaranteed. The user might be running the program from
a tty or the terminal emulator might just not support mouse input.

*/
parse_mouse_input :: proc(input: []byte) -> (mouse_input: t.Mouse_Input, has_input: bool) {
	// the mouse input we support is SGR escape code based
	if len(input) < 6 do return

	if input[0] != '\x1b' && input[1] != '[' && input[2] != '<' do return

	consume_semicolon :: proc(input: ^string) -> bool {
		is_semicolon := len(input) >= 1 && input[0] == ';'
		if is_semicolon do input^ = input[1:]
		return is_semicolon
	}

	consumed: int
	input := cast(string)input[3:]

	mod, _ := strconv.parse_uint(input, n = &consumed)
	input = input[consumed:]
	consume_semicolon(&input) or_return

	x_coord, _ := strconv.parse_uint(input, n = &consumed)
	input = input[consumed:]
	consume_semicolon(&input) or_return

	y_coord, _ := strconv.parse_uint(input, n = &consumed)
	input = input[consumed:]

	mouse_key: t.Mouse_Key
	low_two_bits := mod & 0b11
	switch low_two_bits {
	case 0:
		mouse_key = .Left
	case 1:
		mouse_key = .Middle
	case 2:
		mouse_key = .Right
	}

	mouse_event: bit_set[t.Mouse_Event]
	if mouse_key != .None {
		if input[0] == 'm' do mouse_event |= {.Released}
		if input[0] == 'M' do mouse_event |= {.Pressed}
	}

	next_three_bits := mod & 0b11100
	mouse_mod: bit_set[t.Mod]
	if next_three_bits & 4 == 4 do mouse_mod |= {.Shift}
	if next_three_bits & 8 == 8 do mouse_mod |= {.Alt}
	if next_three_bits & 16 == 16 do mouse_mod |= {.Ctrl}

	if mod & 64 == 64 do mouse_key = .Scroll_Up
	if mod & 65 == 65 do mouse_key = .Scroll_Down

	return t.Mouse_Input {
			event = mouse_event,
			mod = mouse_mod,
			key = mouse_key,
			// coords are converted so it's 0 based index
			coord = {x = x_coord - 1, y = y_coord - 1},
		}, true
}
