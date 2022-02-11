;****************************************************************************
;
;    Copyright (C) 2021,2022 John Winans
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

debug:		equ	0		; Set to 1 to show debug printing, else 0 

include	'io.asm'

stacktop:	equ	0

	org		0x0000		; Cold reset Z80 entry point.

	;###################################################
	; NOTE THAT THE SRAM IS NOT READABLE AT THIS POINT
	;###################################################

	; Select SRAM low bank 0, idle the SD card, and idle printer signals
	ld	a,(gpio_out_cache)
	out	(gpio_out),a

	; Copy the FLASH into the SRAM by reading every byte and 
	; writing it back into the same address.
	ld	hl,0
	ld	de,0
	ld	bc,_end
	ldir				; Copy all the code in the FLASH into RAM at same address.

	; Disable the FLASH and run from SRAM only from this point on.
	in	a,(flash_disable)	; Dummy-read this port to disable the FLASH.

	;###################################################
	; STARTING HERE, WE ARE RUNNING FROM RAM
	;###################################################

	ld	sp,stacktop

	; Initialize the CTC so that the SIO will have a baud clock if J11-A is set to the CTC!
	;ld	c,1			; 115200 bps
	ld	c,6			; 19200 bps
	call	init_ctc_1

	; Init the SIO to run at 115200 or 19200 depending on J11-A
	call	sioa_init

	; Display a startup message
	ld	hl,boot_msg
	call	puts
	call	puts_crlf

	;call	test_80clks		; test the CLK signal
	;call	test_ssel		; test the ssel & CLK logic
	;call	test_bits		; test simple MOSI bit patterns
	;call	test_read		; test MISO bit patterns

	;call	test_80clks		; required prior to a CMD0
	;call	test_cmd0		; see if we can wake up an SD card

	call	iputs
	db	'\r\n\nTests done\r\n\0'

	; Spin loop here because there is nothing else to do
halt_loop:
	halt
	jp	halt_loop


boot_msg:
	defb    '\r\n\n'
	defb	'##############################################################################\r\n'
	defb	'Z80 Retro Board 2063.3\r\n'
	defb	'      git: @@GIT_VERSION@@\r\n'
	defb	'    build: @@DATE@@\r\n'
	defb	'\r\n'
	defb	'I/O library tester.\r\n'
	defb	'\0'


;##############################################################################
; Tick the clock 80 times
;##############################################################################
test_80clks:
	ld	b,10			; 10 8-bit clock bursts
test_80clks_loop:
	call	spi_read8		; read and discard 8 bits with MOSI high
	djnz	test_80clks_loop	; if more to do, keep going
	ret



;##############################################################################
; Test the spi_ssel_true and spi_ssel_false routines
;##############################################################################
test_ssel:
	call	iputs
	db	'test_ssel\r\n\0'

	call	spi_ssel_true		; 8-clk, SSEL=0, 8-clk
	call	spi_ssel_false		; 8-clk, SSEL=1, 16-clk
	ret


;##############################################################################
; Test writing of data bit patterns.
;##############################################################################
test_bits:
	call	iputs
	db	'test_bits\r\n\0'

	ld	hl,bit_test1		; buffer address
	ld	bc,4			; buffer size
	ld	e,0			; no fancy formatting
	call	hexdump			; dump the buffer in hex

	call	spi_ssel_true		; 8-clk, SSEL=0, 8-clk

	ld	hl,bit_test1
	ld	b,4
	call	spi_write_str		; write 4 bytes

	call	spi_ssel_false		; 8-clk, SSEL=1, 16-clk
	ret

bit_test1:
	db	0x01,0x02,0x80,0x40


;##############################################################################
; Test reading a byte.
;##############################################################################
test_read:
	call	iputs
	db	'test_read\r\n\0'

	call	iputs
	db	'A=0x\0'

	call	spi_read8		; read 8 bits into A

	call	hexdump_a
	call	puts_crlf

	ret



;##############################################################################
; Test an SD CMD0
; This command puts the SD card into SPI mode and goes into an idle state.
;##############################################################################
test_cmd0:
	call	iputs
	db	'test_cmd0\r\n\0'

	call	spi_ssel_true		; 8-clk, SSEL=0, 8-clk
	
	call	iputs
	db	'CMD0=\0'
	ld	hl,test_cmd0_msg	; buffer to dump
	ld	bc,6			; buffer length
	ld	e,0			; no fancy formatting
	call	hexdump

	; Send a CMD0 message
	ld	hl,test_cmd0_msg
	ld	b,6
	call	spi_write_str		; write 4 bytes

	ld	b,0xf0			; might need to read multiple bytes before SD replies 
test_cmd0_loop:
	push	bc			; save the retry counter value

	call	iputs
	db	'R1=\0'

	; Read a R1 response message
	call	spi_read8		; read the 1 byte R1 response message into A

	push	af			; save the response byte
	call	hexdump_a
	call	puts_crlf
	pop	af			; restore the R1 response byte
	pop	bc			; restore the retry counter

	cp	0x01			; is the R1 response 0x01?
	jr	z,test_cmd0_success	; yes -> success

	djnz	test_cmd0_loop		; R1 response is bad keep reading until B is zero 

	; max retries exceeded, bail out
	call	iputs
	db	'CMD0 failed after max retries!\r\n\0'
	jp	test_cmd0_done

test_cmd0_success:
	call	iputs
	db	'CMD0 success!\r\n\0'

test_cmd0_done:
	call	spi_ssel_false		; 8-clk, SSEL=1, 16-clk

	ret


; See page 265 of 'SD Physical Layer Simplified Specification Version 8.00'
; This command MUST have a valid CRC.  Subsequent ones in SPI mode need not.
test_cmd0_msg:
	db	0x40,0x0,0x0,0x0,0x0,0x95





include	'spi.asm'
include	'hexdump.asm'
include 'sio.asm'
include 'ctc1.asm'
include 'puts.asm'

;##############################################################################
; This is a cache of the last written data to the gpio_out port.
; The initial value here is what is written to the latch during startup.
;##############################################################################
gpio_out_cache:	db	gpio_out_sd_mosi|gpio_out_sd_ssel|gpio_out_prn_stb


;##############################################################################
; This marks the end of the data copied from FLASH into RAM during boot
;##############################################################################
_end:		equ	$
