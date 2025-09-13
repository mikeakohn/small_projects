;; IR Car
;;
;; Copyright 2012 - By Michael Kohn
;; https://www.mikekohn.net/
;; mike@mikekohn.net
;;
;; Convert a cheapo R/C car into an IR car using the Syma S107 helicopter
;; remote. Microcontroller is MSP430F2013.

.include "msp430g2x31.inc"

; 2.0 ms = 152 interrupts
; 0.3 ms = 23 interrupts
; 0.6 ms = 46 interrupts

; 500ms = 38000 interrupts

; HH YAW PTCH THROTTLE YAW_CORRECT
; YAW = 0-126  63
; PITCH = 0-126 63
; THROTTLE = 0-126
; CORR = 0-126 63

RAM equ 0x0200
HEADER equ 152
SHORT equ 23
LONG equ 46

ALL_MOTORS_OFF equ 0xcc

DRIVE_MOTOR_STOP equ 0xc0
DRIVE_MOTOR_F_OFF equ 0xc0|0x10
DRIVE_MOTOR_B_OFF equ 0xc0|0x20
DRIVE_MOTOR_F_ON equ 0x80|0x10
DRIVE_MOTOR_B_ON equ 0x40|0x20

STEER_MOTOR_C equ 0x0c
;STEER_MOTOR_L_OFF equ 0x0c|0x01
;STEER_MOTOR_R_OFF equ 0x0c|0x02
STEER_MOTOR_L equ 0x08|0x01
STEER_MOTOR_R equ 0x04|0x02

DRIVE_CURR equ RAM+32
STEERING_CURR equ RAM+33
WATCHDOG equ RAM+34

;  r4 = state (0=idle, 1=header_on, 2=header_off, 3=first half, 4=second)
;  r5 = interupt count
;  r6 = pointer to next byte coming in 
;  r7 = current byte
;  r8 = bit count
;  r9 = bit time len
; r10 = interrupt count (drive)
; r11 = drive speed
; r12 = motor_on
; r13 = interrupt routine
; r14 = motor_off
; r15 =

  .org 0xf800
start:
  ;; Turn off watchdog
  mov.w #(WDTPW|WDTHOLD), &WDTCTL

  ;; Please don't interrupt me
  dint

  ;; r13 points to which interrupt routine should be called
  ;mov.w #led_off, r13

  ;; Set up stack pointer
  mov.w #0x0280, SP

  ;; Set MCLK to 16 MHz with DCO 
  mov.b #DCO_4, &DCOCTL
  mov.b #RSEL_15, &BCSCTL1
  mov.b #0, &BCSCTL2

.if 0
  ;; Set MCLK to 16 MHz external crystal
  bic.w #OSCOFF, SR
  bis.b #XTS, &BCSCTL1
  mov.b #LFXT1S_3, &BCSCTL3
  ;mov.b #LFXT1S_3|XCAP_1, &BCSCTL3
test_osc:
  bic.b #OFIFG, &IFG1
  mov.w #0x00ff, r15
dec_again:
  dec r15
  jnz dec_again
  bit.b #(OFIFG), &IFG1
  jnz test_osc
  mov.b #(SELM_3|SELS), &BCSCTL2
.endif

  ;; Set up output pins
  ;; P2.6 = IR Input
  ;; P2.7 = Headlights
  ;; P1.0 = NPN Steering Motor (Outer)
  ;; P1.1 = NPN Steering Motor (Inner)
  ;; P1.2 = PNP Steering Motor (Inner)
  ;; P1.3 = PNP Steering Motor (Outer)
  ;; P1.4 = NPN Drive Motor (Outer)
  ;; P1.5 = NPN Drive Motor (Inner)
  ;; P1.6 = PNP Drive Motor (Inner)
  ;; P1.7 = PNP Drive Motor (Outer)
  mov.b #0xff, &P1DIR
  mov.b #ALL_MOTORS_OFF, &P1OUT
  mov.b #0x80, &P2DIR
  mov.b #0x00, &P2OUT   ; lights off!
  mov.b #0, &P2SEL

  ;; Set up Timer
  mov.w #210, &TACCR0
  mov.w #(TASSEL_2|MC_1), &TACTL ; SMCLK, DIV1, COUNT to TACCR0
  mov.w #CCIE, &TACCTL0
  mov.w #0, &TACCTL1

  mov.b #1, &RAM    ; Yaw
  mov.b #1, &RAM+1  ; Pitch
  mov.b #1, &RAM+2  ; Throttle
  mov.b #1, &RAM+3  ; Yaw correction

  mov.b #0, &DRIVE_CURR
  mov.b #0, &STEERING_CURR
  mov.w #0, &WATCHDOG
  mov.b #0, r11
  mov.b #ALL_MOTORS_OFF, r12
  mov.b #ALL_MOTORS_OFF, r14
  mov.b #0, r7

.if 0
  mov.w #0x210, r6
clear_mem:
  mov.b #0, 0(r6)
  inc r6
  cmp.w #0x250, r6
  jne clear_mem
.endif

  ;; Okay, I can be interrupted now
  eint

clear_int_count:
  mov.w #0, r10
  mov.b r12, &P1OUT      ; motor on

  inc.w &WATCHDOG
  cmp.w #20, &WATCHDOG
  jlo main

  ; haven't seen a command in a while
  mov.b #ALL_MOTORS_OFF, r12
  mov.b #ALL_MOTORS_OFF, r14

main:
  bit.b #0x40, &P2IN
  jeq read_command

  cmp.w #3800, r10
  jhs clear_int_count
  cmp.w r11, r10
  jlo main
  mov.b r14, &P1OUT      ; motor off
  jmp main

read_command:
  mov.w #0, &WATCHDOG
  mov.w #0, r5
wait_low:
  bit.b #0x40, &P2IN
  jz wait_low

  ;; if r5 is less than 100, something went wrong.  Not sure how important
  ;; this check really is
  cmp.w #100, r5
  jlo main

start_signal:

  ;; signal should be low, should we count?
  ;; check there is no IR
  mov.w #0, r5
wait_ir_off_header:
  cmp.w #200, r5
  jhs main                ; pause is wayyyy too long, bail out
  bit.b #0x40, &P2IN
  jnz wait_ir_off_header  ; wait for data on IR sensor

  mov.w #RAM, r6
  ;;mov.w #RAM+16, r9
receive_next_byte:
  mov.b #0, r7            ; shouldn't be needed
  mov.b #8, r8
receive_next_bit:

  ;; check IR signal is on
  mov.w #0, r5
wait_ir_on:
  cmp.w #120, r5
  jhs start_signal        ; looks like the start signal
  cmp.w #70, r5
  jhs main                ; signal is wayyyy too long, bail out
  bit.b #0x40, &P2IN
  jz wait_ir_on           ; wait for data on IR sensor

  ;mov.w r5, @r9
  ;add.w #2, r9

  ;; check there is no IR
  mov.w #0, r5
wait_ir_off:
  cmp.w #100, r5
  jhs main                ; pause is wayyyy too long, bail out
  bit.b #0x40, &P2IN
  jnz wait_ir_off         ; wait for data on IR sensor

  ;mov.w r5, @r9
  ;add.w #2, r9

  rla.b r7
  cmp #SHORT+12, r5
  jlo not_a_zero
  bis.b #1, r7

not_a_zero:
  dec.b r8
  jnz receive_next_bit

  mov.b r7, 0(r6)
  inc r6

  cmp.w #RAM+4, r6
  jne receive_next_byte

  ;; We have a command now
  bit.b #128, &RAM+2
  jz lights_off
  bis.b #0x80, &P2OUT
  jmp done_with_lights
lights_off:
  bic.b #0x80, &P2OUT
done_with_lights:
  ;jmp main

  ;; Do drive motor
  cmp.b #58, &RAM+1
  jhs not_forward
  cmp.b #1, &DRIVE_CURR
  jeq already_forward
  call #drive_inductor_delay
  mov.b #1, &DRIVE_CURR
already_forward:
  mov.b #57, r11
  sub.b &RAM+1, r11
  rla.b r11
  add.w #drive_speed, r11
  mov.w @r11, r11
  bic.b #0xf0, r12
  bic.b #0xf0, r14
  bis.b #DRIVE_MOTOR_F_ON, r12 
  bis.b #DRIVE_MOTOR_F_OFF, r14
  jmp done_main_motor

not_forward:
  cmp.b #69, &RAM+1
  jhs not_stop
  cmp.b #0, &DRIVE_CURR
  jeq already_stopped
  call #drive_inductor_delay
  mov.b #0, &DRIVE_CURR
already_stopped:
  mov.w #0, r11
  bic.b #0xf0, r12
  bic.b #0xf0, r14
  bis.b #DRIVE_MOTOR_STOP, r12
  bis.b #DRIVE_MOTOR_STOP, r14
  jmp done_main_motor

not_stop:
  cmp.b #-1, &DRIVE_CURR
  jeq already_backward
  call #drive_inductor_delay
  mov.b #-1, &DRIVE_CURR
already_backward:
  mov.b &RAM+1, r11
  sub.b #69, r11
  rla.b r11
  add.w #drive_speed, r11
  mov.w @r11, r11
  bic.b #0xf0, r12
  bic.b #0xf0, r14
  bis.b #DRIVE_MOTOR_B_ON, r12
  bis.b #DRIVE_MOTOR_B_OFF, r14
  ;jmp done_main_motor

done_main_motor:
  ;jmp main

  ;; Do steering motor
  cmp.b #40, &RAM+0
  jhs not_left
  cmp.b #1, &STEERING_CURR
  jeq done_steering_motor
  call #steering_inductor_delay
  mov.b #1, &STEERING_CURR
already_left:
  bic.b #0x0f, r12
  bic.b #0x0f, r14
  bis.b #STEER_MOTOR_L, r12
  bis.b #STEER_MOTOR_L, r14
  jmp done_steering_motor

not_left:
  cmp.b #76, &RAM+0
  jhs not_center
  cmp.b #0, &STEERING_CURR
  jeq done_steering_motor
  call #steering_inductor_delay
  mov.b #0, &STEERING_CURR
already_center:
  bic.b #0x0f, r12
  bic.b #0x0f, r14
  bis.b #STEER_MOTOR_C, r12
  bis.b #STEER_MOTOR_C, r14
  jmp done_steering_motor

not_center:
  cmp.b #-1, &STEERING_CURR
  jeq done_steering_motor
  call #steering_inductor_delay
  mov.b #-1, &STEERING_CURR
already_right:
  bic.b #0x0f, r12
  bic.b #0x0f, r14
  bis.b #STEER_MOTOR_R, r12
  bis.b #STEER_MOTOR_R, r14
  ;jmp done_steering_motor

done_steering_motor:
  jmp main

drive_inductor_delay:
  bis.b #0xc0, &P1OUT
  mov.w #0, r5
drive_inductor_delay_wait:
  cmp.w #2, r5
  jlo drive_inductor_delay_wait
  ret

steering_inductor_delay:
  bis.b #0x0c, &P1OUT
  mov.w #0, r5
steering_inductor_delay_wait:
  cmp.w #2, r5
  jlo steering_inductor_delay_wait
  ret

timer_interrupt:
  inc.w r5
  inc.w r10
  reti 

drive_speed:
  dw 76,   152,   228,  304,  380,  456,  532,  608, 
  dw 684,  760,   836,  912,  988, 1064, 1140, 1216, 
  dw 1292, 1368, 1444, 1520, 1596, 1672, 1748, 1824, 
  dw 1900, 1976, 2052, 2128, 2204, 2280, 2356, 2432, 
  dw 2508, 2584, 2660, 2736, 2812, 2888, 2964, 3040, 
  dw 3116, 3192, 3268, 3344, 3420, 3496, 3572, 3648, 
  dw 3724, 3800, 3800, 3800, 3800, 3800, 3800, 3800,
  dw 3800, 3800, 3800, 3800, 3800, 3800, 3800, 3800, 

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

