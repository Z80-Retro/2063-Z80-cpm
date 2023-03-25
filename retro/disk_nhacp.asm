;****************************************************************************
;
;	 Copyright (C) 2023 John Winans
;
;	 This library is free software; you can redistribute it and/or
;	 modify it under the terms of the GNU Lesser General Public
;	 License as published by the Free Software Foundation; either
;	 version 2.1 of the License, or (at your option) any later version.
;
;	 This library is distributed in the hope that it will be useful,
;	 but WITHOUT ANY WARRANTY; without even the implied warranty of
;	 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;	 Lesser General Public License for more details.
;
;	 You should have received a copy of the GNU Lesser General Public
;	 License along with this library; if not, write to the Free Software
;	 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301
;	 USA
;
; https://github.com/Z80-Retro/
;
;****************************************************************************

; An NHACP driver for network-mounted filesystems.

.dn_debug:         equ     1


;****************************************************************************
;****************************************************************************
disk_init:
if .dn_debug >= 1
	call    iputs
	db	"disk_init entered\r\n\0"
	ld	a,(.dn_disk)
endif
	call	nhacp_init		; init the low-level driver
	call	nhacp_start		; send the nhacp start message
	ret


;****************************************************************************
;****************************************************************************
disk_seldsk:
nhacp_seldsk:
        ld      a,c
        ld      (.dn_disk),a

if .dn_debug >= 2
	call    iputs
	db	"nhacp_seldsk entered\r\n\0"
	ld	a,(.dn_disk)
endif

	ld	hl,0			; default = invalid
	or	a
	ret	nz			; XXX only drive A is valid at the moment

	ld	hl,.dn_dph
	ret


;****************************************************************************
;****************************************************************************
disk_home:
nhacp_home:
	ld	bc,0			; just set the track number to zero
	ld	(.dn_track),bc

if .dn_debug >= 2
	call	iputs
	db	"nhacp_home entered:\r\n\0"
	call	.dn_dump_disk
endif
	ret

;****************************************************************************
;****************************************************************************
disk_settrk:
nhacp_settrk:
	ld	(.dn_track),bc
if .dn_debug >= 2
	call	iputs
	db	"nhacp_settrk entered:\r\n\0"
	call	.dn_dump_disk
endif
	ret



;****************************************************************************
;****************************************************************************
disk_setsec:
nhacp_setsec:
	ld	(.dn_sec),bc

if .dn_debug >= 2
	call	iputs
	db	"nhacp_setsec entered:\r\n\0"
	call	.dn_dump_disk
endif
	ret


;****************************************************************************
;****************************************************************************
disk_setdma:
nhacp_setdma:
	ld	(.dn_dma),bc

if .dn_debug >= 2
	call	iputs
	db	"nhacp_setdma entered:\r\n\0"
	call	.dn_dump_disk
endif
	ret



;****************************************************************************
; No skew factor.  1:1.
;****************************************************************************
disk_sectrn:
nhacp_sectrn:
	ld      h,b
	ld      l,c
	ret


;****************************************************************************
;****************************************************************************
disk_write:
nhacp_write:
if .dn_debug >= 1
	call	iputs
	db	"nhacp_write entered:\r\n\0"
	call	.dn_dump_disk
endif

	ld	a,1			; A = 1 = ERROR
	ret


;****************************************************************************
;****************************************************************************
disk_read:
nhacp_read:

if .dn_debug >= 1
	call	iputs
	db	"nhacp_read entered:\r\n\0"
	call	.dn_dump_disk
endif

	; padd the buffer as if reading a blank disk
	ld	hl,(.dn_dma)
	ld	de,(.dn_dma)
	inc	de
	ld	bc,127
	ld	(hl),0xe5
	ldir

	xor	a			; A = 0 = OK
	ret


if .dn_debug >= 1
.dn_dump_disk:
        call    iputs
        db      'disk=0x\0'

        ld      a,(.dn_disk)
        call    hexdump_a

        call    iputs
        db      ", track=0x\0"
        ld      a,(.dn_track+1)
        call    hexdump_a
        ld      a,(.dn_track)
        call    hexdump_a

        call    iputs
        db      ", sector=0x\0"
        ld      a,(.dn_sec+1)
        call    hexdump_a
        ld      a,(.dn_sec)
        call    hexdump_a

        call    iputs
        db      ", dma=0x\0"
        ld      a,(.dn_dma+1)
        call    hexdump_a
        ld      a,(.dn_dma)
        call    hexdump_a
        call    puts_crlf

        ret
endif


;****************************************************************************
;****************************************************************************
.dn_dma:
	dw	0
.dn_disk:
	dw	0
.dn_track:
	dw	0
.dn_sec:
	dw	0	



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
;  8192 allocation block size BLS (Retro BIOS designer's choice)
;  8388608/8192 = 1024 gross allocation blocks in our filesystem
;  0 = number of reserved tracks to hold the O/S
;  0*128 = 0 total reserved track bytes
;  floor(1024-0/8192) = 1024 total allocation blocks
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
;##########################################################################
.dn_dph:
        dw      0               ; XLT sector translation table (no xlation done)
        dw      0               ; scratchpad
        dw      0               ; scratchpad
        dw      0               ; scratchpad
        dw      disk_dirbuf   	; system-wide, shared DIRBUF pointer
        dw      .dn_dpb_a    ; DPB pointer
        dw      0               ; CSV pointer (optional, not implemented)
        dw      .dn_alv_a    ; ALV pointer

.dn_dpb_a:
        dw      1               ; SPT
        db      6               ; BSH
        db      63              ; BLM
        db      3               ; EXM
        dw      1023            ; DSM (max allocation block number)
        dw      511             ; DRM
        db      0xc0            ; AL0
        db      0x00            ; AL1
        dw      0               ; CKS
        dw      0               ; OFF

.dn_alv_a:
	ds	(1023/8)+1,0xaa	; scratchpad used by BDOS for disk allocation info


include 'nhacp.asm'
