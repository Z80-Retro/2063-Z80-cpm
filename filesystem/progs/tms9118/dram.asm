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

; Write data into DRAM and then read it back.
; This is only useful in the debugger to verify the DRAM is working.


.vdp_vram:	equ	0x80	; VDP port for accessing the VRAM
.vdp_reg:	equ	0x81	; VDP port for accessing the registers

	org	0x100

	; set the VRAM write address to 0
	ld	a,0x00
	out	(.vdp_reg),a
	ld	a,0x40
	out	(.vdp_reg),a

	; write 0x00 into VRAM address 0
	ld	a,0x00
	out	(.vdp_vram),a

	; write 0x11 into VRAM address 1
	ld	a,0x11
	out	(.vdp_vram),a

	; write 0x22 into VRAM address 2
	ld	a,0x22
	out	(.vdp_vram),a

	; write 0x33 into VRAM address 3
	ld	a,0x33
	out	(.vdp_vram),a

	; set the VRAM read address to 0
	ld	a,0x00
	out	(.vdp_reg),a
	ld	a,0x00
	out	(.vdp_reg),a

	; read the bytes back from the VRAM 
.spin:
	in	a,(.vdp_vram)	; should be 0x00
	in	a,(.vdp_vram)	; should be 0x11
	in	a,(.vdp_vram)	; should be 0x22
	in	a,(.vdp_vram)	; should be 0x33
	in	a,(.vdp_vram)	; should be garbage
	in	a,(.vdp_vram)	; should be garbage
	in	a,(.vdp_vram)	; should be garbage
	in	a,(.vdp_vram)	; should be garbage

	jp	.spin
