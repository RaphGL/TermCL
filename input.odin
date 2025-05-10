package termcl

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:unicode"

Input :: distinct []byte

Key :: enum {
	None,
	Arrow_Left,
	Arrow_Right,
	Arrow_Up,
	Arrow_Down,
	Page_Up,
	Page_Down,
	Home,
	End,
	Insert,
	Delete,
	F1,
	F2,
	F3,
	F4,
	F5,
	F6,
	F7,
	F8,
	F9,
	F10,
	F11,
	F12,
	Escape,
	Num_0,
	Num_1,
	Num_2,
	Num_3,
	Num_4,
	Num_5,
	Num_6,
	Num_7,
	Num_8,
	Num_9,
	Enter,
	Tab,
	Backspace,
	A,
	B,
	C,
	D,
	E,
	F,
	G,
	H,
	I,
	J,
	K,
	L,
	M,
	N,
	O,
	P,
	Q,
	R,
	S,
	T,
	U,
	V,
	W,
	X,
	Y,
	Z,
	Minus,
	Plus,
	Equal,
	Open_Paren,
	Close_Paren,
	Open_Curly_Bracket,
	Close_Curly_Bracket,
	Open_Square_Bracket,
	Close_Square_Bracket,
	Colon,
	Semicolon,
	Slash,
	Backslash,
	Single_Quote,
	Double_Quote,
	Period,
	Asterisk,
	Backtick,
	Space,
	Dollar,
	Exclamation,
	Hash,
	Percent,
	Ampersand,
	Tick,
	Underscore,
	Caret,
	Comma,
	Pipe,
	At,
	Tilde,
}

Mod :: enum {
	None,
	Alt,
	Ctrl,
	Shift,
}

Input_Seq :: struct {
	mod: Mod,
	key: Key,
}

// Parses the raw bytes sent by the terminal in `Input` and returns an input sequence
// If there's no valid keyboard input, `has_input` is false
//
// Note: the terminal processes some inputs making them be treated the same so if you try to
// parse an input and find that it's not being detected, check what value it is processed into.
// Example: Escape might be Esc, Ctrl + [ and Ctrl + 3
parse_keyboard_input :: proc(input: Input) -> (keyboard_input: Input_Seq, has_input: bool) {
	input := input
	seq: Input_Seq

	if len(input) == 0 do return

	if len(input) == 1 {
		input_rune := cast(rune)input[0]
		if unicode.is_upper(input_rune) {
			seq.mod = .Shift
		}

		if unicode.is_control(input_rune) {
			switch input_rune {
			case '\r', '\n', '\t', '\x1b':
			case:
				seq.mod = .Ctrl
				input[0] += 64
			}
		}

		switch input[0] {
		case '\x1b':
			seq.key = .Escape
		case '1':
			seq.key = .Num_1
		case '2':
			seq.key = .Num_2
		case '3':
			seq.key = .Num_3
		case '4':
			seq.key = .Num_4
		case '5':
			seq.key = .Num_5
		case '6':
			seq.key = .Num_6
		case '7':
			seq.key = .Num_7
		case '8':
			seq.key = .Num_8
		case '9':
			seq.key = .Num_9
		case '0':
			seq.key = .Num_0
		case '\r', '\n':
			seq.key = .Enter
		case '\t':
			seq.key = .Tab
		case 8, 127:
			seq.key = .Backspace
		case 'a', 'A':
			seq.key = .A
		case 'b', 'B':
			seq.key = .B
		case 'c', 'C':
			seq.key = .C
		case 'd', 'D':
			seq.key = .D
		case 'e', 'E':
			seq.key = .E
		case 'f', 'F':
			seq.key = .F
		case 'g', 'G':
			seq.key = .G
		case 'h', 'H':
			seq.key = .H
		case 'i', 'I':
			seq.key = .I
		case 'j', 'J':
			seq.key = .J
		case 'k', 'K':
			seq.key = .K
		case 'l', 'L':
			seq.key = .L
		case 'm', 'M':
			seq.key = .M
		case 'n', 'N':
			seq.key = .N
		case 'o', 'O':
			seq.key = .O
		case 'p', 'P':
			seq.key = .P
		case 'q', 'Q':
			seq.key = .Q
		case 'r', 'R':
			seq.key = .R
		case 's', 'S':
			seq.key = .S
		case 't', 'T':
			seq.key = .T
		case 'u', 'U':
			seq.key = .U
		case 'v', 'V':
			seq.key = .V
		case 'w', 'W':
			seq.key = .W
		case 'x', 'X':
			seq.key = .X
		case 'y', 'Y':
			seq.key = .Y
		case 'z', 'Z':
			seq.key = .Z
		case ',':
			seq.key = .Comma
		case ':':
			seq.key = .Colon
		case ';':
			seq.key = .Semicolon
		case '-':
			seq.key = .Minus
		case '+':
			seq.key = .Plus
		case '=':
			seq.key = .Equal
		case '{':
			seq.key = .Open_Curly_Bracket
		case '}':
			seq.key = .Close_Curly_Bracket
		case '(':
			seq.key = .Open_Paren
		case ')':
			seq.key = .Close_Paren
		case '[':
			seq.key = .Open_Square_Bracket
		case ']':
			seq.key = .Close_Square_Bracket
		case '/':
			seq.key = .Slash
		case '\'':
			seq.key = .Single_Quote
		case '"':
			seq.key = .Double_Quote
		case '.':
			seq.key = .Period
		case '*':
			seq.key = .Asterisk
		case '`':
			seq.key = .Backtick
		case '\\':
			seq.key = .Backslash
		case ' ':
			seq.key = .Space
		case '$':
			seq.key = .Dollar
		case '!':
			seq.key = .Exclamation
		case '#':
			seq.key = .Hash
		case '%':
			seq.key = .Percent
		case '&':
			seq.key = .Ampersand
		case '´':
			seq.key = .Tick
		case '_':
			seq.key = .Underscore
		case '^':
			seq.key = .Caret
		case '|':
			seq.key = .Pipe
		case '@':
			seq.key = .At
		case '~':
			seq.key = .Tilde
		case:
			return
		}

		return seq, true
	}

	if input[0] != '\x1b' do return

	if input[1] == 10 {
		seq.mod = .Alt
		seq.key = .Enter
		return seq, true
	}

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

	return
}

Mouse_Event :: enum {
	Pressed,
	Released,
}

Mouse_Key :: enum {
	None,
	Left,
	Middle,
	Right,
	Scroll_Up,
	Scroll_Down,
}

Mouse_Input :: struct {
	event: bit_set[Mouse_Event],
	mod:   bit_set[Mod],
	key:   Mouse_Key,
	coord: struct {
		x, y: uint,
	},
}

// Parses the raw bytes sent by the terminal in `Input` and returns an input sequence
// If there's no valid mouse input, `has_input` is false
parse_mouse_input :: proc(input: Input) -> (mouse_input: Mouse_Input, has_input: bool) {
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

	mouse_event: bit_set[Mouse_Event]
	if input[0] == 'm' do mouse_event |= {.Released}
	if input[0] == 'M' do mouse_event |= {.Pressed}

	mouse_key: Mouse_Key
	low_two_bits := mod & 0b11
	switch low_two_bits {
	case 0:
		mouse_key = .Left
	case 1:
		mouse_key = .Middle
	case 2:
		mouse_key = .Right
	}

	next_three_bits := mod & 0b11100
	mouse_mod: bit_set[Mod]
	if next_three_bits & 4 == 4 do mouse_mod |= {.Shift}
	if next_three_bits & 8 == 8 do mouse_mod |= {.Alt}
	if next_three_bits & 16 == 16 do mouse_mod |= {.Ctrl}

	if mod & 64 == 64 do mouse_key = .Scroll_Up
	if mod & 65 == 65 do mouse_key = .Scroll_Down

	return Mouse_Input {
			event = mouse_event,
			mod = mouse_mod,
			key = mouse_key,
			// coords are converted so it's 0 based index
			coord = {x = x_coord - 1, y = y_coord - 1},
		}, true
}

