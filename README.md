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

TermCL is an Odin library for writing TUIs and CLIs with.
The library is compatible with any ANSI escape code compatible terminal, which is to say, almost every single modern terminal worth using :)

The library should also work on windows and any posix compatible operating system.

## How it works
The library uses a multiple backend architecture, so to start you need to pick your backend.

Currently there's:
- term: outputs terminal escape codes for modern terminals. This is probably what you want most of the time.
- sdl3: uses SDL3 to render to a window. This is good for tools that need the extra performance, or more flexibility with how you draw pixels, or you just want 
to have a terminal-like UI

Once you've picked your backend you should set it and then initialze the screen.

> [!NOTE]
> you should call destroy_screen before you exit to restore the terminal state otherwise you might end up with a weird behaving terminal

After that you should just set the terminal to whatever mode you want with the `set_term_mode` function, there are 3 modes you can use:
- Raw mode (`.Raw`) - prevents the terminal from processing the user input so that you can handle them yourself
- Cooked mode (`.Cbreak`) - prevents user input but unlike raw, it still processed for signals like Ctrl + C and others
- Restored mode (`.Restored`) - restores the terminal to the state it was in before the program started messing with it, this is also called when the screen is destroyed

After doing this, you should be good to go to do whatever you want.

Here's a few minor things to take into consideration:
- To handle input you can use the `read` function or the `read_blocking` function, as the default read is nonblocking.
- There's convenience functions that allow you to more easily process input, they're called `parse_keyboard_input` and `parse_mouse_input`
- Whatever you do won't show up on screen until you `blit`, since everything is cached first, windows also have their own cached escapes, so make sure you blit them as well

## Usage

```odin
package main

import t "termcl"
import "termcl/term"

main :: proc() {
    term.set_backend()
    scr := t.init_screen()
    defer t.destroy_screen(&scr)
    t.clear(&scr, .Everything)

    t.set_text_style(&scr, {.Bold, .Italic})
    t.write(&scr, "Hello ")
    t.reset_styles(&scr)

    t.set_text_style(&scr, {.Dim})
    t.set_color_style(&scr, .Green, nil)
    t.write(&scr, "from ANSI escapes")
    t.reset_styles(&scr)

    t.move_cursor(&scr, 10, 10)
    t.write(&scr, "Alles Ordnung")

    t.blit(&scr)
}
```

Check the `examples` directory to see more on how to use it.  
