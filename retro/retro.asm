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

;****************************************************************************
;
; Memory banks:
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
;   D
;   E    CP/M zero page and low half of the TPA
;   F    CP/M high half of the TPA, CCP, BDOS, and BIOS
;
;****************************************************************************

.low_bank:	equ	0x0e	; The RAM BANK to use for the bottom 32K



;##########################################################################
; set .debug to:
;    0 = no debug output
;    1 = print messages from new code under development
;    2 = print all the above plus the primairy 'normal' debug messages
;    3 = print all the above plus verbose 'noisy' debug messages
;##########################################################################
;.debug:		equ	1
.debug:		equ	0


include	'io.asm'
include	'memory.asm'

	org	LOAD_BASE		; Where the boot loader places this code.

	; When we arrive here from the boot loader:
	; If A=0 then the SD was booted from a partition that starts at 0x800.
	;
	; If A=1 then:
	; C = partition number (1, 2, 3 or 4)
	; DE = the high 16 bits of the starting SD block number
	; HL = the low 16 bits of the starting SD block number

	or	a
	jp	z,.bios_boot

	; A != 0, patch the BIOS to use the given offset when accessing the SD card
	ld	(disk_offset_low),hl
	ld	(disk_offset_hi),de

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

include '../cpm-2.2/src/cpm22.asm'


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
HOME:   JP      disk_home
SELDSK: JP      disk_seldsk
SETTRK: JP      disk_settrk
SETSEC: JP      disk_setsec
SETDMA: JP      disk_setdma
READ:   JP      disk_read
WRITE:  JP      disk_write
PRSTAT: JP      .bios_prstat
SECTRN: JP      disk_sectrn


;##########################################################################
;
; CP/M 2.2 Alteration Guide p17:
; The BOOT entry point gets control from the cold start loader and is
; responsible for basic system initialization, including sending a signon
; message.
;
; If the IOBYTE function is implemented, it must be set at this point.
;
; The various system parameters which are set by the WBOOT entry point
; must be initialized (see .go_cpm), and control is transferred to the CCP 
; at 3400H+b for further processing.
;
; Note that reg C must be set to zero to select drive A.
;
;##########################################################################

.bios_boot:
	; This will select low-bank E, idle the SD card, and idle the printer
	ld	a,gpio_out_sd_mosi|gpio_out_sd_clk|gpio_out_sd_ssel|gpio_out_prn_stb|(.low_bank<<4)
	ld	(gpio_out_cache),a
	out	(gpio_out),a

	; make sure we have a viable stack
	ld	sp,bios_stack		; use the private BIOS stack to get started

	call	.init_console		; Note: console should still be initialized from the boot loader
	call	.init_list		; initialize the printer interface

if .debug > 0
	call	iputs
	db	"\r\n.bios_boot entered\r\n\0"
	call	iputs
	db	"NOTICE: Debug level is set to: 0x\0"
	ld	a,.debug		; A = the current debug level
	call	hexdump_a		; print the current level number
	call	puts_crlf		; and a newline
endif

	; Display a hello world message.
	ld	hl,.boot_msg
	call	puts

	; For sanity sake, wipe the zero-page so we aren't confused by 
	; whatever random noise the flash boot-loader has left there.
	ld	hl,0
	ld	de,1
	ld	bc,0xff
	ld	(hl),0
	ldir

	; Either ensure the stack is in high RAM or disable IRQs to call disk_init!
	call	disk_init		; initialize anything needed for disk read/write 

	jp	.go_cpm


.boot_msg:
	defb	'\r\n\n'
	defb	'Z80 Retro BIOS Copyright (C) 2021 John Winans\r\n'
	defb	'CP/M 2.2 Copyright (C) 1979 Digital Research\r\n'
	defb	'  git: @@GIT_VERSION@@\r\n'
	defb	'build: @@DATE@@\r\n'
	defb	'\n'
	defb	'\0'


;##########################################################################
;
; CP/M 2.2 Alteration Guide p17:
; The WBOOT entry point gets control when a warm start occurs.  A warm
; start is performed whenever a user program branches to location 0x0000.
;
; The CP/M CCP and BDOS must be re-loaded from the first two tracks of 
; drive A up to, but not including, the BIOS.
;
; The WBOOT & BDOS jump instructions in page-zero must be initialized 
; (see .go_cpm), and control is transferred to the CCP at 3400H+b for 
; further processing.
;
; Upon completion of the initialization, the WBOOT program must branch
; to the CCP at 3400H+b to (re)start the system. Upon entry to the CCP,
; register C is set to the drive to select after system initialization.
;
;##########################################################################

; WARNING: The following assumes that CPM_BASE%128 is zero!

.wb_nsects:	equ (BOOT-CPM_BASE)/128			; number of sectors to load
.wb_trk:	equ (CPM_BASE-LOAD_BASE)/512		; first track number (rounded down)
.wb_sec:	equ ((CPM_BASE-LOAD_BASE)/128)&0x03	; first sector number


.bios_wboot:

	; We can't just blindly set SP=bios_stack here because disk_read can overwrite it!
	; But we CAN set to use other areas that we KNOW are not currently in use!
	ld	sp,.bios_wboot_stack			; the disk_dirbuf is garbage right now


if .debug >= 2
	call	iputs
	db	"\r\n.bios_wboot entered\r\n\0"
endif

	; reload the CCP and BDOS

	ld	c,0			; C = drive number (0=A)
	call	disk_seldsk		; load the OS from drive A

	ld	bc,.wb_trk		; BC = track number whgere the CCP starts
	call	disk_settrk

	ld	bc,.wb_sec		; sector where the CCP begins on .wb_trk
	call	disk_setsec

	ld	bc,CPM_BASE		; starting address to read the OS into
	call	disk_setdma

	ld	bc,.wb_nsects		; BC = gross number of sectors to read
.wboot_loop:
	push	bc			; save the remaining sector count

	call	disk_read		; read 1 sector

	or	a			; disk_read sets A=0 on success
	jr	z,.wboot_sec_ok		; if read was OK, continue processing

	; If there was a read error, stop.
	call	iputs
	db      "\r\n\r\nERROR: WBOOT READ FAILED.  HALTING."
	db      "\r\n\n*** PRESS RESET TO REBOOT ***\r\n"
	db      0
	jp      $               	; endless spin loop

.wboot_sec_ok:
	; advance the DMA pointer by 128 bytes
	ld	hl,(disk_dma)	; HL = the last used DMA address
	ld	de,128
	add	hl,de			; HL += 128
	ld	b,h
	ld	c,l			; BC = HL
	call	disk_setdma

	; increment the sector/track numbers
	ld	a,(disk_sec)		; A = last used sector number (low byte only for 0..3)
	inc	a
	and	0x03			; if A+1 = 4 then A=0
	jr	nz,.wboot_sec		; if A+1 !=4 then do not advance the track number

	; advance to the next track
	ld	bc,(disk_track)
	inc	bc
	call	disk_settrk
	xor	a			; set A=0 for first sector on new track

.wboot_sec:
	ld	b,0
	ld	c,a
	call	disk_setsec

	pop	bc			; BC = remaining sector counter value
	dec	bc			; BC -= 1
	ld	a,b
	or	c
	jr	nz,.wboot_loop		; if BC != 0 then goto .wboot_loop


	; fall through into .go_cpm...

.go_cpm:
	ld	a,0xc3		; opcode for JP
	ld	(0),a
	ld	hl,WBOOT
	ld	(1),hl		; address 0 now = JP WBOOT

	ld	(5),a		; opcode for JP
	ld	hl,FBASE
	ld	(6),hl		; address 6 now = JP FBASE

	ld	bc,0x80		; this is here because it is in the example CBIOS (AG p.52)
	call	disk_setdma

if .debug >= 3
	; dump the zero-page for reference
	ld	hl,0		; start address
	ld	bc,0x100	; number of bytes
	ld	e,1		; fancy format
	call	hexdump
endif

if 1
	ld	c,0		; default = drive A (if previous was invalid)
	ld	a,(4)           ; load the current disk # from page-zero into A
	and	0x0f            ; the drive number is in the 4 lsbs
	cp	dph_vec_num
	jp	nc,CPM_BASE     ; if A >= dph_vec_num then bad drive (use 0)

	ld	a,(4)           ; load the current disk # from page-zero into a/c
	ld	c,a
else
	ld	c,0		; The ONLY valid drive WE have is A!
endif
	jp	CPM_BASE	; start the CCP


;##########################################################################
;
; CP/M 2.2 Alteration Guide p17:
; If the console device is ready for reading then return 0FFH in register A.
; Else return 00H in register A.
;
;##########################################################################
.bios_const:
	call	con_rx_ready
	ret	z		; A = 0 = not ready
	ld	a,0xff
	ret			; A = 0xff = ready

;##########################################################################
;
; CP/M 2.2 Alteration Guide p17:
; Read the next console character into register A and set the parity bit
; (high order bit) to zero.  If no console character is ready, wait until
; a character is typed before returning.
;
;##########################################################################
.bios_conin:
if 1
	jp	con_rx_char
else
	; a simple hack to let us dump the dmcache status on demand
	call	con_rx_char
	cp	0x1B				; escape key??
	ret	nz				; if not an escape then return
	call	z,disk_dmcache_debug_wedge	; else tail-call the debug wedge
	ld	a,0x1B				; restore the trigger key value
	ret
endif

;##########################################################################
;
; CP/M 2.2 Alteration Guide p18:
; Send the character from register C to the console output device.  The
; character is in ASCII, with high order parity bit set to zero.
;
;##########################################################################
.bios_conout:
	jp	con_tx_char

;##########################################################################
;
; CP/M 2.2 Alteration Guide p18:
; Send the character from register C to the currently assigned listing
; device.  The character is in ASCII with zero parity.
;
;##########################################################################
.bios_list:
	jp	prn_out		; tail-call the driver output routine

.init_list:
	jp	prn_init	; tail-call the driver init routine

;##########################################################################
;
; CP/M 2.2 Alteration Guide p20:
; Return the ready status of the list device.  Used by the DESPOOL program
; to improve console response during its operation.  The value 00 is
; returned in A of the list device is not ready to accept a character, and
; 0FFH if a character can be sent to the printer. 
;
; Note that a 00 value always suffices.
;
; Clobbers AF
;##########################################################################
.bios_prstat:
	jp	prn_stat	; tail-call the driver status routine

;##########################################################################
;
; CP/M 2.2 Alteration Guide p18:
; Send the character from register C to the currently assigned punch device.
; The character is in ASCII with zero parity.
;
; The Z80 Retro! has no punch device. Discard any data written.
;
;##########################################################################
.bios_punch:
	ret

;##########################################################################
;
; CP/M 2.2 Alteration Guide p18:
; Read the next character from the currently assigned reader device into
; register A with zero parity (high order bit must be zero), an end of
; file condition is reported by returning an ASCII control-Z (1AH).
;
; The Z80 Retro! has no tape device. Return the EOF character.
;
;##########################################################################
.bios_reader:
	ld	a,0x1a
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
; Libraries
;##########################################################################

include 'disk_callgate.asm'

include 'sio.asm'
include 'ctc1.asm'
include 'puts.asm'
include 'hexdump.asm'
include 'sdcard.asm'
include 'spi.asm'
include 'prn.asm'


;##########################################################################
; General save areas
;##########################################################################

gpio_out_cache: ds  1			; GPIO output latch cache


disk_dirbuf:
	ds	128		; scratch directory buffer
.bios_wboot_stack:		; (ab)use the BDOS directory buffer as a stack during WBOOT


;##########################################################################
; Temporary stack used for BIOS calls needing more than a few stack levels.
;
; WARNING: This is expected to be in memory that is NOT bank-switchable!
;##########################################################################
.bios_stack_lo:
	ds	64,0x55		; 32 stack levels = 64 bytes (init to analyze)
bios_stack:			; full descending stack starts /after/ the storage area 


;##########################################################################
if $ < BOOT
	ERROR THE BIOS WRAPPED AROUND PAST 0xffff
endif


	end
