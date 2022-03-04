;****************************************************************************
;
;	 Copyright (C) 2021 John Winans
;
;	 This library is free software; you can redistribute it and/or
;	 modify it under the terms of the GNU Lesser General Public
;	 License as published by the Free Software Foundation; either
;	 version 2.1 of the License, or (at your option) any later version.
;
;	 This library is distributed in the hope that it will be useful,
;	 but WITHOUT ANY WARRANTY; without even the implied warranty of
;	 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;	 Lesser General Public License for more details.
;
;	 You should have received a copy of the GNU Lesser General Public
;	 License along with this library; if not, write to the Free Software
;	 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301
;	 USA
;
; https://github.com/johnwinans/2063-Z80-cpm
;
;****************************************************************************

; Drivers for the SIO 


;##############################################################
; Return NZ if sio A tx is ready
; Clobbers: AF
;##############################################################
sioa_tx_ready:
	in	a,(sio_ac)	; read sio control status byte
	and	4		; check the xmtr empty bit
	ret			; a = 0 = not ready

;##############################################################
; Return NZ if sio B tx is ready
; Clobbers: AF
;##############################################################
siob_tx_ready:
	in	a,(sio_bc)	; read sio control status byte
	and	4		; check the xmtr empty bit
	ret			; a = 0 = not ready

;##############################################################
; Return NZ (with A=1) if sio A rx is ready and Z (with A=0) if not ready.
; Clobbers: AF
;##############################################################
con_rx_ready:
sioa_rx_ready:
	in	a,(sio_ac)	; read sio control status byte
	and	1		; check the rcvr ready bit
	ret			; 0 = not ready

;##############################################################
; Return NZ (with A=1) if sio B rx is ready and Z (with A=0) if not ready. 
; Clobbers: AF
;##############################################################
siob_rx_ready:
	in	a,(sio_bc)	; read sio control status byte
	and	1		; check the rcvr ready bit
	ret			; 0 = not ready



;##############################################################
; init SIO port A/B
; Clobbers HL, BC, AF
;##############################################################
siob_init:
	ld	c,sio_bc	; port to write into (port B control)
	jp	.sio_init

sioa_init:
	ld	c,sio_ac	; port to write into (port A control)

.sio_init:
	ld	hl,.sio_init_wr	; point to init string
	ld	b,.sio_init_len_wr ; number of bytes to send
	otir			; write B bytes from (HL) into port in the C reg
	ret

;##############################################################
; Initialization string for the Z80 SIO
;##############################################################
.sio_init_wr:
	db	00011000b	; wr0 = reset everything
	db	00000100b	; wr0 = select reg 4
	db	01000100b	; wr4 = /16 N1 (115200 from 1.8432 MHZ clk)
	db	00000011b	; wr0 = select reg 3
	db	11000001b	; wr3 = RX enable, 8 bits/char
	db	00000101b	; wr0 = select reg 5
	db	01101000b	; wr5 = DTR=0, TX enable, 8 bits/char
.sio_init_len_wr:   equ $-.sio_init_wr



;##############################################################
; Wait for the transmitter to become ready and then
; print the character in the C register.
; Clobbers: AF
;##############################################################
siob_tx_char:
	call	siob_tx_ready
	jr	z,siob_tx_char
	ld	a,c
	out	(sio_bd),a	; send the character
	ret

con_tx_char:
sioa_tx_char:
	call	sioa_tx_ready
	jr	z,sioa_tx_char
	ld	a,c
	out	(sio_ad),a	; send the character
	ret

;##############################################################
; Wait for the receiver to become ready and then return the 
; character in the A register.
; Clobbers: AF
;##############################################################
siob_rx_char:
	call	siob_rx_ready
	jr	z,siob_rx_char
	ld	a,(sio_bd)
	ret

con_rx_char:
sioa_rx_char:
	call	sioa_rx_ready
	jr	z,sioa_rx_char
	in	a,(sio_ad)
	ret
