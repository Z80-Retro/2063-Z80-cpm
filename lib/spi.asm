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

;############################################################################
; An SD card library.
;
; SD cards are 3.3v ONLY!
; Must provide a pull up on MISO.
;
; SD cards operate on SPI mode 0.
; Data changes on falling CLK edge & sampled on rising CLK edge:
;        __                               ___
; /SSEL    \_____________________________/      Host --> SD
;        _____    __    __    __    _________
; CLK         \__/  \__/  \__/  \__/            Host --> SD
;        _____ _____ _____ _____ _____ ______
; MOSI        \_____X_____X_____X_____/         Host --> SD
;        _____ _____ _____ _____ _____ ______
; MISO        \_____X_____X_____X_____/         Host <-- SD
;
; Use partition type 0x7F (reserved for experimental projects)?
;############################################################################

;############################################################################
; Write 8 bits in C to the SDCARD and discard the received data.
; Clobbers: A, D
;############################################################################
write1:	macro	bitpos
	ld	a,d			; a = gpio_out value w/CLK & MOSI = 0
	bit	bitpos,c		; [8] is the bit of C a 1?
	jr	z,.lo_bit		; [7/12] (transmit a 0)
	or	gpio_out_sd_mosi	; [7] prepare to transmit a 1 (only [4] if mask is in a reg)
.lo_bit: ds 0				; for some reason, these labels disappear if there is no neumonic
	out	(gpio_out),a		; set data value & CLK falling edge
	or	gpio_out_sd_clk		; set the CLK bit
	out	(gpio_out),a		; CLK rising edge
	endm

spi_write8:
	ld	a,(gpio_out_cache)	; get current gpio_out value
	and	0+~(gpio_out_sd_mosi|gpio_out_sd_clk)	; MOSI & CLK = 0
	ld	d,a			; save in D for reuse

	;--------- bit 7
	; special case for the first bit (a already has the gpio_out value)
	bit	7,c
	jr	z,lo7
	or	gpio_out_sd_mosi
lo7:
	out	(gpio_out),a		; set data value & CLK falling edge
	or	gpio_out_sd_clk		; set the CLK bit
	out	(gpio_out),a		; CLK rising edge

	write1	6
	write1	5
	write1	4
	write1	3
	write1	2
	write1	1
	write1	0

	ret

;############################################################################
; Read 8 bits from the SPI & return it in A
; Clobbers D and E
;############################################################################
read1:	macro
	ld	a,d
	out	(gpio_out),a		; set data value & CLK falling edge
	or	gpio_out_sd_clk		; set the CLK bit
	out	(gpio_out),a		; CLK rising edge

	in	a,(gpio_in)		; read MISO
	and	gpio_in_sd_miso
	or	e
	rlca
	ld	e,a
	endm

;XXX consider moving this per-byte overhead into the caller????    XXX

spi_read8:
	ld	e,0					; E = 0

	ld	a,(gpio_out_cache)	; get current gpio_out value
	and	~gpio_out_sd_clk	; CLK = 0
	or	gpio_out_sd_mosi	; MOSI = 1
	ld	d,a			; save in D for reuse

	read1	;7
	read1	;6
	read1	;5
	read1	;4
	read1	;3
	read1	;2
	read1	;1
	read1	;0

	ret

;##############################################################
; Assert the select line (set it low)
; Clobbers A
;##############################################################
spi_ssel_true:
	push	bc
	push	de

	; send in a byte of 'nothing'
	ld      c,0xff
	call    spi_write8

	ld	a,(gpio_out_cache)

	; make sure the clock is low before we enable the card
	and	~gpio_out_sd_clk		; CLK = 0
	or	gpio_out_sd_mosi		; MOSI = 1
	out	(gpio_out),a

	; enable the card
	and	~gpio_out_sd_ssel		; SSEL = 0
	ld	(gpio_out_cache),a
	out	(gpio_out),a

	; send in a byte of 'nothing'	
	ld      c,0xff
	call    spi_write8

	pop	de
	pop	bc
	ret

;##############################################################
; de-assert the select line (set it high)
; Clobbers A
;
; See section 4 of 
;	Physical Layer Simplified Specification Version 8.00
;##############################################################
spi_ssel_false:
	push	de

	; send in a byte of 'nothing'	
	call	spi_read8

	ld	a,(gpio_out_cache)

	; make sure the clock is low before we disable the card
	and	~gpio_out_sd_clk			; CLK = 0
	out	(gpio_out),a

	or	gpio_out_sd_ssel|gpio_out_sd_mosi	; SSEL=1, MOSI=1
	ld	(gpio_out_cache),a
	out	(gpio_out),a

	; send two bytes of 'nothing'	
	call	spi_read8
	call	spi_read8

	pop	de
	ret


if 0
;##############################################################
; Write the message from address in HL register for length in BC to the SPI port.
; Save the returned data into the address in the DE register
;##############################################################
spi_write:
	call	spi_ssel_true

spi_write_loop:
	ld	a,b
	or	c
	jp	z,spi_write_done
	push	bc
	ld	c,(hl)
	call	spi_write8
	inc	hl
	pop	bc
	dec	bc
	jp	spi_write_loop

spi_write_done:
	call	spi_ssel_false

	ret
endif


;##############################################################
; HL = @ of bytes to write 
; B = byte count
; clobbers: A, BC, D, HL
;##############################################################
spi_write_str:
	ld	c,(hl)
	call	spi_write8
	inc	hl
	djnz	spi_write_str
	ret

