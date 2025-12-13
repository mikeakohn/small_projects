;; Xylophone - Copyright 2025 by Michael Kohn
;; Email: mike@mikekohn.net
;;   Web: https://www.mikekohn.net/
;;
;; Read data (converted from .mid) to play the drum line over UART
;; to an M5Stack MIDI device and melody data to a xylophone with
;; solenoids.

.avr8
.include "tn2313def.inc"

; 8MHz clock
; note: CLKSEL 0100
; lowfuse = 0xe4

; r0  = 0
; r1  = 1
; r2  = 127
; r3  = 3
; r4  = track 0 division delay
; r5  = track 1 division delay
; r7  = store SREG in interrupts
; r8  = 0x89
; r9  = 0x99
; r10 =
; r11 =
; r12 =
; r13 =
; r14 =
; r15 = 255
; r16 = temp
; r17 = temp
; r18 =
; r19 = function parameter
; r20 = temp in interrupt
; r21 = temp in interrupt
; r22 = Channel 0 L data (drum)
; r23 = Channel 0 H data (drum)
; r24 = Channel 1 L data (melody)
; r25 = Channel 1 H data (melody)
; r26 = drum queue head L
; r27 = drum queue head H
; r28 = drum queue tail L
; r29 = drum queue tail H
; r30 = ZL
; r31 = ZH

;BAUD_RATE equ 9600
BAUD_RATE equ 31250

;; 8,000,000 cycles per second.
;; divisions = 240
;; bpm = 110.
;; 110 / 60 = beats per second.
;; 8,000,000 / (110 / 60) = cycles per beat = 4,363,636 cycles.
;; cycles per beat / (divisions / 4) = cycles per division = 72727.
;; 72727 / scale_8 = 9090
TIMER_TOP equ 9090

QUEUE_SIZE  equ 32
QUEUE_START equ SRAM_START
QUEUE_END   equ SRAM_START + QUEUE_SIZE

.org 0x000
  rjmp start
.org 0x004
  rjmp timer1_interrupt

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
  ;ldi r17, 0x89
  ;mov r8, r17
  ldi r17, 0x99
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

  ;; Set up TIMER1
  ;; Compare to 7812 clocks.
  ;; Prescaler @ 1024 / OCR1A is top.
  ldi r17, (TIMER_TOP >> 8)
  out OCR1AH, r17
  ldi r17, (TIMER_TOP & 0xff)
  out OCR1AL, r17

  out TCCR1A, r0
  out TCCR1C, r0
  ldi r17, (1 << WGM12) | (1 << CS11)
  out TCCR1B, r17

  ;; Set up interrupts for timer.
  ldi r17, (1 << OCIE1A)
  out TIMSK, r17

  ;; Set up PORTB.
  ;; PB0: Solenoid E4
  ;; PB1: Solenoid F4
  ;; PB2: Solenoid G4
  ;; PB3: Solenoid A4
  ;; PB4: Solenoid B4
  ;; PB5: MOSI
  ;; PB6: MISO
  ;; PB7: UCSK
  ldi r17, 0x1f
  out DDRB, r17
  out PORTB, r0

  ;; Set up PORTD.
  ;; PD2: Solenoid C5
  ;; PD3: Solenoid D5
  ;; PD4: Solenoid E5
  ;; PD5: Button
  ldi r17, 0x1c
  out DDRD, r17
  ldi r17, 0x20
  out PORTD, r17

  ;; PORTA is for debug.
  ;; PA0: LED
  ;; PA1: LED
  ldi r17, 0x03
  out DDRA, r17
  out PORTA, r0

  ;; Erase 32 bytes of RAM used as a queue.
  ldi r26, QUEUE_START
  ldi r27, 0
  ldi r17, QUEUE_SIZE
memset:
  st X+, r0
  dec r17
  brne memset

  ;; Setup queue head.
  ldi r26, QUEUE_START & 0xff
  ldi r27, QUEUE_START >> 8

  ;; Setup queue tail.
  ldi r28, QUEUE_START & 0xff
  ldi r29, QUEUE_START >> 8

  ;; Set up divisions to be 255 indicating that the music
  ;; isn't playing.
  mov r4, r15
  mov r5, r15

  ;; Enable interrupts.
  sei

  ;; DEBUG
  ;ldi r19, 'A'
  ;rcall uart_send_byte
  ;; DEBUG

main:
  ;; Wait for a button push.
main_wait_button:
  sbic PIND, 5
  rjmp main_wait_button

  rcall reset_pointers
  rcall play

  rjmp main

reset_pointers:
  ;; Setup pointers to channel data.
  ldi r22, (track_drum * 2) & 0xff
  ldi r23, (track_drum * 2) >> 8
  ldi r24, (track_melody * 2) & 0xff
  ldi r25, (track_melody * 2) >> 8

  mov r4, r1
  mov r5, r1
  ret

play:
  cp r4, r15
  brne play_not_at_end
  cp r5, r15
  brne play_not_at_end
  rjmp play_exit
play_not_at_end:
  rcall service_queue
  rjmp play
play_exit:
  ret

service_queue:
  ;; if queue_head == queue_end, no note to process.
  cp r26, r28
  breq service_queue_empty
  cli
  ;; X = queue_head.
  ld r16, X+
  ;; If queue is at end, loop back to the start.
  cpi r26, QUEUE_END
  brne service_queue_not_at_end
  ldi r26, QUEUE_START
service_queue_not_at_end:
  sei
  rcall send_note_on
service_queue_empty:
  ret

;; send_note_on(r16)
send_note_on:
  mov r19, r9
  rcall uart_send_byte
  mov r19, r16
  rcall uart_send_byte
  mov r19, r2
  rcall uart_send_byte
  ret

;; void uart_send_byte(r19)
uart_send_byte:
  sbis UCSRA, UDRE
  rjmp uart_send_byte
  out UDR, r19
  ret

;; void add_to_queue(r21).
add_to_queue:
  ;; Add r21 (note) to tail of queue.
  st Y+, r21
  cpi r28, QUEUE_END
  brne add_to_queue_dont_reset
  ldi r28, QUEUE_START
add_to_queue_dont_reset:
  ret

;; void hit_xylophone(r21)
hit_xylophone:
  sbi PORTA, 0
  subi r21, 64
  ldi r30, (note_table * 2) & 0xff
  ldi r31, (note_table * 2) >> 8
  lsl r21
  add r30, r21
  adc r31, r0
  lpm r21, Z+
  lpm r20, Z+
  cpi r20, 1
  breq hit_xylophone_not_portb
  out PORTB, r21
  ret
hit_xylophone_not_portb:
  out PORTD, r21
  ret

timer1_interrupt:
  in r7, SREG
  ;; Reset solenoids.
  out PORTB, r0
  ldi r20, 0x20
  out PORTD, r20
  cbi PORTA, 0

  ;; track_drum.
timer1_interrupt_track_drum:
  ;; If r4 == 255 (track isn't playing), break;
  cp r4, r15
  breq timer1_interrupt_track_drum_done
  ;; Subtract 1 division.
  dec r4
  ;; If r4 != 0 (track is still paused), break;
  brne timer1_interrupt_track_drum_done
timer1_interrupt_track_drum_loop:
  movw r30, r22
  lpm r4, Z+
  lpm r21, Z+
  movw r22, r30
  tst r21
  breq timer1_interrupt_track_drum_off
  rcall add_to_queue
timer1_interrupt_track_drum_off:
  ;; If division / delay value == 0, read another value.
  tst r4
  breq timer1_interrupt_track_drum_loop
timer1_interrupt_track_drum_done:

  ;; track_melody.
timer1_interrupt_track_melody:
  ;; If r5 == 255 (track isn't playing), break;
  cp r5, r15
  breq timer1_interrupt_track_melody_done
  ;; Subtract 1 division.
  dec r5
  ;; If r5 != 0 (track is still paused), break;
  brne timer1_interrupt_track_melody_done
timer1_interrupt_track_melody_loop:
  movw r30, r24
  lpm r5, Z+
  lpm r21, Z+
  movw r24, r30
  ;; If r21 == 0, note is off.
  tst r21
  breq timer1_interrupt_track_melody_off
  ;; Calculate which I/O pin to trigger based on note_table.
  rcall hit_xylophone
timer1_interrupt_track_melody_off:
  ;; If division / delay value == 0, read another value.
  tst r5
  breq timer1_interrupt_track_melody_loop
timer1_interrupt_track_melody_done:

  ;; Exit intertupt.
  out SREG, r7
  reti

note_table:
  .db 0x01, 0x00  // E4
  .db 0x02, 0x00  // F4
  .db 0x00, 0x00
  .db 0x04, 0x00  // G4
  .db 0x00, 0x00
  .db 0x08, 0x00  // A4
  .db 0x00, 0x00
  .db 0x10, 0x00  // B4
  .db 0x24, 0x01  // C5
  .db 0x20, 0x01
  .db 0x28, 0x01  // D5
  .db 0x22, 0x01
  .db 0x30, 0x01  // E5

.include "music.inc"

