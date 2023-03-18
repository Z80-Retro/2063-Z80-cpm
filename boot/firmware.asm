;****************************************************************************
;
;    Copyright (C) 2021,2022,2023 John Winans
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
;
; Boot flash versions:
;
; This code will enter the loaded application with a value in the A register 
; that indicates the version of the FLASH code:
;
; A = 0 Code was loaded from the SD card starting from the first partition.
;       The code read from the SD card will be placed into RAM at LOAD_BASE.
;       The first partition is assumed to begin at SD block number 0x800.
;
; A = 1 Code was loaded from the SD card starting from the indicated partition.
;       The code read from the SD card will be placed into RAM at LOAD_BASE.
;       The booted partition number will be stored in the C register.
;	C=1: first partition, C=2: second,...
;       The booted partition starting SD block number will be stored into
;       the DE and HL pairs.  DE = the high 16 and HL = the low 16 bits.
;
;****************************************************************************

.boot_rom_version:	equ	1

.debug:		equ	0		; Set to 1 to show debug printing, else 0 

include	'io.asm'
include	'memory.asm'

.load_blks:	equ	(0x10000-LOAD_BASE)/512
.stacktop:	equ	LOAD_BASE	; (so the SD loader does not overwrite)

	org		0x0000		; Cold reset Z80 entry point.

	;###################################################
	; NOTE THAT THE SRAM IS NOT READABLE AT THIS POINT
	;###################################################

	; Select SRAM low bank 14, idle the SD card, and idle printer signals
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

	; Initialize the CTC so that the SIO will have a baud clock if J11-A is set to the CTC!
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
	call	.boot_sd

	call	iputs
	db	'SYSTEM LOAD FAILED! HALTING.\r\n\0'

	; Spin loop here because there is nothing else to do
.halt_loop:
	halt
	jp	.halt_loop

.boot_msg:
	db	'\r\n\n'
	db	'##############################################################################\r\n'
	db	'Z80 Retro Board 2063.3\r\n'
	db	'      git: @@GIT_VERSION@@\r\n'
	db	'    build: @@DATE@@\r\n'
	db	'\0'

;##############################################################################
; Load 16K from the first blocks of partition 1 on the SD card into
; memory starting at 'LOAD_BASE' and jump to it.
; If reading the SD card should fail then this function will return.
;
; TODO: Sanity-check the partition type, size and design some sort of 
; signature that can be used to recognize the SD card partition as viable.
;##############################################################################
.boot_sd:
	call	iputs
	db	'\r\nBooting SD card partition 1\r\n\n\0'

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
; XXX I don't care what voltages are supported... I assume that 3.3v is fine.
;	ld	de,LOAD_BASE
;	call	sd_cmd58		; cmd58 = read OCR (operation conditions register)

.ac41_max_retry: equ	0x80		; limit the number of acmd41 retries

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
	ld	a,ac41_max_retry
	sub	b
	inc	a			; account for b not yet decremented on last time
	call	hexdump_a
	call	iputs
	db	' times.\r\n\0'
endif

	; Find out the card capacity (HC or XC)
	; This status is not valid until after ACMD41.
	ld	de,LOAD_BASE
	call	sd_cmd58

if .debug
	call	iputs
	db	'** Note: Called CMD58: R3: \0'
	ld	hl,LOAD_BASE
	ld	bc,5
	ld	e,0
	call	hexdump
endif

	; Check that CCS=1 here to indicate that we have an HC/XC card
	ld	a,(LOAD_BASE+1)
	and	0x40			; CCS bit is here (See spec p275)
	jr	nz,.boot_hcxc_ok

	call	iputs
	db	'Error: SD card capacity is not HC or XC.\r\n\0'
	ret


.boot_hcxc_ok:
	; ############ Read the MBR ############

	; push the starting block number onto the stack in little-endian order
	ld	hl,0			; SD card block number to read
	push	hl			; high half
	push	hl			; low half
	ld	de,LOAD_BASE		; where to read the sector data into
	call	sd_cmd17
	pop	hl			; remove the block number from the stack
	pop	hl

	or	a
	jr	z,.boot_cmd17_ok

	call	iputs
	db	'Error: SD card CMD17 failed to read block zero.\r\n\0'
	ret

.boot_cmd17_ok:
if 1 ;.debug
	call	iputs
	db	'Partition Table:\r\n\0'

	ld	hl,LOAD_BASE+0x01BE	; address of the first partiton entry
	ld	e,0			; no fancy formatting
	ld	bc,16			; dump 16 bytes
	call	hexdump
	ld	hl,LOAD_BASE+0x01CE	; address of the second partiton entry
	ld	e,0			; no fancy formatting
	ld	bc,16			; dump 16 bytes
	call	hexdump
	ld	hl,LOAD_BASE+0x01DE	; address of the third partiton entry
	ld	e,0			; no fancy formatting
	ld	bc,16			; dump 16 bytes
	call	hexdump
	ld	hl,LOAD_BASE+0x01EE	; address of the fourth partiton entry
	ld	e,0			; no fancy formatting
	ld	bc,16			; dump 16 bytes
	call	hexdump
endif

	; XXX validate that we really HAVE an MBR and that it looks OK to boot! XXX

	; Find the geometry of the first partition record:
	ld	ix,LOAD_BASE+0x01BE+0x08

	call	iputs
	db	'\nPartition 1 starting block number: \0'
	ld	a,(ix+3)
	call	hexdump_a
	ld	a,(ix+2)
	call	hexdump_a
	ld	a,(ix+1)
	call	hexdump_a
	ld	a,(ix+0)
	call	hexdump_a
	call	puts_crlf

	call	iputs
	db	'Partition 1 number of blocks:      \0'
	ld	a,(ix+7)
	call	hexdump_a
	ld	a,(ix+6)
	call	hexdump_a
	ld	a,(ix+5)
	call	hexdump_a
	ld	a,(ix+4)
	call	hexdump_a
	call	puts_crlf


	; ############ Read the first sectors of the first partition ############
	ld	ix,LOAD_BASE+0x01BE+0x08
	ld	d,(ix+3)
	ld	e,(ix+2)
	push	de
	ld	d,(ix+1)
	ld	e,(ix+0)
	push	de

	ld	de,LOAD_BASE		; where to read the sector data into
	ld	b,.load_blks		; number of blocks to load (should be 32/16KB)

if 1
	; Print the details of what we are going to load and where it will go
	call	iputs
	db	'\nLoading 0x\0'
	ld	a,b
	call	hexdump_a
	call	iputs
	db	' 512-byte blocks into 0x\0'
	ld	a,d
	call	hexdump_a
	ld	a,e
	call	hexdump_a
	call	iputs
	db	' - 0x\0'

	; Calculate the ending address of the load area
	ld	hl,LOAD_BASE
	ld	a,.load_blks
	add	a
	ld	b,a
	ld	c,0
	dec	bc
	add	hl,bc
	ld	a,h
	call	hexdump_a
	ld	a,l
	call	hexdump_a
	call	puts_crlf

	; re-load these if the debug logic messed them up
	ld	de,LOAD_BASE		; where to read the sector data into
	ld	b,.load_blks		; number of blocks to load (should be 32/16KB)
endif

	call	read_blocks
	pop	hl			; Remove the 32-bit block number from the stack.
	pop	de

	ld	c,1			; XXX note we booted from partition #1

	or	a
	ld	a,.boot_rom_version
	jp	z,LOAD_BASE		; Run the code that we just read in from the SD card.

	call	iputs
	db	'Error: Could not load O/S from partition 1.\r\n\0'
	ret



;############################################################################
;### Read B number of blocks into memory at address DE starting with
;### 32-bit little-endian block number on the stack.
;### Return A=0 = success!
;############################################################################
read_blocks:
					; +12 = starting block number
					; +10 = return @
	push	bc			; +8
	push	de			; +6
	push	iy			; +4

	ld	iy,-4
	add	iy,sp			; iy = &block_number
	ld	sp,iy

	; copy the first block number 
	ld	a,(iy+12)
	ld	(iy+0),a
	ld	a,(iy+13)
	ld	(iy+1),a
	ld	a,(iy+14)
	ld	(iy+2),a
	ld	a,(iy+15)
	ld	(iy+3),a

	;call	spi_read8f_init for the 8f version of CMD17

.read_block_n:

if 1
	ld	c,'.'
	call	con_tx_char
endif

if 0
	call	iputs
	db	'Read Block: \0'

	ld	a,(iy+3)
	call	hexdump_a
	ld	a,(iy+2)
	call	hexdump_a
	ld	a,(iy+1)
	call	hexdump_a
	ld	a,(iy+0)
	call	hexdump_a
	call	puts_crlf
endif

	; SP is currently pointing at the block number
	call	sd_cmd17
	or	a
	jr	nz,.rb_fail

	; count the block
	dec	b
	jr	z,.rb_success		; note that a=0 here = success!

	; increment the target address by 512
	inc	d
	inc	d

	; increment the 32-bit block number
	inc	(iy+0)
	jr	nz,.read_block_n
	inc	(iy+1)
	jr	nz,.read_block_n
	inc	(iy+2)
	jr	nz,.read_block_n
	inc	(iy+3)
	jr	.read_block_n

.rb_success:
	xor	a

.rb_fail:
	ld	iy,4
	add	iy,sp
	ld	sp,iy
	pop	iy
	pop	de
	pop	bc
	ret


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
.low_bank:      equ     0x0e    ; The RAM BANK to use for the bottom 32K
gpio_out_cache:	db	gpio_out_sd_mosi|gpio_out_sd_ssel|gpio_out_prn_stb|gpio_out_sd_clk|(.low_bank<<4)


;##############################################################################
; This marks the end of the data copied from FLASH into RAM during boot
;##############################################################################
.end:		equ	$
