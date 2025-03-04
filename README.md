<!-- PROJECT LOGO -->
<br />
<p align="center">
  <h1>TermCL</h1>

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
    <li><a href="#usage">Usage</a></li>
    <li><a href="#acknowledgements">Acknowledgements</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->

TermCL is an Odin library for writing TUIs and CLIs with. It provides allows you to control and draw to the terminal.
The library should be compatible with any ANSI escape code compatible terminal, which is to say, almost every single modern terminal worth using :)

## Usage

```odin
package main

import "termcl"

main :: proc() {
    scr := termcl.init_screen()
    defer termcl.destroy_screen(&scr)

    termcl.set_text_style(&scr, {.Bold, .Italic})
    termcl.write(&scr, "Hello ")
    termcl.reset_styles(&scr)

    termcl.set_text_style(&scr, {.Dim})
    termcl.set_color_style_8(&scr, .Green, nil)
    termcl.write(&scr, "from ANSI escapes")
    termcl.reset_styles(&scr)

    termcl.move_cursor(&scr, 10, 10)
    termcl.write(&scr, "Alles Ordnung")

    termcl.blit_screen(&scr)
}
```
