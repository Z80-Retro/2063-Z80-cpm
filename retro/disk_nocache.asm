;****************************************************************************
;
;    Z80 Retro! BIOS 
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


;##########################################################################
; set .nc_debug to:
;    0 = no debug output
;    1 = print messages from new code under development
;    2 = print all the above plus the primairy 'normal' debug messages
;    3 = print all the above plus verbose 'noisy' debug messages
;##########################################################################
.nc_debug:		equ	0


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
.nocache_read:
if .nc_debug >= 1
	call	iputs
	db	".nocache_read entered: \0"
	call	disk_dump
endif

	; switch to a local stack (we only have a few levels when called from the BDOS!)
	push	hl			; save HL into the caller's stack
	ld	hl,0
	add	hl,sp			; HL = SP
	ld	sp,bios_stack		; SP = temporary private BIOS stack area
	push	hl			; save the old SP value in the BIOS stack

	push	bc			; save the register pairs we will otherwise clobber
	push	de			; this is not critical but may make WBOOT cleaner later

	ld	hl,(disk_track)	; HL = CP/M track number

	;Check to see if the disk number has changed - Trevor Jacobs - 02-15-2023
	ld	a,(disk_dph)
	ld	b,a
	ld	a,(.disk_dph_last)
	cp	b
	jp	nz,.read_block		; not the same, force a new read

	ld	a,(disk_dph+1)
	ld	b,a
	ld	a,(.disk_dph_last+1)
	cp	b
	jp	nz,.read_block		; not the same, force a new read

	; Check to see if the SD block in .sdbuf is already the one we want
	ld	a,(.sdbuf_val)		; get the .sdbuf valid flag
	or	a			; is it a non-zero value?
	jr	nz,.read_block		; block buffer is invalid, read the SD block

	ld	a,(.sdbuf_trk)		; A = CP/M track LSB
	cp	l			; is it the one we want?
	jr	nz,.read_block		; LSB does not match, read the SD block

	ld	a,(.sdbuf_trk+1)	; A = CP/M track MSB
	cp	h			; is it the one we want?
	jr	z,.read_sd_ok		; The SD block in .sdbuf is the one we want!

.read_block:
if .nc_debug >= 2
	call	iputs
	db	".nocache_read cache miss: \0"
	call	disk_dump
endif
	; Remember drive that is in the cache - Trevor Jacobs - 02-15-2023
	ld	de,(disk_dph)
	ld	(.disk_dph_last),de

	; Assume all will go well reading the SD card block.
	; We only need to touch this if we are going to actually read the SD card.
	ld	(.sdbuf_trk),hl		; store the current CP/M track number in the .sdbuf
	xor	a			; A = 0
	ld	(.sdbuf_val),a		; mark the .sdbuf as valid

	call	.calc_sd_block		; DE,HL = partition_base + HL

	; push the 32-bit physical SD block number into the stack in little-endian order
	push	de			; 32-bit SD block number (big end)
	push	hl			; 32-bit SD block number (little end)
	ld	de,.sdbuf		; DE = target buffer to read the 512-byte block
	call	sd_cmd17		; read the SD block
	pop	hl			; clean the SD block number from the stack
	pop	de

	or	a			; was the SD driver read OK?
	jr	z,.read_sd_ok

	call	iputs
	db	"BIOS_READ FAILED!\r\n\0"
	ld	a,1			; tell CP/M the read failed
	ld	(.sdbuf_val),a		; mark the .sdbuf as invalid
	jp	.read_ret

.read_sd_ok:

	; calculate the CP/M sector offset address (disk_sec*128)
	xor	a			;clear a, clear carry
	ld	l,a
	ld	a,(disk_sec)		; must be less than 16
	rra				; divide a by 2, remainder into carry
	rr	l			; carry into l
	ld	h,a			; HL = A*128

	; calculate the address of the CP/M sector in the .sdbuf
	ld	bc,.sdbuf
	add	hl,bc			; HL = @ of cpm sector in the .sdbuf

	; copy the data of interest from the SD block
	ld	de,(disk_dma)		; target address
	ld	bc,0x0080		; number of bytes to copy
	ldir

	xor	a			; A = 0 = read OK

.read_ret:
	pop	de			; restore saved regs
	pop	bc

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
.nocache_write:

if .nc_debug >= 1
	push	bc
	call	iputs
	db	".nocache_write entered, C=\0"
	pop	bc
	push	bc
	ld	a,c
	call	hexdump_a
	call	iputs
	db	": \0"
	call	disk_dump
	pop	bc
endif

	; switch to a local stack (we only have a few levels when called from the BDOS!)
	push	hl			; save HL into the caller's stack
	ld	hl,0
	add	hl,sp			; HL = SP
	ld	sp,bios_stack		; SP = temporary private BIOS stack area
	push	hl			; save the old SP value in the BIOS stack

	push	de			; save the register pairs we will otherwise clobber
	push	bc

	ld	hl,(disk_track)		; HL = CP/M track number

	;Check to see if the disk number has changed - Trevor Jacobs - 02-15-2023
	ld	a,(disk_dph)
	ld	b,a
	ld	a,(.disk_dph_last)
	cp	b
	jp	nz,.write_miss		; not the same, force a new read

	ld	a,(disk_dph+1)
	ld	b,a
	ld	a,(.disk_dph_last+1)
	cp	b
	jp	nz,.write_miss		; not the same, force a new read

	; Check to see if the SD block in .sdbuf is already the one we want
	ld	a,(.sdbuf_val)		; get the .sdbuf valid flag
	or	a			; is it a non-zero value?
	jr	nz,.write_miss		; block buffer is invalid, pre-read the SD block

	ld	a,(.sdbuf_trk)		; A = CP/M track LSB
	cp	l			; is it the one we want?
	jr	nz,.write_miss		; LSB does not match, pre-read the SD block

	ld	a,(.sdbuf_trk+1)	; A = CP/M track MSB
	cp	h			; is it the one we want?
	jp	z,.write_sdbuf		; The SD block in .sdbuf is the one we want!

.write_miss:
if .nc_debug >= 1
	call	iputs
	db	".write cache miss: \0"
	call	bios_debug_disk
endif
	; Remember drive that is in the cache - Trevor Jacobs - 02-15-2023
	ld	de,(disk_dph)
	ld	(.disk_dph_last),de

	; Assume all will go well reading the SD card block.
	; We only need to touch this if we are going to actually read the SD card.
	ld	(.sdbuf_trk),hl		; store the current CP/M track number in the .sdbuf
	xor	a			; A = 0
	ld	(.sdbuf_val),a		; mark the .sdbuf as valid

	; if C==2 then we are writing into an alloc block (and therefore an SD block) that is not dirty
	pop	bc			; restore C in case was clobbered above
	push	bc
	ld	a,2
	cp	c
	jr	nz,.write_prerd

	; padd the SD buffer with all 0xe5
	ld	hl,.sdbuf		; buffer to initialize
	ld	de,.sdbuf+1		; buffer+1
	ld	bc,0x1ff		; number of bytes to initialize
	ld	(hl),0xe5		; set the first byte to 0xe5
	ldir				; set the rest of the bytes to 0xe5
	jp	.write_sdbuf		; go to write logic (skip the SD card pre-read)

.write_prerd:
	; pre-read the block so we can replace one sector and write it back

	call	.calc_sd_block		; DE,HL = partition_base + HL

	; push the 32-bit physical SD block number into the stack in little-endian order
	push	de			; 32-bit SD block number (big end)
	push	hl			; 32-bit SD block number (little end)
	ld	de,.sdbuf		; DE = target buffer to read the 512-byte block
	call	sd_cmd17		; pre-read the SD block
	pop	hl			; clean the SD block number from the stack
	pop	de

	or	a			; was the SD driver read OK?
	jr	z,.write_sdbuf

	call	iputs
	db	"BIOS_WRITE SD CARD PRE-READ FAILED!\r\n\0"
	ld	a,1			; tell CP/M the read failed
	ld	(.sdbuf_val),a		; mark the .sdbuf as invalid
	jp	.write_ret

.write_sdbuf:
	; calculate the CP/M sector offset address (disk_sec*128)
	xor	a			;clear a, clear carry
	ld	l,a
	ld	a,(disk_sec)		; must be less than 16
	rra				; divide a by 2, remainder into carry
	rr	l			; carry into l
	ld	h,a			; HL = A*128

	; calculate the address of the CP/M sector in the .sdbuf
	ld	bc,.sdbuf
	add	hl,bc			; HL = @ of cpm sector in the .sdbuf
	ld	d,h
	ld	e,l			; DE = @ of cpm sector in the .sdbuf

	; copy the data of interest /into/ the SD block
	ld	hl,(disk_dma)		; source address
	ld	bc,0x0080		; number of bytes to copy
	ldir

	; write the .sdbuf contents to the SD card
	ld      hl,(disk_track)
	call	.calc_sd_block		; DE,HL = partition_base + HL

	push	de			; SD block number to write
	push	hl
	ld	de,.sdbuf		; DE = target buffer to read the 512-byte block
	call	sd_cmd24		; write the SD block
	pop	hl			; clean the SD block number from the stack
	pop	de

	or	a
	jr	z,.write_ret

	call	iputs
	db	"BIOS_WRITE SD CARD WRITE FAILED!\r\n\0"
	ld	a,1			; tell CP/M the read failed
	ld	(.sdbuf_val),a		; mark the .sdbuf as invalid

.write_ret:
	pop	bc
	pop	de			; restore saved regs

	pop	hl			; HL = original saved stack pointer
	ld	sp,hl			; SP = original stack address
	pop	hl			; restore the original  HL value

	ret


;##########################################################################
; Calculate the address of the SD block, given the CP/M track number
; in HL and the fact that the currently selected drive's DPH is in 
; disk_dph.
; HL = CP/M track number
; Return: the 32-bit block number in DE,HL
; Based on proposal from Trevor Jacobs - 02-15-2023
;##########################################################################
.calc_sd_block:
	ld	ix,(disk_dph)		; IX = current DPH base address
	ld	e,(ix+16)		; DE = low-word of the SD starting block
	ld	d,(ix+17)		; DE = low-word of the SD starting block
	add	hl,de
	push 	hl
	ld	l,(ix+18)
	ld	h,(ix+19)
	ld	de,0
	adc	hl,de			; cy flag still set from add hl,de
	ld	e,l
	ld	d,h
	pop	hl

	; add the partition offset
	ld	a,(disk_offset_low)
	add	l
	ld	l,a
	ld	a,(disk_offset_low+1)
	adc	a,h			; cy flag still set from prior add
	ld	h,a
	ld	a,(disk_offset_hi)
	adc	a,e
	ld	e,a
	ld	a,(disk_offset_hi+1)
	adc	a,d
	ld	d,a
	ret


;##########################################################################
; A single SD block cache
;##########################################################################
.sdbuf_trk:			; The CP/M track number last left in the .sdbuf
	ds	2,0xff		; initial value = garbage
.sdbuf_val:			; The CP/M track number in .sdbuf_trk is valid when this is 0
	ds	1,0xff		; initial value = INVALID
.sdbuf:				; scratch area to use for SD block reading and writing
	ds	512,0xa5	; initial value = garbage
.disk_dph_last:			; the drive that has a block in the cache
	dw	0		; an impossible DPH address


;##########################################################################
; Called once before library is used.
;##########################################################################
.nocache_init:
;	call	iputs
;	db	'NOTICE: disk_nocache library installed. Disk cache disabled.\r\n\0'

	ld	a,1
	ld	(.sdbuf_val),a	; mark .sdbuf_trk as invalid

	ret


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

nocache_dph:	macro	sdblk_hi sdblk_lo
	dw	0		; +0 XLT sector translation table (no xlation done)
	dw	0		; +2 scratchpad
	dw	0		; +4 scratchpad
	dw	0		; +6 scratchpad
	dw	disk_dirbuf	; +8 DIRBUF pointer
	dw	nocache_dpb	; +10 DPB pointer
	dw	0		; +12 CSV pointer (optional, not implemented)
	dw	.alv		; +14 ALV pointer
	dw	sdblk_lo	; +16	32-bit starting SD card block offset
	dw	sdblk_hi	; +18

.alv:	ds	0
	ds	(1021/8)+1,0xaa	; scratchpad used by BDOS for disk allocation info

	endm

;##########################################################################
; The DPB is shared by all the SD drives.
;##########################################################################
	dw	.nocache_init	; .sd_dpb-6	pointer to the init function
	dw	.nocache_read	; .sd_dpb-4	pointer to the read function
	dw	.nocache_write	; .sd_dpb-2	pointer to the write function
nocache_dpb:
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

