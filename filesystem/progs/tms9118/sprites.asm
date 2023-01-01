;****************************************************************************
;
;    VDP test app
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

.vdp_vram:	equ	0x80	; VDP port for accessing the VRAM
.vdp_reg:	equ	0x81	; VDP port for accessing the registers

.joy0:		equ	0xa8	; I/O port for joystick 0
.joy1:		equ	0xa9	; I/O port for joystick 1

joy_left:	equ	0x04		; and-mask for left
joy_right:	equ	0x20		; and-mask for right
joy_up:		equ	0x80		; and-mask for up
joy_down:	equ	0x40		; and-mask for down
joy_btn:	equ	0x01		; and-mask for button

joy_horiz_min:	equ	0x00		; left of the screen
joy_horiz_max:	equ	0x0100-16	; right of the screen - sprite width
joy_vert_min:	equ	0x00		; top of the screen
joy_vert_max:	equ	0x00c0-16	; bottom of the screen - sprite height

	org	0x100

	ld	sp,.stack

	; Initialize the VDP into graphics mode 1
	ld	hl,.mode1init
	ld	b,.mode1init_len
	ld	c,.vdp_reg

	otir				; write the config bytes

	; Initialize the VRAM with useful patterns

	; Set the VRAM write address to 0
	ld	a,0x00		; LSB
	out	(.vdp_reg),a

	ld	a,0x40		; MSB
	out	(.vdp_reg),a

	ld	hl,.vraminit		; buffer-o-bytes to send
	ld	c,.vdp_vram		; the I/O port number
	ld	de,.vraminit_len	; number of bytes to send
.vram_init_loop:
	outi				; note: this clobbers B

	; waste time between transfers
	push	hl			; waste much time between transfers
	pop	hl
	push	hl
	pop	hl

	dec	de
	ld	a,d
	or	e
	jp	nz,.vram_init_loop

; move the sprites around

	ld	d,0		; d = horizontal posn
	ld	e,0		; e = vertical posn

	; .spriteattr+0 = vertical posn 00..
	; .spriteattr+1 = horizontal posn
	; .spriteattr+2 = pattern name
	; .spriteattr+3 = early clock & color

.spriteloop:
	ld	hl,.spriteattr
	ld	(hl),e		; set vert posn
	inc	hl
	ld	(hl),d		; set horiz posn

	push	de		; save the sprite position  value

	; copy the new sprite location values into the VRAM
	; Set the VRAM write address
	ld	a,0x00			; VRAM address LSB to write
	out	(.vdp_reg),a
	ld	a,0x10|0x40		; VRAM address MSB to write 
	out	(.vdp_reg),a

	ld	hl,.spriteattr		; buffer-o-bytes to send
	ld	c,.vdp_vram		; the I/O port number
	ld	de,2			; number of bytes to send

if 1
	; spin waiting for the vertical retrace time
.framesync:
	in	a,(.vdp_reg)
	and	0x80
	jp	z,.framesync
endif

.vram_update_loop:
	outi				; note: this clobbers B

	; waste time between transfers
	push	hl			; waste much time between transfers
	pop	hl
	push	hl
	pop	hl

	dec	de
	ld	a,d
	or	e
	jp	nz,.vram_update_loop

	pop	de			; restore posn value



; XXX check for any key (or ^C) to terminate the proggie??
;	jp	0		; warm boot

if 0
	ld	bc,0x4000
.sdelay:
	dec	bc
	ld	a,b
	or	c
	jp	nz,.sdelay
endif


	; Read joystick for up/down and left/right direction

	; XXX clamp the min/max values on the posn values

	in	a,(.joy1)
	and	joy_up
	jr	nz,.not_up
	ld	a,e
	cp	joy_vert_min
	jr	z,.not_up	; if at max value, don't increment it
	dec	e		; dec vertical position
	dec	e		; move faster
.not_up:

	in	a,(.joy1)
	and	joy_down
	jr	nz,.not_down
	ld	a,e
	cp	joy_vert_max
	jr	z,.not_down	; if at max value, don't increment it
	inc	e		; inc vertical position
	inc	e
.not_down:

	in	a,(.joy1)
	and	joy_left
	jr	nz,.not_left
	ld	a,d
	cp	joy_horiz_min
	jr	z,.not_left	; if at min value, don't decrement it
	dec	d		; dec horizontal position
	dec	d
.not_left:

	in	a,(.joy1)
	and	joy_right
	jr	nz,.not_right
	ld	a,d
	cp	joy_horiz_max
	jr	z,.not_right	; if at max value, don't increment it
	inc	d		; inc horizontal position
	inc	d
.not_right:

	
	jp	.spriteloop


.mode1init:
	db	0x00,0x80	; R0 = graphics mode, no EXT video
;	db	0xc0,0x81	; R1 = 16K RAM, enable display, disable INT, 8x8 sprites, mag off
	db	0xc1,0x81	; R1 = 16K RAM, enable display, disable INT, 8x8 sprites, mag off
	db	0x05,0x82	; R2 = name table = 0x1400
	db	0x80,0x83	; R3 = color table = 0x0200
	db	0x01,0x84	; R4 = pattern table = 0x0800
	db	0x20,0x85	; R5 = sprite attribute table = 0x1000
	db	0x00,0x86	; R6 = sprite pattern table = 0x0000
	db	0x14,0x87	; R7 = bg color = dark blue
.mode1init_len: equ	$-.mode1init	; number of bytes to write


; data sent to initialize the VRAM
.vraminit:
.spritepat:
if 0
	ds	0x800,0xf0	; 0x0000-0x07ff sprite patterns
else
	db	0x10,0x10,0xfe,0x7c,0x38,0x6c,0x44,0x00		; sprite 0 = a star
	ds	0x7f8,0xf0	
endif
	ds	0x800,0xc0	; 0x0800-0x0fff pattern table = 01010101  
.spriteattr:
if 0
	ds	0x080,0x00	; 0x1000-0x107f sprite attributes
else
	db	0x70,0x70,0x00,0x08	; sprite 0
	ds	0x07c,0xd0		; sprites 1..31 (0xd0 = no such sprite and higher numbered ones are ignored)
endif
	ds	0x380,0x00	; 0x1080-0x13ff unused
.vraminit_name:
	ds	0x400,0x00	; 0x1400-0x17ff name table
	ds	0x800,0x00	; 0x1800-0x1fff unused

	; For the color table, provide assortment of random color pairs
	db	0x21,0x31,0x41,0x51,0x61,0x71,0x81,0x91
	db	0xa1,0xb1,0xc1,0xd1,0xe1,0xf1,0x12,0x32
	db	0x42,0x52,0x62,0x72,0x82,0x92,0xa2,0xb2
	db	0xc2,0xd2,0xe2,0xf2,0x13,0x23,0x43,0x53
.vraminit_len:	equ	$-.vraminit


	ds	1024
.stack:	equ	$
