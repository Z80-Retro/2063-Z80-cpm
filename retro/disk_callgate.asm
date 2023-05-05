;****************************************************************************
;
;	 Copyright (C) 2021,2022,2023 John Winans
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

; A call-gate that directs disk subroutine calls into the correct
; driver based on which drive is being referred to.


.disk_debug:	equ	0


;****************************************************************************
; For each drive, find the init function from the DPH->DPB and call it.
;****************************************************************************
disk_init:

if .disk_debug >= 1
        call    iputs
        db      "disk_init entered: \0"
        call    disk_dump
endif

	ld	iy,dph_vec		; IY = &dph_vec
	ld	b,dph_vec_num		; count to initialize
.init_loop:
	ld	l,(iy+0)
	ld	h,(iy+1)		; HL = dph[0]
	ld	(disk_dph),hl		; set disk_dph in case it is needed

	push	hl
	pop	ix			; IX = dph[0]

	ld	l,(ix+10)
	ld	h,(ix+11)
	push	hl
	pop	ix			; IX = DPB address

	ld	l,(ix-6)
	ld	h,(ix-5)		; HL = disk init func address

	push	iy
	push	bc
	call	.jphl			; call the function HL points to
	pop	bc
	pop	iy

	inc	iy			; point to the next table entry
	inc	iy

	djnz	.init_loop

	ret

.jphl:
	jp	(hl)			; go to the address in HL register


;****************************************************************************
;****************************************************************************
disk_seldsk:

if .disk_debug >= 2
	push	bc
	call    iputs
	db	"disk_seldsk entered\r\n\0"
	pop	bc
endif
	; check if the disk is valid
        ld      a,c
	cp	dph_vec_num
	jr	nc,.seldsk_fail		; if (a >= dph_vec_num) then error

        ld      (disk_disk),a

	; disk is valid, find the DPH
	ld	hl,dph_vec		; default = invalid
	sla	a			; A = A * 2
	ld	c,a
	ld	b,0
	add	hl,bc			; HL = HL + A * 2
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,0
	add	hl,bc			; HL = DPH for drive n
	push	hl

	ld	(disk_dph),hl		; save the current DPH for reference

	; find and make handy the read and write handler pointers
	push	hl
	pop	ix			; IX = DPH for drive n

	ld	l,(ix+10)
	ld	h,(ix+11)
if 0
	push 	hl
	call	iputs
	db	"ix=\0"
	push	ix
	pop	de
	ld	a,d
	call	hexdump_a
	ld	a,e
	call	hexdump_a

	call	iputs
	db	", hl=\0"
	ld	a,h
	call	hexdump_a
	ld	a,l
	call	hexdump_a

	call	iputs
	db	"\r\nvars:\r\n\0"

	ld	hl,disk_dma
	ld	bc,16
	ld	e,1
	call	hexdump	
	pop	hl
endif

	push	hl
	pop	ix			; IX = DPB address

	ld	l,(ix-4)
	ld	h,(ix-3)		; HL = disk read func address
	ld	(.cur_disk_read),hl
	ld	l,(ix-2)
	ld	h,(ix-1)		; HL = disk write func address
	ld	(.cur_disk_write),hl

if 0
	call	iputs
	db	"disk_seldsk: iy=\0"
	push	iy
	pop	de
	ld	a,d
	call	hexdump_a
	ld	a,e
	call	hexdump_a

	call	iputs
	db	", ix=\0"
	push	ix
	pop	de
	ld	a,d
	call	hexdump_a
	ld	a,e
	call	hexdump_a

	call	iputs
	db	", hl=\0"
	ld	a,h
	call	hexdump_a
	ld	a,l
	call	hexdump_a

	call	iputs
	db	"\r\nvars:\r\n\0"
	
	ld	hl,disk_dma
	ld	bc,16
	ld	e,1
	call	hexdump	
endif

	pop	hl		; HL = DPH
	ret


.seldsk_fail:
	; if the disk select failed, make sure we don't get wierd
	ld	hl,0
	ld	(disk_dph),hl
	ld	(.cur_disk_read),hl
	ld	(.cur_disk_write),hl

	ret			; HL = 0 = fail


;****************************************************************************
;****************************************************************************
disk_home:
	ld	bc,0			; just set the track number to zero
	ld	(disk_track),bc

if .disk_debug >= 2
	call	iputs
	db	"disk_home entered:\r\n\0"
	call	disk_dump
endif
	ret

;****************************************************************************
;****************************************************************************
disk_settrk:
	ld	(disk_track),bc
if .disk_debug >= 2
	call	iputs
	db	"disk_settrk entered:\r\n\0"
	call	disk_dump
endif
	ret



;****************************************************************************
;****************************************************************************
disk_setsec:
	ld	(disk_sec),bc

if .disk_debug >= 2
	call	iputs
	db	"disk_setsec entered:\r\n\0"
	call	disk_dump
endif
	ret


;****************************************************************************
;****************************************************************************
disk_setdma:
	ld	(disk_dma),bc

if .disk_debug >= 2
	call	iputs
	db	"disk_setdma entered:\r\n\0"
	call	disk_dump
endif
	ret



;****************************************************************************
; No skew factor.  1:1.
;****************************************************************************
disk_sectrn:
	ld      h,b
	ld      l,c
	ret


;****************************************************************************
;****************************************************************************
disk_write:
if .disk_debug >= 1
	call	iputs
	db	"disk_write entered:\r\n\0"
	call	disk_dump
endif
	ld	hl,(.cur_disk_write)
	ld	a,h
	or	l
	jr	z,.disk_fail
	jp	(hl)			; tail-call the driver

.disk_fail:
	ld	a,1			; A = 1 = ERROR
	ret


;****************************************************************************
;****************************************************************************
disk_read:
if .disk_debug >= 1
	call	iputs
	db	"disk_read entered:\r\n\0"
	call	disk_dump
endif

	ld	hl,(.cur_disk_read)
	ld	a,h
	or	l
	jr	z,.disk_fail
	jp	(hl)			; tail-call the driver



;****************************************************************************
;****************************************************************************
if .disk_debug >= 1
disk_dump:
        call    iputs
        db      'disk=0x\0'

        ld      a,(disk_disk)
        call    hexdump_a

        call    iputs
        db      ", track=0x\0"
        ld      a,(disk_track+1)
        call    hexdump_a
        ld      a,(disk_track)
        call    hexdump_a

        call    iputs
        db      ", sector=0x\0"
        ld      a,(disk_sec+1)
        call    hexdump_a
        ld      a,(disk_sec)
        call    hexdump_a

        call    iputs
        db      ", dma=0x\0"
        ld      a,(disk_dma+1)
        call    hexdump_a
        ld      a,(disk_dma)
        call    hexdump_a
        call    puts_crlf

        ret
endif


;****************************************************************************
; These are global because they are read by the disk drivers.
;****************************************************************************
disk_dma:
	dw	0		; The current DMA address
disk_disk:
	db	0		; The currently selected disk (only 8-bits used for this one!)
disk_track:
	dw	0		; The current track
disk_sec:
	dw	0		; The current sector
disk_dph:
	dw	0		; The DPH of the currently selected disk


; When running from a disk/SD, disk_offset_xxx represent the physical
; address of the starting block number.
disk_offset_low:
	dw	0x0800		; backward compatible default block number
disk_offset_hi:
	dw	0x0000


;****************************************************************************
; When a disk is selected, the address of the READ and WRITE driver 
; functions are cached here so that future calls to same will be 
; dispatched appropriately. 
; @see disk_seldsk
;****************************************************************************
.cur_disk_read:
	dw	0
.cur_disk_write:
	dw	0

include 'disk_config.asm'
