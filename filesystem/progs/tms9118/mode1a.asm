;****************************************************************************
;
;    VDP test app
;
;    Copyright (C) 2021,2022 John Winans
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

; Graphics MODE1 test app based on example from the TI VDP Programmer's Guide - SPPU004

.vdp_vram:	equ	0x80	; VDP port for accessing the VRAM
.vdp_reg:	equ	0x81	; VDP port for accessing the registers

	org	0x100

	; XXX save SP & use our own?
	;ld	sp,.stack

	; Initialize the VDP into graphics mode 1
	ld	hl,.mode1init
	ld	b,.mode1init_len
	ld	c,.vdp_reg

if 1
	; is otir too fast?
	otir				; write the config bytes
else
.reg_init_loop:
	outi
	push	hl			; waste much time between transfers
	pop	hl
	push	hl			
	pop	hl
	jp	nz,.reg_init_loop
endif


	; Initialize the VRAM with useful patterns


	; generate a pattern in the name table
	ld	hl,.vraminit_name
	ld	bc,0x400
.name_pattern:
	ld	(hl),l
	inc	hl
	dec	bc
	ld	a,b
	or	c
	jp	nz,.name_pattern

	; Set the VRAM write address to 0
	ld	a,0x00		; LSB
	out	(.vdp_reg),a

	push	hl	; waste some time
	pop	hl

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
if 0
	push	hl
	pop	hl
	push	hl
	pop	hl
	push	hl
	pop	hl
endif
	dec	de
	ld	a,d
	or	e
	jp	nz,.vram_init_loop


	ret
;	jp	0		; warm boot



.mode1init:
	db	0x00,0x80	; R0 = graphics mode, no EXT video
	db	0xc0,0x81	; R1 = 16K RAM, enable display, disable INT, 8x8 sprites, mag off
	db	0x05,0x82	; R2 = name table = 0x1400
	db	0x80,0x83	; R3 = color table = 0x0200
	db	0x01,0x84	; R4 = pattern table = 0x0800
	db	0x20,0x85	; R5 = sprite attribute table = 0x1000
	db	0x00,0x86	; R6 = sprite pattern table = 0x0000
	db	0x14,0x87	; R7 = bg color = dark blue
.mode1init_len: equ	$-.mode1init	; number of bytes to write


; data sent to initialize the VRAM
.vraminit:
	ds	0x800,0xaa	; 0x0000-0x07ff sprite patterns
	ds	0x800,0x55	; 0x0800-0x0fff pattern table = 01010101  
	ds	0x080,0x00	; 0x1000-0x107f sprite attributes
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
