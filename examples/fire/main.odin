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

import tcl "../.."
import "core:math/rand"

// Set the dimensions
txcols :: 80 // W
txrows :: 40 // H

fire: [txrows][txcols]int
coolmap: [txrows][txcols]int

// Executes the game intro.
main :: proc() {
	screen := tcl.init_screen()
	tcl.clear(&screen, .Everything)
	tcl.blit(&screen)

	CreateCoolMap()

	for {
		DrawScreen(&screen, false)
		tcl.blit(&screen)
	}
}

MAXAGE :: 80

pal := [MAXAGE]tcl.RGB_Color {
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF7, b = 0xD4},
	tcl.RGB_Color{r = 0xF9, g = 0xF6, b = 0xB6},
	tcl.RGB_Color{r = 0xF8, g = 0xF4, b = 0x8E},
	tcl.RGB_Color{r = 0xF8, g = 0xF3, b = 0x64},
	tcl.RGB_Color{r = 0xF8, g = 0xF1, b = 0x39},
	tcl.RGB_Color{r = 0xF9, g = 0xEC, b = 0x14},
	tcl.RGB_Color{r = 0xFA, g = 0xD5, b = 0x1B},
	tcl.RGB_Color{r = 0xFC, g = 0xBE, b = 0x22},
	tcl.RGB_Color{r = 0xFD, g = 0xA5, b = 0x2A},
	tcl.RGB_Color{r = 0xFF, g = 0x8C, b = 0x31},
	tcl.RGB_Color{r = 0xFA, g = 0x80, b = 0x2E},
	tcl.RGB_Color{r = 0xF4, g = 0x75, b = 0x2A},
	tcl.RGB_Color{r = 0xEE, g = 0x6A, b = 0x26},
	tcl.RGB_Color{r = 0xE9, g = 0x5E, b = 0x22},
	tcl.RGB_Color{r = 0xE3, g = 0x53, b = 0x1D},
	tcl.RGB_Color{r = 0xDE, g = 0x47, b = 0x1A},
	tcl.RGB_Color{r = 0xD5, g = 0x36, b = 0x13},
	tcl.RGB_Color{r = 0xCC, g = 0x25, b = 0x0D},
	tcl.RGB_Color{r = 0xC3, g = 0x12, b = 0x07},
	tcl.RGB_Color{r = 0xBB, g = 0x01, b = 0x00},
	tcl.RGB_Color{r = 0xAC, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x9D, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x8E, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x7F, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x70, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x61, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x5A, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x55, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x51, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x4D, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x48, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x44, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x3F, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x3B, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x37, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x32, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x2E, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x2A, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x25, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x21, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x1C, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x18, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x13, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x10, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x0B, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x07, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x02, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x00, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x00, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x00, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x00, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x00, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x00, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x00, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x00, g = 0x00, b = 0x00},
	tcl.RGB_Color{r = 0x00, g = 0x00, b = 0x00},
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
DrawScreen :: proc(screen: ^tcl.Screen, egg: bool) {
	MoveParticles()
	AddParticles()
	for y in 0 ..< txrows {
		for x in 0 ..< txcols {
			if fire[y][x] < MAXAGE {
				cage := Smooth(fire, x, y)
				cage += 10
				if cage >= MAXAGE do cage = MAXAGE - 1
				clr := pal[cage]
				tcl.move_cursor(screen, uint(y), uint(x))
				tcl.set_color_style_rgb(screen, nil, clr)
				tcl.write_rune(screen, ' ')
				tcl.reset_styles(screen)
			}
		}
	}
}

