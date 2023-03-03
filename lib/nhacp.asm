;****************************************************************************
;
;	 Copyright (C) 2023 John Winans
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
; https://github.com/Z80-Retro/
;
;****************************************************************************

; An NHACP driver for network-mounted filesystems.

; For performance reasons, the SIO driver is not used and the access is in-lined here.

.nhacp_debug:         equ     1


.EOM:		equ	0xc0
.ESC:		equ	0xdb
.ESC_EOM:	equ	.EOM+1
.ESC_ESC:	equ	.ESC+1

;****************************************************************************
;****************************************************************************
nhacp_init:
if .dn_debug >= 1
        call    iputs
        db      "rw_init entered\r\n\0"
        ld      a,(.dn_disk)
endif
	call	siob_init
	ret

;****************************************************************************
; type 	u8 	0x8f
; magic 	char[3] 	"ACP"
; version 	u16 	Version number of the protocol
;****************************************************************************
nhacp_start:
	ld	hl,.msg_start
	ld	bc,.msg_start_len
	call	nhacp_tx_msg
	ld	hl,.nhacp_buf
	ld	bc,.nhacp_buf_len
	call	nhacp_rx_msg

	;XXX check response here

	ret
.msg_start:
	db	0x8f,'A','C','P',0x01,0x00
.msg_start_len:	equ	$-.msg_start


.nhacp_buf:
	ds	256
.nhacp_buf_len:	equ	$-.nhacp_buf

;****************************************************************************
;****************************************************************************
nhacp_stg_open:
	ld	a,0	; OK
	ret

;****************************************************************************
;****************************************************************************
nhacp_stg_close:
	ld	a,0	; OK
	ret

;****************************************************************************
; type 		u8 	0x07
; index 	u8 	Storage slot to access
; block-number 	u32 	0-based index of block to access
; block-length 	u16 	Length of the block
;****************************************************************************
nhacp_get_blk:
	ld	a,1	; A = 1 = error
	ret

;****************************************************************************
; type 	u8 	0x08
; index 	u8 	Storage slot to access
; block-number 	u32 	0-based index of block to access
; block-length 	u16 	Length of the block
;****************************************************************************
nhacp_put_blk:
	ld	a,1	; A = 1 = error
	ret


;****************************************************************************
; Write one character
;****************************************************************************
nhacp_tx_ch:
	ret



;****************************************************************************
;****************************************************************************
nhacp_tx_msg:
	ret


;****************************************************************************
; Read one character
; Return:
;  A = new char read in
;  CY = 0 = char is valid
;  CY = 1 = timeout 
;****************************************************************************
.rx_ch_loop:
	; XXX wait forever for now
nhacp_rx_ch:
	in	a,(sio_bc)      ; read sio control status byte
	rra			; if rcvr is ready then CY = 1
	jr	nc,.rx_ch_loop
	ld	a,(sio_bd)	; read the new character
	ccf			; invert the CY flag
	ret			; CY = 0 = OK
	
;****************************************************************************
; Read up to B bytes from the nhacp link and store them into (HL) 
; Upon return, HL will point to the first unused byte in the buffer.
;
; Return:
;  if CY set then error
;****************************************************************************
nhacp_rx_msg:
	call	nhacp_rx_ch		; read a character
	ret	c			; timeout, CY = 1
	cp	.EOM			; of A == .EOM then Z=1 and CY=0
	ret	z			; CY is clear, we returned a complete message 
	cp	.ESC			; was the new char an ESC?
	jr	z,.rx_do_esc		; got an ESC, read again before storing

	ld	(hl),a			; store the character read into the buffer
	inc	hl			; HL = next buffer address to fill
	djnz	nhacp_rx_msg		; B = B-1, if not zero then loop
	scf				; set the CY flag because we overflowed 
	ret	

.rx_do_esc:
	call	nhacp_rx_ch		; read the escaped character
	ret	c			; timeout, CY = 1
	dec	a			; adjust the escaped character to correct value

	ld	(hl),a			; store the character read into the buffer
	inc	hl			; HL = next buffer address to fill
	djnz	nhacp_rx_msg		; B = B-1, if not zero then loop
	scf				; set the CY flag because we overflowed 
	ret	

