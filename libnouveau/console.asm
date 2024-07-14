;****************************************************************************
;
;	 Copyright (C) 2024 John Winans
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

; Drivers for the Z8S180 ASCI 

.CNTLA0: equ     0x00
.CNTLB0: equ     0x02
.RDR0:   equ     0x08
.ASEXT0: equ     0x12
.STAT0:  equ     0x04
.TDR0:   equ     0x06

;##############################################################
; Return NZ if the console UART is ready and Z (with A=0) if not ready.
; Clobbers: AF
;##############################################################
con_tx_ready:
        ;IN0     A,(.STAT0)      ;C4H,read status
        db      11101101B,00111000B,.STAT0
        AND     2
	ret			; a = 0 = not ready

;##############################################################
; Return NZ if the console UART is ready and Z (with A=0) if not ready.
; Clobbers: AF
;##############################################################
con_rx_ready:
        ; hack to clear any overrun errors (See Errata about ASCI seizures)
        ;IN0     A,(.CNTLA0)      ;C4H,read status
        db      11101101B,00111000B,.CNTLA0
        and     ~0x08
        ;OUT0    (.CNTLA0),A
        db      0xed,0x39,.CNTLA0

        ;IN0     A,(.STAT0)      ;C4H,read status
        db      11101101B,00111000B,.STAT0
        AND     10000000B
	ret			; 0 = not ready


;##############################################################
; stolen from https://groups.google.com/g/retro-comp/c/N574sGiwmaI?pli=1
; mods are my fault :-)
;##############################################################
con_init:
        LD      A,01100100B    ; rcv enable, xmit enable, no parity
        ;LD      A,01100101B    ; rcv enable, xmit enable, no parity
        ;OUT0    (.CNTLA0),A    ; set cntla
        db      0xed,0x39,.CNTLA0

        LD      A,00000000B    ; div 10, div 16, div 2 18432000/1/1/10/16/1 = 115200
        ;OUT0    (.CNTLB0),A     ; set cntlb
        db      0xed,0x39,.CNTLB0

        LD      A,01100110B    ; no cts, no dcd, no break detect
        ;OUT0    (.ASEXT0),A     ; set ASCI0 EXTENSION CONTROL (Z8S180 only)
        db      0xed,0x39,.ASEXT0
        XOR     A
        ;OUT0    (.STAT0),A      ; ASCI Status Reg Ch 0
        db      0xed,0x39,.STAT0
        ret


;##############################################################
; Wait for the transmitter to become ready and then
; print the character in the C register.
; Clobbers: AF
;##############################################################
con_tx_char:
	call	con_tx_ready
	jr	z,con_tx_char
	ld	a,c

        ;OUT0    (.TDR0),A       ;C6H
        db      0xed,0x39,.TDR0

	ret

;##############################################################
; Wait for the receiver to become ready and then return the 
; character in the A register.
; Clobbers: AF
;
; XXX need to concern ourselves with the Errata note that
; says we need to write zero into CNTLA0, bit 3 (ERF) to
; reset an overflow error flag when set because RX will
; seize.
;
;##############################################################
con_rx_char:
	call	con_rx_ready
	jr	z,con_rx_char

        ;IN0     A,(.RDR0)
        db      11101101B,00111000B,.RDR0

	ret
