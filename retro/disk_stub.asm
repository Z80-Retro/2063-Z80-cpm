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


; stubbed in read and write logic for testing a simulated blank read-only disk

.stub_debug:		equ	0

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
.stub_read:
if .stub_debug >= 1
	call	iputs
	db	".stub_read entered: \0"
	call	disk_dump
endif

	; fake a 'blank'/formatted sector
	ld	hl,(disk_dma)		; HL = buffer address
	ld	de,(disk_dma)
	inc	de			; DE = buffer address + 1
	ld	bc,0x007f		; BC = 127
	ld	(hl),0xe5
	ldir				; set 128 bytes from (hl) to 0xe5
	xor	a			; A = 0 = OK

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
.stub_write:

if .stub_debug >= 1
	push	bc
	call	iputs
	db	".stub_write entered, C=\0"
	pop	bc
	push	bc
	ld	a,c
	call	hexdump_a
	call	iputs
	db	": \0"
	call	disk_dump
	pop	bc
endif
	ld	a,1
	ret			; 100% error!



;##########################################################################
; Called once before library is used.
;##########################################################################
.stub_init:
	call	iputs
	db	'NOTICE: disk_stub library installed. All disk I/O disabled.\r\n\0'
	ret


;##########################################################################
; Define a CP/M-compatible filesystem intended to be network-mounted 
; using NHACP.
;
; This defines the disk as having 1 sector on each track.  This will 
; allow the track number on its own to represent the sector number to
; transfer in calls to nhacp_write and nhacp_read.
;
; This CP/M filesystem has:
;  128 bytes/sector (CP/M requirement)
;  1 sector/track (Retro BIOS designer's choice)
;  65536 total sectors (max CP/M limit)
;  65536*128 = 8388608 gross bytes (max CP/M limit)
;  65536/1 = 65536 tracks
;  16384 allocation block size BLS (Retro BIOS designer's choice)
;  8388608/16384 = 512 gross allocation blocks in our filesystem
;  0 = number of reserved tracks to hold the O/S
;  0*128 = 0 total reserved track bytes
;  floor(1024-0/16384) = 512 total allocation blocks
;  512 directory entries (Retro BIOS designer's choice)
;  512*32 = 16384 total bytes in the directory
;  ceiling(16384/16384) = 1 allocation blocks for the directory
;
;                  DSM<256   DSM>255
;  BLS  BSH BLM    ------EXM--------
;  1024  3    7       0         x
;  2048  4   15       1         0
;  4096  5   31       3         1
;  8192  6   63       7         3 
; 16384  7  127      15         7  <----------------------
;
;##########################################################################
stub_dph:	macro
        dw      0               ; XLT sector translation table (no xlation done)
        dw      0               ; scratchpad
        dw      0               ; scratchpad
        dw      0               ; scratchpad
        dw      disk_dirbuf   	; system-wide, shared DIRBUF pointer
        dw      stub_dpb	; DPB pointer
        dw      0               ; CSV pointer (optional, not implemented)
        dw      .alv		; ALV pointer
.alv:	ds	0
	ds	(512/8)+1,0xaa	; scratchpad used by BDOS for disk allocation info
	endm


;##########################################################################
;##########################################################################
	dw	.stub_init	; .dpb-6
	dw	.stub_read	; .dpb-4
	dw	.stub_write	; .dpb-2
stub_dpb:
        dw      1		; SPT
        db      7		; BSH
        db      127		; BLM
        db      7		; EXM
        dw      512		; DSM (max allocation block number)
        dw      511             ; DRM
        db      0x80            ; AL0
        db      0x00            ; AL1
        dw      0               ; CKS
        dw      0               ; OFF


