;; IR Car (dsPICF3012)
;;
;; Copyright 2013 - By Michael Kohn
;; https://www.mikekohn.net/
;; mike@mikekohn.net
;;
;; Convert a cheapo R/C car into an IR car using the Syma S107 helicopter
;; remote. Microcontroller: dsPIC30F3012.

.dspic
.include "p30f3012.inc"

; Effective clock-speed 10MHz
; 500ms = 10000 interrupts

; 2.0 ms = 40 interrupts
; 0.3 ms = 6 interrupts
; 0.6 ms = 12 interrupts

; HH YAW PTCH THROTTLE YAW_CORRECT
; YAW = 0-126  63
; PITCH = 0-126 63
; THROTTLE = 0-126
; CORR = 0-126 63

RAM equ 0x0a00
HEADER equ 40
SHORT equ 6
LONG equ 12

YAW equ RAM
PITCH equ RAM+1
THROTTLE equ RAM+2
CORR equ RAM+3

DRIVE_CURR equ RAM+30
DRIVE_MAX equ RAM+32
WATCHDOG equ RAM+34

; dsPIC3012 registers
;  w0 = wreg
;  w1 =
;  w2 =
;  w3 =
;  w4 = temp in interrupt
;  w5 = interrupt count for watchdog (protection from losing IR)
;  w6 = pointer to next byte read in
;  w7 = current byte being read in
;  w8 = current bit count
;  w9 = temp in interrupt
;  w10 = interrupt count
;  w11 = motor on value
;  w12 =
;  w13 =
;  w14 =
;  w15 =

.org 0
  goto start

.org 0x14+(3*2)
  dc32 timer1_interrupt

.org 0x100
start:
  clr TRISB          ; PORTB is all output
  clr PORTB          ; Turn off MOSFETS on 2 H-Bridges
  clr TRISC          ; PORTC is all output
  mov #0x0000, w0
  mov wreg, PORTC    ; Debug LED's
  mov #1, w0         ; RD0 = input for IR
  mov wreg, TRISD

  ;; Point table to drive speed table
  mov #0, w1
  mov w1, TBLPAG

  ;call delay

.if 0
wait_for_pin:        ; Safety net for possible clock/programming issue
  btss.b PORTD, #0
  bra wait_for_pin
.endif

  ;; Set up TIMER1 to interrupt at specific interval
  clr T1CON
  ;mov #9999, w0     ; 0.001s
  mov #499, w0       ; 0.00005s
  ;mov #249, w0       ; 0.00005s
  mov wreg, PR1
  bset IEC0, #T1IE
  bset T1CON, #TON

  clr WATCHDOG       ; If this gets too high then turn off car's motors

  ;; main()
main:
  ;; If RD0 goes low, we have data, so goto read_command
  btss.b PORTD, #0
  bra read_command

  mov #10000, w0
  cp WATCHDOG
  bra leu, main

  clr WATCHDOG
  ;mov #0x0000, w0           ; turn off lights? or no
  ;mov w0, PORTC
  and #0xf0, w11             ; 500ms without a command, shut down motors
  clr PORTB

  bra main

read_command:
  ;; Wait for header to to turn off
  mov #HEADER+5, w0
  clr w10
wait_header_on:
  btsc.b PORTD, #0
  bra header_off
  cp w10, w0
  bra leu, wait_header_on
  bra main                  ; IR is too long
header_off:

  ;; If signal was too short, it wasn't a header so ignore it
  mov #HEADER-5, w0
  cp w10, w0
  bra leu, main

  ;; Wait for first bit
  mov #HEADER+5, w0
  clr w10
wait_header_off:
  btss.b PORTD, #0
  bra first_bit
  cp w10, w0
  bra leu, wait_header_off
  bra main                  ; IR is too long
first_bit:

  mov #RAM, w6
receive_next_byte:
  mov #0, w7                ; current byte of data
  mov #8, w8                ; current bit count
receive_next_bit:

  ;; check IR signal is on
  clr w10
wait_ir_on:
  cp w10, #SHORT+3
  bra gtu, main             ; signal is wayyyy too long, bail out
  btss.b PORTD, #0          ; if IR goes high, we're done here
  bra wait_ir_on

  ;; check IR signal is off
  clr w10
wait_ir_off:
  cp w10, #LONG+5
  bra gtu, main             ; signal is wayyyy too long, bail out
  btsc.b PORTD, #0          ; if IR goes low, we're done here
  bra wait_ir_off

  sl w7, #1, w7             ; w7=w7<<1
  cp w10, #SHORT+1
  bra leu, is_a_zero
  bset w7, #0               ; w7=w7|1
is_a_zero:

  dec w8, w8                ; w8--
  bra nz, receive_next_bit

  mov.b w7, [w6++]          ; w6[0] = w7; w6++
  mov #RAM+4, w0
  cp w6, w0
  bra nz, receive_next_byte

  ;; Now we have 4 bytes, time to do something
  clr WATCHDOG

  ;; Change the forward/backward value on rear wheels
  mov #60, w0
  cp.b PITCH
  bra geu, rear_more_than_60
  ;mov #0x4000, w0    ;; DEBUG
  ;mov w0, PORTC      ;; DEBUG
  ;and #0xfe, w11
  and #(0xff^0x03)|0x02, w11
  ior #0x02, w11
  clr w0
  mov.b PITCH, wreg              ; drive_curr = drive_speed[(60 - PITCH) * 4]
  mov.b #60, w8
  sub.b w8, w0, w0
  sl w0, #2, w0
  mov #drive_speed, w8
  ;mov #0, w8
  add w0, w8, w8
  ;mov #2000, w0
  ;mov [w8], w0
  tblrdl [w8], w0
  mov w0, DRIVE_MAX
  bra done_with_rear
rear_more_than_60:

  mov #67, w0
  cp.b PITCH
  bra leu, rear_less_than_67
  ;mov #0x2000, w0    ;; DEBUG
  ;mov w0, PORTC      ;; DEBUG
  ;and #0xfd, w11
  and #(0xff^0x03)|0x01, w11
  ior #0x01, w11
  clr w0
  mov.b PITCH, wreg              ; drive_curr = drive_speed[(PITCH - 67) * 4]
  sub.b #67, w0
  sl w0, #2, w0
  mov #drive_speed, w8
  ;mov #0, w8
  add w0, w8, w8
  ;mov #2000, w0
  ;mov [w8], w0
  tblrdl [w8], w0
  mov w0, DRIVE_MAX
  bra done_with_rear
rear_less_than_67:

  ;; Looks like the stick is in the dead zone, so stop rear motors
  and #0xfc, w11
  mov w11, PORTB
done_with_rear:

  ;; Change the steering value on front wheels
  mov #30, w0
  cp.b YAW
  bra geu, steering_more_than_30
  and #(0xff^0x0c)|0x04, w11
  ior #0x04, w11
  mov w11, PORTB
  ;mov #0x2000, w0       ;; DEBUG
  ;mov w0, PORTC         ;; DEBUG
  bra done_with_steering
steering_more_than_30:

  mov #100, w0
  cp.b YAW
  bra leu, steering_less_than_100
  and #(0xff^0x0c)|0x08, w11
  ior #0x08, w11
  mov w11, PORTB
  ;mov #0x4000, w0       ;; DEBUG
  ;mov w0, PORTC         ;; DEBUG
  bra done_with_steering
steering_less_than_100:

  and #(0xff^0x0c), w11
  mov w11, PORTB
  ;clr PORTC
done_with_steering:

  ;; Check if headlights should be turned on or off
  btst.b CORR, #1
  bra z, dont_turn_lights_on
  mov #0x6000, w0
  mov w0, PORTC
dont_turn_lights_on:
  btst.b CORR, #2
  bra z, dont_turn_lights_off
  clr PORTC
dont_turn_lights_off:

  bra main

  ;; TIMER1 interrupt routine
timer1_interrupt:
  inc WATCHDOG
  inc w10, w10

  ;; PWM motor
  inc DRIVE_CURR
  mov DRIVE_CURR, w4
  mov DRIVE_MAX, w9
  cp w4, w9                   ; if (DRIVE_CURR > DRIVE_MAX) { turn off motor }
  bra leu, keep_motor_on
  bclr LATB, #0
  bclr LATB, #1
keep_motor_on:
  mov #3800, w9               ; if (DRIVE_CURR == 3800) { reset PWM }
  cp w4, w9
  bra nz, pwm_not_at_top
  clr DRIVE_CURR
  mov w11, PORTB
pwm_not_at_top:

  bclr IFS0, #T1IF
  retfie

delay:
  mov w4, 1000
repeat_loop:
  dec w4, w4
  bra nz, repeat_loop
  return

drive_speed:
  dc32 76,   152,   228,  304,  380,  456,  532,  608,
  dc32 684,  760,   836,  912,  988, 1064, 1140, 1216,
  dc32 1292, 1368, 1444, 1520, 1596, 1672, 1748, 1824,
  dc32 1900, 1976, 2052, 2128, 2204, 2280, 2356, 2432,
  dc32 2508, 2584, 2660, 2736, 2812, 2888, 2964, 3040,
  dc32 3116, 3192, 3268, 3344, 3420, 3496, 3572, 3648,
  dc32 3724, 3800, 3800, 3800, 3800, 3800, 3800, 3800,
  dc32 3800, 3800, 3800, 3800, 3800, 3800, 3800, 3800,

  ;; Setup oscillator for 20MHz resonator + PLL and prescale for 10MHz
  ;; FOS=7 FPR=17
.org __FOSC
  ;dc32 0x0000f9e0
  dc32 0x0000fff1
.org __FWDT
  dc32 0x00007fff
.org __FBORPOR
  dc32 0x0000ff7f
.org __FGS
  dc32 0x0000ffff

