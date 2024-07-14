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

;##########################################################################
; Initialize the printer.
;##########################################################################
list_init:
	ret

;##########################################################################
; Return A=0 if printer is not ready.
; Return A=0xff if printer is ready.
;##########################################################################
list_stat:
        ld      a,0xff
	ret


;##########################################################################
; Print the character in the C register.
;##########################################################################
list_out:
        ret
