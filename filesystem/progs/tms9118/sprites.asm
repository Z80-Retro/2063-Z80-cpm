;****************************************************************************
;
;    VDP Graphics Mode 1 With Sprites Test 
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

; A graphics MODE1 test app to demonstrate sprites.

.vdp_vram:	equ	0x80		; VDP port for accessing the VRAM
.vdp_reg:	equ	0x81		; VDP port for accessing the registers

.joy0:		equ	0xa8		; I/O port for joystick 0
.joy1:		equ	0xa9		; I/O port for joystick 1

joy_left:	equ	0x04		; and-mask for left
joy_right:	equ	0x20		; and-mask for right
joy_up:		equ	0x80		; and-mask for up
joy_down:	equ	0x40		; and-mask for down
joy_btn:	equ	0x01		; and-mask for button

joy_horiz_min:	equ	0x00		; left of the screen
joy_horiz_max:	equ	0x0100-16	; right of the screen - sprite width
joy_vert_min:	equ	0x00		; top of the screen
joy_vert_max:	equ	0x00c0-16	; bottom of the screen - sprite height

joy_horiz_speed: equ	3		; movement rate pixel rate/field 
joy_vert_speed:	equ	1

	org	0x100

	ld	sp,.stack

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
	call	vdp_write_slow

	;******************************************
	; move the sprites around
	;******************************************

	; game variables are initialized in the .vram buffer

.spriteloop:

	; XXX check for a quit key to terminate the proggie here??

	; Update the sprite position(s) and the display characters

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
	or	0x04			; set the up bit in the direction character
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
	or	0x01			; set the down bit in the direction character
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
	or	0x08			; set the left bit in the direction character
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
	or	0x02			;set the down bit in the direction character
	ld	b,a

	ld	a,d			; A = current X position
	ld	d,joy_horiz_max		; assume we hit the limit
	cp	joy_horiz_max-joy_horiz_speed
	jp	nc,.right_limit		; if at max value, don't increment it
	add	joy_horiz_speed
	ld	d,a
.right_limit:
.not_right:

	; XXX It is also probably a better idea not to bother doing this if nothing changed ;-)
	;	...BUUUUT that would make it tougher to check timing on the scope.
	;	...AAAAND the call to vdp_wait is how the game speed is governed.

	ld	(.paddle0),de		; store sprite posn back into sprite attrib table

	; update the character code representing the mouse direction
	; XXX This would run faster if done custom while transferring data into the VDP name table.
	; XXX The point of doing it this way is to analyze the efficency of 
	;	doing full screen double-buffered updates.

	ld	hl,.nametable
	ld	(hl),b			; store the direction heading
	ld	de,.nametable+1
	ld	bc,.nametable_len-1
	ldir				; copy the direction arrow to entire screen

	; wait for the next vertical blanking period
	call	vdp_wait

	; flush the sprite attribute table
	ld	hl,.spriteattr		; buffer-o-bytes to send
	ld	bc,.spriteattr_len 	; number of bytes to send
	ld	de,0x1000		; VDP sprite attribute table starts at 0x1000
	call	vdp_write

	; flush the name table
	ld	hl,.nametable		; buffer-o-bytes to send
	ld	bc,.nametable_len	; number of bytes to send
	ld	de,0x1400		; VDP name table starts at 0x1400
	call	vdp_write

	jp	.spriteloop



;**********************************************************************
; Wait for the VDP to indicate that it has finished rendering a frame
; and that we now have time to access the VDP RAM at high speed.
; Clobbers: AF
;**********************************************************************
vdp_wait:
	in	a,(.vdp_reg)		; read the VDP status register
	and	0x80			; frame flag on?
	jp	z,vdp_wait
	ret


;**********************************************************************
; Copy a given memory buffer into the VDP buffer
;
; The VDP requires 2usec per VRAM write during the 4300 usec time 
; period just after it generates the end-of-frame IRQ signal.
; The rest of the time the VDP can require up to 8usec between writes.
; (TMS9918 manual page 2-4)
;
; DE = VDP target memory address
; HL = host memory address
; BC = number of bytes to write
; Clobbers: AF, BC, DE, HL
;**********************************************************************
vdp_write:
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

;********************************************************************************
; This version if SLIGHTLY too fast on 10MHZ Z80
if 0
	ld	b,e			; first chunk length to transfer
	ld	a,e			; if is 0 then multiple of 0x100 bytes
	or	a
	jr	z,.vdp_write_loop	; 
	inc	d			; when e != 0, do otir one extra time

.vdp_write_loop:
	otir				; 2.1usec @ 10MHZ, from write to write (too fast)

	dec	d
	jr	nz,.vdp_write_loop	; go back and do 0x100 more bytes

	ret
endif
;********************************************************************************
; This version is the Goldilocks speed 
if 1
	; if DE == 0 then this will copy 64K
	ld	b,e
	inc	e
	dec	e
	jr	z,.vdp_write_loop	; if E==0 then D is OK as-is
	inc	d			; if E!=0 then increment D

.vdp_write_loop:
	outi				; note: this clobbers B

if 0
	; fast counter logic (3.0 usec update rate @ 10 MHZ)
	dec	e			; dec the LSB
	jp	nz,.vdp_write_loop	; if not zero then keep going
else
	; fast counter logic (2.6 usec update rate @ 10 MHZ)
	jp	nz,.vdp_write_loop
endif
	dec	d			; dec the MSB
	jp	nz,.vdp_write_loop	; if not zero then keep going
	ret
endif

;********************************************************************************
; This version is OK but unnecessairly slow on 10MHZ Z80
if 0
.vdp_write_loop:
	outi				; note: this clobbers B

	; counter logic (4.2 usec update rate @ 10 MHZ)
	dec	de
	ld	a,d
	or	e
	jp	nz,.vdp_write_loop
	ret
endif



;**********************************************************************
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
;**********************************************************************
vdp_write_slow:
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

	; padd the initializer table % 0x1000 to make debugging addresses easy
	ds	0x1000-(($+0x1000)&0x0fff)

; data sent to initialize the VRAM
.vraminit:
.spritepat:
	; 0x0000-0x07ff sprite patterns (8x8 mode)
	db	0x10,0x10,0xfe,0x7c,0x38,0x6c,0x44,0x00	; 0 = star
	db	0x3c,0x7e,0xff,0xff,0xff,0xff,0x7e,0x3c	; 1 = ball
	db	0x00,0x00,0x00,0x00,0xff,0xff,0xff,0x00	; 2 = horizontal paddle

	ds      0x800-($-.spritepat),0xf0       	; padd the rest of the sprite pattern table

.patterns:
	; 0x0800-0x0fff pattern table
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00	; 0 = blank 
	db	0x00,0x00,0x00,0x00,0x00,0x7e,0x3c,0x18	; 1 = down arrowhead
	db	0x00,0x04,0x06,0x07,0x07,0x06,0x04,0x00	; 2 = right arrowhead
	db	0x00,0x00,0x00,0x01,0x03,0x07,0x0f,0x1f	; 3 = 4th quadrant arrowhead
	db	0x18,0x3c,0x7e,0x00,0x00,0x00,0x00,0x00	; 4 = up arrowhead
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00	; 5 = blank
	db	0x1f,0x0f,0x07,0x03,0x01,0x00,0x00,0x00	; 6 = 1st quadrant arrowhead
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00	; 7 = blank
	db	0x00,0x20,0x60,0xe0,0xe0,0x60,0x20,0x00	; 8 = left arrowhead
	db	0x00,0x00,0x00,0x80,0xc0,0xe0,0xf0,0xf8	; 9 = 3rd quadrant arrowhead
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00	; A = blank
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00	; B = blank
	db	0xf8,0xf0,0xe0,0xc0,0x80,0x00,0x00,0x00	; C = 2nd quandrant arrowhead
	ds      0x800-($-.patterns),0x66       		; padd the rest of the pattern table

.spriteattr:
	; 0x1000-0x107f sprite attributes
	; sprite zero is paddle zero:
.paddle0:
	db	24*8/2-16/2	; vertical position.   0=top (center it)
	db	32*8/2-16/2	; horizontal position. 0=left (center it)
	db	0x02		; pattern name number
	db	0x08		; early clock & color

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
	db	0x21,0x21,0x21,0x21,0x21,0x21,0x21,0x21
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
	db	0xe1,0x81	; R1 = 16K RAM, enable display, enable INT, 8x8 sprites, mag on
	db	0x05,0x82	; R2 = name table = 0x1400
	db	0x80,0x83	; R3 = color table = 0x0200
	db	0x01,0x84	; R4 = pattern table = 0x0800
	db	0x20,0x85	; R5 = sprite attribute table = 0x1000
	db	0x00,0x86	; R6 = sprite pattern table = 0x0000
	db	0xf1,0x87	; R7 = fg=white, bg=black
.mode1init_len: equ	$-.mode1init	; number of bytes to write

	ds	1024
.stack:	equ	$
