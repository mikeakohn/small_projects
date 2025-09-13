;; Atmel VGA - Copyright 2008 by Michael Kohn
;; Email: mike@mikekohn.net
;;   Web: https://www.mikekohn.net/
;;
;; Draw to a VGA display with an Atmel chip

.include "m168def.inc"

; note: CLKSEL 0110

; One scan line
;   8 pixels front porch           0
;  96 pixels horizontal sync       6.4
;  40 pixels back porch            83.3
;   8 pixels left border           115.2
; 640 pixels video                 121.6
;   8 pixels right border          633.6
; ---
; 800 pixels total per line

; One field
;   2 lines front porch
;   2 lines vertical sync
;  25 lines back porch
;   8 lines top border
; 480 lines video
;   8 lines bottom border
; ---
; 525 lines total per field              

; PC0 = RED
; PC1 = GREEN
; PC2 = BLUE
; PC3 = HSYNC
; PC4 = VSYNC

.dseg

.cseg

.org 0x000
  rjmp start
.org 0x016
  rjmp end_scan_line
.org 0x018        ; compare B
  ijmp            ; indirect jump 
.org 0x01a
  rjmp end_scan_line

;; FIXME - erase this padding.. it's dumb
.org 0x020

start:
  ;; I'm busy.  Don't interrupt me!
  cli

  ;; Set up stack ptr
  ldi r16, RAMEND>>8
  out SPH, r16
  ldi r16, RAMEND&255
  out SPL, r16

  ;; Set up PORTB and PORTC
  ser r17
  ldi r18, 0
  out DDRB, r17             ; entire port B is output
  out PORTB, r18            ; turn off all of port B for fun
  out DDRC, r17             ; entire port C is output
  out PORTC, r18            ; turn off all of port C for fun

  ;; Set up rs232 baud rate
  eor r16, r16
  sts UBRR0H, r16
  ldi r16, 25
  sts UBRR0L, r16           ; 129 @ 20MHz = 9600 baud

  ;; Set up rs232 options
  ldi r16, (1<<UCSZ00)+(1<<UCSZ01)    ; sets up data as 8N1
  sts UCSR0C, r16
  ldi r17, (1<<TXEN0)+(1<<RXEN0)      ; enables send/receive
  sts UCSR0B, r17
  eor r17, r17
  sts UCSR0A, r17

  ; constant register
  eor r0, r0

  ; current line of "block"
  ;ldi r23, 8

  ; playfield ptr
  ldi r27, (image*2)>>8
  ldi r26, (image*2)&0xff

  ; vsync = r29, r28
  ldi r29, 0              ; vcounth
  ldi r28, 0              ; vcountl

  ; turn hsync on at next interrupt
  ldi r21, 8

  ; First interrupt.. turn on hsync
  ldi r31, (hsync_on)>>8
  ldi r30, (hsync_on)&0xff

  ;; Set up Counter
  lds r17, PRR
  andi r17, 255 ^ (1<<PRTIM1)
  sts PRR, r17                   ; turn of power management bit on TIM1

  ldi r17, (639>>8)              ; I think this could be 1 off
  sts OCR1AH, r17
  ldi r17, (639&0xff)            ; compare to 639 clocks (800 25MHz pixels)
  sts OCR1AL, r17

  sts OCR1BH, r0
  ldi r17, 8                     ; compare to hsync_on clocks (8 25MHz pixels)
  sts OCR1BL, r17

  ldi r17, (1<<OCIE1B)|(1<<OCIE1A)
  sts TIMSK1, r17                ; enable interrupt comare B 
  eor r17, r17
  sts TCCR1C, r17
  ; r17 = 0 still
  sts TCCR1A, r17                ; normal counting (0xffff is top, count up)
  ldi r17, (1<<CS10)|(1<<WGM12) ; CTC OCR1A
  sts TCCR1B, r17                ; prescale = 1 from clock source
  
  ; Fine, I can be interrupted now
  sei

  ; current pixel register
  eor r18, r18

main:
  lds r20, UCSR0A         ; poll uart to see if there is a data waiting
  sbrs r20, RXC0
  rjmp main               ; if no data, loop around
  ; We can do something here if we want with the rs232 data
  rjmp main


hsync_on:
  ; turn on hsync
  out PORTC, r21
  andi r21, 0xf0                 ; next interrupt turns hsync off

  ; compare TIMER to hsync_off (83 cycles) (8+96 25MHz pixels)
  sts OCR1BH, r0
  ldi r17, 84
  sts OCR1BL, r17
  ldi r31, (hsync_off)>>8
  ldi r30, (hsync_off)&0xff    ; next interrupt jump to hsync_off

  ; Increment vscan line counter
  inc r28
  brne vsync_not_zero
  inc r29
vsync_not_zero:

  reti

hsync_off:
  ; turn off hsync
  out PORTC, r21

  ; Check if we should turn on vsync or not
  cpi r29, 0
  brne no_vsync
  cpi r28, 2
  breq vsync
  cpi r28, 3
  breq vsync
  rjmp no_vsync
vsync:
  ldi r21, 16
  rjmp exit_vsync_check
no_vsync:
  eor r21, r21
exit_vsync_check:

  ; Test to see if we are at max scan line
  cpi r29, 0x02
  brne not_max_vscan
  cpi r28, 0x0d              ; FIXME - should this be 0x0c
  brne not_max_vscan
  eor r29, r29
  eor r28, r28
  ; reset playfield ptr
  ldi r27, (image*2)>>8
  ldi r26, (image*2)&0xff
  eor r18, r18
  ldi r23, 8
not_max_vscan:


  ; compare TIMER to playfield start clocks (8+96+40+8 25MHz pixels)
  sts OCR1BH, r0
  ;ldi r17, 122
  ldi r17, 160
  sts OCR1BL, r17
  ldi r31, (playfield)>>8
  ldi r30, (playfield)&0xff

  reti

playfield:
  ; Test if vscan is (at least) more than 37 scanlines
  cpi r29, 0
  brne vscan_not_zero     ; 2 cycles on branch otherwise 1
  mov r17, r28
  andi r17, (128)
  breq done_drawing       ; 1 cycle (don't care about the branch)
  ;cpi r28, 40             ; 1 cycle
  ;brhs done_drawing       ; 1 cycle (don't care about the branch)
  rjmp past40             ; 2 cycles  (5 cycles total)
vscan_not_zero:
  nop
  nop
  nop                     ; This branch should take 5 cycles now also
past40:

  ; Check if we are at the bottom border (waste some scan lines just to
  ; make the calculation simpler)
  cpi r29, 2
  breq done_drawing

  ; Now we can do some real drawing

  ; Test bar
  ;mov r25, r28
  ;andi r25, 0x07
  ;out PORTC, r25
  ;nop
  ;nop
  ;nop
  ;nop
  ;eor r25, r25
  ;out PORTC, r25

  cpi r18, 0xff
  breq done_drawing

  mov r30, r26                   ; DANGER DANGER WILL ROBINSON
  mov r31, r27
playfield_loop:
  lpm r18, Z+
  sbrc r18, 7
  rjmp playfield_loop_exit
  andi r18, 0x07
  out PORTC, r18
  rjmp playfield_loop

playfield_loop_exit:
  out PORTC, r0

  dec r23
  brne done_drawing
  mov r26, r30
  mov r27, r31
  ldi r23, 8

done_drawing:

  ; compare TIMER to hsync_on clocks (8 25MHz pixels)
  sts OCR1BH, r0
  ldi r17, 8                    ; 2009-02-16 should this be 6.4?
  sts OCR1BL, r17
  ldi r31, (hsync_on)>>8
  ldi r30, (hsync_on)&0xff
  reti

end_scan_line:
  out PORTC, r21
  ori r21, 0x08

  reti

.include "image.inc"

signature:
.db "Atmel VGA - Copyright 2008 - Michael Kohn - Version 0.04"

