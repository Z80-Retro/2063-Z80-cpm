;****************************************************************************
;
;    Copyright (C) 2022 John Winans
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

;############################################################################
; An library suitable for tallking to an Epson RX-80 printer.
;############################################################################


;##########################################################################
; Just set the print strobe & line-feed signals high.
;
; NOTE: The line-feed signal is ignored here and is assumed to be
;	left set high by the init code in the SIO driver!
;
; Clobbers AF
;##########################################################################
prn_init:
	ld	a,(gpio_out_cache)
	or	gpio_out_prn_stb	; make PRN_STB high (false)
	ld	(gpio_out_cache),a	; save in the cached output value
	out	(gpio_out),a		; make it so in the GPIO register too
	ret

;##########################################################################
; Return A=0 if printer is not ready.
; Return A=0xff if printer is ready.
; Clobbers AF
;##########################################################################
prn_stat:
	in	a,(gpio_in)
	and	gpio_in_prn_bsy		; if this bit is low then it is ready
	jr	z,.prn_stat_ready
	xor	a			; A=0 = not ready
	ret
.prn_stat_ready:
	dec	a			; A=0xff = ready
	ret


;##########################################################################
; Print the character in the C register.
;##########################################################################
prn_out:

	; Sanity check to prevent seizing the entire OS.
	; If EVERY printer status input is high, then there is probably no
	; printer attached!  This is reasonable since paper-empty high should
	; also force gpio_in_prn_err low at same time.

	in	a,(gpio_in)
	and	gpio_in_prn_err|gpio_in_prn_stat|gpio_in_prn_papr|gpio_in_prn_bsy|gpio_in_prn_ack
	cp	gpio_in_prn_err|gpio_in_prn_stat|gpio_in_prn_papr|gpio_in_prn_bsy|gpio_in_prn_ack
	ret	z			; If all signals high then just discard the data.

	; wait until the printer is ready for data
	; XXX this can seize the system if the printer is offline!  :-(
.list_wait:
	call	prn_stat
	or	a
	jr	z,.list_wait		; if A=0 then is not ready

	; proceed to print the character
	ld	a,c
	out	(prn_dat),a		; put the character code into the output latch

	; assert the strobe signal
	ld	a,(gpio_out_cache)
	and	~gpio_out_prn_stb	; set the strobe signal low
	out	(gpio_out),a		; write to port but not update cache!

	; A brief delay so that strobe signal can be seen by the printer.
	ld	a,0x10			; loop 16 times
.list_stb_wait:
	dec	a
	jr	nz,.list_stb_wait

	; raise the strobe signal
	ld	a,(gpio_out_cache)	; we never updated the cache, so this is right
	out	(gpio_out),a
	ret
