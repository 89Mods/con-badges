	SECTION SDCARD
	PUBLIC sdcard_init
	PUBLIC sdcard_read_block
	PUBLIC sd_capacity
	align 16
	; Compute CRC7
	; Args: byte, crc7
	; Uses: r1, r2, r3
sd_crc7:
	lui r1, 0
	lli r1, 7
	andi r16, r16, 0xFF
	---
sd_crc7_loop:
	slli r17, r17, 1 #
	andi r2, r16, 0x80
	andi r3, r17, 0x80
	---
	pne p1, r2, r3 #
	slli r16, r16, 1
	xori r17, r17, 0x09 [p1]
	---
	subi r1, r1, 1
	bnez r1, sd_crc7_loop
	nop
	---
	andi r17, r17, 0x7F
	jalr zero, r60, 0
	nop
	---

	; Wait for SD card to respond to a command
	; Args: none
	; Uses: r1, r2
	; Returns: byte received (r2)
sd_res1:
	lui r1, 0
	lli r1, 255
	lui r2, 0
	---
sd_res1_loop:
	lli r2, 255
	subi r1, r1, 1
	bez r1, sd_res1_done
	---
	sw r2, SDAT(r62)
	---
	lw r2, STAT(r62) #
	andi r2, r2, 2 #
	bnez r2, $
	---
	lw r2, SDAT(r62) #
	subi r2, r2, 255 #
	bez r2, sd_res1_loop
	---
sd_res1_done:
	addi r2, r2, 255
	jalr zero, r60, 0
	---

	; Reads a word-length command result from SD card
	; Args: none
	; Uses: r1, r2
	; Returns word received (r2)
sd_res7:
	xor r2, r2, r2
	lli r1, 255
	---
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	lw r1, SDAT(r62) #
	or r2, r2, r1
	lli r1, 255
	---
	sw r1, SDAT(r62)
	slli r2, r2, 8
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	lw r1, SDAT(r62) #
	or r2, r2, r1
	lli r1, 255
	---
	sw r1, SDAT(r62)
	slli r2, r2, 8
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	lw r1, SDAT(r62) #
	or r2, r2, r1
	lli r1, 255
	---
	sw r1, SDAT(r62)
	slli r2, r2, 8
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	lw r1, SDAT(r62) #
	or r2, r2, r1
	jalr zero, r60, 0
	---

	; Waits for the SD card to be idle (all 0xFF on the bus)
	; Args: none
	; Uses: r1
sd_wait_ready:
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	lw r1, SDAT(r62) #
	xori r1, r1, 255 #
	bnez r1, sd_wait_ready
	---
sd_wait_ready_done:
	jalr zero, r60, 0
	---

	; Waits for the SD card to send the start token for a buffer transfer
	; Args: none
	; Uses: r1, r2
	; Returns: error code (r2)
sd_wait_buffer_ready:
	lui r2, 0
	lli r2, 32000
	---
sd_wait_buffer_ready_loop:
	lli r1, 0xFF #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	lw r1, SDAT(r62) #
	---
	subi r1, r1, 0xFE #
	bez r1, sd_wait_buffer_ready_done
	addi r1, r1, 0xFE
	---
	andi r1, r1, 0xF0 #
	bez r1, sd_wait_buffer_ready_error
	---
	subi r2, r2, 1
	bnez r2, sd_wait_buffer_ready_loop
	---
sd_wait_buffer_ready_timeout:
	lui r2, 0
	lli r2, 0xFF
	bez zero, sd_desel
	---
sd_wait_buffer_ready_done:
	xor r2, zero, zero
	jalr zero, r60, 0
	---
sd_wait_buffer_ready_error:
	srli r2, r1, 4
	bez zero, sd_desel
	---

	; Send command to sdcard
	; Args: cmd, arg
	; Uses: r1, r2, r3, r4, r5, r6, r8
sd_cmd:
	sw r60, 0(r61)
	subi r61, r61, 4
	ori r16, r16, 0x40 ; cmd |= 0x40
	---
	lli r60, (sd_wait_ready-$)>>4 #
	lipc r60, r60 #
	jalr r60, r60, 0
	---
	cpy r6, r16
	xor r17, r17, r17
	cpy r4, r17
	---
	; sd_crc7(cmd, &crc);
	lli r8, (sd_crc7-$)>>4 #
	lipc r8, r8 #
	jalr r60, r8, 0
	---
	; sd_crc7(arg >> 24, &crc);
	nop
	srli r16, r4, 24
	jalr r60, r8, 0
	---
	; sd_crc7(arg >> 16, &crc);
	nop
	srli r16, r4, 16
	jalr r60, r8, 0
	---
	; sd_crc7(arg >> 8, &crc);
	nop
	srli r16, r4, 8
	jalr r60, r8, 0
	---
	; sd_crc7(arg, &crc);
	nop
	cpy r16, r4
	jalr r60, r8, 0
	---
	; crc = (crc << 1) | 1;
	add r17, r17, r17 #
	addi r17, r17, 1
	sw r6, SDAT(r62) ; Send cmd
	---
	lw r6, STAT(r62) #
	andi r6, r6, 2 #
	bnez r6, $
	---
	; Send arg >> 24
	srli r6, r4, 24 #
	sw r6, SDAT(r62)
	nop
	---
	lw r6, STAT(r62) #
	andi r6, r6, 2 #
	bnez r6, $
	---
	; Send arg >> 16
	srli r6, r4, 16 #
	sw r6, SDAT(r62)
	nop
	---
	lw r6, STAT(r62) #
	andi r6, r6, 2 #
	bnez r6, $
	---
	; Send arg >> 8
	srli r6, r4, 8 #
	sw r6, SDAT(r62)
	nop
	---
	lw r6, STAT(r62) #
	andi r6, r6, 2 #
	bnez r6, $
	---
	; Send arg >> 0
	srli r6, r4, 0 #
	sw r6, SDAT(r62)
	nop
	---
	lw r6, STAT(r62) #
	andi r6, r6, 2 #
	bnez r6, $
	---
	; Send crc
	nop
	nop
	sw r17, SDAT(r62)
	---
	lw r6, STAT(r62) #
	andi r6, r6, 2 #
	bnez r6, $
	---
	; Return
	lw r60, 4(r61)
	addi r61, r61, 4 #
	jalr zero, r60, 0
	---

	; Select SD card - pulls CS low and sends dummy cycles
	; Args: none
	; Uses: r1
sd_sel:
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	lw r1, PORTA(r62) #
	andi r1, r1, 255-1 #
	sw r1, PORTA(r62)
	---
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	; Return
	jalr zero, r60, 0
	---

	; Deselect SD card - sends dummy cycles and pulls CS high
	; Args: none
	; Uses: r1
sd_desel:
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	lw r1, PORTA(r62) #
	ori r1, r1, 1 #
	sw r1, PORTA(r62)
	---
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	; Return
	jalr zero, r60, 0
	---

SD_CMD0 equ 0
SD_CMD0_ARG equ 0
SD_CMD8 equ 8
SD_CMD8_ARG equ 0x1AA
SD_CMD58 equ 58
SD_CMD58_ARG equ 0
SD_CMD55 equ 55
SD_CMD55_ARG equ 0
SD_ACMD41 equ 41
SD_ACMD41_ARG equ 0x40000000
SD_CMD59 equ 59
SD_CMD59_ARG equ 0
SD_CMD16 equ 16
SD_CMD16_ARG equ 512
SD_CMD9 equ 9
SD_CMD9_ARG equ 0
SD_CMD17 equ 17
SD_CMD24 equ 24

sdcard_init:
	lliu r1, sd_capacity&0xFFFF
	lui r1, sd_capacity>>16 #
	sw r0, 0(r1)
	---
	subi r61, r61, 12 #
	sw r60, 12(r61)
	---
	sw r24, 4(r61) #
	sw r25, 8(r61)
	---
	lw r1, PORTA(r62) #
	ori r1, r1, 32 #
	sw r1, PORTA(r62)
	---
	lui r1, 0
	lli r1, 9
	lli r2, 255
	---
	; Bunch of cycles with CS high to put card in SPI mode
sdcard_spiinit_loop:
	sw r2, SDAT(r62)
	nop
	nop
	---
sdcard_spi_wait_1:
	lw r3, STAT(r62) #
	andi r3, r3, 2 #
	bnez r3, sdcard_spi_wait_1
	---
	subi r1, r1, 1
	bnez r1, sdcard_spiinit_loop
	lui r25, 0
	---
	lliu r16, text_sd_cmd0&0xFFFF
	lui r16, text_sd_cmd0>>16
	---
	nop
	---
	lli r25, 500
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
sdcard_cmd0_loop:
	subi r25, r25, 1
	bez r25, sdcard_cmd0_timeout
	---
	lipc r60, zero #
	jalr r60, r60, (sd_sel-$)>>4
	---
	lli r16, SD_CMD0
	lliu r17, SD_CMD0_ARG&0xFFFF
	lui r17, SD_CMD0_ARG>>16
	---
	lipc r60, zero #
	jalr r60, r60, (sd_cmd-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_res1-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_desel-$)>>4
	---
	subi r3, r2, 255 #
	bez r3, sdcard_cmd0_loop
	---
	subi r3, r2, 1 #
	bnez r3, sdcard_cmd0_fail
	---
sdcard_cmd0_pass:
	lliu r16, text_sd_cmd8&0xFFFF
	lui r16, text_sd_cmd8>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_sel-$)>>4
	---
	lli r16, SD_CMD8
	lliu r17, SD_CMD8_ARG&0xFFFF
	lui r17, SD_CMD8_ARG>>16
	---
	lipc r60, zero #
	jalr r60, r60, (sd_cmd-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_res1-$)>>4
	---
	subi r2, r2, 1 #
	bnez r2, sdcard_cmd8_fail
	addi r2, r2, 1
	---
	lipc r60, zero #
	jalr r60, r60, (sd_res7-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_desel-$)>>4
	---
	srli r1, r2, 8 #
	andi r1, r1, 15
	---
	subi r1, r1, 1 #
	bnez r1, sdcard_cmd8_bad_response
	---
	andi r1, r2, 255 #
	subi r1, r1, 0xAA #
	bnez r1, sdcard_cmd8_bad_response
	---
sdcard_cmd8_pass:
	lliu r16, text_sd_cmd58&0xFFFF
	lui r16, text_sd_cmd58>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_sel-$)>>4
	---
	lli r16, SD_CMD58
	lliu r17, SD_CMD58_ARG&0xFFFF
	lui r17, SD_CMD58_ARG>>16
	---
	lipc r60, zero #
	jalr r60, r60, (sd_cmd-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_res1-$)>>4
	---
	subi r2, r2, 1 #
	bnez r2, sdcard_cmd58_fail
	addi r2, r2, 1
	---
	lipc r60, zero #
	jalr r60, r60, (sd_res7-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_desel-$)>>4
	---
	srli r3, r2, 15 #
	andi r3, r3, 0b001100000 #
	bez r3, sdcard_cmd58_bad_response
	---
sdcard_cmd58_pass:
	lliu r16, text_sd_acmd41&0xFFFF
	lui r16, text_sd_acmd41>>16
	xor r25, r25, r25
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	lliu r25, 600
	---
sdcard_acmd41_loop:
	subi r25, r25, 1
	bez r25, sdcard_acmd41_timeout
	---
	lipc r60, zero #
	jalr r60, r60, (sd_sel-$)>>4
	---
	lli r16, SD_CMD55
	lliu r17, SD_CMD55_ARG&0xFFFF
	lui r17, SD_CMD55_ARG>>16
	---
	lipc r60, zero #
	jalr r60, r60, (sd_cmd-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_res1-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_desel-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_sel-$)>>4
	---
	lli r16, SD_ACMD41
	lliu r17, SD_ACMD41_ARG&0xFFFF
	lui r17, SD_ACMD41_ARG>>16
	---
	lipc r60, zero #
	jalr r60, r60, (sd_cmd-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_res1-$)>>4
	xor r3, r3, r3
	---
	lipc r60, zero #
	jalr r60, r60, (sd_desel-$)>>4
	lli r3, 1
	---
	bez r2, sdcard_acmd41_pass
	be r2, r3, sdcard_acmd41_loop
	bez zero, sdcard_acmd41_fail
	---
sdcard_acmd41_pass:
	lui r25, 0
	lli r25, 1
	nop
	---
	lliu r16, text_sd_cmd58&0xFFFF
	lui r16, text_sd_cmd58>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_sel-$)>>4
	---
	lli r16, SD_CMD58
	lliu r17, SD_CMD58_ARG&0xFFFF
	lui r17, SD_CMD58_ARG>>16
	---
	lipc r60, zero #
	jalr r60, r60, (sd_cmd-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_res1-$)>>4
	---
	lipc r60, zero #
	bg r2, r25, sdcard_cmd58_fail
	jalr r60, r60, (sd_res7-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_desel-$)>>4
	---
	srli r3, r2, 30 #
	andi r3, r3, 1 #
	bp r2, sdcard_cmd58_bad_response
	---
	lliu r16, text_sd_cap&0xFFFF
	lui r16, text_sd_cap>>16
	bez r3, sdcard_cmd58_pass_2
	---
sdcard_cmd58_is_hc:
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
sdcard_cmd58_pass_2:
	lliu r16, text_sd_cmd59&0xFFFF
	lui r16, text_sd_cmd59>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_sel-$)>>4
	---
	lli r16, SD_CMD59
	lliu r17, SD_CMD59_ARG&0xFFFF
	lui r17, SD_CMD59_ARG>>16
	---
	lipc r60, zero #
	jalr r60, r60, (sd_cmd-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_res1-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_desel-$)>>4
	---
	andi r2, r2, 0xFF #
	bg r2, r25, sdcard_cmd59_fail
	---
sdcard_cmd59_pass:
	lliu r16, text_sd_cmd16&0xFFFF
	lui r16, text_sd_cmd16>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_sel-$)>>4
	---
	lli r16, SD_CMD16
	lliu r17, SD_CMD16_ARG&0xFFFF
	lui r17, SD_CMD16_ARG>>16
	---
	lipc r60, zero #
	jalr r60, r60, (sd_cmd-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_res1-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_desel-$)>>4
	---
	andi r2, r2, 0xFF #
	bg r2, r25, sdcard_cmd16_fail
	---
sdcard_cmd16_pass:
	nop
	lli r1, FAST_SPI_DIV # ; Now faster SDIV possible
	sw r1, SDIV(r62)
	---
	lliu r16, text_sd_cmd9&0xFFFF
	lui r16, text_sd_cmd9>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_sel-$)>>4
	---
	lli r16, SD_CMD9
	lliu r17, SD_CMD9_ARG&0xFFFF
	lui r17, SD_CMD9_ARG>>16
	---
	lipc r60, zero #
	jalr r60, r60, (sd_cmd-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_res1-$)>>4
	---
	andi r2, r2, 0xFF #
	bg r2, r25, sdcard_cmd9_fail
	---
	lipc r60, zero #
	jalr r60, r60, (sd_wait_buffer_ready-$)>>4
	xor r24, r60, r60
	---
	bnez r2, sdcard_cmd9_fail
	---
	; First cmd9 byte
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	lw r1, SDAT(r62) #
	srli r1, r1, 6 #
	subi r1, r1, 1
	---
	bez r1, sd_cmd9_one_way
	nop
	bnez r1, sd_cmd9_the_other_way
	---
sd_cmd9_one_way:
	lui r3, 0
	lli r3, 5
	---
sd_skip1_loop:
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	subi r3, r3, 1
	bnez r3, sd_skip1_loop
	---
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	lw r1, SDAT(r62) #
	andi r1, r1, 63 #
	slli r24, r1, 16
	---
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	lw r1, SDAT(r62) #
	slli r1, r1, 8 #
	or r24, r1, r24
	---
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	lw r1, SDAT(r62) #
	or r24, r1, r24 #
	addi r24, r24, 1
	---
	slli r24, r24, 10
	lui r3, 0
	lli r3, 5+2
	---
sd_skip2_loop:
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	subi r3, r3, 1
	bnez r3, sd_skip2_loop
	bez r3, sd_cmd9_pass
	---
sd_cmd9_the_other_way:
	lui r3, 0
	lli r3, 3
	---
sd_skip3_loop:
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	subi r3, r3, 1
	bnez r3, sd_skip3_loop
	---
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	lw r1, SDAT(r62) #
	andi r25, r1, 15
	---
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	lw r1, SDAT(r62) #
	andi r1, r1, 3 #
	slli r24, r1, 10
	---
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	lw r1, SDAT(r62) #
	slli r1, r1, 2 #
	add r24, r24, r1
	---
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	lw r1, SDAT(r62) #
	srli r1, r1, 6 #
	add r24, r24, r1
	---
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	lw r1, SDAT(r62) #
	andi r1, r1, 3 #
	add r1, r1, r1
	---
	add r25, r25, r1
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	lw r1, SDAT(r62) #
	andi r1, r1, 128 #
	srli r1, r1, 7
	---
	add r25, r25, r1 #
	addi r25, r25, 2
	addi r24, r24, 1
	---
	subi r25, r25, 9 #
	sll r24, r24, r25
	---
	lui r3, 0
	lli r3, 4+2
	---
sd_skip4_loop:
	lli r1, 255 #
	sw r1, SDAT(r62)
	---
	lw r1, STAT(r62) #
	andi r1, r1, 2 #
	bnez r1, $
	---
	subi r3, r3, 1
	bnez r3, sd_skip4_loop
	---
sd_cmd9_pass:
	lipc r60, zero #
	jalr r60, r60, (sd_desel-$)>>4
	---
	lliu r1, sd_capacity&0xFFFF
	lui r1, sd_capacity>>16 #
	sw r24, 0(r1)
	---
	srli r24, r24, 1
	lliu r16, text_sd_capacity&0xFFFF
	lui r16, text_sd_capacity>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	cpy r16, r24
	lipc r60, zero #
	jalr r60, r60, (puthex32_cachef-$)>>4
	---
	lliu r16, text_sd_capacity_end&0xFFFF
	lui r16, text_sd_capacity_end>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	bez r24, sdcard_capacity_fail
	---
	liu r16, 0
	---

sdcard_init_return:
	lw r24, 4(r61) #
	lw r60, 12(r61)
	---
	; Return
	lw r25, 8(r61)
	addi r61, r61, 12
	jalr zero, r60, 0
	---

sdcard_capacity_fail:
	lliu r16, text_sd_fail_capacity&0xFFFF
	lui r16, text_sd_fail_capacity>>16
	bez zero, sdcard_print_res_fail
	---
sdcard_cmd9_fail:
	lliu r16, text_sd_cmd9_fail&0xFFFF
	lui r16, text_sd_cmd9_fail>>16
	bez zero, sdcard_print_res_fail
	---
sdcard_cmd59_fail:
	lliu r16, text_sd_cmd59_fail&0xFFFF
	lui r16, text_sd_cmd59_fail>>16
	bez zero, sdcard_print_res_fail
	---
sdcard_cmd16_fail:
	lliu r16, text_sd_cmd16_fail&0xFFFF
	lui r16, text_sd_cmd16_fail>>16
	bez zero, sdcard_print_res_fail
	---
sdcard_acmd41_fail:
	lliu r16, text_sd_acmd41_fail&0xFFFF
	lui r16, text_sd_acmd41_fail>>16
	bez zero, sdcard_print_res_fail
	---
sdcard_acmd41_timeout:
	lliu r16, text_sd_acmd41_timeout&0xFFFF
	lui r16, text_sd_acmd41_timeout>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	bez zero, sdcard_init_fail
	---
sdcard_cmd58_bad_response:
	lliu r16, text_sd_cmd58_bad_response&0xFFFF
	lui r16, text_sd_cmd58_bad_response>>16
	bez zero, sdcard_print_res_fail
	---
sdcard_cmd58_fail:
	lliu r16, text_sd_cmd58_fail&0xFFFF
	lui r16, text_sd_cmd58_fail>>16
	bez zero, sdcard_print_res_fail
	---
sdcard_cmd8_bad_response:
	lliu r16, text_sd_cmd8_bad_response&0xFFFF
	lui r16, text_sd_cmd8_bad_response>>16
	bez zero, sdcard_print_res_fail
	---
sdcard_cmd8_fail:
	lliu r16, text_sd_cmd8_fail&0xFFFF
	lui r16, text_sd_cmd8_fail>>16
	bez zero, sdcard_print_res_fail
	---
sdcard_cmd0_timeout:
	lliu r16, text_sd_cmd0_timeout&0xFFFF
	lui r16, text_sd_cmd0_timeout>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	bez zero, sdcard_init_fail
	---
sdcard_cmd0_fail:
	lliu r16, text_sd_cmd0_fail&0xFFFF
	lui r16, text_sd_cmd0_fail>>16
	---
sdcard_print_res_fail:
	cpy r24, r2
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	cpy r16, r24
	lipc r60, zero #
	jalr r60, r60, (puthex32_cachef-$)>>4
	---
	lliu r16, text_sd_clear_color_nl&0xFFFF
	lui r16, text_sd_clear_color_nl>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
sdcard_init_fail:
	lipc r60, zero #
	jalr r60, r60, (sd_desel-$)>>4
	---
	lipc r60, zero #
	lli r2, 1
	jalr r60, r60, (init_leds-$)>>4
	---
	bez r0, $
	---

	; Reads one block from the SD card
	; Args: byte buffer ptr, block address
	; Returns: error code (r2)
	; ADDRESS MUST BE WORD-ALIGNED!
sdcard_read_block:
	subi r61, r61, 16 #
	sw r60, 12(r61)
	---
	sw r24, 4(r61) #
	sw r25, 8(r61) #
	sw r26, 16(r61)
	---
	
	liu r3, stat_base_no_irupts #
	sh r3, F_STAT(r58)
	---
	
	cpy r25, r16
	lipc r60, zero #
	jalr r60, r60, (sd_sel-$)>>4
	---
	lli r16, SD_CMD17 ; and r17 should already contain the required argument
	lipc r60, zero #
	jalr r60, r60, (sd_cmd-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sd_res1-$)>>4
	---
	subi r3, r2, 2 #
	bp r3, sdcard_read_block_fail
	---
	lipc r60, zero #
	jalr r60, r60, (sd_wait_buffer_ready-$)>>4
	xor r24, r60, r60
	---
	bnez r2, sdcard_read_block_fail
	liu r24, 255
	liu r26, 255
	---
	liu r1, 1 #
	sw r1, ICEN(r62)
	---
sdcard_read_block_loop:
	sw r26, SDAT(r62)
	---
sdcard_r_1:
	lw r1, STAT(r62)
	---
	andi r1, r1, 2
	---
	bnez r1, sdcard_r_1
	---
	lw r2, SDAT(r62)
	---
	sw r26, SDAT(r62)
	---
sdcard_r_2:
	lw r1, STAT(r62)
	---
	andi r1, r1, 2
	---
	bnez r1, sdcard_r_2
	---
	lw r1, SDAT(r62)
	---
	slli r1, r1, 8
	---
	or r1, r2, r1
	---
	sw r1, 0(r25)
	---
	addi r25, r25, 2
	---
	subi r24, r24, 1
	bnez r24, sdcard_read_block_loop
	---
	sw zero, ICEN(r62)
	---
	lipc r60, zero #
	jalr r60, r60, (sd_desel-$)>>4
	xor r2, r2, r2
	---
sdcard_read_block_return:
	liu r3, stat_base #
	sh r3, F_STAT(r58)
	---
	nop
	---
	nop
	---
	cpy r16, r25
	---
	lw r26, 16(r61) #
	lw r24, 4(r61) #
	lw r60, 12(r61)
	---
	; Return
	lw r25, 8(r61)
	addi r61, r61, 16
	jalr zero, r60, 0
	---
sdcard_read_block_fail:
	nop
	nop
	bez zero, sdcard_read_block_return
	---

text_sd_cmd0:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] [SD] CMD0",13,10,0
text_sd_cmd0_fail:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] [SD] CMD0 FAIL ",0
text_sd_cmd0_timeout:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] [SD] CMD0 TIMEOUT",0x1B,"[0m",13,10,0
text_sd_cmd8:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] [SD] CMD8",13,10,0
text_sd_cmd8_fail:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] [SD] CMD8 FAIL ",0
text_sd_cmd8_bad_response:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] [SD] BAD CMD8 RESPONSE ",0
text_sd_cmd58:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] [SD] CMD58",13,10,0
text_sd_cmd58_fail:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] [SD] CMD58 FAIL ",0
text_sd_cmd58_bad_response:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] [SD] BAD CMD58 RESPONSE ",0
text_sd_acmd41:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] [SD] ACMD41",13,10,0
text_sd_acmd41_timeout:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] [SD] ACMD41 TIMEOUT",0x1B,"[0m",13,10,0
text_sd_acmd41_fail:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] [SD] ACMD41 FAIL ",0
text_sd_cap:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] [SD] ",0x1B,"[1;32m","SD Card type is SDXC or SDHC",0x1B,"[0m",13,10,0
text_sd_cmd59:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] [SD] CMD59",13,10,0
text_sd_cmd59_fail:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] [SD] CMD59 FAIL ",0
text_sd_cmd16:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] [SD] CMD16",13,10,0
text_sd_cmd16_fail:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] [SD] CMD16 FAIL ",0
text_sd_cmd9:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] [SD] CMD9",13,10,0
text_sd_cmd9_fail:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] [SD] CMD9 FAIL ",0
text_sd_clear_color_nl:
	db 0x1B,"[0m",13,10,0
text_sd_capacity:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] [SD] Capacity: ",0
text_sd_capacity_end:
	db "KiB",13,10,'[',0x1B,"[1;34mINFO",0x1B,"[0m] [SD] Initialized!",13,10,13,10,0
text_sd_fail_capacity:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] [SD] SD has 0 capacity. Init FAIL!",0x1B,"[0m",13,10,0
	align 4
sd_capacity:
	dd 0
	dd 0
	ENDSECTION
