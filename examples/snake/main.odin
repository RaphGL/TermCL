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

get_term_center :: proc() -> [2]uint {
	termsize := t.get_term_size()
	pos := [2]uint{termsize.w / 2, termsize.h / 2}
	return pos
}

snake_init :: proc(s: ^t.Screen) -> Snake {
	DEFAULT_SNAKE_SIZE :: 4
	pos := get_term_center()
	pos.x -= DEFAULT_SNAKE_SIZE

	body := make([dynamic][2]uint)

	for i in 0 ..< DEFAULT_SNAKE_SIZE {
		curr_pos := pos
		curr_pos.x += uint(i)
		append(&body, curr_pos)
	}

	pos.x += DEFAULT_SNAKE_SIZE - 1

	return Snake{head = pos, body = body, dir = .Right}
}

snake_destroy :: proc(snake: Snake) {
	delete(snake.body)
}

snake_draw :: proc(snake: Snake, s: ^t.Screen) {
	t.set_color_style_8(s, .Green, .Green)
	defer t.reset_styles(s)

	for part in snake.body {
		t.move_cursor(s, part.y, part.x)
		t.write(s, ' ')
	}

	t.set_color_style_8(s, .White, .White)
	t.move_cursor(s, snake.head.y, snake.head.x)
	t.write(s, ' ')
}

Game_Box :: struct {
	x, y, w, h: uint,
}

box_init :: proc() -> Game_Box {
	termcenter := get_term_center()

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
	t.set_color_style_8(s, .Black, .White)
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

	msg := "Player Score: %d"
	t.move_cursor(s, box.y + box.h, box.x + (box.w / 2 - len(msg) / 2))
	t.writef(s, msg, game.score)
}

snake_handle_input :: proc(s: ^t.Screen, game: ^Game, input: t.Input_Seq) {
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

	append(&snake.body, snake.head)
}

Food :: struct {
	x, y: uint,
}

food_generate :: proc(game: Game) -> Food {
	box := game.box
	x, y: uint

	for {
		x = cast(uint)rand.uint32() % (box.x + box.w)
		y = cast(uint)rand.uint32() % (box.y + box.h)
		if x < box.x do x += box.x
		if y < box.y do y += box.y

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
		box   = box_init(),
	}
	game.food = food_generate(game)
	return game
}

game_destroy :: proc(game: Game) {
	snake_destroy(game.snake)
}

game_tick :: proc(s: ^t.Screen, game: ^Game) {
	if game.snake.head.x == game.food.x && game.snake.head.y == game.food.y {
		game.score += 1
		game.food = food_generate(game^)
	}

	t.move_cursor(s, game.food.y, game.food.x)
	t.set_color_style_8(s, .Yellow, .Yellow)
	t.write(s, ' ')
	t.reset_styles(s)

	snake_draw(game.snake, s)
	box_draw(game^, s)
}

main :: proc() {
	s := t.init_screen()
	defer t.destroy_screen(&s)
	t.set_term_mode(&s, .Raw)
	t.hide_cursor(true)
	defer t.hide_cursor(false)
	t.clear_screen(&s, .Everything)
	t.blit_screen(&s)

	game := game_init(&s)
	stopwatch: time.Stopwatch

	for {
		defer t.blit_screen(&s)

		time.stopwatch_start(&stopwatch)
		defer time.stopwatch_reset(&stopwatch)
		t.clear_screen(&s, .Everything)


		input, has_input := t.read(&s)
		keys := t.interpret_input(input)

		if has_input {
			#partial switch keys.key {
			case .Escape:
				return
			}
		}

		snake_handle_input(&s, &game, keys)

		for {
			duration := time.stopwatch_duration(stopwatch)
			nanosecs := duration / 1000000
			if nanosecs > 16 {
				break
			}
		}

		game_tick(&s, &game)
	}
}

