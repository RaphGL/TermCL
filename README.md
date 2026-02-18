<!-- PROJECT LOGO -->
<br />
<p align="center">
  <h1 align="center">TermCL</h1>
  <h3 align="center">Terminal control and ANSI escape code library for Odin</h3>
  <p align="center">
    <br />
    <!-- TODO: Add docs link later -->
    <!-- <a href="https://github.com/RaphGL/TermCL"><strong>Explore the docs »</strong></a> -->
    <br />
    <br />
    ·
    <a href="https://github.com/RaphGL/TermCL/issues">Report Bug</a>
    ·
    <a href="https://github.com/RaphGL/TermCL/issues">Request Feature</a>
  </p>
</p>

<!-- TABLE OF CONTENTS -->
<details open="open">
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
    </li>
    <li><a href="#how-it-works">How it works</a></li>
    <li><a href="#usage">Usage</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->

TermCL is an Odin library for writing TUIs and CLIs.
The library is compatible with any ANSI escape code compatible terminal, which is to say, almost every single modern terminal worth using :)

The library should work on windows and any posix compatible operating system.

> [!NOTE]
> If it doesn't work on your OS, it's probably missing the terminal mode and size syscalls. PRs are welcomed, otherwise create an issue.

> [!TIP]
> If you just want a nice and small abstraction for working with ANSI escape codes and nothing else, `termcl/raw` exists. It's a ~300 LOC file that implements the escape codes used by TermCL itself. Feel free to copy it into your own projects.

## How it works
The library has a base `termcl` that handles all the basics of interacting with a terminal such as cursors, drawing, and the possible values for mouse and keyboard input. Then there are the "backends" which implement the interface that `termcl` expects. The purpose of the backends is to do the actual work of setting setting up the terminal, reading input and printing things to the screen.

Currently the following backends are available:
- `term`: outputs ANSI escape codes to the terminal. It is meant for modern terminals. This is probably what you want most of the time.
- `sdl3`: uses SDL3 to render your TUI to a window. This is good for people that want a TUI like experience but as GUI or just want to be able to reuse the same components from their TUI on top of a GUI.

These backends are implemented as a vtable that is passed to termcl itself when you initialize the screen with `termcl.init_screen`. 

```odin
screen := termcl.init_screen(term.VTABLE)
defer termcl.destroy_screen(&screen)
```

> [!WARNING]
> you should call `destroy_screen` before you exit to restore the terminal state otherwise you might end up with a weird behaving terminal

After that you should just set the terminal to whatever mode you want with the `set_term_mode` function, there are 3 modes you can use:
- Raw mode (`.Raw`) - prevents the terminal from processing the user input so that you can handle them yourself
- Cooked mode (`.Cbreak`) - prevents user input but unlike raw, it's still processed for signals like Ctrl + C and others
- Restored mode (`.Restored`) - restores the terminal to the state it was in before the program started messing with it. Restored mode is set automatically if you destroy the screen 

After doing this, you should be good to go to do whatever you want.

Here's a few minor things to take into consideration:
- `read` is nonblocking, if you want to do a blocking read use `read_blocking`
- `termcl.read` returns a parsed `Input`, if you want to access the raw input you're gonna want to use `read_raw` from the backend you chose, you can still use `parse_keyboard_input` and `parse_mouse_input` to get `Input` instead
- `Window`s (including `Screen`) cache everything you write to them, you have to `blit` for them to show up on screen.

## Usage
```odin
package test

import t "termcl"
import term "termcl/term"

main :: proc() {
	s := t.init_screen(term.VTABLE)
	defer t.destroy_screen(&s)
	t.set_term_mode(&s, .Cbreak)

	for {
		t.clear(&s, .Everything)
		defer t.blit(&s)

		t.move_cursor(&s, 0, 0)
		t.write(&s, "Press Q to exit")

		input, input_ok := t.read(&s).(t.Keyboard_Input)
		if input_ok && input.key == .Q {
			break
		}

		t.move_cursor(&s, 4, 0)
		t.set_text_style(&s, {.Bold, .Italic})
		t.write(&s, "Hello ")
		t.reset_styles(&s)

		t.set_text_style(&s, {.Dim})
		t.set_color_style(&s, .Green, nil)
		t.write(&s, "from ANSI escapes")
		t.reset_styles(&s)

		t.move_cursor(&s, 14, 10)
		t.write(&s, "Alles Ordnung")
	}

}
```

Basic CLI using `termcl/raw`:
```odin
package test

import t "termcl/raw"
import "core:fmt"
import "core:strings"

main :: proc() {
	sb: strings.Builder
	strings.builder_init(&sb)
	defer strings.builder_destroy(&sb)

	t.set_text_style(&sb, {.Bold, .Italic})
	strings.write_string(&sb, "Hello ")
	t.reset_styles(&sb)

	t.set_text_style(&sb, {.Dim})
	t.set_bg_color_style(&sb, .Red)
	t.set_fg_color_style(&sb, .Blue)
	strings.write_string(&sb, "from ANSI escapes")
	t.reset_styles(&sb)

	strings.write_string(&sb, "\n\n\n\n")

	t.set_fg_color_style(&sb, .Green)
	strings.write_string(&sb, "    Alles Ordnung")
	t.reset_styles(&sb)

	fmt.println(strings.to_string(sb))
}
```

Check the `examples` directory if you want to see more examples of how to use the library.
