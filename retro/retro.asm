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
;
;****************************************************************************

.debug:		equ	0		; set to 1 for debug printing, 0 for not

include	'io.asm'
include	'memory.asm'

.stacktop:	equ	0x0000		; end of RAM


	org	LOAD_BASE		; Where the boot loader places this code.

	; This is the entry point from the boot loader.
	jp	.bios_boot

	; The 'org' in cpm22.asm does not generate any fill so we must
	; padd memory out to the base location of CP/M
	ds	CPM_BASE-$,0xff


;##########################################################################
;
; In a traditional system, the CP/M CCP and BDOS is manually copied into
; place when linking it with the BIOS.  
;
; In this build we cheat by simply compiling the CP/M source in with the 
; BIOS.
;
;##########################################################################

include 'cpm22.asm'


;##########################################################################
;
; The BIOS vector table has to have its entries named AND located precisely
; to match the included CP/M code above.  
;
; Specifically, the BIOS branch vectors must start at CPM_BASE+0x1600.  
;
;##########################################################################
if $ != CPM_BASE+0x1600
	ERROR	THE BIOS VECTOR TABLE IS IN THE WRONG PLACE
endif

BOOT:   JP      .bios_boot
WBOOT:  JP      .bios_wboot
CONST:  JP      .bios_const
CONIN:  JP      .bios_conin
CONOUT: JP      .bios_conout
LIST:   JP      .bios_list
PUNCH:  JP      .bios_punch
READER: JP      .bios_reader
HOME:   JP      .bios_home
SELDSK: JP      .bios_seldsk
SETTRK: JP      .bios_settrk
SETSEC: JP      .bios_setsec
SETDMA: JP      .bios_setdma
READ:   JP      .bios_read
WRITE:  JP      .bios_write
PRSTAT: JP      .bios_prstat
SECTRN: JP      .bios_sectrn




;##########################################################################
;
; CP/M 2.2 Alteration Guide p17:
; The BOOT entry point gets control from the cold start loader and is
; responsible for basic system initialization, including sending a signon
; message (which can be omitted in the first version).
;
; If the IOBYTE function is implemented, it must be set at this point.
;
; The various system parameters which are set by the WBOOT entry point
; must be initialized, and control is transferred to the CCP at
; 3400H+b for further processing.  
;
; Note that reg C must be set to zero to select drive A.
;
;##########################################################################

.bios_boot:
	; This will select low-bank 0 and idle the SD card and printer
	ld	a,gpio_out_sd_mosi|gpio_out_sd_clk|gpio_out_sd_ssel|gpio_out_prn_stb
	ld	(gpio_out_cache),a
	out	(gpio_out),a

	; make sure we have a viable stack
	ld	sp,.stacktop

	call	.init_console		; Note: console should still be initialized from the boot loader

	; Display a hello world message.
	ld	hl,.boot_msg
	call	puts

	jp	.go_cpm


.boot_msg:
	defb	'\r\n\n'
	defb	'Z80 Retro BIOS Copyright (C) 2021 John Winans\r\n'
	defb	'CP/M 2.2 Copyright (C) 1979 Digital Research\r\n'
	defb	'  git: @@GIT_VERSION@@\r\n'
	defb	'build: @@DATE@@\r\n'
	defb	'\n'
	defb	'\0'


.bios_wboot:
	call	iputs
	db	".bios_wboot entered\r\n\0"
	; XXX finish me


.go_cpm:
	ld	a,0xc3		; opcode for JP
	ld	(0),a
	ld	hl,WBOOT
	ld	(1),hl		; address 0 now = JP WBOOT

	ld	(5),a		; opcode for JP
	ld	hl,FBASE
	ld	(6),hl		; address 6 now = JP FBASE
	
	ld	c,0
	jp	CPM_BASE	; start the CCP
	


.bios_const:
	; A = 0xff if ready
	call	con_rx_ready
	ret	z		; a = 0 = not ready
	ld	a,0xff
	ret			; a = 0xff = ready

.bios_conin:
	; return char in A
	jp	con_rx_char

.bios_conout:
	; print char in C
	jp	con_tx_char

.bios_list:
	ret

.bios_punch:
	ret

.bios_reader:
	ld	a,0x1a
	ret

.bios_home:
	call	iputs
	db	".bios_home entered\r\n\0"
	ld	bc,0
	; fall into .bios_settrk

.bios_settrk:
	call	iputs
	db	".bios_settrk entered\r\n\0"
	ld	(.disk_track),bc
	ret

.bios_seldsk:
	call	iputs
	db	".bios_seldsk entered\r\n\0"
	ld	a,c
	ld	(.disk_disk),a
	ld	hl,0			; XXX finish this!
	ret

.bios_setsec:
	call	iputs
	db	".bios_setsec entered\r\n\0"
	ld	(.disk_sector),bc
	ret

.bios_setdma:
	call	iputs
	db	".bios_setdma entered\r\n\0"
	ld	(.disk_dma),bc
	ret

.bios_read:
	call	iputs
	db	".bios_read entered\r\n\0"
	ld	a,1	; XXX 
	ret

.bios_write:
	call	iputs
	db	".bios_write entered\r\n\0"
	ld	a,1	; XXX 
	ret

.bios_prstat:
	ld	a,0		; printer is never ready
	ret

.bios_sectrn:
	; 1:1 translation  (no skew factor)
	ld	h,b
	ld	l,c
	ret


;##########################################################################
; Initialize the console port.  Note that this includes CTC port 1.
;##########################################################################
.init_console:
	;ld	c,6			; C = 6 = 19200 bps
	ld	c,12			; C = 12 = 9600 bps
	call	init_ctc_1		; start CTC1 in case J11-A selects it!
	call	sioa_init		; 115200 or 19200/9600 depending on J11-A
	ret



;##########################################################################
.disk_dma:
	dw	0x80			; default DMA address = 0x80

.disk_track:
	dw	0x0

.disk_disk:
	db	0x0

.disk_sector:
	dw	0x0



;##########################################################################
; Libraries
;##########################################################################

include 'sio.asm'
include 'ctc1.asm'
include 'puts.asm'
include 'hexdump.asm'
;include 'sdcard.asm'
;include 'spi.asm'

;##########################################################################
; General save areas
;##########################################################################
gpio_out_cache: ds  1
