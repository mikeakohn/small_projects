;; WIZnet W5500.
;;
;; Copyright 2025 - By Michael Kohn
;; https://www.mikekohn.net/
;; mike@mikekohn.net
;;
;; Simple example using a WIZnet W5500 to send / receive UDP packets.
;;
;; SPI Frame: [ 16 bit address] [ control byte ] [ data 0 ... data n ]
;; Control byte:
;; [7:3] Block Select Bits:
;;     Upper 3 bits is socket number.
;;     Bottom 2 is type:
;;       00 Common (only valid for socket 0).
;;       01 Register.
;;       10 TX Buffer.
;;       11 RX Buffer.
;;   [2] R/W: 0 is read, 1 is write.
;; [1:0] OP Mode:
;;     0 is Data length controlled by SCSn.
;;     1 is Fixed data length mode 1 byte length before data.
;;     2 is Fixed data length mode 2 byte length before data.
;;     3 is Fixed data length mode 4 byte length before data.
;;
;; INT is active low (when low there is an interrupt).
;; RST is active low (hold low for 500us to reset).

.msp430
.include "msp430x2xx.inc"

;; Port 1
.define ETH_RST  0x04
.define ETH_INT  0x08
.define SPI_CS   0x10
.define SPI_CLK  0x20
.define SPI_SOMI 0x40
.define SPI_SIMO 0x80

.define CS_SELECT   bic.b #SPI_CS, &P1OUT
.define CS_DESELECT bis.b #SPI_CS, &P1OUT

RAM equ 0x0200
SD_BUFFER equ RAM

.macro SEND_BYTE(value)
  mov.b #value, r15
  call #spi_send_byte
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
  ;; Turn off watchdog.
  mov.w #WDTPW|WDTHOLD, &WDTCTL

  ;; Disable interrupts.
  dint

  ;; Set up stack pointer.
  mov.w #0x0400, SP

  ;; Set MCLK to 8 MHz with DCO.
  mov.b #DCO_5, &DCOCTL
  mov.b #RSEL_13, &BCSCTL1
  mov.b #0, &BCSCTL2

  ;; Set up output pins.
  ;; P1.2 = RST
  ;; P1.3 = INT
  ;; P1.4 = /CS
  ;; P1.5 = UCB0CLK
  ;; P1.6 = UCB0SOMI
  ;; P1.7 = UCB0SIMO
  mov.b #SPI_CS|ETH_RST, &P1DIR
  mov.b #SPI_CS, &P1OUT
  mov.b #SPI_CLK|SPI_SOMI|SPI_SIMO, &P1SEL
  mov.b #SPI_CLK|SPI_SOMI|SPI_SIMO, &P1SEL2

  ;; Set up SPI. W5500 SPI can be up to 80MHz.
  mov.b #UCSWRST,  &UCB0CTL1
  bis.b #UCSSEL_2, &UCB0CTL1
  mov.b #UCCKPH|UCMSB|UCMST|UCSYNC, &UCB0CTL0
  mov.b #1, &UCB0BR0
  mov.b #0, &UCB0BR1
  bic.b #UCSWRST, &UCB0CTL1

  ;; Enable interrupts
  eint

  ;; Clear 48 bytes of MSP430 RAM.
  mov.w #0x200, r15
memset:
  mov.w #0, 0(r15)
  add.w #2, r15
  cmp.w #0x240, r15
  jnz memset

  ;; Need at least 500us delay before pulling /RST high.
  call #delay

  bis.b #ETH_RST, &P1OUT
  call #delay

  call #send_reset

main_wait_common_rst_done:
  call #get_common_registers
  bit.b #0x80, &0x200
  jnz main_wait_common_rst_done

  ;call #send_set_phy_reset
  ;call #send_set_phy_enable

main_wait_phy_rst_done:
  call #get_common_registers
  bit.b #0x01, &0x22e
  jz main_wait_phy_rst_done

  call #send_init
  ;call #send_close

  call #send_set_socket_0_interrupt_mask

main_wait_socket_opened:
  call #send_config_udp
  call #send_set_source_port
  call #send_open
  call #get_socket_0_registers
  cmp.b #0x22, &0x203
  jnz main_wait_socket_opened

  call #send_tx_size
  call #send_set_destination
  call #send_tx_data
  call #send_tx_send

  call #get_socket_0_registers
  ;call #get_common_registers

main:
  jmp main

delay:
  mov.w #0, r15
delay_loop:
  dec.w r15
  jnz delay_loop
  ret

send_reset:
  ;; Set SW reset flag in control register 0.
  mov.w #w5500_sw_reset, r14
  mov.w #w5500_sw_reset_end - w5500_sw_reset, r13
  call #spi_send_block
  mov.w #0, r8
send_reset_loop:
  ;; Wait for reset flag to go low.
  inc.w r8
  mov.w #0x0000, r14
  mov.w #0, r13
  mov.w #1, r12
  call #spi_read_block
  bit.b #0x80, &0x200
  jnz send_reset_loop
  ret

send_init:
  ;; Setup Common.
  mov.w #w5500_common_init, r14
  mov.w #w5500_common_init_end - w5500_common_init, r13
  call #spi_send_block
  ret

send_set_phy_reset:
  mov.w #w5500_phy_reset, r14
  mov.w #w5500_phy_reset_end - w5500_phy_reset, r13
  call #spi_send_block
  ret

send_set_phy_enable:
  mov.w #w5500_phy_enable, r14
  mov.w #w5500_phy_enable_end - w5500_phy_enable, r13
  call #spi_send_block
  ret

send_set_socket_0_interrupt_mask:
  mov.w #w5500_socket_0_interrupt_mask, r14
  mov.w #w5500_socket_0_interrupt_mask_end - w5500_socket_0_interrupt_mask, r13
  call #spi_send_block
  ret

send_set_source_port:
  ;; Setup source_port.
  mov.w #w5500_socket_0_src, r14
  mov.w #w5500_socket_0_src_end - w5500_socket_0_src, r13
  call #spi_send_block
  ret

send_set_destination:
  ;; Setup destination.
  mov.w #w5500_socket_0_dst, r14
  mov.w #w5500_socket_0_dst_end - w5500_socket_0_dst, r13
  call #spi_send_block
  ret

send_config_udp:
  ;; Set as UDP.
  mov.w #w5500_socket_0_udp, r14
  mov.w #w5500_socket_0_udp_end - w5500_socket_0_udp, r13
  call #spi_send_block
  ret

send_open:
  mov.w #w5500_socket_0_open, r14
  mov.w #w5500_socket_0_open_end - w5500_socket_0_open, r13
  call #spi_send_block
  ret

send_connect:
  mov.w #w5500_socket_0_connect, r14
  mov.w #w5500_socket_0_connect_end - w5500_socket_0_connect, r13
  call #spi_send_block
  ret

send_close:
  mov.w #w5500_socket_0_close, r14
  mov.w #w5500_socket_0_close_end - w5500_socket_0_close, r13
  call #spi_send_block
  ret

send_tx_size:
  mov.w #w5500_socket_0_tx_size, r14
  mov.w #w5500_socket_0_tx_size_end - w5500_socket_0_tx_size, r13
  call #spi_send_block
  ret

send_tx_data:
  mov.w #w5500_socket_0_tx_data, r14
  mov.w #w5500_socket_0_tx_data_end - w5500_socket_0_tx_data, r13
  call #spi_send_block

  mov.w #w5500_socket_0_tx_len, r14
  mov.w #w5500_socket_0_tx_len_end - w5500_socket_0_tx_len, r13
  call #spi_send_block
  ret

send_tx_send:
  mov.w #w5500_socket_0_send, r14
  mov.w #w5500_socket_0_send_end - w5500_socket_0_send, r13
  call #spi_send_block
  ret

get_common_registers:
  mov.w #0x0000, r14
  mov.w #0, r13
  mov.w #0x40, r12
  call #spi_read_block
  ret

get_socket_0_registers:
  mov.w #0x0000, r14
  mov.w #0x01, r13
  mov.w #0x30, r12
  call #spi_read_block
  ret

;; spi_send_block(r14=msp430_address, r13=length)
spi_send_block:
  CS_SELECT
spi_send_block_loop:
  mov.b @r14+, r15
  call #spi_send_byte
  dec.w r13
  jnz spi_send_block_loop
  CS_DESELECT
  ret

;; spi_read_block(r14=w5500_address, r13=block_num, r12=count) : r15=address
spi_read_block:
  CS_SELECT
  mov.w r14, r15
  swpb r15
  call #spi_send_byte
  mov.b r14, r15
  call #spi_send_byte
  mov.b r13, r15
  rla.b r15
  rla.b r15
  rla.b r15
  call #spi_send_byte
  ;; Store return data in 0x200 RAM.
  mov.w #0x200, r14
spi_read_block_loop:
  mov.b #0xff, r15
  call #spi_send_byte
  mov.b r15, @r14
  add.w #1, r14
  dec.w r12
  jnz spi_read_block_loop
  CS_DESELECT
  ret

;; spi_send_frame()
spi_send_frame:

  ret

; spi_send_byte(r15)
spi_send_byte:
  mov.b r15, &UCB0TXBUF
spi_send_char_wait:
  bit.b #UCB0RXIFG, &IFG2
  jz spi_send_char_wait
  mov.b &UCB0RXBUF, r15
  ret

w5500_sw_reset:
  ;; Address 0x0000.
  ;; Control Byte: Common register 00000, W 1, OpMode 00
  .db 0x00, 0x00, 0x04
mr_reset:
  .db 0x80
w5500_sw_reset_end:

w5500_common_init:
  ;; Address 0x0001.
  ;; Control Byte: Common register 00000, W 1, OpMode 00
  .db 0x00, 0x01, 0x04
gateway_address:
  .db 192, 168, 0, 254
subnet_mask:
  .db 255, 255, 255, 0
source_hardware_address:
  .db 0x36, 0xff, 0xee, 0x11, 0x11, 0x36
source_ip_address:
  .db 192, 168, 0, 190
interrupt_low_level_timer:
  .db 0, 0
interrupt_register:
  ;; IR - Writing 1111 1000 clears all interrupts.
  .db 0xf8
interrupt_mask_register:
  ;; IMR
  .db 0xc0
socket_interrupt_register:
  ;; SIR
  .db 0xff
socket_interrupt_mask:
  ;; SIMR
  .db 0x01
w5500_common_init_end:

w5500_phy_reset:
  .db 0x00, 0x2e, 0x04
phy_config_reset:
  .db 0x38
w5500_phy_reset_end:

w5500_phy_enable:
  .db 0x00, 0x2e, 0x04
phy_config_enable:
  .db 0xb8
w5500_phy_enable_end:

w5500_socket_0_interrupt_mask:
  ;; Address 0x002c.
  ;; Control Byte: Socket 0 register 00010, W 1, OpMode 00
  .db 0x00, 0x2c, 0x0c
interrupt_mask_0:
  .db 0x1f
w5500_socket_0_interrupt_mask_end:

w5500_socket_0_udp:
  ;; Address 0x0000.
  ;; Control Byte: Socket 0 register 00001, W 1, OpMode 00
  .db 0x00, 0x00, 0x0c
socket_mode_udp:
  ;; UDP.
  .db 0x02
w5500_socket_0_udp_end:

w5500_socket_0_dst:
  ;; Address 0x000c.
  ;; Control Byte: Socket 0 register 00001, W 1, OpMode 00
  .db 0x00, 0x0c, 0x0c
destination_address:
  .db 192, 168, 0, 10
destination_port:
  .db 10000 >> 8, 10000 & 0xff
w5500_socket_0_dst_end:

w5500_socket_0_src:
  ;; Address 0x0004.
  ;; Control Byte: Socket 0 register 00001, W 1, OpMode 00
  .db 0x00, 0x04, 0x0c
source_port:
  .db 10001 >> 8, 10001 & 0xff
w5500_socket_0_src_end:

w5500_socket_0_open:
  ;; Address 0x0001.
  ;; Control Byte: Socket 0 register 00001, W 1, OpMode 00
  .db 0x00, 0x01, 0x0c
command_open:
  ;; OPEN.
  .db 0x01
w5500_socket_0_open_end:

w5500_socket_0_connect:
  ;; Address 0x0001.
  ;; Control Byte: Socket 0 register 00001, W 1, OpMode 00
  .db 0x00, 0x01, 0x0c
command_connect:
  ;; CONNECT (TCP only).
  .db 0x04
w5500_socket_0_connect_end:

w5500_socket_0_close:
  ;; Address 0x0001.
  ;; Control Byte: Socket 0 register 00001, W 1, OpMode 00
  .db 0x00, 0x01, 0x0c
command_close:
  ;; CLOSE.
  .db 0x10
w5500_socket_0_close_end:

w5500_socket_0_tx_size:
  ;; Address 0x001f.
  ;; Control Byte: Socket 0 register 00010, W 1, OpMode 00
  .db 0x00, 0x1f, 0x0c
tx_size:
  ;; 4 = 4kb
  .db 0x04
w5500_socket_0_tx_size_end:

w5500_socket_0_tx_data:
  ;; Address 0x0000.
  ;; Control Byte: Socket 0 register 00010, W 1, OpMode 00
  .db 0x00, 0x00, 0x14
tx_data:
  .db "HELLO\r\n"
w5500_socket_0_tx_data_end:

w5500_socket_0_tx_len:
  ;; Address 0x0024.
  ;; Control Byte: Socket 0 register 00010, W 1, OpMode 00
  .db 0x00, 0x24, 0x0c
tx_len:
  .db 0x00, 0x07
w5500_socket_0_tx_len_end:

w5500_socket_0_send:
  ;; Address 0x0001.
  ;; Control Byte: Socket 0 register 00001, W 1, OpMode 00
  .db 0x00, 0x01, 0x0c
send_command:
  ;; SEND.
  .db 0x20
w5500_socket_0_send_end:

;; Vectors.
.org 0xfffe
  dw start

