;****************************************************************************
;
;    Copyright (C) 2021 John Winans
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
; https://github.com/johnwinans/2063-Z80-cpm
;
;****************************************************************************

; Z80 Retro Rev 3 IO port definitions


gpio_in:		equ     0x00		; GP input port
gpio_out:		equ	0x10		; GP output port
prn_dat:		equ	0x20		; printer data out

sio_ad:			equ	0x30		; SIO port A, data
sio_bd:			equ	0x31		; SIO port B, data
sio_ac:			equ	0x32		; SIO port A, control
sio_bc:			equ	0x33		; SIO port B, control

ctc_0:			equ	0x40		; CTC port 0
ctc_1:			equ	0x41		; CTC port 1
ctc_2:			equ	0x42		; CTC port 2
ctc_3:			equ	0x43		; CTC port 3

flash_disable:		equ	0x70		; dummy-read from this port to disable the FLASH


; bit-assignments for General Purpose output port 
gpio_out_sd_mosi:	equ	0x01
gpio_out_sd_clk:	equ	0x02
gpio_out_sd_ssel:	equ	0x04
gpio_out_prn_stb:	equ	0x08
gpio_out_a15:		equ	0x10
gpio_out_a16:		equ	0x20
gpio_out_a17:		equ	0x40
gpio_out_a18:		equ	0x80

; a bitmask representing all of the lobank address bits 
gpio_out_lobank:	equ	0|(gpio_out_a15|gpio_out_a16|gpio_out_a17|gpio_out_a18)

; bit-assignments for General Purpose input port 
gpio_in_prn_err:	equ	0x01
gpio_in_prn_stat:	equ	0x02
gpio_in_prn_papr:	equ	0x04
gpio_in_prn_bsy:	equ	0x08
gpio_in_prn_ack:	equ	0x10
gpio_in_user1:		equ	0x20 
gpio_in_sd_det:		equ	0x40
gpio_in_sd_miso:	equ	0x80


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

.low_bank:      equ     0x0e    ; The RAM BANK to use for the bottom 32K

; The initial value to write into the gpio_out latch.
; This will select low-bank E, idle the SD card, and idle the printer.
gpio_out_init:  equ     gpio_out_sd_mosi|gpio_out_sd_clk|gpio_out_sd_ssel|gpio_out_prn_stb|(.low_bank<<4)
