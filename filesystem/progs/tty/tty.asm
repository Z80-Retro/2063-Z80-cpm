;****************************************************************************
;
;    BAUDOT TTY test app
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

; Set the AUX port to 50 (or 45.5) BPS and send some test data to a BAUDOT TTY.


.sio_bd:	equ	0x31		; SIO port B, data
.sio_bc:	equ	0x33		; SIO port B, control

.ctc_2:		equ	0x42		; CTC port 2


	org	0x100

	; Config SIO port B
        ld      c,.sio_bc        ; port to write into (port B control)
        ld      hl,.siob_init_wr ; point to init string
        ld      b,.siob_init_len_wr ; number of bytes to send
        otir                    ; write B bytes from (HL) into port in the C reg

	; To run at 50 BPS, we need 50*64 HZ = 3200 HZ
	; Run CTC channel in timer mode w/16 prescaler = 10000000/16 = 625000 HZ
	; 625000/3200 = 195.312 (set timer limit to 196, meh... close enough) 

	ld      a,0x07		; TC follows, Timer, /16, Control, Reset
	out     (.ctc_2),a
if 1 ;baud50
	ld	a,196		; divide by 196 for 50 baud
else
	ld	a,215		; divide by 215 for 45.5 baud
endif
	out     (.ctc_2),a

	
	;call	.tx_loop
	;call	.pattern
	;call	.p2
	;call	.message_test

	call	.tx_startup
	;call	.shift_test
	call	.ipsum

	ret


;***************************************************************************
;***************************************************************************
.siob_init_wr:
        db      00011000b       ; wr0 = reset everything
        db      00000100b       ; wr0 = select reg 4
;	db      11001100b       ; wr4 = /64 no parity, 2 stop
 	db      11001000b       ; wr4 = /64 no parity, 1.5 stop
        db      00000011b       ; wr0 = select reg 3
        db      11000001b       ; wr3 = RX enable, 8 bits/char
        db      00000101b       ; wr0 = select reg 5
; 	db      00001000b       ; wr5 = DTR=0, TX enable, 5 bits/char
 	db      01001000b       ; wr5 = DTR=0, TX enable, 6 bits/char
.siob_init_len_wr:   equ $-.siob_init_wr



;***************************************************************************
;***************************************************************************
.ipsum:
	ld	hl,.news1
	call	.print_ascii
	ret


;***************************************************************************
; shift from figs to ltrs and back again over and over
;***************************************************************************
.shift_test:
	ld	hl,.shift_msg
	call	.print_ascii
	jp	.shift_test

.shift_msg:
	db	"abcdefghijklmnopqrstuvwxyz 01234567890~!@#$%^&*()-_=+[]{}|\r\n"
	db	"a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q.r.s.t.u.v.w.x.y.z\r\n"
	db	"a-b?c:d$e3f!g&h#i8j'k(l)m.n,o9p0q1r4s\at5u7v;w2x/y6z\" !!\r\n",0

;***************************************************************************
;***************************************************************************
	; write a pattern of all-ones, all-zeros, ...
.tx_loop:
	call	.wait_tx
;	ld	a,0x1f		; all ones
	ld	a,0xef		; msb only set to 0
;	ld	a,0xff
	out	(.sio_bd),a
	jp	.tx_loop

	call	.wait_tx
	ld	a,0x00		; all zeros
	out	(.sio_bd),a

	jp	.tx_loop

;***************************************************************************
;***************************************************************************
.p2:
	call	.wait_tx
	ld	a,1
	out	(.sio_bd),a

	call	.wait_tx
	ld	a,0
	out	(.sio_bd),a

	jp	.p2

;***************************************************************************
;***************************************************************************
.pattern:
	ld	b,0x10
.ploop:
	call	.wait_tx
	call	.delay
	call	.delay
	call	.delay
	call	.delay

	ld	a,b
	;ld	a,0xff
	;xor	b
	
	out	(.sio_bd),a
	srl	b
	jr	nz,.ploop

	jp	.pattern


.delay:
	ld 	hl,0
.dly1:
	dec	hl
	ld	a,h
	or	l
	jp	nz,.dly1
	ret


;***************************************************************************
;***************************************************************************
.message_test:
	call	.hello2
	ld	hl,.crlf
	call	.print_ascii
	jp	.message_test

;***************************************************************************
;***************************************************************************
.overstrike_tst:
	ld	b,9
.os_loop:
	push	bc
	call	.hello2
	ld	hl,.cr
	call	.print_ascii
	pop	bc
	djnz	.os_loop

	ld	hl,.crlf
	call	.print_ascii
	jp	.overstrike_tst


;***************************************************************************
;***************************************************************************
.hello2:
	ld	hl,.msg
	call	.print_ascii
	ld	hl,.spaces
	call	.print_ascii
	ld	hl,.msg
	call	.print_ascii
	ret

.spaces:
	db	"      ",0

.cr:
	db	"\r",0		; a CR 

.crlf:
	db	"\r\n",0	; a CR, LF 


;***************************************************************************
;***************************************************************************
.hello_jb:
	ld	hl,.msg
	call	.print_ascii
	jp	.message_test

.msg:
	db	"hello world from johns basement",0







;***************************************************************************
; Clobbers AF
;***************************************************************************
.wait_tx:
	in	a,(.sio_bc)
	and	4		; xmtr empty bit?
	jr	z,.wait_tx

	ret

;****************************************************************************
; Print the BAUDOT character code in C
; CLobbers AF, B
;****************************************************************************
.tx_baudot_char:
	; if 0x40 is set, the print it as-is
	ld	a,c
	and	0x40		; if 0x40 is set then can print regardless of current state
	jr	nz,.tx_baud_print

	ld	a,(.tx_baudot_stat)
	xor	c		; if the MSB matches, then we are in the right state
	and	0x80		; if this is zero, then the MSB matches current state
	jr	z,.tx_baud_print

	; else if 0x80 is set, we need figs 
	ld	a,c
	and	0x80
	ld	(.tx_baudot_stat),a	; save the new state while we have it handy
	jr	z,.tx_baudot_ltrs
	call	.wait_tx
	ld	a,0x1b		; shift to figs
	out	(.sio_bd),a
	jp	.tx_baud_print

.tx_baudot_ltrs:
	; else we need ltrs
	call	.wait_tx
	ld	a,0x1f		; shift to ltrs
	out	(.sio_bd),a

.tx_baud_print:
	call	.wait_tx
	ld	a,c
;	and	0x1f		; zero the flag bits
	or	0xe0		; set all the MSBs (make them into extra stop bits)
	out	(.sio_bd),a
;	cp	0x08		; was that a carriage-return?
	cp	0xe8		; was that a carriage-return?
	ret	nz		; no?  We are done

	; print a few nulls to waste time while the carriage returns
	ld	b,0x04		; send 4 for good measure
.tx_nulls:
	call	.wait_tx
	ld	a,0xe0
	out	(.sio_bd),a
	djnz	.tx_nulls

if 0
	call	.wait_tx
	xor	a		; set the saved state to ltrs 
	ld	(.tx_baudot_stat),a	
	; for good measure, shift back to ltrs
	ld	a,0x1f		; rather than nulls, shift to ltrs
	out	(.sio_bd),a
endif

	ret

.tx_baudot_stat:
	db	0


;****************************************************************************
; Send a bunch of nulls and a CR to wake things up.
; CLobbers: AF, BC
;****************************************************************************
.tx_startup:
	ld	c,0x40		; print a null regardless of shift
	ld	b,0x10		; send 16 nulls
.tx_startup_lp:
	call	.tx_baudot_char
	djnz	.tx_startup_lp

	; shift to ltrs
	ld	c,0x5f		; shift to ltrs from any current state
	call	.tx_baudot_char

	xor	a		; force current shift state to match
	ld	(.tx_baudot_stat),a

	ld	c,0x48		; send a CR
	call	.tx_baudot_char

	ret



;****************************************************************************
; Print the null-terminated ASCII message pointed to by HL.
;****************************************************************************
.print_ascii:
	ld	a,(hl)
	or	a
	ret	z	; if null then we are done

	push	hl
	ld	e,(hl)		; E = ASCII character to be printed
	ld	d,0
	ld	hl,.ascii_baudot
	add	hl,de
	ld	c,(hl)		; C = BAUDOT character to be printed
	pop	hl

	call	.tx_baudot_char

	inc	hl
	jp	.print_ascii




;****************************************************************************
; ASCII to BAUDOT Translation table suitable for a Model 15 Teletype.
;
; 0x80 is set for figs
; 0x40 is set if is valid in both figs and ltrs mode
;****************************************************************************
.ascii_baudot:
	db	0x40
	db	0x40
	db	0x40
	db	0x40
	db	0x40
	db	0x40
	db	0x40
	db	0x85	; bell
	db	0x40
	db	0x40
	db	0x42	; LF
	db	0x40
	db	0x40
;	db	0x48	; CR
	db	0x08	; CR	(always in ltrs mode in case shift out of sync)
	db	0x40
	db	0x40

	db	0x40	; 0x10
	db	0x40
	db	0x40
	db	0x40
	db	0x40
	db	0x40
	db	0x40
	db	0x40
	db	0x40
	db	0x40
	db	0x40
	db	0x40
	db	0x40
	db	0x40
	db	0x40
	db	0x40

	db	0x44	; space 0x20
	db	0x8b	; !
	db	0x91	; "
	db	0x94	; #
	db	0x89	; $
	db	0x44	; % (not available, print as a space)
	db	0x9a	; &
	db	0x8b	; '
	db	0x8f	; (
	db	0x92	; )
	db	0x94	; * (print as #)
	db	0x94	; + (print as #)
	db	0x8c	; ,
	db	0x83	; -
	db	0x9c	; .
	db	0x9d	; /

	db	0x96	; 0
	db	0x97	; 1
	db	0x93	; 2
	db	0x81	; 3
	db	0x8a	; 4
	db	0x90	; 5
	db	0x95	; 6
	db	0x87	; 7
	db	0x86	; 8
	db	0x98	; 9
	db	0x8e	; :
	db	0x9e	; ;
	db	0x44	; < (print as space)
	db	0x44	; = (print as space)
	db	0x44	; > (print as space)
	db	0x99	; ?

	db	0x44	; @ (print as space)
	db	0x03	; A
	db	0x19	; B
	db	0x0e	; C
	db	0x09	; D
	db	0x01	; E
	db	0x0d	; F
	db	0x1a	; G
	db	0x14	; H
	db	0x06	; I
	db	0x0b	; J
	db	0x0f	; K
	db	0x12	; L
	db	0x1c	; M
	db	0x0c	; N
	db	0x18	; O

	db	0x16	; P
	db	0x17	; Q
	db	0x0a	; R
	db	0x05	; S
	db	0x10	; T
	db	0x07	; U
	db	0x1e	; V
	db	0x13	; W
	db	0x1d	; X
	db	0x15	; Y
	db	0x11	; Z
	db	0x8f	; [ (print as ( )
	db	0x44	; \ (print as space)
	db	0x12	; ] (print as ) )
	db	0x44	; ^ (print as space)
	db	0x83	; _ (print as -)

	db	0x44	; ` (print as space)
	db	0x03	; a
	db	0x19	; b
	db	0x0e	; c
	db	0x09	; d
	db	0x01	; e
	db	0x0d	; f
	db	0x1a	; g
	db	0x14	; h
	db	0x06	; i
	db	0x0b	; j
	db	0x0f	; k
	db	0x12	; l
	db	0x1c	; m
	db	0x0c	; n
	db	0x18	; o

	db	0x16	; p
	db	0x17	; q
	db	0x0a	; r
	db	0x05	; s
	db	0x10	; t
	db	0x07	; u
	db	0x1e	; v
	db	0x13	; w
	db	0x1d	; x
	db	0x15	; y
	db	0x11	; z
	db	0x8f	; { (print as ( )
	db	0x44	; | (print as space)
	db	0x12	; } (print as ) )
	db	0x44	; ~ (print as space)
	db	0x44	; del (print as space)






.news1:
	db	"Chicago, June 30 (JB) Lorem ipsum dolor sit amet, consectetur\r\n"
	db	"adipiscing elit. Proin dignissim ipsum magna, aliquam ultricies\r\n"
	db	"tortor elementum eu. Nulla vel elit maximus, hendrerit nisl eget,\r\n"
	db	"eleifend nibh. Nullam fringilla egestas dui non elementum. Integer\r\n"
	db	"accumsan arcu eu elit bibendum rutrum. Nunc lacinia accumsan turpis,\r\n"
	db	"sit amet suscipit neque posuere sed. Mauris sit amet pellentesque\r\n"
	db	"elit. Aliquam felis elit, vestibulum eget dignissim at, cursus sit\r\n"
	db	"amet lorem. Vivamus enim metus, fermentum elementum vulputate in,\r\n"
	db	"tristique eget eros. Maecenas lectus dolor, sagittis et urna a,\r\n"
	db	"viverra mollis dolor. Integer faucibus nec risus id consequat.\r\n"
	db	"\r\n"
	db	"Vivamus nunc nisl, faucibus eget mattis non, aliquet vitae odio. Cras\r\n"
	db	"nulla libero, pharetra eu molestie ut, commodo non felis. In molestie\r\n"
	db	"velit id elit luctus, eget fermentum nulla condimentum. Vestibulum\r\n"
	db	"eleifend placerat nisi quis pellentesque. Integer ut odio magna.\r\n"
	db	"Etiam bibendum orci cursus dapibus venenatis. Nullam at imperdiet\r\n"
	db	"ante. Maecenas eu sem risus. Vivamus pretium efficitur finibus.\r\n"
	db	"Pellentesque volutpat elit sit amet mi pulvinar consectetur. Praesent\r\n"
	db	"blandit dolor in libero scelerisque, quis pharetra ligula elementum.\r\n"
	db	"\r\n"
	db	"Vivamus a eros in ex dictum sagittis. Quisque non ante ut nisl varius\r\n"
	db	"scelerisque. Aliquam a tincidunt enim. Nunc pretium tempus\r\n"
	db	"ullamcorper. Suspendisse potenti. Nullam luctus, orci a consectetur\r\n"
	db	"pharetra, felis orci interdum libero, vitae iaculis arcu risus non\r\n"
	db	"ex. Cras convallis nisi ac felis porta, sed placerat diam ultricies.\r\n"
	db	"Nunc eleifend lorem eget urna tincidunt, ultricies auctor elit\r\n"
	db	"eleifend. Sed ipsum sem, pellentesque quis arcu eu, dapibus maximus\r\n"
	db	"tortor. Fusce sed imperdiet nulla, id bibendum nunc. Maecenas sem\r\n"
	db	"neque, condimentum et metus a, rhoncus convallis quam. Vestibulum\r\n"
	db	"ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia\r\n"
	db	"curae; Nulla laoreet efficitur condimentum. Maecenas lectus eros,\r\n"
	db	"lacinia vel mauris sed, ornare gravida nisl. Interdum et malesuada\r\n"
	db	"fames ac ante ipsum primis in faucibus. Sed eu lacus eu neque\r\n"
	db	"efficitur mattis.\r\n"
	db	"\r\n"
	db	"Duis mattis velit vel magna tincidunt, a placerat enim aliquam. Morbi\r\n"
	db	"nisi ex, venenatis vitae iaculis sed, imperdiet vitae nunc. Aliquam\r\n"
	db	"ut mi justo. Proin cursus tortor ut mi viverra molestie. Sed\r\n"
	db	"scelerisque at tellus sit amet posuere. Phasellus convallis ante\r\n"
	db	"maximus lorem lobortis tincidunt. Donec sit amet tortor consectetur,\r\n"
	db	"interdum ante non, gravida massa. Proin maximus vestibulum lacus a\r\n"
	db	"gravida. Praesent gravida fringilla posuere. Integer pharetra tortor\r\n"
	db	"eu felis feugiat blandit. Praesent ultrices pellentesque ligula ut\r\n"
	db	"euismod. Quisque dolor turpis, eleifend sed vehicula non, maximus\r\n"
	db	"vitae arcu. Nulla dapibus lorem sit amet egestas consectetur.\r\n"
	db	"Interdum et malesuada fames ac ante ipsum primis in faucibus.\r\n"
	db	"\r\n"
	db	"Duis ex sapien, sagittis tincidunt augue a, ultrices efficitur urna.\r\n"
	db	"Vivamus vel dapibus nibh. Morbi imperdiet felis sed mollis ultricies.\r\n"
	db	"Maecenas viverra, felis sit amet auctor porta, metus neque porttitor\r\n"
	db	"magna, at tincidunt nulla massa eu orci. Nulla feugiat eros et\r\n"
	db	"lobortis tempor. Donec iaculis bibendum rutrum. Quisque id felis\r\n"
	db	"rutrum, venenatis lorem eget, fermentum diam. Nunc lacinia efficitur\r\n"
	db	"urna, vel egestas neque blandit at. Nam iaculis, quam sed pretium\r\n"
	db	"tincidunt, erat mi mollis dui, a pulvinar enim neque eget est.\r\n"
	db	"Vivamus hendrerit felis quis enim fringilla pharetra. Etiam convallis\r\n"
	db	"id ante at pretium. Suspendisse ac volutpat ante. Aliquam sed libero\r\n"
	db	"vel sapien malesuada gravida. Nulla facilisi. Suspendisse potenti.\r\n"
	db	"\r\n"
	db	"Pellentesque vel consequat ante. Donec ante libero, malesuada vel\r\n"
	db	"ultricies et, suscipit vel eros. Integer nec efficitur mauris.\r\n"
	db	"Quisque vulputate ipsum a rutrum lacinia. Vestibulum ante ipsum\r\n"
	db	"primis in faucibus orci luctus et ultrices posuere cubilia curae;\r\n"
	db	"Suspendisse feugiat suscipit fermentum. Sed turpis sapien, feugiat\r\n"
	db	"nec consectetur ac, tristique ac lorem. Praesent lobortis sapien\r\n"
	db	"turpis, in hendrerit metus scelerisque eu. Praesent sit amet est\r\n"
	db	"consectetur, dignissim tortor et, mattis purus. Mauris euismod eros\r\n"
	db	"et mollis maximus. Praesent tempor ipsum in turpis vulputate maximus.\r\n"
	db	"Pellentesque habitant morbi tristique senectus et netus et malesuada\r\n"
	db	"fames ac turpis egestas. Curabitur non ex elit. Maecenas et accumsan\r\n"
	db	"nisl, nec vehicula nunc. Nulla in suscipit erat, aliquet dignissim\r\n"
	db	"lorem.\r\n"
	db	"\r\n"
	db	"Sed rhoncus tortor turpis, ut tincidunt felis blandit sed. Maecenas\r\n"
	db	"cursus risus eget magna mollis porta. Praesent dapibus eget mi ac\r\n"
	db	"efficitur. Morbi eget metus id erat hendrerit varius. Fusce justo\r\n"
	db	"eros, eleifend venenatis turpis ac, consectetur tincidunt sem. In\r\n"
	db	"vestibulum condimentum ipsum, sit amet porttitor sem bibendum ac.\r\n"
	db	"Quisque pretium a risus nec iaculis. Maecenas quis velit vitae enim\r\n"
	db	"vulputate condimentum. Integer porta urna at nisl suscipit, sagittis\r\n"
	db	"tempor ante euismod. Donec vel efficitur mi, vitae vehicula metus.\r\n"
	db	"\r\n"
	db	"Donec sit amet venenatis diam. Proin scelerisque condimentum ornare.\r\n"
	db	"Cras sit amet erat accumsan, tempor libero et, varius dui.\r\n"
	db	"Suspendisse iaculis nisl justo. Aenean euismod porttitor sapien, quis\r\n"
	db	"dapibus est luctus non. Suspendisse a nunc elementum, fringilla felis\r\n"
	db	"eu, vestibulum tellus. Suspendisse imperdiet nunc nec diam lacinia\r\n"
	db	"dignissim. Sed at tempor massa. Praesent cursus eu urna vel\r\n"
	db	"tincidunt. Integer congue nec dolor ac rhoncus. Pellentesque ultrices\r\n"
	db	"lacus sit amet quam tincidunt scelerisque. Nam imperdiet lectus\r\n"
	db	"sollicitudin libero mollis sodales. Praesent ipsum orci, lobortis ut\r\n"
	db	"justo nec, laoreet aliquam urna. Ut gravida fringilla leo, eget\r\n"
	db	"fringilla risus viverra id. Mauris sit amet velit lorem. Proin a\r\n"
	db	"lectus ac dui placerat congue.\r\n"
	db	"\r\n"
	db	"Phasellus ultricies justo quis diam euismod faucibus. Nullam feugiat\r\n"
	db	"facilisis lectus. Vivamus lectus lorem, pharetra ac luctus et,\r\n"
	db	"tristique eu eros. Phasellus vel elementum elit. Donec pharetra\r\n"
	db	"gravida tellus, id feugiat erat lacinia sit amet. Ut faucibus quis\r\n"
	db	"sapien eu sodales. Aliquam in diam purus. Curabitur interdum nisl\r\n"
	db	"elit, vitae fringilla mauris sodales vitae. Sed dictum iaculis metus,\r\n"
	db	"ut vestibulum lectus semper quis. Mauris ultrices suscipit\r\n"
	db	"pellentesque. Aliquam pulvinar et quam eget rutrum. Suspendisse nec\r\n"
	db	"mi eros. Mauris neque nulla, ullamcorper nec velit sit amet, gravida\r\n"
	db	"consectetur urna. Nullam quis condimentum est. Cras eget metus at\r\n"
	db	"ante lobortis efficitur. Nulla facilisi.\r\n"
	db	"\r\n"
	db	"Mauris nulla lorem, ullamcorper et risus quis, auctor dapibus enim.\r\n"
	db	"Phasellus eleifend ex sem, nec auctor ligula pellentesque quis.\r\n"
	db	"Pellentesque lobortis vel lacus et malesuada. Sed eget posuere mi.\r\n"
	db	"Praesent justo neque, malesuada in finibus vel, suscipit vitae\r\n"
	db	"sapien. Duis sagittis turpis nulla, eu vestibulum odio consequat sit\r\n"
	db	"amet. Donec et erat risus. Phasellus quis ultrices elit, vitae\r\n"
	db	"pellentesque nibh. Sed elit justo, faucibus eu malesuada ac,\r\n"
	db	"scelerisque id massa. Fusce feugiat a augue in venenatis. Etiam\r\n"
	db	"auctor volutpat blandit. Integer quis enim ut nisl interdum aliquet\r\n"
	db	"nec quis tortor. Orci varius natoque penatibus et magnis dis\r\n"
	db	"parturient montes, nascetur ridiculus mus. Nulla facilisi. Morbi\r\n"
	db	"luctus luctus mollis.\r\n"
	db	0
