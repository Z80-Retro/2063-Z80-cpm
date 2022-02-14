;****************************************************************************
;
;    Copyright (C) 2021 John Winans
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

; Driver for CTC port 2

;#############################################################################
; Init the bit-rate generator for SIO B.
; C = clock divisor
;#############################################################################
init_ctc_2:
;   ld      a,0x07      ; TC follows, Timer, Control, Reset
    ld      a,0x47      ; TC follows, Counter, Control, Reset
    out     (ctc_1),a
    ld      a,c
    out     (ctc_1),a
    ret
