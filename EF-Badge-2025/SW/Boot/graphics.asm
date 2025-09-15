lcd_width equ 800
lcd_height equ 480
character_width equ 7
character_height equ 8

	SECTION graphics
	PUBLIC lcd_init
	PUBLIC lcd_clear
	PUBLIC draw_string
	PUBLIC disp_image_raw
	PUBLIC disp_image_qoi
	PUBLIC led_pattern_illuminate
	PUBLIC led_pattern_tholin
	PUBLIC leds_constant_color
	align 16
lcd_delay_len equ 0xFFF
	; Initialize display - to be used once after reset
	; Args: none
	; Returns: none
	; Uses: r1
lcd_init:
	; Display init
	; PLL multiplier, set PLL clock to 120M
	sh zero, F_LCD_CMD(r58) #
	sh zero, F_LCD_CMD(r58)
	---
	liu r1, 0xE2 #
	sh r1, F_LCD_CMD(r58) #
	liu r1, 0x23
	---
	sh r1, F_LCD_PARAM(r58) #
	liu r1, 0x02 #
	sh r1, F_LCD_PARAM(r58)
	---
	liu r1, 0x54 #
	sh r1, F_LCD_PARAM(r58) #
	; PLL Enable
	liu r1, 0xE0
	---
	sh r1, F_LCD_CMD(r58) #
	liu r1, 0x01 #
	sh r1, F_LCD_PARAM(r58)
	---
	lliu r1, lcd_delay_len&0xFFFF ; Set delay length
	lui r1, lcd_delay_len>>16
	---
	subi r1, r1, 1
	bne r1, r0, $
	---
	liu r1, 0xE0 #
	sh r1, F_LCD_CMD(r58) #
	liu r1, 0x03
	---
	sh r1, F_LCD_PARAM(r58)
	lliu r1, lcd_delay_len&0xFFFF ; Set delay length
	lui r1, lcd_delay_len>>16
	---
	subi r1, r1, 1
	bne r1, r0, $
	---
	; software reset
	liu r1, 0x01 #
	sh r1, F_LCD_CMD(r58)
	---
	lliu r1, lcd_delay_len&0xFFFF ; Set delay length
	lui r1, lcd_delay_len>>16
	---
	subi r1, r1, 1
	bne r1, r0, $
	---
	; PLL setting to PCLK, depends on resolution
	liu r1, 0xE6 #
	sh r1, F_LCD_CMD(r58) #
	liu r1, 0x03
	---
	sh r1, F_LCD_PARAM(r58) #
	liu r1, 0x33 #
	sh r1, F_LCD_PARAM(r58)
	---
	sh r1, F_LCD_PARAM(r58) #
	; LCD SPECIFICATION
	liu r1, 0xB0 #
	sh r1, F_LCD_CMD(r58)
	---
	liu r1, 0x20 #
	sh r1, F_LCD_PARAM(r58) #
	sh zero, F_LCD_PARAM(r58)
	---
	liu r1, 0x03 # ; Set HDP 799
	sh r1, F_LCD_PARAM(r58) #
	liu r1, 0x1F
	---
	sh r1, F_LCD_PARAM(r58) #
	liu r1, 0x01 # ; set VDP 479
	sh r1, F_LCD_PARAM(r58)
	---
	liu r1, 0xDF #
	sh r1, F_LCD_PARAM(r58) #
	sh zero, F_LCD_PARAM(r58)
	---
	
	; HSYNC
	liu r1, 0xB4 #
	sh r1, F_LCD_CMD(r58) #
	liu r1, 0x04 ; Set HT 928
	---
	sh r1, F_LCD_PARAM(r58) #
	liu r1, 0x1F #
	sh r1, F_LCD_PARAM(r58)
	---
	sh zero, F_LCD_PARAM(r58) ; Set HPS 46
	liu r1, 0xD2 #
	sh r1, F_LCD_PARAM(r58)
	---
	sh zero, F_LCD_PARAM(r58) # ; Set HPW 48
	sh zero, F_LCD_PARAM(r58) # ; Set LPS 15
	sh zero, F_LCD_PARAM(r58)
	---
	sh zero, F_LCD_PARAM(r58)
	; VSYNC
	liu r1, 0xB6 #
	sh r1, F_LCD_CMD(r58)
	---
	liu r1, 0x02 # ; Set VT 525
	sh r1, F_LCD_PARAM(r58) #
	liu r1, 0x0C
	---
	sh r1, F_LCD_PARAM(r58) #
	sh zero, F_LCD_PARAM(r58) ; Set VPS 16
	liu r1, 0x22
	---
	sh r1, F_LCD_PARAM(r58) #
	sh zero, F_LCD_PARAM(r58) # ; Set VPW 16
	sh zero, F_LCD_PARAM(r58) ; Set FPS 8
	---
	sh zero, F_LCD_PARAM(r58)
	liu r1, 0xBA #
	sh r1, F_LCD_CMD(r58)
	---
	liu r1, 0x01 #
	sh r1, F_LCD_PARAM(r1)
	---
	lliu r1, lcd_delay_len&0xFFFF ; Set delay length
	lui r1, lcd_delay_len>>16
	---
	subi r1, r1, 1
	bne r1, r0, $
	---
	liu r1, 0xB8 #
	sh r1, F_LCD_CMD(r58) #
	liu r1, 0x0F
	---
	sh r1, F_LCD_PARAM(r58) #
	liu r1, 0x01 #
	sh r1, F_LCD_PARAM(r58)
	---
	liu r1, 0x36 #
	sh r1, F_LCD_CMD(r58) #
	sh zero, F_LCD_PARAM(r58)
	---
	
	; Pixel data interface
	liu r1, 0xF0 #
	sh r1, F_LCD_CMD(r58) #
	liu r1, 0x01
	---
	sh r1, F_LCD_PARAM(r58) #
	lliu r1, lcd_delay_len&0xFFFF ; Set delay length
	lui r1, lcd_delay_len>>16
	---
	subi r1, r1, 1
	bne r1, r0, $
	---
	
	; Set display on
	liu r1, 0x29 #
	sh r1, F_LCD_CMD(r58)
	---
	lliu r1, lcd_delay_len&0xFFFF ; Set delay length
	lui r1, lcd_delay_len>>16
	---
	subi r1, r1, 1
	bne r1, r0, $
	---

	; Set column address
	liu r1, 0x2A #
	sh r1, F_LCD_CMD(r58) #
	sh zero, F_LCD_PARAM(r58)
	---
	sh zero, F_LCD_PARAM(r58)
	liu r1, 0x03 #
	sh r1, F_LCD_PARAM(r58)
	---
	liu r1, 0x1F #
	sh r1, F_LCD_PARAM(r58) #
	; Set page address
	liu r1, 0x2B
	---
	sh r1, F_LCD_CMD(r58) #
	sh zero, F_LCD_PARAM(r58) #
	sh zero, F_LCD_PARAM(r58)
	---
	liu r1, 0x01 #
	sh r1, F_LCD_PARAM(r58) #
	liu r1, 0xDF
	---
	sh r1, F_LCD_PARAM(r58) #
	
	jalr zero, r60, 0
	---
	
	; Clears framebuffer with a solid color
	; Args: clear color
	; Returns: none
	; Uses: r1, r2
lcd_clear:
	nop
	---
	lli r1, 1 #
	sw r1, ICEN(r62)
	---
	lliu r1, vram_base&0xFFFF
	lui r1, vram_base>>16
	lliu r2, ((lcd_width*lcd_height)-1)&0xFFFF
	---
	lui r2, ((lcd_width*lcd_height)-1)>>16
	---
lcd_clear_loop:
	sw r16, 0(r1)
	addi r1, r1, 4
	---
	subi r2, r2, 1
	bnez r2, lcd_clear_loop
	---
	sw zero, ICEN(r62) #
	---
	jalr zero, r60, 0
	---

	; Draws a string of text anywhere in the framebuffer
	; Args: str ptr, scale, x pos, y pos, text color, bg color
	; Returns: none
	; Uses: none?
	; r4 - str*
	; r17 - scale
	; r1 - character row counter
	; r8 - vram* (row pointer only)
	; r9 - vram* in loop
	; r3 - vertical scale counter
	; r5 - current char pixels
	; r6 - i (putpixel_outer)
	; r2 - j (putpixel_inner, temp var otherwise)
draw_string:
	subi r61, r61, 40 #
	sw r60, 40(r61) #
	sw r2, 8(r61)
	---
	sw r3, 12(r61) #
	sw r4, 16(r61) #
	sw r5, 20(r61)
	---
	sw r6, 24(r61) #
	sw r7, 28(r61) #
	sw r8, 32(r61)
	---
	sw r11, 4(r61) #
	sw r9, 36(r61)
	slli r18, r18, 2
	---

	liu r11, 0
	muliu r8, r19, lcd_width*4 #
	add r8, r8, r18
	---
	lliu r2, vram_base&0xFFFF
	lui r2, vram_base>>16 #
	add r8, r2, r8
	---
draw_string_line_loop_outer:
	subi r3, r17, 1
	---
draw_string_line_loop_inner:
	cpy r4, r16
	cpy r9, r8
	---
draw_string_char_loop:
	lbu r2, 0(r4) #
	lbu r2, 0(r4)
	---
	addi r4, r4, 1
	bez r2, draw_string_done
	---
	subi r5, r2, ' ' #
	pn p1, r5 #
	liu r2, '?' [p1]
	---
	subi r2, r2, ' ' #
	slli r2, r2, 3
	lliu r5, font&0xFFFF
	---
	lui r5, font>>16 #
	add r2, r2, r11
	---
	add r2, r5, r2 #
	lbu r5, 0(r2) #
	lbu r5, 0(r2)
	---
	;liu r5, 0x55
	;---
	liu r6, character_width-1
	lli r2, 1 #
	sw r2, ICEN(r62)
	---
draw_string_putpixel_outer:
	srli r5, r5, 1
	andi r7, r5, 1
	---
	pez p3, r7
	cpy r7, r20
	---
	cpy r7, r21 [p3]
	subi r2, r17, 1
	---
draw_string_putpixel_inner:
	sw r7, 0(r9)
	addi r9, r9, 4
	---
	subi r2, r2, 1
	bnez r2, draw_string_putpixel_inner
	---
	subi r6, r6, 1
	bnez r6, draw_string_putpixel_outer
	---
	sw zero, ICEN(r62)
	bez zero, draw_string_char_loop
	---
draw_string_done:
	addi r8, r8, lcd_width*4
	subi r3, r3, 1
	bnez r3, draw_string_line_loop_inner
	---
	addi r11, r11, 1 #
	subi r2, r11, 8 #
	bnez r2, draw_string_line_loop_outer
	---

	lw r11, 4(r61) #
	lw r2, 8(r61) #
	lw r3, 12(r61)
	---
	lw r4, 16(r61) #
	lw r5, 20(r61) #
	lw r6, 24(r61)
	---
	lw r7, 28(r61) #
	lw r8, 32(r61) #
	lw r9, 36(r61)
	---
	lw r60, 40(r61) #
	addi r61, r61, 40
	jalr zero, r60, 0
	---

	; Color in r16
	; Uses: r1, r2
leds_constant_color:
	subi r61, r61, 4 #
	sw r60, 4(r61)
	---
	liu r1, 0 #
	sw r1, F_LED(r58)
	liu r2, NUM_LEDS-1
	---
leds_constant_color_loop:
	sw r16, F_LED(r58) #
	subi r2, r2, 1
	bnez r2, leds_constant_color_loop
	---
	lli r1, -1 #
	sw r1, F_LED(r58)
	---
	lw r60, 4(r61) #
	addi r61, r61, 4
	jalr zero, r60, 0
	---

led_pattern_illuminate:
	subi r61, r61, 4 #
	sw r60, 4(r61)
	---
	liu r1, 0 #
	sw r1, F_LED(r58)
	liu r2, NUM_LEDS-1
	---
led_pattern_illuminate_loop:
	andi r1, r2, 1 #
	bez r1, led_ill_opt1
	---
	lliu r1, 0xFFFF
	lui r1, 0xEAFF
	bez zero, led_ill_opt2
	---
led_ill_opt1:
	lliu r1, 0x3DFF
	lui r1, 0xEA11
	---
led_ill_opt2:
	sw r1, F_LED(r58)
	subi r2, r2, 1
	bnez r2, led_pattern_illuminate_loop
	---
	lli r1, -1 #
	sw r1, F_LED(r58)
	---
	lw r60, 4(r61) #
	addi r61, r61, 4
	jalr zero, r60, 0
	---

led_pattern_tholin:
	subi r61, r61, 4 #
	sw r60, 4(r61)
	---
	liu r1, 0 #
	sw r1, F_LED(r58)
	liu r2, NUM_LEDS-1-5
	---
led_pattern_tholin_loop:
	andi r1, r2, 1 #
	bez r1, led_tholin_opt1
	---
	lliu r1, 0x3517
	lui r1, 0xEAFF
	bez zero, led_tholin_opt2
	---
led_tholin_opt1:
	lliu r1, 0xCA75
	lui r1, 0xE5FF
	---
led_tholin_opt2:
	sw r1, F_LED(r58)
	subi r2, r2, 1
	bnez r2, led_pattern_tholin_loop
	---
	lliu r1, 0xFF10
	lui r1, 0xEA40
	---
	sw r1, F_LED(r58)
	---
	sw r1, F_LED(r58)
	---
	sw r1, F_LED(r58)
	---
	sw r1, F_LED(r58)
	---
	sw r1, F_LED(r58)
	---
	lli r1, -1
	---
	sw r1, F_LED(r58)
	---
	lw r60, 4(r61) #
	addi r61, r61, 4
	jalr zero, r60, 0
	---

	; Args: inode ptr, xpos, ypos (note: clips at screen edges)
	; Returns: none
	; Uses: r1, r2, r3, r4, r5, r6
disp_image_raw:
	nop
	---
	subi r61, r61, 800*3+ext4_FIL_s_length+32 #
	---
	sw r47, 800*3+ext4_FIL_s_length+28(r61) #
	sw r46, 800*3+ext4_FIL_s_length+24(r61) #
	sw r45, 800*3+ext4_FIL_s_length+20(r61)
	---
	sw r48, 800*3+ext4_FIL_s_length+32(r61) #
	sw r60, 800*3+ext4_FIL_s_length+16(r61) #
	sw r25, 800*3+ext4_FIL_s_length+12(r61)
	---
	sw r26, 800*3+ext4_FIL_s_length+8(r61) #
	sw r27, 800*3+ext4_FIL_s_length+4(r61) #
	addi r25, r61, 800*3+4 ; ext4_FIL pointer
	---
	cpy r47, r17 ; xpos
	cpy r48, r18 ; ypos
	---
	addi r26, r61, 4 ; image data buffer pointer
	cpy r17, r25
	---
	lipc r60, zero #
	jalr r60, r60, (ext4_open_read-$)>>4
	---
	nop
	---
	bnez r18, disp_image_error
	; Read & parse header
	cpy r16, r25
	cpy r17, r26
	---
	liu r18, 8
	lipc r60, zero #
	jalr r60, r60, (ext4_read-$)>>4
	---
	nop
	---
	bnez r19, disp_image_error
	lui r1, 0x5052
	lliu r1, 0x4843
	---
	lw r2, 0(r26) #
	sub r1, r1, r2 #
	bnez r1, disp_image_error
	---
	lhu r45, 4(r26) # ; Width
	lhu r46, 6(r26) ; Height
	liu r27, 0
	---
disp_image_raw_rows_loop:
	; Exit loop if row below screen
	liu r1, lcd_height #
	bges r48, r1, disp_image_raw_rows_loop_over
	muliu r18, r45, 3 ; Read width*3 bytes
	---
	cpy r16, r25
	cpy r17, r26
	---
	lipc r60, zero #
	jalr r60, r60, (ext4_read-$)>>4
	---
	nop
	---
	bnez r19, disp_image_error
	bn r48, disp_image_raw_cols_loop_over ; Skip this whole row if above screen
	---
	; Push pixels to screen
	slli r17, r47, 2
	muli r18, r48, lcd_width*4 #
	add r2, r17, r18 ; Screen pointer for this row
	---
	lliu r1, vram_base&0xFFFF
	lui r1, vram_base>>16 #
	add r2, r2, r1
	---
	cpy r3, r47
	liu r4, 0
	cpy r5, r26
	---
	lli r1, 1 #
	sw r1, ICEN(r62)
	---
disp_image_raw_cols_loop:
	bn r3, disp_image_raw_cols_loop_continue ; Continue if off of the left side of the screen
	liu r1, lcd_width
	liu r6, 0xFF00
	---
	bge r3, r1, disp_image_raw_cols_loop_over ; Break if off of the right side of the screen
	lbu r1, 2(r5)
	---
	add r6, r6, r1
	---
	lbu r1, 1(r5)
	slli r6, r6, 8
	---
	add r6, r6, r1
	---
	lbu r1, 0(r5)
	slli r6, r6, 8
	---
	add r6, r6, r1
	---
	sw r6, 0(r2)
	---
disp_image_raw_cols_loop_continue:
	addi r2, r2, 4
	addi r3, r3, 1
	addi r4, r4, 1
	---
	addi r5, r5, 3
	bne r4, r45, disp_image_raw_cols_loop
	---
disp_image_raw_cols_loop_over:
	sw zero, ICEN(r62)
	---
	addi r48, r48, 1
	addi r27, r27, 1 #
	bl r27, r46, disp_image_raw_rows_loop
	---
disp_image_raw_rows_loop_over:
disp_image_raw_return:
	lw r47, 800*3+ext4_FIL_s_length+28(r61) #
	lw r46, 800*3+ext4_FIL_s_length+24(r61) #
	lw r45, 800*3+ext4_FIL_s_length+20(r61)
	---
	lw r48, 800*3+ext4_FIL_s_length+32(r61) #
	lw r60, 800*3+ext4_FIL_s_length+16(r61) #
	lw r25, 800*3+ext4_FIL_s_length+12(r61)
	---
	lw r26, 800*3+ext4_FIL_s_length+8(r61) #
	lw r27, 800*3+ext4_FIL_s_length+4(r61) #
	---
	addi r61, r61, 800*3+ext4_FIL_s_length+32
	jalr zero, r60, 0
	---
disp_image_error:
	lui r16, str_failed_to_open_image>>16
	lliu r16, str_failed_to_open_image&0xFFFF
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	bez zero, disp_image_raw_return
	---

	; Args: inode ptr, xpos, ypos (note: clips at screen edges)
	; Returns: none
	; Uses: r1, r2, r3, r4

	; r25 - ext4_FIL*
	; r26 - spare
	; r47 - xpos
	; r48 - ypos
	; r27 - i (rows_loop)
	; r49 - j (cols_loop)

	; r45 - width
	; r46 - height
	; r30 - qoi_pos*
	; r35 - const qoi_buff_end*
	; r34 - const qoi_index*
	; r31 - qoi_run_remaining
	; r32 - qoi_run_px_red
	; r36 - qoi_run_px_green
	; r37 - qoi_run_px_blue
	; r33 - qoi_run_px_alpha
disp_image_qoi:
	nop
	---
	subi r61, r61, 256+ext4_FIL_s_length+68
	---
	sw r49, 256+ext4_FIL_s_length+68(r61) #
	sw r37, 256+ext4_FIL_s_length+64(r61) #
	sw r36, 256+ext4_FIL_s_length+60(r61)
	---
	sw r35, 256+ext4_FIL_s_length+56(r61) #
	sw r34, 256+ext4_FIL_s_length+52(r61) #
	sw r33, 256+ext4_FIL_s_length+48(r61)
	---
	sw r30, 256+ext4_FIL_s_length+44(r61) #
	sw r31, 256+ext4_FIL_s_length+40(r61) #
	sw r32, 256+ext4_FIL_s_length+36(r61)
	---
	sw r48, 256+ext4_FIL_s_length+32(r61) #
	sw r47, 256+ext4_FIL_s_length+28(r61) #
	sw r46, 256+ext4_FIL_s_length+24(r61)
	---
	sw r45, 256+ext4_FIL_s_length+20(r61) #
	sw r60, 256+ext4_FIL_s_length+16(r61) #
	sw r25, 256+ext4_FIL_s_length+12(r61)
	---
	sw r26, 256+ext4_FIL_s_length+8(r61) #
	sw r27, 256+ext4_FIL_s_length+4(r61) #
	addi r25, r61, 4 ; ext4_FIL pointer
	---
	cpy r47, r17 ; xpos
	cpy r48, r18 ; ypos
	addi r34, r61, ext4_FIL_s_length+4 ; qoi_index*
	---
	cpy r17, r25
	---
	lipc r60, zero #
	jalr r60, r60, (ext4_open_read-$)>>4
	---
	nop
	---
	; Read & parse header
	cpy r16, r25
	cpy r17, r34
	---
	liu r18, 14
	lipc r60, zero #
	jalr r60, r60, (ext4_read-$)>>4
	---
	nop
	---
	bnez r19, disp_qoi_error
	lui r1, 0x6669
	lliu r1, 0x6F71
	---
	lw r2, 0(r34) #
	bne r1, r2, disp_qoi_error
	---
	; Get width/height
	lliu r30, qoi_dbuff&0xFFFF ; qoi_pos
	lui r30, qoi_dbuff>>16
	lbu r2, 4(r34)
	---
	sb r2, 3(r30) #
	lbu r2, 5(r34) #
	sb r2, 2(r30)
	---
	lbu r2, 6(r34) #
	sb r2, 1(r30) #
	lbu r2, 7(r34)
	---
	sb r2, 0(r30) #
	lw r45, 0(r30) # ; width
	lbu r2, 8(r34)
	---
	sb r2, 3(r30) #
	lbu r2, 9(r34) #
	sb r2, 2(r30)
	---
	lbu r2, 10(r34) #
	sb r2, 1(r30) #
	lbu r2, 11(r34)
	---
	sb r2, 0(r30) #
	lw r46, 0(r30) # ; height
	---
	lui r35, (qoi_dbuff+256)>>16	; qoi_dbuff
	lliu r35, (qoi_dbuff+256)&0xFFFF
	---
	lli r31, -1 ; qoi_run_remaining
	liu r32, 0 ; qoi_run_px_red
	---
	liu r36, 0 ; qoi_run_px_green
	liu r37, 0 ; qoi_run_px_blue
	liu r33, 0xFF ; qoi_run_px_alpha
	---
	lli r1, 1 #
	sw r1, ICEN(r62)
	---
	cpy r1, r34
	liu r2, 256-4
	---
	lui r3, 0xFF00
	lliu r3, 0
	---
disp_qoi_clear_index_loop:
	sw r3, 0(r1)
	addi r1, r1, 4
	---
	subi r2, r2, 4
	bnez r2, disp_qoi_clear_index_loop
	---
	sw zero, ICEN(r62)
	liu r27, 0
	---
disp_qoi_rows_loop:
	; Read next width amount of pixels and put them on screen
	liu r1, lcd_height #
	bges r48, r1, disp_qoi_return ; Return if below the screen
	bp r31, qoi_buffokay_1
	---
	lipc r60, zero #
	jalr r60, r60, (qoi_fill_buffer-$)>>4
	---
	nop
	---
	xor r31, r31, r31
	---
qoi_buffokay_1:
	liu r49, 0
	---
qoi_pixels_loop:
	bez r31, qoi_not_run
	---
	subi r31, r31, 1
	bez zero, qoi_post_put_index
	---
qoi_not_run:
	bne r30, r35, qoi_buffokay_2
	---
	lipc r60, zero #
	jalr r60, r60, (qoi_fill_buffer-$)>>4
	---
	nop
	---
qoi_buffokay_2:
	lbu r1, 0(r30) #
	addi r30, r30, 1
	---
	subi r2, r1, 0xFE #
	bnez r2, qoi_not_OP_RGB
	---
	lipc r60, zero #
	jalr r60, r60, (qoi_op_rgb-$)>>4
	---
	bez zero, qoi_post_op
	---
qoi_not_OP_RGB:
	subi r2, r1, 0xFF #
	bnez r2, qoi_not_OP_RGBA
	---
	lipc r60, zero #
	jalr r60, r60, (qoi_op_rgb-$)>>4
	---
	bne r30, r35, qoi_buffokay_8
	---
	lipc r60, zero #
	jalr r60, r60, (qoi_fill_buffer-$)>>4
	---
	nop
	---
qoi_buffokay_8:
	addi r30, r30, 1
	bez zero, qoi_post_op
	---
qoi_not_OP_RGBA:
	andi r2, r1, 0xC0 #
	bnez r2, qoi_not_OP_INDEX
	---
	muliu r2, r1, 4 #
	add r2, r2, r34 #
	lbu r37, 0(r2)
	---
	lbu r36, 1(r2) #
	lbu r32, 2(r2)
	bez zero, qoi_post_put_index
	---
qoi_not_OP_INDEX:
	subi r3, r2, 0x40 #
	bnez r3, qoi_not_OP_DIFF
	---
	andi r3, r1, 3
	subi r37, r37, 2 #
	add r37, r37, r3
	---
	srli r3, r1, 2 #
	andi r3, r3, 3
	subi r36, r36, 2
	---
	add r36, r36, r3
	srli r3, r1, 4 #
	andi r3, r3, 3
	---
	subi r32, r32, 2 #
	add r32, r32, r3
	bez zero, qoi_post_op
	---
qoi_not_OP_DIFF:
	subi r3, r2, 0x80 #
	bnez r3, qoi_not_OP_LUMA
	---
	bne r30, r35, qoi_buffokay_7
	---
	lipc r60, zero #
	jalr r60, r60, (qoi_fill_buffer-$)>>4
	---
	nop
	---
qoi_buffokay_7:
	lbu r2, 0(r30) #
	addi r30, r30, 1
	---
	andi r1, r1, 0x3F #
	subi r1, r1, 32 #
	add r36, r36, r1
	---
	subi r1, r1, 8
	andi r3, r2, 0x0F #
	add r3, r3, r1
	---
	add r37, r37, r3
	srli r2, r2, 4 #
	add r2, r2, r1
	---
	add r32, r32, r2
	bez zero, qoi_post_op
	---
qoi_not_OP_LUMA:
	subi r3, r2, 0xC0 #
	bnez r3, qoi_not_OP_RUN
	---
	andi r31, r1, 0x3F
	bez zero, qoi_post_op
	---
qoi_not_OP_RUN:
qoi_post_op:
	andi r32, r32, 0xFF
	andi r36, r36, 0xFF
	andi r37, r37, 0xFF
	---
	; Compute color hash
	muliu r1, r32, 3
	muliu r2, r36, 5
	muliu r3, r37, 7
	---
	add r1, r1, r2
	addi r3, r3, 2805 #
	add r1, r1, r3
	---
	andi r1, r1, 0x3F #
	muli r1, r1, 4 #
	add r1, r1, r34
	---
	sb r33, 3(r1) #
	sb r32, 2(r1)
	---
	sb r36, 1(r1) #
	sb r37, 0(r1)
	---
qoi_post_put_index:
	; Assemble color value into r2
	cpy r2, r37
	slli r1, r36, 8
	slli r4, r32, 16
	---
	slli r3, r33, 24
	add r2, r2, r1
	---
	add r2, r2, r4 #
	add r2, r2, r3
	---
	; Put pixel on screen (if in visible area)
	add r1, r47, r49 ; screen x position
	bn r48, qoi_put_skip ; above screen
	liu r3, lcd_width
	---
	bn r1, qoi_put_skip
	bges r1, r3, qoi_put_skip
	---
	slli r1, r1, 2
	muliu r3, r48, lcd_width*4 #
	add r1, r1, r3
	---
	
	lliu r3, vram_base&0xFFFF
	lui r3, vram_base>>16 #
	add r1, r1, r3
	---
	sw r2, 0(r1)
	---
qoi_put_skip:
	addi r49, r49, 1 #
	bl r49, r45, qoi_pixels_loop
	---
	addi r48, r48, 1
	addi r27, r27, 1 #
	bl r27, r46, disp_qoi_rows_loop
	---
	
	lcd_push

disp_qoi_return:
	lw r49, 256+ext4_FIL_s_length+68(r61) #
	lw r37, 256+ext4_FIL_s_length+64(r61) #
	lw r36, 256+ext4_FIL_s_length+60(r61)
	---
	lw r35, 256+ext4_FIL_s_length+56(r61) #
	lw r34, 256+ext4_FIL_s_length+52(r61) #
	lw r33, 256+ext4_FIL_s_length+48(r61)
	---
	lw r30, 256+ext4_FIL_s_length+44(r61) #
	lw r31, 256+ext4_FIL_s_length+40(r61) #
	lw r32, 256+ext4_FIL_s_length+36(r61)
	---
	lw r48, 256+ext4_FIL_s_length+32(r61) #
	lw r47, 256+ext4_FIL_s_length+28(r61) #
	lw r46, 256+ext4_FIL_s_length+24(r61)
	---
	lw r45, 256+ext4_FIL_s_length+20(r61) #
	lw r60, 256+ext4_FIL_s_length+16(r61) #
	lw r25, 256+ext4_FIL_s_length+12(r61)
	---
	lw r26, 256+ext4_FIL_s_length+8(r61) #
	lw r27, 256+ext4_FIL_s_length+4(r61)
	---
	addi r61, r61, 256+ext4_FIL_s_length+68
	jalr zero, r60, 0
	---
disp_qoi_error:
	lui r16, str_failed_to_open_image>>16
	lliu r16, str_failed_to_open_image&0xFFFF
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	bez zero, disp_qoi_return
	---
	; Backs up ALL regs to be safe!
qoi_fill_buffer:
	subi r61, r61, 40 #
	sw r1, 4(r61) #
	sw r2, 8(r61)
	---
	sw r3, 12(r61) #
	sw r4, 16(r61) #
	sw r5, 20(r61)
	---
	sw r6, 24(r61) #
	sw r7, 28(r61) #
	sw r8, 32(r61)
	---
	sw r60, 36(r61) #
	sw r9, 40(r61)
	---
	lliu r30, qoi_dbuff&0xFFFF ; rewind
	lui r30, qoi_dbuff>>16
	---
	cpy r16, r25
	cpy r17, r30
	---
	
	lw r3, ext4_FIL_position(r25) #
	lw r4, ext4_FIL_limit(r25) #
	sub r18, r4, r3
	---
	liu r4, 256 #
	bl r18, r4, qoi_fill_buffer_cont
	---
	liu r18, 256
	---
qoi_fill_buffer_cont:
	lipc r60, zero #
	jalr r60, r60, (ext4_read-$)>>4
	---
	nop
	---
	lw r1, 4(r61) #
	lw r2, 8(r61) #
	lw r3, 12(r61)
	---
	lw r4, 16(r61) #
	lw r5, 20(r61) #
	lw r6, 24(r61)
	---
	lw r7, 28(r61) #
	lw r8, 32(r61) #
	lw r60, 36(r61)
	---
	lw r9, 40(r61) #
	addi r61, r61, 40
	---
	;bnez r19, disp_qoi_error
	;---
	jalr zero, r60, 0
	---

qoi_op_rgb:
	subi r61, r61, 4 #
	sw r60, 4(r61)
	bne r30, r35, qoi_buffokay_3
	---
	lipc r60, zero #
	jalr r60, r60, (qoi_fill_buffer-$)>>4
	---
	nop
	---
qoi_buffokay_3:
	lbu r32, 0(r30) #
	addi r30, r30, 1 #
	bne r30, r35, qoi_buffokay_4
	---
	lipc r60, zero #
	jalr r60, r60, (qoi_fill_buffer-$)>>4
	---
	nop
	---
qoi_buffokay_4:
	lbu r36, 0(r30) #
	addi r30, r30, 1 #
	bne r30, r35, qoi_buffokay_5
	---
	lipc r60, zero #
	jalr r60, r60, (qoi_fill_buffer-$)>>4
	---
	nop
	---
qoi_buffokay_5:
	lbu r37, 0(r30) #
	addi r30, r30, 1
	---
	
	lw r60, 4(r61) #
	addi r61, r61, 4
	jalr zero, r60, 0
	---

qoi_dbuff:
	dd 0
	org qoi_dbuff+256
font:
	db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
	db 0x04,0x04,0x04,0x04,0x04,0x04,0x00,0x04
	db 0x0a,0x0a,0x0a,0x00,0x00,0x00,0x00,0x00
	db 0x0a,0x0a,0x1f,0x0a,0x0a,0x1f,0x0a,0x0a
	db 0x04,0x1e,0x05,0x05,0x0e,0x14,0x0f,0x04
	db 0x00,0x00,0x12,0x08,0x04,0x02,0x09,0x00
	db 0x06,0x09,0x09,0x09,0x06,0x16,0x09,0x16
	db 0x02,0x02,0x00,0x00,0x00,0x00,0x00,0x00
	db 0x04,0x02,0x01,0x01,0x01,0x01,0x02,0x04
	db 0x04,0x08,0x10,0x10,0x10,0x10,0x08,0x04
	db 0x00,0x04,0x15,0x0e,0x15,0x04,0x00,0x00
	db 0x00,0x04,0x04,0x1f,0x04,0x04,0x00,0x00
	db 0x00,0x00,0x00,0x00,0x00,0x04,0x04,0x04
	db 0x00,0x00,0x00,0x0e,0x00,0x00,0x00,0x00
	db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x04
	db 0x00,0x00,0x10,0x08,0x04,0x02,0x01,0x00
	db 0x0e,0x11,0x19,0x15,0x15,0x13,0x11,0x0e
	db 0x18,0x14,0x10,0x10,0x10,0x10,0x10,0x10
	db 0x0e,0x11,0x10,0x08,0x04,0x02,0x01,0x1f
	db 0x0e,0x11,0x10,0x0e,0x10,0x10,0x11,0x0e
	db 0x18,0x14,0x12,0x11,0x1f,0x10,0x10,0x10
	db 0x1f,0x01,0x01,0x0e,0x10,0x10,0x11,0x0e
	db 0x0e,0x11,0x01,0x0f,0x11,0x11,0x11,0x0e
	db 0x1f,0x10,0x10,0x08,0x04,0x04,0x04,0x04
	db 0x0e,0x11,0x11,0x0e,0x11,0x11,0x11,0x0e
	db 0x0e,0x11,0x11,0x1e,0x10,0x10,0x11,0x0e
	db 0x00,0x04,0x00,0x00,0x00,0x00,0x04,0x00
	db 0x00,0x04,0x00,0x00,0x00,0x00,0x04,0x04
	db 0x00,0x08,0x04,0x02,0x01,0x02,0x04,0x08
	db 0x00,0x00,0x1f,0x00,0x00,0x1f,0x00,0x00
	db 0x00,0x02,0x04,0x08,0x10,0x08,0x04,0x02
	db 0x0e,0x11,0x10,0x08,0x04,0x04,0x00,0x04
	db 0x0e,0x11,0x10,0x10,0x16,0x15,0x15,0x0e
	db 0x0e,0x11,0x11,0x11,0x1f,0x11,0x11,0x11
	db 0x0f,0x11,0x11,0x0f,0x11,0x11,0x11,0x0f
	db 0x0e,0x01,0x01,0x01,0x01,0x01,0x01,0x0e
	db 0x0f,0x11,0x11,0x11,0x11,0x11,0x11,0x0f
	db 0x1f,0x01,0x01,0x1f,0x01,0x01,0x01,0x1f
	db 0x1f,0x01,0x01,0x1f,0x01,0x01,0x01,0x01
	db 0x0e,0x11,0x11,0x01,0x1d,0x11,0x11,0x0e
	db 0x11,0x11,0x11,0x1f,0x11,0x11,0x11,0x11
	db 0x04,0x04,0x04,0x04,0x04,0x04,0x04,0x04
	db 0x08,0x08,0x08,0x08,0x08,0x08,0x0a,0x04
	db 0x11,0x09,0x05,0x03,0x03,0x05,0x09,0x11
	db 0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x0f
	db 0x11,0x1b,0x15,0x11,0x11,0x11,0x11,0x11
	db 0x11,0x11,0x13,0x15,0x19,0x11,0x11,0x11
	db 0x0e,0x11,0x11,0x11,0x11,0x11,0x11,0x0e
	db 0x0f,0x11,0x11,0x0f,0x01,0x01,0x01,0x01
	db 0x0e,0x11,0x11,0x11,0x11,0x15,0x19,0x1e
	db 0x0f,0x11,0x11,0x0f,0x11,0x11,0x11,0x11
	db 0x0e,0x11,0x01,0x0e,0x10,0x10,0x11,0x0e
	db 0x1f,0x04,0x04,0x04,0x04,0x04,0x04,0x04
	db 0x11,0x11,0x11,0x11,0x11,0x11,0x11,0x0e
	db 0x11,0x11,0x11,0x11,0x11,0x11,0x0a,0x04
	db 0x11,0x11,0x11,0x11,0x11,0x15,0x1b,0x11
	db 0x11,0x11,0x11,0x0a,0x04,0x0a,0x11,0x11
	db 0x11,0x11,0x11,0x0a,0x04,0x04,0x04,0x04
	db 0x1f,0x10,0x08,0x04,0x04,0x02,0x01,0x1f
	db 0x0e,0x02,0x02,0x02,0x02,0x02,0x02,0x0e
	db 0x00,0x00,0x01,0x02,0x04,0x08,0x10,0x00
	db 0x0e,0x08,0x08,0x08,0x08,0x08,0x08,0x0e
	db 0x04,0x0a,0x11,0x00,0x00,0x00,0x00,0x00
	db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x1f
	db 0x02,0x04,0x00,0x00,0x00,0x00,0x00,0x00
	db 0x00,0x00,0x00,0x0e,0x10,0x1e,0x11,0x1e
	db 0x01,0x01,0x01,0x01,0x0d,0x13,0x11,0x0f
	db 0x00,0x00,0x00,0x0e,0x01,0x01,0x01,0x0e
	db 0x10,0x10,0x10,0x16,0x19,0x11,0x11,0x1e
	db 0x00,0x00,0x00,0x0e,0x11,0x1f,0x01,0x0e
	db 0x0c,0x12,0x02,0x02,0x07,0x02,0x02,0x02
	db 0x00,0x00,0x00,0x1e,0x11,0x1e,0x10,0x0e
	db 0x00,0x01,0x01,0x01,0x0d,0x13,0x11,0x11
	db 0x00,0x04,0x00,0x06,0x04,0x04,0x04,0x0e
	db 0x00,0x08,0x00,0x0c,0x08,0x08,0x0a,0x04
	db 0x00,0x01,0x01,0x09,0x05,0x03,0x05,0x09
	db 0x00,0x06,0x04,0x04,0x04,0x04,0x04,0x0e
	db 0x00,0x00,0x00,0x00,0x0b,0x15,0x15,0x11
	db 0x00,0x00,0x00,0x0d,0x13,0x11,0x11,0x11
	db 0x00,0x00,0x00,0x0e,0x11,0x11,0x11,0x0e
	db 0x00,0x00,0x00,0x0f,0x11,0x0f,0x01,0x01
	db 0x00,0x00,0x00,0x16,0x19,0x16,0x10,0x10
	db 0x00,0x00,0x00,0x0d,0x13,0x01,0x01,0x01
	db 0x00,0x00,0x00,0x0e,0x01,0x0e,0x10,0x0f
	db 0x00,0x02,0x02,0x07,0x02,0x02,0x12,0x0c
	db 0x00,0x00,0x00,0x11,0x11,0x11,0x19,0x16
	db 0x00,0x00,0x00,0x11,0x11,0x11,0x0a,0x04
	db 0x00,0x00,0x00,0x11,0x11,0x15,0x15,0x0a
	db 0x00,0x00,0x00,0x11,0x0a,0x04,0x0a,0x11
	db 0x00,0x00,0x00,0x11,0x11,0x1e,0x10,0x0e
	db 0x00,0x00,0x00,0x1f,0x08,0x04,0x02,0x1f
	db 0x00,0x04,0x02,0x02,0x01,0x02,0x02,0x04
	db 0x04,0x04,0x04,0x04,0x04,0x04,0x04,0x04
	db 0x00,0x04,0x08,0x08,0x10,0x08,0x08,0x04
	db 0x00,0x00,0x00,0x12,0x15,0x09,0x00,0x00
	ENDSECTION
