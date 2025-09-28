;; Laser Relay - Copyright 2025 by Michael Kohn
;; Email: mike@mikekohn.net
;;   Web: https://www.mikekohn.net/
;;
;; Interface 2 UARTs together with a laser / phototransistor.

.include "tn85def.inc"
.avr8

; CKSEL = 0010   (8 MHz Calibrated Internal Oscillator)
; CLKPS = 0000
; CKDIV8 = 0

; FUSE LOW = 11100010 = 0xe2

; r0  = 0
; r1  = 1
; r15 = 255
; r16 = temp
; r17 = temp
; r20 = count in interrupt / (bit 0 is laser value)

.org 0x000
  rjmp start

start:
  ;; Disable interrupts.
  cli

  ;; Setup stack ptr.
  ;ldi r17, RAMEND>>8
  ;out SPH, r17
  ldi r17, RAMEND & 255
  out SPL, r17

  ;; r0 = 0, r1 = 1, r15 = 255.
  eor r0, r0
  eor r1, r1
  inc r1
  ldi r17, 0xff
  mov r15, r17

  ;; Setup PORTB (10101).
  ;; PB0: UART-TX (output)
  ;; PB1: UART-RX (input)
  ;; PB3: laser-out
  ;; PB4: light-in (reverse logic)
  ldi r17, 0x09
  out DDRB, r17
  out PORTB, r0

  ; Enable interrupts.
  sei

main:
  in r16, PINB

  ;; Service UART-RX / laser out.
  sbrs r16, 1
  cbi PORTB, 3
  sbrc r16, 1
  sbi PORTB, 3

  ;; Service laser in / UART-TX.
  sbrs r16, 4
  sbi PORTB, 0
  sbrc r16, 4
  cbi PORTB, 0

  rjmp main

