// stress is a port of the tcell stress test

// Copyright 2022 The TCell Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use file except in compliance with the License.
// You may obtain a copy of the license at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// stress will fill the whole screen with random characters, colors and
// formatting. The frames are pre-generated to draw as fast as possible.
// ESC and Ctrl-C will end the program. Note that resizing isn't supported.
package stress

import t "../.."
import tb "../../term"
import "core:fmt"
import "core:math/rand"
import "core:time"


main :: proc() {
	screen := t.init_screen()
	frames: int

	Style :: struct {
		text_style: t.Text_Style,
		fg:         t.Color_RGB,
		bg:         t.Color_RGB,
	}

	cell :: struct {
		c:     rune,
		style: Style,
	}

	size := t.get_window_size(&screen)
	height, width := int(size.h), int(size.w)
	glyphs := []rune{'@', '#', '&', '*', '=', '%', 'Z', 'A'}
	attrs := []t.Text_Style{.Bold, .Dim, .Italic, .Crossed}

	// Pre-Generate 100 different frame patterns, so we stress the terminal as
	// much as possible :D
	patterns := make([][][]cell, 100)
	for i := 0; i < 100; i += 1 {
		pattern := make([][]cell, height)
		for h := 0; h < height; h += 1 {
			row := make([]cell, width)
			for w := 0; w < width; w += 1 {
				rF := u8(rand.int_max(256))
				gF := u8(rand.int_max(256))
				bF := u8(rand.int_max(256))
				rB := u8(rand.int_max(256))
				gB := u8(rand.int_max(256))
				bB := u8(rand.int_max(256))

				row[w] = cell {
					c = rand.choice(glyphs),
					style = {
						text_style = rand.choice(attrs),
						bg = {rB, gB, bB},
						fg = {rF, gF, bF},
					},
				}
			}
			pattern[h] = row
		}
		patterns[i] = pattern
	}

	t.clear(&screen, .Everything)
	start_time := time.now()
	for time.since(start_time) < 30 * time.Second {
		pattern := patterns[frames % len(patterns)]
		for h in 0 ..< height {
			for w in 0 ..< width {
				cell := &pattern[h][w]
				t.move_cursor(&screen, uint(h), uint(w))
				t.set_color_style(&screen, cell.style.fg, cell.style.bg)
				t.write(&screen, cell.c)
			}
		}
		t.blit(&screen)
		frames += 1
	}
	delete(patterns)
	t.reset_styles(&screen)
	t.clear(&screen, .Everything)
	t.blit(&screen)
	t.destroy_screen(&screen)
	duration := time.since(start_time)
	fps := int(f64(frames) / time.duration_seconds(duration))
	fmt.println("------RESULTS------")
	fmt.println("FPS:", fps)
}

