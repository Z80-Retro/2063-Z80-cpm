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

load_base:	equ	0xc000		; Where to load the boot image from the SD card.
load_blks:	equ	(0x10000-load_base)/512

stacktop:	equ	load_base	; (so the SD loader does not overwrite)

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

	; Display a hello world message.
	ld	hl,boot_msg
	call	puts

	; Load bootstrap code from the SD card.
	call	boot_sd

	ld	hl,done_msg
	call	puts

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
	defb	'\0'

done_msg:
	defb	'SYSTEM LOAD FAILED! HALTING.\r\n\0'



;##############################################################################
; Load 32K from the first blocks of partition 1 on the SD card into
; memory starting at 'load_base' and jump to it.
; If reading the SD card should fail then this function will return.
;##############################################################################
boot_sd:
	call	iputs
	db		'\r\nBooting SD card partition 1\r\n\n\0'

	call	sd_boot

	; The response byte should be 0x01 (idle) from cmd0
	call	sd_cmd0
	cp	0x01
	jr	z,boot_sd_1

	call	iputs
	db	'Error: Can not read SD card (cmd0 command status not idle)\r\n\0'
	ret

boot_sd_1:
	ld	de,load_base	; Use the load area for a temporary buffer
	call	sd_cmd8		; CMD8 is sent to verify that we have a Version 2+ SD card
				; and agree on the operating voltage.
				; CMD8 also expands the functionality of CMD58 and ACMD41

	; The response should be: 0x01 0x00 0x00 0x01 0xAA.
	ld	a,(load_base)
	cp	1
	jr	z,boot_sd_2

	call	iputs
	db	'Error: Can not read SD card (cmd8 command status not valid):\r\n\0'

	; dump the command response buffer
	ld	hl,load_base	; dump bytes from here
	ld	e,0		; no fancy formatting
	ld	bc,5		; dump 5 bytes
	call	hexdump
	call	puts_crlf

	ret


boot_sd_2:

; After power cycle, card is in 3.3V signaling mode.  We do not intend 
; to change it nor we we care about what other options may be available.
;	ld		de,load_base
;	call	sd_cmd58		; cmd58 = read OCR (operation conditions register)



ac41_max_retry:	equ	0x80		; limit the number of acmd41 retries

	ld	b,ac41_max_retry
ac41_loop:
	push	bc			; save BC since B contains the retry count 
	ld	de,load_base		; store command response into load_base
	call	sd_acmd41		; ask if the card is ready
	pop	bc			; restore our retry counter
	or	a			; check to see if A is zero
	jr	z,ac41_done		; is A is zero, then the card is ready

	; Card is not ready, waste some time before trying again
	ld	hl,0x1000		; count to 0x1000 to consume time
ac41_dly:
	dec	hl			; HL = HL -1
	ld	a,h			; does HL == 0?
	or	l
	jr	nz,ac41_dly		; if HL != 0 then keep counting

	djnz	ac41_loop		; if (--retries != 0) then try again


ac41_fail:
	call	iputs
	db	'Error: Can not read SD card (ac41 command failed)\r\n\0'
	ret

ac41_done:
if 0
	call	iputs
	db	'** Note: Called ACMD41 0x\0'
	ld	a,ac41_max_retry
	sub	b
	call	hexdump_a
	call	iputs
	db	' times.\r\n\0'
endif

	; XXX I don't care what voltages are supported... I assume that 3.3v is


	; Find out the card capacity (HC or XC)
	ld	de,load_base
	call	sd_cmd58

	; XXX I don't care what the capacity is.







	; ############ Read the MBR ############

	;call	spi_read8f_init		; this is needed for cmd17

	; push the starting block number onto the stack in litle-endian order
	ld	hl,0			; SD card block number to read
	push	hl			; high half
	push	hl			; low half
	ld	de,load_base		; where to read the sector data into
	call	sd_cmd17
	pop	hl			; remove the block number from the stack
	pop	hl

if debug
	call	puts_crlf		; skip a line to set off from any debug dumps
endif
if 1
	call	iputs
	db	'Partition Table:\r\n\0'

	ld	hl,load_base+0x01BE	; address of the first partiton entry
	ld	e,0			; no fancy formatting
	ld	bc,16			; dump 16 bytes
	call	hexdump
	ld	hl,load_base+0x01CE	; address of the second partiton entry
	ld	e,0			; no fancy formatting
	ld	bc,16			; dump 16 bytes
	call	hexdump
	ld	hl,load_base+0x01DE	; address of the third partiton entry
	ld	e,0			; no fancy formatting
	ld	bc,16			; dump 16 bytes
	call	hexdump
	ld	hl,load_base+0x01EE	; address of the fourth partiton entry
	ld	e,0			; no fancy formatting
	ld	bc,16			; dump 16 bytes
	call	hexdump
endif

	; Find the geometry of the first partition record:
	ld	ix,load_base+0x01BE+0x08

	ld	hl,boot_sd_start
	call	puts
	ld	a,(ix+3)
	call	hexdump_a
	ld	a,(ix+2)
	call	hexdump_a
	ld	a,(ix+1)
	call	hexdump_a
	ld	a,(ix+0)
	call	hexdump_a
	call	puts_crlf

	ld	hl,boot_sd_count
	call	puts
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
	ld	ix,load_base+0x01BE+0x08
	ld	d,(ix+3)
	ld	e,(ix+2)
	push	de
	ld	d,(ix+1)
	ld	e,(ix+0)
	push	de

	ld	de,load_base		; where to read the sector data into
	ld	b,load_blks		; number of blocks to load (should be 32/16KB)

if 1
	; Print the details of what we are going to load and where it will go
	ld	hl,sd_msg_sd_blks1
	call	puts
	ld	a,b
	call	hexdump_a
	ld	hl,sd_msg_sd_blks2
	call	puts
	ld	a,d
	call	hexdump_a
	ld	a,e
	call	hexdump_a
	ld	hl,sd_msg_sd_blks3
	call	puts

	; Calculate the ending address of the load area
	ld	hl,load_base
	ld	a,load_blks
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
	ld	de,load_base		; where to read the sector data into
	ld	b,load_blks		; number of blocks to load (should be 32/16KB)
endif

	call	read_blocks
	pop	de			; Remove the 32-bit block number from the stack.
	pop	de

	jp	load_base		; Run the code that we just read in from the SD card.


boot_sd_start:		defb	'\nPartition 1 starting block number: \0'
boot_sd_count:		defb	'Partition 1 number of blocks:      \0'

boot_sd_agn:		defb	'Reinitialize and read SD card again? (x to quit)\0'

sd_msg_sd_blks1:	defb	'\nLoading 0x\0'
sd_msg_sd_blks2:	defb	' 512-byte blocks into 0x\0'
sd_msg_sd_blks3:	defb	' - 0x\0'



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

read_block_n:

if 1
	ld	c,'.'
	call	con_tx_char
endif

if 0
	ld	hl,rb_blk_msg
	call	puts
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
	jr	nz,rb_fail

	; count the block
	dec	b
	jr	z,rb_success		; note that a=0 here = success!

	; increment the target address by 512
	inc	d
	inc	d

	; increment the 32-bit block number
	inc	(iy+0)
	jr	nz,read_block_n
	inc	(iy+1)
	jr	nz,read_block_n
	inc	(iy+2)
	jr	nz,read_block_n
	inc	(iy+3)
	jr	read_block_n

rb_success:
	xor	a

rb_fail:
	ld	iy,4
	add	iy,sp
	ld	sp,iy
	pop	iy
	pop	de
	pop	bc
	ret


rb_blk_msg:	defb	'Read Block: \0'


include	'sdcard.asm'
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
