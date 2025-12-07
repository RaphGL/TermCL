package kitty_keyboard

import "../term"
import "core:fmt"
import os "core:os/os2"
import "core:strconv"
import "core:strings"
import "core:terminal/ansi"
import "core:unicode"

Modifier :: enum {
	Shift     = 1,
	Alt       = 2,
	Ctrl      = 3,
	Super     = 4,
	Hyper     = 5,
	Meta      = 6,
	Caps_Lock = 7,
	Num_Lock  = 8,
}

Event :: enum {
	Press   = 1,
	Repeat  = 2,
	Release = 3,
}

enable :: proc(enable: bool) {
	if enable {
		fmt.print(ansi.CSI + ">1u")
	} else {
		fmt.print(ansi.CSI + "<u")
	}
}

parse :: proc() {
	// TODO: parse inputs
}

is_supported :: proc() -> bool {
	_, ok := query_enhancements()
	return ok
}

Enhancement :: enum {
	// https://sw.kovidgoyal.net/kitty/keyboard-protocol/#disambiguate-escape-codes
	Disambiguate_Escape_Codes       = 0,
	// https://sw.kovidgoyal.net/kitty/keyboard-protocol/#report-event-types
	Report_Event_types              = 1,
	// https://sw.kovidgoyal.net/kitty/keyboard-protocol/#report-alternate-keys
	Report_Alternate_Keys           = 2,
	// https://sw.kovidgoyal.net/kitty/keyboard-protocol/#report-all-keys-as-escape-codes
	Report_All_Keys_As_Escape_Codes = 3,
	// https://sw.kovidgoyal.net/kitty/keyboard-protocol/#report-associated-text
	Report_Associated_Text          = 4,
}

query_enhancements :: proc() -> (enhancements: bit_set[Enhancement], ok: bool) {
	sb: strings.Builder
	strings.builder_init(&sb)
	defer strings.builder_destroy(&sb)

	strings.write_string(&sb, ansi.CSI)
	strings.write_rune(&sb, '?')
	strings.write_rune(&sb, 'u')

	query := strings.to_string(sb)
	os.write_string(os.stdout, query)

	response: [10]byte
	term.raw_read(response[:])

	if cast(string)response[:2] != ansi.CSI do return
	if response[2] != '?' do return

	enhancement_end := 3
	for b, i in response[3:] {
		if !unicode.is_digit(cast(rune)b) {
			enhancement_end += i
			break
		}
	}

	enhancement_int := strconv.parse_int(cast(string)response[3:enhancement_end]) or_return
	enhancements = transmute(bit_set[Enhancement])cast(u8)enhancement_int
	ok = true
	return
}

Enhancement_Request_Mode :: enum {
	// only the bits that have beeen set are enabled
	Enable_Set_Bits_Only = 1,
	// add set bits and leave unset bits unchanged
	Add_Set_Bits         = 2,
	// remove set bits and leave unset bits unchanged
	Remote_Set_Bits      = 3,
}

request_enhancements :: proc(enhancements: bit_set[Enhancement], mode: Enhancement_Request_Mode) {
	sb: strings.Builder
	strings.builder_init(&sb)
	defer strings.builder_destroy(&sb)

	strings.write_string(&sb, ansi.CSI)
	strings.write_rune(&sb, '=')
	strings.write_int(&sb, cast(int)transmute(u8)enhancements)
	strings.write_rune(&sb, ';')
	strings.write_int(&sb, cast(int)mode)
	strings.write_rune(&sb, 'u')
	os.write_string(os.stdout, strings.to_string(sb))
}

push_enhancements :: proc(enhancements: bit_set[Enhancement]) {
	sb: strings.Builder
	strings.builder_init(&sb)
	defer strings.builder_destroy(&sb)

	enhancements_buf: [2]byte
	strings.write_string(&sb, ansi.CSI)
	strings.write_rune(&sb, '>')
	strings.write_int(&sb, cast(int)transmute(u8)enhancements)
	strings.write_rune(&sb, 'u')
	os.write_string(os.stdout, strings.to_string(sb))
}

pop_enhancements :: proc(num_of_entries: int) {
	if num_of_entries < 0 do return

	sb: strings.Builder
	strings.builder_init(&sb)
	defer strings.builder_destroy(&sb)

	strings.write_string(&sb, ansi.CSI)
	strings.write_rune(&sb, '<')
	strings.write_int(&sb, num_of_entries)
	strings.write_rune(&sb, 'u')
	os.write_string(os.stdout, strings.to_string(sb))
}
