This directory contains test programs for the Z80 Retro! VDP board.

- `green` Disable the display and set the background color to *green*.
- `white` Disable the display and set the background color to *white*.
- `mode1` Enable the display, set background to `green` and enter *mode1*.
- `mode1i2` Disable Z80 IRQs, enable the display, set background to `green`, enter *mode1*, and spin reading the VDP status register.
- `m1t1` Enter graphics *mode1* and draw a set of patterns on the top 5 lines of the screen.
- `m1t2` Enter graphics *mode1* and draw a set of patterns on the top 5 lines of the screen.
- `sprites` Enter *mode1* and redraw the screen after each field (at 60 HZ) while moving around a sprite and indicating the direction of motion with 768 arrows.
