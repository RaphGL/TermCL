/*****************************************************************************
* This file is a partial odin port of Let's Build a Roguelike Chapter 6
* by Richard D. Clark, originally licensed under the Wide Open License. 
*
* The original copyright notice is preserved below.
*
* Copyright 2010, Richard D. Clark
*
*                          The Wide Open License (WOL)
*
* Permission to use, copy, modify, distribute and sell this software and its
* documentation for any purpose is hereby granted without fee, provided that
* the above copyright notice and this license appear in all source copies. 
* THIS SOFTWARE IS PROVIDED "AS IS" WITHOUT EXPRESS OR IMPLIED WARRANTY OF
* ANY KIND. See http://www.dspguru.com/wol.htm for more information.
*
*****************************************************************************/

package main

import t "../.."
import tb "../../term"
import "core:math/rand"

// Set the dimensions
txcols :: 80 // W
txrows :: 40 // H

fire: [txrows][txcols]int
coolmap: [txrows][txcols]int

// Executes the game intro.
main :: proc() {
	tb.set_backend()
	screen := t.init_screen()
	defer t.destroy_screen(&screen)
	t.clear(&screen, .Everything)
	t.blit(&screen)
	t.hide_cursor(true)

	CreateCoolMap()

	for {
		DrawScreen(&screen, false)
		t.blit(&screen)
	}
}

MAXAGE :: 80

pal := [MAXAGE]t.Color_RGB {
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF7, 0xD4},
	{0xF9, 0xF6, 0xB6},
	{0xF8, 0xF4, 0x8E},
	{0xF8, 0xF3, 0x64},
	{0xF8, 0xF1, 0x39},
	{0xF9, 0xEC, 0x14},
	{0xFA, 0xD5, 0x1B},
	{0xFC, 0xBE, 0x22},
	{0xFD, 0xA5, 0x2A},
	{0xFF, 0x8C, 0x31},
	{0xFA, 0x80, 0x2E},
	{0xF4, 0x75, 0x2A},
	{0xEE, 0x6A, 0x26},
	{0xE9, 0x5E, 0x22},
	{0xE3, 0x53, 0x1D},
	{0xDE, 0x47, 0x1A},
	{0xD5, 0x36, 0x13},
	{0xCC, 0x25, 0x0D},
	{0xC3, 0x12, 0x07},
	{0xBB, 0x01, 0x00},
	{0xAC, 0x00, 0x00},
	{0x9D, 0x00, 0x00},
	{0x8E, 0x00, 0x00},
	{0x7F, 0x00, 0x00},
	{0x70, 0x00, 0x00},
	{0x61, 0x00, 0x00},
	{0x5A, 0x00, 0x00},
	{0x55, 0x00, 0x00},
	{0x51, 0x00, 0x00},
	{0x4D, 0x00, 0x00},
	{0x48, 0x00, 0x00},
	{0x44, 0x00, 0x00},
	{0x3F, 0x00, 0x00},
	{0x3B, 0x00, 0x00},
	{0x37, 0x00, 0x00},
	{0x32, 0x00, 0x00},
	{0x2E, 0x00, 0x00},
	{0x2A, 0x00, 0x00},
	{0x25, 0x00, 0x00},
	{0x21, 0x00, 0x00},
	{0x1C, 0x00, 0x00},
	{0x18, 0x00, 0x00},
	{0x13, 0x00, 0x00},
	{0x10, 0x00, 0x00},
	{0x0B, 0x00, 0x00},
	{0x07, 0x00, 0x00},
	{0x02, 0x00, 0x00},
	{0x00, 0x00, 0x00},
	{0x00, 0x00, 0x00},
	{0x00, 0x00, 0x00},
	{0x00, 0x00, 0x00},
	{0x00, 0x00, 0x00},
	{0x00, 0x00, 0x00},
	{0x00, 0x00, 0x00},
	{0x00, 0x00, 0x00},
	{0x00, 0x00, 0x00},
}

// This smooths the fire by averaging the values.
Smooth :: proc(arr: [txrows][txcols]int, x, y: int) -> int {
	xx, yy, cnt, v: int

	cnt = 0

	v = arr[y][x]
	cnt += 1

	if x < txcols - 1 {
		xx = x + 1
		yy = y
		v += arr[yy][xx]
		cnt += 1
	}

	if x > 0 {
		xx = x - 1
		yy = y
		v += arr[yy][xx]
		cnt += 1
	}

	if y < txrows - 1 {
		xx = x
		yy = (y + 1)
		v += arr[y + 1][x]
		cnt += 1
	}

	if y > 0 {
		xx = x
		yy = (y - 1)
		v += arr[y - 1][x]
		cnt += 1
	}

	v = v / cnt

	return v
}

//Creates a cool map that will combined with the fire value to give a nice effect.
CreateCoolMap :: proc() {
	for y in 0 ..< txrows {
		for x in 0 ..< txcols {
			coolmap[y][x] = rand.int_max(21) - 10
		}
	}


	for _ in 0 ..= 9 {
		for y in 1 ..< txrows - 1 {
			for x in 1 ..< txcols - 1 {
				coolmap[y][x] = Smooth(coolmap, x, y)
			}
		}
	}
}

// Moves each particle up on the screen, with a chance of moving side to side.
MoveParticles :: proc() {
	for y in 1 ..< txrows {
		for x in 0 ..< txcols {
			// Get the current age of the particle.
			tage := fire[y][x]
			//Moves particle left (-1) or right (1) or keeps it in current column (0).
			xx := rand.int_max(3) - 1 + x
			// Wrap around the screen.
			if xx < 0 do xx = txcols - 1
			if xx > txcols - 1 do xx = 0
			// Set the particle age.
			tage += coolmap[y - 1][xx] + 1
			// Make sure the age is in range.
			if tage < 0 do tage = 0
			if tage > (MAXAGE - 1) do tage = MAXAGE - 1
			fire[y - 1][xx] = tage
		}
	}

}

// Adds particles to the fire along bottom of screen.
AddParticles :: proc() {
	for x in 0 ..< txcols {
		fire[txrows - 1][x] = rand.int_max(21)
	}

}

// Draws the fire or parchment on the screen.
DrawScreen :: proc(screen: ^t.Screen, egg: bool) {
	MoveParticles()
	AddParticles()
	for y in 0 ..< txrows {
		for x in 0 ..< txcols {
			if fire[y][x] < MAXAGE {
				cage := Smooth(fire, x, y)
				cage += 10
				if cage >= MAXAGE do cage = MAXAGE - 1
				clr := pal[cage]
				t.move_cursor(screen, uint(y), uint(x))
				t.set_color_style(screen, nil, clr)
				t.write_rune(screen, ' ')
				t.reset_styles(screen)
			}
		}
	}
}

