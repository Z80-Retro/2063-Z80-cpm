;****************************************************************************
;
;    Copyright (C) 2024 John Winans
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

; Z80 Nouveau

gpio_in:		equ     0xf0		; GP input port
gpio_out:		equ	0xf1		; GP output port
flash_disable:		equ	0xfe		; dummy-read from this port to disable the FLASH

; bit-assignments for General Purpose output port 
gpio_out_sd_mosi:	equ	0x01
gpio_out_sd_clk:	equ	0x02
gpio_out_sd_ssel:	equ	0x04

; bit-assignments for General Purpose input port 
;gpio_in_user1:		equ	0x20 
gpio_in_sd_det:		equ	0x40
gpio_in_sd_miso:	equ	0x80

; The initial value to write into the gpio_out latch.
; The value here will idle the SD card interface.
gpio_out_init:          equ     gpio_out_sd_mosi|gpio_out_sd_clk|gpio_out_sd_ssel
