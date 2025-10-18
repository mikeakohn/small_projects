;; Tape Data Recorder - Copyright 2010 by Michael Kohn
;; Email: mike@mikekohn.net
;;   Web: https://www.mikekohn.net/
;;
;; Read/Write data from a cassette tape with attiny2313
;; This program is a modified version of the my SIRC IR program.

;.include "tn2313def.inc"
.device ATtiny2313

;  cycles  sample rate   @8 MHz
;    400   10.0kHz * 2

; Based on Sony SIRC
;
; 2.4ms on, 0.6ms off: Start bit
; 1.2ms on, 0.6ms off: 1
; 0.6ms on, 0.6ms off: 0
;
; @ 8MHz @ 40 kHz
; 2.4ms = 19200 cycles = 192 interrupts
; 1.2ms = 9600 cycles = 96 interrupts
; 0.6ms = 4800 cycles = 48 interrupts
;
; Packet: Start bit, 8 bit data, 4 bit address
;
; Real SIRC is Start bit, 7 bit data, 5 bit address
; All bits are sent LSb to MSb (gross)

; r0  = 0
; r1  = 1
; r2  = clear to send (cts)
; r3  = banged 1/2 bits.  even number means bang on, odd bang off
; r13 = temp in interrupt
; r14 = temp in main funct
; r15 = 255
; r16 = temp main funct
; r17 = temp
; r18 = temp in funct
; r19 = send_char param
; r20 = read from rs232
; r21 = current carrier freq toggle bit
; r22 = holding LOW
; r23 = holding HI
; r24 = interrupt count
; r26 = output pointer LOW     (X)
; r27 = output pointer HI
; r28 = temp in main()         (Y)
; r29 = temp in main()
; r30 = interrupt pointer LOW  (Z)
; r31 = interrupt pointer HI
;

; States
; 0 = start bit started
; 1 = start bit off
; 2 = LSB Data
; 3 = LSB Data off
; ...
; ...
; 18 = MSB Data
; 19 = MSB Data off
; 20 = send a byte to computer and listen again

; note: CLKSEL 0100

.cseg

.org 0x000
  rjmp start
.org 0x008
  ijmp         ; might as well ijmp, IJMP!

;; FIXME erase this thing.. it's dumb
.org 0x00a
  reti

;; FIXME - erase this padding.. it's dumb
;;.org 0x020

start:
  ;; I'm busy.  Don't interrupt me!
  cli

  ;; Set up stack ptr
  ;ldi r17, RAMEND>>8
  ;out SPH, r17
  ldi r17, RAMEND&255
  out SPL, r17

  ;; r0 = 0, r1 = 1, r15 = 255
  eor r0, r0
  eor r1, r1
  inc r1
  eor r15, r15
  dec r15

  ; init variables
  clr r21
  mov r2, r1                   ; clear to send! (cts)

  ; Z points to interrupt
  ;ldi r31, (ingenting)>>8
  ;ldi r30, (ingenting)&0xff
  ;ldi r31, (bang_bit_interrupt)>>8
  ;ldi r30, (bang_bit_interrupt)&0xff
  ldi r31, (delay_interrupt)>>8
  ldi r30, (delay_interrupt)&0xff

  ;; Set up rs232 baud rate
  ldi r17, ((8000000/(16*9600))-1) >> 8
  out UBRRH, r17
  ldi r17, ((8000000/(16*9600))-1) & 0xff
  out UBRRL, r17             ; 51 @ 8MHz = 9600 baud

  ;; Set up rs232 options
  ldi r17, (1<<UCSZ0)|(1<<UCSZ1)      ; sets up data as 8N1
  out UCSRC, r17
  ldi r17, (1<<TXEN)|(1<<RXEN)        ; enables send/receive
  out UCSRB, r17
  out UCSRA, r0

  ;; Set up PORTB
  ldi r17, 253
  out DDRB, r17             ; PB0 is output / PB1 input
  out PORTB, r0             ; turn off all of port B for fun
  ldi r17, 3
  out DDRA, r17             ; Because Jeff Blevins says so
  ldi r17, 252
  out DDRD, r17             ; Because Jeff Blevins says so

  ;; Set up TIMER1
  ldi r17, (299>>8)
  out OCR1AH, r17
  ldi r17, (299&0xff)            ; compare to 400 clocks (10kHz)
  out OCR1AL, r17

  ldi r17, (1<<OCIE1A)
  out TIMSK, r17                 ; enable interrupt comare A 
  out TCCR1C, r0
  out TCCR1A, r0                 ; normal counting (0xffff is top, count up)
  ldi r17, (1<<CS10)|(1<<WGM12)  ; CTC OCR1A  Clear Timer on Compare
  out TCCR1B, r17                ; prescale = 1 from clock source

  ser r23
  ser r24

  ; Fine, I can be interrupted now
  sei

main:
  in r20, UCSRA         ; poll uart to see if there is a data waiting
  sbrs r20, RXC
  rjmp main             ; if no data, loop around

  in r19, UDR
  rcall send_char       ; echo for debug

not_clear_to_send:
  sbrs r2, 0
  rjmp not_clear_to_send
  rcall ir_send_data

sending_byte:
  sbrs r2, 0
  rjmp sending_byte

  ldi r19, '!'
  rcall send_char

  rjmp main             ; do while(1)

; void send_char(r19)  : r14 trashed
send_char:
  in r14, UCSRA       ; check to see if it's okay to send a char
  sbrs r14, UDRE
  rjmp send_char      ; if it's not okay, loop around :)
  out UDR, r19        ; output a char over rs232
  ret

; void ir_send_data(r19) : r14,r16 trashed
ir_send_data:
  ldi r27, SRAM_START>>8
  ldi r26, SRAM_START&0xff

  mov r2, r0

  ldi r16, 48
  mov r14, r16
  ldi r16, 192
  st X+, r16          ; start bit
  st X+, r14
  ldi r16, 96

  ldi r20, 8
set_bang_bits:
  sbrs r19, 0
  st X+, r14
  sbrc r19, 0
  st X+, r16

  st X+, r14

  lsr r19
 
  dec r20
  brne set_bang_bits 

  st X+, r14          ; STOP! IM FULL!
  st X+, r14

  st X+, r0

  mov r3, r0

  ldi r27, SRAM_START>>8
  ldi r26, SRAM_START&0xff
  ld r24, X+

  ;; .. ZOMG.. IT'S ATOMIC!!!!
  ldi r29, (bang_bit_interrupt)>>8
  ldi r28, (bang_bit_interrupt)&0xff
  movw r30, r28
  ret

;; Nothing
ingenting:
  reti

;; Bang a bit interrupt
bang_bit_interrupt:
  in r7, SREG

  sbrs r3, 0
  sbi PORTB, PB0
  sbrc r3, 0
  cbi PORTB, PB0

  dec r24
  brne half_bit_still_banging

  inc r3

  cbi PORTB, PB0
  ld r24, X+
  tst r24
  brne half_bit_still_banging

  ;ldi r31, (ingenting)>>8
  ;ldi r30, (ingenting)&0xff
  ldi r31, (listener_interrupt)>>8
  ldi r30, (listener_interrupt)&0xff

  mov r2, r1

half_bit_still_banging:
  out SREG, r7
  reti

;; Delay so circuits can settle (probably not needed)
delay_interrupt:
  dec r23
  brne delay_not_done
  ser r23
  dec r24
  brne delay_not_done

  ldi r31, (listener_interrupt)>>8
  ldi r30, (listener_interrupt)&0xff
delay_not_done:
  reti

;; Listen for incoming data on input pin
listener_interrupt:
  in r7, SREG

  sbrs r2, 0
  rjmp listener_finished
  sbis PINB, PB1
  rjmp listener_finished

  clr r21     ; state = start bit
  ;clr r22     ; holding LOW
  clr r23     ; holding HI
  ;mov r24, r1 ; interrupt counter = 1
  clr r24     ; interrupt counter
  ldi r31, (read_bit_interrupt)>>8
  ldi r30, (read_bit_interrupt)&0xff

  ;; RECORD DEBUG
  ;ldi r27, SRAM_START>>8
  ;ldi r26, SRAM_START&0xff

listener_finished:
  out SREG, r7
  reti

;; Listen for incoming data on IR receiver
read_bit_interrupt:
  in r7, SREG

  sbrc r21, 0          ; check if current state is even
  rjmp half_bit_is_off ; we are looking for a 600us off state

  sbis PINB, PB1
  rjmp falling_edge    ; if PB1 == 0 then state changed
  inc r24              ; inc interrupt counter
  out SREG, r7
  reti

falling_edge:
  ;; RECORD DEBUG
  ;st X+, r24

  inc r21             ; increment the state
  cpi r21, 19         ; check if this is last half of stop bit
  breq one_byte_done

  cpi r24, 186        ; compare to 2.4ms (192 interrupts really)
  brlo not_start_bit
  mov r21, r1
  ;clr r22             ; holding LOW
  clr r23             ; holding HI
  rjmp exit_falling_edge

not_start_bit:
  cpi r24, 90        ; compare to 1.2ms (96 interrupts really)
  ;cpi r24, 80        ; compare to 1.2ms (96 interrupts really)
  brlo not_one
  sec
  ror r23
  ;ror r22
  rjmp exit_falling_edge

not_one:
  cpi r24, 42        ; compare to 0.6ms (48 interrupts really)
  ;cpi r24, 15        ; compare to 0.6ms (48 interrupts really)
  brlo bad_input
  clc
  ror r23
  ;ror r22

exit_falling_edge:
  clr r24
  out SREG, r7
  reti

half_bit_is_off:
  sbic PINB, PB1
  rjmp rising_edge    ; if PB1 == 1 then state changed
  inc r24             ; inc interrupt counter
  out SREG, r7
  reti

rising_edge:
  ;; RECORD DEBUG
  ;st X+, r24
  inc r21             ; increment the state

  cpi r24, 54         ; check for around 0.6ms (48 interrupts really)
  brsh bad_input

  ;cpi r21, 24
  rjmp exit_falling_edge
  ;brne exit_falling_edge

  ;ldi r19, '$'
  ;rcall send_char      ; debug ZOMG
  ;ldi r19, '-'
  ;rcall send_char      ; debug ZOMG

  ; Shouldn't be needed for 8 bit
  ;ror r23               ; holding = holding >> 5
  ;ror r22
  ;ror r23
  ;ror r22
  ;ror r23
  ;ror r22
  ;ror r23
  ;ror r22
  ;ror r23               ; if 12 bit SIRC, remove these two lines
  ;ror r22

  ; FOR DEBUGGING
  ;mov r19, r23
  ;rcall send_hex
  ;mov r19, r22
  ;rcall send_hex

one_byte_done:
  mov r19, r23
  rcall send_char

  ;clr r24             ; reset interrupt counter
  ldi r31, (listener_interrupt)>>8
  ldi r30, (listener_interrupt)&0xff
  out SREG, r7
  reti

;; ZOMG!!!1!  RESET!
bad_input:
  ;; RECORD DEBUG
;  ldi r27, SRAM_START>>8
;  ldi r26, SRAM_START&0xff
;debug_loop:
;  ld r19, X+
;  rcall send_hex
;  dec r21
;  brne debug_loop

  ;; DEBUG --------- ;;
  ;mov r19, r24
  ;rcall send_hex
  ;mov r19, r21
  ;rcall send_hex
  ;ldi r19, '#'
  ;rcall send_char      ; debug ZOMG
  ;; DEBUG --------- ;;

  ldi r31, (listener_interrupt)>>8
  ldi r30, (listener_interrupt)&0xff
  out SREG, r7
  reti

; void send_nibble(r19)  : r14, r18 trashed
send_nibble:
  cpi r19, 10
  brlo hex_nibble_under_10
  subi r19, 10
  ldi r18, 'A'
  add r19, r18
  rcall send_char
  ret
hex_nibble_under_10:
  ldi r18, '0'
  add r19, r18
  rcall send_char
  ret

; void send_hex(r19)  : r13, r14, r18, r24 trashed
send_hex:
  mov r13, r19
  swap r19
  andi r19, 0x0f
  rcall send_nibble
  mov r19, r13
  andi r19, 0x0f
  rcall send_nibble
  ldi r19, ' '
  rcall send_char
  ret

signature:
.db "Tape Data Recorder - Copyright 2010 - Michael Kohn - Version 0.01",0

