idt_base equ 0
gdt_base equ idt_base+256
ram_start equ gdt_base+256 ;Start of usable memory
ram_limit equ 1048576
ram_limit_pages equ ram_limit>>12
rom_base equ 0x80000000
rom_limit equ 262144
rom_limit_pages equ rom_limit>>12

i_div equ idt_base
i_nmi equ (idt_base+2*8)
i_int equ (idt_base+3*8)
i_illegal equ (idt_base+6*8)
i_stackf equ (idt_base+12*8)
i_gp equ (idt_base+13*8)

cpld_base equ ((1 << 13) | (1 << 10) | (1 << 15))
cpld_lcd_cmd equ ((1 << 13) | (1 << 10) | (1 << 15) | (4 << 2))
cpld_lcd_copy equ ((1 << 13) | (1 << 10) | (1 << 15) | (3 << 2))
cpld_ptr equ ((1 << 13) | (1 << 10) | (1 << 15) | (1 << 2))
cpld_pxdata equ ((1 << 13) | (1 << 10) | (1 << 15) | (5 << 2))

ram_segment equ 0x08
stack_segment equ 0x10
rom_segment equ 0x18

cs1fx equ (1 << 10)
cs3fx equ 0
ata_reg_data equ (cs1fx | (0 << 4))
ata_reg_err_feat equ (cs1fx | (1 << 4))
ata_reg_sec_count equ (cs1fx | (2 << 4))
ata_reg_sec_number equ (cs1fx | (3 << 4))
ata_reg_cylinder_low equ (cs1fx | (4 << 4))
ata_reg_cylinder_high equ (cs1fx | (5 << 4))
ata_reg_drv_head equ (cs1fx | (6 << 4))
ata_reg_status_cmd equ (cs1fx | (7 << 4))

ata_reg_altstat_ctrl equ (cs3fx | (6 << 4))
ata_reg_drvaddr equ (cs3fx | (7 << 4))

ata_drv_head_base equ 0b11100000

ata_cmd_diag equ 0x90
ata_cmd_ident equ 0xEC
ata_cmd_read_sec equ 0x21

lcd_cmd_nop equ 0x00
lcd_cmd_soft_reset equ 0x01
lcd_cmd_exit_sleep_mode equ 0x11
lcd_cmd_enter_normal_mode equ 0x13
lcd_cmd_set_display_off equ 0x28
lcd_cmd_set_display_on equ 0x29
lcd_cmd_set_column_address equ 0x2A
lcd_cmd_set_page_address equ 0x2B
lcd_cmd_write_memory_start equ 0x2C
lcd_cmd_set_address_mode equ 0x36
lcd_cmd_set_pixel_data_interface equ 0xF0

; Protected mode entry point after reset
[org 0]
[bits 32]
entrypoint:
	mov ax, ram_segment
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ax, stack_segment
	mov ss, ax
	mov ebp, ram_limit-20
	mov esp, ebp
	push edx ;Still contains processor info
	push ebx
	
	mov dx,cpld_base
	mov eax,20
	out dx,eax

	mov eax,startup_string
	call putstring
		
	mov ebp,i_int
	mov eax,generic_exception_handler
	mov [ebp],ax
	mov word [ebp+2],rom_segment
	mov byte [ebp+4],0
	mov byte [ebp+5],0b10001110
	shr eax,16
	mov word [ebp+6],ax
	
	mov ebp,i_div
	mov eax,i_int
	mov ebx,[eax]
	mov [ebp],ebx
	mov ebx,[eax+4]
	mov [ebp+4],ebx
	
	mov ebp,i_nmi
	mov eax,nmi_exception_handler
	mov [ebp],ax
	mov word [ebp+2],rom_segment
	mov byte [ebp+4],0
	mov byte [ebp+5],0b10001110
	shr eax,16
	mov word [ebp+6],ax
	
	mov ebp,i_illegal
	mov eax,illegal_exception_handler
	mov [ebp],ax
	mov word [ebp+2],rom_segment
	mov byte [ebp+4],0
	mov byte [ebp+5],0b10001110
	shr eax,16
	mov word [ebp+6],ax
	
	mov ebp,i_stackf
	mov eax,stack_exception_handler
	mov [ebp],ax
	mov word [ebp+2],rom_segment
	mov byte [ebp+4],0
	mov byte [ebp+5],0b10001110
	shr eax,16
	mov word [ebp+6],ax
	
	mov ebp,i_gp
	mov eax,gp_exception_handler
	mov [ebp],ax
	mov word [ebp+2],rom_segment
	mov byte [ebp+4],0
	mov byte [ebp+5],0b10001110
	shr eax,16
	mov word [ebp+6],ax

;	mov eax,0xAAAAAAAA
;loop:
;	mov dx,cpld_base
;	out dx,eax
;	push eax
;	mov eax,startup_string
;	call putstring
;	pop eax
;	mov bx,0xFFFF
;delay_loop:
;	nop
;	nop
;	nop
;	nop
;	nop
;	nop
;	nop
;	dec bx
;	jne delay_loop
;	not eax
;	jmp loop

	call lcd_delay
	; PLL multiplier, set PLL clock to 120M
	mov dx,cpld_lcd_cmd
	mov eax,0xE2
	out dx,eax
	mov eax,0x23 | (1 << 23)
	out dx,eax
	mov eax,0x02 | (1 << 23)
	out dx,eax
	mov eax,0x54 | (1 << 23)
	out dx,eax
	; PLL Enable
	mov eax,0xE0
	out dx,eax
	mov eax,0x01 | (1 << 23)
	out dx,eax
	call lcd_delay
	mov eax,0xE0
	out dx,eax
	mov eax,0x03 | (1 << 23)
	out dx,eax
	call lcd_delay
	; software reset
	mov eax,lcd_cmd_soft_reset
	out dx,eax
	call lcd_delay
	; PPL setting for PCLK, depends on resolution
	mov eax,0xE6
	out dx,eax
	mov eax,0x03 | (1 << 23)
	out dx,eax
	mov eax,0x33 | (1 << 23)
	out dx,eax
	mov eax,0x33 | (1 << 23)
	out dx,eax
	; LCD SPECIFICATION
	mov eax,0xB0
	out dx,eax
	mov eax,0x20 | (1 << 23)
	out dx,eax
	mov eax,0x00 | (1 << 23)
	out dx,eax
	mov eax,0x03 | (1 << 23) ; Set HDP 799
	out dx,eax
	mov eax,0x1F | (1 << 23)
	out dx,eax
	mov eax,0x01 | (1 << 23) ; set VDP 479
	out dx,eax
	mov eax,0xDF | (1 << 23)
	out dx,eax
	mov eax,0x00 | (1 << 23)
	out dx,eax
	
	; HSYNC
	mov eax,0xB4
	out dx,eax
	mov eax,0x04 | (1 << 23) ; Set HT 928
	out dx,eax
	mov eax,0x1F | (1 << 23)
	out dx,eax
	mov eax,0x00 | (1 << 23) ; Set HPS 46
	out dx,eax
	mov eax,0xD2 | (1 << 23)
	out dx,eax
	mov eax,0x00 | (1 << 23) ; Set HPW 48
	out dx,eax
	mov eax,0x00 | (1 << 23) ; Set LPS 15
	out dx,eax
	mov eax,0x00 | (1 << 23)
	out dx,eax
	mov eax,0x00 | (1 << 23)
	out dx,eax
	
	; VSYNC
	mov eax,0xB6
	out dx,eax
	mov eax,0x02 | (1 << 23) ; Set VT 525
	out dx,eax
	mov eax,0x0C | (1 << 23)
	out dx,eax
	mov eax,0x00 | (1 << 23) ; Set VPS 16
	out dx,eax
	mov eax,0x22 | (1 << 23)
	out dx,eax
	mov eax,0x00 | (1 << 23) ; Set VPW 16
	out dx,eax
	mov eax,0x00 | (1 << 23) ; Set FPS 8
	out dx,eax
	mov eax,0x00 | (1 << 23)
	out dx,eax
	
	mov eax,0xBA
	out dx,eax
	mov eax,0x01 | (1 << 23)
	out dx,eax
	call lcd_delay
	
	mov eax,0xB8
	out dx,eax
	mov eax,0x0F | (1 << 23)
	out dx,eax
	mov eax,0x01 | (1 << 23)
	out dx,eax
	
	mov eax,lcd_cmd_set_address_mode
	out dx,eax
	mov eax,0x00 | (1 << 23)
	out dx,eax
	
	; Pixel data interface
	mov eax,lcd_cmd_set_pixel_data_interface
	out dx,eax
	mov eax,0x01 | (1 << 23) ; 16-bit packed
	out dx,eax
	call lcd_delay
	
	mov eax,lcd_cmd_set_display_on
	out dx,eax
	call lcd_delay
	
	mov eax,lcd_cmd_set_column_address
	out dx,eax
	mov eax,0x00 | (1 << 23)
	out dx,eax
	nop
	out dx,eax
	mov eax,0x03 | (1 << 23)
	out dx,eax
	mov eax,0x1F | (1 << 23)
	out dx,eax
	mov eax,lcd_cmd_set_page_address
	out dx,eax
	mov eax,0x00 | (1 << 23)
	out dx,eax
	nop
	out dx,eax
	mov eax,0x01 | (1 << 23)
	out dx,eax
	mov eax,0xDF | (1 << 23)
	out dx,eax
	
	mov dx,cpld_ptr
	xor eax,eax
	out dx,eax
	mov ebp,0
logo_copy_outer:
	mov ebx,cs:[ebp+bitmap]
	inc ebp
	mov cl,8
logo_copy_inner:
	mov eax,0xFC7921
	test ebx,128
	jz is_orange
	xor eax,eax
	dec eax
is_orange:
	mov dx,cpld_pxdata
	out dx,eax
	add ebx,ebx
	dec cl
	jnz logo_copy_inner
	cmp ebp,48000
	jne logo_copy_outer
	
	mov dx,cpld_lcd_cmd
	mov eax,lcd_cmd_write_memory_start
	out dx,eax
	mov dx,cpld_lcd_copy
	xor eax,eax
	out dx,eax
	
	call mem_test
	
	mov eax,esp
	call puthex
	call newl

	; ATA software reset
	call ata_busy_wait
	mov dx,ata_reg_altstat_ctrl
	mov eax,6
	out dx,eax
	mov dx,2000
short_del_1:
	dec dx
	jnz short_del_1
	mov dx,ata_reg_altstat_ctrl
	xor eax,eax
	out dx,eax
	call ata_busy_wait
	mov dx,ata_reg_drv_head
	mov eax,ata_drv_head_base
	out dx,eax
	call ata_busy_wait
	
	mov dx,ata_reg_status_cmd
	mov eax,ata_cmd_diag
	out dx,eax
	call ata_busy_wait
	mov dx,ata_reg_err_feat
	in eax,dx
	and al,0x7F
	cmp al,1
	je ata_diag_passed
	mov eax,str_ata_diag_err
	call putstring
	jmp aaaa
ata_diag_passed:
	mov eax,str_diag_passed
	call putstring
aaaa:

	mov dx,ata_reg_status_cmd
	mov eax,ata_cmd_ident
	out dx,eax
	call ata_wait_for_data
	pop ebx
	enter 512,0
	push ebx
	add ebp,512
	mov ebx,0
	mov dx,ata_reg_data
;ata_buff_read_loop:
;	in eax,dx
;	mov [ebx*2+ebp],ax
;	inc ebx
;	cmp ebx,256
;	jne ata_buff_read_loop
	
	cld
	mov ecx,256
	mov edi,ebp
	rep insw
	
	mov eax,str_drive_serial
	call putstring
	mov eax,20
	mov cl,10
serial_print_loop:
	mov bl,[ebp+eax*2+1]
	call putchar
	mov bl,[ebp+eax*2]
	call putchar
	inc eax
	dec cl
	jnz serial_print_loop
	call newl
	
	mov eax,str_drive_model
	call putstring
	mov eax,54
	mov cl,20
model_print_loop:
	mov bl,[ebp+eax+1]
	call putchar
	mov bl,[ebp+eax]
	call putchar
	add eax,2
	dec cl
	jnz model_print_loop
	call newl
	
	mov bl,[ebp+49*2+1]
	test bl,2
	jnz drive_does_support_lba
	mov eax,str_lba_not_supported
	call putstring
	jmp error_halt
drive_does_support_lba:
	
	call ata_busy_wait
	mov eax,1
	mov dx,ata_reg_sec_count
	out dx,eax
	call ata_begin_read
	xor ebx,ebx
	mov dx,ata_reg_data
;ata_buff_read_loop2:
;	in eax,dx
;	mov [ebx*2+ebp],ax
;	inc ebx
;	cmp ebx,256
;	jne ata_buff_read_loop2
	
	cld
	mov ecx,256
	mov edi,ebp
	rep insw
	
	mov eax,[ebp+0]
	cmp eax,0x0621EEBB
	jne header_error
	;Generate new GDT from boot header information
	; Null
	pop ebx ;Address of placeholder second GDT, from all the way back in boot.asm
	mov dword [ebx],0
	mov dword [ebx+4],0
	;Code
	add ebx,8
	mov eax,[ebp+4] ;Code Limit
	mov [ebx],ax
	mov dword [ebx+2],4096
	mov byte [ebx+5],0b10011010
	shr eax,16
	and al,0x0F
	or al,0xC0
	mov [ebx+6],al
	mov byte [ebx+7],0
	;Data + stack (identical)
	add ebx,8
	mov ecx,ram_limit_pages ;Data Limit
	mov eax,[ebp+4] ;Code Limit - now the base for data
	inc eax
	sub ecx,eax
	shl eax,12
	push ecx
	mov [ebx],cx
	mov [ebx+8],cx
	mov [ebx+2],ax
	mov [ebx+2+8],ax
	shr eax,16
	mov [ebx+4],al
	mov [ebx+4+8],al
	mov byte [ebx+5],0b10010010
	mov byte [ebx+5+8],0b10010010
	shr ecx,16
	and cl,0x0F
	or cl,0xC0
	mov [ebx+6],cl
	mov [ebx+6+8],cl
	mov [ebx+7],ah
	mov [ebx+7+8],ah
	;ROM - Not intended to be used anymore after bootload, but you never know
	add ebx,16
	mov word [ebx],rom_limit_pages&0xFFFF
	mov word [ebx+2],rom_base&0xFFFF
	mov byte [ebx+4],(rom_base>>16)&0xFF
	mov byte [ebx+5],0b10011010
	mov byte [ebx+6],((rom_limit_pages>>16)&0xF)|0xC0
	mov byte [ebx+7],(rom_base>>24)&0xFF
	;GDT/IDT Segment
	add ebx,8
	mov word [ebx],4096
	mov dword [ebx+2],0
	mov byte [ebx+5],0b10010010
	mov byte [ebx+6],0x40
	mov byte [ebx+7],0
	;Dynamic code segment
	add ebx,8
	mov eax,[ebp+8] ;Length of static data segment in pages
	add eax,[ebp+4] ;Add start of data segment
	inc eax ;Add GDT segment length - this is now the base for dyn code (in pages)
	mov ecx,ram_limit_pages ;Data Limit
	sub ecx,eax ;Limit for this segment
	shl eax,12 ;Convert base to bytes
	mov [ebx],cx
	mov [ebx+2],ax
	shr eax,16
	mov [ebx+4],al
	mov byte [ebx+5],0b10011010
	shr ecx,16
	and cl,0x0F
	or cl,0xC0
	mov [ebx+6],cl
	mov [ebx+7],ah
	;GDT descriptor
	add ebx,8
	mov word [ebx],47
	mov eax,ebx
	sub eax,56
	mov [ebx+2],eax
	
	pop ecx
	sub ebp,512
	leave
	push eax
	push ebx
	push ecx
	
	mov ecx,1000
smol_delay:
	nop
	nop
	loop smol_delay
	
	;Dump generated GDT
	mov ecx,7
	mov ebp,ebx
	sub ebp,7*8
	mov eax,str_gdt_dump
	call putstring
segment_dump_loop:
	mov al,7
	sub al,cl
	shl al,3
	call puthex_byte
	call newl
	mov al,[ebp+4]
	mov ah,[ebp+7]
	shl eax,16
	mov ax,[ebp+2]
	mov ebx,9
	call putchar
	call puthex
	call newl
	xor eax,eax
	mov al,[ebp+6]
	and al,0x0F
	shl eax,16
	mov ax,[ebp]
	cmp ecx,2
	je dumpseg_byteg
	shl eax,12
dumpseg_byteg:
	mov ebx,9
	call putchar
	call puthex
	call newl
	mov al,[ebp+5]
	mov ebx,9
	call putchar
	call puthex_byte
	call newl
	add ebp,8
	dec ecx
	jnz segment_dump_loop
	call newl
	
	call ata_busy_wait
	mov eax,str_loading
	call putstring
	
	mov edi,4096
	mov eax,2
	push eax
copy_loop_outerer:
	; 256 blocks are now copied from disk into RAM
	mov eax,0
	mov dx,ata_reg_sec_count
	out dx,eax
	mov eax,ss:[esp]
	call ata_begin_read
	mov ecx,0
copy_loop_outer:
	call ata_busy_wait
	call ata_wait_for_data
	mov dx,ata_reg_data
	mov ebx,0
copy_loop_inner:
	in eax,dx
	mov [edi+ebx*2],ax
	inc ebx
	cmp ebx,256
	jne copy_loop_inner
	add edi,512
	
	dec cl
	jnz copy_loop_outer
	
	pop eax
	cmp eax,514
	je copy_done
	add eax,256
	push eax
	jmp copy_loop_outerer
copy_done:

;	mov edi,4096
;	mov esi,chirp+1
;test_loop:
;	mov eax,cs:[esi]
;	add esi,4
;	mov [edi],eax
;	add edi,4
;	cmp edi,4096+16*1024
;	jne test_loop

	mov dx,cpld_base
	mov eax,20
	out dx,eax
	mov eax,str_booting
	call putstring
	pop ecx
	shl ecx,12
	mov ebp,ecx
	sub ebp,20
	pop ebx
	pop eax
	pop dx
	lgdt [ebx]
	mov ebx,eax
	mov ax,0x20
	mov word [i_int+2],ax
	mov word [i_div+2],ax
	mov word [i_nmi+2],ax
	mov word [i_illegal+2],ax
	mov word [i_stackf+2],ax
	mov word [i_gp+2],ax
	jmp 0x08:0

lcd_delay:
	mov eax,0xFFFF
longer_delay:
	nop
	dec eax
	jnz longer_delay
	ret

mem_test_limit equ (ram_limit-128)

;mem_test:
;	mov eax,str_testing_memory
;	call putstring
;	mov edx,0x06216969
;	mov edi,4096
;mem_test_loop:
;	call xorshift
;	and ebp,3
;	cmp ebp,0
;	jne mem_test_not_byte
;	mov eax,edx
;	mov [edi],ah
;	inc edi
;	jmp mem_test_continue
;mem_test_not_byte:
;	cmp ebp,1
;	jne mem_test_not_word
;	mov eax,edx
;	shr eax,16
;	mov [edi],ax
;	inc edi
;	inc edi
;	jmp mem_test_continue
;mem_test_not_word:
;	call xorshift
;	mov [edi],edx
;	add edi,4
;mem_test_continue:
;	cmp edi,mem_test_limit
;	jl mem_test_loop
;mem_test_verify:
;	mov edx,0x06216969
;	mov edi,4096
;mem_verify_loop:
;	call xorshift
;	and ebp,3
;	cmp ebp,0
;	jne mem_verify_not_byte
;	mov eax,edx
;	cmp [edi],ah
;	jne memtest_fail
;	inc edi
;	jmp mem_verify_continue
;mem_verify_not_byte:
;	cmp ebp,1
;	jne mem_verify_not_word
;	mov eax,edx
;	shr eax,16
;	cmp [edi],ax
;	jne memtest_fail
;	inc edi
;	inc edi
;	jmp mem_verify_continue
;mem_verify_not_word:
;	call xorshift
;	cmp [edi],edx
;	jne memtest_fail
;	add edi,4
;mem_verify_continue:
;	cmp edi,mem_test_limit
;	jl mem_verify_loop
;	
;	mov eax,str_test_pass
;	call putstring
;	
;	ret

;mem_test:
;	mov eax,str_testing_memory
;	call putstring
;	mov edx,0x06216969
;	mov edi,mem_test_limit
;mem_test_loop:
;	call xorshift
;	mov [edi],edx
;	sub edi,4
;mem_test_continue:
;	cmp edi,4096
;	jg mem_test_loop
;
;mem_test_verify:
;	mov edx,0x06216969
;	mov edi,mem_test_limit
;mem_verify_loop:
;	call xorshift
;	cmp [edi],edx
;	jne memtest_fail
;	sub edi,4
;mem_verify_continue:
;	cmp edi,4096
;	jg mem_verify_loop
;	
;	mov eax,str_test_pass
;	call putstring
;	
;	ret

mem_test:
	mov eax,str_testing_memory
	call putstring
	mov edx,0x06216969
	mov edi,(mem_test_limit-4096)/4
mem_test_loop:
	push edx
	shl edx,1
	jnc mem_test_no_rs
	or edx,1
mem_test_no_rs:
	dec edi
	jnz mem_test_loop
	mov edi,(mem_test_limit-4096)/4
mem_test_verify:
	shr edx,1
	jnc mem_verify_no_rs
	or edx,0x80000000
mem_verify_no_rs:
	pop eax
	cmp eax,edx
	jne memtest_fail
	dec edi
	jnz mem_test_verify
	mov eax,str_test_pass
	call putstring
	ret

memtest_fail:
	mov eax,str_test_fail
	call putstring
error_halt:
fail_loop:
	lock inc word [4096]
	jmp fail_loop
	
xorshift:
	mov ebp,edx
	shl ebp,13
	xor edx,ebp
	mov ebp,edx
	shr ebp,17
	xor edx,ebp
	mov ebp,edx
	shl ebp,5
	xor edx,ebp
	mov ebp,edx
	ret

;dump:
;	mov ebp,0
;dump_loop:
;	mov al,[ebp]
;	call puthex_byte
;	mov bl,' '
;	call putchar
;	mov eax,ebp
;	inc eax
;	and al,0x0F
;	jnz dump_loop_cont
;	mov bl,10
;	call putchar
;	mov bl,13
;	call putchar
;dump_loop_cont:
;	inc ebp
;	cmp ebp,8*1024
;	jne dump_loop
;	ret

header_error:
	mov eax,str_header_invalid
	call putstring
	jmp error_halt

	; With sec number already in eax
ata_begin_read:
	call ata_busy_wait
	mov dx,ata_reg_sec_number
	out dx,eax
	nop
	mov dx,ata_reg_cylinder_low
	mov al,ah
	out dx,eax
	nop
	mov dx,ata_reg_cylinder_high
	xor eax,eax
	out dx,eax
	nop
	mov dx,ata_reg_drv_head
	mov ax,ata_drv_head_base
	out dx,eax
	nop
	mov dx,ata_reg_status_cmd
	mov ax,ata_cmd_read_sec
	out dx,eax
	nop
	call ata_busy_wait
	mov dx,ata_reg_status_cmd
	in eax,dx
	test al,1
	jnz ata_read_err
	call ata_wait_for_data
	ret

ata_read_err:
	mov eax,str_ata_read_err
	call putstring
	jmp error_halt

ata_busy_wait:
	push eax
	mov dx,ata_reg_status_cmd
ata_busy_wait_loop:
	in eax,dx
	and al,128+64
	xor al,64
	jnz ata_busy_wait_loop
	pop eax
	ret

ata_wait_for_data:
	push eax
	mov dx,ata_reg_status_cmd
ata_wait_for_data_wait_loop:
	in eax,dx
	and al,8+128+64
	xor al,64+8
	jnz ata_wait_for_data_wait_loop
	pop eax
	ret

	; Char in ebx
putchar:
	push edx
	mov dx,cpld_base+(6<<2)
	push eax
uart_busy_wait:
	in eax,dx
	and eax,2
	jnz uart_busy_wait
	mov dx,cpld_base+(7<<2)
	mov eax,ebx
	out dx,eax
	pop eax
	pop edx
	ret

newl:
	push ebx
	mov ebx,13
	call putchar
	mov ebx,10
	call putchar
	pop ebx
	ret

	; Pointer in eax
putstring:
	push ebx
	mov ebx,0
putstring_loop:
	mov bl,cs:[eax]
	test bl,0xFF
	jz putstring_done
	inc eax
	call putchar
	jmp putstring_loop
putstring_done:
	pop ebx
	ret

	; Value in al
puthex_byte:
	push ebx
	push eax
	mov ebx,hexchars
	shr al,4
	and eax,15
	add ebx,eax
	mov ebx,cs:[ebx]
	call putchar
	pop eax
	and eax,15
	mov ebx,hexchars
	add ebx,eax
	mov ebx,cs:[ebx]
	call putchar
	pop ebx
	ret

	; Value in eax
puthex:
	push eax
	shr eax,24
	call puthex_byte
	mov eax,ss:[esp]
	shr eax,16
	call puthex_byte
	mov eax,ss:[esp]
	shr eax,8
	call puthex_byte
	mov eax,ss:[esp]
	call puthex_byte
	pop eax
	ret

generic_exception_handler:
	mov eax,str_generic_exception
chirp_loop:
	mov bl,cs:[eax]
	cmp bl,0
	je chirp_done
	inc eax
	call putchar
	jmp chirp_loop
chirp_done:
	jmp fail_loop

gp_exception_handler:
	mov eax,str_gp_exception
	jmp chirp_loop

illegal_exception_handler:
	mov eax,str_illegal_exception
	jmp chirp_loop

stack_exception_handler:
	mov eax,str_stack_exception
	jmp chirp_loop

nmi_exception_handler:
	pushf
	push eax
	push edx
	mov eax,str_nmi_exception
	call putstring
	mov dx,cpld_base+(7<<2)
	in eax,dx
	mov edx,cpld_base
	mov eax,16
	out dx,eax
	pop edx
	pop eax
	popf
	iret

%macro inline_putchar 0
	mov dx,cpld_base+(6<<2)
%%uart_busy_wait_inline:
	in eax,dx
	and eax,2
	jnz %%uart_busy_wait_inline
	mov dx,cpld_base+(7<<2)
	mov eax,ebx
	out dx,eax
%endmacro

%macro puthex_byte_inline 0
	mov ebx,hexchars
	mov esi,eax
	shr al,4
	and eax,15
	add ebx,eax
	mov ebx,cs:[ebx]
	inline_putchar
	mov eax,esi
	and eax,15
	mov ebx,hexchars
	add ebx,eax
	mov ebx,cs:[ebx]
	inline_putchar
%endmacro

;debug_crash:
;	mov edi,eax
;	shr eax,24
;	puthex_byte_inline
;	mov eax,edi
;	shr eax,16
;	puthex_byte_inline
;	mov eax,edi
;	shr eax,8
;	puthex_byte_inline
;	mov eax,edi
;	puthex_byte_inline
;	jmp fail_loop

hexchars:
	db "0123456789ABCDEF"
startup_string:
	db "Hellorld!",13,10,0
str_ata_diag_err:
	db '[',0x1B,"[1;33mWARNING",0x1B,"[0m] ATA Diag command failed!",13,10,0
str_drive_serial:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] Drive serial: ",0
str_drive_model:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] Drive model: ",0
str_lba_not_supported:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Drive does not support LBA.",13,10,0
str_ata_read_err:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] ATA Block Read Error",13,10,0
str_header_invalid:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Invalid header block",13,10,0
str_generic_exception:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] CPU Exception",13,10,0
str_gp_exception:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] General Protection Exception",13,10,0
str_illegal_exception:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Illegal Instruction Exception",13,10,0
str_stack_exception:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Stack Exception",13,10,0
str_nmi_exception:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Unexpected NMI",13,10,0
str_loading:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] Loading...",13,10,0
str_booting:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] Ready to go!",10,13,0
str_diag_passed:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] ATA Diag passed!",10,13,0
str_gdt_dump:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] GDT dump:",10,13,0
str_testing_memory:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] Testing RAM...",10,13,0
str_test_pass:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] Pass!",10,13,0
str_test_fail:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] RAM test fails!",13,10,0
%include 'bitmap.asm'
chirp:
	db 0xFF
