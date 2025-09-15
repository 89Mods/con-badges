	SECTION badge
	PUBLIC badge_loop
	align 16
	; rainbow pattern on LEDs when showing pride flags
badge_loop:
	lw r16, CHC(r62)
	lipc r60, zero #
	jalr r60, r60, (puthex32_cachef-$)>>4
	---
	nop
	---
	putc ' '
	putc '-'
	putc ' '
	cpy r16, r57
	lipc r60, zero #
	jalr r60, r60, (puthex32_cachef-$)>>4
	---
	nop
	---
	putc 13
	putc 10
	
	lipc r60, zero #
	jalr r60, r60, (slide_show-$)>>4
	---
	nop
	---
	lipc r60, zero #
	jalr r60, r60, (screen_find_me-$)>>4
	---
	nop
	---
	lipc r60, zero #
	jalr r60, r60, (website_link-$)>>4
	---
	nop
	---
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	nop
	---
	lipc r60, zero #
	jalr r60, r60, (portfolio-$)>>4
	---
	nop
	---
	lipc r60, zero #
	jalr r60, r60, (website_link-$)>>4
	---
	nop
	---
	lipc r60, zero #
	jalr r60, r60, (disp_uptime-$)>>4
	---
	nop
	---
	
	bez r0, badge_loop
	---

sync_to_irupt:
	subi r61, r61, 4 #
	sw r60, 4(r61)
	---
	
	cpy r1, r57
	---
	be r1, r57, $
	---
	
	lw r60, 4(r61) #
	addi r61, r61, 4
	jalr zero, r60, 0
	---

slide_show:
	subi r61, r61, 12 #
	sw r40, 8(r61) #
	sw r41, 4(r61)
	---
	sw r60, 12(r61) #
	---
	lliu r40, inode_cache&0xFFFF
	lui r40, inode_cache>>16 #
	---
	lw r16, 0(r40)
	liu r17, 0
	liu r18, 0
	---
	lipc r60, zero #
	jalr r60, r60, (disp_image_raw-$)>>4
	---
	nop
	---
	lipc r60, zero #
	jalr r60, r60, (led_pattern_illuminate-$)>>4
	---
	lcd_push
	lliu r1, slideshow_state&0xFFFF
	lui r1, slideshow_state>>16 #
	lbu r2, 0(r1)
	---
	xori r2, r2, 1 #
	andi r2, r2, 1 #
	sb r2, 0(r1)
	---
	lliu r41, slideshow_order0&0xFFFF
	lui r41, slideshow_order0>>16
	bnez r2, slide_show_loop
	---
	lliu r41, slideshow_order1&0xFFFF
	lui r41, slideshow_order1>>16
	---
slide_show_loop:
	lbu r1, 0(r41) #
	addi r41, r41, 1
	subi r2, r1, 255
	---
	bez r2, slide_show_loop_end
	add r1, r1, r40 #
	lw r16, 0(r1)
	---
	liu r17, 0
	liu r18, 0
	---
	lipc r60, zero #
	jalr r60, r60, (disp_image_raw-$)>>4
	---
	lliu r16, str_my_name&0xFFFF
	lui r16, str_my_name>>16
	liu r17, 6
	---
	liu r18, 8
	liu r19, 8
	lli r20, -1
	---
	lliu r21, 0
	lui r21, 0xFF00
	---
	lipc r60, zero #
	jalr r60, r60, (draw_string-$)>>4
	---
	nop
	---
	lcd_push
	lipc r60, zero #
	jalr r60, r60, (led_pattern_tholin-$)>>4
	---
	bez zero, slide_show_loop
	---
slide_show_loop_end:
	lw r41, 4(r61) #
	lw r40, 8(r61) #
	lw r60, 12(r61)
	---
	addi r61, r61, 12
	jalr zero, r60, 0 #
	nop
	---

screen_find_me:
	subi r61, r61, 8 #
	sw r30, 4(r61) #
	sw r60, 8(r61)
	---
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	nop
	---
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	nop
	---
	lliu r30, inode_cache&0xFFFF
	lui r30, inode_cache>>16
	---
	lliu r16, 0
	lui r16, 0xFF00
	---
	lipc r60, zero #
	jalr r60, r60, (lcd_clear-$)>>4
	---
	lw r16, 8(r30)
	liu r17, 0
	liu r18, 140
	---
	lipc r60, zero #
	jalr r60, r60, (disp_image_raw-$)>>4
	---
	nop
	---
	lcd_push
	lliu r16, 0
	lui r16, 0xE200
	---
	lipc r60, zero #
	jalr r60, r60, (leds_constant_color-$)>>4
	---
	nop
	---
	lw r16, 12(r30)
	liu r17, 400
	liu r18, 0
	---
	lipc r60, zero #
	jalr r60, r60, (disp_image_raw-$)>>4
	---
	nop
	---
	lcd_push
	lw r16, 16(r30)
	liu r17, 450
	liu r18, 190
	---
	lipc r60, zero #
	jalr r60, r60, (disp_image_qoi-$)>>4
	---
	nop
	---
	lliu r16, str_find_me&0xFFFF
	lui r16, str_find_me>>16
	liu r17, 7
	---
	liu r18, 8
	liu r19, 27
	lli r20, -1
	---
	lliu r21, 0
	lui r21, 0xFF00
	---
	lipc r60, zero #
	jalr r60, r60, (draw_string-$)>>4
	---
	nop
	---
	lcd_push
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	lliu r30, 0 ; Set delay length
	lui r30, 0x0001
	---
	subi r30, r30, 1
	bne r30, r0, $
	---
	lw r60, 8(r61)
	---
	lw r30, 4(r61) #
	addi r61, r61, 8
	jalr zero, r60, 0
	---

website_link:
	subi r61, r61, 8 #
	sw r30, 4(r61) #
	sw r60, 8(r61)
	---
	lliu r30, inode_cache&0xFFFF
	lui r30, inode_cache>>16
	---
	lliu r16, 0
	lui r16, 0xFF00
	---
	lipc r60, zero #
	jalr r60, r60, (lcd_clear-$)>>4
	---
	lw r16, 72(r30)
	liu r17, 800-480
	liu r18, 0
	---
	lipc r60, zero #
	jalr r60, r60, (disp_image_qoi-$)>>4
	---
	nop
	---
	lliu r16, str_link&0xFFFF
	lui r16, str_link>>16
	liu r17, 4
	---
	liu r18, 1
	liu r19, 1
	lli r20, -1
	---
	lliu r21, 0
	lui r21, 0xFF00
	---
	lipc r60, zero #
	jalr r60, r60, (draw_string-$)>>4
	---
	nop
	---
	lcd_push
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	lw r60, 8(r61) #
	lw r30, 4(r61) #
	addi r61, r61, 8
	---
	jalr zero, r60, 0
	---

portfolio:
	subi r61, r61, 12 #
	sw r30, 8(r61) #
	sw r31, 4(r61)
	---
	sw r60, 12(r61)
	---
; i_make_vrc_worlds
	lliu r30, inode_cache&0xFFFF
	lui r30, inode_cache>>16
	liu r31, 0
	---
i_make_vrc_worlds_rep:
	lliu r16, 0
	lui r16, 0xFF00
	---
	lipc r60, zero #
	jalr r60, r60, (lcd_clear-$)>>4
	---
	lw r16, 52(r30)
	liu r17, 0
	liu r18, 30
	---
	lipc r60, zero #
	jalr r60, r60, (disp_image_raw-$)>>4
	---
	nop
	---
	lliu r16, str_vr_worlds&0xFFFF
	lui r16, str_vr_worlds>>16
	liu r17, 5
	---
	liu r18, 100
	liu r19, 3
	lli r20, -1
	---
	lliu r21, 0
	lui r21, 0xFF00
	addi r30, r30, 4
	---
	lipc r60, zero #
	jalr r60, r60, (draw_string-$)>>4
	---
	nop
	---
	lcd_push
	ori r31, r31, 1
	bez r31, i_make_vrc_worlds_rep
	---
; i_make_planet_models
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	lliu r30, inode_cache&0xFFFF
	lui r30, inode_cache>>16
	---
	lliu r16, 0
	lui r16, 0xFF00
	---
	lipc r60, zero #
	jalr r60, r60, (lcd_clear-$)>>4
	---
	nop
	---
	
	lw r16, 48(r30)
	liu r17, 225
	liu r18, 100
	---
	lipc r60, zero #
	jalr r60, r60, (disp_image_raw-$)>>4
	---
	nop
	---
	lliu r16, str_planet_models&0xFFFF
	lui r16, str_planet_models>>16
	liu r17, 5
	---
	liu r18, 8
	liu r19, 30
	lli r20, -1
	---
	lliu r21, 0
	lui r21, 0xFF00
	---
	lipc r60, zero #
	jalr r60, r60, (draw_string-$)>>4
	---
	nop
	---
	lcd_push
; i_make_electronics_stuff
	lliu r30, inode_cache&0xFFFF
	lui r30, inode_cache>>16
	liu r31, 0
	---
i_make_electronics_stuffs_rep:
	lliu r16, 0
	lui r16, 0xFF00
	---
	lipc r60, zero #
	jalr r60, r60, (lcd_clear-$)>>4
	---
	nop
	---
	lw r16, 60(r30)
	liu r17, 0
	liu r18, 30
	---
	lipc r60, zero #
	jalr r60, r60, (disp_image_raw-$)>>4
	---
	nop
	---
	lliu r16, str_electronics&0xFFFF
	lui r16, str_electronics>>16
	liu r17, 4
	---
	liu r18, 50
	liu r19, 3
	lli r20, -1
	---
	lliu r21, 0
	lui r21, 0xFF00
	addi r30, r30, 4
	---
	lipc r60, zero #
	jalr r60, r60, (draw_string-$)>>4
	---
	nop
	---
	lcd_push
	addi r31, r31, 1
	bez r31, i_make_electronics_stuffs_rep
	---
; i_make_integrated_circuits
	lliu r16, 0
	lui r16, 0xFF00
	---
	lipc r60, zero #
	jalr r60, r60, (lcd_clear-$)>>4
	---
	nop
	---
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	nop
	---
	lliu r30, inode_cache&0xFFFF
	lui r30, inode_cache>>16
	---
	lw r16, 68(r30)
	cpy r17, zero
	cpy r18, r0
	---
	lipc r60, zero #
	jalr r60, r60, (disp_image_qoi-$)>>4
	---
	nop
	---
	lliu r16, str_chips&0xFFFF
	lui r16, str_chips>>16
	liu r17, 4
	---
	liu r18, 151
	liu r19, 3
	lli r20, -1
	---
	lliu r21, 0
	lui r21, 0xFF00
	addi r30, r30, 4
	---
	lipc r60, zero #
	jalr r60, r60, (draw_string-$)>>4
	---
	nop
	---
	lliu r16, str_chips_here&0xFFFF
	lui r16, str_chips_here>>16
	liu r17, 4
	---
	liu r18, 23
	liu r19, 191
	lli r20, -1
	---
	lliu r21, 0
	lui r21, 0xFF00
	addi r30, r30, 4
	---
	lipc r60, zero #
	jalr r60, r60, (draw_string-$)>>4
	---
	nop
	---
	lcd_push
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	lw r30, 8(r61) #
	lw r31, 4(r61) #
	lw r60, 12(r61)
	---
	addi r61, r61, 12
	jalr zero, r60, 0
	---

led_color_rising equ 1365
led_color_falling equ 2730

disp_uptime:
	subi r61, r61, 16 #
	sw r60, 4(r61) #
	sw r24, 8(r61)
	---
	sw r25, 12(r61) #
	sw r26, 16(r61)
	---
	
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	nop
	---
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	nop
	---
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	nop
	---
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	nop
	---
	lipc r60, zero #
	jalr r60, r60, (sync_to_irupt-$)>>4
	---
	nop
	---
	lliu r16, 0x0000
	lui r16, 0xFF00
	---
	lipc r60, zero #
	jalr r60, r60, (lcd_clear-$)>>4
	---
	nop
	---
	
	liu r24, 4008
	cpy r25, zero
	cpy r26, zero
	---
disp_uptime_loop:
	be r25, r57, disp_uptime_loop_skip
	---
	cpy r25, r57
	---
	lliu r16, str_uptime&0xFFFF
	lui r16, str_uptime>>16
	liu r17, 11
	---
	liu r18, 105
	liu r19, 115
	---
	lliu r20, 0x75FA
	lui r20, 0xFF39
	---
	lliu r21, 0
	lui r21, 0xFF00
	addi r30, r30, 4
	---
	lipc r60, zero #
	jalr r60, r60, (draw_string-$)>>4
	---
	nop
	---
	
	cpy r1, r57
	lliu r2, str_buff&0xFFFF
	lui r2, str_buff>>16
	---
	diviu r3, r1, 3600
	modiu r1, r1, 3600
	---
	diviu r4, r3, 10
	modiu r3, r3, 10
	---
	addi r4, r4, '0'
	addi r3, r3, '0'
	---
	sb r4, 0(r2) #
	sb r3, 1(r2)
	---
	diviu r3, r1, 60
	modiu r1, r1, 60
	---
	diviu r4, r3, 10
	modiu r3, r3, 10
	---
	addi r4, r4, '0'
	addi r3, r3, '0'
	---
	sb r4, 3(r2) #
	liu r4, ':' #
	sb r4, 2(r2)
	---
	sb r3, 4(r2)
	diviu r4, r1, 10
	modiu r3, r1, 10
	---
	addi r4, r4, '0'
	addi r3, r3, '0'
	---
	sb r4, 6(r2) #
	liu r4, ':' #
	sb r4, 5(r2)
	---
	sb r3, 7(r2)
	liu r4, 0 #
	sb r4, 8(r2)
	---
	lliu r16, str_buff&0xFFFF
	lui r16, str_buff>>16
	liu r17, 11
	---
	liu r18, 105
	liu r19, 115+10*11
	---
	lliu r20, 0x75FA
	lui r20, 0xFF39
	---
	lliu r21, 0
	lui r21, 0xFF00
	addi r30, r30, 4
	---
	lipc r60, zero #
	jalr r60, r60, (draw_string-$)>>4
	---
	nop
	---
	lcd_push
disp_uptime_loop_skip:
	liu r1, 0 #
	sw r1, F_LED(r58)
	liu r2, NUM_LEDS-1
	---
	liu r3, 0
	---
disp_uptime_leds_loop:
	add r1, r26, r3
	---
	cpy r11, r1
	lipc r60, zero #
	jalr r60, r60, (led_color_function-$)>>4
	---
	nop
	---
	lui r4, 0xFE00
	lliu r4, 0
	slli r12, r12, 16
	---
	or r4, r12, r4
	addi r11, r1, led_color_rising
	---
	lipc r60, zero #
	jalr r60, r60, (led_color_function-$)>>4
	---
	nop
	---
	slli r12, r12, 8 #
	or r4, r4, r12
	addi r11, r1, led_color_rising*2
	---
	lipc r60, zero #
	jalr r60, r60, (led_color_function-$)>>4
	---
	nop
	---
	or r4, r4, r12 #
	sw r4, F_LED(r58)
	---
	addi r3, r3, 300 ; color shift from led to led
	subi r2, r2, 1
	bnez r2, disp_uptime_leds_loop
	---
	addi r26, r26, 7 # ; color shift over time
	andi r26, r26, 0x0FFF
	---
	lli r1, -1 #
	sw r1, F_LED(r58)
	---
	liu r2, 2000 ; Delay length
	---
	subi r2, r2, 1
	bnez r2, $
	---
	subi r24, r24, 1
	bnez r24, disp_uptime_loop
	---
	lliu r16, 0x0A0A
	lui r16, 0xE20A
	---
	lliu r16, 0x3030
	lui r16, 0xFF30
	---
	lipc r60, zero #
	jalr r60, r60, (lcd_clear-$)>>4
	---
	nop
	---
	lcd_push
	lipc r60, zero #
	jalr r60, r60, (leds_constant_color-$)>>4
	---
	nop
	---
	lw r25, 12(r61) #
	lw r24, 8(r61) #
	lw r60, 4(r61)
	---
	lw r26, 16(r61) #
	addi r61, r61, 16
	jalr zero, r60, 0
	---

	; x-coord in r11
	; res in r12
led_color_function:
	subi r61, r61, 4 #
	sw r60, 4(r61)
	andi r11, r11, 0x0FFF
	---
	xor r12, r12, r12
	liu r10, led_color_falling #
	bge r11, r10, led_color_ret
	---
	liu r10, led_color_rising #
	bl r11, r10, led_color_adjusted
	---
	subi r11, r11, led_color_rising #
	liu r10, led_color_rising #
	sub r11, r10, r11
	---
led_color_adjusted:
	diviu r12, r11, 6
	---
led_color_ret:
	lw r60, 4(r61) #
	addi r61, r61, 4
	jalr zero, r60, 0
	---

slideshow_state:
	db 0
slideshow_order0:
	db 4,24,40,44,255 ; removed 32
slideshow_order1:
	db 4,20,36,28,255
str_find_me:
	db "FIND ME:",0
str_my_name:
	db "Tholin",0
str_planet_models:
	db "I make: Planet Models",0
str_vr_worlds:
	db "I make: VR Worlds",0
str_electronics:
	db "I make: Electronics Stuff",0
str_chips:
	db "I make: IC Layouts",0
str_chips_here:
	db "Custom Silicon!",0
str_link:
	db "tholin.dev/",0
str_uptime_raw:
	db "Uptime raw: ",0
str_sine_cosine_test:
	db "Sine/Cosine test",0
str_uptime:
	db "Uptime: ",0
str_buff:
	db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	ENDSECTION
