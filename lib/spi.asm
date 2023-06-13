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
; An SPI library suitable for tallking to SD cards.
;
; This library implements SPI mode 0 (SD cards operate on SPI mode 0.)
; Data changes on falling CLK edge & sampled on rising CLK edge:
;        __                                             ___
; /SSEL    \______________________ ... ________________/      Host --> Device
;                 __    __    __   ... _    __    __
; CLK    ________/  \__/  \__/  \__     \__/  \__/  \______   Host --> Device
;        _____ _____ _____ _____ _     _ _____ _____ ______
; MOSI        \_____X_____X_____X_ ... _X_____X_____/         Host --> Device
;        _____ _____ _____ _____ _     _ _____ _____ ______
; MISO        \_____X_____X_____X_ ... _X_____X_____/         Host <-- Device
;
;############################################################################

;############################################################################
; Write 8 bits in C to the SPI port and discard the received data.
; It is assumed that the gpio_out_cache value matches the current state
; of the GP Output port and that SSEL is low.
; This will leave: CLK=1, MOSI=(the LSB of the byte written)
; Clobbers: A, D
; Refactored by Tim Gordon and Trevor Jacobs 06-02-2023 
;############################################################################

;If shifting carry into a's lsb by using "adc b":
spi_write1: macro
		ld a, d			; Restore gpio port bits ready for clock and data 4
		rl c			; Isolate next data bit 8
		adc a,l                 ; Put data bit into lsb by adding 0 with carry. Do it fast by storing 0 in reg l 4
		out (gpio_out), a	; Drive MOSI and CLK signal onto SPI bus 11
		or h			; Set CLK high.  Do it fast by ORing reg 4
		out (gpio_out), a	; Drive MOSI and other CLK edge	11
	endm
;T: 42 clocks/bit = 33.6us/byte + overhead (24% improvement)
;NOTE: must preload reg l with 0 and h with gpio_out_sd_clk

spi_write8:
	push hl				; Do expensive push in order to realize fast register usage 11
	
	ld h, gpio_out_sd_clk		; Initialize CLK bit mask 7
	ld l, 0				; Initialize for fast data bit set 7

	;di				; Start of critical section
	
	ld a,(gpio_out_cache)		; Get current gpio_out value 13
	and	0+~(gpio_out_sd_mosi|gpio_out_sd_clk)	; Set MOSI & CLK = 0 7
	ld d, a						; Save in register for reuse each bit 4
	
	spi_write1 ;7 42
	spi_write1 ;6
	spi_write1 ;5
	spi_write1 ;4
	spi_write1 ;3
	spi_write1 ;2
	spi_write1 ;1
	spi_write1 ;0
	
	;ei				; End of critical section

	pop hl                          ; 10
       
	ret				; 10
;T: 69+42*8 = 405 cycles/byte = 40.5us/byte = ~24.7kB/s

;############################################################################
; Read 8 bits from the SPI & return it in A.
; MOSI will be set to 1 during all bit transfers.
; This will leave: CLK=1, MOSI=1
; Clobbers A, D and E
; Returns the byte read in the A (and a copy of it also in E)
; Refactored by Tim Gordon and Trevor Jacobs 06-02-2023 
;############################################################################

;Using precalculated bit patterns for gpio_out (I saw PoE do this):
spi_read1: macro
	out	(c), h			; Drive MOSI high and CLK low.  Do it fast by using register 12
	out	(c), l			; Drive MOSI HIGH and CLK high 12
	in	a, (gpio_in)		; Read MISO (in bit 7) 11
	rla					; Put MISO value in carry 4
	rl e				; Shift carry (= MISO bit) into bit 0 of reg e 8
	endm
;T: 47 clocks/bit = 37.6us/byte (~30% improvement)
;NOTE: Must preload b and c registers with gpio_out_cache and correct MISO and CLK levels (and make sure this doesn't affect spi_read call)
;NOTE: There's no reason to even initialize the e register because 8 left rotates will leave all bits updated correctly

spi_read8:
	push hl
	push bc				; Push unclobbered registers onto stack.  Slow operation in order to accelerate bit code 22

	ld c, gpio_out			; Load gpio port address into c reg 7
	ld e, 0				; Prepare to accumulate the bits into e reg 7
	
	;di				; Start of critical section
	
	ld	a, (gpio_out_cache)	; Get current gpio_out value 13
	and	~gpio_out_sd_clk	; Clear CLK bit	7
	or	gpio_out_sd_mosi	; Set MOSI bit 7
	ld h, a				; Store for fast use 4
	or	gpio_out_sd_clk		; Set CLK bit 7
	ld l, a				; Store for fast use 4
	
	spi_read1 ;7		        ; Read the 8 bits 51
	spi_read1 ;6
	spi_read1 ;5
	spi_read1 ;4
	spi_read1 ;3
	spi_read1 ;2
	spi_read1 ;1
	spi_read1 ;0

	;ei				; End of critical section
	
	ld a, e				; Final transfer accumulated byte to a reg 4
					; The final value will be in both the E and A registers
	pop bc				; 20
	pop hl
	
	ret				; 10

;T: 108+47*8 = 484 cycles/byte = 48.4us/byte = ~20.7kB/s

;##############################################################
; Assert the select line (set it low)
; This will leave: SSEL=0, CLK=0, MOSI=1
; Clobbers A
;##############################################################
spi_ssel_true:
	push	de

	; read and discard a byte to generate 8 clk cycles
	call	spi_read8

	ld	a,(gpio_out_cache)

	; make sure the clock is low before we enable the card
	and	~gpio_out_sd_clk		; CLK = 0
	or	gpio_out_sd_mosi		; MOSI = 1
	out	(gpio_out),a

	; enable the card
	and	~gpio_out_sd_ssel		; SSEL = 0
	ld	(gpio_out_cache),a		; save current state in the cache
	out	(gpio_out),a

	; generate another 8 clk cycles
	call	spi_read8

	pop	de
	ret

;##############################################################
; de-assert the select line (set it high)
; This will leave: SSEL=1, CLK=0, MOSI=1
; Clobbers A
;
; See section 4 of 
;	Physical Layer Simplified Specification Version 8.00
;##############################################################
spi_ssel_false:
	push	de		; save DE because read8 alters it

	; read and discard a byte to generate 8 clk cycles
	call	spi_read8

	ld	a,(gpio_out_cache)

	; make sure the clock is low before we disable the card
	and	~gpio_out_sd_clk			; CLK = 0
	out	(gpio_out),a

	or	gpio_out_sd_ssel|gpio_out_sd_mosi	; SSEL=1, MOSI=1
	ld	(gpio_out_cache),a
	out	(gpio_out),a

	; generate another 16 clk cycles
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
	ld	c,(hl)		; get next byte to send
	call	spi_write8	; send it
	inc	hl		; point to the next byte
	djnz	spi_write_str	; count the byte & continue of not done
	ret

