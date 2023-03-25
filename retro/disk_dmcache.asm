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

.sd_partition_base:	equ	0x800


;##########################################################################
; set .dmcache_debug to:
;    0 = no debug output
;    1 = print messages from new code under development
;    2 = print all the above plus the primairy 'normal' debug messages
;    3 = print all the above plus verbose 'noisy' debug messages
;##########################################################################
;.dmcache_debug:		equ	3
.dmcache_debug:		equ	0

.cache_tag_bank: 	equ	0xd0	; defined in terms of the GPIO port bits 
;.cache_tag_base:	equ	0	; the first tag table entry MUST be at 0x0000!

.cache_tag_inval:	equ	0x80	; when MSB is set to 0 then the tag is valid
.cache_tag_track:	equ	0x3f	; a mask for the tag's track bits 


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




;************************************************************************
; Convert a CP/M track number & sector to the address of the sector
; in the appropriate cache slot.
;
; HL=CP/M track number
; BC=CP/M sector number
;
; Clobbers everything
;************************************************************************
.dm_trksec2addr:
	push	bc
	call	.dm_trk2slt
	call	.dm_slt2adr
	ex	de,hl			; DE = target slot buffer address (HL = garbage)

	; calculate the CP/M sector offset address (disk_sec*128)
	pop	hl			; HL=CP/M sector number, must be 0..3
	add	hl,hl			; HL *= 2
	add	hl,hl			; HL *= 4
	add	hl,hl			; HL *= 8
	add	hl,hl			; HL *= 16
	add	hl,hl			; HL *= 32
	add	hl,hl			; HL *= 64
	add	hl,hl			; HL *= 128

	; calculate the address of the CP/M sector in the .bios_sdbuf
	add	hl,de			; HL = @ of cpm sector in the cache

if .dmcache_debug >= 3
	call	iputs
	db	'.dm_trksec2addr sector addr=\0'
	ld	a,h
	call	hexdump_a
	ld	a,l
	call	hexdump_a
	call	puts_crlf
endif
	ret





if 0 ;not yet
;************************************************************************
; Special case cache 'fill' logic to padd a slot with 0xe5 when CP/M
; wants to write into a sector in an as-yet unused allocation block.
;
; HL=track number
;************************************************************************
.cache_slot_padd:

	push	hl			; save the track number for repeated use later 

	call	.dm_trk2slt
	call	.dm_slt2bnk
	ld	d,a			; D = bank number in high 4-bits

	; select the RAM bank with the target cache slot in it
	ld      a,(gpio_out_cache)	; get current value of the GPIO port
	and	(~gpio_out_lobank)&0x0ff	; zero the RAM bank bits
	or	d			; set the bank to that with the desired slot
	out     (gpio_out),a		; select the cache tag bank

if .dmcache_debug >= 3
	push	af
	call	iputs
	db	'.cache_slot_padd slot bank=\0'
	pop	af
	call	hexdump_a
	call	puts_crlf
endif

	; calculate the slot address within the selected bank
	pop	hl			; HL = the CP/M track number we want
	push	hl
	call	.dm_trk2slt
	call	.dm_slt2adr		; HL = target slot buffer address to read the 512-byte block
	ld	d,h
	ld	e,l			; DE = HL

	ld	(hl),0xe5		; HL=first slot byte address
	inc	de			; DE=second slot byte address
	ld	bc,0x007f		; padd the remaining 127 bytes
	ldir

	; Update the cache tag for the slot that we just replaced
	pop	hl			; HL = the CP/M track number we want
	call	.dm_settag		; set tag=H for slot=L

	; restore the proper RAM bank 
	ld	a,(gpio_out_cache)
	out     (gpio_out),a

	ret
endif


;************************************************************************
; Fill a cache slot by reading the CP/M track number in HL into the 
; appropriate slot.
;
; This assumes that it is running with a stack over 0x8000
;
; HL = CP/M track number 
; return Z flag = 1 = OK
;************************************************************************
.cache_slot_fill:

	push	hl			; save the track number for repeated use later 

	call	.dm_trk2slt		; HL=slot number
	call	.dm_slt2trk		; HL=track number currently in the target slot

	; Note: The cache slot's track number will be 0xffff if the slot is empty. 
	; Track 0xffff is impossible when CP/M tracks have more than one sector in them.

	pop	de			; DE = the CP/M track number we want
        or	a			; clear the CY flag
        sbc     hl,de                   ; HL = got - want

if .dmcache_debug >= 2
	jr	nz,.dbg_csm		; if we have a cache-miss then don't print here
	push	af			; save the flags so can decide to return below
	call	iputs
	db	".cache_slot_fill cache hit: \0"
	call	bios_debug_disk
	pop	af
.dbg_csm:
endif

	ret	z			; if HL==DE then return w/Z=1 now


if .dmcache_debug >= 2
	call	iputs
	db	".cache_slot_fill cache miss: \0"
	call	bios_debug_disk
endif

	push	de			; put a copy of the CP/M track we want back onto the stack

	; calculate the proper RAM bank for the given slot we need to use for the CP/M track
	ld	h,d
	ld	l,e
	call	.dm_trk2slt
	call	.dm_slt2bnk
	ld	d,a			; D = bank number in high 4-bits

	; select the RAM bank with the target cache slot in it
	ld      a,(gpio_out_cache)	; get current value of the GPIO port
	ld	(.save_gpio_out),a	; save the current gpio port value so can restore later
	and	(~gpio_out_lobank)&0x0ff	; zero the RAM bank bits
	or	d			; set the bank to that with the desired slot
	ld	(gpio_out_cache),a	; save it so that the SD/SPI logic uses the right value
	out     (gpio_out),a		; select the cache tag bank

if .dmcache_debug >= 3
	push	af
	call	iputs
	db	'.cache_slot_fill slot bank=\0'
	pop	af
	call	hexdump_a
	call	puts_crlf
endif

	; calculate the slot address within the selected bank
	pop	hl			; HL = the CP/M track number we want
	push	hl
	call	.dm_trk2slt
	call	.dm_slt2adr		; HL = target slot buffer address to read the 512-byte block
	ex	de,hl			; DE = target slot buffer address (HL = garbage)

	; Calculate the SD physical block number that we want to read
	pop	hl
	push	hl			; HL = cp/m track number
if 1
	ld	bc,.sd_partition_base	; XXX Add the starting partition block number
	add	hl,bc			; HL = SD physical block number

	; Push the 32-bit physical SD block number into the stack in little-endian order
	ld	bc,0
	push	bc			; 32-bit SD block number (big end)
	push	hl			; 32-bit SD block number (little end)
else
; this doesn't work
	call	.calc_sd_block		; DE,HL = partition_base + HL

	; Push the 32-bit physical SD block number into the stack in little-endian order
	push	de			; 32-bit SD block number (big end)
	push	hl			; 32-bit SD block number (little end)
endif

if .dmcache_debug >= 3
	call	iputs
	db	'.cache_slot_fill slot addr=\0'
	ld	a,d
	call	hexdump_a
	ld	a,e
	call	hexdump_a
	call	puts_crlf
endif

	call	sd_cmd17		; read the SD block

	pop	hl			; clean the 4-byte SD block number from the stack
	pop	bc

	or	a
	jr	z,.cache_fill_ok

	; Mark the slot as invalid because the read has failed
	pop	hl			; HL = the CP/M track number we want
	call	.dm_trk2slt		; overkill, but proper
	ld	h,.cache_tag_inval	; mark the slot as invalid
	call	.dm_settag

	ld	a,(.save_gpio_out)
	ld	(gpio_out_cache),a	
	out     (gpio_out),a

if .dmcache_debug >= 3
	push	af			; save the GPIO latch value
	call	iputs
	db	'.cache_slot_fill SD read block failed.  restore bank=\0'
	pop	af			; restore the GPIO latch value
	call	hexdump_a
	call	puts_crlf
endif

	or	1			; Z = 0 = error
	ret


.cache_fill_ok:

if .dmcache_debug >= 3
	call	iputs
	db	'.cache_slot_fill update tag=\0'
	pop	hl			; HL = the CP/M track number we want
	push	hl
	ld	a,h
	call	hexdump_a
	call	iputs
	db	', for slot=\0'
	ld	a,l
	call	hexdump_a
	call	puts_crlf
endif

	; Update the cache tag for the slot that we just replaced
	pop	hl			; HL = the CP/M track number we want
	call	.dm_settag		; set tag=H for slot=L

	; restore the proper RAM bank 
	ld	a,(.save_gpio_out)
	ld	(gpio_out_cache),a	
	out     (gpio_out),a

if .dmcache_debug >= 3
	push	af
	call	iputs
	db	'.cache_slot_fill restore bank=\0'
	pop	af
	call	hexdump_a
	call	puts_crlf
endif

	xor	a			; Z = 1 = no errors
	ret





;************************************************************************
; Flush a cache slot by writing the CP/M track number in HL out
; to disk.
;
; This assumes that it is running with a stack over 0x8000
;
; HL = CP/M track number 
; return Z flag = 1 = OK
;************************************************************************
.cache_slot_flush:

	push	hl			; save the track number for repeated use later 

	; calculate the proper RAM bank for the given slot we need to use for the CP/M track
	call	.dm_trk2slt
	call	.dm_slt2bnk
	ld	d,a			; D = bank number in high 4-bits

	; select the RAM bank with the target cache slot in it
	ld      a,(gpio_out_cache)	; get current value of the GPIO port
	ld	(.save_gpio_out),a	; save the current gpio port value so can restore later
	and	(~gpio_out_lobank)&0x0ff	; zero the RAM bank bits
	or	d			; set the bank to that with the desired slot
	ld	(gpio_out_cache),a	; save it so that the SD/SPI logic uses the right value
	out     (gpio_out),a		; select the cache tag bank

if .dmcache_debug >= 3
	push	af
	call	iputs
	db	'.cache_slot_flush slot bank=\0'
	pop	af
	call	hexdump_a
	call	puts_crlf
endif

	; calculate the slot address within the selected bank
	pop	hl			; HL = the CP/M track number we want
	push	hl			;	...and leave a copy on the stack
	call	.dm_trk2slt
	call	.dm_slt2adr		; HL = target slot buffer address to read the 512-byte block
	ex	de,hl			; DE = slot buffer address (and HL = garbage)

	; write the cache slot contents to the SD card
	pop	hl			; HL=CP/M track number

if 1
	ld	bc,.sd_partition_base	; XXX add the starting partition block number
	add	hl,bc			; HL = SD physical block number
	ld	bc,0
	push	bc			; SD block number to write
	push	hl
else
; this doesn't work
	ld	c,e
	ld	b,d			; BC = DE
	call	.calc_sd_block		; DE,HL = partition_base + HL

	; Push the 32-bit physical SD block number into the stack in little-endian order
	push	de			; 32-bit SD block number (big end)
	push	hl			; 32-bit SD block number (little end)
	ld	e,c
	ld	d,b			; DE = BC
endif

if .dmcache_debug >= 3
	call	iputs
	db	'.cache_slot_flush slot addr=\0'
	ld	a,d
	call	hexdump_a
	ld	a,e
	call	hexdump_a
	call	puts_crlf
endif

	call	sd_cmd24		; write the SD block
	pop	hl			; clean the SD block number from the stack
	pop	bc

	or	a
	jr	z,.slot_flush_ret	; write operation succeeded Z=1

	call	iputs
	db	".cache_slot_flush SD CARD WRITE FAILED!\r\n\0"

	or	1			; the write has failed Z=0

.slot_flush_ret:
	push	af
	ld	a,(.save_gpio_out)
	ld	(gpio_out_cache),a	
	out     (gpio_out),a

if .dmcache_debug >= 3
	push	af			; save the GPIO latch value
	call	iputs
	db	'.cache_slot_flush restore bank=\0'
	pop	af			; restore the GPIO latch value
	call	hexdump_a
	call	puts_crlf
endif
	pop	af
	ret



;************************************************************************
; Copy the CP/M sector data from cache into the RAM.
;
; disk_sec = sector in the cache to read from
; disk_track = track in the cache to read from
; disk_dma = where to copy the data into
;
; This assumes that it is running with a stack above 0x8000
;
; Clobbers everything
;************************************************************************
.copy_cache2ram:

	; calculate the proper RAM bank for the given slot we need to use for the CP/M track
	ld	hl,(disk_track)
	call	.dm_trk2slt
	call	.dm_slt2bnk
	ld	d,a				; D = bank number in high 4-bits

	; select the RAM bank with the target cache slot in it
	ld      a,(gpio_out_cache)		; get current value of the GPIO port
	ld	(.save_gpio_out),a		; save the current gpio port value so can restore later
	and	(~gpio_out_lobank)&0x0ff	; zero the RAM bank bits
	or	d				; set the bank to that with the desired slot
	ld	(gpio_out_cache),a		; save it so that the SD/SPI logic uses the right value
	out     (gpio_out),a			; select the cache tag bank

if .dmcache_debug >= 3
	push	af
	call	iputs
	db	'.copy_cache2ram slot bank=\0'
	pop	af
	call	hexdump_a
	call	puts_crlf
endif

	ld	hl,(disk_track)
	ld	bc,(disk_sec)
	call	.dm_trksec2addr			; HL = @ of cpm sector in the cache

	; Copy the CP/M sector data from the cache slot
	ld	de,(disk_dma)		; DE = CP/M target buffer address
	ld	a,0x7f				; is DE > 0x7fff ?
	cp	d
	jp	m,.copy_cache2ramd		; yes? then OK

	; we need to use a bounce buffer
	ld	de,.dm_bounce_buffer

if .dmcache_debug >= 3
	call	iputs
	db	'.copy_cache2ram bounce dest=\0'
	ld	a,d
	call	hexdump_a
	ld	a,e
	call	hexdump_a
	call	puts_crlf
endif

	ld	bc,0x0080			; number of bytes to copy
	ldir

	; restore the original RAM bank
	ld	a,(.save_gpio_out)
	ld	(gpio_out_cache),a	
	out     (gpio_out),a

	ld	hl,.dm_bounce_buffer
	ld	de,(disk_dma)

if .dmcache_debug >= 3
	call	iputs
	db	'.copy_cache2ram bounce src=\0'
	ld	a,h
	call	hexdump_a
	ld	a,l
	call	hexdump_a
endif

.copy_cache2ramd:

if .dmcache_debug >= 3
	call	iputs
	db	', dest=\0'
	ld	a,d
	call	hexdump_a
	ld	a,e
	call	hexdump_a
	call	puts_crlf
endif

	ld	bc,0x0080			; number of bytes to copy
	ldir

	; restore the proper RAM bank (redundant but OK if used a bounce buffer)
	ld	a,(.save_gpio_out)
	ld	(gpio_out_cache),a	
	out     (gpio_out),a

if .dmcache_debug >= 3
	push	af
	call	iputs
	db	'.copy_cache2ram restore bank=\0'
	pop	af
	call	hexdump_a
	call	puts_crlf
endif

	ret






;************************************************************************
; Copy the CP/M sector data from RAM into the cache.
;
; disk_sec = sector in the cache to write into
; disk_track = track in the cache to write into
; disk_dma = where to copy the data from
;
; This assumes that it is running with a stack above 0x8000
;
; Clobbers everything
;************************************************************************
.copy_ram2cache:

	ld	hl,(disk_dma)		; HL = CP/M target buffer address

if .dmcache_debug >= 3
	call	iputs
	db	'.copy_ram2cache sector src dma addr=\0'
	ld	a,h
	call	hexdump_a
	ld	a,l
	call	hexdump_a
endif

	; Do we need to use a bounce buffer?
	ld	a,0x7f				
	cp	h				; is HL > 0x7fff ?
	jp	m,.copy_ram2cached		; if HL > 0x7fff then no bounce

	; Need to copy the sector into the bounce buffer
	ld	de,.dm_bounce_buffer

if .dmcache_debug >= 3
	call	iputs
	db	', bounce dest=\0'
	ld	a,d
	call	hexdump_a
	ld	a,e
	call	hexdump_a
	call	puts_crlf
endif

	ld	bc,0x80
	ldir
	ld	hl,.dm_bounce_buffer

if .dmcache_debug >= 3
	call	iputs
	db	'.copy_ram2cache bounce src=\0'
	ld	a,h
	call	hexdump_a
	ld	a,l
	call	hexdump_a
endif

.copy_ram2cached:
	; source address = HL
	push	hl				; save for later

	; calculate the proper RAM bank for the given slot we need to use for the CP/M track
	ld	hl,(disk_track)
	call	.dm_trk2slt
	call	.dm_slt2bnk
	ld	d,a				; D = bank number in high 4-bits

	; select the RAM bank with the target cache slot in it
	ld      a,(gpio_out_cache)		; get current value of the GPIO port
	ld	(.save_gpio_out),a		; save the current gpio port value so can restore later
	and	(~gpio_out_lobank)&0x0ff	; zero the RAM bank bits
	or	d				; set the bank to that with the desired slot
	ld	(gpio_out_cache),a		; save it so that the SD/SPI logic uses the right value
	out     (gpio_out),a			; select the cache tag bank

if .dmcache_debug >= 3
	push	af
	call	iputs
	db	', dest slot bank=\0'
	pop	af
	call	hexdump_a
	call	puts_crlf
endif
	ld	hl,(disk_track)
	ld	bc,(disk_sec)
	call	.dm_trksec2addr			; HL = @ of cpm sector in the cache

	ex	de,hl				; DE = @ of target in the cache (and HL = garbage)
	pop	hl				; HL = @ of source data
	ld	bc,0x0080			; number of bytes to copy
	ldir

	; restore the original RAM bank
	ld	a,(.save_gpio_out)
	ld	(gpio_out_cache),a	
	out     (gpio_out),a

if .dmcache_debug >= 3
	push	af
	call	iputs
	db	'.copy_ram2cache restore bank=\0'
	pop	af
	call	hexdump_a
	call	puts_crlf
endif

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
.dmcache_read:
if .dmcache_debug >= 1
	call	iputs
	db	".dmcache_read entered: \0"
	call	disk_dump
endif


if .dmcache_debug >= 1

	; Test the conversion routines

	call	iputs
	db	"DM cache slot=\0"

	ld      hl,(disk_track)
	call	.dm_trk2slt

	ld	a,h
	call	hexdump_a
	ld	a,l
	call	hexdump_a


	call	iputs
	db	", bank=\0"

	ld      hl,(disk_track)
	call	.dm_trk2slt
	call	.dm_slt2bnk

	call	hexdump_a


	call	iputs
	db	', address=\0'

	ld      hl,(disk_track)
	call	.dm_trk2slt
	call	.dm_slt2adr

	ld	a,h
	call	hexdump_a
	ld	a,l
	call	hexdump_a



	; show the current tag for the slot 
	call	iputs
	db	', (tag=\0'

	ld	hl,(disk_track)
	call	.dm_trk2slt		; find the slot for the desired track
	call	.dm_slt2tag		; get the value of the tag for the slot

	call	hexdump_a


	; show the current track number in the slot
	call	iputs
	db	', track=\0'

	ld	hl,(disk_track)
	call	.dm_trk2slt		; find the slot for the desired track
	call	.dm_slt2trk		; ask what track is currently in that slot

	ld	a,h
	call	hexdump_a
	ld	a,l
	call	hexdump_a

	call	iputs
	db	', hit=\0'

	; Does the slot have the track in it that we are looking for?
	ex	de,hl			; DE = track number/slot (HL = garbage)
	ld	hl,(disk_track)
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

	ld	hl,(disk_track)

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

	ld	hl,(disk_track)	; HL = CP/M track number to read
	call	.cache_slot_fill
	jr	nz,.bios_read_err

	call	.copy_cache2ram  
	xor	a			; tell CP/M the read succeeded

.bios_read_ret:
	pop	de			; restore saved regs
	pop	bc

	; Restore the caller's stack
	pop	hl			; HL = original saved stack pointer
	ld	sp,hl			; SP = original stack address
	pop	hl			; restore the original  HL value

	ret

.bios_read_err:
	call	iputs
	db	"BIOS_READ FAILED!\r\n\0"

	ld	a,1			; tell CP/M the read failed
	jp	.bios_read_ret


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
.dmcache_write:

if .dmcache_debug >= 1
	push	bc
	call	iputs
	db	".dmcache_write entered, C=\0"
	pop	bc
	push	bc
	ld	a,c
	call	hexdump_a
	call	iputs
	db	": \0"
	call	bios_debug_disk
	pop	bc
endif

	; switch to a local stack (we only have a few levels when called from the BDOS!)
	push	hl			; save HL into the caller's stack
	ld	hl,0
	add	hl,sp			; HL = SP
	ld	sp,bios_stack		; SP = temporary private BIOS stack area
	push	hl			; save the old SP value in the BIOS stack

	push	bc			; save the register pairs we will otherwise clobber
	push	de			; this is not critical but may make WBOOT cleaner later

if 0
	;XXX This logic is ONLY legal when a track size is <= CP/M allocation block size
	; if C==2 then we are writing into an alloc block (and therefore an SD block) that is not dirty
	ld	a,2
	cp	c
	jr	nz,.bios_write_prerd	; if C!=2 then read the sector

	; C==2, no need to read the SD.  Just padd it with 0xe5.
	ld	hl,(disk_track)	; track to padd
	call	.cache_slot_padd
	jp	.bios_write_slot	; go to write logic (skip the SD card pre-read)
endif

	ld	hl,(disk_track)	; HL = CP/M track number to read
	call	.cache_slot_fill
	jr	z,.bios_write_slot	; If .cache_slot_fill is OK then continue

	call	iputs
	db	"BIOS_WRITE SD CARD CACHE SLOT FILL FAILED!\r\n\0"
	jp	.bios_write_err
.slot_flush_err:
	call	iputs
	db	"BIOS_WRITE SD CARD CACHE SLOT FLUSH FAILED!\r\n\0"
.bios_write_err:
	ld	a,1			; tell CP/M the write failed
	jp	.bios_write_ret

.bios_write_slot:
	call	.copy_ram2cache		; copy the write-data into the cache

	ld	hl,(disk_track)	; HL = CP/M track number to write
	call	.cache_slot_flush	; flush the cache slot to disk
	jr	nz,.slot_flush_err	; If .cache_slot_flush failed then return error 
	xor	a			; tell CP/M the write was OK

.bios_write_ret:
	pop	bc
	pop	de			; restore saved regs

	pop	hl			; HL = original saved stack pointer
	ld	sp,hl			; SP = original stack address
	pop	hl			; restore the original  HL value

	ret

if 0
;##########################################################################
; Calculate the address of the SD block, given the CP/M track number
; in HL and the fact that the currently selected drive's DPH is in 
; disk_dph.
; Clobbers: DE, HL, IX
; HL = CP/M track number
; Return: the 32-bit block number in DE,HL
; Based on proposal from Trevor Jacobs - 02-15-2023
;##########################################################################
.calc_sd_block:
        ld      ix,(disk_dph)           ; IX = current DPH base address
        ld      e,(ix+16)               ; DE = low-word of the SD starting block
        ld      d,(ix+17)               ; DE = low-word of the SD starting block
        add     hl,de
        push    hl
        ld      l,(ix+18)
        ld      h,(ix+19)
        ld      de,0
        adc     hl,de                   ; cy flag still set from add hl,de
        ld      e,l
        ld      d,h
        pop     hl
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
.dmcache_init:
	call    iputs
	db      'NOTICE: dmcache library installed.\r\n\0'

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
if .dmcache_debug >= 3
disk_dmcache_debug_wedge:

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




;##########################################################################
; Goal: Define a CP/M-compatible filesystem that can be implemented using
; an SDHC card.  An SDHC card is comprised of a number of 512-byte blocks.
;
; Plan:
; - Put 4 128-byte CP/M sectors into each 512-byte SDHC block.
; - Treat each SDHC block as a CP/M track.
;
; This CP/M filesystem has:
;  128 bytes/sector (CP/M requirement)
;  4 sectors/track (Retro BIOS designer's choice)
;  65536 total sectors (max CP/M limit)
;  65536*128 = 8388608 gross bytes (max CP/M limit)
;  65536/4 = 16384 tracks
;  8192 allocation block size BLS (Retro BIOS designer's choice)
;  8388608/8192 = 1024 gross allocation blocks in our filesystem
;  32 = number of reserved tracks to hold the O/S
;  32*512 = 16384 total reserved track bytes
;  floor(1024-16384/8192) = 1022 total allocation blocks, absent the reserved tracks
;  512 directory entries (Retro BIOS designer's choice)
;  512*32 = 16384 total bytes in the directory
;  ceiling(16384/8192) = 2 allocation blocks for the directory
;
;                  DSM<256   DSM>255
;  BLS  BSH BLM    ------EXM--------
;  1024  3    7       0         x
;  2048  4   15       1         0
;  4096  5   31       3         1
;  8192  6   63       7         3  <----------------------
; 16384  7  127      15         7
;
; ** NOTE: This filesystem design is inefficient because it is unlikely
;          that ALL of the allocation blocks will ultimately get used!
;
;##########################################################################
dmcache_dph:	macro sdblk_lo sdblk_hi
	dw	0		; XLT sector translation table (no xlation done)
	dw	0		; scratchpad
	dw	0		; scratchpad
	dw	0		; scratchpad
	dw	disk_dirbuf	; DIRBUF pointer
	dw	dmcache_dpb	; DPB pointer
	dw	0		; CSV pointer (optional, not implemented)
	dw	.alv		; ALV pointer
	dw	sdblk_lo	; +16	32-bit starting SD card block number
	dw	sdblk_hi	; +18

.alv:	ds	0
	ds	(1021/8)+1,0xaa	; scratchpad used by BDOS for disk allocation info
	endm

;##########################################################################
;##########################################################################
	dw	.dmcache_init
	dw	.dmcache_read
	dw	.dmcache_write
dmcache_dpb:
	dw	4		; SPT
	db	6		; BSH
	db	63		; BLM
	db	3		; EXM
	dw	1021		; DSM (max allocation block number)
	dw	511		; DRM
	db	0xc0		; AL0
	db	0x00		; AL1
	dw	0		; CKS
	dw	32		; OFF

