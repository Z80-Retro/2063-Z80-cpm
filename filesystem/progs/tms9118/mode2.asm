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

; Enable the display and enter mode 1 (w/garbage in the VRAM.)


.vdp_vram:	equ	0x80	; VDP port for accessing the VRAM
.vdp_reg:	equ	0x81	; VDP port for accessing the registers

	org	0x100

	ld	a,0x1c		; FG=black, BG=green
	out	(.vdp_reg),a
	ld	a,0x87		; Write to register 7
	out	(.vdp_reg),a

	; enable graphics mode 2
	ld	a,0x02		; Reg0 = 0x02
	out	(.vdp_reg),a
	ld	a,0x80
	out	(.vdp_reg),a

	; enable the display
	ld	a,0x40		; Reg1 = 0x40 (enable display)
	out	(.vdp_reg),a
	ld	a,0x81
	out	(.vdp_reg),a

	ret
