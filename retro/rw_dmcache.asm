;****************************************************************************
;
;    Z80 Retro! BIOS 
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


;****************************************************************************
;
; BANK     Usage
;   0    SD cache bank 0
;   1    SD cache bank 1
;   2    SD cache bank 2
;   3    SD cache bank 3
;   4
;   5
;   6
;   7
;   8
;   9
;   A
;   B
;   C
;   D    DM Cache tag table
;   E    CP/M zero page and low half of the TPA *
;   F    CP/M high half of the TPA, CCP, BDOS, and BIOS *
;
;  * These banks are controlled by the BIOS.
;
; DM cache tag table is used to record the use of each of the 256
; cache slots.  The tag table contains 256 entries, each containing 
; 8-bits:
;
;	VxTTTTTT
;
; Where:
; 	V = 0 if the entry contains valid data, else it is unused
;	x = not used, set to zero
;	TTTTTT = CP/M track number bits 8-13 that occupy this slot
;
; Each entry of the tag table are indexed using the cache slot number.
; The slot number is defined as the low 8-bits of the CP/M track
; number that COULD be stored within.  Therefore the CP/M track number 
; of the data that is stored any given cache slot is the slot-tag bits 
; 5-0 followed by the slot number.  In binary:
;
;	00TTTTTTSSSSSSSS
;
; Examples of tag values (note that ss is the slot number when used below)
;
;	1xxxxxxx = Slot is not used (filled with garbage)
;	00000000 = Slot contains a copy of CP/M track number 0x00ss
;	00001111 = Slot contains a copy of CP/M track number 0x0Fss
;	00110000 = Slot contains a copy of CP/M track number 0x30ss
;
; Therefore, if entry number 5 (binary 00000101) of the cache tag table
; contains 00110000 then the slot contains a copy of track 0x3005 because:
;
;	Tag entry number 5 represents slot number 5.
;	The value of entry 5 in this example is binary: 00110000 
;	The entry is a valid track because the MSB is 0.
;	Tag bits 5-0 contain bits 13-8 of the CP/M track number: 110000.
;	Combine the tag bits with the slot number to get the CP/M track number: 
;		  110000 00000101
;	Zero-extend the result to get a 16-bit track number:
;		00110000 00000101 = 0x3005
;
; The cache tag table is located in bank 0xD (13) and begins at address 0.
;
;****************************************************************************


;##########################################################################
; set .rw_debug to:
;    0 = no debug output
;    1 = print messages from new code under development
;    2 = print all the above plus the primairy 'normal' debug messages
;    3 = print all the above plus verbose 'noisy' debug messages
;##########################################################################
.rw_debug:		equ	3
;.rw_debug:		equ	0

.cache_tag_bank: 	equ	0xd0	; defined in terms of the GPIO port bits 
;.cache_tag_base:	equ	0	; the first tag table entry MUST be at 0x0000!

.cache_tag_inval:	equ	0x80	; when MSB is set to 0 then the tag is valid
.cache_tag_track:	equ	0x3f	; a mask for the tag's track bits 


; XXX This is a hack that won't work unless the disk partition < 0x10000
; XXX This has the SD card partition offset hardcoded in it!!!
.sd_partition_base: equ	0x800


;##########################################################################
; Calc the cache slot number from the CP/M track number
;
; HL = track number
; return: HL=slot number
;##########################################################################
.dm_trk2slt:
	ld	h,0
	ret

;##########################################################################
; Convert a cache slot number in HL to the bank number wherein the slot 
; is stored.
;
; L=slot number (H must be zero and is ignored here)
; return: A=blank number
;##########################################################################
.dm_slt2bnk:
	ld	a,l		; BBxx xxxx
	rrca			; xBBx xxxx
	rrca			; xxBB xxxx
	and	0x30		; 00BB 0000
	ret

;##########################################################################
; Convert a cache slot number in HL to the address the slot is stored.
;
; L = slot number (H must be zero and is ignored here)
; return: HL = slot address
; Clobbers: AF
;##########################################################################
.dm_slt2adr:
	ld	a,l		; A = xxAA AAAA
	rlca			; A = xAAA AAAx
	and	0x7e		; A = 0AAA AAA0
	ld	h,a		; HL = 0AAA AAA0 xxAA AAAA
	ld	l,0		; HL = 0AAA AAA0 0000 0000
	ret


;##########################################################################
; Return the value of the cache tag for the given slot number
;
; WARNING: This will temporarily change the RAM bank value! If any IRQs
;	are possible, either the stack must be in high-memory or the
;	IRQs must be disabled before calling this function.
;
; HL = slot number
; return: A = cache tag value
; Clobbers: H
;##########################################################################
.dm_slt2tag:
	; select the RAM bank containing the cache tag table
	ld      a,(gpio_out_cache)	; get current value of the GPIO port
	and	(~gpio_out_lobank)&0x0ff	; zero the RAM bank bits
	or	.cache_tag_bank		; set the bank to the tag table
	out     (gpio_out),a		; select the cache tag bank


if 0
	; XXX break the rules for testing is OK because BIOS uses a high-stack
	push	hl
	push	bc
	push	de
	ld	b,a	; save the bank number
	call	iputs
	db	'bank=\0'
	ld	a,b	; restore the bank number
	call	hexdump_a
	call	puts_crlf

	; dump the cache tag table
	ld	hl,0
	ld	bc,256
	ld	e,1
	call	hexdump

	pop	de
	pop	bc
	pop	hl
endif


	; DO NOT USE THE STACK HERE!
	; since the cache tag table starts at 0x0000, HL = tag entry address
	ld	h,(hl)			; H = tag value for the slot

	; restore the RAM bank
	ld	a,(gpio_out_cache)
	out	(gpio_out),a		; restore the bank to the original value

	ld	a,h			; A = tag
	ret
	

;##########################################################################
; Return the value of the CP/M track number for a given slot number.
;
; HL = slot address (H must be zero and is ignored here)
; return: HL = CP/M track number (or 0xFFFF if the slot is empty)
; See stack & IRQ warnings in .dm_slt2tag!
; Clobbers: AF
;##########################################################################
.dm_slt2trk:
	call	.dm_slt2tag		; A = tag, H is clobbered

	;and	.cache_tag_inval	; this takes longer than..
	or	a			; check the MSb

	jp	m,.dm_slt2trkv		; V-bit is set

	and	.cache_tag_track	; mask off the high bits (should be zero here anyway)
	ld	h,a			; H = track bits 13-8, L = slot = track bits 7-0
	ret

.dm_slt2trkv:
	ld	hl,0xffff		; tag is invalid
	ret
	


;##########################################################################
; Set the tag for a given slot number to the given value.
;
; WARNING: This will temporarily change the RAM bank value! If any IRQs
;	are possible, either the stack must be in high-memory or the
;	IRQs must be disabled before calling this function.
;
; H = tag
; L = slot number
; Clobbers: H, A
;##########################################################################
.dm_settag:
	; select the RAM bank containing the cache tag table
	ld      a,(gpio_out_cache)	; get current value of the GPIO port
	and	(~gpio_out_lobank)&0x0ff	; zero the RAM bank bits
	or	.cache_tag_bank		; set the bank to the tag table
	out     (gpio_out),a		; select the cache tag bank

	; DO NOT USE THE STACK HERE!
	ld	a,h			; save the tag value

	; Since the cache tag table starts at 0x0000, L = tag entry address
	ld	h,0			; HL = tag entry address 
	ld	(hl),a

if 0
	; XXX break the rules for testing is OK because BIOS uses a high-stack
	push	hl
	push	bc
	push	de
	call	iputs
	db	'\r\ncache tags:\r\n\0'

	; dump the cache tag table
	ld	hl,0
	ld	bc,256
	ld	e,1
	call	hexdump

	pop	de
	pop	bc
	pop	hl
endif

	; restore the RAM bank
	ld	a,(gpio_out_cache)
	out	(gpio_out),a		; restore the bank to the original value

	ret



;##########################################################################
;
; CP/M 2.2 Alteration Guide p19:
; Assuming the drive has been selected, the track has been set, the sector
; has been set, and the DMA address has been specified, the READ subroutine
; attempts to read one sector based upon these parameters, and returns the
; following error codes in register A:
;
;    0 no errors occurred
;    1 non-recoverable error condition occurred
;
; When an error is reported the BDOS will print the message "BDOS ERR ON
; x: BAD SECTOR".  The operator then has the option of typing <cr> to ignore
; the error, or ctl-C to abort.
;
;##########################################################################
bios_read:
if .rw_debug >= 1
	call	iputs
	db	"bios_read entered: \0"
	call	bios_debug_disk
endif


if .rw_debug >= 1

	; Test the conversion routines

	call	iputs
	db	"DM cache slot=\0"

	ld      hl,(bios_disk_track)
	call	.dm_trk2slt

	ld	a,h
	call	hexdump_a
	ld	a,l
	call	hexdump_a


	call	iputs
	db	", bank=\0"

	ld      hl,(bios_disk_track)
	call	.dm_trk2slt
	call	.dm_slt2bnk

	call	hexdump_a


	call	iputs
	db	', address=\0'

	ld      hl,(bios_disk_track)
	call	.dm_trk2slt
	call	.dm_slt2adr

	ld	a,h
	call	hexdump_a
	ld	a,l
	call	hexdump_a



	; show the current tag for the slot 
	call	iputs
	db	', (tag=\0'

	ld	hl,(bios_disk_track)
	call	.dm_trk2slt		; find the slot for the desired track
	call	.dm_slt2tag		; get the value of the tag for the slot

	call	hexdump_a


	; show the current track number in the slot
	call	iputs
	db	', track=\0'

	ld	hl,(bios_disk_track)
	call	.dm_trk2slt		; find the slot for the desired track
	call	.dm_slt2trk		; ask what track is currently in that slot

	ld	a,h
	call	hexdump_a
	ld	a,l
	call	hexdump_a



	call	iputs
	db	', hit=\0'

	; Does the slot have the track in it that we are looking for?
	ld	d,h			; save the track number 
	ld	e,l			;      that is currently in the slot
	ld	hl,(bios_disk_track)
	or	a			; clear the CY flag
	sbc	hl,de			; HL = got - want
	jp	nz,.debug_read_miss
	call	iputs
	db	'Y\0'
	jp	.debug_read_hit
.debug_read_miss:
	call	iputs
	db	'N\0'
.debug_read_hit:
	
	; In a write-through cache this will simply discard what is in the slot if it is 
	; not what we need.

	call	iputs
	db	', new tag=\0'

	ld	hl,(bios_disk_track)

	ld	a,h
	call	hexdump_a



	call	iputs
	db	')\0'

	call	puts_crlf

endif




	; switch to a local stack (we only have a few levels when called from the BDOS!)
	push	hl			; save HL into the caller's stack
	ld	hl,0
	add	hl,sp			; HL = SP
	ld	sp,bios_stack		; SP = temporary private BIOS stack area
	push	hl			; save the old SP value in the BIOS stack

	push	bc			; save the register pairs we will otherwise clobber
	push	de			; this is not critical but may make WBOOT cleaner later


	; select the proper RAM bank for the given slot
	ld      hl,(bios_disk_track)
	call	.dm_trk2slt
	call	.dm_slt2bnk
	ld	d,a			; D = bank number in high 4-bits

	; Is the target track number in the cache? 

	ld      hl,(bios_disk_track)
	call	.dm_trk2slt		; HL=slot number
	call	.dm_slt2trk		; HL=track number currently in the target slot

	; select the RAM bank with the target cache slot in it
	ld      a,(gpio_out_cache)	; get current value of the GPIO port
	ld	(.save_gpio_out),a	; save the current gpio port value so can restore later
	and	(~gpio_out_lobank)&0x0ff	; zero the RAM bank bits
	or	d			; set the bank to that with the desired slot
	ld	(gpio_out_cache),a	; save it so that the SD/SPI logic uses the right value
	out     (gpio_out),a		; select the cache tag bank

if .rw_debug >= 3
	push	af
	call	iputs
	db	'cache slot bank=\0'
	pop	af
	call	hexdump_a
	call	puts_crlf
endif


	; Note: The cache slot's track number will be 0xffff if the slot is empty. 
	; Track 0xffff is impossible when CP/M tracks have more than one sector in them.

	ld      de,(bios_disk_track)	; DE = the CP/M track number we want
        or	a			; clear the CY flag
        sbc     hl,de                   ; HL = got - want
        jp      z,.read_cache_hit	; if equal then is in the cache

	; The track in the slot is /not/ what we want.  Read it from the SD card 
	; (possibly discarding/replacing a track that is currently in the slot.)

if .rw_debug >= 2
	call	iputs
	db	"bios_read cache miss: \0"
	call	bios_debug_disk
endif

	; Calculate the SD physical block number that we want to read
	ld	hl,(bios_disk_track)
	ld	de,.sd_partition_base	; XXX Add the starting partition block number
	add	hl,de			; HL = SD physical block number

	; Push the 32-bit physical SD block number into the stack in little-endian order
	ld	de,0
	push	de			; 32-bit SD block number (big end)
	push	hl			; 32-bit SD block number (little end)

	; calculate the slot address within the selected bank
	ld	hl,(bios_disk_track)
	call	.dm_trk2slt
	call	.dm_slt2adr		; HL = target slot buffer address to read the 512-byte block
	ld	d,h
	ld	e,l			; DE = HL

if .rw_debug >= 3
	call	iputs
	db	'cache slot addr=\0'
	ld	a,h
	call	hexdump_a
	ld	a,l
	call	hexdump_a
	call	puts_crlf
endif

	call	sd_cmd17		; read the SD block

	pop	hl			; clean the 4-byte SD block number from the stack
	pop	de

	or	a			; was the SD driver read OK?
	jr	z,.bios_read_sd_ok


	call	iputs
	db	"BIOS_READ FAILED!\r\n\0"

	; Mark the slot as invalid in case the read fails
	ld	hl,(bios_disk_track)
	call	.dm_trk2slt		; overkill, but proper
	ld	h,.cache_tag_inval	; mark the slot as invalid
	call	.dm_settag

	ld	a,1			; tell CP/M the read failed
	jp	.bios_read_ret


.bios_read_sd_ok:
	; Update the cache tag for the slot that we just replaced
	ld	hl,(bios_disk_track)
	call	.dm_settag		; set tag=H for slot=L

if .rw_debug >= 3
	call	iputs
	db	'update tag=\0'
	ld	a,(bios_disk_track+1)
	call	hexdump_a
	call	iputs
	db	', for slot=\0'
	ld	a,(bios_disk_track)
	call	hexdump_a
	call	puts_crlf
	
endif

.read_cache_hit:
	ld	hl,(bios_disk_track)
	call	.dm_trk2slt
	call	.dm_slt2adr
	ld	d,h
	ld	e,l			; DE = target slot buffer address of the track

	; calculate the CP/M sector offset address (bios_disk_sector*128)
	ld	hl,(bios_disk_sector)	; must be 0..3
	add	hl,hl			; HL *= 2
	add	hl,hl			; HL *= 4
	add	hl,hl			; HL *= 8
	add	hl,hl			; HL *= 16
	add	hl,hl			; HL *= 32
	add	hl,hl			; HL *= 64
	add	hl,hl			; HL *= 128

	; calculate the address of the CP/M sector in the .bios_sdbuf
	add	hl,de			; HL = @ of cpm sector in the cache

if .rw_debug >= 3
	call	iputs
	db	'RAM bank=\0'
	ld	a,(gpio_out_cache)
	call	hexdump_a
	call	iputs
	db	', sector src addr=\0'
	ld	a,h
	call	hexdump_a
	ld	a,l
	call	hexdump_a
endif

	; copy the CP/M sector data from the cache slot
	ld	de,(bios_disk_dma)		; DE = CP/M target buffer address
	ld	a,0x7f				; is DE > 0x7fff ?
	cp	d
	jp	m,.bios_read_direct		; yes? then OK

	; we need to use a bounce buffer
	ld	de,.dm_bounce_buffer

if .rw_debug >= 3
	call	iputs
	db	', bounce dest=\0'
	ld	a,d
	call	hexdump_a
	ld	a,e
	call	hexdump_a
	call	puts_crlf
endif

	ld	bc,0x0080		; number of bytes to copy
	ldir


	; restore the original RAM bank
	ld	a,(.save_gpio_out)
	ld	(gpio_out_cache),a	
	out     (gpio_out),a

	ld	hl,.dm_bounce_buffer
	ld	de,(bios_disk_dma)

if .rw_debug >= 3
	call	iputs
	db	'bounce src=\0'
	ld	a,h
	call	hexdump_a
	ld	a,l
	call	hexdump_a
endif

.bios_read_direct:

if .rw_debug >= 3
	call	iputs
	db	', dest=\0'
	ld	a,d
	call	hexdump_a
	ld	a,e
	call	hexdump_a
	call	puts_crlf
endif

	ld	bc,0x0080		; number of bytes to copy
	ldir

	xor	a			; A = 0 = read OK

.bios_read_ret:
	; restore the proper RAM bank (redundant but OK if used a bounce buffer)
	push	af
	ld	a,(.save_gpio_out)
	ld	(gpio_out_cache),a	
	out     (gpio_out),a

if .rw_debug >= 3
	push	af
	call	iputs
	db	'restore bank=\0'
	pop	af
	call	hexdump_a
	call	puts_crlf
endif

	pop	af

	pop	de			; restore saved regs
	pop	bc


	; Restore the caller's stack
	pop	hl			; HL = original saved stack pointer
	ld	sp,hl			; SP = original stack address
	pop	hl			; restore the original  HL value

	ret

;##########################################################################
;
; CP/M 2.2 Alteration Guide p19:
; Write the data from the currently selected DMA address to the currently
; selected drive, track, and sector.  The error codes given in the READ
; command are returned in register A:
;
;    0 no errors occurred
;    1 non-recoverable error condition occurred
;
; p34 adds: Upon entry the value of C will be useful for blocking
; and deblocking a drive's physical sector sizes:
;
;  0 = normal sector write
;  1 = write into a directory sector
;  2 = first sector of a newly used block
;
; Return the following completion status in register A:
;
;    0 no errors occurred
;    1 non-recoverable error condition occurred
;
; When an error is reported the BDOS will print the message "BDOS ERR ON
; x: BAD SECTOR".  The operator then has the option of typing <cr> to ignore
; the error, or ctl-C to abort.
;
;##########################################################################
bios_write:

if .rw_debug >= 1
	push	bc
	call	iputs
	db	"bios_write entered, C=\0"
	pop	bc
	push	bc
	ld	a,c
	call	hexdump_a
	call	iputs
	db	": \0"
	call	bios_debug_disk
	pop	bc
endif


	; XXX stub in for testing
	ld	a,1
	ret			; 100% error!




if 0

	; switch to a local stack (we only have a few levels when called from the BDOS!)
	push	hl			; save HL into the caller's stack
	ld	hl,0
	add	hl,sp			; HL = SP
	ld	sp,bios_stack		; SP = temporary private BIOS stack area
	push	hl			; save the old SP value in the BIOS stack

	push	de			; save the register pairs we will otherwise clobber
	push	bc

	ld	hl,(bios_disk_track)	; HL = CP/M track number

	; Check to see if the SD block in .bios_sdbuf is already the one we want
	ld	a,(.bios_sdbuf_val)	; get the .bios_sdbuf valid flag
	or	a			; is it a non-zero value?
	jr	nz,.bios_write_miss	; block buffer is invalid, pre-read the SD block

	ld	a,(.bios_sdbuf_trk)	; A = CP/M track LSB
	cp	l			; is it the one we want?
	jr	nz,.bios_write_miss	; LSB does not match, pre-read the SD block

	ld	a,(.bios_sdbuf_trk+1)	; A = CP/M track MSB
	cp	h			; is it the one we want?
	jp	z,.bios_write_sdbuf	; The SD block in .bios_sdbuf is the one we want!

.bios_write_miss:
if .rw_debug >= 1
	call	iputs
	db	"bios_write cache miss: \0"
	call	bios_debug_disk
endif

	; Assume all will go well reading the SD card block.
	; We only need to touch this if we are going to actually read the SD card.
	ld	(.bios_sdbuf_trk),hl	; store the current CP/M track number in the .bios_sdbuf
	xor	a			; A = 0
	ld	(.bios_sdbuf_val),a	; mark the .bios_sdbuf as valid


	; if C==2 then we are writing into an alloc block (and therefore an SD block) that is not dirty
	pop	bc			; restore C in case was clobbered above
	push	bc
	ld	a,2
	cp	c
	jr	nz,.bios_write_prerd

	; padd the SD buffer with all 0xe5
	ld	hl,.bios_sdbuf		; buffer to initialize
	ld	de,.bios_sdbuf+1	; buffer+1
	ld	bc,0x1ff		; number of bytes to initialize
	ld	(hl),0xe5		; set the first byte to 0xe5
	ldir				; set the rest of the bytes to 0xe5
	jp	.bios_write_sdbuf	; go to write logic (skip the SD card pre-read)

.bios_write_prerd:
	; pre-read the block so we can replace one sector and write it back
	; XXX This is a hack that won't work unless the disk partition < 0x10000
	; XXX This has the SD card partition offset hardcoded in it!!!
	ld	de,.sd_partition_base	; XXX add the starting partition block number
	add	hl,de			; HL = SD physical block number

	; push the 32-bit physical SD block number into the stack in little-endian order
	ld	de,0
	push	de			; 32-bit SD block number (big end)
	push	hl			; 32-bit SD block number (little end)
	ld	de,.bios_sdbuf		; DE = target buffer to read the 512-byte block
	call	sd_cmd17		; pre-read the SD block
	pop	hl			; clean the SD block number from the stack
	pop	de

	or	a			; was the SD driver read OK?
	jr	z,.bios_write_sdbuf

	call	iputs
	db	"BIOS_WRITE SD CARD PRE-READ FAILED!\r\n\0"
	ld	a,1			; tell CP/M the read failed
	ld	(.bios_sdbuf_val),a	; mark the .bios_sdbuf as invalid
	jp	.bios_write_ret

.bios_write_sdbuf:
	; calculate the CP/M sector offset address (bios_disk_sector*128)
	ld	hl,(bios_disk_sector)	; must be 0..3
	add	hl,hl			; HL *= 2
	add	hl,hl			; HL *= 4
	add	hl,hl			; HL *= 8
	add	hl,hl			; HL *= 16
	add	hl,hl			; HL *= 32
	add	hl,hl			; HL *= 64
	add	hl,hl			; HL *= 128

	; calculate the address of the CP/M sector in the .bios_sdbuf
	ld	bc,.bios_sdbuf
	add	hl,bc			; HL = @ of cpm sector in the .bios_sdbuf
	ld	d,h
	ld	e,l			; DE = @ of cpm sector in the .bios_sdbuf

	; copy the data of interest /into/ the SD block
	ld	hl,(bios_disk_dma)		; source address
	ld	bc,0x0080		; number of bytes to copy
	ldir

	; write the .bios_sdbuf contents to the SD card
	ld      hl,(bios_disk_track)
	ld	de,.sd_partition_base	; XXX add the starting partition block number
	add	hl,de			; HL = SD physical block number
	ld	de,0
	push	de			; SD block number to write
	push	hl
	ld	de,.bios_sdbuf		; DE = target buffer to read the 512-byte block
	call	sd_cmd24		; write the SD block
	pop	hl			; clean the SD block number from the stack
	pop	de

	or	a
	jr	z,.bios_write_ret

	call	iputs
	db	"BIOS_WRITE SD CARD WRITE FAILED!\r\n\0"
	ld	a,1			; tell CP/M the read failed
	ld	(.bios_sdbuf_val),a	; mark the .bios_sdbuf as invalid

.bios_write_ret:
	pop	bc
	pop	de			; restore saved regs

	pop	hl			; HL = original saved stack pointer
	ld	sp,hl			; SP = original stack address
	pop	hl			; restore the original  HL value

	ret

endif


;##########################################################################
; A bounce buffer used when copying between a DM cache bank and a DMA 
; buffer address that is less than 0x8000
;##########################################################################
.dm_bounce_buffer:
	ds	0x80

;##########################################################################
; A place to save the GPIO latch value so can restore the original RAM
; bank after changing it.
;##########################################################################
.save_gpio_out:
	ds	1


;##########################################################################
; Called once before library is used.
;
; WARNING: This will temporarily change the RAM bank value! If any IRQs
;	are possible, either the stack must be in high-memory or the
;	IRQs must be disabled before calling this function.
;
; Clobbers: AF, BC, DE, HL
;##########################################################################
rw_init:
	call    iputs
	db      'NOTICE: rw_dmcache library installed.\r\n\0'

	; initialize the cache tags
	
	; select the RAM bank containing the cache tag table
	ld      a,(gpio_out_cache)	; get current value of the GPIO port
	and	(~gpio_out_lobank)&0x0ff	; zero the RAM bank bits
	or	.cache_tag_bank		; set the bank to the tag table
	out     (gpio_out),a		; select the cache tag bank

	; DO NOT USE THE STACK HERE!
	ld	hl,0			; address of the first tag
	ld	de,1			; address of second tag
	ld	bc,0xff			; all but one left to go
	;ld	(hl),.cache_tag_inval	; mark the first one as invalid
	ld	(hl),0xff		; mark the first one as invalid (easier to see than 0x80)
	ldir				; copy the first to all the rest



	; restore the RAM bank
	ld	a,(gpio_out_cache)
	out	(gpio_out),a		; restore the bank to the original value

	ret




;##########################################################################
; Dump the cache tag table.
;
; WARNING: 
;	This will use the bios_stack and temporarily change the RAM bank 
;	value! 
;
;##########################################################################
if 1
rw_debug_wedge:

	; switch to a local stack since we need to change the RAM bank
	push	hl			; save HL into the caller's stack
	ld	hl,0
	add	hl,sp			; HL = SP
	ld	sp,bios_stack		; SP = temporary private BIOS stack area
	push	hl			; save the old SP value in the BIOS stack

	; select the RAM bank containing the cache tag table
	ld      a,(gpio_out_cache)	; get current value of the GPIO port
	and	(~gpio_out_lobank)&0x0ff	; zero the RAM bank bits
	or	.cache_tag_bank		; set the bank to the tag table
	out     (gpio_out),a		; select the cache tag bank


	; dump the cache tag table

        call    iputs
        db      '\r\ncache tags:\r\n\0'

        ld      hl,0
        ld      bc,256
        ld      e,1
        call    hexdump



	; restore the RAM bank
	ld	a,(gpio_out_cache)
	out	(gpio_out),a		; restore the bank to the original value

	; restore the caller's stack
	pop	hl			; HL = original saved stack pointer
	ld	sp,hl			; SP = original stack address
	pop	hl			; restore the original  HL value

	ret
endif
