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

;############################################################################
; An SPI library suitable for tallking to SD cards.
;
; This library implements SPI mode 0 (SD cards operate on SPI mode 0.)
; Data changes on falling CLK edge & sampled on rising CLK edge:
;        __                                             ___
; /SSEL    \______________________ ... ________________/      Host --> Device
;                 __    __    __   ... _    __    __
; CLK    ________/  \__/  \__/  \__     \__/  \__/  \______   Host --> Device
;        _____ _____ _____ _____ _     _ _____ _____ ______
; MOSI        \_____X_____X_____X_ ... _X_____X_____/         Host --> Device
;        _____ _____ _____ _____ _     _ _____ _____ ______
; MISO        \_____X_____X_____X_ ... _X_____X_____/         Host <-- Device
;
;############################################################################

;############################################################################
; Write bc bytes from buffer pointed to by hl
; It is assumed that the gpio_out_cache value matches the current state
; of the GP Output port and that SSEL is low.
; This will leave: CLK=0, MOSI=1
;
; Strategy for making a single write function is that small writes are relatively
; infrequent and can take longer to execute due to overhead, while with large
; writes (like an SD sector), the overhead is relatively small and transfer is
; the fastest that it can be.
;
; Inner loop with inlined spi_write8 takes 362** cycles, best case 185344
; cycles for 512 bytes.  Actual 512 byte time longer due to outer loop,
; but the increase is comparatively miniscule (69 more cycles)
; Clobbers: A
; Refactored by Tim Gordon and Trevor Jacobs 06-02-2023
;
; Unlike the read_str function, there are ALMOST enough registers for the
; loops in this function.  Instead of using the alternate register set,
; the bc register is pushed onto the stack between bytes to preserve the
; value for the next OUTER loop.  The inner loop stays fast at the expense
; of a slower outer loop (12 cycles per INNER loop versus 21 per outer-
; that's a 12 x 8 = 96 cycle savings at the cost of 21!)
;
; For both the write_str and read_str functions, any set up that makes the
; inner and outer loops faster is considered *totally* worth it, because
; those clocks are spent once per string rather than per bit or byte.  Using
; the same logic, the cycle cost of saving and restoring all registers can
; be considered very low whilst making the functions more user friendly.
;
; ** TG 071623 Interrupt page register impact analysis: in the ssel and read
; functions it was determined that by making sure that CLK "idles" at 0 and
; MOSI "idles" at 1 at all times, an interrupt that accesses the page bits
; in the gpio_out port would not impact the CLK or MOSI lines.  Here in
; the write function, an interrupt CAN change the MOSI line inadvertently.
; Thus there is a critical section between when the data pin is set and the
; rising edge of the clock happens.  Adding di/ei here minimizes the interrupt
; latency but increases the write cycle time by 18%.  By wrapping the whole
; byte in a di/ei pair, the write time is maximized but the worst-case
; interrupt latency becomes 36us.  This is probably the best choice.
;
; ** JW 2025-12-15 The Retro SPI driver never used to DI/EI this critical
; region (to protect the latch & cached value relationship.)  The rule 
; has always been that no IRQ handler shall touch either the cached latch
; value nor the latch itself.  Therefore the DI/EI is not present in this
; version of the code.
;
; Note that blindly doing so is invalid anyway because it will enable
; IRQs even if they did not used to be enabled... which is another problem
; that we are avoiding by omitting the DI/EI pair here.
;
;############################################################################

spi_write1: macro   ; 42 cycles / bit
        ld a, e                 ; Restore gpio port bits ready for clock and data   4
        rl c                    ; Isolate next data bit                     8
        rla                     ; Put data bit into lsb by rotating in      4
        out (gpio_out), a       ; Drive MOSI and CLK = 0 signal onto SPI bus    11
        or d                    ; Set CLK high.  Do it fast by ORing reg    4
        out (gpio_out), a       ; Drive MOSI and other CLK rising edge      11
    endm

spi_write_str:      ; hl has read buffer pointer, bc has count
    push de
    push bc
    push hl

    ld a, c                     ; Swap b for c in order to use djnz inst
    or a                        ; Adjust outer loop count when inner loop is 00
    jr nz, .write_correct_count
        dec b
.write_correct_count:           ; * The extra time taken here is miniscule compared to
    ld c, b                     ; the inner loop; it is once per call so worth it
    ld b, 0                     ; Preload inner loop count with 0 for next outer loop
    push bc                     ; Save bc for outer loop use
    ld b, a                     ; First inner loop count in b for djnz

    ld d, gpio_out_sd_clk       ; Initialize CLK = 1 bit mask           7

    ld a, (gpio_out_cache)      ; Get current gpio_out value- CLK will = 0 and MOSI will = 1    13
            ; TG 071623 Changed to just clear MOSI because idle state of CLK is already 0
    and ~gpio_out_sd_mosi       ; Set MOSI (& CLK) = 0  7
    rra                         ; Right shift now to accept left shift of data bit  4
    ld e, a                     ; Save in register for reuse each bit   4

.write_str_loop:
            ld c, (hl)          ; Fetch byte from write buffer          7
            inc hl              ; Increment buffer pointer              6

            ;di                  ; Critical section start
            spi_write1  ;7      ; Write 8 bits                          42 * 8 = 336
            spi_write1  ;6      ; Inlining this saves call and ret cycles
            spi_write1  ;5
            spi_write1  ;4
            spi_write1  ;3
            spi_write1  ;2
            spi_write1  ;1
            spi_write1  ;0
            ;ei                  ; Critical section end

            djnz .write_str_loop    ; Loop count.LSB first, 256 thereafter  13/7

        pop bc                  ; Restore loop count                    11
        dec c                   ; Outer loop -1                         4
        push bc                 ; Store for next time                   10
        jp p, .write_str_loop   ; Outer loop until c goes -ve       10 (7)

.write_str_done:
            ; a still has last bit pattern driven to bus
    and ~gpio_out_sd_clk
    or gpio_out_sd_mosi         ; Drive SPI lines back to idle state CLK = 0, MOSI = 1

    out (gpio_out), a           ; Leave pins at idle states.  No need to write to cache
                                ; ...because SPI bits in cache should already be in idle states
    pop bc

    pop hl
    pop bc
    pop de

    ret


;############################################################################
; Writes one byte in C to SPI port and gives nothing in return
; This will leave: CLK=0, MOSI=1
;
; Clobbers A and E
; Refactored by Tim Gordon and Trevor Jacobs 06-02-2023
;
; This function simply sets up the spi_write call with a count of one and a
; pointer to a scratch memory location.  The scratch variable is used for
; both the write8 and read8 functions.
;
;############################################################################

spi_write8:                 ; Write the byte passed in c
    push hl
    push bc

    ld hl, .spi_8_scratch
    ld (hl), c
    ld bc, 1

    call spi_write_str

    pop bc
    pop hl

    ret


;############################################################################
; Read bc bytes from SPI port to buffer pointed to in hl
; MOSI will be set to 1 during all bit transfers.
; This will leave: CLK=0, MOSI=1
;
; Strategy for making a single read function is that small reads are relatively
; infrequent and can take longer to execute due to overhead, while with large
; reads (like an SD sector), the overhead is relatively small and transfer is
; the fastest that it can be.
;
; Inner loop with inlined spi_read8 takes 418 cycles, best case 214016
; cycles for 512 bytes.  Actual 512 byte time longer due to outer loop,
; but the increase is comparatively miniscule (69 more cycles)
;
; Clobbers A and E
;
; Returns the byte read in the A (and a copy of it also in E)
; Refactored by Tim Gordon and Trevor Jacobs 06-02-2023
;
; The alternate register set was used in this routine in order to minimize
; the inner and outer loop time.  There were not enough regular registers
; (not considering IX and IY) to keep the loops tight, so the a, bc and de
; registers are set up in the alternate set and switched in for each inner
; loop.
; For safety's sake, the alternate register set's used registers are stored on the
; stack and restored upon exit.
;
; TG 071523 Analysis of impact of interrupted page changes:
; With the "idle" state of CLK and MOSI set to 0 and 1 respectively, this
; function is free of a critical section that must be protected with a di/ei
; pair.  An interrupt can only force the pins back to their idle states, and
; this means that this code is the only code creating a rising edge on CLK.
; Thus no critical section protection need be implemented.
;
;############################################################################

spi_read1: macro
        in a, (gpio_in)         ; Read MISO (in bit 7)              11
        out (c), d              ; Drive MOSI HIGH and CLK high      12
        rla                     ; Put MISO value in carry           4
        rl e                    ; Shift carry (= MISO bit) into bit 0 of reg e  8
        out (c), b              ; Drive MOSI high and CLK low.  Do it fast by using register    12
    endm

spi_read_str:       ; hl has read buffer pointer, bc has count
    push de                     ; For restoration later
    push bc
    push hl

    ld a, c
    or a
    jr nz, .read_correct_count
        dec b                   ; Adjust outer loop count if inner is 256
.read_correct_count:
    ld c, b                     ; Corrected outer loop count in c
    ld b, a                     ; Inside loop initial count in b

    exx                         ; Go into one bit register context (BC, DE and HL)
    push bc                     ; Store previous state of alternate registers
    push de                     ; Alt hl register not used so no need to save

    ld a, (gpio_out_cache)      ; Get current gpio_out value (CLK = 0, MOSI = 1)    13
            ; TG 071623 Not needed because idle state of lines is CLK = 0 and MOSI = 1
    ld b, a                     ; Store bitmap in b
    or gpio_out_sd_clk          ; Set CLK bit                           7
    ld d, a                     ; Store bitmap in d

    ld c, gpio_out              ; Set up c for fast IO ops              7
    exx
            ; Inner and outer loop boundary
.read_str_loop:                 ; No need to zero out reg e; 8 shifts eliminates previous contents
        exx                     ; Enter one-bit context                 4

        spi_read1   ;7          ; Read the 8 bits, byte in reg e        47 * 8 = 376
        spi_read1   ;6          ; Unrolling this saves call and ret cycles!
        spi_read1   ;5
        spi_read1   ;4
        spi_read1   ;3
        spi_read1   ;2
        spi_read1   ;1
        spi_read1   ;0
        ld a, e                 ; Put result in a                       4

        exx                     ; Flip out of one-bit context           4

        ld (hl), a              ; Store in read buffer                  7
        inc hl                  ; Increment read buffer pointer         6

        djnz .read_str_loop     ; Loop count.LSB first, 256 thereafter  13

            ; Inner loop boundary
                                ; If inner loop count zero,
        dec c                   ; Outer loop -1                         4
        jp p, .read_str_loop    ; Outer loop until c goes -ve       10 (7)

            ; Outer loop boundary

.read_str_done:

    exx                         ; c still has gpio port, and b still has "idle" SPI bus state
    pop de
    pop bc
    exx

    pop hl
    pop bc
    pop de

    ld e, a                     ; Put last byte assembled into reg e now

    ret


;############################################################################
; Read one byte from SPI port and return in a and e registers
; MOSI will be set to 1 during all bit transfers.
; This will leave: CLK=0, MOSI=1
;
; Clobbers A and E
; Refactored by Tim Gordon and Trevor Jacobs 06-02-2023
;############################################################################

spi_read8:              ; Read one byte and return in a and e
    push hl
    push bc

    ld bc, 1
    ld hl, .spi_8_scratch
    call spi_read_str

    pop bc
    pop hl

    ret

.spi_8_scratch:     ds 1


;##############################################################
; Assert the select line (set it low)
; This will leave: SSEL=0, CLK=0, MOSI=1
;
; Clobbers A
;
; Refactored 061623 TG
; This function is special because SSEL is changed and the
; gpio_out_cache value needs to remember the new state.  All
; other functions explicitly set the MOSI and CLK so the
; cached copy doesn't need to constantly "remember" their
; states.
;
; The read8 at the beginning of the function (while SSEL is
; inactive) reflects state of original code so is left in.
;
; The read8 loop after asserting SSEL makes sure that a write
; left "in progress" is completed before a new command is started.
; If there is no write in progress, the sd card should leave
; the bus floating and the loop will exit immediately.  Extra
; clocks in groups of 8 never hurt anyone (outside of write
; data transfers!)
;
; TG 071523 Analysis of issues caused by interrupt-driven page
; changes results in need to "protect" the coherency of the
; gpio_out_cache and port pins by wrapping the critical
; section in a di/ei pair.
; If not protected, a page change triggered by an interrupt
; could cause the SSEL line to revert to its entry state,
; which will definetly cause a problem.
; Since adopting the "idle" state of CLK = 0 and MOSI = 1,
; there is no longer a chance of an extra rising CLK edge
; as the cached value will always have a low clock state.  The
; same goes for MOSI; it would always be driven to its idle
; state.
; In fact, by ordering the cache write and the port write as
; below, interrupts do not need to be disabled because the
; ISR will read the cached value and "pre"-write it out.
; If the cache write was after the port write, an ISR would
; write the previous value.
;
; The de register is pushed upon entry becaue the disk boot
; function in firmware.asm assumes that it is retained.
;
; Scorching deficiency:
; There is no loop counter or indication of failure of a
; previous operation in the wait for not busy loop.
;
;##############################################################

spi_ssel_true:
    push de

    ; read and discard a byte to generate 8 clk cycles
    call spi_read8                  ; Create 8 CLK pulses- won't hurt anything

    ld a, (gpio_out_cache)

            ; TG 071623 We make sure idle state of pins is CLK = 0 and MOSI = 1, so no need to do it here
;   and ~gpio_out_sd_clk            ; CLK = 0
;   or gpio_out_sd_mosi             ; MOSI = 1 (required because previous write can leave data line low)
;   out (gpio_out), a

    ; enable the card
    and ~gpio_out_sd_ssel           ; SSEL = 0

            ; Even though this is a critical section, no need to disbale ints because ISR would set new SSEL
            ; level anyway.  After returns, the out () will happen and write the same again- no problem!
    ld  (gpio_out_cache), a         ; Store port in cache because SSEL has changed
    out (gpio_out), a

    ; Generate clk cycles until not busy (in case sdcard.asm
    ;   doesn't wait for long-duration writes to complete)
.spi_ssel_true_busy:
    call spi_read8
    cp 0ffh
    jr nz, .spi_ssel_true_busy

    pop de

    ret


;##############################################################
; de-assert the select line (set it high)
; This will leave: SSEL=1, CLK=0, MOSI=1
;
; Clobbers A
;
; See section 4 of
;   Physical Layer Simplified Specification Version 8.00
; Refactored 061623 TG
; This function is special because SSEL is changed and the
; gpio_out_cache value needs to remember the new state.  All
; other functions explicitly set the MOSI and CLK so the
; cache doesn't need to "remember" their states.
;
; The single read8 at the beginning meets spec requirement to
; supply 8 clocks immediately following a CMD string, response
; sequence or data transfer ready confirmation.
;
; The two read8s mimic the original code an are left in
; out of paranoia.  Lacking references indicating need to do
; this.
;
; TG 071523 Analysis of issues caused by interrupt-driven page
; changes results in the same conclusions as spi_ssel_true.
; The same changes have been made.
;
; DE was also pushed for the same reason as ssel_true.
;
;##############################################################

spi_ssel_false:
    push de

    ; read and discard a byte to generate 8 clk cycles
    call spi_read8                  ; This meets the need for 8 clocks after

    ld  a, (gpio_out_cache)

            ; TG 071623 We make sure idle state of pins is CLK = 0 and MOSI = 1, so no need to do it here
;   and ~gpio_out_sd_clk            ; CLK = 0
;   or gpio_out_sd_mosi             ; MOSI = 1 (required because previous write can leave data line low)
;   out (gpio_out), a

    or gpio_out_sd_ssel             ; SSEL = 1

            ; Even though this is a critical section, no need to disbale ints because ISR would set new SSEL
            ; level anyway.  After returns, the out () will happen and write the same again- no problem!
    ld  (gpio_out_cache), a         ; Store port in cache because SSEL has changed.
    out (gpio_out), a

    ; generate another 16 clk cycles
    call spi_read8
    call spi_read8

    pop de

    ret
