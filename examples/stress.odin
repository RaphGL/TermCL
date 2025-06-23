package adsfadsf

import termcl ".."
import "core:fmt"
import "core:math/rand"
import "core:time"

//go:build ignore
// +build ignore

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

main :: proc() {
	screen := termcl.init_screen()

	frames: int

	// TermCL doesn't have a style type so I made one
	Style :: struct {
		text_style: termcl.Text_Style,
		fg:         termcl.RGB_Color,
		bg:         termcl.RGB_Color,
	}

	cell :: struct {
		c:     rune,
		style: Style,
	}

	size := termcl.get_term_size(&screen)
	height, width := int(size.h), int(size.w)
	glyphs := []rune{'@', '#', '&', '*', '=', '%', 'Z', 'A'}
	attrs := []termcl.Text_Style{.Bold, .Dim, .Italic, .Crossed}

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

	termcl.clear(&screen, .Everything)
	startTime := time.now()
	for time.since(startTime) < time.Second * 30 {
		pattern := patterns[frames % len(patterns)]
		for h in 0 ..< height {
			for w in 0 ..< width {
				cell := &pattern[h][w]
				termcl.move_cursor(&screen, uint(h), uint(w))
				termcl.set_color_style(&screen, cell.style.fg, cell.style.bg)
				termcl.write(&screen, cell.c)
			}
		}
		termcl.blit(&screen)
		frames += 1
	}
	delete(patterns)
	termcl.reset_styles(&screen)
	termcl.clear(&screen, .Everything)
	termcl.blit(&screen)
	termcl.destroy_screen(&screen)
	duration := time.since(startTime)
	fps := int(f64(frames) / time.duration_seconds(duration))
	fmt.println("------RESULTS------")
	fmt.println("FPS:", fps)
}

