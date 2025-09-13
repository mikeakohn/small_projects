;; Floppy MIDI - Copyright 2009 by Michael Kohn
;; Email: mike@mikekohn.net
;;   Web: https://www.mikekohn.net/
;;
;; Control a floppy drive stepper through MIDI commands.

.include "m168def.inc"

;  cycles  time   @8MHz:
;   65536: 8.192ms  122Hz

; Outputs
; PD2   High Density Select (2)
; PB0 - Motor On A          (10)
; PB1 - Drive Select B      (12)
; PB2 - Drive Select A      (14)
; PB3 - Motor On B          (16)
; PB4 - Direction           (18)
; PB5 - Step Pulse          (20)

; Inputs
; PC0 - Index Pulse         (8)
; PC1 - Track 0             (26)
; PC2 - Write Protect       (28)
; PC3 - Read Data           (30)
; PC4 - Disk Changed        (34)
; PC5 - NC

; r0  = 0
; r1  = 1
; r2 = Motor A low
; r3 = Motor A high
; r4 = Motor A dir
; r5 = Motor A track
; r6 = Motor A reset low
; r7 = Motor A reset high
; r8 = Motor B low
; r9 = Motor B high
; r10 = Motor B dir
; r11 = Motor B track
; r12 = Motor B reset low
; r13 = Motor B reset high
; r15 = 255
; r14 = temp
; r17 = temp
; r18 = 79
;

; Commands are 3 bytes, velocity is ignored:
; 0x9x [note 0 to 127] [velocity 0 to 127] (on)
; 0x8x [note 0 to 127] [velocity 0 to 127] (off)

; note: CLKSEL 0110

; Current frequency  (FIXME - Do we want this since we have enough free regs?)
.equ DRIVE_A = SRAM_START
.equ DRIVE_B = SRAM_START+2

.cseg

.org 0x000
  rjmp start
.org 0x016
  rjmp service_motors
.org 0x01a
  rjmp service_motors

;; FIXME - erase this padding.. it's dumb
.org 0x020

start:
  ;; I'm busy.  Don't interrupt me!
  cli

  ;; Set up stack ptr
  ldi r17, RAMEND>>8
  out SPH, r17
  ldi r17, RAMEND&255
  out SPL, r17

  ;; r0 = 0, r1 = 1
  eor r0, r0
  eor r1, r1
  inc r1
  eor r15, r15
  dec r15
  ldi r18, 79

  ;; Clear RAM
  ldi r17, 4
  ldi r31, SRAM_START>>8
  ldi r30, SRAM_START&255
memset_clear:
  st Z+, r0
  dec r17
  brne memset_clear

  ;; Motor data
  eor r2, r2   ; motor_a = 0
  eor r3, r3
  eor r4, r4   ; motor_a_dir = 1
  inc r4
  eor r5, r5   ; motor_a_track = 0
  eor r6, r6   ; motor_a_reset = 0
  eor r7, r7
  eor r8, r8   ; motor_b = 0
  eor r9, r9
  eor r10, r10 ; motor_b_dir = 1
  inc r10
  eor r11, r11 ; motor_b_track = 0
  eor r12, r12 ; motor_b_reset = 0
  eor r13, r13

  ;; Set up PORTB, PORTC, PORTD
  out DDRB, r15             ; entire port B is output
  out PORTB, r15            ; turn on all of port B for fun
  out DDRC, r0              ; entire port C is input
  out PORTC, r0             ; turn off all of port C for fun
  ldi r17, (1<<PD2)|(1<<PD3)
  out DDRD, r17             ; port D is output
  ldi r17, (1<<PD2)
  out PORTD, r17            ; port D turn on bit for high density

  ;; Set up rs232 baud rate
  sts UBRR0H, r0
  ldi r17, 51
  sts UBRR0L, r17           ; 51 @ 8MHz = 9600 baud

  ;; Set up rs232 options
  ldi r17, (1<<UCSZ00)|(1<<UCSZ01)    ; sets up data as 8N1
  sts UCSR0C, r17
  ldi r17, (1<<TXEN0)|(1<<RXEN0)      ; enables send/receive
  sts UCSR0B, r17
  sts UCSR0A, r0

  ;; Set up TIMER1
  lds r17, PRR
  andi r17, 255 ^ (1<<PRTIM1)
  sts PRR, r17                   ; turn of power management bit on TIM1

  ldi r17, (250>>8)
  sts OCR1AH, r17
  ldi r17, (250&0xff)            ; compare to 250 clocks
  sts OCR1AL, r17

  ldi r17, (1<<OCIE1A)
  sts TIMSK1, r17                ; enable interrupt comare A 
  sts TCCR1C, r0
  sts TCCR1A, r0                 ; normal counting (0xffff is top, count up)
  ldi r17, (1<<CS10)|(1<<WGM12)  ; CTC OCR1A  Clear Timer on Compare
  sts TCCR1B, r17                ; prescale = 1 from clock source
  
  ; Fine, I can be interrupted now
  sei

main:
  lds r20, UCSR0A         ; poll uart to see if there is a data waiting
  sbrs r20, RXC0
  rjmp main               ; if no data, loop around

  lds r20, UDR0

  ;; ECHO - just for checking things are okay
  ldi r24, '\r'
  call send_char
  ldi r24, '\n'
  call send_char
  mov r24, r20
  call send_char

  mov r17, r20
  andi r17, 0xf0
  cpi r17, 0x90
  brne not_note_on
wait_note_on:
  lds r20, UCSR0A         ; poll uart to see if there is a data waiting
  sbrs r20, RXC0
  rjmp wait_note_on       ; if no data, loop around
  lds r20, UDR0           ; read note from uart
  ldi r31, (midi_notes*2)>>8
  ldi r30, (midi_notes*2)&255
  lsl r20
  add r30, r20
  brcc no_carry_note_on
  inc r31
no_carry_note_on:
  lpm r6, Z+
  lpm r7, Z+
  eor r3, r3
  eor r2, r2
wait_velocity_on:
  lds r20, UCSR0A         ; poll uart to see if there is a data waiting
  sbrs r20, RXC0
  rjmp wait_velocity_on   ; if no data, loop around
  lds r20, UDR0           ; read velocity from uart
  rjmp main
not_note_on:

  cpi r17, 0x80
  brne not_note_off
  eor r6, r6
  eor r7, r7
wait_note_off:
  lds r20, UCSR0A         ; poll uart to see if there is a data waiting
  sbrs r20, RXC0
  rjmp wait_note_off      ; if no data, loop around
  lds r20, UDR0           ; read note from uart
wait_velocity_off:
  lds r20, UCSR0A         ; poll uart to see if there is a data waiting
  sbrs r20, RXC0
  rjmp wait_velocity_off  ; if no data, loop around
  lds r20, UDR0           ; read velocity from uart
  rjmp main
not_note_off:

  cpi r20, 'a'
  brne nota
  sbi PORTB, PB0
  jmp main
nota:

  cpi r20, 'z'
  brne notz
  cbi PORTB, PB0
  jmp main
notz:

  cpi r20, 's'
  brne nots
  sbi PORTB, PB1
  jmp main
nots:

  cpi r20, 'x'
  brne notx
  cbi PORTB, PB1
  jmp main
notx:

  cpi r20, 'd'
  brne notd
  sbi PORTB, PB2
  jmp main
notd:

  cpi r20, 'c'
  brne notc
  cbi PORTB, PB2
  jmp main
notc:

  cpi r20, 'f'
  brne notf
  sbi PORTB, PB3
  jmp main
notf:

  cpi r20, 'v'
  brne notv
  cbi PORTB, PB3
  jmp main
notv:

  cpi r20, 'g'
  brne notg
  sbi PORTB, PB4
  jmp main
notg:

  cpi r20, 'b'
  brne notb
  cbi PORTB, PB4
  jmp main
notb:

  cpi r20, 'h'
  brne noth
  sbi PORTB, PB5
  jmp main
noth:

  cpi r20, 'n'
  brne notn
  cbi PORTB, PB5
  jmp main
notn:

;  cpi r20, '1'
;  brne not1
;  sbi PORTB, PD2
;  jmp main
;not1:
;
;  cpi r20, '0'
;  brne not0
;  cbi PORTB, PD2
;  jmp main
;not0:

  cpi r20, '1'
  brlo not_num
  cpi r20, ('9'+1)
  brge not_num

  ldi r31, (midi_notes*2)>>8
  ldi r30, (midi_notes*2)&255

  ;subi r20, '0'
  ;addi r20, 48
  lsl r20

  add r30, r20
  brcc no_carry
  inc r31
no_carry:         ;; crap on me
;  add r30, r20
;  brcc no_carry2
;  inc r31
;no_carry2:

  lpm r6, Z+
  lpm r7, Z+

  ;ldi r17, 48
  ;mov r6, r17
  ;eor r7, r7

;  ldi r17, 250
;  mov r6, r17
;  eor r7, r7
  eor r2, r2
  eor r3, r3

  jmp main
not_num:


  cpi r20, 'i'
  brne noti
  ;sbis PINC, PC0     ;; HERE
  sbrs r4, 7
  ldi r24, '0'
  ;sbic PINC, PC0
  sbrc r4, 7
  ldi r24, '1'
  call send_char
  jmp main
noti:

  cpi r20, 't'
  brne nott
  sbis PINC, PC1     ;; HERE
  ldi r24, '0'
  sbic PINC, PC1
  ldi r24, '1'
  call send_char
  jmp main
nott:

  cpi r20, '0'       ; turn off note
  brne noto
  eor r6, r6
  eor r7, r7
  jmp main
noto:

;  cpi r20, 'p'
;  brne notp
;  ldi r17, 250
;  mov r6, r17
;  eor r7, r7
;  eor r2, r2
;  eor r3, r3
;  jmp main
;notp:

  rjmp main


;; The Great Interrupt Routine!
service_motors:
  in r21, SREG
  ;; if motor_a_reset == 0
  ;;   goto skipa
  ;; if motor_a == motor_a_reset
  ;;   motor_a = 0
  ;;   turn on stepper

  ;;   /* never mind.. making the head move back and forth is boring
  ;;      instead lets just slam the head against the stopper :)
  ;;   if track == 79
  ;;     direction = -1
  ;;   elsif track == 0
  ;;     direction = 1
  ;;    */
  ;; if motor_a == 1
  ;;   turn off stepper

  tst r6           ; if motor_a_reset != 0 then don't skip
  brne service_a
  tst r7
  brne service_a
  rjmp skipa

service_a:
  cp r2, r6         ; if motor_a != motor_a_reset then don't reset
  brne not_ready_a
  cp r3, r7
  brne not_ready_a
  ldi r19, 30       ; ZOMG
  eor r2, r2        ; motor_a = 0
  eor r3, r3

  sbis PORTB, PB4
  rjmp set_dir
clear_dir:
  cbi PORTB, PB4
  rjmp done_setting_direction

set_dir:
  sbi PORTB, PB4
done_setting_direction:

  cbi PORTB, PB2    ; select A
  cbi PORTB, PB5    ; step motor
  ;sbi PORTB, PB2    ; unselect A



;; /* doesn't work well
;;  add r5, r4        ; motor_a_track = motor_a_track + motor_a_dir
;;  tst r5            ; if motor_a_track == 0 then motor_a_dir = 1
;;  brne motor_a_track_not_0
;;  eor r4, r4
;;  inc r4
;;  cbi PORTB, PB4    ; direction = +
;;  rjmp skipa
;;motor_a_track_not_0:
;;  cp r5, r18        ; elsif motor_a_track == 79 then motor_a_dir = 255
;;  brne motor_a_track_not_79
;;  eor r4, r4
;;  dec r4
;;  sbi PORTB, PB4    ; direction = -
;;motor_a_track_not_79:
;; */

  rjmp skipa

not_ready_a:
  inc r2            ; motor_a = motor_a + 1
  ;;brvc no_a_overflow  ; FIXME - use skip?
  brne no_a_overflow  ; FIXME - use skip?
  inc r3
no_a_overflow:
  ;tst r3            ; if motor_a == 1 then turn off step
  ;brne skipa
  ;mov r22, r2
  ;cpi r22, 1
  ;brne skipa
  tst r19       ; if it's already 0, don't decrement anymore
  breq skipa    ; this should be pointless really
  dec r19       ; ZOMG
  brne skipa    ; ZOMG
  cbi PORTB, PB2   ; select A
  sbi PORTB, PB5   ; step motor stop
  ;sbi PORTB, PB2   ; unselect A

skipa:
  out SREG, r21
  reti

; void send_char(r24)  : r14 trashed
send_char:
  lds r14, UCSR0A     ; check to see if it's okay to send a char
  sbrs r14, UDRE0
  rjmp send_char      ; if it's not okay, loop around :)
  sts UDR0, r24       ; output a char over rs232
  ret


signature:
.db "Floppy MIDI - Copyright 2009 - Michael Kohn - Version 0.05"

.include "midi_notes.inc"

