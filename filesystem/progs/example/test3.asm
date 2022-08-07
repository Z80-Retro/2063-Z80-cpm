;****************************************************************************
;
;    An example transient (.com file) application designed to be 
;    cross-assembled on Linux and executed on a CP/M 2.0 system.
;
;    Copyright (C) 2022 John Winans
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

BDOS:		equ	5		; The BDOS entry point address

CON_IN:		equ	1		; read character into A
CON_OUT:	equ	2		; write character in E
CON_STR:	equ	9		; write string from address in DE


	org	0x100

	ld	hl,0
	add	hl,sp			; HL = SP
	ld	sp,mystack		; use a local stack area
	push	hl			; save the original SP value


loop:
	ld	c,CON_IN
	call	BDOS			; blocking read of a char from console into A

	cp	'*'			; did we read an asterisk?
	jp	z,do_asterisk

	cp	'.'			; did we read a period?
	jp	z,do_period		; if so then terminate the program

	; else nothing special to do... just echo the character
	ld	e,a
	ld	c,CON_OUT
	call	BDOS
	jp	loop

do_asterisk:
	; We received an asterisk, print the build date & git version info.
	ld	c,CON_STR
	ld	de,message
	call	BDOS
	jp	loop


do_period:
	pop	hl			; HL = original SP value
	ld	sp,hl			; restore original SP
	ret


; A string to print.  Note that the string is terminated with: $
message:
	db	'GIT version: @@GIT_VERSION@@\r\n$'


	ds	256
mystack:

	end
