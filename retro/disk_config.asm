;****************************************************************************
; Configure the BIOS drive DPH structures here.
;
; WARNING
; 	Do *NOT* expected to mount the same drive more than one 
;	way and expect it to work without corrupting the drive!
;****************************************************************************

; Create a DPH & ALV for each filesystem 


if 1

; The SD card offset specified here is relative to the start of the
; boot partition. The 32-bit boot partition base address is
; expected to be stored in disk_offset_hi and disk_offset_low

include 'disk_nocache.asm'
.dph0:	nocache_dph     0x0000 0x0000	; SD logical drive 0  A:
.dph1:	nocache_dph     0x0000 0x4000	; SD logical drive 1  B:
.dph2:	nocache_dph     0x0000 0x8000	; SD logical drive 2  C:
.dph3:	nocache_dph     0x0000 0xc000	; SD logical drive 3  D:
.dph4:	nocache_dph     0x0001 0x0000	; SD logical drive 4  E:
.dph5:	nocache_dph     0x0001 0x4000	; SD logical drive 5  F:
.dph6:	nocache_dph     0x0001 0x8000	; SD logical drive 6  G:
.dph7:	nocache_dph     0x0001 0xc000	; SD logical drive 7  H:
if 0
; If we configure all 16 drives then we'll run out of memory
.dph8:	nocache_dph     0x0002 0x0000	; SD logical drive 8  I:
.dph9:	nocache_dph     0x0002 0x4000	; SD logical drive 9  J:
.dph10:	nocache_dph     0x0002 0x8000	; SD logical drive 10 K:
.dph11:	nocache_dph     0x0002 0xc000	; SD logical drive 11 L:
.dph12:	nocache_dph     0x0003 0x0000	; SD logical drive 12 M:
.dph13:	nocache_dph     0x0003 0x4000	; SD logical drive 13 N:
.dph14:	nocache_dph     0x0003 0x8000	; SD logical drive 14 O:
.dph15:	nocache_dph     0x0003 0xc000	; SD logical drive 15 P:
endif

else

; NOTE: dmcache ONLY works on a single-partition starting at SD block number 0x0800
include 'disk_dmcache.asm'
.dph0:	dmcache_dph	0x0000 0x0800	; This is absolute, NOT partition-relative!

endif


;include 'disk_stub.asm'
;.dph1:	stub_dph	; useful for testing
;.dph2:	stub_dph	; useful for testing
;.dph3:	stub_dph
;.dph4:	stub_dph
;.dph5:	stub_dph
;.dph6:	stub_dph
;.dph7:	stub_dph
;.dph8:	stub_dph
;.dph9:	stub_dph
;.dph10: stub_dph
;.dph11: stub_dph
;.dph12: stub_dph
;.dph13: stub_dph
;.dph14: stub_dph
;.dph15: stub_dph


dph_vec:
	dw	.dph0
	dw	.dph1
	dw	.dph2
	dw	.dph3
	dw	.dph4
	dw	.dph5
	dw	.dph6
	dw	.dph7
if 0
	dw	.dph8
	dw	.dph9
	dw	.dph10
	dw	.dph11
	dw	.dph12
	dw	.dph13
	dw	.dph14
	dw	.dph15
endif
dph_vec_num:	equ	($-dph_vec)/2		; number of configured drives
