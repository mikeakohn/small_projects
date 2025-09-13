;; Xbee Car
;;
;; Copyright 2016 - By Michael Kohn
;; https://www.mikekohn.net/
;; mike@mikekohn.net
;;
;; Control an R/C car with an Xbee Pro module.

.include "msp430x2xx.inc"

; 2.0 ms = 152 interrupts
; 0.3 ms = 23 interrupts
; 0.6 ms = 46 interrupts
; 1.0 ms = 76 interrupts

RAM equ 0x0200

WATCHDOG equ RAM+48

;  r4 =
;  r5 =
;  r6 = byte coming in from UART
;  r7 = interrupt count
;  r8 =
;  r9 =
; r10 = curr drive speed
; r11 = curr drive direction
; r12 = horn toggle value
; r13 = new drive speed
; r14 = new drive direction
; r15 = temp in interrupt

  .org 0xc000
start:
  ;; Turn off watchdog
  mov.w #(WDTPW|WDTHOLD), &WDTCTL

  ;; Turn off interrupts
  dint

  ;; Set up stack pointer
  mov.w #0x0400, SP

  ;; Set MCLK to 1 MHz with DCO 
  mov.b #DCO_3, &DCOCTL
  mov.b #RSEL_7, &BCSCTL1
  mov.b #0, &BCSCTL2

  ;; Set ACLK to 32.768kHz external crystal
  ;mov.b #XCAP_3, &BCSCTL3

  ;; Set up output pins
  ;; P1.1 = RX
  ;; P1.2 = TX
  ;; P1.4 = Steering Motor
  ;; P1.5 = Steering Motor
  ;; P2.0 = Drive Motor
  ;; P2.1 = Drive Motor
  ;; P2.3 = Horn
  ;; P2.4 = LED 0
  ;; P2.5 = LED 1
  mov.b #0x30, &P1DIR
  mov.b #0x00, &P1OUT
  mov.b #0x06, &P1SEL
  mov.b #0x06, &P1SEL2
  mov.b #0x3b, &P2DIR
  mov.b #0x00, &P2OUT
  ;mov.b #0x00, &P2SEL

  ;; Set up Timer (interrupt 400 times a second @ 1 MHz)
  mov.w #2500, &TACCR0
  mov.w #(TASSEL_2|MC_1), &TACTL ; SMCLK, DIV1, COUNT to TACCR0
  mov.w #CCIE, &TACCTL0
  mov.w #0, &TACCTL1

  ;; Setup UART (9600 @ 1 MHz)
  mov.b #UCSSEL_2|UCSWRST, &UCA0CTL1
  mov.b #0, &UCA0CTL0
  mov.b #UCBRS_2, &UCA0MCTL
  mov.b #109, &UCA0BR0
  ;mov.b #UCBRS_3, &UCA0MCTL
  ;mov.b #3, &UCA0BR0
  mov.b #0, &UCA0BR1
  bic.b #UCSWRST, &UCA0CTL1

  mov.w #50, &WATCHDOG
  mov.w #0, r6
  mov.w #0, r7
  mov.w #0, r10
  mov.w #0, r11
  mov.w #0, r12
  mov.w #0, r13
  mov.w #0, r13

  ;; Interrupts back on
  eint

  ; DEBUG
  ;mov.b #'A', &UCA0TXBUF

main:
  bit.b #UCA0RXIFG, &IFG2
  jz main

  mov.b &UCA0RXBUF, r6
  mov.w #200, &WATCHDOG

.if 0
  mov.b #'*', &UCA0TXBUF
wait_tx:
  bit.b #UCA0TXIFG, &IFG2
  jz wait_tx
.endif

  cmp.b #1, r6
  jnz dont_turn_horn_not_on
  mov.b #8, r12
  jmp main
dont_turn_horn_not_on:

  cmp.b #2, r6
  jnz dont_turn_horn_not_off
  mov.b #0, r12
  bic.b #8, &P2OUT
  jmp main
dont_turn_horn_not_off:

  cmp.b #3, r6
  jnz dont_turn_headlights_on
  bis.b #0x10, &P2OUT
  jmp main
dont_turn_headlights_on:

  cmp.b #4, r6
  jnz dont_turn_headlights_off
  bic.b #0x10, &P2OUT
  jmp main
dont_turn_headlights_off:

  cmp.b #5, r6
  jnz dont_turn_brakelights_on
  bis.b #0x20, &P2OUT
  jmp main
dont_turn_brakelights_on:

  cmp.b #6, r6
  jnz dont_turn_brakelights_off
  bic.b #0x20, &P2OUT
  jmp main
dont_turn_brakelights_off:

  ;; If bit 7 is clear, ignore this command.
  bit.b #0x80, r6
  jz main

  ;; If bit 6 is set, change motor speed.
  bit.b #0x40, r6
  jnz modify_motor_speed

  ;; Adjust steering.
  bic.b #0xc0, r6
  cmp.b #10, r6
  jl turn_left
  cmp.b #53, r6
  jge turn_right
  bic.b #0x30, &P1OUT
  jmp main

turn_left:
  bic.b #0x30, &P1OUT
  bis.b #0x20, &P1OUT
  jmp main

turn_right:
  bic.b #0x30, &P1OUT
  bis.b #0x10, &P1OUT
  jmp main

modify_motor_speed:
  bic.w #0xc0, r6
  mov.b direction_table(r6), r14
  rla.w r6
  mov.w speed_table(r6), r13
  mov.w r13, r15
  jmp main

timer_interrupt:
  ;; Toggle horn if needed.
  xor.b r12, &P2OUT

  ;; Motor PWM
  cmp.w r10, r7
  jnz no_drive_pwm_change
  bic.b #0x03, &P2OUT
no_drive_pwm_change:
  inc.w r7
  cmp.w #127, r7
  jnz no_drive_pwm_reset
  mov.w #0, r7
  cmp.w r14, r11
  jz dont_clear_motor_pins
  bic.b #0x03, &P2OUT
dont_clear_motor_pins:
  mov.w r13, r10
  mov.w r14, r11
  bis.b r11, &P2OUT
no_drive_pwm_reset:

  ;; Decrement the watchdog.
  dec.w &WATCHDOG
  jnz not_25_ms_yet

  ;; If watchdog reaches 0, stop motor and center tires.
  bic.b #0x30, &P1OUT
  bic.b #0x0b, &P2OUT
  mov.w #0, r12
  mov.w #0, r13
  mov.w #0, r14

not_25_ms_yet:
  reti 

speed_table:
  dw 0x0080, 0x007a, 0x0074, 0x006e, 0x0068, 0x0062, 0x005c, 0x0056,
  dw 0x0050, 0x004a, 0x0044, 0x003e, 0x0038, 0x0032, 0x002c, 0x0026,
  dw 0x0020, 0x001a, 0x0014, 0x000e, 0x0008, 0x0000, 0x0000, 0x0000,
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
  dw 0x0000, 0x0000, 0x0000, 0x0008, 0x000e, 0x0014, 0x001a, 0x0020,
  dw 0x0026, 0x002c, 0x0032, 0x0038, 0x003e, 0x0044, 0x004a, 0x0050,
  dw 0x0056, 0x005c, 0x0062, 0x0068, 0x006e, 0x0074, 0x007a, 0x0080,

direction_table:
  db 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
  db 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
  db 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00,
  db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  db 0x00, 0x00, 0x00, 0x02, 0x02, 0x02, 0x02, 0x02,
  db 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,
  db 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,


  org 0xffe8
vectors:
  dw 0
  dw 0
  dw 0
  dw 0
  dw 0
  dw timer_interrupt       ; Timer_A2 TACCR0, CCIFG
  dw 0
  dw 0
  dw 0
  dw 0
  dw 0
  dw start                 ; Reset



