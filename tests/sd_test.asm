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

;############################################################################
;
; Test app for the sdcard driver.
;
; Read the data from the SD raw block 0 (where an MBR would normally 
; be present) into RAM starting at address 'LOAD_BASE', dump it out
; and then branch into it to execute it.
;
;############################################################################

.debug:	equ	1		; Set to 1 to show debug printing, else 0 


include	'io.asm'
include	'memory.asm'

.stacktop: equ	LOAD_BASE	; So the SD loader does not overwrite!


	org	0x0000			; Cold reset Z80 entry point.

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
	ld	bc,.end
	ldir				; Copy all the code in the FLASH into RAM at same address.

	; Disable the FLASH and run from SRAM only from this point on.
	in	a,(flash_disable)	; Dummy-read this port to disable the FLASH.

	;###################################################
	; STARTING HERE, WE ARE RUNNING FROM RAM
	;###################################################

	ld	sp,.stacktop

	; Initialize the CTC so that the SIO will have a custom baud clock if J11-A is set to the CTC!
	;ld	c,1			; 115200 bps
	;ld	c,6			; 19200 bps
	ld	c,12			; 9600 bps
	call	init_ctc_1

	; Init the SIO to run at 115200 or at the CTC rate depending on J11-A
	call	sioa_init

	; Display a hello world message.
	ld	hl,.boot_msg
	call	puts

	; Load bootstrap code from the SD card.
	call	.test_sd

	call	iputs
	db	'SYSTEM LOAD FAILED! HALTING.\r\n\0'

	; Spin loop here because there is nothing else to do
.halt_loop:
	halt
	jp	.halt_loop


.boot_msg:
	db	'\r\n\n'
	db	'##############################################################################\r\n'
	db	'Z80 Retro Board 2063.3 -- sd_test.asm\r\n'
	db	'      git: @@GIT_VERSION@@\r\n'
	db	'    build: @@DATE@@\r\n'
	db	'\0'




;##############################################################################
; Initialize the SD card and load the first block on the SD card into 
; memory starting at 'LOAD_BASE' and then jump to it.
; If any SD card commands should fail then this function will return.
;##############################################################################
.test_sd:
	call	iputs
	db	'\r\nReading SD card block zero\r\n\n\0'

	call	sd_boot		; transmit 74+ CLKs

	; The response byte should be 0x01 (idle) from cmd0
	call	sd_cmd0
	cp	0x01
	jr	z,.boot_sd_1

	call	iputs
	db	'Error: Can not read SD card (cmd0 command status not idle)\r\n\0'
	ret

.boot_sd_1:
	ld	de,LOAD_BASE	; Use the load area for a temporary buffer
	call	sd_cmd8		; CMD8 is sent to verify that we have a Version 2+ SD card
				; and agree on the operating voltage.
				; CMD8 also expands the functionality of CMD58 and ACMD41

	; The response should be: 0x01 0x00 0x00 0x01 0xAA.
	ld	a,(LOAD_BASE)
	cp	1
	jr	z,.boot_sd_2

	call	iputs
	db	'Error: Can not read SD card (cmd8 command status not valid):\r\n\0'

	; dump the command response buffer
	ld	hl,LOAD_BASE	; dump bytes from here
	ld	e,0		; no fancy formatting
	ld	bc,5		; dump 5 bytes
	call	hexdump
	call	puts_crlf

	ret


.boot_sd_2:

; After power cycle, card is in 3.3V signaling mode.  We do not intend 
; to change it nor we we care about what other options may be available.
; Therefore the CMD58 does not appear to serve any a purpose at this time. 
;	ld	de,LOAD_BASE
;	call	sd_cmd58		; cmd58 = read OCR (operation conditions register)

.ac41_max_retry: equ	0x80		; limit the number of ACMD41 retries to 128

	ld	b,.ac41_max_retry
.ac41_loop:
	push	bc			; save BC since B contains the retry count 
	ld	de,LOAD_BASE		; store command response into LOAD_BASE
	call	sd_acmd41		; ask if the card is ready
	pop	bc			; restore our retry counter
	or	a			; check to see if A is zero
	jr	z,.ac41_done		; is A is zero, then the card is ready

	; Card is not ready, waste some time before trying again
	ld	hl,0x1000		; count to 0x1000 to consume time
.ac41_dly:
	dec	hl			; HL = HL -1
	ld	a,h			; does HL == 0?
	or	l
	jr	nz,.ac41_dly		; if HL != 0 then keep counting

	djnz	.ac41_loop		; if (--retries != 0) then try again

.ac41_fail:
	call	iputs
	db	'Error: Can not read SD card (ac41 command failed)\r\n\0'
	ret

.ac41_done:
if .debug
	call	iputs
	db	'** Note: Called ACMD41 0x\0'
	ld	a,.ac41_max_retry
	sub	b
	inc	a			; account for b not yet decremented on last time
	call	hexdump_a
	call	iputs
	db	' times.\r\n\0'
endif

	; Find out the card capacity (SDHC or SDXC)
	; This status is not valid until after ACMD41.
	ld	de,LOAD_BASE
	call	sd_cmd58

if .debug
	call	iputs
	db	'** Note: Called CMD58: R3: \0'
	ld	hl,LOAD_BASE
	ld	bc,5
	ld	e,0
	call	hexdump			; dump the response message from CMD58
endif

	; Check that CCS=1 here to indicate that we have an HC/XC card
	ld	a,(LOAD_BASE+1)
	and	0x40			; CCS bit is here (See SD spec p275)
	jr	nz,.boot_hcxc_ok

	call	iputs
	db	'Error: SD card capacity is not SDHC or SDXC.\r\n\0'
	ret


.boot_hcxc_ok:
	; ############ Read block number zero into memory at 'LOAD_BASE' ############

	; push the starting block number onto the stack in little-endian order
	ld	hl,0			; SD card block number to read
	push	hl			; high half
	push	hl			; low half
	ld	de,LOAD_BASE		; where to read the sector data into
	call	sd_cmd17
	pop	hl			; remove the block number from the stack
	pop	hl

	or	a
	jr	z,.boot_cmd17_ok	; if CMD17 ended OK then run the code

	call	iputs
	db	'Error: SD card CMD17 failed to read block zero.\r\n\0'
	ret

.boot_cmd17_ok:

if .debug
	call	iputs
	db	'The block has been read!\r\n\0'

	ld	hl,LOAD_BASE		; Dump the block we read from the SD card
	ld	bc,0x200		; 512 bytes to dump
	ld	e,1			; and make it all all purdy like
	call	hexdump
endif

	jp	LOAD_BASE		; Go execute what ever came from the SD card



include	'sdcard.asm'
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
.end:	equ	$
