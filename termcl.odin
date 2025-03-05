package termcl

import "base:runtime"
import "core:encoding/ansi"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/posix"

Screen :: struct {
	allocator:          runtime.Allocator,
	seq_builder:        strings.Builder,
	original_termstate: posix.termios,
	input_buf:          [512]byte,
}

init_screen :: proc(allocator := context.temp_allocator) -> Screen {
	context.allocator = allocator

	termstate: posix.termios
	posix.tcgetattr(posix.STDIN_FILENO, &termstate)

	return Screen {
		allocator = allocator,
		seq_builder = strings.builder_make(),
		original_termstate = termstate,
	}
}

destroy_screen :: proc(screen: ^Screen) {
	free_all(screen.allocator)
	posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &screen.original_termstate)
	strings.builder_destroy(&screen.seq_builder)
}

blit_screen :: proc(screen: ^Screen) {
	fmt.print(strings.to_string(screen.seq_builder))
	strings.builder_reset(&screen.seq_builder)
}

Direction :: enum {
	Up,
	Down,
	Left,
	Right,
}

// changes the cursor's position relative to the current position
step_cursor :: proc(screen: ^Screen, dir: bit_set[Direction], steps: uint) {
	MOVE_CURSOR_UP :: ansi.CSI + "%dA"
	MOVE_CURSOR_DOWN :: ansi.CSI + "%dB"
	MOVE_CURSOR_RIGHT :: ansi.CSI + "%dC"
	MOVE_CURSOR_LEFT :: ansi.CSI + "%dD"

	if .Up in dir {
		strings.write_string(&screen.seq_builder, fmt.tprintf(MOVE_CURSOR_UP, steps))
	}
	if .Down in dir {
		strings.write_string(&screen.seq_builder, fmt.tprintf(MOVE_CURSOR_DOWN, steps))
	}
	if .Left in dir {
		strings.write_string(&screen.seq_builder, fmt.tprintf(MOVE_CURSOR_LEFT, steps))
	}
	if .Right in dir {
		strings.write_string(&screen.seq_builder, fmt.tprintf(MOVE_CURSOR_RIGHT, steps))
	}
}

// changes the cursor's absolute position
move_cursor :: proc(screen: ^Screen, y, x: uint) {
	CURSOR_POSITION :: ansi.CSI + "%d;%dH"
	// x and y are shifted by one position so that programmers can keep using 0 based indexing
	strings.write_string(&screen.seq_builder, fmt.tprintf(CURSOR_POSITION, y + 1, x + 1))
}

Text_Style :: enum {
	Bold,
	Italic,
	Underline,
	Crossed,
	Inverted,
	Dim,
}

hide_cursor :: proc(hide: bool) {
	SHOW_CURSOR :: ansi.CSI + "?25h"
	HIDE_CURSOR :: ansi.CSI + "?25l"
	fmt.print(HIDE_CURSOR if hide else SHOW_CURSOR)
}

set_text_style :: proc(screen: ^Screen, styles: bit_set[Text_Style]) {
	SGR_BOLD :: ansi.CSI + ansi.BOLD + "m"
	SGR_DIM :: ansi.CSI + ansi.FAINT + "m"
	SGR_ITALIC :: ansi.CSI + ansi.ITALIC + "m"
	SGR_UNDERLINE :: ansi.CSI + ansi.UNDERLINE + "m"
	SGR_INVERTED :: ansi.CSI + ansi.INVERT + "m"
	SGR_CROSSED :: ansi.CSI + ansi.STRIKE + "m"

	if .Bold in styles do strings.write_string(&screen.seq_builder, SGR_BOLD)
	if .Dim in styles do strings.write_string(&screen.seq_builder, SGR_DIM)
	if .Italic in styles do strings.write_string(&screen.seq_builder, SGR_ITALIC)
	if .Underline in styles do strings.write_string(&screen.seq_builder, SGR_UNDERLINE)
	if .Inverted in styles do strings.write_string(&screen.seq_builder, SGR_INVERTED)
	if .Crossed in styles do strings.write_string(&screen.seq_builder, SGR_CROSSED)
}

Color_8 :: enum {
	Black,
	Red,
	Green,
	Yellow,
	Blue,
	Magenta,
	Cyan,
	White,
}

// sets colors based from the original 8 color palette
set_color_style_8 :: proc(screen: ^Screen, fg: Maybe(Color_8), bg: Maybe(Color_8)) {
	SGR_COLOR :: ansi.CSI + "%dm"

	get_color_code :: proc(c: Color_8, is_bg: bool) -> uint {
		code: uint
		switch c {
		case .Black:
			code = 30
		case .Red:
			code = 31
		case .Green:
			code = 32
		case .Yellow:
			code = 33
		case .Blue:
			code = 34
		case .Magenta:
			code = 35
		case .Cyan:
			code = 36
		case .White:
			code = 37
		}

		if is_bg do code += 10
		return code
	}

	strings.write_string(
		&screen.seq_builder,
		fmt.tprintf(SGR_COLOR, get_color_code(fg.?, false) if fg != nil else 39),
	) // 39 == default foreground
	strings.write_string(
		&screen.seq_builder,
		fmt.tprintf(SGR_COLOR, get_color_code(bg.?, true) if bg != nil else 49), // 49 == default background
	)
}

RGB_Color :: struct {
	r, g, b: u8,
}

set_color_style_rgb :: proc(screen: ^Screen, fg: RGB_Color, bg: Maybe(RGB_Color)) {
	RGB_FG_COLOR :: ansi.CSI + "38;2;%d;%d;%dm"
	RGB_BG_COLOR :: ansi.CSI + "48;2;%d;%d;%dm"

	strings.write_string(&screen.seq_builder, fmt.tprintf(RGB_FG_COLOR, fg.r, fg.g, fg.b))
	if bg != nil {
		bg := bg.?
		strings.write_string(&screen.seq_builder, fmt.tprintf(RGB_BG_COLOR, bg.r, bg.g, bg.b))
	}
}

reset_styles :: proc(screen: ^Screen) {
	strings.write_string(&screen.seq_builder, ansi.CSI + "0m")
}

Clear_Mode :: enum {
	Before_Cursor,
	After_Cursor,
	Everything,
}

// clears screen starting from current line.
// can clear everything or before or after the current line
clear_screen :: proc(screen: ^Screen, mode: Clear_Mode) {
	switch mode {
	case .After_Cursor:
		strings.write_string(&screen.seq_builder, ansi.CSI + "0J")
	case .Before_Cursor:
		strings.write_string(&screen.seq_builder, ansi.CSI + "1J")
	case .Everything:
		strings.write_string(&screen.seq_builder, ansi.CSI + "2J")
	}
}

// clears current line before or after cursor or entirely
clear_line :: proc(screen: ^Screen, mode: Clear_Mode) {
	switch mode {
	case .After_Cursor:
		strings.write_string(&screen.seq_builder, ansi.CSI + "0K")
	case .Before_Cursor:
		strings.write_string(&screen.seq_builder, ansi.CSI + "1K")
	case .Everything:
		strings.write_string(&screen.seq_builder, ansi.CSI + "2K")
	}
}

ring_bell :: proc() {
	fmt.print("\a")
}

write_string :: proc(screen: ^Screen, str: string) {
	strings.write_string(&screen.seq_builder, str)
}

write_rune :: proc(screen: ^Screen, r: rune) {
	strings.write_rune(&screen.seq_builder, r)
}

write :: proc {
	write_string,
	write_rune,
}

writef :: proc(screen: ^Screen, format: string, args: ..any) {
	fmt.sbprintf(&screen.seq_builder, format, ..args)
}

Input :: distinct []byte

read :: proc(screen: ^Screen) -> (user_input: Input, has_input: bool) {
	bytes_read, err := os.read_ptr(os.stdin, &screen.input_buf, len(screen.input_buf))
	if err != nil {
		fmt.eprintln("failing to get user input")
		os.exit(1)
	}

	return Input(screen.input_buf[:bytes_read]), bytes_read > 0
}

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
}

Mod :: enum {
	None,
	Alt,
	Ctrl,
}

Input_Seq :: struct {
	mod: Mod,
	key: Key,
}

// TODO: interpret ctrl + ch using a lookup array or something
interpret_input :: proc(input: Input) -> Input_Seq {
	seq: Input_Seq

	if len(input) == 0 {
		return {}
	}

	// TODO: input ctrl + ch and regular ch here
	if len(input) == 1 {
		return {}
	}

	if len(input) == 3 && input[0] == '\x1b' && input[1] == 'O' {
		switch input[2] {
		case 'P':
			seq.key = .F1
		case 'Q':
			seq.key = .F2
		case 'R':
			seq.key = .F3
		case 'S':
			seq.key = .F4

		}
		return seq
	}

	if input[0] == '\x1b' && input[1] == '[' {
		if len(input) == 3 {
			switch input[2] {
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
			}
		}


		if len(input) == 4 {
			switch input[2] {
			case 'O':
				switch input[3] {
				case 'H':
					seq.key = .Home
				case 'F':
					seq.key = .End
				}
			case '1':
				switch input[3] {
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

		if len(input) == 4 && input[3] == '~' {
			switch input[2] {
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
		}

		if len(input) == 5 && input[4] == '~' {
			switch input[2] {
			case '1':
				switch input[3] {
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
				switch input[3] {
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

		return seq
	}

	return {}
}

Term_Mode :: enum {
	// Raw mode, prevents the terminal from preprocessing inputs
	Raw,
	// Restores the mode the terminal was in before program started
	Restored,
	// A sort of "soft" raw mode that allows interrupts to still work
	Cbreak,
}

set_term_mode :: proc(screen: ^Screen, mode: Term_Mode) {
	raw: posix.termios
	if posix.tcgetattr(posix.STDIN_FILENO, &raw) != .OK {
		fmt.eprintln(#procedure, "failed:", "tcgetattr returned an error")
		os.exit(1)
	}

	switch mode {
	case .Raw:
		raw.c_lflag -= {.ECHO, .ICANON, .ISIG, .IEXTEN}
		raw.c_iflag -= {.ICRNL, .IXON}
		raw.c_oflag -= {.OPOST}

		// probably meaningless on modern terminals but apparently it's good practice
		raw.c_iflag -= {.BRKINT, .INPCK, .ISTRIP}
		raw.c_cflag |= {.CS8}

	case .Cbreak:
		raw.c_lflag -= {.ECHO, .ICANON}

	case .Restored:
		raw = screen.original_termstate
	}

	if mode == .Raw || mode == .Cbreak {
		// timeout for reads
		raw.c_cc[.VMIN] = 0
		raw.c_cc[.VTIME] = 1 // 100 ms

	}

	if posix.tcsetattr(posix.STDIN_FILENO, .TCSAFLUSH, &raw) != .OK {
		fmt.eprintln(#procedure, "failed:", "tcsetattr returned an error")
		os.exit(1)
	}
}

Screen_Size :: struct {
	h, w: uint,
}

