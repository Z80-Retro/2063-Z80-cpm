;****************************************************************************
;
;    Copyright (C) 2024 John Winans
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
; https://github.com/johnwinans/2063-Z80-cpm
;
;****************************************************************************

bsp_init:
        ld      a,0
        ;out0     (0x36),a        ; RCR = 0 = disable the DRAM refresh controller
        db      0xed,0x39,0x36
        ;out0     (0x32),a        ; DCNTL = 0 = zero wait states
        db      0xed,0x39,0x32

        ld      a,0x80
        ;out0    (0x1f),a        ; CCR = 0x80 = run at 1X extal clock speed
        db      0xed,0x39,0x1f

        ret
