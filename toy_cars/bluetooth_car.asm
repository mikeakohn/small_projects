;; Bluetooth Car - Copyright 2013 by Michael Kohn
;; Email: mike@mikekohn.net
;;   Web: https://www.mikekohn.net/
;;
;; Control RC car with bluetooth and an Android phone.

.avr8
.include "tn2313def.inc"

;  cycles  time   @20MHz:
;   20000: 1ms
;   10000: 0.5ms
;    1000: 0.05ms

; interrupts  time   @0.05ms increments
;         20  1ms 
;         40  2ms 
;        400 20ms 

; r0  = 0
; r1  =
; r2  = PORTB on servo reset (20ms of interrupts)
; r3  =
; r4  =
; r5  =
; r6  =
; r7  = Status register save
; r17 = temp
; r18 = temp
; r19 = temp
; r20 = UART received data
; r21 = temp in main
; r23 = interrupt count
; r24 = used in send_char function
; r25 = motor state (PORTB)
; r26 = number of interrupts to wait before turning off motor (pwm)
; r30 = bluetooth watchdog low
; r31 = bluetooth watchdog high

; Command byte:
; 7 6 5 4 3 2 1 0
; V V V V V V D D
;
; D = device (0=rear wheels, 1=front wheels, 2=LEDs)
; V = value from -32 to 31
;
; Rear wheels  = -31 to 31 where 0 is stop
; Front wheels = 0=center, 1=turned, 0=turned opposite of 1
; LEDs         = 0=off, 1=LED1 on, 2 = LED2 on, 3=both on

; note: CLKSEL 0110

; max count for signal high (little endian)
M0_MAX equ SRAM_START

.org 0x000
  rjmp start
.org 0x008
  rjmp service_motors
.org 0x00a
  rjmp service_motors

start:
  ;; I'm busy.  Don't interrupt me!
  cli

  ;; Setup some registers
  eor r0, r0   ; r0 = constant 0

  ;; Set up PORTB
  ser r17
  ldi r18, 0
  out DDRB, r17             ; entire port B is output
  out PORTB, r18            ; turn off all of port B
  out DDRD, r17             ; entire port D is output
  out PORTD, r0             ; turn off all of port D

  ;sbi PORTD, 5 ; debug.. turn on PD5

  ;; r4 = SRAM_START+16, r5 = 20, r6 = SRAM_START+24
  ;ldi r17, (M0_MODE&255)
  ;mov r4, r17
  ;ldi r17, 20
  ;mov r5, r17
  ;ldi r17, (M0_UPDATE&255)
  ;mov r6, r17

  ;; r23 = interrupt counts, r26 = interrupt count to shut off motor (pwm)
  eor r23, r23
  eor r26, r26

  ;; Motors should all be off
  eor r25, r25

  ;; r31:r30 = bluetooth watchdog (0.5s is desired)
  ldi r31, 10000>>8
  ldi r30, 10000&0xff

  ;; put input state (r21) in command mode
  ;; ser r21

  ;; Set up stack ptr
  ;ldi r17, RAMEND>>8
  ;out SPH, r17
  ldi r17, RAMEND&255
  out SPL, r17

  ;; Set up rs232 baud rate
  ;eor r17, r17
  out UBRRH, r0
  ldi r17, 129
  out UBRRL, r17           ; 129 @ 20MHz = 9600 baud

  ;; Set up rs232 options
  ldi r17, (1<<UCSZ0)|(1<<UCSZ1)    ; sets up data as 8N1
  out UCSRC, r17
  ldi r17, (1<<TXEN)|(1<<RXEN)      ; enables send/receive
  out UCSRB, r17
  out UCSRA, r0

  ;; Set up TIMER1
  ;lds r17, PRR
  ;andi r17, 255 ^ (1<<PRTIM1)
  ;sts PRR, r17                   ; turn of power management bit on TIM1

  ldi r17, (1000>>8)
  out OCR1AH, r17
  ldi r17, (1000&0xff)            ; compare to 1000 clocks (0.05ms)
  out OCR1AL, r17

  ldi r17, (1<<OCIE1A)
  out TIMSK, r17                  ; enable interrupt comare A 
  out TCCR1C, r0
  out TCCR1A, r0                  ; normal counting (0xffff is top, count up)
  ldi r17, (1<<CS10)|(1<<WGM12)   ; CTC OCR1A
  out TCCR1B, r17                 ; prescale = 1 from clock source
  
  ; Fine, I can be interrupted now
  sei

main:
  ;in r20, UCSRA           ; poll uart to see if there is a data waiting
  ;sbrs r20, RXC
  sbis UCSRA, RXC
  rjmp main               ; if no data, loop around

  in r20, UDR

  ;; ECHO - just for checking things are okay
  mov r24, r20
  rcall send_char

  ;sbi PORTD, 5 ; debug.. turn on PD5

  ;; We got some data so the bluetooth connection is still alive,
  ;; kick the software watchdog.
  ldi r31, 10000>>8
  ldi r30, 10000&0xff            ; could remove line, but it's more accurate

  ; cpi r21, 255
  ; brne process_command
  mov r21, r20
  andi r21, 3                    ; r21 now holds device number
  lsr r20
  lsr r20                        ; r20 now holds value

  ;; Check and service the rear
  cpi r21, 0
  brne not_rear
  cpi r20, 0
  brne rear_not_zero
  cbr r25, 0x3                   ; turn off motors
  out PORTB, r25
  rjmp main
rear_not_zero:
  sbrc r20, 5                    ; if bit 5 is set, move wheels backwards
  rjmp rear_negative
  cbr r25, 0x2                   ; motor is forward 
  sbr r25, 0x1
  ;lsl r20
  ;lsl r20
  ldi r24, 30
  add r20, r24
  mov r26, r20
  rjmp main
rear_negative:
  cbr r20, (1<<5)                ; clear sign bit
  cbr r25, 0x1                   ; motor is backwards 
  sbr r25, 0x2
  ;lsl r20
  ;lsl r20
  ldi r24, 30
  add r20, r24
  mov r26, r20
  rjmp main

  ;; Check and service the front
not_rear:
  cpi r21, 1
  brne not_front
  cpi r20, 1
  brne front_not_1
  cbr r25, (1<<3)
  sbr r25, (1<<2)
  rjmp main
front_not_1:
  cpi r20, 0
  brne front_not_0
  cbr r25, (3<<2)
  rjmp main
front_not_0:
  cpi r20, 0x3f 
  brne front_not_neg1
  cbr r25, (1<<2)
  sbr r25, (1<<3)
  rjmp main
front_not_neg1:
  rjmp main

  ;; Check and service the LEDS
not_front:
  cpi r21, 2
  brne not_lights

  andi r20, 3
  swap r20
  out PORTD, r20
  rjmp main

not_lights:
  rjmp main

service_motors:
  ; save status register
  in r7, SREG

  ; watchdog for bluetooth, if no data in 500ms, then reset motors
  sbiw r30, 1
  brne watchdog_ignore
  ;cbi PORTD, 5 ; debug.. turn on PD5
  cbr r25, 0x0f

watchdog_ignore:

  ; increment interrupt counter (PWM)
  inc r23
  cp r23, r26
  brne dont_service_pwm
  cbi PORTB, 0
  cbi PORTB, 1
dont_service_pwm:
  cpi r23, 61
  brne dont_reset_pwm
  out PORTB, r25
  clr r23
dont_reset_pwm:

  out SREG, r7
  reti

; void send_char(r24)  : r14 trashed
send_char:
  ;in r14, UCSRA       ; check to see if it's okay to send a char
  ;sbrs r14, UDRE
  sbis UCSRA, UDRE
  rjmp send_char      ; if it's not okay, loop around :)
  out UDR, r24        ; output a char over rs232
  ret

signature:
.db "Bluetooth Car - Copyright 2013 - Michael Kohn - Version 0.01",0

;dc_motor_lookup:
;.db 0, 0, 20, 0, 40, 0, 60, 0, 80, 0, 100, 0, 120, 0, 140, 0, 160, 0 
;.db 180, 0, 200, 0, 220, 0, 240, 0, 4, 1, 24, 1, 44, 1, 64, 1, 84, 1
;.db 104, 1, 124, 1, 144, 1, 144, 1, 144, 1, 144, 1, 144, 1, 144, 1
;.db 144, 1, 144, 1, 144, 1, 144, 1, 144, 1, 144, 1, 144, 1

