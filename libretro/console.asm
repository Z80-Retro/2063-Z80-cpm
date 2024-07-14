;****************************************************************************
;
;        Copyright (C) 2021,2024 John Winans
;
;        This library is free software; you can redistribute it and/or
;        modify it under the terms of the GNU Lesser General Public
;        License as published by the Free Software Foundation; either
;        version 2.1 of the License, or (at your option) any later version.
;
;        This library is distributed in the hope that it will be useful,
;        but WITHOUT ANY WARRANTY; without even the implied warranty of
;        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;        Lesser General Public License for more details.
;
;        You should have received a copy of the GNU Lesser General Public
;        License along with this library; if not, write to the Free Software
;        Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301
;        USA
;
; https://github.com/johnwinans/2063-Z80-cpm
;
;****************************************************************************


include 'sio.asm'
include 'ctc1.asm'

con_init:
        ;ld     c,6                     ; C = 6 = 19200 bps
        ld      c,12                    ; C = 12 = 9600 bps
        call    init_ctc_1              ; start CTC1 in case J11-A selects it!
        call    sioa_init               ; 115200 or 19200/9600 depending on J11-A
        ret


;##########################################################################
;
; CP/M 2.2 Alteration Guide p17:
; Read the next console character into register A and set the parity bit
; (high order bit) to zero.  If no console character is ready, wait until
; a character is typed before returning.
;
;##########################################################################
if 1
con_rx_char:    equ     sioa_rx_char    ; assemble the BIOS to call the sioa version direct
else
con_rx_char:
        call    sioa_rx_char
        ; A special hacked version to dump the disk cache status when pressing the escape key
        cp      0x1B                            ; escape key??
        ret     nz                              ; if not an escape then return
        call    z,disk_dmcache_debug_wedge      ; else tail-call the debug wedge
        ld      a,0x1B                          ; restore the trigger key value
        ret
endif

