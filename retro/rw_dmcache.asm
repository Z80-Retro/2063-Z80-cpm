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


;##########################################################################
; set .rw_debug to:
;    0 = no debug output
;    1 = print messages from new code under development
;    2 = print all the above plus the primairy 'normal' debug messages
;    3 = print all the above plus verbose 'noisy' debug messages
;##########################################################################
.rw_debug:		equ	1


; XXX This is a hack that won't work unless the disk partition < 0x10000
; XXX This has the SD card partition offset hardcoded in it!!!
.sd_partition_base: equ	0x800


;##########################################################################
; Calc the cache slot number from the CP/M track number
;
; HL = track number
; return: HL=slot number
;##########################################################################
.dmt2s:
	ld	h,0
	ret

;##########################################################################
; Convert a cache slot number in HL to the bank number wherein the slot 
; is stored.
;
; L=slot number (H must be zero and is ignored here)
; return: A=blank number
;##########################################################################
.dms2b:
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
.dms2a:
	ld	a,l		; A = xxAA AAAA
	rlca			; A = xAAA AAAx
	and	0x7e		; A = 0AAA AAA0
	ld	h,a		; HL = 0AAA AAA0 xxAA AAAA
	ld	l,0		; HL = 0AAA AAA0 0000 0000
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



	; Test the conversion routines

	call	iputs
	db	"DM cache slot=\0"

	ld      hl,(bios_disk_track)
	call	.dmt2s

	ld	a,h
	call	hexdump_a
	ld	a,l
	call	hexdump_a


	call	iputs
	db	", bank=\0"

	ld      hl,(bios_disk_track)
	call	.dmt2s
	call	.dms2b

	call	hexdump_a


	call	iputs
	db	', address=\0'

	ld      hl,(bios_disk_track)
	call	.dmt2s
	call	.dms2a

	ld	a,h
	call	hexdump_a
	ld	a,l
	call	hexdump_a

	call	puts_crlf








if 0
	; fake a 'blank'/formatted sector
	ld	hl,(bios_disk_dma)		; HL = buffer address
	ld	de,(bios_disk_dma)
	inc	de			; DE = buffer address + 1
	ld	bc,0x007f		; BC = 127
	ld	(hl),0xe5
	ldir				; set 128 bytes from (hl) to 0xe5
	xor	a			; A = 0 = OK
else
	; switch to a local stack (we only have a few levels when called from the BDOS!)
	push	hl			; save HL into the caller's stack
	ld	hl,0
	add	hl,sp			; HL = SP
	ld	sp,bios_stack		; SP = temporary private BIOS stack area
	push	hl			; save the old SP value in the BIOS stack

	push	bc			; save the register pairs we will otherwise clobber
	push	de			; this is not critical but may make WBOOT cleaner later

	ld	hl,(bios_disk_track)	; HL = CP/M track number

	; Check to see if the SD block in .bios_sdbuf is already the one we want
	ld	a,(.bios_sdbuf_val)	; get the .bios_sdbuf valid flag
	or	a			; is it a non-zero value?
	jr	nz,.bios_read_block	; block buffer is invalid, read the SD block

	ld	a,(.bios_sdbuf_trk)	; A = CP/M track LSB
	cp	l			; is it the one we want?
	jr	nz,.bios_read_block	; LSB does not match, read the SD block

	ld	a,(.bios_sdbuf_trk+1)	; A = CP/M track MSB
	cp	h			; is it the one we want?
	jr	z,.bios_read_sd_ok	; The SD block in .bios_sdbuf is the one we want!

.bios_read_block:
if .rw_debug >= 2
	call	iputs
	db	"bios_read cache miss: \0"
	call	bios_debug_disk
endif

	; Assume all will go well reading the SD card block.
	; We only need to touch this if we are going to actually read the SD card.
	ld	(.bios_sdbuf_trk),hl	; store the current CP/M track number in the .bios_sdbuf
	xor	a			; A = 0
	ld	(.bios_sdbuf_val),a	; mark the .bios_sdbuf as valid

	ld	de,.sd_partition_base	; XXX add the starting partition block number
	add	hl,de			; HL = SD physical block number

	; push the 32-bit physical SD block number into the stack in little-endian order
	ld	de,0
	push	de			; 32-bit SD block number (big end)
	push	hl			; 32-bit SD block number (little end)
	ld	de,.bios_sdbuf		; DE = target buffer to read the 512-byte block
	call	sd_cmd17		; read the SD block
	pop	hl			; clean the SD block number from the stack
	pop	de

	or	a			; was the SD driver read OK?
	jr	z,.bios_read_sd_ok

	call	iputs
	db	"BIOS_READ FAILED!\r\n\0"
	ld	a,1			; tell CP/M the read failed
	ld	(.bios_sdbuf_val),a	; mark the .bios_sdbuf as invalid
	jp	.bios_read_ret

.bios_read_sd_ok:

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

	; copy the data of interest from the SD block
	ld	de,(bios_disk_dma)		; target address
	ld	bc,0x0080		; number of bytes to copy
	ldir

	xor	a			; A = 0 = read OK

.bios_read_ret:
	pop	de			; restore saved regs
	pop	bc

	pop	hl			; HL = original saved stack pointer
	ld	sp,hl			; SP = original stack address
	pop	hl			; restore the original  HL value
endif

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



;##########################################################################
; A single SD block cache
;##########################################################################
.bios_sdbuf_trk:                ; The CP/M track number last left in the .bios_sdbuf
        ds      2,0xff          ; initial value = garbage
.bios_sdbuf_val:                ; The CP/M track number in .bios_sdbuf_trk is valid when this is 0
        ds      1,0xff          ; initial value = INVALID
.bios_sdbuf:                    ; scratch area to use for SD block reading and writing
        ds      512,0xa5        ; initial value = garbage


;##########################################################################
; Called once before library is used.
;##########################################################################
rw_init:
	call    iputs
	db      'NOTICE: rw_dmcache library installed.\r\n\0'

        ld      a,1
        ld      (.bios_sdbuf_val),a     ; mark .bios_sdbuf_trk as invalid

        ret

