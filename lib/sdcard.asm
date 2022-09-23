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

;############################################################################
;
; An SD card library suitable for talking to SD cards in SPI mode 0.
;
; XXX As of 2022-02-14, this code has been tested on house-brand (Inland)
; MicroCenter SD version 2.0 SDHC cards:
;	https://www.microcenter.com/product/486146/micro-center-16gb-microsdhc-card-class-10-flash-memory-card-with-adapter
;
; WARNING: SD cards are 3.3v ONLY!
; Must provide a pull up on MISO to 3.3V.
; SD cards operate on SPI mode 0.
;
; References:
; - SD Simplified Specifications, Physical Layer Simplified Specification, 
;   Version 8.00:    https://www.sdcard.org/downloads/pls/
;
; The details on operating an SD card in SPI mode can be found in 
; Section 7 of the SD specification, p242-264.
;
; To initialize an SDHC/SDXC card:
; - send at least 74 CLKs
; - send CMD0 & expect reply message = 0x01 (enter SPI mode)
; - send CMD8 (establish that the host uses Version 2.0 SD SPI protocol)
; - send ACMD41 (finish bringing the SD card on line)
; - send CMD58 to verify the card is SDHC/SDXC mode (512-byte block size)
;
; At this point the card is on line and ready to read and write 
; memory blocks.
;
; - use CMD17 to read one 512-byte block
; - use CMD24 to write one 512-byte block
;
;############################################################################

.sd_debug: equ 0
;.sd_debug: equ 1

;############################################################################
; NOTE: Response message formats in SPI mode are different than in SD mode.
;
; Read bytes until we find one with MSB = 0 or bail out retrying.
; Return last read byte in A (and a copy also in E)
; Calls spi_read8 (see for clobbers)
; Clobbers A, B, DE
;############################################################################
.sd_read_r1:
	ld	b,0xf0		; B = number of retries
.sd_r1_loop:
	call	spi_read8	; read a byte into A (and a copy in E as well)
	and	0x80		; Is the MSB set to 1?
	jr	z,.sd_r1_done	; If MSB=0 then we are done
	djnz	.sd_r1_loop	; else try again until the retry count runs out
.sd_r1_done:
	ld	a,e		; copy the final value into A
	ret


;############################################################################
; NOTE: Response message formats in SPI mode are different than in SD mode.
;
; Read an R7 message into the 5-byte buffer pointed to by HL.
; Clobbers A, B, DE, HL
;############################################################################
.sd_read_r7:
	call	.sd_read_r1	; A = byte #1
	ld	(hl),a		; save it
	inc	hl		; advance receive buffer pointer
	call	spi_read8	; A = byte #2
	ld	(hl),a		; save it
	inc	hl		; advance receive buffer pointer
	call	spi_read8	; A = byte #3
	ld	(hl),a		; save it
	inc	hl		; advance receive buffer pointer
	call	spi_read8	; A = byte #4
	ld	(hl),a		; save it
	inc	hl		; advance receive buffer pointer
	call	spi_read8	; A = byte #5
	ld	(hl),a		; save it
	ret


;############################################################################
; SSEL = HI (deassert)
; wait at least 1 msec after power up
; send at least 74 (80) SCLK rising edges
; Clobbers A, DE, B
;############################################################################
sd_boot:
	ld	b,10		; 10*8 = 80 bits to read
.sd_boot1:
	call	spi_read8	; read 8 bits (causes 8 CLK xitions)
	djnz	.sd_boot1	; if not yet done, do another byte
	ret


;############################################################################
; Send a command and read an R1 response message.
; HL = command buffer address
; B = command byte length
; Clobbers A, BC, DE, HL
; Returns A = reply message byte
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
;############################################################################
.sd_cmd_r1:
	; assert the SSEL line
	call    spi_ssel_true

	; write a sequence of bytes represending the CMD message
	call    spi_write_str		; write B bytes from HL buffer @

	; read the R1 response message
	call    .sd_read_r1		; A = E = message response byte

	; de-assert the SSEL line
	call    spi_ssel_false

	ld	a,e
	ret


;############################################################################
; Send a command and read an R7 response message.
; Note that an R3 response is the same size, so can use the same code.
; HL = command buffer address
; B = command byte length
; DE = 5-byte response buffer address
; Clobbers A, BC, DE, HL
;############################################################################
.sd_cmd_r3:
.sd_cmd_r7:
	call    spi_ssel_true

	push	de			; save the response buffer @
	call    spi_write_str		; write cmd buffer from HL, length=B

	; read the response message into buffer @ in HL
	pop	hl			; pop the response buffer @ HL
	call    .sd_read_r7

	; de-assert the SSEL line
	call    spi_ssel_false

	ret


;############################################################################
; Send a CMD0 (GO_IDLE) message and read an R1 response.
;
; CMD0 will 
; 1) Establish the card protocol as SPI (if has just powered up.)
; 2) Tell the card the voltage at which we are running it.
; 3) Enter the IDLE state.
;
; Return the response byte in A.
; Clobbers A, BC, DE, HL
;############################################################################
sd_cmd0:
	ld	hl,.sd_cmd0_buf		; HL = command buffer
	ld	b,.sd_cmd0_len		; B = command buffer length
	call	.sd_cmd_r1		; send CMD0, A=response byte

if .sd_debug
	push	af
	call	iputs
	db	'CMD0: \0'
	ld	hl,.sd_cmd0_buf
	ld	bc,.sd_cmd0_len
	ld	e,0
	call	hexdump
	call	iputs
	db	'  R1: \0'
	pop	af
	push	af
	call	hexdump_a		; dump the reply message
	call    puts_crlf
	pop	af
endif

	ret

.sd_cmd0_buf:	db	0|0x40,0,0,0,0,0x94|0x01
.sd_cmd0_len:	equ	$-.sd_cmd0_buf


;############################################################################
; Send a CMD8 (SEND_IF_COND) message and read an R7 response.
;
; Establish that we are squawking V2.0 of spec & tell the SD 
; card the operating voltage is 3.3V.  The reply to CMD8 should 
; be to confirm that 3.3V is OK and must echo the 0xAA back as 
; an extra confirm that the command has been processed properly. 
; The 0x01 in the byte before the 0xAA in the command buffer 
; below is the flag for 2.7-3.6V operation.
;
; Establishing V2.0 of the SD spec enables the HCS bit in 
; ACMD41 and CCS bit in CMD58.
;
; Clobbers A, BC, DE, HL
; Return the 5-byte response in the buffer pointed to by DE.
; The response should be: 0x01 0x00 0x00 0x01 0xAA.
;############################################################################
sd_cmd8:
if .sd_debug
	push	de			; PUSH response buffer address
endif

	ld	hl,.sd_cmd8_buf
	ld	b,.sd_cmd8_len
	call	.sd_cmd_r7

if .sd_debug
	call	iputs
	db	'CMD8: \0'
	ld	hl,.sd_cmd8_buf
	ld	bc,.sd_cmd8_len
	ld	e,0
	call	hexdump
	call	iputs
	db	'  R7: \0'
	pop	hl			; POP buffer address
	ld	bc,5
	ld	e,0
	call	hexdump			; dump the reply message
endif

	ret

.sd_cmd8_buf:	db	8|0x40,0,0,0x01,0xaa,0x86|0x01
.sd_cmd8_len:	equ	$-.sd_cmd8_buf


;############################################################################
; Send a CMD58 message and read an R3 response.
; CMD58 is used to ask the card what voltages it supports and
; if it is an SDHC/SDXC card or not.
; Clobbers A, BC, DE, HL
; Return the 5-byte response in the buffer pointed to by DE.
;############################################################################
sd_cmd58:
if .sd_debug
	push	de			; PUSH buffer address
endif

	ld	hl,.sd_cmd58_buf
	ld	b,.sd_cmd58_len
	call	.sd_cmd_r3

if .sd_debug
	call	iputs
	db	'CMD58: \0'
	ld	hl,.sd_cmd58_buf
	ld	bc,.sd_cmd58_len
	ld	e,0
	call	hexdump
	call	iputs
	db	'  R3: \0'
	pop	hl			; POP buffer address
	ld	bc,5
	ld	e,0
	call	hexdump			; dump the reply message
endif

	ret

.sd_cmd58_buf:	db	58|0x40,0,0,0,0,0x00|0x01
.sd_cmd58_len:	equ	$-.sd_cmd58_buf


;############################################################################
; Send a CMD55 (APP_CMD) message and read an R1 response.
; CMD55 is used to notify the card that the following message is an ACMD 
; (as opposed to a regular CMD.)
; Clobbers A, BC, DE, HL
; Return the 1-byte response in A
;############################################################################
sd_cmd55:
	ld	hl,.sd_cmd55_buf	; HL = buffer to write
	ld	b,.sd_cmd55_len	; B = buffer byte count
	call	.sd_cmd_r1	; write buffer, A = R1 response byte

if .sd_debug
	push	af
	call	iputs
	db	'CMD55: \0'
	ld	hl,.sd_cmd55_buf
	ld	bc,.sd_cmd55_len
	ld	e,0
	call	hexdump
	call	iputs
	db	'  R1: \0'
	pop	af
	push	af
	call	hexdump_a	; dump the response byte
	call    puts_crlf
	pop	af
endif

	ret

.sd_cmd55_buf:	db	55|0x40,0,0,0,0,0x00|0x01
.sd_cmd55_len:	equ	$-.sd_cmd55_buf


;############################################################################
; Send a ACMD41 (SD_SEND_OP_COND) message and return an R1 response byte in A.
;
; The main purpose of ACMD41 to set the SD card state to READY so
; that data blocks may be read and written.  It can fail if the card
; is not happy with the operating voltage.
;
; Clobbers A, BC, DE, HL
; Note that A-commands are prefixed with a CMD55.
;############################################################################
sd_acmd41:
	call	sd_cmd55		; send the A-command prefix

	ld	hl,.sd_acmd41_buf	; HL = command buffer
	ld	b,.sd_acmd41_len	; B = buffer byte count
	call	.sd_cmd_r1

if .sd_debug
	push	af
	call	iputs
	db	'ACMD41: \0'
	ld	hl,.sd_acmd41_buf
	ld	bc,.sd_acmd41_len
	ld	e,0
	call	hexdump
	call	iputs
	db	'   R1: \0'
	pop	af
	push	af
	call	hexdump_a	; dump the status byte
	call    puts_crlf
	pop	af
endif

	ret


; SD spec p263 Fig 7.1 footnote 1 says we want to set the HCS bit here for HC/XC cards.
; Notes on Internet about setting the supply voltage in ACMD41. But not in SPI mode?
; The folowing works on my MicroCenter SDHC cards:

.sd_acmd41_buf:	db	41|0x40,0x40,0,0,0,0x00|0x01	; Note the HCS flag is set here
.sd_acmd41_len:	equ	$-.sd_acmd41_buf



;############################################################################
; Get the SD card to wake up ready for block transfers.
;
; XXX This is a hack added to let the BIOS reset everything. XXX
;
;############################################################################
sd_reset:
	;call	sd_boot
	call	.sd_clk_dly

	call    sd_cmd0

	ld      de,.sd_scratch
	call    sd_cmd8

	;ld      de,.sd_scratch
	;call    sd_cmd58

	ld      b,0x20          ; limit the number of retries here
.sd_reset_ac41:
	push    bc
	ld      de,.sd_scratch
	call    sd_acmd41
	pop     bc
	or      a
	jr      z,.sd_reset_done
	djnz    .sd_reset_ac41

	call	iputs
	db	"SD_RESET FAILED!\r\n\0"
	ld	a,0x01
	ret

.sd_reset_done:
	ld      de,.sd_scratch
	call    sd_cmd58
	xor	a
	ret

;############################################################################
; A hack to just supply clock for a while.
;############################################################################
.sd_clk_dly:
	push	de
	push	hl
	ld	hl,0x80
.sd_clk_dly1:
	call	spi_read8
	dec	hl
	ld	a,h
	or	l
	jr	nz,.sd_clk_dly1
	pop	hl
	pop	de
	ret
	

;############################################################################
; CMD17 (READ_SINGLE_BLOCK)
;
; Read one block given by the 32-bit (little endian) number at 
; the top of the stack into the buffer given by address in DE.
;
; - set SSEL = true
; - send command
; - read for CMD ACK
; - wait for 'data token'
; - read data block
; - read data CRC
; - set SSEL = false
;
; A = 0 if the read operation was successful. Else A=1
; Clobbers A, IX
;############################################################################
.sd_debug_cmd17: equ	.sd_debug

sd_cmd17:
					; +10 = &block_number
					; +8 = return @
	push	bc			; +6
	push	hl			; +4
	push	iy			; +2
	push	de			; +0 target buffer address

	ld	iy,.sd_scratch		; iy = buffer to format command
	ld	ix,10			; 10 is the offset from sp to the location of the block number
	add	ix,sp			; ix = address of uint32_t sd_lba_block number

	ld	(iy+0),17|0x40		; the command byte
	ld	a,(ix+3)		; stack = little endian
	ld	(iy+1),a		; cmd_buffer = big endian
	ld	a,(ix+2)
	ld	(iy+2),a
	ld	a,(ix+1)
	ld	(iy+3),a
	ld	a,(ix+0)
	ld	(iy+4),a
	ld	(iy+5),0x00|0x01	; the CRC byte

if .sd_debug_cmd17
	; print the comand buffer
	call	iputs
	db	'CMD17: \0'
	push	iy
	pop	hl			; HL = IY = cmd_buffer address
	ld	bc,6			; B = command buffer length
	ld	e,0
	call	hexdump

	; print the target address
	call	iputs
	db	'  Target: \0'

	pop	de			; restore DE = target buffer address
	push	de			; and keep it on the stack too

	ld	a,d
	call	hexdump_a
	ld	a,e
	call	hexdump_a
	call	puts_crlf
endif

	; assert the SSEL line
	call    spi_ssel_true

	; send the command 
	push	iy
	pop	hl			; HL = IY = cmd_buffer address
	ld	b,6			; B = command buffer length
	call    spi_write_str		; clobbers A, BC, D, HL

	; read the R1 response message
	call    .sd_read_r1		; clobbers A, B, DE

if .sd_debug_cmd17
	push	af
	call	iputs
	db	'  R1: \0'
	pop	af
	push	af
	call	hexdump_a
	call	puts_crlf
	pop	af
endif

	; If R1 status != SD_READY (0x00) then error (SD spec p265, Section 7.2.3)
	or	a			; if (a == 0x00) then is OK
	jr	z,.sd_cmd17_r1ok

	; print the R1 status byte
	push	af
	call	iputs
	db	"\r\nSD CMD17 R1 error = 0x\0"
	pop	af
	call	hexdump_a
	call	puts_crlf

	jp	.sd_cmd17_err


.sd_cmd17_r1ok:

	; read and toss bytes while waiting for the data token
	ld      bc,0x1000		; expect to wait a while for a reply
.sd_cmd17_loop:
	call    spi_read8		; (clobbers A, DE)
	cp	0xff			; if a=0xff then command is not yet completed
	jr      nz,.sd_cmd17_token
	dec	bc
	ld	a,b
	or	c
	jr	nz,.sd_cmd17_loop

	call	iputs
	db	"SD CMD17 data timeout\r\n\0"
	jp	.sd_cmd17_err		; no flag ever arrived

.sd_cmd17_token:
	cp	0xfe			; A = data block token? (else is junk from the SD)
	jr	z,.sd_cmd17_tokok

	push	af
	call	iputs
	db	"SD CMD17 invalid response token: 0x\0"
	pop	af
	call	hexdump_a
	call	iputs
	db	"\r\n\0"
	jp	.sd_cmd17_err

.sd_cmd17_tokok:
	pop	hl			; HL = target buffer address
	push	hl			; and keep the stack level the same
	ld	bc,0x200		; 512 bytes to read
.sd_cmd17_blk:
	call	spi_read8		; Clobbers A, DE
	ld	(hl),a
	inc	hl			; increment the buffer pointer
	dec	bc			; decrement the byte counter

if .sd_debug_cmd17
	; A VERY verbose dump of every byte as they are read in from the card
	push	bc
	call	hexdump_a
	ld	c,' '
	call	con_tx_char
	pop	bc
	push	bc
	ld	a,c			; if %16 then 
	and	0x0f		
	jr	nz,.sd_cmd17_dsp
	ld	c,'\r';
	call	con_tx_char
	ld	c,'\n'
	call	con_tx_char
.sd_cmd17_dsp:
	pop	bc
endif

	ld	a,b			; did BC reach zero?
	or	c
	jr	nz,.sd_cmd17_blk	; if not, go back & read another byte

	call	spi_read8		; read the CRC value (XXX should check this)
	call	spi_read8		; read the CRC value (XXX should check this)

	call    spi_ssel_false
	xor	a			; A = 0 = success!

.sd_cmd17_done:
	pop	de
	pop	iy
	pop	hl
	pop	bc
	ret

.sd_cmd17_err:
	call	spi_ssel_false

	ld	a,0x01		; return an error flag
	jr	.sd_cmd17_done


;############################################################################
; CMD24 (WRITE_BLOCK)
;
; Write one block given by the 32-bit (little endian) number at 
; the top of the stack from the buffer given by address in DE.
;
; - set SSEL = true
; - send command
; - read for CMD ACK
; - send 'data token'
; - write data block
; - wait while busy 
; - read 'data response token' (must be 0bxxx00101 else errors) (see SD spec: 7.3.3.1, p281)
; - set SSEL = false
;
; - set SSEL = true		
; - wait while busy		Wait for the write operation to complete.
; - set SSEL = false
;
; XXX This /should/ check to see if the block address was valid 
; and that there was no write protect error by sending a CMD13
; after the long busy wait has completed.
;
; A = 0 if the write operation was successful. Else A = 1.
; Clobbers A, IX
;############################################################################
.sd_debug_cmd24: equ	.sd_debug

sd_cmd24:
					; +10 = &block_number
					; +8 = return @
	push	bc			; +6
	push	de			; +4 target buffer address
	push	hl			; +2
	push	iy			; +0

	ld	iy,.sd_scratch		; iy = buffer to format command
	ld	ix,10			; 10 is the offset from sp to the location of the block number
	add	ix,sp			; ix = address of uint32_t sd_lba_block number

.sd_cmd24_len: equ	6

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

if .sd_debug_cmd24
	push	de
	; print the command buffer
	call	iputs
	db	"  CMD24: \0"
	push	iy
	pop	hl			; hl = &cmd_buffer
	ld	bc,.sd_cmd24_len
	ld	e,0
	call	hexdump

	; print the target address
	call	iputs
	db	"  CMD24: source: \0"
	ld	a,(ix-5)
	call	hexdump_a
	ld	a,(ix-6)
	call	hexdump_a
	call	puts_crlf
	pop	de
endif

	; assert the SSEL line
	call    spi_ssel_true

	; send the command 
	push	iy
	pop	hl			; hl = iy = &cmd_buffer
	ld	b,.sd_cmd24_len
	call	spi_write_str		; clobbers A, BC, D, HL

	; read the R1 response message
	call    .sd_read_r1		; clobbers A, B, DE

	; If R1 status != SD_READY (0x00) then error
	or	a			; if (a == 0x00) 
	jr	z,.sd_cmd24_r1ok	; then OK
					; else error...

	push	af
	call	iputs
	db	"SD CMD24 status = \0"
	pop	af
	call	hexdump_a
	call	iputs
	db	" != SD_READY\r\n\0"
	jp	.sd_cmd24_err		; then error


.sd_cmd24_r1ok:
	; give the SD card an extra 8 clocks before we send the start token
	call	spi_read8

	; send the start token: 0xfe
	ld	c,0xfe
	call	spi_write8		; clobbers A and D

	; send 512 bytes

	ld	l,(ix-6)		; HL = source buffer address
	ld	h,(ix-5)
	ld	bc,0x200		; BC = 512 bytes to write
.sd_cmd24_blk:
	push	bc			; XXX speed this up
	ld	c,(hl)
	call	spi_write8		; Clobbers A and D
	inc	hl
	pop	bc			; XXX speed this up
	dec	bc
	ld	a,b
	or	c
	jr	nz,.sd_cmd24_blk

	; read for up to 250msec waiting on a completion status

	ld	bc,0xf000		; wait a potentially /long/ time for the write to complete
.sd_cmd24_wdr:				; wait for data response message
	call	spi_read8		; clobber A, DE
	cp	0xff
	jr	nz,.sd_cmd24_drc
	dec	bc
	ld	a,b
	or	c
	jr	nz,.sd_cmd24_wdr

	call    iputs
	db	"SD CMD24 completion status timeout!\r\n\0"
	jp	.sd_cmd24_err	; timed out


.sd_cmd24_drc:
	; Make sure the response is 0bxxx00101 else is an error
	and	0x1f
	cp	0x05
	jr	z,.sd_cmd24_ok


	push	bc
	call	iputs
	db	"ERROR: SD CMD24 completion status != 0x05 (count=\0"
	pop	bc
	push	bc
	ld	a,b
	call	hexdump_a
	pop	bc
	ld	a,c
	call	hexdump_a
	call	iputs
	db	")\r\n\0"

	jp	.sd_cmd24_err

.sd_cmd24_ok:
	call	spi_ssel_false


if 1
	; Wait until the card reports that it is not busy
	call	spi_ssel_true

.sd_cmd24_busy:
	call	spi_read8		; clobber A, DE
	cp	0xff
	jr	nz,.sd_cmd24_busy

	call	spi_ssel_false
endif
	xor	a			; A = 0 = success!

.sd_cmd24_done:
	pop	iy
	pop	hl
	pop	de
	pop	bc
	ret

.sd_cmd24_err:
    call    spi_ssel_false

if .sd_debug_cmd24
	call	iputs
	db	"SD CMD24 write failed!\r\n\0"
endif

	ld	a,0x01		; return an error flag
	jr	.sd_cmd24_done



;############################################################################
; A buffer for exchanging messages with the SD card.
;############################################################################
.sd_scratch:
	ds	6
