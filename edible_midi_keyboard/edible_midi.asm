;; Edible MIDI Keyboard - Copyright 2025 by Michael Kohn
;; Email: mike@mikekohn.net
;;   Web: https://www.mikekohn.net/
;;
;; Trigger note-on / note-off events over a UART based on
;; buttons (keys) being pushed on the input pins of an ATtiny2313.

.avr8
.include "tn2313def.inc"

; 8MHz clock
; note: CLKSEL 0100
; lowfuse = 0xe4

; r0  = 0
; r1  = 1
; r2  = 127
; r3  = 3
; r4  =
; r5  =
; r7  = store SREG in interrupts
; r8  = 0x81
; r9  = 0x91
; r10 =
; r11 =
; r12 =
; r13 =
; r14 =
; r15 =
; r16 = temp
; r17 = temp
; r18 =
; r19 =
; r20 =
; r21 =
; r22 =
; r23 =
; r24 =
; r25 =
; r26 =
; r27 =
; r28 =
; r29 =
; r30 =
; r31 =

;BAUD_RATE equ 9600
BAUD_RATE equ 31250

.macro check_key_on(reg, pin, key_num)
.scope
  ;; Check key pressed (0 is on).
  sbrc reg, pin
  rjmp not_key_on_0
  ;; Debug LED.
  sbi PORTA, 0
  ;; Check SRAM if the key is already down.
  lds r16, SRAM_START + key_num
  cpi r16, 0
  brne not_key_on_0
  ;; Set MIDI note to turn on.
  ldi r16, 60 + key_num
  rcall send_note_on
  ;; Mark key as pressed.
  sts SRAM_START + key_num, r1
not_key_on_0:
.ends
.endm

.macro check_key_off(reg, pin, key_num)
.scope
  ;; Check key not pressed (1 is off).
  sbrs reg, pin
  rjmp not_key_off_0
  ;; Debug LED.
  cbi PORTA, 0
  ;; Check SRAM if the key is already up.
  lds r16, SRAM_START + key_num
  cpi r16, 0
  breq not_key_off_0
  ;; Set MIDI note to turn off.
  ldi r16, 60 + key_num
  rcall send_note_off
  ;; Mark key as off.
  sts SRAM_START + key_num, r0
not_key_off_0:
.ends
.endm

.org 0x000
  rjmp start

start:
  ;; Disable Interrupts.
  cli

  ;; Set up stack ptr
  ;ldi r17, RAMEND >> 8
  ;out SPH, r17
  ldi r17, RAMEND & 0xff
  out SPL, r17

  ;; r0 = 0, r1 = 1, r15 = 255
  clr r0
  ldi r17, 1
  mov r1, r17
  ldi r17, 127
  mov r2, r17
  ldi r17, 3
  mov r3, r17
  ldi r17, 0x81
  mov r8, r17
  ldi r17, 0x91
  mov r9, r17
  ldi r17, 255
  mov r15, r17

  ;; Set up UART baud rate.
  ;; 9600 for a computer, 31250 for MIDI.
  ldi r17, ((8_000_000 / (8 * BAUD_RATE)) - 1) >> 8
  out UBRRH, r17
  ;ldi r17, ((8_000_000 / (8 * BAUD_RATE)) - 1) & 0xff
  ldi r17, ((8_000_000 / (8 * BAUD_RATE)) - 0) & 0xff
  out UBRRL, r17

  ;; Set up UART options.
  ldi r17, (1 << UCSZ1) | (1 << UCSZ0)   ; sets up data as 8N1
  out UCSRC, r17
  ldi r17, (1 << TXEN ) | (1 << RXEN)    ; enables send/receive
  out UCSRB, r17
  ldi r17, (1 << U2X)
  out UCSRA, r17

  ;; Set up PORTB.
  ;; PB0: Key C4   60
  ;; PB1: Key C#4  61
  ;; PB2: Key D4   62
  ;; PB3: Key D#4  63
  ;; PB4: Key E4   64
  ;; PB5: Key F4   65
  ;; PB6: Key F#4  66
  ;; PB7: Key G4   67
  out DDRB, r0
  out PORTB, r15

  ;; Set up PORTD.
  ;; PD2: Key G#4 68
  ;; PD3: Key A4  69
  ;; PD4: Key A#4 70
  ;; PD5: Key B4  71
  ;; PD6: Key C5  72
  out DDRD, r0
  out PORTD, r15

  ;; PORTA is for debug.
  ;; PA0: LED
  ;; PA1: LED
  ldi r17, 0x03
  out DDRA, r17
  out PORTA, r0

  ;; Erase 13 bytes of RAM used for key-on tracking.
  ldi r26, SRAM_START 
  ldi r27, 0
  ldi r17, 13
memset:
  st X+, r0
  dec r17
  brne memset

  ;; Enable interrupts.
  sei

  ;; DEBUG
  ;ldi r19, 'A'
  ;rcall uart_send_byte
  ;ldi r19, 'B'
  ;rcall uart_send_byte
  ;ldi r19, 'C'
  ;rcall uart_send_byte
  ;; DEBUG

main:
  in r20, PINB
  in r21, PIND

  check_key_on(r20, 0, 0)
  check_key_on(r20, 1, 1)
  check_key_on(r20, 2, 2)
  check_key_on(r20, 3, 3)
  check_key_on(r20, 4, 4)
  check_key_on(r20, 5, 5)
  check_key_on(r20, 6, 6)
  check_key_on(r20, 7, 7)

  check_key_on(r21, 2, 8)
  check_key_on(r21, 3, 9)
  check_key_on(r21, 4, 10)
  check_key_on(r21, 5, 11)
  check_key_on(r21, 6, 12)

  check_key_off(r20, 0, 0)
  check_key_off(r20, 1, 1)
  check_key_off(r20, 2, 2)
  check_key_off(r20, 3, 3)
  check_key_off(r20, 4, 4)
  check_key_off(r20, 5, 5)
  check_key_off(r20, 6, 6)
  check_key_off(r20, 7, 7)

  check_key_off(r21, 2, 8)
  check_key_off(r21, 3, 9)
  check_key_off(r21, 4, 10)
  check_key_off(r21, 5, 11)
  check_key_off(r21, 6, 12)

  rjmp main

;; insert_note_on(r16)
send_note_on:
  mov r19, r9
  rcall uart_send_byte
  mov r19, r16
  rcall uart_send_byte
  mov r19, r2
  rcall uart_send_byte
  ret

;; insert_note_off(r16)
send_note_off:
  mov r19, r8
  rcall uart_send_byte
  mov r19, r16
  rcall uart_send_byte
  mov r19, r2
  rcall uart_send_byte
  ret

; void uart_send_byte(r19)
uart_send_byte:
  sbis UCSRA, UDRE
  rjmp uart_send_byte
  out UDR, r19
  ret

signature:
.db "Edible MIDI - Copyright 2025 - Michael Kohn - Version 0.01",0

