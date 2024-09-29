badge_main:
	wdtclr
	mov dword [term_bg],0
	mov dword [term_fg],0xffffff
	mov eax,str_uptime_raw
	call putstring
	mov eax,[uptime]
	call puthex
	call newl
	
	call slide_show
	call screen_find_me
	call website_link
	call portfolio
	call website_link
	call disp_uptime
	call demo_sine
	call render_borb
	jmp badge_main

screen_find_me:
	xor eax,eax
	call lcd_clear
	mov eax,[inode_cache+8]
	mov ebx,0
	mov ecx,140
	call disp_image_raw
	mov eax,[inode_cache+12]
	mov ebx,400
	mov ecx,0
	call disp_image_raw
	mov eax,[inode_cache+16]
	mov ebx,450
	mov ecx,190
	call disp_image_qoi
	
	mov eax,str_find_me
	mov bl,7
	mov edx,lcd_width*27+8
	call draw_string
	
	call lcd_push
	
	mov ecx,2000000
del_1:
	lock add dword [gbuff1],5
	nop
	loop del_1
	ret

slide_show:
	mov eax,[inode_cache]
	xor ebx,ebx
	xor ecx,ecx
	call disp_image_qoi
	call lcd_push
	;call slide_show_del
	mov eax,[inode_cache+4]
	xor ebx,ebx
	mov ecx,ebx
	call disp_image_qoi
	call slide_show_push
	call slide_show_del
	mov eax,[inode_cache+20]
	xor ebx,ebx
	mov ecx,ebx
	call disp_image_raw
	call slide_show_push
	;call slide_show_del
	mov eax,[inode_cache+24]
	xor ebx,ebx
	mov ecx,ebx
	call disp_image_qoi
	call slide_show_push
	call slide_show_del
	mov eax,[inode_cache+32]
	xor ebx,ebx
	mov ecx,ebx
	call disp_image_raw
	call slide_show_push
	call slide_show_del
	mov eax,[inode_cache+36]
	xor ebx,ebx
	mov ecx,ebx
	call disp_image_raw
	call slide_show_push
	call slide_show_del
	mov eax,[inode_cache+40]
	xor ebx,ebx
	mov ecx,ebx
	call disp_image_raw
	call slide_show_push
	;call slide_show_del
	mov eax,[inode_cache+28]
	xor ebx,ebx
	mov ecx,ebx
	call disp_image_qoi
	call slide_show_push
	call slide_show_del
	mov eax,[inode_cache+44]
	xor ebx,ebx
	mov ecx,ebx
	call disp_image_raw
	call slide_show_push
	call slide_show_del
	ret

portfolio:
	call i_make_vrc_worlds
	call i_make_planet_models
	call i_make_electronics_stuff
	call i_make_integrated_circuits
	ret

i_make_vrc_worlds:
	mov ecx,52
i_make_vrc_worlds_rep:
	xor eax,eax
	call lcd_clear
	mov eax,[inode_cache+ecx]
	add ecx,4
	push ecx
	mov ebx,0
	mov ecx,30
	call disp_image_raw
	mov eax,str_vr_worlds
	mov bl,5
	mov edx,lcd_width*3+100
	call draw_string
	call lcd_push
	call slide_show_del
	pop ecx
	cmp ecx,60
	jne i_make_vrc_worlds_rep
	ret

i_make_planet_models:
	xor eax,eax
	call lcd_clear
	mov eax,[inode_cache+48]
	mov ebx,225
	mov ecx,100
	call disp_image_qoi
	mov eax,str_planet_models
	mov bl,5
	mov edx,lcd_width*8+30
	call draw_string
	call lcd_push
	mov ecx,2024
del_2:
	add eax,eax
	nop
	loop del_2
	ret

i_make_electronics_stuff:
	mov ecx,60
i_make_electronics_stuff_rep:
	xor eax,eax
	call lcd_clear
	mov eax,[inode_cache+ecx]
	add ecx,4
	push ecx
	mov ebx,0
	mov ecx,30
	call disp_image_qoi
	mov eax,str_electronics
	mov bl,4
	mov edx,lcd_width*3+50
	call draw_string
	call lcd_push
	pop ecx
	cmp ecx,68
	jne i_make_electronics_stuff_rep
	call slide_show_del
	call slide_show_del
	ret

i_make_integrated_circuits:
	mov eax,0x000F0F0F
	call lcd_clear
	mov eax,[inode_cache+68]
	mov ebx,246
	mov ecx,80
	call disp_image_qoi
	mov eax,str_chips
	mov bl,5
	mov edx,lcd_width*3+50
	call draw_string
	call lcd_push
	call slide_show_del
	call slide_show_del
	ret

website_link:
	xor eax,eax
	call lcd_clear
	mov eax,[inode_cache+72]
	mov ebx,800-480
	xor ecx,ecx
	call disp_image_raw
	mov eax,str_link
	mov bl,4
	mov edx,lcd_width*1+1
	call draw_string
	call lcd_push
	call slide_show_del
	call slide_show_del
	call slide_show_del
	wdtclr
	call slide_show_del
	call slide_show_del
	call slide_show_del
	ret

slide_show_del:
	push ecx
	mov ecx,1400000
slide_show_del_loop:
	nop
	nop
	nop
	loop slide_show_del_loop
	pop ecx
	ret

slide_show_push:
	mov eax,str_my_name
	mov bl,4
	mov edx,lcd_width*8+8
	call draw_string
	jmp lcd_push

disp_uptime:
	enter 3*4+9,0
	mov eax,[term_fg]
	push eax
	mov eax,[term_bg]
	push eax
	lea edi,[ebp-3*4-9]
	mov dword [term_bg],0
	mov dword [term_fg],0x3975fa
	
	mov esi,8
disp_uptime_loop:
	xor eax,eax
	call lcd_clear
	mov eax,[uptime]
	shr eax,2
	; Div by 3600 to get hours
	xor edx,edx
	mov ecx,3600
	div ecx
	cmp eax,99
	jle disp_uptime_not_hour_limit
	mov eax,99
disp_uptime_not_hour_limit:
	mov [ebp-4],eax
	; Div remainder by 60 to get minutes
	mov eax,edx
	xor edx,edx
	mov ecx,60
	div ecx
	mov [ebp-8],eax
	; Remainder is seconds
	mov [ebp-12],edx
	
	mov eax,[ebp-4]
	mov cl,10
	div cl
	add al,'0'
	add ah,'0'
	mov [edi],al
	mov [edi+1],ah
	mov byte [edi+2],':'
	mov eax,[ebp-8]
	div cl
	add al,'0'
	add ah,'0'
	mov [edi+3],al
	mov [edi+4],ah
	mov byte [edi+5],':'
	mov eax,[ebp-12]
	div cl
	add al,'0'
	add ah,'0'
	mov [edi+6],al
	mov [edi+7],ah
	mov byte [edi+8],0
	call lcd_busy_wait
	mov ax,fs
	push eax
	mov ax,stack_segment
	mov fs,ax
	mov eax,edi
	mov bl,11
	mov edx,lcd_width*(115+11*(character_height+2))+105
	call draw_string
	pop eax
	mov fs,ax
	
	mov eax,str_uptime
	mov bl,11
	mov edx,lcd_width*115+105
	call draw_string
	call lcd_push
	
	call slide_show_del
	wdtclr
	dec esi
	jnz disp_uptime_loop

	pop eax
	mov [term_bg],eax
	pop eax
	mov [term_fg],eax
	leave
	ret

demo_sine:
	xor eax,eax
	call lcd_clear
	mov eax,str_sine_cosine_test
	mov bl,2
	mov edx,lcd_width*8+380
	call draw_string
	
	xor ebp,ebp
demo_sine_rep:
	mov ecx,lcd_width
	mov ebx,0xFFFF0000
demo_sine_loop:
	mov eax,ebx
	test ebp,1
	jnz demo_sine_cosine
	call sine
	jmp demo_sine_trig_done
demo_sine_cosine:
	call cosine
demo_sine_trig_done:
	add eax,0x00010000
	shr eax,1
	
	cmp eax,0x00010000
	jne demo_sine_not_one
	mov eax,0x0000FFFF
demo_sine_not_one:
	mov edi,0x0000FFFF
	sub edi,eax
	mov eax,lcd_height<<16
	mul edi
	and edx,0x0000FFFF
	mov eax,lcd_width
	mul edx
	mov edi,lcd_width
	sub edi,ecx
	add eax,edi
	call lcd_busy_wait
	mov dx,cpld_ptr
	out dx,eax
	mov dx,cpld_pxdata
	mov eax,0xec28c5
	test ebp,1
	jz demo_sine_ebp_color
	mov eax,0x28eca4
demo_sine_ebp_color:
	out dx,eax
	
	test ecx,15
	jnz demo_sine_no_push
	call lcd_push
demo_sine_no_push:
	add ebx,655
	dec ecx
	jnz demo_sine_loop
	
	inc ebp
	test ebp,1
	jnz demo_sine_rep
	
	call lcd_push
	call slide_show_del
	
	ret

	; x in eax
	; result in eax
sine:
	push ebx
	push ecx
	push edx
	push eax
	
	test eax,0x80000000
	jz sine_not_neg
	not eax
	inc eax
sine_not_neg:
	; Divide by 2pi
	mov ecx,eax
	shr ecx,16
	xor edx,edx
	mov dx,cx
	shl eax,16
	mov ecx,0x0006487F
	div ecx
	shr eax,8
	xor edx,edx
	mov dl,al
	add dl,dl
	and dl,0b01111110
	
	test al,0b01000000
	jz sine_not_inverse
	mov cl,0b01111110
	sub cl,dl
	mov dl,cl
sine_not_inverse:
	cmp dl,0b01111110
	jne sine_not_one
	mov edx,0x00010000
	jmp sine_lut_done
sine_not_one:
	mov dx,cs:[sine_lut+edx]
sine_lut_done:
	test al,0b10000000
	jz sine_not_negative
	not edx
	inc edx
sine_not_negative:
	pop eax
	test eax,0x80000000
	jz sine_not_neg2
	not edx
	inc edx
sine_not_neg2:
	mov eax,edx
	pop edx
	pop ecx
	pop ebx
	ret

	; x in eax
	; result in eax
cosine:
	add eax,0x00019220
	jmp sine

sine_lut:
	db 0x00,0x00
	db 0x61,0x06
	db 0xc2,0x0c
	db 0x21,0x13
	db 0x7d,0x19
	db 0xd4,0x1f
	db 0x27,0x26
	db 0x74,0x2c
	db 0xb9,0x32
	db 0xf7,0x38
	db 0x2b,0x3f
	db 0x55,0x45
	db 0x75,0x4b
	db 0x88,0x51
	db 0x8e,0x57
	db 0x86,0x5d
	db 0x70,0x63
	db 0x4a,0x69
	db 0x13,0x6f
	db 0xca,0x74
	db 0x6e,0x7a
	db 0xff,0x7f
	db 0x7c,0x85
	db 0xe4,0x8a
	db 0x35,0x90
	db 0x70,0x95
	db 0x92,0x9a
	db 0x9d,0x9f
	db 0x8d,0xa4
	db 0x64,0xa9
	db 0x1f,0xae
	db 0xbf,0xb2
	db 0x43,0xb7
	db 0xa9,0xbb
	db 0xf1,0xbf
	db 0x1b,0xc4
	db 0x26,0xc8
	db 0x10,0xcc
	db 0xdb,0xcf
	db 0x84,0xd3
	db 0x0b,0xd7
	db 0x71,0xda
	db 0xb3,0xdd
	db 0xd3,0xe0
	db 0xce,0xe3
	db 0xa5,0xe6
	db 0x58,0xe9
	db 0xe5,0xeb
	db 0x4d,0xee
	db 0x8f,0xf0
	db 0xab,0xf2
	db 0xa0,0xf4
	db 0x6e,0xf6
	db 0x15,0xf8
	db 0x94,0xf9
	db 0xec,0xfa
	db 0x1c,0xfc
	db 0x24,0xfd
	db 0x03,0xfe
	db 0xba,0xfe
	db 0x48,0xff
	db 0xae,0xff
	db 0xeb,0xff

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
str_link:
	db "tholin.dev/",0
str_uptime_raw:
	db "Uptime raw: ",0
str_sine_cosine_test:
	db "Sine/Cosine test",0
str_uptime:
	db "Uptime: ",0
