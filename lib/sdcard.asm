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
;****************************************************************************


sd_debug: equ 0

;############################################################################
; Read bytes until we find one with MSB = 0 or bail out retrying.
; Return last read byte in A.
; Calls spi_read8 (see for clobbers)
; Clobbers A, B, DE
;############################################################################
sd_read_r1:
	;ld	b,10
	ld	b,0xf0
sd_r1_loop:
	call	spi_read8
	ld	e,a
	and	0x80
	jr	z,sd_r1_done
	djnz	sd_r1_loop
sd_r1_done:
	ld	a,e
	ret


;############################################################################
; Read an R7 message into the 5-byte buffer pointed to by HL.
; Clobbers HL.
; Calls sd_read_r1 and spi_read8
;############################################################################
sd_read_r7:
	call	sd_read_r1
	ld	(hl),a
	inc	hl
	call	spi_read8
	ld	(hl),a
	inc	hl
	call	spi_read8
	ld	(hl),a
	inc	hl
	call	spi_read8
	ld	(hl),a
	inc	hl
	call	spi_read8
	ld	(hl),a
	ret



;##############################################################
; SSEL = HI (deassert)
; wait at least 1 msec after power up
; send at least 74 SCLK rising edges
; Clobbers A, D, B, and C
;##############################################################
sd_boot:
	ld	c,0xff
	ld	b,10
sd_boot1:
	call	spi_write8
	djnz	sd_boot1
	ret


;##############################################################
; Send a command and read an R1 response message.
; HL = command buffer address
; B = command byte length
; Clobbers A, B, HL
; Calls spi_write8, spi_ssel_true, spi_write_str, sd_read_r1, spi_ssel_false
; Returns A = reply message
;
; Modus operandi
; SSEL = LO (assert)
; send CMD
; send arg 0
; send arg 1
; send arg 2
; send arg 3
; send CRC 

; wait for reply (MSB=0)
; read reply
; SSEL = HI
;##############################################################
sd_cmd_r1:
	push	hl
	push	bc

	; assert the SSEL line
	call    spi_ssel_true

	; write a sequence of bytes represending the CMD message
	pop	bc
	pop	hl
	call    spi_write_str

	; read the R1 response message
	call    sd_read_r1
	push	af

	; de-assert the SSEL line
	call    spi_ssel_false

	pop	af
	ret


;##############################################################
; Send a command and read an R7 response message.
; HL = command buffer address
; B = command byte length
; DE = 5-byte response buffer
;##############################################################
sd_cmd_r7:
	push	de
	push	hl
	push	bc

	; assert the SSEL line
	call    spi_ssel_true

	; write a sequence of bytes represending the CMD message
	pop	bc
	pop	hl
	call    spi_write_str

	; read the R1 response message
	pop	hl			; pop the response buffer length into HL
	call    sd_read_r7

	; de-assert the SSEL line
	call    spi_ssel_false

	ret




;##############################################################
; Send a CMD0 message and read the response.
; Return the response byte in A.
;##############################################################
sd_cmd0:
	ld	hl,sd_cmd0_buf
	ld	b,sd_cmd0_len
	call	sd_cmd_r1

if sd_debug
	push	af
	ld	hl,sd_cmd0_str
	call	pstr
	pop	af
	call	hexdump_a		; dump the reply message
	call    puts_crlf
endif

	ret

sd_cmd0_buf:	defb	0|0x40,0,0,0,0,0x94|0x01
sd_cmd0_len:	equ	$-sd_cmd0_buf
if sd_debug
sd_cmd0_str:	defb	'CMD0: \0'
endif


;##############################################################
; Send a CMD8 message and read the response.
; Return the 5-byte response in the buffer pointed to by DE.
; The response should be: 0x01 0x00 0x00 0x01 0xAA.
;##############################################################
sd_cmd8:
if sd_debug
	push	de			; PUSH buffer address
endif

	ld	hl,sd_cmd8_buf
	ld	b,sd_cmd8_len
	call	sd_cmd_r7

if sd_debug
	ld	hl,sd_cmd8_str
	call	pstr
	pop	hl			; POP buffer address
	ld	bc,5
	ld	e,0
	call	hexdump			; dump the reply message
	call	puts_crlf
endif

	ret

sd_cmd8_buf:	defb	8|0x40,0,0,0x01,0xaa,0x86|0x01
sd_cmd8_len:	equ	$-sd_cmd8_buf
if sd_debug
sd_cmd8_str:	defb	'CMD8: \0'
endif


;##############################################################
; Send a CMD58 message and read the response.
; Return the 5-byte response in the buffer pointed to by DE.
;##############################################################
sd_cmd58:
if sd_debug
	push	de			; PUSH buffer address
endif

	ld	hl,sd_cmd58_buf
	ld	b,sd_cmd58_len
	call	sd_cmd_r7

if sd_debug
	ld	hl,sd_cmd58_str
	call	pstr
	pop	hl			; POP buffer address
	ld	bc,5
	ld	e,0
	call	hexdump			; dump the reply message
	call	puts_crlf
endif

	ret

sd_cmd58_buf:	defb	58|0x40,0,0,0,0,0x00|0x01
sd_cmd58_len:	equ	$-sd_cmd58_buf
if sd_debug
sd_cmd58_str:	defb	'CMD58: \0'
endif


;############################################################################
; Send a CMD55 message and read the response.
; Return the 5-byte response in the buffer pointed to by DE. 
;############################################################################
sd_cmd55:
	ld	hl,sd_cmd55_buf
	ld	b,sd_cmd55_len
	call	sd_cmd_r1

if sd_debug
	push	af
	ld	hl,sd_cmd55_str
	call	pstr
	pop	af
	call	hexdump_a	; dump the response byte
	call    puts_crlf
endif

	ret

sd_cmd55_buf:	defb	55|0x40,0,0,0,0,0x00|0x01
sd_cmd55_len:	equ	$-sd_cmd55_buf
if sd_debug
sd_cmd55_str:	defb	'CMD55: \0'
endif


;############################################################################
; Send a ACMD41 message and return the response byte in A.
; Note that A-commands are prefixed with a CMD55.
;############################################################################
sd_acmd41:
	push	de
	call	sd_cmd55
	pop	de
	
	ld	hl,sd_acmd41_buf
	ld	b,sd_acmd41_len
	call	sd_cmd_r1

if sd_debug
	push	af
	ld	hl,sd_acmd41_str
	call	pstr
	pop	af
	push	af
	call	hexdump_a	; dump the status byte
	call    puts_crlf
	pop	af
endif

	ret


; Notes on Internet mention setting HCS and a bit.
; Notes on Internet about setting the supply voltage in ACMD41. But not in SPI mode?

sd_acmd41_buf:	defb	41|0x40,0x40,0,0,0,0x00|0x01	; Note the HCS flag is set here
sd_acmd41_len:	equ	$-sd_acmd41_buf
if sd_debug
sd_acmd41_str:	defb	'ACMD41: \0'
endif



;############################################################################
; Get the SD card to wake up ready for block transfers.
; XXX This is a hack added to let the BIOS reset everything.
;############################################################################
sd_reset:
	;call	sd_boot
	call	sd_clk_dly
	call    sd_cmd0

	ld      de,sd_scratch
	call    sd_cmd8

	ld      de,sd_scratch
	call    sd_cmd58

	ld      b,0x20          ; limit the number of retries here
sd_reset_ac41:
	push    bc
	ld      de,sd_scratch
	call    sd_acmd41
	pop     bc
	or      a
	jr      z,sd_reset_done
	djnz    sd_reset_ac41

	call	iputs
	defb	"SD_RESET FAILED!\r\n\0"
	ld	a,0x01
	ret

sd_reset_done:
	ld      de,sd_scratch
	call    sd_cmd58
	xor	a
	ret

;############################################################################
; A hack to just supply clock for a while.
;############################################################################
sd_clk_dly:
	push	de
	push	hl
	ld	hl,0x80
sd_clk_dly1:
	call	spi_read8
	dec	hl
	ld	a,h
	or	l
	jr	nz,sd_clk_dly1
	pop	hl
	pop	de
	ret
	

;############################################################################
; Read one block given by the 32-bit (little endian) number at 
; the top of the stack into the buffer given by address in DE.
;
; A = 0 if the read operation was successful. Else A=1
; Clobbers A
;############################################################################
debug_cmd17:	equ	0

sd_cmd17:
	; iy is the frame pointer 
					; +16 = &block_number
					; +14 = return @
	push	bc			; +12
	push	de			; +10 target buffer address
	push	hl			; +8
	push	iy			; +6

	; make room for the command buffer
sd_cmd17_len:	equ	6
	ld	iy,-sd_cmd17_len
	add	iy,sp			; iy = &cmd_buffer
	ld	sp,iy

	ld	(iy+0),17|0x40		; the command byte
	ld	a,(iy+19)		; stack = little endian
	ld	(iy+1),a		; cmd_buffer = big endian
	ld	a,(iy+18)
	ld	(iy+2),a
	ld	a,(iy+17)
	ld	(iy+3),a
	ld	a,(iy+16)
	ld	(iy+4),a
	ld	(iy+5),0x00|0x01	; the CRC byte

if debug_cmd17
	; print the comand buffer
	ld	hl,sd_cmd17_str	; print dump heading 
	call	pstr
	push	iy
	pop	hl			; hl = &cmd_buffer
	ld	b,sd_cmd17_len
	call	hexdump_c
;	call	puts_crlf
	
	; print the target address
	ld	hl,sd_cmd17_trg	; print dump heading 
	call	pstr
	ld	a,(iy+11)
	call	hexdump_a
	ld	a,(iy+10)
	call	hexdump_a
	call	puts_crlf
endif

	; assert the SSEL line
	call    spi_ssel_true

	; send the command 
	push	iy
	pop	hl			; hl = iy = &cmd_buffer
	ld	b,sd_cmd17_len
	call    spi_write_str		; clobbers A, BC, D, HL

	; read the R1 response message
	call    sd_read_r1		; clobbers A, B, DE

	; If R1 status != SD_READY (0x00) then error
;	or	a			; if (a == 0x00) then is OK
;	jr	z,sd_cmd17_r1ok
	cp	0xff
	jr	nz,sd_cmd17_r1ok

	; print the R1 status byte
	push	af
	call	iputs
	defb	"SD CMD17 R1 error = 0x\0"
	pop	af
	call	hexdump_a
	call	puts_crlf

if debug_cmd17
	; print the command buffer
	ld	hl,sd_cmd17_str	; print dump heading 
	call	pstr
	push	iy
	pop	hl			; hl = &cmd_buffer
	ld	b,sd_cmd17_len
	call	hexdump_c

	; print the target address
	ld	hl,sd_cmd17_trg	; print dump heading 
	call	pstr
	ld	a,(iy+11)
	call	hexdump_a
	ld	a,(iy+10)
	call	hexdump_a
	call	puts_crlf
endif

	jp	sd_cmd17_err


sd_cmd17_r1ok:

	; read and toss bytes while waiting for the data token
	ld      bc,0x400		; expect to wait a while for a reply
sd_cmd17_loop:
	call    spi_read8		; (clobbers A, DE)
	cp	0xff			; if a=0xff then command has timed out
	jr      nz,sd_cmd17_token
	dec	bc
	ld	a,b
	or	c
	jr	nz,sd_cmd17_loop

	call	iputs
	defb	"SD CMD17 data timeout\r\n\0"
	jp	sd_cmd17_err		; no flag ever arrived

sd_cmd17_token:
	ld	l,(iy+10)		; hl = target buffer address
	ld	h,(iy+11)

	cp	0xfe			; A = data block token? (else is junk from the SD)
	jr	z,sd_cmd17_tokok

	call	iputs
	defb	"SD CMD17 invalid response token\r\n\0"
	jp	sd_cmd17_err

sd_cmd17_tokok:
	ld	bc,0x200		; 512 bytes to read
sd_cmd17_blk:
	call	spi_read8		; Clobbers A, DE
	ld	(hl),a
	inc	hl
	dec	bc

if 0; debug_cmd17
	call	hexdump_a
	ld	a,' '
	call	tx_char
	ld	a,c			; if %16 then 
	and	0x0f		
	jr	nz,sd_cmd17_dsp
	ld	a,'\r';
	call	tx_char
	ld	a,'\n'
	call	tx_char
sd_cmd17_dsp:
endif

	ld	a,b
	or	c
	jr	nz,sd_cmd17_blk

	call	spi_read8		; read the CRC value (XXX should check this)
	call	spi_read8		; read the CRC value (XXX should check this)

	call    spi_ssel_false
	xor	a			; A = 0 = success!

sd_cmd17_done:
	ld	iy,sd_cmd17_len
	add	iy,sp
	ld	sp,iy
	pop	iy
	pop	hl
	pop	de
	pop	bc
	ret

sd_cmd17_err:
	call	spi_ssel_false

	ld	a,0x01		; return an error flag
	jr	sd_cmd17_done


if 1; debug_cmd17
sd_cmd17_str:		defb	'CMD17: \r\n\0'
sd_cmd17_trg:		defb	'Target: \0'
endif




;##############################################################
; Write one block given by the 32-bit (little endian) number at 
; the top of the stack from the buffer given by address in DE.
;
; A = 0 if the write operation was successful. Else A = 1.
; Clobbers A
;##############################################################
debug_cmd24:	equ	0 ;debug

sd_cmd24:
	; ix is a quasi-frame pointer 
					; +10 = &block_number
					; +8 = return @
	push	bc			; +6
	push	de			; +4 target buffer address
	push	hl			; +2
	push	iy			; +0

	ld	iy,sd_scratch		; iy = buffer to format command
	ld	ix,10
	add	ix,sp			; ix = uint32_t sd_lba_block

sd_cmd24_len: equ	6

	ld	(iy+0),24|0x40		; the command byte
	ld	a,(ix+3)		; stack = little endian
	ld	(iy+1),a		; cmd_buffer = big endian
	ld	a,(ix+2)
	ld	(iy+2),a
	ld	a,(ix+1)
	ld	(iy+3),a
	ld	a,(ix+0)
	ld	(iy+4),a
	ld	(iy+5),0x00|0x01	; the CRC byte

if debug_cmd24
	; print the command buffer
	call	iputs
	defb	"  CMD24: \0"
	push	iy
	pop	hl			; hl = &cmd_buffer
	ld	b,sd_cmd24_len
	call	hexdump_c

	; print the target address
	call	iputs
	defb	"  CMD24: source: \0"
	ld	a,(ix-5)
	call	hexdump_a
	ld	a,(ix-6)
	call	hexdump_a
	call	puts_crlf
endif

	; assert the SSEL line
	call    spi_ssel_true

	; send the command 
	push	iy
	pop	hl			; hl = iy = &cmd_buffer
	ld	b,sd_cmd24_len
	call	spi_write_str		; clobbers A, BC, D, HL

	; read the R1 response message
	call    sd_read_r1		; clobbers A, B, DE

	; If R1 status != SD_READY (0x00) then error
	or	a			; if (a == 0x00) 
	jr	z,sd_cmd24_r1ok		; then OK
					; else error...

	push	af
	call	iputs
	defb	"SD CMD24 status = \0"
	pop	af
	call	hexdump_a
	call	iputs
	defb	" != SD_READY\r\n\0"
	jp	sd_cmd24_err		; then error


sd_cmd24_r1ok:
	; give the SD card an extra 8 clocks before we send the start token
	ld	c,0xff
	call	spi_write8

	; send the start token: 0xfe
	ld	c,0xfe
	call	spi_write8		; clobbers A and D

	; send 512 bytes

	ld	l,(ix-6)		; hl = source buffer address
	ld	h,(ix-5)
	ld	bc,0x200		; bc = 512 bytes to read
sd_cmd24_blk:
	push	bc			; XXX speed this up
	ld	c,(hl)
	call	spi_write8		; Clobbers A and D
	inc	hl
	pop	bc			; XXX speed this up
	dec	bc
	ld	a,b
	or	c
	jr	nz,sd_cmd24_blk

	; read for up to 250msec waiting on a completion status

	ld	bc,0xf000		; wait a potentially /long/ time for the write to complete
sd_cmd24_wdr:				; wait for data response message
	call	spi_read8		; clobber A, DE
	cp	0xff
	jr	nz,sd_cmd24_drc
	ld	a,b
	or	c
	jr	nz,sd_cmd24_wdr

	call    iputs
	defb	"SD CMD24 completion status timeout!\r\n\0"
	jp	sd_cmd24_err	; timed out


sd_cmd24_drc:
	; Make sure the response is 0bxxx00101 else is an error
	and	0x1f
	cp	0x05
	jr	z,sd_cmd24_ok


	push	bc
	call	iputs
	defb	"SD CMD24 completion status != 0x05 (count=\0"
	pop	bc
	push	bc
	ld	a,b
	call	hexdump_a
	pop	bc
	ld	a,c
	call	hexdump_a
	call	iputs
	defb	")\r\n\0"

	jp	sd_cmd24_err

sd_cmd24_ok:
	call	spi_ssel_false


if 1
	; Wait until the card reports that it is not busy
	call	spi_ssel_true

sd_cmd24_busy:
	call	spi_read8		; clobber A, DE
	cp	0xff
	jr	nz,sd_cmd24_busy

	call	spi_ssel_false
endif
	xor	a			; A = 0 = success!

sd_cmd24_done:
	pop	iy
	pop	hl
	pop	de
	pop	bc
	ret

sd_cmd24_err:
    call    spi_ssel_false

if debug_cmd24
	call	iputs
	defb	"SD CMD24 write failed!\r\n\0"
endif

	ld	a,0x01		; return an error flag
	jr	sd_cmd24_done



;##############################################################
; A buffer for exchanging messages with the SD card.
;##############################################################
sd_scratch:
	ds	6
