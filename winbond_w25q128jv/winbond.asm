;; Winbond W25Q128JV
;;
;; Copyright 2020 - By Michael Kohn
;; https://www.mikekohn.net/
;; mike@mikekohn.net
;;
;; Example reading and writing from a Winbond W25Q128JV SPI Flash chip.

.msp430
.include "msp430x2xx.inc"

;; Port 1
.define WINBOND_RESET 0x04
.define WINBOND_WP 0x08
.define SPI_CS 0x10
.define SPI_CLK 0x20
.define SPI_SOMI 0x40
.define SPI_SIMO 0x80

.define CS_SELECT bic.b #SPI_CS, &P1OUT
.define CS_DESELECT bis.b #SPI_CS, &P1OUT

RAM equ 0x0200
MANUFACTURER_ID equ RAM
DEVICE_ID equ RAM+1
TEMP equ RAM+2
STATUS_1 equ RAM+4
STATUS_2 equ RAM+5
STATUS_3 equ RAM+6
BUFFER equ RAM+16

.macro SEND_BYTE(value)
  mov.b #value, r15
  call #spi_send_char
.endm

;  r4 =
;  r5 =
;  r6 =
;  r7 =
;  r8 =
;  r9 =
; r10 =
; r11 =
; r12 = Function paramter.
; r13 = Function paramter.
; r14 = Function paramter.
; r15 = Function paramter.

.org 0xc000
start:
  ;; Turn off watchdog
  mov.w #WDTPW|WDTHOLD, &WDTCTL

  ;; Disable interrupts
  dint

  ;; Set up stack pointer
  mov.w #0x0400, SP

  ;; Set MCLK to 8 MHz with DCO 
  mov.b #DCO_5, &DCOCTL
  mov.b #RSEL_13, &BCSCTL1
  mov.b #0, &BCSCTL2

  ;; Set up output pins
  ;; P1.2 = /WINBOND_RESET
  ;; P1.3 = /WINBOND_WP
  ;; P1.4 = /CS
  ;; P1.5 = UCB0CLK
  ;; P1.6 = UCB0SOMI
  ;; P1.7 = UCB0SIMO
  mov.b #SPI_CS|WINBOND_WP|WINBOND_RESET, &P1DIR
  mov.b #SPI_CS, &P1OUT
  mov.b #SPI_CLK|SPI_SOMI|SPI_SIMO, &P1SEL
  mov.b #SPI_CLK|SPI_SOMI|SPI_SIMO, &P1SEL2

  ;; Set up SPI
  mov.b #UCSWRST, &UCB0CTL1
  bis.b #UCSSEL_2, &UCB0CTL1
  mov.b #UCCKPH|UCMSB|UCMST|UCSYNC, &UCB0CTL0
  mov.b #8, &UCB0BR0
  mov.b #0, &UCB0BR1
  bic.b #UCSWRST, &UCB0CTL1

  ;; Enable interrupts
  eint

  ;; Clear MSP430 RAM.
  mov.w #0x200, r15
memset:
  mov.w #0, 0(r15)
  add.w #2, r15
  cmp.w #0x230, r15
  jnz memset

  ;; I doubt this delay is needed.
  call #delay

  ;; Take Windbond out of reset.
  bis.b #WINBOND_RESET|WINBOND_WP, &P1OUT
  call #delay

  ;; The get_ids() function will grab the device and manufacturer id
  ;; from the chip to prove SPI is working. The STATUS_1 register is
  ;; then changed so it's possible to write to flash.
  call #get_ids
  call #set_status_write_enable
  call #read_status

  ;; Reads a single byte from address 0x000000 (r12 is MSB).
  mov.b #0, r12
  mov.b #0, r13
  mov.b #0, r14
  call #read_address

  ;; Erase 1 sector (4096 bytes) starting add address 0x000000.
  call #write_enable
  mov.b #0, r12
  mov.b #0, r13
  mov.b #0, r14
  call #sector_erase
  call #wait_on_write

  ;; Write a single byte to address 0x000000 (r12 is MSB).
  call #write_enable
  mov.b #0, r12
  mov.b #0, r13
  mov.b #0, r14
  mov.b #'M', r15
  call #write_address
  call #wait_on_write

  ;; Reads a single byte from address 0x000000 (r12 is MSB).
  mov.b #0, r12
  mov.b #0, r13
  mov.b #0, r14
  call #read_address

main:
  jmp main

;; get_ids()
get_ids:
  CS_SELECT
  SEND_BYTE(0x90)
  SEND_BYTE(0x00)
  SEND_BYTE(0x00)
  SEND_BYTE(0x00)

  SEND_BYTE(0x00)
  mov.b r15, &MANUFACTURER_ID
  SEND_BYTE(0x00)
  mov.b r15, &DEVICE_ID
  CS_DESELECT
  ret

;; read_status()
read_status:
  CS_SELECT
  SEND_BYTE(0x05)
  mov.b r15, &STATUS_1
  CS_DESELECT

  CS_SELECT
  SEND_BYTE(0x35)
  mov.b r15, &STATUS_2
  CS_DESELECT

  CS_SELECT
  SEND_BYTE(0x15)
  mov.b r15, &STATUS_3
  CS_DESELECT
  ret

;; set_status_write_enable()
set_status_write_enable:
  CS_SELECT
  SEND_BYTE(0x01)
  SEND_BYTE(0x00)
  CS_DESELECT
  ret

;; read_address(r12, r13, r14) : buffer
read_address:
  CS_SELECT
  SEND_BYTE(0x03)

  mov.b r12, r15
  call #spi_send_char
  mov.b r13, r15
  call #spi_send_char
  mov.b r14, r15
  call #spi_send_char

  SEND_BYTE(0x00)
  mov.b r15, &BUFFER
  CS_DESELECT
  ret

;; sector_erase(r12, r13, r14) // 4k sector
sector_erase:
  CS_SELECT
  SEND_BYTE(0x20)

  mov.b r12, r15
  call #spi_send_char
  mov.b r13, r15
  call #spi_send_char
  mov.b r14, r15
  call #spi_send_char

  CS_DESELECT
  ret

;; write_enable()
write_enable:
  CS_SELECT
  SEND_BYTE(0x06)
  CS_DESELECT
  ret

;; write_address(r12, r13, r14, r15)
write_address:
  mov.b r15, &TEMP

  CS_SELECT
  SEND_BYTE(0x02)

  mov.b r12, r15
  call #spi_send_char
  mov.b r13, r15
  call #spi_send_char
  mov.b r14, r15
  call #spi_send_char

  mov.b &TEMP, r15
  call #spi_send_char
  CS_DESELECT
  ret

;; wait_on_write()
wait_on_write:
  CS_SELECT
  SEND_BYTE(0x05)
  SEND_BYTE(0x00)
  CS_DESELECT

  bit.b #1, r15
  jnz wait_on_write
  ret

delay:
  mov.w #0, r15
delay_loop:
  dec.w r15
  jnz delay_loop
  ret

; spi_send_char(r15)
spi_send_char:
  mov.b r15, &UCB0TXBUF
spi_send_char_wait:
  bit.b #UCB0RXIFG, &IFG2
  jz spi_send_char_wait
  mov.b &UCB0RXBUF, r15
  ret

;; Vectors.
.org 0xfffe
  dw start                 ; Reset

