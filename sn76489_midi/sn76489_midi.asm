
;; SN76489 MIDI
;; Email: mike@mikekohn.net
;;   Web: https://www.mikekohn.net/
;;
;; Accept MIDI commands over RS232 and play them using an SN76489 chip.

.avr8
.include "tn2313def.inc"

; note: CLKSEL ????
;
;  first byte is:  7 6 5 4 3 2 1 0
;                  1 N N C V V V V
; second byte is: same as a midi note
;
; C = chip number
; N = voice number
; V = volume

; r0  = 0
; r1  = 1
; r4  = 0x0f
; r10 = 0x10
; r15 = 255
; r14 = temp
; r16 =
; r17 = temp
; r18 =
; r19 =
; r20 = function parameter
; r21 = function parameter
; r22 =
; r23 = channel,volume
; r24 = frequency
; r25 =
; r26 = channel reg
; r27 =
; r30 = Z pointer to frequency table
; r31 = Z pointer to frequency table

BUS_DELAY equ 11

start:
  ldi r16, RAMEND&255
  out SPL, r16

  ;; Setup registers
  eor r0, r0
  mov r1, r0
  inc r1
  ldi r17, 0x10
  mov r10, r17
  mov r15, r0
  dec r15
  ldi r17, 0x0f
  mov r4, r17

  ;; Prescale CPU from 4MHz to 2MHz
  ldi r17, (1<<CLKPCE)
  ldi r18, (1<<CLKPS0)
  out CLKPR, r17
  out CLKPR, r18

  ;; Setup rs232 baud rate
  out UBRRH, r0
  ;ldi r17, 207    ; 1200
  ;ldi r17, 103   ; 2400
  ldi r17, 25    ; 9600
  ;ldi r17, 13    ; 9600
  out UBRRL, r17                 ; 25 @ 4MHz = 9600 baud

  ;; Set up rs232 options
  ldi r17, (1<<UCSZ0)|(1<<UCSZ1) ; sets up data as 8N1
  out UCSRC, r17
  ldi r17, (1<<TXEN)|(1<<RXEN)   ; enables send/receive
  out UCSRB, r17
  ;out UCSRA, r0
  ldi r17, (1<<U2X)
  out UCSRA, r17

  ;; Set up LED default
  ;; PB7 -> D0
  ;; PB6 -> D1
  ;; PB5 -> D2
  ;; PB4 -> D3
  ;; PB3 -> D4
  ;; PB2 -> D5
  ;; PB1 -> D6
  ;; PB0 -> D7
  ;; -- PA1 -> /CE   (0)   (CLK)
  ;; -- PA0 -> /WE   (0)   (CLK)
  ;; -- CLKOUT
  ;; PD3 -> /WE   (0)
  ;; PD4 -> /CE   (0)
  ;; PD5 <- /WE   (1)
  ;; PD6 <- /CE   (1)
  ser r17
  out DDRB, r17
  out PORTB, r0
  ldi r17, (1<<PORTD3)|(1<<PORTD4)|(1<<PORTD5)|(1<<PORTD6)
  out DDRD, r17
  out PORTD, r17
  ;ldi r17, (1<<PORTA0)|(1<<PORTA1)
  ;out DDRA, r17
  ;out PORTA, r17

  rcall turn_off_all

main:
  ; Read volume from UART
  sbis UCSRA, RXC
  rjmp main
  in r23, UDR

  ; Echo char back for debug
main_echo_r23:
  sbis UCSRA, UDRE
  rjmp main_echo_r23 ; if it's not okay, loop around :)
  out UDR, r23

  ; Check if this is a note-off event
check_note_off:
  mov r5, r23
  and r5, r4
  cp r5, r4
  brne read_second_byte

  ldi r24, 0
  rcall play_note
  rjmp main

read_second_byte:
  ; Read note from UART
  sbis UCSRA, RXC
  rjmp read_second_byte
  in r24, UDR

  ; Echo char back for debug
main_echo_r24:
  sbis UCSRA, UDRE
  rjmp main_echo_r24 ; if it's not okay, loop around :)
  out UDR, r24

  ; If bit 7 is 1, then this is really a first bit
  sbrs r24, 7
  rjmp main_play
  mov r23, r24
  rjmp check_note_off

main_play:
  rcall play_note

  rjmp main

.if 0
  ldi r20, 0x90
  rcall write_volume_reg_1
  ldi r20, 0x8d
  ldi r21, 0x1d
  rcall write_frequency_reg_1

  ldi r20, 0x90
  rcall write_volume_reg_0
  ldi r20, 0x81
  ldi r21, 0x12
  rcall write_frequency_reg_0

  ldi r23, 0x80
  ldi r24, 60
  rcall play_note

  ldi r23, 0x90
  ldi r24, 64
  rcall play_note
.endif

  ;rjmp main

  ;sbic PIND, PORTD0
  ;rjmp main

;; play_note(r23=channel,volume, r24=note)
play_note:
  ;; Look up note in frequency table
  ldi r30, (frequency_table * 2) & 0xff
  ldi r31, (frequency_table * 2) >> 8
  add r24, r24
  add r30, r24
  adc r31, r0

  ;; Set channel reg
  mov r26, r23        ; r26 = (r23 & 0x60)
  andi r26, 0x60
  mov r27, r26        ; r27 = r26 + 0x10
  add r27, r10

  sbrs r23, 4
  rjmp chip_0

  ;; Set Frequency
  lpm r20, Z+
  lpm r21, Z+
  ;andi r20, 0x0f
  ;andi r21, 0x3f
  cp r20, r0            ; if frequency == 0, turn off note
  brne freq_not_zero_1
  cp r21, r0
  brne freq_not_zero_1
  or r23, r4
  rjmp set_volume_1
freq_not_zero_1:
  ori r20, 0x80
  or r20, r26
  rcall write_frequency_reg_1

  ;; Set volume
set_volume_1:
  andi r23, 0x8f
  or r23, r27
  mov r20, r23
  rcall write_volume_reg_1
  ret

chip_0:
  ;; Set Frequency
  lpm r20, Z+
  lpm r21, Z+
  ;andi r20, 0x0f
  ;andi r21, 0x3f
  cp r20, r0            ; if frequency == 0, turn off note
  brne freq_not_zero_0
  cp r21, r0
  brne freq_not_zero_0
  or r23, r4
  rjmp set_volume_0
freq_not_zero_0:
  ori r20, 0x80
  or r20, r26
  rcall write_frequency_reg_0

  ;; Set volume
set_volume_0:
  andi r23, 0x8f
  or r23, r27
  mov r20, r23
  rcall write_volume_reg_0
  ret

;; write_frequency_reg_0(r20=byte0, r21=byte1)
write_frequency_reg_0:
  out PORTB, r20
  cbi PORTD, PD4 ; CE=1
  nop
  cbi PORTD, PD3 ; WE=1
  ldi r17, BUS_DELAY
delay_1:
  dec r17
  brne delay_1
  sbi PORTD, PD3 ; WE=0
  sbi PORTD, PD4 ; CE=0
  nop
  nop

  out PORTB, r21
  cbi PORTD, PD4 ; CE=1
  nop
  cbi PORTD, PD3 ; WE=1
  ldi r17, BUS_DELAY
delay_2:
  dec r17
  brne delay_2
  sbi PORTD, PD3 ; WE=0
  sbi PORTD, PD4 ; CE=0
  ret

;; write_frequency_reg_1(r20=byte0, r21=byte1)
write_frequency_reg_1:
  out PORTB, r20
  cbi PORTD, PD6 ; CE=1
  nop
  cbi PORTD, PD5 ; WE=1
  ldi r17, BUS_DELAY
delay_4:
  dec r17
  brne delay_4
  sbi PORTD, PD5 ; WE=0
  sbi PORTD, PD6 ; CE=0
  nop
  nop

  out PORTB, r21
  cbi PORTD, PD6 ; CE=1
  nop
  cbi PORTD, PD5 ; WE=1
  ldi r17, BUS_DELAY
delay_5:
  dec r17
  brne delay_5
  sbi PORTD, PD5 ; WE=0
  sbi PORTD, PD6 ; CE=0
  ret

;; write_volume_reg_0(r20=byte0)
write_volume_reg_0:
  out PORTB, r20
  cbi PORTD, PD4 ; CE=1
  nop
  cbi PORTD, PD3 ; WE=1
  ldi r17, BUS_DELAY
delay_6:
  dec r17
  brne delay_6
  sbi PORTD, PD3 ; WE=0
  sbi PORTD, PD4 ; CE=0
  ret

;; write_volume_reg_1(r20=byte0)
write_volume_reg_1:
  out PORTB, r20
  cbi PORTD, PD6 ; CE=1
  nop
  cbi PORTD, PD5 ; WE=1
  ldi r17, BUS_DELAY
delay_3:
  dec r17
  brne delay_3
  sbi PORTD, PD5 ; WE=0
  sbi PORTD, PD6 ; CE=0
  ret

turn_off_all:
  ldi r20, 0x9f
  rcall write_volume_reg_0
  ldi r20, 0xbf
  rcall write_volume_reg_0
  ldi r20, 0xff
  rcall write_volume_reg_0
  ldi r20, 0x9f
  rcall write_volume_reg_1
  ldi r20, 0xbf
  rcall write_volume_reg_1
  ldi r20, 0xff
  rcall write_volume_reg_1
  ret

frequency_table:
  .db 0x00, 0x00 ; 0
  .db 0x00, 0x00 ; 1
  .db 0x00, 0x00 ; 2
  .db 0x00, 0x00 ; 3
  .db 0x00, 0x00 ; 4
  .db 0x00, 0x00 ; 5
  .db 0x00, 0x00 ; 6
  .db 0x00, 0x00 ; 7
  .db 0x00, 0x00 ; 8
  .db 0x00, 0x00 ; 9
  .db 0x00, 0x00 ; 10
  .db 0x00, 0x00 ; 11
  .db 0x00, 0x00 ; 12 C0
  .db 0x00, 0x00 ; 13 C#0/Db0
  .db 0x00, 0x00 ; 14 D0
  .db 0x00, 0x00 ; 15 D#0/Eb0
  .db 0x00, 0x00 ; 16 E0
  .db 0x00, 0x00 ; 17 F0
  .db 0x00, 0x00 ; 18 F#0/Gb0
  .db 0x00, 0x00 ; 19 G0
  .db 0x00, 0x00 ; 20 G#0/Ab0
  .db 0x00, 0x00 ; 21 A0
  .db 0x00, 0x00 ; 22 A#0/Bb0
  .db 0x00, 0x00 ; 23 B0
  .db 0x00, 0x00 ; 24 C1
  .db 0x00, 0x00 ; 25 C#1/Db1
  .db 0x00, 0x00 ; 26 D1
  .db 0x00, 0x00 ; 27 D#1/Eb1
  .db 0x00, 0x00 ; 28 E1
  .db 0x00, 0x00 ; 29 F1
  .db 0x00, 0x00 ; 30 F#1/Gb1
  .db 0x00, 0x00 ; 31 G1
  .db 0x00, 0x00 ; 32 G#1/Ab1
  .db 0x00, 0x00 ; 33 A1
  .db 0x00, 0x00 ; 34 A#1/Bb1
  .db 0x04, 0x3f ; 35 B1
  .db 0x0b, 0x3b ; 36 C2
  .db 0x05, 0x38 ; 37 C#2/Db2
  .db 0x03, 0x35 ; 38 D2
  .db 0x03, 0x32 ; 39 D#2/Eb2
  .db 0x06, 0x2f ; 40 E2
  .db 0x0b, 0x2c ; 41 F2
  .db 0x03, 0x2a ; 42 F#2/Gb2
  .db 0x0d, 0x27 ; 43 G2
  .db 0x09, 0x25 ; 44 G#2/Ab2
  .db 0x08, 0x23 ; 45 A2
  .db 0x08, 0x21 ; 46 A#2/Bb2
  .db 0x0a, 0x1f ; 47 B2
  .db 0x0d, 0x1d ; 48 C3
  .db 0x02, 0x1c ; 49 C#3/Db3
  .db 0x09, 0x1a ; 50 D3
  .db 0x01, 0x19 ; 51 D#3/Eb3
  .db 0x0b, 0x17 ; 52 E3
  .db 0x05, 0x16 ; 53 F3
  .db 0x01, 0x15 ; 54 F#3/Gb3
  .db 0x0e, 0x13 ; 55 G3
  .db 0x0c, 0x12 ; 56 G#3/Ab3
  .db 0x0c, 0x11 ; 57 A3
  .db 0x0c, 0x10 ; 58 A#3/Bb3
  .db 0x0d, 0x0f ; 59 B3
  .db 0x0e, 0x0e ; 60 C4
  .db 0x01, 0x0e ; 61 C#4/Db4
  .db 0x04, 0x0d ; 62 D4
  .db 0x08, 0x0c ; 63 D#4/Eb4
  .db 0x0d, 0x0b ; 64 E4
  .db 0x02, 0x0b ; 65 F4
  .db 0x08, 0x0a ; 66 F#4/Gb4
  .db 0x0f, 0x09 ; 67 G4
  .db 0x06, 0x09 ; 68 G#4/Ab4
  .db 0x0e, 0x08 ; 69 A4
  .db 0x06, 0x08 ; 70 A#4/Bb4
  .db 0x0e, 0x07 ; 71 B4
  .db 0x07, 0x07 ; 72 C5
  .db 0x00, 0x07 ; 73 C#5/Db5
  .db 0x0a, 0x06 ; 74 D5
  .db 0x04, 0x06 ; 75 D#5/Eb5
  .db 0x0e, 0x05 ; 76 E5
  .db 0x09, 0x05 ; 77 F5
  .db 0x04, 0x05 ; 78 F#5/Gb5
  .db 0x0f, 0x04 ; 79 G5
  .db 0x0b, 0x04 ; 80 G#5/Ab5
  .db 0x07, 0x04 ; 81 A5
  .db 0x03, 0x04 ; 82 A#5/Bb5
  .db 0x0f, 0x03 ; 83 B5
  .db 0x0b, 0x03 ; 84 C6
  .db 0x08, 0x03 ; 85 C#6/Db6
  .db 0x05, 0x03 ; 86 D6
  .db 0x02, 0x03 ; 87 D#6/Eb6
  .db 0x0f, 0x02 ; 88 E6
  .db 0x0c, 0x02 ; 89 F6
  .db 0x0a, 0x02 ; 90 F#6/Gb6
  .db 0x07, 0x02 ; 91 G6
  .db 0x05, 0x02 ; 92 G#6/Ab6
  .db 0x03, 0x02 ; 93 A6
  .db 0x01, 0x02 ; 94 A#6/Bb6
  .db 0x0f, 0x01 ; 95 B6
  .db 0x0d, 0x01 ; 96 C7
  .db 0x0c, 0x01 ; 97 C#7/Db7
  .db 0x0a, 0x01 ; 98 D7
  .db 0x09, 0x01 ; 99 D#7/Eb7
  .db 0x07, 0x01 ; 100 E7
  .db 0x06, 0x01 ; 101 F7
  .db 0x05, 0x01 ; 102 F#7/Gb7
  .db 0x03, 0x01 ; 103 G7
  .db 0x02, 0x01 ; 104 G#7/Ab7
  .db 0x01, 0x01 ; 105 A7
  .db 0x00, 0x01 ; 106 A#7/Bb7
  .db 0x0f, 0x00 ; 107 B7
  .db 0x0e, 0x00 ; 108 C8
  .db 0x0e, 0x00 ; 109 C#8/Db8
  .db 0x0d, 0x00 ; 110 D8
  .db 0x0c, 0x00 ; 111 D#8/Eb8
  .db 0x0b, 0x00 ; 112 E8
  .db 0x0b, 0x00 ; 113 F8
  .db 0x0a, 0x00 ; 114 F#8/Gb8
  .db 0x09, 0x00 ; 115 G8
  .db 0x09, 0x00 ; 116 G#8/Ab8
  .db 0x08, 0x00 ; 117 A8
  .db 0x08, 0x00 ; 118 A#8/Bb8
  .db 0x07, 0x00 ; 119 B8

signature:
  .db "SN76489 - Copyright 2015 - Michael Kohn - Version 0.01"


