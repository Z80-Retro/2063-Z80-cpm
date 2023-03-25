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


ERROR   DO NOT USE!!!  THIS CODE IS ONLY A STUB.

; An NHACP driver for network-mounted filesystems.

; For performance reasons, the SIO driver is not used and the access is in-lined here.

.nhacp_debug:         equ     1

if 1
.SOM:		equ	's'
.EOM:		equ	'e'
.ESC:		equ	'1'
else
.SOM:		equ	0xcb
.EOM:		equ	0xc0
.ESC:		equ	0xdb
endif
.ESC_SOM:	equ	.SOM+1
.ESC_EOM:	equ	.EOM+1
.ESC_ESC:	equ	.ESC+1

;****************************************************************************
;****************************************************************************
nhacp_init:
if .nhacp_debug >= 1
        call    iputs
        db      "rw_init entered\r\n\0"
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
; Send a STORAGE-GET-BLOCK message
; type 		u8 	0x07
; index 	u8 	Storage slot to access
; block-number 	u32 	0-based index of block to access
; block-length 	u16 	Length of the block
;
; Parameters:
;  HL = block number
;   A  = slot number
;  DE = buffer to store block into
; Return:
;  If CY is set then error/timeout
;****************************************************************************
nhacp_get_blk:
	ld	(.get_blk_block),hl
	ld	(.get_blk_slot),a
	ld	hl,.get_blk
	ld	b,8
	call	nhacp_tx_msg
	ld	b,128
	call	.rx_buffer
	ret

.get_blk:
	db	0x07
.get_blk_slot:
	db	0
.get_blk_block:
	dw	0,0
.get_blk_len:
	dw	128	; all blocks on the Retro are 128 bytes 


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
; A = character to send
;****************************************************************************
nhacp_tx_ch:
	cp	.SOM
	jr	z,.tx_som
	cp	.EOM
	jr	z,.tx_eom
	cp	.ESC
	jr	z,.tx_esc
	ld	c,a
.tx_loop:
	call	siob_tx_char
	ret
.tx_som:
	ld	c,.ESC
	call	siob_tx_char
	ld	c,.ESC_SOM
	jp	.tx_loop
.tx_eom:
	ld	c,.ESC
	call	siob_tx_char
	ld	c,.ESC_EOM
	jp	.tx_loop
.tx_esc:
	ld	c,.ESC
	call	siob_tx_char
	ld	c,.ESC_ESC
	jp	.tx_loop


;****************************************************************************
; Send the given buffer with EOM framing bytes around it.
;
; Parameters:
;  HL = buff to send
;  B  = number of bytes to write
;****************************************************************************
nhacp_tx_msg:
	ld	c,.SOM
	call	siob_tx_char	; write without escaping
.tx_msg_loop:
	ld	a,(hl)
	call	nhacp_tx_ch
	inc	hl
	djnz	.tx_msg_loop
	ld	c,.EOM
	call	siob_tx_char	; write without escaping
	ret


;****************************************************************************
; Read one character
; Return:
;  A = new char read in
;  CY = 0 = char is valid
;  CY = 1 = timeout 
;****************************************************************************
.rx_ch_loop:
	; XXX add timeout logic later
nhacp_rx_ch:
	in	a,(sio_bc)      ; read sio control status byte
	rra			; if rcvr is ready then CY = 1
	jr	nc,.rx_ch_loop
	in	a,(sio_bd)	; read the new character
if 0
	push	af
	call	hexdump_a
;	ld	a,'.'
;	out	(sio_ad),a
	pop	af
endif
	ccf			; invert the CY flag
	ret			; CY = 0 = OK
	
;****************************************************************************
; Read up to B bytes from the NHACP link and store them into (HL) 
; Upon return, HL will point to the first unused byte in the buffer.
;
; Message format:
;
;  SOM {data,(ESC,X)}* EOM
;
; The data returned will not include the EOM framing bytes and the
; escapes will have been applied.
;
; This function will discard all data until it sees an EOM and then read
; data into the buffer until it sees a second EOM or the operation times 
; out.
;
; HL = buffer
; B  = buffer size (0 = 256)
;
; Return:
;  if CY set then error
;****************************************************************************

;XXX
;SOM is only of interest when skipping to the start of the next message.  
;While skipping, no other compares need be done. While ingesting a packet 
;body, we only need to check for ESC or EOM.  If ESC and EOM both have 
;their high (or low) 7 bits identical then you only need a shift, CP 
;and conditional branch.  At the branch target, check the carry for which 
;of the two you got.


nhacp_rx_msg:
	call	nhacp_rx_ch		; read a character
	ret	c			; timeout, CY = 1
	cp	.SOM			; of A == .SOM then we can start reading message data
	jr	nz,nhacp_rx_msg		; discard the garbage byte

.nhacp_rx_loop:
	call	nhacp_rx_ch		; read a character
	ret	c			; timeout, CY = 1
	cp	.EOM			; of A == .EOM then Z=1 and CY=0
	ret	z			; CY is clear, we returned a complete message 
	cp	.ESC			; was the new char an ESC?
	jr	z,.rx_do_esc		; got an ESC, read again before storing

	ld	(hl),a			; store the character read into the buffer
	inc	hl			; HL = next buffer address to fill
	djnz	.nhacp_rx_loop		; B = B-1, if not zero then loop
	scf				; set the CY flag because we overflowed 
	ret	

.rx_do_esc:
	call	nhacp_rx_ch		; read the escaped character
	ret	c			; timeout, CY = 1
	dec	a			; adjust the escaped character to correct value

	ld	(hl),a			; store the character read into the buffer
	inc	hl			; HL = next buffer address to fill
	djnz	.nhacp_rx_loop		; B = B-1, if not zero then loop
	scf				; set the CY flag because we overflowed 
	ret	


;****************************************************************************
; Special case for reading a DATA-BUFFER response
;
; Parameters:
;  DE = address of the buffer to store into
;   B = number of bytes to read
; Return:
;  If CY is set then timeout
;  B  = residual length
;  DE = buffer length from the message header
;****************************************************************************
.rx_buffer:
	; discard EOMs until we see an 0x84
	call	nhacp_rx_ch		; read a character
	ret	c			; timeout, CY = 1
	cp	.SOM			; of A == .SOM then Z=1 and CY=0
	jr	nz,.rx_buffer		; thank you sir, may I have another..
	call	nhacp_rx_ch		; read a character
	ret	c			; timeout, CY = 1
	cp	0x84
;	jr	z,.rx_buffer_len1
	scf
	ret	nz			; error due to unexpected message arriving

	ld	l,e
	ld	h,d			; HL = buffer address

	call	nhacp_rx_ch
	ret	c
	ld	e,a
	call	nhacp_rx_ch
	ret	c
	ld	d,a			; DE = data length

.rx_buffer_loop:
	call	nhacp_rx_ch
	cp	.ESC
	jr	z,.rx_buffer_esc
	cp	.EOM
	ret	z			; CY clear after CP and we are done
	ld	(hl),a
	inc	hl
	djnz	.rx_buffer_loop
	or	a			; clear CY flag
	ret

.rx_buffer_esc:
	call	nhacp_rx_ch
	ret	c
	dec	a
	ld	(hl),a
	inc	hl
	djnz	.rx_buffer_loop
	or	a
	ret

