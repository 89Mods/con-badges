mmio_base equ 0xFFFFFF80

NES_RIGHT  equ 1
NES_LEFT   equ 2
NES_DOWN   equ 4
NES_UP     equ 8
NES_START  equ 16
NES_SELECT equ 32
NES_B      equ 64
NES_A      equ 128

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

NUM_LEDS equ 11

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

stat_base equ (stat_trupt0) ; TODO: idk why UART interrupt is broken
stat_base_no_irupts equ 0
stat_clr_tmr0 equ (stat_base|stat_tmr0)

tmr_pre_setting equ 100
tmr_top_setting equ 999999

INITIAL_SPI_DIV equ 300
;INITIAL_SPI_DIV equ 6
FAST_SPI_DIV equ 0

; r62 permanently holds MMIO base address (internal)
; r61 is the stack pointer
; r60 is the default link register
; r59 is the workaround zero-reg
; r58 permanently holds MMIO base address (FPGA)
; r57 holds system uptime (seconds)
; r1 - r15 are local/non-saved vars
; r16 - r23 are function params
; r24 - r56 are saved vars

fpga_base equ 16777216
fastram_base equ fpga_base
fpga_mmio_base equ (fpga_base+8192)
vram_base equ (fpga_base+8388608)
mem_start equ 0
mem_size equ 8388608
mem_last_addr equ (mem_start+mem_size-4)

putc macro xval
	liu r16, xval #
	sh r16, F_UDAT(r58)
	---
	lhu r16, F_STAT(r58) #
	andi r16, r16, stat_ubusy #
	bnez r16, $
	---
	endm

lcd_push macro
	liu r1, 0x2C # ; lcd_cmd_write_memory_start
	sh r1, F_LCD_CMD(r58)
	---
	sh r1, F_LCD_PUSH(r58)
	---
	liu r1, 0x20 #
	sh r1, F_LCD_CMD(r58)
	---
	endm

	org 0
reset:
	lui r61, mem_last_addr>>16
	lliu r61, mem_last_addr&0xFFFF #
	be r61, r61, start
	---
fpga_int_entry:
	bez zero, fpga_int_handler
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
unused_irupt:
	nop
	nop
	jalr zero, r63, 0
	---
start:
	xor r59, r59, r59
	xor r57, r57, r57
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
	liu r4, 129 #
	;liu r4, 128
	sw r4, PORTA(r62)
	---
	nop
	lli r4, INITIAL_SPI_DIV # ; Low SDIV at first for SD card init
	sw r4, SDIV(r62)
	---
	lliu r16, startup_str&0xFFFF
	lui r16, startup_str>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr_unsafe-$)>>4
	---
	lipc r60, zero #
	lli r2, 0
	jalr r60, r60, (init_leds-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (lcd_init-$)>>4
	---
	
	; Put boot logo
	nop
	lli r6, 1 #
	sw r6, ICEN(r62)
	---
	liu r1, 47999
	;liu r1, 1
	lliu r2, bitmap&0xFFFF
	lui r2, bitmap>>16
	---
	lliu r6, vram_base&0xFFFF
	lui r6, vram_base>>16
	---
logo_copy_loop_outer:
	lbu r3, 0(r2)
	liu r4, 7
	---
	addi r2, r2, 1
	slli r3, r3, 24
	---
logo_copy_loop_inner:
	lliu r5, 0x7921
	lui r5, 0xFFFC
	pn p1, r3
	---
	;---
	lli r5, -1 [p1]
	---
	add r3, r3, r3
	sw r5, 0(r6)
	---
	addi r6, r6, 4
	subi r4, r4, 1
	bnez r4, logo_copy_loop_inner
	---
	subi r1, r1, 1
	bnez r1, logo_copy_loop_outer
	---
	sw zero, ICEN(r62)
	---
	lcd_push
	lipc r60, zero #
	jalr r60, r60, (memtest-$)>>4
	---
	nop
	---
	lipc r60, zero #
	jalr r60, r60, (sdcard_init-$)>>4
	---
	nop
	---
	lipc r60, zero #
	jalr r60, r60, (parse_mbr-$)>>4
	---
	nop
	---
	bez r2, partition_not_found
	---
	lliu r16, text_partition_found&0xFFFF
	lui r16, text_partition_found>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	nop
	---
	lliu r10, ext4_partition_start&0xFFFF
	lui r10, ext4_partition_start>>16 #
	lw r16, 0(r10)
	---
	lipc r60, zero #
	jalr r60, r60, (puthex32_cachef-$)>>4
	---
	nop
	---
	lliu r16, text_partition_found2&0xFFFF
	lui r16, text_partition_found2>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	nop
	---
	lliu r10, ext4_partition_size&0xFFFF
	lui r10, ext4_partition_size>>16 #
	lw r16, 0(r10)
	---
	lipc r60, zero #
	jalr r60, r60, (puthex32_cachef-$)>>4
	---
	nop
	---
	lipc r60, zero #
	jalr r60, r60, (newl_cachef-$)>>4
	---
	nop
	---
	lipc r60, zero #
	jalr r60, r60, (ext4_mount-$)>>4
	---
	nop
	---
	subi r16, r16, EXT4_OKAY #
	bnez r16, error
	---
	lipc r60, zero #
	jalr r60, r60, (newl_cachef-$)>>4
	---
	nop
	---
	
	;bez zero, find_files_loop_done ; TODO: remove!
	;---
	
	lliu r16, str_indexing_files&0xFFFF
	lui r16, str_indexing_files>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr_unsafe-$)>>4
	---
	nop
	---
	lliu r32, important_files&0xFFFF
	lui r32, important_files>>16
	---
	lliu r33, inode_cache&0xFFFF
	lui r33, inode_cache>>16
	---
find_files_loop:
	lbu r1, 0(r32) #
	bez r1, find_files_loop_done
	---
	cpy r16, r32
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	nop
	---
	liu r16, ' '
	lipc r60, zero #
	jalr r60, r60, (putchar_cachef-$)>>4
	---
	nop
	---
	liu r16, '@'
	lipc r60, zero #
	jalr r60, r60, (putchar_cachef-$)>>4
	---
	nop
	---
	liu r16, ' '
	lipc r60, zero #
	jalr r60, r60, (putchar_cachef-$)>>4
	---
	nop
	---
	cpy r16, r32
	lipc r60, zero #
	jalr r60, r60, (ext4_find_file-$)>>4
	---
	nop
	---
	bnez r20, find_file_loop_error
	subi r19, r19, 1
	---
	bnez r19, find_file_loop_error
	bez r18, find_file_loop_error
	sw r18, 0(r33)
	---
	cpy r16, r18
	lipc r60, zero #
	jalr r60, r60, (puthex32_cachef-$)>>4
	---
	nop
	---
	addi r33, r33, 4
	lipc r60, zero #
	jalr r60, r60, (newl-$)>>4
	---
	nop
	---
find_file_skip_loop:
	lbu r1, 0(r32) #
	addi r32, r32, 1
	bnez r1, find_file_skip_loop
	---
	bez zero, find_files_loop
	---
find_file_loop_error:
	lliu r16, str_file_not_found&0xFFFF
	lui r16, str_file_not_found>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr_unsafe-$)>>4
	---
	bez zero, error
	---
find_files_loop_done:
	
	lliu r16, init_complete_str&0xFFFF
	lui r16, init_complete_str>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	nop
	---
	
	; Set up timer 0
	liu r1, tmr_pre_setting #
	sh r1, F_TMR0_PRE(r58)
	---
	lliu r1, tmr_top_setting&0xFFFF
	lui r1, tmr_top_setting>>16 #
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
	sw r1, ISTAT(r62) ; Global interrupt enable
	---
	
	bez r0, badge_loop
	---
	
partition_not_found:
	lliu r16, text_partition_not_found&0xFFFF
	lui r16, text_partition_not_found>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	nop
	---
	bez zero, error
	---

; Creepy memory tester code - needs to be able to run even when there is
; no working, writable memory, so all register usage rules go out the window for a bit

	; Prints a string over UART
	; Args: byte*
	; Uses: none
putstr_unsafe:
	nop
	---
putstr_unsafe_loop:
	lb r15, 0(r16) #
	bez r15, putstr_unsafe_done #
	sh r15, F_UDAT(r58)
	---
	lhu r15, F_STAT(r58) #
	andi r15, r15, stat_ubusy #
	bnez r15, $
	---
	addi r16, r16, 1
	nop
	bez r0, putstr_unsafe_loop
	---
putstr_unsafe_done:
	nop
	---
	jalr zero, r60, 0
	---

; r10, r11 - Xorshift state
; r1 thru r7 - temps in subroutines

puthex32_unsafe:
	liu r2, 7
	---
puthex32_unsafe_loop:
	srli r1, r16, 28 #
	lb r1, hex_chars(r1) #
	sh r1, F_UDAT(r58)
	---
	lhu r1, F_STAT(r58) #
	andi r1, r1, 1 #
	bnez r1, $
	---
	slli r16, r16, 4
	subi r2, r2, 1
	bnez r2, puthex32_unsafe_loop
	---
	jalr zero, r60, 0
	---

putchar_unsafe:
	sh r16, F_UDAT(r58)
	---
	lhu r16, F_STAT(r58) #
	andi r16, r16, 1 #
	bnez r16, $
	---
	jalr zero, r60, 0
	---

mem_disp_base equ vram_base

mem_debug_disp:
	nop
	nop
	nop
	---
mem_disp_loop:
	lliu r10, 0x2928
	lui r10, 0xACD9
	lliu r11, 0x3939
	---
	lui r11,0x70C8
	lliu r20, mem_disp_base&0xFFFF
	lui r20, mem_disp_base>>16
	---
	lui r21, 0
	lliu r21, 9
	xor r22, r22, r22
	---
mem_disp_write_loop:
	lipc r60, zero #
	jalr r60, r60, (xorshift_step-$)>>4
	---
	liu r25, 0xFF #
	slli r25, r25, 24 #
	or r10, r10, r25
	---
	sw r10, 0(r20)
	addi r20, r20, 4
	subi r21, r21, 1
	---
	bnez r21, mem_disp_write_loop
	---
	; Reset RNG seed and start address
	lliu r10, 0x2928
	lui r10, 0xACD9
	lliu r11, 0x3939
	---
	lui r11,0x70C8
	lliu r20, mem_disp_base&0xFFFF
	lui r20, mem_disp_base>>16
	---
	lui r21, 0
	lliu r21, 9
	addi r22, r22, 2
	---
mem_disp_verify_loop:
	lipc r60, zero #
	jalr r60, r60, (xorshift_step-$)>>4
	---
	liu r25, 0xFF #
	slli r25, r25, 24 #
	or r10, r10, r25
	---
	lw r22, 0(r20)
	addi r20, r20, 4
	subi r21, r21, 1
	---
	cpy r16, r10
	lipc r60, zero #
	jalr r60, r60, (puthex32_unsafe-$)>>4
	---
	liu r16, 9
	lipc r60, zero #
	jalr r60, r60, (putchar_unsafe-$)>>4
	---
	liu r16, '-'
	lipc r60, zero #
	jalr r60, r60, (putchar_unsafe-$)>>4
	---
	liu r16, 9
	lipc r60, zero #
	jalr r60, r60, (putchar_unsafe-$)>>4
	---
	cpy r16, r22
	lipc r60, zero #
	jalr r60, r60, (puthex32_unsafe-$)>>4
	---
	liu r16, 13
	lipc r60, zero #
	jalr r60, r60, (putchar_unsafe-$)>>4
	---
	liu r16, 10
	lipc r60, zero #
	jalr r60, r60, (putchar_unsafe-$)>>4
	---
	bnez r21, mem_disp_verify_loop
	---
	liu r16, 10
	lipc r60, zero #
	jalr r60, r60, (putchar_unsafe-$)>>4
	---
	lliu r56, 0xFFFF ; Set delay length
	lui r56, 0x002F
	---
	; Delay loop
mem_disp_wait_loop:
	subi r56, r56, 1
	bne r56, r0, mem_disp_wait_loop
	bez r0, mem_disp_loop
	---

mem_test_base equ mem_start+mem_size-0x00080000
mem_test_len equ 0x0000A000

	; Test memory
memtest:
	cpy r32, r60
	---
	lliu r10, 0x2928
	lui r10, 0xACD9
	lliu r11, 0x3939
	---
	lui r11,0x70C8
	lliu r20, mem_test_base&0xFFFF
	lui r20, mem_test_base>>16
	---
	lui r21, mem_test_len>>16
	lliu r21, mem_test_len&0xFFFF
	xor r22, r22, r22
	---
memtest_write_loop:
	lipc r60, zero #
	jalr r60, r60, (xorshift_step-$)>>4
	---
	nop
	---
	sw r10, 0(r20)
	addi r20, r20, 4
	subi r21, r21, 1
	---
	bnez r21, memtest_write_loop
	---
	; Reset RNG seed and start address
	lliu r10, 0x2928
	lui r10, 0xACD9
	lliu r11, 0x3939
	---
	lui r11,0x70C8
	lliu r20, mem_test_base&0xFFFF
	lui r20, mem_test_base>>16
	---
	lui r21, mem_test_len>>16
	lliu r21, mem_test_len&0xFFFF
	xor r22, r22, r22
	---
memtest_verify_loop:
	lipc r60, zero #
	jalr r60, r60, (xorshift_step-$)>>4
	---
	nop
	---
	lw r22, 0(r20)
	addi r20, r20, 4
	subi r21, r21, 1
	---
	bne r10, r22, memtest_fail
	bnez r21, memtest_verify_loop
	---
	nop
	---
	lliu r16, memtest_pass&0xFFFF
	lui r16, memtest_pass>>16
	---
abc:
	lb r15, 0(r16) #
	bez r15, abcd #
	sh r15, F_UDAT(r58)
	---
	lhu r15, F_STAT(r58) #
	andi r15, r15, stat_ubusy #
	bnez r15, $
	---
	addi r16, r16, 1
	nop
	bez r0, abc
	---
abcd:
	
	jalr zero, r32, 0
	---
memtest_fail:
	lliu r16, memtest_fail_str&0xFFFF
	lui r16, memtest_fail_str>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr_unsafe-$)>>4
	---
	cpy r16, r10
	lipc r60, zero #
	jalr r60, r60, (puthex32_unsafe-$)>>4
	---
	liu r16, ' '
	lipc r60, zero #
	jalr r60, r60, (putchar_unsafe-$)>>4
	---
	subi r16, r22, 4
	lipc r60, zero #
	jalr r60, r60, (puthex32_unsafe-$)>>4
	---
	liu r16, ' '
	lipc r60, zero #
	jalr r60, r60, (putchar_unsafe-$)>>4
	---
	subi r16, r20, 4
	lipc r60, zero #
	jalr r60, r60, (puthex32_unsafe-$)>>4
	---
	liu r16, 13
	lipc r60, zero #
	jalr r60, r60, (putchar_unsafe-$)>>4
	---
	liu r16, 10
	lipc r60, zero #
	jalr r60, r60, (putchar_unsafe-$)>>4
	---
error:
	lipc r60, zero #
	lli r2, 1
	jalr r60, r60, (init_leds-$)>>4
	---
error_loop:
	nop
	---
	bez r0, error_loop
	---

xorshift_step:
	slli r1, r11, 13
	srli r2, r10, 19 #
	or r1, r2, r1
	---
	xor r11, r11, r1
	slli r1, r10, 13 #
	xor r10, r1, r10
	---
	srli r1, r10, 7
	slli r2, r11, 25 #
	or r2, r2, r1
	---
	xor r10, r10, r2
	srli r2, r11, 7 #
	xor r11, r2, r11
	---
	slli r1, r11, 17
	srli r2, r10, 15 #
	or r1, r2, r1
	---
	xor r11, r11, r1
	slli r1, r10, 17 #
	xor r10, r1, r10
	---
	jalr zero, r60, 0
	---

init_leds:
	liu r1, 0 #
	sw r1, F_LED(r58)
	---
	liu r3, 0x00FF
	pe p1, r2, r0 #
	lliu r3, 0xFF00 [p1]
	---
	nop
	nop
	lli r2, NUM_LEDS-1
	---
init_leds_loop:
	cpy.l r1, r3
	lui r1, 0xE200 #
	sw r1, F_LED(r58)
	---
	subi r2, r2, 1
	bnez r2, init_leds_loop
	---
	lli r1, -1 #
	sw r1, F_LED(r58)
	jalr zero, r60, 0
	---

fpga_int_handler:
	sw zero, ICEN(r62)
	---
	subi r61, r61, 8 #
	sw r1, 4(r61) #
	sw r60, 8(r61)
	---
	lw r1, PORTA(r62) #
	xori r1, r1, 64 #
	sw r1, PORTA(r62)
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
	liu r1, 1 #
	sw r1, ISTAT(r62) #
	lw r1, 4(r61)
	---
	lw r60, 8(r61) #
	addi r61, r61, 8
	jalr zero, r63, 0
	---

handle_timer_int:
	addi r57, r57, 1
	---
	liu r1, stat_clr_tmr0 #
	sh r1, F_STAT(r58)
	jalr zero, r60, 0
	---

handle_uart_int:

	lhu r1, F_UDAT(r58)
	jalr zero, r60, 0
	---

	include "serial.asm"
	include "sdcard.asm"
	include "mbr.asm"
	include "ext4.asm"
	include "graphics.asm"
	include "interrupts.asm"
	include "badge.asm"
	include "utils.asm"
startup_str:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] Tholin’s VLIW Badge",13,10,0
memtest_fail_str:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] MEMORY TEST FAILED",13,10,0
memtest_pass:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] Memory test passed!",13,10,0
hex_chars:
	db "0123456789ABCDEF"
text_partition_not_found:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] ext4 partition not found, can’t continue",13,10,0
text_partition_found:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] ext4 partition found at ",0
text_partition_found2:
	db " with size ",0
init_complete_str:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] Initialization complete! Entering main program loop.",13,10,13,10,0
str_indexing_files:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] Indexing files...",10,13,0
str_file_not_found:
	db 13,10,'[',0x1B,"[1;31mFATAL",0x1B,"[0m] File not found!",13,10,0
str_failed_to_open_image:
	db '[',0x1B,"[1;33mWARNING",0x1B,"[0m] Failed to open an image file!",13,10,0
important_files:
	; Concatenated list of null-terminated strings of commonly used files
	; End indicated by a zero-length string (double null-terminator)
	db "/images/awawi_raw",0
	db "/images/tholin2_raw",0
	db "/images/vrc_logo_raw",0
	db "/images/cvr_logo_raw",0
	db "/images/resonite_logo.qoi",0
	db "/images/tholin3_raw",0
	db "/images/tholin4_raw",0
	db "/images/tholin8_raw",0
	db "/images/tholin5_raw",0
	db "/images/tholin6_raw",0
	db "/images/tholin7_raw",0
	db "/images/tholin9_raw",0
	db "/images/plernert_raw",0
	db "/images/vrcworld1_raw",0
	db "/images/vrcworld2_raw",0
	db "/images/tech1_raw",0
	db "/images/tech2_raw",0
	db "/images/chip.qoi",0
	db "/images/qrcode.qoi",0
	db "/models/javali.bin",0
	;db "/models/tholin.bin",0
	db 0,0
	align 4
inode_cache:
	; Testing values - overwritten on boot
	dd 0x00100002
	dd 0x00100009
	dd 0x00100011
	dd 0x00100004
	dd 0x00100006
	dd 0x0010000A
	dd 0x0010000B
	dd 0x0010000F
	dd 0x0010000C
	dd 0x0010000D
	dd 0x0010000E
	dd 0x00100010
	dd 0x00100014
	dd 0x00100012
	dd 0x00100013
	dd 0x00100007
	dd 0x00100008
	dd 0x00100003
	dd 0x00100005
	dd 0x00020003
	include "bitmap.asm" ; This always needs to be the last thing included
