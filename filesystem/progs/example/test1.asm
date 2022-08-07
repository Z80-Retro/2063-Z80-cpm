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


	org	0x100
loop:
	ld	c,CON_IN
	call	BDOS			; blocking read of a char from console into A

	ld	e,a
	ld	c,CON_OUT
	call	BDOS			; blocking write char in E to console

	jp	loop			; endless loop (this program does not exit)

	end
