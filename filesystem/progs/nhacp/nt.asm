;****************************************************************************
;
;    A test app to debug the NHACP library
;
;    Copyright (C) 2023 John Winans
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

	org	0x100

	ld	sp,.stack

	call	nhacp_init

	call	iputs
	db	"ready...\r\n\0"

.loop:
	ld	hl,0x1234
	ld	de,.buf
	xor	a
	call	nhacp_get_blk

	call	iputs
	db	"RX block:\r\n\0"

	ld	hl,.buf
	ld	bc,128
	ld	e,1
	call	hexdump

	jp	.loop



if 0

if 0
	ld	hl,.buf
	ld	b,0		; B = 256 max bytes to read into the buffer
	call	nhacp_rx_msg
endif
	; DE points to first unused byte in the buffer
	; if CY is set then there has been an error

	jp	nc,.good_msg
	call	iputs		; clobbers AF and C
	db	"error detected :-(\r\n\0"
	
.good_msg:

if 0
	ld	a,e
	or	a
	jp	nz,.nz_msg
        ld      c,'.'
        call    con_tx_char
	jp	.loop
endif

.nz_msg:
	call	iputs
	db	"Length=\0"
	ld	a,e		; LSB of the nhacp_get_blk length is good enough
	call	hexdump_a

	call	iputs
	db	"\r\nmessage:\r\n\0"

	ld	hl,.buf
	ld	bc,256
	ld	e,1
	call	hexdump
	
	jp	.loop
endif

include 'io.asm'
include 'puts.asm'
include 'sio.asm'
include 'nhacp.asm'
include 'hexdump.asm'

	ds	256
.stack:


	ds      0x100-(($+0x100)&0x0ff)		; align to multiple of 0x100 for EZ dumping
.buf:
	ds	256

