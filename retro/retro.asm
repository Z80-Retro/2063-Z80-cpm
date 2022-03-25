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


;##########################################################################
; set .debug to:
;    0 = no debug output
;    1 = print messages from new code under development
;    2 = print all the above plus the primairy 'normal' debug messages
;    3 = print all the above plus verbose 'noisy' debug messages
;##########################################################################
.debug:		equ	3


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
	; This will select low-bank 0 and idle the SD card and printer
	ld	a,gpio_out_sd_mosi|gpio_out_sd_clk|gpio_out_sd_ssel|gpio_out_prn_stb
	ld	(gpio_out_cache),a
	out	(gpio_out),a

	; make sure we have a viable stack
	ld	sp,.stacktop

	call	.init_console		; Note: console should still be initialized from the boot loader

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
.bios_wboot:
if .debug >= 2
	call	iputs
	db	"\r\n.bios_wboot entered\r\n\0"
endif

	; XXX reload the CCP and BDOS here

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
	call	.bios_setdma

if .debug >= 3
	; dump the zero-page for reference
	ld	hl,0		; start address
	ld	bc,0x100	; number of bytes
	ld	e,1		; fancy format
	call	hexdump
endif

	ld	a,(4)		; load the current disk # from page-zero into a/c
	ld	c,a
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
	jp	con_rx_char

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
	; XXX finish me
	ret

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
	ld	a,0		; printer is never ready
	ret

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
;
; CP/M 2.2 Alteration Guide p18:
; Return the disk head of the currently selected disk to the track 
; 00 position.
;
; The Z80 Retro! does not have a mechanical disk drive. So just treat
; this like a SETTRK 0.
;
;##########################################################################
.bios_home:
if .debug >= 2
	call	iputs
	db	".bios_home entered\r\n\0"
endif

	ld	bc,0		; BC = 0 = track number passed into .bios_settrk

	; Fall into .bios_settrk <--------------- NOTICE!!

;##########################################################################
;
; CP/M 2.2 Alteration Guide p19:
; Register BC contains the track number for subsequent disk
; accesses on the currently selected drive.  BC can take on
; values from 0-65535.
;
;##########################################################################
.bios_settrk:
	ld	(.disk_track),bc

if .debug >= 2
	call	iputs
	db	".bios_settrk entered: \0"
	call	.debug_disk
endif
	ret

;##########################################################################
;
; CP/M 2.2 Alteration Guide p18:
; Select the disk drive given by register C for further operations, where
; register C contains 0 for drive A, 1 for drive B, and so-forth UP to 15
; for drive P.
;
; On each disk select, SELDSK must return in HL the base address of a 
; l6-byte area, called the Disk Parameter Header for the selected drive.
;
; If there is an attempt to select a non-existent drive, SELDSK returns
; HL=0000H as an error indicator.
;
; The Z80 Retro! only has one drive.
;
;##########################################################################
.bios_seldsk:
	ld	a,c
	ld	(.disk_disk),a		; XXX should we save this now or defer 
					; till after we validate the value?

if .debug >= 2
	call	iputs
	db	".bios_seldsk entered: \0"
	call	.debug_disk
endif

	ld	hl,0			; HL = 0 = invalid disk 
	ld	a,(.disk_disk)
	or	a			; did drive A get selected?
	ret	nz			; no -> error

	ld	hl,.bios_dph		; the DPH for disk A
	ret

;##########################################################################
;
; CP/M 2.2 Alteration Guide p19:
; Register BC contains the sector number for subsequent disk accesses on
; the currently selected drive.
;
;##########################################################################
.bios_setsec:
	ld	(.disk_sector),bc

if .debug >= 2
	call	iputs
	db	".bios_setsec entered: \0"
	call	.debug_disk
endif

	ret

;##########################################################################
;
; CP/M 2.2 Alteration Guide p19:
; Register BC contains the DMA (disk memory access) address for subsequent
; read or write operations.  For example, if B = 00H and C = 80H when SETDMA
; is called, then all subsequent read operations read their data into 80H
; through 0FFH, and all subsequent write operations get their data from
; 80H through 0FFH, until the next call to SETDMA changes it.
;
;##########################################################################
.bios_setdma:
	ld	(.disk_dma),bc

if .debug >= 2
	call	iputs
	db	".bios_setdma entered: \0"
	call	.debug_disk
endif

	ret

;##########################################################################
; A debug routing for displaying the settings before a read or write
; operation.
;
; Clobbers AF, C
;##########################################################################
if .debug >= 1
.debug_disk:
	call	iputs
	db	'disk=0x\0'

	ld	a,(.disk_disk)
	call	hexdump_a

	call    iputs
	db	", track=0x\0"
	ld	a,(.disk_track+1)
	call	hexdump_a
	ld	a,(.disk_track)
	call	hexdump_a

	call	iputs
	db	", sector=0x\0"
	ld	a,(.disk_sector+1)
	call	hexdump_a
	ld	a,(.disk_sector)
	call	hexdump_a

	call	iputs
	db	", dma=0x\0"
	ld	a,(.disk_dma+1)
	call	hexdump_a
	ld	a,(.disk_dma)
	call	hexdump_a
	call	puts_crlf

	ret
endif


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
.bios_read:
if .debug >= 1
	call	iputs
	db	".bios_read entered: \0"
	call	.debug_disk
endif

if 0
	; tell CP/M that we can not read the requested sector
	ld	a,1	; XXX  <--------- stub in an error for every read
else
	; fake a 'blank'/formatted sector
	ld	hl,(.disk_dma)		; HL = buffer address
	ld	de,(.disk_dma)
	inc	de			; DE = buffer address + 1
	ld	bc,0x007f		; BC = 127
	ld	(hl),0xe5
	ldir				; set 128 bytes from (hl) to 0xe5
	xor	a			; A = 0 = OK
endif

	ret

;##########################################################################
;
; CP/M 2.2 Alteration Guide p19:
; Write the data from the currently selected DMA address to the currently
; selected drive, track, and sector.  The error codes given in the READ
; command are returned in register A.
;
; Upon entry the value of C will be useful for deblocking and deblocking a
; drive's physical sector sizes:
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
.bios_write:
if .debug >= 1
	call	iputs
	db	".bios_write entered: \0"
	call	.debug_disk
endif

	ld	a,1	; XXX  <--------- stub in an error for every write

	ret


;##########################################################################
;
; CP/M 2.2 Alteration Guide p20:
; Performs sector logical to physical sector translation in order to improve
; the overall response of CP/M.
;
; Xlate the sector number in BC using table in DE & return in HL
; If DE=0 here then translation is 1:1
;
; The Z80 Retro! does not translate its sectors.  Therefore it will return
; HL = BC for a 1:1 translation.
;
;##########################################################################
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

gpio_out_cache: ds  1			; GPIO output latch cache

;##########################################################################
; The .disk_XXX values are used to retain the most recent values that
; have been set by the .bios_setXXX routines.
; These are used by the .bios_read and .bios_write routines.
;##########################################################################
.disk_dma:				; last set value of the DMA buffer address
	dw	0xa5a5

.disk_track:				; last set value of the disk track
	dw	0xa5a5

.disk_disk:				; last set value of the selected disk
	db	0xa5

.disk_sector:				; last set value of of the disk sector
	dw	0xa5a5



;##########################################################################
; Goal: Define a CP/M-compatible filesystem that can be implemented using
; an SDHC card.  An SDHC card is comprised of a number of 512-byte blocks.
;
; Plan:
; - Put 4 128-byte CP/M sectors into each 512-byte SDHC block.
; - Treat each SDHC block as a CP/M track.
;
; This filesystem has:
;  128 bytes/sector (CP/M requirement)
;  4 sectors/track (Retro BIOS designer's choice)
;  65536 total sectors (CP/M limit)
;  65536*128 = 8388608 total bytes (CP/M limit)
;  65536/4 = 16384 tracks
;  2048 allocation block size (Retro BIOS designer's choice)
;  8388608/2048 = 4096 total allocation blocks
;  4096-32*512/2048 = 4088 allocation blocks not counting reserved tracks
;  512 directory entries (Retro BIOS designer's choice)
;  512*32 = 16384 total bytes in the directory
;  16384/2048 = 8 allocation blocks for the directory
;
;  BLS  BSH BLM    ------EXM--------
;                  DSM<256   DSM>255
;  1024  3    7       0         x
;  2048  4   15       1         0  <----------------------
;  4096  5   31       3         1
;  8192  6   63       7         3
; 16384  7  127      15         7
;
;##########################################################################
.bios_dph:
	dw	0		; XLT sector translation table (no xlation done)
	dw	0		; scratchpad
	dw	0		; scratchpad
	dw	0		; scratchpad
	dw	.bios_dirbuf	; DIRBUF pointer
	dw	.bios_dpb_a	; DPB pointer
	dw	0		; CSV pointer (optional, not implemented)
	dw	.bios_alv_a	; ALV pointer

.bios_dirbuf:
	ds	128		; scratch directory buffer

.bios_dpb_a:
	dw	4		; SPT
	db	4		; BSH
	db	15		; BLM
	db	0		; EXM
	dw	4087		; DSM (max allocation block number)
	dw	511		; DRM
	db	0xff		; AL0
	db	0x00		; AL1
	dw	0		; CKS
	dw	32		; OFF

.bios_alv_a:
	ds	(4087/8)+1	; scratchpad used by BDOS for disk allocation info


	end
