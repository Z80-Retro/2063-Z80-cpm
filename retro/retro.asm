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

	jp	.halt_loop


.boot_msg:
	defb	'\r\n\n'
	defb	'Z80 Retro BIOS Copyright (C) 2021 John Winans\r\n'
	defb	'CP/M 2.2 Copyright (C) 1979 Digital Research\r\n'
	defb	'  git: @@GIT_VERSION@@\r\n'
	defb	'build: @@DATE@@\r\n'
	defb	'\n'
	defb	'\0'





.bios_wboot:
.bios_const:
.bios_conin:
.bios_conout:
.bios_list:
.bios_punch:
.bios_reader:
.bios_home:
.bios_seldsk:
.bios_settrk:
.bios_setsec:
.bios_setdma:
.bios_read:
.bios_write:
.bios_prstat:
.bios_sectrn:


.halt_loop:
	halt
	jp	.halt_loop


;##########################################################################
; Initialize the console port.  Note that this includes CTC port 1.
;##########################################################################
.init_console:
	;ld	c,6			; C = 6 = 19200 bps
	ld	c,12			; C = 6 = 9600 bps
	call	init_ctc_1		; start CTC1 in case J11-A selects it!
	call	sioa_init		; 115200 or 19200 depending on J11-A
	ret


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
