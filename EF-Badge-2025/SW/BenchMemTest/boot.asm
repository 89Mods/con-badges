mmio_base equ 0xFFFFFF80

TMR0 equ 0x00
TMR1 equ 0x04
TTOP0 equ 0x08
TTOP1 equ 0x0C
PRE0 equ 0x10
PRE1 equ 0x14
UDIV equ 0x18
SDIV equ 0x1C
UDAT equ 0x20
SDAT equ 0x24
STAT equ 0x28
DDRA equ 0x2C
PORTA equ 0x30
PINA equ 0x34
ICEN equ 0x34
ALT equ 0x38
CHC equ 0x40
PWM equ 0x50
ISTAT equ 0x3C

F_UDAT equ 0x100
F_STAT equ 0x102
F_RNG equ 0x104
F_TCAPT equ 0x108
F_TMR0_PRE equ 0x10A
F_TMR0_W equ 0x10C
F_TMR0_TOP_W equ 0x110
F_LED equ 0x120
F_LCD_CMD equ 0x1C0
F_LCD_PARAM equ 0x1C2
F_LCD_PUSH equ 0x1C8

stat_ubusy equ 0x01
stat_uhb equ 0x02
stat_led equ 0x04
stat_urupt equ 0x08
stat_tmr0 equ 0x10
stat_trupt0 equ 0x20

stat_base equ (stat_urupt|stat_trupt0)
stat_clr_tmr0 equ (stat_base|stat_tmr0)

INITIAL_SPI_DIV equ 300
;INITIAL_SPI_DIV equ 6
FAST_SPI_DIV equ 4

; r62 permanently holds MMIO address (internal)
; r61 is the stack pointer
; r60 is the default link register
; r59 is the workaround zero-reg
; r58 permanently holds MMIO address (FPGA)
; r1 - r15 are local/non-saved vars
; r16 - r23 are function params
; r24 - r58 are saved vars

fpga_base equ 16777216
fastram_base equ fpga_base
fpga_mmio_base equ (fpga_base+8192)
vram_base equ (fpga_base+8388608)
mem_start equ 0
mem_size equ 8388608
mem_last_addr equ (mem_start+mem_size-4)

	org 0
reset:
	lui r61, mem_last_addr>>16
	lliu r61, mem_last_addr&0xFFFF #
	be r61, r61, start
	---
external_int:
	nop #
	nop #
	bez zero, irupt_test
	---
t0_irupt:
	nop
	nop
	jalr zero, r63, 0
	---
sw_trap:
	nop
	nop
	jalr zero, r63, 0
	---
uart_irupt:
	nop
	nop
	jalr zero, r63, 0
	---
start:
	xor r59, r59, r59
	---
	lui r62, mmio_base>>16
	lli r3, 0xED
	lliu r62, mmio_base&0xFFFF
	---
	lui r58, fpga_mmio_base>>16
	lliu r58, fpga_mmio_base&0xFFFF
	---
	sw r3, DDRA(r62)
	xor r4, r4, r4
	sw zero, CHC(r62)
	---
	liu r4, 1 #
	sw r4, PORTA(r62)
	---
	
	lui r10, vram_base>>16
	lliu r10, vram_base&0xFFFF
	---
	lui r11, 0xFF30
	lliu r11, 0x3030
	---
	sw r11, 4(r10)
	---
	lui r11, 0xA1FF
	lliu r11, 0x0088
	---
	sw r11, 4(r10) #
	xor r11, r11, r11 #
	lw r11, 4(r10)
	---

	; Set up timer 0
	liu r1, 177 #
	sh r1, F_TMR0_PRE(r58)
	---
	lliu r1, 0x88
	lui r1, 0 #
	sw r1, F_TMR0_TOP_W(r58)
	---
	sw zero, F_TMR0_W(r58)
	; Enable timer and UART interrupts
	liu r1, stat_base #
	sh r1, F_STAT(r58)
	---
	lli r1, -1 #
	sw r1, TTOP0(r62) #
	sw r1, TTOP1(r62)
	---
	sw zero, PRE0(r62) #
	sw zero, PRE1(r62) #
	sw zero, TMR0(r62)
	---
	sw zero, TMR1(r62)
	lli r1, 2 #
	sw r1, ALT(r62) ; External interrupts enable
	---
	lhu r1, F_UDAT(r58) #
	liu r1, stat_clr_tmr0 #
	sh r1, F_STAT(r58)
	---
	liu r1, 0x18 #
	sw r1, ISTAT(r62) # ; Global interrupt enable
	---
	
loop:
	nop
	nop
	nop
	---
	nop
	nop
	be r10, r10, loop
	---

irupt_test:
	subi r61, r61, 8 #
	sw r1, 4(r61) #
	sw r60, 8(r61)
	---
fpga_int_handler_loop:
	lhu r1, F_STAT(r58) #
	andi r1, r1, stat_tmr0 #
	bez r1, fpga_no_timer_int
	---
	lipc r60, zero #
	jalr r60, r60, (handle_timer_int-$)>>4
	---
fpga_no_timer_int:
	lhu r1, F_STAT(r58) #
	andi r1, r1, stat_uhb #
	bez r1, fpga_no_uart_int
	---
	lipc r60, zero #
	jalr r60, r60, (handle_uart_int-$)>>4
	---
fpga_no_uart_int:
	lhu r1, F_STAT(r58) #
	andi r1, r1, stat_uhb+stat_tmr0 #
	bnez r1, fpga_int_handler_loop
	---
	lw r1, 4(r61) #
	lw r60, 8(r61) #
	addi r61, r61, 8
	---
	liu r1, 1 #
	sw r1, ISTAT(r62) #
	jalr zero, r63, 0
	---

handle_timer_int:
	lw r1, PORTA(r62) #
	xori r1, r1, 64 #
	sw r1, PORTA(r62)
	---
	
	liu r1, stat_clr_tmr0 #
	sh r1, F_STAT(r58)
	jalr zero, r60, 0
	---

handle_uart_int:
	lw r1, PORTA(r62) #
	xori r1, r1, 64 #
	sw r1, PORTA(r62)
	---

	lhu r1, F_UDAT(r58)
	jalr zero, r60, 0
	---
