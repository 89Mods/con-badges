	; Prints a string over UART
	; Args: byte*
	; Uses: none
putstr:
	nop
	---
	sw r15, 0(r61)
	subi r61, r61, 4
	nop
	---
putstr_loop:
	lbu r15, 0(r16) #
	bez r15, putstr_done #
	sh r15, F_UDAT(r58)
	---
	lhu r15, F_STAT(r58) #
	andi r15, r15, stat_ubusy #
	bnez r15, $
	---
	addi r16, r16, 1
	nop
	bez r0, putstr_loop
	---
putstr_done:
	lw r15, 4(r61)
	addi r61, r61, 4
	---
	nop
	---
	jalr zero, r60, 0
	---

putchar_cachef:
	nop
	---
	sw r1, 0(r61)
	subi r61, r61, 4
	---
	sh r16, F_UDAT(r58)
	---
putchar_cachef_wait_loop:
	lhu r1, F_STAT(r58)
	---
	andi r1, r1, stat_ubusy
	---
	bnez r1, putchar_cachef_wait_loop
	---
putchar_cachef_done:
	addi r61, r61, 4
	lw r1, 0(r61)
	---
	nop
	---
	jalr zero, r60, 0
	---

	; Prints a single byte as hexadecimal over UART
	; Args: byte
	; Uses: none
puthex8:
	nop
	---
	sw r15, 0(r61) #
	sw r33, -4(r61)
	subi r61, r61, 8
	---
	lui r33, hex_chars>>16
	lliu r33, hex_chars&0xFFFF
	nop
	---
	srli r15, r16, 4 #
	andi r15, r15, 0xF #
	add r15, r15, r33
	---
	lb r15, 0(r15) #
	sh r15, F_UDAT(r58)
	nop
	---
	lhu r15, F_STAT(r58) #
	andi r15, r15, stat_ubusy #
	bnez r15, $
	---
	andi r15, r16, 0xF #
	add r15, r33, r15 #
	lb r15, 0(r15)
	---
	sh r15, F_UDAT(r58) #
	lw r33, 4(r61)
	nop
	---
	lhu r15, F_STAT(r58) #
	andi r15, r15, stat_ubusy #
	bnez r15, $
	---
	lw r15, 8(r61)
	addi r61, r61, 8
	---
	nop
	---
	jalr zero, r60, 0
	---

	; Same as puthex8, but cache-friendly
	; (Workaround for CI2406 bug)
puthex8_cachef:
	nop
	---
	sw r15, 0(r61)
	subi r61, r61, 8
	---
	sw r33, 4(r61)
	srli r15, r16, 4
	---
	lui r33, hex_chars>>16
	lliu r33, hex_chars&0xFFFF
	andi r15, r15, 0xF
	---
	add r15, r15, r33
	---
	lb r15, 0(r15)
	---
	sh r15, F_UDAT(r58)
	---
	lhu r15, F_STAT(r58)
	---
	andi r15, r15, stat_ubusy
	---
	bnez r15, $-32
	andi r15, r16, 0xF
	---
	add r15, r33, r15
	---
	lb r15, 0(r15)
	---
	sh r15, F_UDAT(r58)
	---
	lhu r15, F_STAT(r58)
	---
	andi r15, r15, stat_ubusy
	---
	bnez r15, $-32
	---
	lw r33, 4(r61)
	---
	lw r15, 8(r61)
	addi r61, r61, 8
	jalr zero, r60, 0
	---

	; Same as puthex32, but cache-friendly
	; (Workaround for CI2406 bug)
puthex32_cachef:
	nop
	---
	subi r61, r61, 16
	---
	sw r51, 4(r61)
	---
	sw r60, 8(r61)
	lli r51, (puthex8_cachef-$-16)>>4
	---
	sw r33, 12(r61)
	lipc r51, r51
	---
	cpy r33, r16
	sw r16, 16(r61)
	nop
	---
	srli r16, r33, 24
	jalr r60, r51, 0
	---
	srli r16, r33, 16
	jalr r60, r51, 0
	---
	srli r16, r33, 8
	jalr r60, r51, 0
	---
	srli r16, r33, 0
	jalr r60, r51, 0
	---
	lw r16, 16(r61)
	---
	lw r51, 4(r61)
	---
	lw r60, 8(r61)
	---
	lw r33, 12(r61)
	addi r61, r61, 16
	---
	nop
	---
	jalr zero, r60, 0
	---

	; Sends a newline (\r\n) over the UART
	; Args: none
	; Uses: none
newl:
	nop
	---
	sw r1, 0(r61)
	subi r61, r61, 4
	---
	lui r1, 0
	lliu r1, '\r' #
	sh r1, F_UDAT(r58)
	---
	lhu r1, F_STAT(r58) #
	andi r1, r1, stat_ubusy #
	bnez r1, $
	---
	lui r1, 0
	lliu r1, '\n' #
	sh r1, F_UDAT(r58)
	---
	lhu r1, F_STAT(r58) #
	andi r1, r1, stat_ubusy #
	bnez r1, $
	---
	lw r1, 4(r61)
	addi r61, r61, 4
	---
	nop
	---
	jalr zero, r60, 0
	---

	; Same as puthex8, but cache-friendly
	; (Workaround for CI2406 bug)
newl_cachef:
	nop
	---
	subi r61, r61, 4
	sw r1, 0(r61)
	---
	lui r1, 0
	lliu r1, '\r'
	---
	sh r1, F_UDAT(r58)
	---
	lhu r1, F_STAT(r58)
	---
	nop
	andi r1, r1, stat_ubusy
	nop
	---
	bnez r1, $-32
	lui r1, 0
	lliu r1, '\n'
	---
	sh r1, F_UDAT(r58)
	---
	lhu r1, F_STAT(r58)
	---
	andi r1, r1, stat_ubusy
	---
	bnez r1, $-32
	---
	addi r61, r61, 4
	lw r1, 4(r61)
	---
	nop
	---
	jalr zero, r60, 0
	---

	; Returns length of a null-terminated string
	; Args: byte*
	; Returns: length of string (r17)
	; Uses: none
strlen:
	subi r61, r61, 12 #
	sw r60, 12(r61)
	---
	sw r16, 4(r61) #
	sw r1, 8(r61)
	---
	xor r17, r17, r17
	lli r1, 1 #
	sw r1, ICEN(r62) ; Enable icache
	---
strlen_loop:
	lbu r1, 0(r16)
	---
	bez r1, strlen_loop_end
	---
	addi r16, r16, 1
	addi r17, r17, 1
	bez zero, strlen_loop
	---
strlen_loop_end:
	nop
	nop
	sw zero, ICEN(r62) ; Disable icache
	---
	lw r16, 4(r61) #
	lw r1, 8(r61) #
	lw r60, 12(r61)
	---
	addi r61, r61, 12
	---
	nop
	---
	jalr zero, r60, 0
	---
