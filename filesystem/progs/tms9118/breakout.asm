;****************************************************************************
;
;    VDP Breakout Game
;
;    Copyright (C) 2021,2022,2023 John Winans
;
;    This library is free software; you can redistribute it and/or
;    modify it under the terms of the GNU Lesser General Public
;    License as published by the Free Software Foundation; either
;    version 2.1 of the License, or (at your option) any later version.
;
;    This library is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;    Lesser General Public License for more details.
;
;    You should have received a copy of the GNU Lesser General Public
;    License along with this library; if not, write to the Free Software
;    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301
;    USA
;
;
;****************************************************************************

BDOS:		equ	0x0005		; BDOS entry address (for system calls)
CON_STATUS:	equ	0x0b		; Get Console Status


.vdp_vram:	equ	0x80		; VDP port for accessing the VRAM
.vdp_reg:	equ	0x81		; VDP port for accessing the registers

.joy0:		equ	0xa8		; I/O port for joystick 0
.joy1:		equ	0xa9		; I/O port for joystick 1

joy_left:	equ	0x04		; and-mask for left
joy_right:	equ	0x20		; and-mask for right
joy_up:		equ	0x80		; and-mask for up
joy_down:	equ	0x40		; and-mask for down
joy_btn:	equ	0x01		; and-mask for button

; It is unfortunate that this does not match the joystick port bits.
; The reason is to make the range of possible values 0..15 as opposed to 0..255.

dir_down:	equ	1
dir_right:	equ	2
dir_up:		equ	4
dir_left:	equ	8



joy_horiz_min:	equ	0x00		; left of the screen
joy_horiz_max:	equ	0x0100-8	; right of the screen - sprite width
joy_vert_min:	equ	0x00		; top of the screen
joy_vert_max:	equ	0x00c0-8	; bottom of the screen - sprite height

joy_horiz_speed: equ	3		; movement rate pixel rate/field 
joy_vert_speed:	equ	1

brick_row_len:	equ	32				; num tile patterns per row
brick_row_1:	equ	brick_row_len*2			; offset to the 2nd row in the nametable
brick_row_3:	equ	brick_row_1+brick_row_len*2	; offset to the 4th row
brick_row_5:	equ	brick_row_3+brick_row_len*2	; offset to the 6th row
brick_row_7:	equ	brick_row_5+brick_row_len*2	; offset to the 8th row


; note the sprite position is the upper-left corner of the sprite tile
ball_width:	equ	8			; pixel-width of the ball sprite
ball_height:	equ	8			; pixel-height of the ball sprite
ball_min_x:	equ	0			; x position where the ball will hit the left wall
ball_max_x:	equ	32*8-ball_width		; x position where the ball will hit the right wall
ball_min_y:	equ	0			; y position where the ball will hit the top wall
ball_max_y:	equ	24*8-ball_height	; y position where the ball will hit the bottom wall



	org	0x100

	ld	sp,.stack

	; reset the game variables & display
	call	.reset


	;******************************************
	; Initialize the VDP into graphics mode 1
	;******************************************

	ld	hl,.mode1init
	ld	b,.mode1init_len
	ld	c,.vdp_reg
	otir				; write the config bytes

	;******************************************
	; Initialize the VRAM with useful patterns
	;******************************************

	ld	hl,.vraminit		; buffer-o-bytes to send
	ld	bc,.vraminit_len	; number of bytes to send
	ld	de,0x0000		; VDP sprite attribute table starts at 0x1000
	call	.vdp_write_slow




	;******************************************
	; Play ball!
	;******************************************
.gameloop:
	call	.check_quitkey		; terminate the game if a quit-key has been pressed
	call	.update_paddle		; read and update paddle position accordingly
	call	.update_ball		; update the ball location & handle colisions

	; wait for the next vertical blanking period
	call	.vdp_wait		; wait for the end-of-frame flag
	call	.flush_screen		; fluch the cached VRAM to the VDP

	jp	.gameloop




;*****************************************************************************
;*****************************************************************************

;*****************************************************************************
; If a quit key has been pressed, quit the program
;*****************************************************************************
.check_quitkey:
	; XXX check for a quit key to terminate the proggie here??
	ld	c,CON_STATUS		; See if a console character is ready (nonblocking)
	call	BDOS
	or	a			; if A=0 then there is no character ready
	jp	nz,.terminate		; else there is a character, terminate the program

	ret				; return to caller, nothing to do


;*****************************************************************************
; Check the paddle/joystick and update any prosition changes.
;*****************************************************************************
.update_paddle:

	ld	b,0x00			; B = direction mask: up=4, dn=1, rt=2, lt=8
	ld	de,(.paddle0)		; D = x position, E = y position

	in	a,(.joy1)		; Read joystick once so can't transition during processing
	ld	c,a			; C = current joystick value

	; up/down and left/right direction control logic

	; move up?
	ld	a,c
	and	joy_up
	jr	nz,.not_up

	ld	a,b
	or	dir_up			; set the up bit in the direction character
	ld	b,a

	ld	a,e			; A = current Y position
	ld	e,joy_vert_min		; assume we hit the limit
	cp	joy_vert_min+joy_vert_speed
	jp	c,.up_limit		; if borrow then we are at the limit
	sub	joy_vert_speed		; move it up
	ld	e,a
.up_limit:
.not_up:

	; move down?
	ld	a,c
	and	joy_down
	jr	nz,.not_down

	ld	a,b
	or	dir_down		; set the down bit in the direction character
	ld	b,a

	ld	a,e			; A = current Y position
	ld	e,joy_vert_max		; assume we hit the limit
	cp	joy_vert_max-joy_vert_speed
	jp	nc,.down_limit		; if at max value, don't increment it
	add	joy_vert_speed
	ld	e,a
.down_limit:
.not_down:

	; move left?
	ld	a,c
	and	joy_left
	jr	nz,.not_left

	ld	a,b
	or	dir_left		; set the left bit in the direction character
	ld	b,a

	ld	a,d			; A = current X position
	ld	d,joy_horiz_min		; assume we hit the limit 
	cp	joy_horiz_min+joy_horiz_speed
	jp	c,.left_limit		; if borrow then we are at the limit
	sub	joy_horiz_speed		; move it up
	ld	d,a
.left_limit:
.not_left:

	; move right
	ld	a,c
	and	joy_right
	jr	nz,.not_right

	ld	a,b
	or	dir_right		;set the right bit in the direction character
	ld	b,a

	ld	a,d			; A = current X position
	ld	d,joy_horiz_max		; assume we hit the limit
	cp	joy_horiz_max-joy_horiz_speed
	jp	nc,.right_limit		; if at max value, don't increment it
	add	joy_horiz_speed
	ld	d,a
.right_limit:
.not_right:

	ld	(.paddle0),de		; save sprite posn back into sprite attrib table

	ld	a,b
	ld	(.dir_heading),a	; save the current direction heading value

	; XXX It is also probably a better idea not to bother doing this if nothing changed ;-)
	;	...BUUUUT that would make it tougher to check timing on the scope.
	;	...AAAAND the call to vdp_wait is how the game speed is governed.

	; update the character code representing the mouse direction
	; XXX This would run faster if done custom while transferring data into the VDP name table.
	; XXX The point of doing it this way is to analyze the efficency of 
	;	doing full screen double-buffered updates.

if 0
	ld	hl,.nametable
	ld	(hl),b			; store the direction heading
	ld	de,.nametable+1
	ld	bc,.nametable_len-1
	ldir				; copy the direction arrow to entire screen
endif

	ret




;*****************************************************************************
; Flush the cached copy of the VRAM using a fast VDP write transfer.
; note: Only want to do this right after the VDP frame flag is set.
;*****************************************************************************
.flush_screen:
	; flush the sprite attribute table
	ld	hl,.spriteattr		; buffer-o-bytes to send
	ld	bc,.spriteattr_len 	; number of bytes to send
	ld	de,0x1000		; VDP sprite attribute table starts at 0x1000
	call	.vdp_write

	; flush the name table
	ld	hl,.nametable		; buffer-o-bytes to send
	ld	bc,.nametable_len	; number of bytes to send
	ld	de,0x1400		; VDP name table starts at 0x1400
	call	.vdp_write

	ret



;*****************************************************************************
; Clean up any mess we leave behind & return to CP/M
;*****************************************************************************
.terminate:
	jp	0			; warm boot


;*****************************************************************************
; Wait for the VDP to indicate that it has finished rendering a frame
; and that we now have time to access the VDP RAM at high speed.
; Clobbers: AF
;
; WARNING: This is not reliable because the TMS9x18 does not appear to 
;	properly synchronize the Frame Flag bit in its status register 
;	with the read-select logic.  Some times it will return a 
;	false-negative that will cause this loop to miss one and then 
;	continue to for the next.  It does, however, work most of the 
;	time. Therefore it is useful for testing non-critical code.
;*****************************************************************************
.vdp_wait:
	in	a,(.vdp_reg)		; read the VDP status register
	and	0x80			; frame flag on?
	jp	z,.vdp_wait
	ret


;*****************************************************************************
; Copy a given memory buffer into the VDP buffer
;
; The VDP requires 2usec per VRAM write during the 4300 usec time 
; period just after it generates the end-of-frame IRQ signal.
; The rest of the time the VDP can require up to 8usec between writes.
; (TMS9918 manual page 2-4)
;
; DE = VDP target memory address
; HL = host memory address
; BC = number of bytes to write (0 = 0x10000)
; Clobbers: AF, BC, DE, HL
;*****************************************************************************
.vdp_write:
	; copy the new sprite location values into the VRAM
	; Set the VRAM write address
	ld	a,e
	out	(.vdp_reg),a		; VRAM address LSB to write
	ld	a,d
	or	0x40
	out	(.vdp_reg),a		; VRAM address MSB to write

	ld	d,b
	ld	e,c			; DE = byte count

	ld	c,.vdp_vram		; the I/O port number

;*****************************************************************************
; This version is the Goldilocks speed 
	; if DE == 0 then this will copy 64K
	ld	b,e			; use b as the LSB counter
	inc	e
	dec	e
	jr	z,.vdp_write_loop	; if E==0 then D is OK as-is
	inc	d			; if E!=0 then increment D

.vdp_write_loop:
	outi				; #16 note: this will include a DEC B

	; fast counter logic 
if 0
	; (3.0 usec update rate @ 10 MHZ)
	dec	e			; #4 dec the LSB
	jp	nz,.vdp_write_loop	; #10 if not zero then keep going
else
	; (2.6 usec update rate @ 10 MHZ)
	jp	nz,.vdp_write_loop	; #10 if not zero then keep going

	; (2.8 usec update rate @ 10 MHZ)
	;jr	nz,.vdp_write_loop	; #12 (if branch) if not zero then keep going
endif
	dec	d			; dec the MSB
	jp	nz,.vdp_write_loop	; if not zero then keep going
	ret



;*****************************************************************************
; Copy a given memory buffer into the VDP buffer.  
;
; This is the same as vdp_write but it runs slow enough to be used 
; during active display.
;
; The VDP can require up to 8usec per VRAM write in Graphics modes
; 1 and 2 when painting the active display area. 
; (TMS9918 manual page 2-4)
;
; DE = VDP target memory address
; HL = host memory address
; BC = number of bytes to write
; Clobbers: AF, BC, DE, HL
;*****************************************************************************
.vdp_write_slow:
	; copy the new sprite location values into the VRAM
	; Set the VRAM write address
	ld	a,e
	out	(.vdp_reg),a		; VRAM address LSB to write
	ld	a,d
	or	0x40
	out	(.vdp_reg),a		; VRAM address MSB to write

	ld	d,b
	ld	e,c			; DE = byte count

	ld	c,.vdp_vram		; the I/O port number

.vdp_write_slow_loop:
	outi				; note: this clobbers B

	; Waste time between transfers (8.36 usec update rate @ 10 MHZ)
	push	hl
	pop	hl
	push	hl
	pop	hl

	; counter logic 
	dec	de
	ld	a,d
	or	e
	jr	nz,.vdp_write_slow_loop

	ret


;********************************************************************************
; If the ball has hit a wall then negate the appropriate .ball_d[xy] value.
;
; TODO 
; - set a flag if hit a wall
; - set a flag if hit the paddle
; - set a flag if hit the bottom of the screen (out of bounds)
; - set a flag if hit a brick & note which one
;********************************************************************************
if 0
.update_ball:
	ld	de,(.ball)		; e=y, d=x
	ld	a,(.ball_dx)		; determine the sign (dir) of the x movement
	add	d
	ld	d,a
	ld	a,(.ball_dy)
	add	e
	ld	e,a
	ld	(.ball),de

	ret
endif

if 1
; XXX this ONLY works if dx and dy are 1
.update_ball:

	; horizontal movement
	ld	c,ball_min_x		; assume moving to the left
	ld	a,(.ball_dx)		; determine the sign (dir) of the x movement
	ld	d,a			; D = .ball_dx
	or	a
	jp	m,.ball_check_x
	ld	c,ball_max_x		; move to the right
.ball_check_x:
	ld	a,(.ball_x)		; A = .ball_x
	ld	b,a			; B = .ball_x
	cp	c			; A == max/min x value ?
	jp	nz,.ball_go_x		; no ? then OK to move it dx pixels
	ld	a,d			; else, negate the dx value
	neg				; A = -A
	ld	(.ball_dx),a
.ball_go_x:
	ld	a,b			; A = .ball_x
	add	d			; A = .ball_x + .ball_dx
	ld	(.ball_x),a		; .ball_x = .ball_x + .ball_dx

	; vertical movement
	ld	c,ball_min_y		; assume moving to the left
	ld	a,(.ball_dy)		; determine the sign (dir) of the y movement
	ld	d,a			; D = .ball_dy
	or	a
	jp	m,.ball_check_y
	ld	c,ball_max_y		; move to the right
.ball_check_y:
	ld	a,(.ball_y)		; A = .ball_y
	ld	b,a			; B = .ball_y
	cp	c			; A == max/min y value ?
	jp	nz,.ball_go_y		; no ? then OK to move it dy pixels
	ld	a,d			; else, negate the dy value
	neg				; A = -A
	ld	(.ball_dy),a
.ball_go_y:
	ld	a,b			; A = .ball_y
	add	d			; A = .ball_y + .ball_dy
	ld	(.ball_y),a		; .ball_y = .ball_y + .ball_dy

	ret
endif



;********************************************************************************
; TODO
; - draw one brick at a given position (with rounded ends?)
; - place paddle (including a width of 1X, 2X, or 3X?)
; - determine if the ball has hit a brick
; - determine if the ball is colliding with the the left, center, or right of the paddle
;
;********************************************************************************

.dir_heading:	db	0			; see dir_xxxx


; The .ball_d[xy] values are added to the current ball position
; each time that .update_ball is called (normally, once per frame.)
.ball_dx:	db	1			; distance to move each frame
.ball_dy:	db	1 			; distance to move each frame



;********************************************************************************
; reset all of the game variables & the display (name table) to start a game. 
;********************************************************************************

.reset:
	; blank the screen
	ld	hl,.nametable
	ld	(hl),0x00
	ld	de,.nametable+1
	ld	bc,.nametable_len-1
	ldir

	; fill in the bricks
	ld	hl,.nametable+brick_row_1
	ld	(hl),.ptrn_red_brick
	ld	de,.nametable+brick_row_1+1
	ld	bc,brick_row_len*2-1
	ldir

	ld	hl,.nametable+brick_row_3
	ld	(hl),.ptrn_orn_brick
	ld	de,.nametable+brick_row_3+1
	ld	bc,brick_row_len*2-1
	ldir
	
	ld	hl,.nametable+brick_row_5
	ld	(hl),.ptrn_grn_brick
	ld	de,.nametable+brick_row_5+1
	ld	bc,brick_row_len*2-1
	ldir

	ld	hl,.nametable+brick_row_7
	ld	(hl),.ptrn_yel_brick
	ld	de,.nametable+brick_row_7+1
	ld	bc,brick_row_len*2-1
	ldir

	; move paddle to starting position
	ld	e,24*8-8	; vertical posn (bottom)
	ld	d,32*8/2-8/2	; horiz posn (center)
	ld	(.paddle0),de

	; move ball to starting position
	ld	e,24*8/2-16/2	; vertical posn (middle)
	ld	d,32*8-8	; horiz posn (right)
	ld	(.ball),de

	; clear the current joystick direction/heading
	xor	a
	ld	(.dir_heading),a

	ret 


;********************************************************************************


;********************************************************************************

	; padd the initializer table % 0x1000 to make debugging addresses easy
	ds	0x1000-(($+0x1000)&0x0fff)

; data sent to initialize the VRAM
.vraminit:
.spritepat:
	; 0x0000-0x07ff sprite patterns (8x8 mode)
	db	0x10,0x10,0xfe,0x7c,0x38,0x6c,0x44,0x00	; 0 = star
	db	0x3c,0x7e,0xff,0xff,0xff,0xff,0x7e,0x3c	; 1 = ball
	db	0x00,0x00,0x00,0xff,0xff,0xff,0xff,0x00	; 2 = horizontal paddle

	ds      0x800-($-.spritepat),0xf0       	; padd the rest of the sprite pattern table

.patterns:
	; 0x0800-0x0fff pattern table
		; grapic mode 1 color 0
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00	; 00 = blank 
	db	0x00,0x00,0x00,0x00,0x00,0x7e,0x3c,0x18	; 01 = down arrowhead
	db	0x00,0x04,0x06,0x07,0x07,0x06,0x04,0x00	; 02 = right arrowhead
	db	0x00,0x00,0x00,0x01,0x03,0x07,0x0f,0x1f	; 03 = 4th quadrant arrowhead
	db	0x18,0x3c,0x7e,0x00,0x00,0x00,0x00,0x00	; 04 = up arrowhead
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00	; 05 = blank
	db	0x1f,0x0f,0x07,0x03,0x01,0x00,0x00,0x00	; 06 = 1st quadrant arrowhead
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00	; 07 = blank
		; grapic mode 1 color 1
	db	0x00,0x20,0x60,0xe0,0xe0,0x60,0x20,0x00	; 08 = left arrowhead
	db	0x00,0x00,0x00,0x80,0xc0,0xe0,0xf0,0xf8	; 09 = 3rd quadrant arrowhead
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00	; 0A = blank
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00	; 0B = blank
	db	0xf8,0xf0,0xe0,0xc0,0x80,0x00,0x00,0x00	; 0C = 2nd quandrant arrowhead
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 0D
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 0E
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 0F

.ptrn_red_brick: equ ($-.patterns)/8
		; grapic mode 1 color 2 (red)
	db	0x00,0xff,0xff,0xff,0xff,0xff,0xff,0x00 ; 10	full-width brick
	db	0x00,0x1f,0x3f,0x3f,0x3f,0x3f,0x1f,0x00 ; 11	brick left-end
	db	0x00,0xf8,0xfc,0xfc,0xfc,0xfc,0xf8,0x00 ; 12	brick right-end
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 13
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 14
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 15
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 16
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 17

.ptrn_orn_brick: equ ($-.patterns)/8
		; grapic mode 1 color 3 (orange)
	db	0x00,0xff,0xff,0xff,0xff,0xff,0xff,0x00 ; 18	full-width brick
	db	0x00,0x1f,0x3f,0x3f,0x3f,0x3f,0x1f,0x00 ; 19	brick left-end
	db	0x00,0xf8,0xfc,0xfc,0xfc,0xfc,0xf8,0x00 ; 1A	brick right-end
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 1B
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 1C
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 1D
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 1E
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 1F

.ptrn_grn_brick: equ ($-.patterns)/8
		; grapic mode 1 color 4 (green)
	db	0x00,0xff,0xff,0xff,0xff,0xff,0xff,0x00 ; 20	full-width brick
	db	0x00,0x1f,0x3f,0x3f,0x3f,0x3f,0x1f,0x00 ; 21	brick left-end
	db	0x00,0xf8,0xfc,0xfc,0xfc,0xfc,0xf8,0x00 ; 22	brick right-end
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 23
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 24
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 25
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 26
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 27

.ptrn_yel_brick: equ ($-.patterns)/8
		; grapic mode 1 color 5 (yellow)
	db	0x00,0xff,0xff,0xff,0xff,0xff,0xff,0x00 ; 28	full-width brick
	db	0x00,0x1f,0x3f,0x3f,0x3f,0x3f,0x1f,0x00 ; 29	brick left-end
	db	0x00,0xf8,0xfc,0xfc,0xfc,0xfc,0xf8,0x00 ; 2A	brick right-end
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 2B
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 2C
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 2D
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 2E
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 2F

	ds      0x800-($-.patterns),0x66       		; padd the rest of the pattern table

.spriteattr:
	; 0x1000-0x107f sprite attributes

; sprite zero is the paddle
.paddle0:
	db	24*8/2-16/2	; vertical position.   0=top (center it)
	db	32*8/2-16/2	; horizontal position. 0=left (center it)
	db	0x02		; pattern name number (paddle)
	db	0x07		; early clock & color (cyan)

; sprite 1 is the ball
.ball:
.ball_y:
	db	24*8/2-16/2	; vertical position.
.ball_x:
	db	32*8/2-16/2	; horizontal position.
	db	0x01		; pattern name number (ball)
	db	0x0f		; early clock & color (white)

	ds      0x080-($-.spriteattr),0xd0     		; padd the rest (0xd0 = no such sprite)

.spriteattr_len:	equ	$-.spriteattr		; how many bytes are in the sprite attrib table

	ds	0x380,0x00				; 0x1080-0x13ff unused

.nametable:
	ds	0x400,0x00				; 0x1400-0x17ff name table
if 0
.nametable_len:	equ	$-.nametable			; How many bytes are in the sprite attrib table
else
.nametable_len:	equ	768				; BUT... only 768 are actually used!
endif

	ds	0x800,0x00				; 0x1800-0x1fff unused

	; For the color table, provide assortment of random color pairs
	db	0x21,0x21,0x61,0x91,0x21,0xB1,0x21,0x21
	db	0x21,0x21,0x21,0x21,0x21,0x21,0x21,0x21
	db	0x21,0x21,0x21,0x21,0x21,0x21,0x21,0x21
	db	0x21,0x21,0x21,0x21,0x21,0x21,0x21,0x21

.vraminit_len:	equ	$-.vraminit


;**********************************************************************
; VDP register initialization values
;**********************************************************************
.mode1init:
	db	0x00,0x80	; R0 = graphics mode, no EXT video
;	db	0xc0,0x81	; R1 = 16K RAM, enable display, disable INT, 8x8 sprites, mag off
;	db	0xc1,0x81	; R1 = 16K RAM, enable display, disable INT, 8x8 sprites, mag on
;	db	0xe1,0x81	; R1 = 16K RAM, enable display, enable INT, 8x8 sprites, mag on
	db	0xe0,0x81	; R1 = 16K RAM, enable display, enable INT, 8x8 sprites, mag off
	db	0x05,0x82	; R2 = name table = 0x1400
	db	0x80,0x83	; R3 = color table = 0x0200
	db	0x01,0x84	; R4 = pattern table = 0x0800
	db	0x20,0x85	; R5 = sprite attribute table = 0x1000
	db	0x00,0x86	; R6 = sprite pattern table = 0x0000
	db	0xf1,0x87	; R7 = fg=white, bg=black
.mode1init_len: equ	$-.mode1init	; number of bytes to write

	ds	1024
.stack:	equ	$
