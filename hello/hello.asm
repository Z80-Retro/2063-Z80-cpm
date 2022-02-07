;****************************************************************************
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
;****************************************************************************

include	'io.asm'

stacktop:	equ	0

	org	0xc000		; the second-stage load address

	ld	sp,stacktop

	; XXX Note that the boot loader should have initialize the SIO, CTC etc.
	; XXX therefore we can just write to them from here.


	; Display a hello world message.
	call	iputs
	db	"\r\n\n"
	db	"Hello from the SD card!!!\r\n"
	db	0			; DON'T FORGET the null terminator!

	; Spin loop here because there is nothing else to do
halt_loop:
	halt
	jp	halt_loop


include	'hexdump.asm'
include 'sio.asm'
include 'ctc1.asm'
include 'puts.asm'
