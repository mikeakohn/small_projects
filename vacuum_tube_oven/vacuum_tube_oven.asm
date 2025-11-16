;; Vacuum Tube Oven - Copyright 2025 by Michael Kohn
;; Email: mike@mikekohn.net
;;   Web: https://www.mikekohn.net/
;;
;; Read data from a MAX31855 thermocouple and if temperature is below
;; threshold turn on some vacuum tubes to warm them up.

.avr8
.include "tn2313def.inc"

; 8MHz clock
; note: CLKSEL 0100
; lowfuse = 0xe4

; r0  = const 0
; r1  = const 1
; r2  = seconds count (reset at 60, carry to r3).
; r3  = minutes count
; r4  =
; r5  =
; r6  = const 60
; r7  = store SREG in interrupts
; r8  = element on / off.
; r9  =
; r10 = const '0'
; r11 =
; r12 =
; r13 = current seconds (safe from interrupt)
; r14 = current minute (safe from interrupt)
; r15 = const 255
; r16 = temp
; r17 = temp
; r18 =
; r19 =
; r20 = spi low byte
; r21 = spi high byte
; r22 = spi count
; r23 =
; r24 =
; r25 = whole number to print (hi)
; r26 = whole number to print (lo)
; r27 =
; r28 =
; r29 =
; r30 =
; r31 =

BAUD_RATE equ 9600
SPI_CS   equ 0
SPI_MOSI equ 1
SPI_MISO equ 2
SPI_SCLK equ 3

THRESHOLD_HI equ (85 << 2)
THRESHOLD_LO equ (80 << 2)

TIME_OFF_S equ SRAM_START+0
TIME_OFF_M equ SRAM_START+1

;; 7812 * 1024 = 7,999,488 (approximately 1 second).
TIMER_TOP equ 7900

.macro set_Z(string)
  ldi r30, (string * 2) & 0xff
  ldi r31, (string * 2) >> 8
.endm

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

  ;; r0 = 0, r1 = 1, r6 = 60, r10 = '0', r15 = 255
  clr r0
  ldi r17, 1
  mov r1, r17
  ldi r17, 60
  mov r6, r17
  ldi r17, '0'
  mov r10, r17
  ldi r17, 255
  mov r15, r17

  ;; Set up UART baud rate to 9600.
  ldi r17, ((8_000_000 / (8 * BAUD_RATE)) - 1) >> 8
  out UBRRH, r17
  ;ldi r17, ((8_000_000 / (8 * BAUD_RATE)) - 1) & 0xff
  ldi r17, 0x69
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
  ldi r17, (1 << WGM12) | (1 << CS12) | (1 << CS10)
  out TCCR1B, r17

  ;; Set up interrupts for timer.
  ldi r17, (1 << OCIE1A)
  out TIMSK, r17

  ;; Set up PORTB.
  ;; PB0: Software /SPI_CS
  ;; PB1: Software SPI_MOSI
  ;; PB2: Software SPI_MISO
  ;; PB3: Software SPI_SCLK
  ;; PB4:
  ;; PB5: MOSI
  ;; PB6: MISO
  ;; PB7: UCSK
  ldi r17, 0x0b
  out DDRB, r17
  ldi r17, 0x08
  out PORTB, r17

  ;; Set up PORTD.
  ;; PD4: LED
  ;; PD5: Vacuum Tube
  ldi r17, 0x30
  out DDRD, r17
  out PORTD, r17

  ;; Erase 13 bytes of RAM.
  ldi r26, SRAM_START
  ldi r27, 0
  ldi r17, 13
memset:
  st X+, r0
  dec r17
  brne memset

  ;; Setup seconds / minutes.
  mov r2, r0
  mov r3, r0
  mov r8, r1
  sts TIME_OFF_S, r0
  sts TIME_OFF_M, r0

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

  ;ldi r20, 0x03
  ;ldi r21, 0x19
  ;rcall sign_extend_14

main:
  rcall read_spi
  rcall send_xml

  sbrc r8, 0
  rcall element_is_on
  sbrs r8, 0
  rcall element_is_off

  rcall delay
  rjmp main

element_is_on:
  sbi PORTD, 4
  sbi PORTD, 5
  rcall is_lower_than_threshold_h
  cpi r17, 1
  breq element_is_on_exit
  mov r8, r0
  movw r26, r2
  sts TIME_OFF_S, r26
  sts TIME_OFF_M, r27
element_is_on_exit:
  ret

element_is_off:
  cbi PORTD, 4
  cbi PORTD, 5
  rcall is_lower_than_threshold_l
  cpi r17, 0
  breq element_is_off_exit
  mov r8, r1
element_is_off_exit:
  ret

read_spi:
  cbi PORTB, SPI_CS
  ldi r20, 0
  ldi r21, 0
  ldi r22, 14
read_spi_loop:
  sbi PORTB, SPI_SCLK
  lsl r20
  rol r21
  sbic PINB, SPI_MISO
  ori r20, 1
  cbi PORTB, SPI_SCLK
  dec r22
  brne read_spi_loop
  sbi PORTB, SPI_CS
  rcall sign_extend_14
  ret

sign_extend_14:
  lsl r21
  lsl r21
  asr r21
  asr r21
  ret

is_lower_than_threshold_h:
  ldi r17, 1
  ldi r26, THRESHOLD_HI >> 8
  cpi r20, THRESHOLD_HI & 0xff
  cpc r21, r26
  brlo is_lower_than_threshold_h_exit
  ldi r17, 0
is_lower_than_threshold_h_exit:
  ret

is_lower_than_threshold_l:
  ldi r17, 1
  ldi r26, THRESHOLD_LO >> 8
  cpi r20, THRESHOLD_LO & 0xff
  cpc r21, r26
  brlo is_lower_than_threshold_l_exit
  ldi r17, 0
is_lower_than_threshold_l_exit:
  ret

send_xml:
  set_Z(xml_start)
  rcall send_string
  set_Z(xml_raw_0)
  rcall send_string
  rcall send_raw
  set_Z(xml_raw_1)
  rcall send_string
  set_Z(xml_temp_0)
  rcall send_string
  rcall send_temp
  set_Z(xml_temp_1)
  rcall send_string
  set_Z(xml_time_0)
  rcall send_string
  cli
  movw r12, r2
  sei
  rcall send_time
  set_Z(xml_time_1)
  rcall send_string
  set_Z(xml_element_0)
  rcall send_string
  rcall send_element_value
  set_Z(xml_element_1)
  rcall send_string
  set_Z(xml_time_off_0)
  rcall send_string
  lds r12, TIME_OFF_S
  lds r13, TIME_OFF_M
  rcall send_time
  set_Z(xml_time_off_1)
  rcall send_string
  set_Z(xml_end)
  rcall send_string
  ret

send_raw:
  mov r19, r21
  lsr r19
  lsr r19
  lsr r19
  lsr r19
  call send_hex
  mov r19, r21
  andi r19, 0x0f
  call send_hex
  mov r19, r20
  lsr r19
  lsr r19
  lsr r19
  lsr r19
  call send_hex
  mov r19, r20
  andi r19, 0x0f
  call send_hex
  ret

send_hex:
  cpi r19, 10
  brlo send_hex_09
  ldi r23, 'A' - 10
  add r19, r23
  rcall uart_send_byte
  ret
send_hex_09:
  add r19, r10
  rcall uart_send_byte
  ret

send_temp:
  tst r21
  brpl send_temp_not_negative
  ldi r19, '-'
  rcall uart_send_byte
  com r20
  com r21
  add r20, r1
  adc r21, r0
send_temp_not_negative:
  mov r24, r20
  mov r25, r21
  ldi r18, 0
send_temp_div_loop:
  mov r17, r20
  andi r17, 3
  lsr r25
  ror r24
  lsr r25
  ror r24
  rcall send_whole_number
  ldi r19, '.'
  rcall uart_send_byte
  cpi r17, 1
  breq send_temp_25
  cpi r17, 2
  breq send_temp_50
  cpi r17, 3
  breq send_temp_75
  ldi r19, '0'
  rcall uart_send_byte
  ldi r19, '0'
  rcall uart_send_byte
  ret
send_temp_25:
  ldi r19, '2'
  rcall uart_send_byte
  ldi r19, '5'
  rcall uart_send_byte
  ret
send_temp_50:
  ldi r19, '5'
  rcall uart_send_byte
  ldi r19, '0'
  rcall uart_send_byte
  ret
send_temp_75:
  ldi r19, '7'
  rcall uart_send_byte
  ldi r19, '5'
  rcall uart_send_byte
  ret

div_10:
  ldi r26, 0
  ldi r27, 0
div_10_loop:
  cpi r25, 0
  brne div_10_high_not_0
  cpi r24, 10
  brlo div_10_exit
div_10_high_not_0:
  subi r24, 10
  sbc r25, r0
  adiw r26, 1
  rjmp div_10_loop
div_10_exit:
  mov r19, r24
  add r19, r10
  mov r24, r26
  mov r25, r27
  ret

send_element_value:
  ldi r19, 'o'
  rcall uart_send_byte
  cp r8, r1
  breq send_element_value_on
  ldi r19, 'f'
  rcall uart_send_byte
  rcall uart_send_byte
  ret
send_element_value_on:
  ldi r19, 'n'
  rcall uart_send_byte
  ret

send_time:
  mov r24, r13
  mov r25, r0
  cpi r24, 10
  brge send_time_minute_no_0
  ldi r19, '0'
  rcall uart_send_byte
send_time_minute_no_0:
  rcall send_whole_number
  ldi r19, ':'
  rcall uart_send_byte
  mov r24, r12
  mov r25, r0
  cpi r24, 10
  brge send_time_second_no_0
  ldi r19, '0'
  rcall uart_send_byte
send_time_second_no_0:
  rcall send_whole_number
  ret

send_whole_number:
  mov r4, r0
send_whole_number_push_loop:
  rcall div_10
  push r19
  add r4, r1
  cpi r25, 0
  brne send_whole_number_push_loop
  cpi r26, 0
  brne send_whole_number_push_loop
send_whole_number_pop_loop:
  pop r19
  rcall uart_send_byte
  dec r4
  brne send_whole_number_pop_loop
  ret

; void send_string(Z)
send_string:
  lpm r19, Z+
  cpi r19, 0
  breq send_string_exit
  rcall uart_send_byte
  rjmp send_string
send_string_exit:
  ret

; void uart_send_byte(r19)
uart_send_byte:
  sbis UCSRA, UDRE
  rjmp uart_send_byte
  out UDR, r19
  ret

delay:
  ldi r17, 80
delay_loop_outer:
  ldi r24, 0x00
  ldi r25, 0x00
delay_loop:
  adiw r24, 1
  brne delay_loop
  dec r17
  brne delay_loop_outer
  ret

timer1_interrupt:
  in r7, SREG
  inc r2
  cp r2, r6
  brne timer1_interrupt_exit
  mov r2, r0
  inc r3
timer1_interrupt_exit:
  out SREG, r7
  reti

.align 16
xml_start:
  .db "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r\n<max31855>\r\n", 0

.align 16
xml_raw_0:
  .db "  <raw>", 0

.align 16
xml_raw_1:
  .db "</raw>\r\n", 0

.align 16
xml_temp_0:
  .db "  <temp>", 0

.align 16
xml_temp_1:
  .db "</temp>\r\n", 0

.align 16
xml_time_0:
  .db "  <time>", 0

.align 16
xml_time_1:
  .db "</time>\r\n", 0

.align 16
xml_element_0:
  .db "  <element>", 0

.align 16
xml_element_1:
  .db "</element>\r\n", 0

.align 16
xml_time_off_0:
  .db "  <time_off>", 0

.align 16
xml_time_off_1:
  .db "</time_off>\r\n", 0

.align 16
xml_end:
  .db "</max31855>\r\n\r\n", 0

