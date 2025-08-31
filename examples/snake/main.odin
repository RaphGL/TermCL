package main

import t "../.."
import "core:math/rand"
import "core:time"

Direction :: enum {
	Up,
	Down,
	Left,
	Right,
}

Snake :: struct {
	head: [2]uint,
	body: [dynamic][2]uint,
	dir:  Direction,
}

get_term_center :: proc(s: ^t.Screen) -> [2]uint {
	termsize := t.get_window_size(s)
	pos := [2]uint{termsize.w / 2, termsize.h / 2}
	return pos
}

snake_init :: proc(s: ^t.Screen) -> Snake {
	DEFAULT_SNAKE_SIZE :: 4
	pos := get_term_center(s)
	pos.x -= DEFAULT_SNAKE_SIZE

	body := make([dynamic][2]uint)

	for i in 0 ..< DEFAULT_SNAKE_SIZE {
		curr_pos := pos
		curr_pos.x += uint(i)
		append(&body, curr_pos)
	}

	pos.x += DEFAULT_SNAKE_SIZE

	return Snake{head = pos, body = body, dir = .Right}
}

snake_destroy :: proc(snake: Snake) {
	delete(snake.body)
}

snake_draw :: proc(snake: Snake, s: ^t.Screen) {
	t.set_color_style(s, nil, .Green)
	defer t.reset_styles(s)

	for part in snake.body {
		t.move_cursor(s, part.y, part.x)
		t.write(s, ' ')
	}

	t.set_color_style(s, nil, .White)
	t.move_cursor(s, snake.head.y, snake.head.x)
	t.write(s, ' ')
}

Game_Box :: struct {
	x, y, w, h: uint,
}

box_init :: proc(s: ^t.Screen) -> Game_Box {
	termcenter := get_term_center(s)

	BOX_HEIGHT :: 20
	BOX_WIDTH :: 60

	return Game_Box {
		x = termcenter.x - BOX_WIDTH / 2,
		y = termcenter.y - BOX_HEIGHT / 2,
		w = BOX_WIDTH,
		h = BOX_HEIGHT,
	}
}

box_draw :: proc(game: Game, s: ^t.Screen) {
	box := game.box
	t.set_color_style(s, .Black, .White)
	defer t.reset_styles(s)

	draw_row :: proc(box: Game_Box, s: ^t.Screen, y: uint) {
		for i in 0 ..= box.w {
			t.move_cursor(s, y, box.x + i)
			t.write(s, ' ')
		}
	}

	draw_row(box, s, box.y)
	draw_row(box, s, box.y + box.h)

	draw_col :: proc(box: Game_Box, s: ^t.Screen, x: uint) {
		for i in 0 ..= box.h {
			t.move_cursor(s, box.y + i, x)
			t.write(s, ' ')
		}
	}

	draw_col(box, s, box.x)
	draw_col(box, s, box.x + box.w)

	t.set_text_style(s, {.Bold})
	msg := "Press 'q' to exit.  Player Score: %d"
	t.move_cursor(s, box.y + box.h, box.x + (box.w / 2 - len(msg) / 2))
	t.writef(s, msg, game.score)
	t.reset_styles(s)
}

snake_handle_input :: proc(s: ^t.Screen, game: ^Game, input: t.Keyboard_Input) {
	snake := &game.snake
	box := &game.box

	#partial switch input.key {
	case .Arrow_Left, .A:
		if snake.dir != .Right do snake.dir = .Left
	case .Arrow_Right, .D:
		if snake.dir != .Left do snake.dir = .Right
	case .Arrow_Up, .W:
		if snake.dir != .Down do snake.dir = .Up
	case .Arrow_Down, .S:
		if snake.dir != .Up do snake.dir = .Down
	}

	ordered_remove(&snake.body, 0)
	append(&snake.body, snake.head)

	switch snake.dir {
	case .Up:
		snake.head.y -= 1
	case .Down:
		snake.head.y += 1
	case .Left:
		snake.head.x -= 1
	case .Right:
		snake.head.x += 1
	}

	if snake.head.y <= box.y {
		snake.head.y = box.y + box.h - 1
	}

	if snake.head.y >= box.y + box.h {
		snake.head.y = box.y
	}

	if snake.head.x >= box.x + box.w {
		snake.head.x = box.x + 1
	}

	if snake.head.x <= box.x {
		snake.head.x = box.x + box.w - 1
	}
}

Food :: struct {
	x, y: uint,
}

food_generate :: proc(game: Game) -> Food {
	box := game.box
	x, y: uint

	for {
		x = (cast(uint)rand.uint32() % (box.w - 1)) + box.x + 1
		y = (cast(uint)rand.uint32() % (box.h - 1)) + box.y + 1

		no_collision := true
		for part in game.snake.body {
			if part.x == x && part.y == y {
				no_collision = false
			}
		}

		if no_collision do break
	}

	return Food{x = x, y = y}
}

Game :: struct {
	snake: Snake,
	box:   Game_Box,
	food:  Food,
	score: uint,
}

game_init :: proc(s: ^t.Screen) -> Game {
	game := Game {
		snake = snake_init(s),
		box   = box_init(s),
	}
	game.food = food_generate(game)
	return game
}

game_destroy :: proc(game: Game) {
	snake_destroy(game.snake)
}

game_is_over :: proc(game: Game, s: ^t.Screen) -> bool {
	snake := game.snake
	for part in snake.body {
		if part.x == snake.head.x && part.y == snake.head.y {
			return true
		}
	}

	return false
}

game_tick :: proc(game: ^Game, s: ^t.Screen) {
	if game.snake.head.x == game.food.x && game.snake.head.y == game.food.y {
		game.score += 1
		game.food = food_generate(game^)
		append(&game.snake.body, game.snake.body[len(game.snake.body) - 1])
	}

	t.move_cursor(s, game.food.y, game.food.x)
	t.set_color_style(s, nil, .Yellow)
	t.write(s, ' ')
	t.reset_styles(s)

	snake_draw(game.snake, s)
	box_draw(game^, s)
}


main :: proc() {
	s := t.init_screen()
	defer t.destroy_screen(&s)
	t.set_term_mode(&s, .Cbreak)
	t.hide_cursor(true)
	t.clear(&s, .Everything)
	t.blit(&s)

	game := game_init(&s)
	stopwatch: time.Stopwatch

	for {
		defer t.blit(&s)

		if game_is_over(game, &s) {
			t.move_cursor(&s, game.box.y + game.box.h + 5, 0)
			t.write(&s, "=== Game Over ===\n")
			break
		}

		time.stopwatch_start(&stopwatch)
		defer time.stopwatch_reset(&stopwatch)
		t.clear(&s, .Everything)

		input, _ := t.read(&s)
		keys, kb_has_input := t.parse_keyboard_input(input)

		if kb_has_input && (keys.key == .Q) {
			break
		}


		snake_handle_input(&s, &game, keys)

		for {
			duration := time.stopwatch_duration(stopwatch)
			millisecs := time.duration_milliseconds(duration)
			if millisecs > 80 {
				break
			}
		}

		game_tick(&game, &s)
	}
}

