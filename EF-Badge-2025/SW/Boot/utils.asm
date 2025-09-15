	SECTION utils
	PUBLIC read_controller
	align 16
nes_clk_bit equ 4
nes_latch_bit equ 8
nes_data_bit equ 16
log_nes_data_bit equ 4
	; Uses: r1, r2, r3
	; Result in r3
read_controller:
	lw r1, PORTA(r62) #
	ori r1, r1, nes_latch_bit #
	sw r1, PORTA(r62)
	---
	xor r3, r3, r3
	xori r1, r1, nes_latch_bit #
	sw r1, PORTA(r62)
	---
	liu r2, 7
	---
read_controller_loop:
	slli r3, r3, 1
	lw r1, PINA(r62) #
	srli r1, r1, log_nes_data_bit
	---
	andi r1, r1, 1 #
	or r3, r1, r3
	---
	lw r1, PORTA(r62) #
	ori r1, r1, nes_clk_bit #
	sw r1, PORTA(r62)
	---
	xori r1, r1, nes_clk_bit #
	sw r1, PORTA(r62)
	---
	subi r2, r2, 1
	bnez r2, read_controller_loop
	---
	jalr zero, r60, 0
	---
	ENDSECTION
