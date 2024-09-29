code_segment equ 0x08
ram_segment equ 0x10
stack_segment equ 0x18
rom_segment equ 0x20
gdt_segment equ 0x28
dyncode_segment equ 0x30

idt_base equ 0
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

static_base equ 0
proc_info equ static_base
term_cx equ proc_info+1
term_cy equ term_cx+1
term_fg equ term_cy+1
term_bg equ term_fg+4
ext4_firstblock equ term_bg+4
swap_firstblock equ ext4_firstblock+4
ext4_lastblock equ swap_firstblock+4
ext4_length equ ext4_lastblock+4
swap_length equ ext4_length+4
ext4_buff equ (swap_length+4+(4-(swap_length&3)))
ext4_sb_first_datablock equ ext4_buff+4096
ext4_lub equ ext4_sb_first_datablock+4
ext4_sb_inodes_per_group equ ext4_lub+4
ext4_sb_inode_size equ ext4_sb_inodes_per_group+4
ext4_sb_desc_size equ ext4_sb_inode_size+2
ext4_sb_blocks_per_group equ ext4_sb_desc_size+2
ext4_sb_feature_compat equ ext4_sb_blocks_per_group+4
ext4_sb_feature_incompat equ ext4_sb_feature_compat+4
ext4_sb_feature_ro_compat equ ext4_sb_feature_incompat+4
gdt_start_addr equ ext4_sb_feature_ro_compat+4
inode_cache equ gdt_start_addr+4
;Enough for 256 files. Should be enough.
inode_cache_end equ (inode_cache+1024)
ram_limit equ inode_cache_end
uptime equ ram_limit+4
watchdog equ uptime+4
gimg1 equ uptime+8
gdt_backup equ gimg1+qoi_struct_length
gbuff1 equ gdt_backup+512
buffer_space_start equ gbuff1+256

%macro wdtclr 0
	mov dword [watchdog],40
%endmacro

%macro setup_segments 0
	mov ax, ram_segment
	mov ds, ax
	mov es, ax
	;mov ebp, ram_limit - Provided by bootloader
	mov esp, ebp
	mov ax, stack_segment
	mov ss, ax
	mov ax, gdt_segment
	mov gs, ax
	mov ax, code_segment
	mov fs, ax
	mov [ram_limit],ebp
	mov dword [uptime],0
%endmacro

[org 0]
[bits 32]
entrypoint:
	nop
	nop
	jmp entrypoint_actual
funct_table:
	dd putchar
	dd puthex
	dd newl
	dd putstring
	dd ata_begin_read
	dd ata_read_buffer
	dd ata_write_buffer
	dd ata_busy_wait
	dd ata_wait_for_data
	dd ext4_path_parser
	dd ext4_dir_next
	dd ext4_open_dir
	dd ext4_read
	dd ext4_open_read
	dd lcd_push
	dd lcd_clear
	dd draw_string
soft_reset:
	mov ebp,[ram_limit]
	cmp ebp,[ram_limit]
	jne soft_reset
	mov edi,0
	mov esi,gdt_backup
	mov ecx,128
gdt_restore_loop:
	mov eax,[esi]
	add esi,4
	mov gs:[edi],eax
	add edi,4
	loop gdt_restore_loop
	setup_segments
	jmp post_segment_setup
entrypoint_actual:
	setup_segments
	
	and edx,0x0000FFFF
	mov [proc_info],edx ;STILL contains processor info
	mov [gdt_start_addr],ebx
	
	; Set up pointers to exception handlers
	mov ebp,i_int
	mov eax,generic_exception_handler
	mov gs:[ebp],ax
	mov word gs:[ebp+2],code_segment
	mov byte gs:[ebp+4],0
	mov byte gs:[ebp+5],0b10001110
	shr eax,16
	mov word gs:[ebp+6],ax
	
	mov ebp,i_div
	mov eax,i_int
	mov ebx,gs:[eax]
	mov gs:[ebp],ebx
	mov ebx,gs:[eax+4]
	mov gs:[ebp+4],ebx
	
	mov ebp,i_illegal
	mov eax,illegal_exception_handler
	mov gs:[ebp],ax
	mov word gs:[ebp+2],code_segment
	mov byte gs:[ebp+4],0
	mov byte gs:[ebp+5],0b10001110
	shr eax,16
	mov word gs:[ebp+6],ax
	
	mov ebp,i_stackf
	mov eax,stack_exception_handler
	mov gs:[ebp],ax
	mov word gs:[ebp+2],code_segment
	mov byte gs:[ebp+4],0
	mov byte gs:[ebp+5],0b10001110
	shr eax,16
	mov word gs:[ebp+6],ax
	
	mov ebp,i_gp
	mov eax,gp_exception_handler
	mov gs:[ebp],ax
	mov word gs:[ebp+2],code_segment
	mov byte gs:[ebp+4],0
	mov byte gs:[ebp+5],0b10001110
	shr eax,16
	mov word gs:[ebp+6],ax
	
	mov ebp,i_nmi
	mov eax,nmi_handler
	mov gs:[ebp],ax
	mov word gs:[ebp+2],code_segment
	mov byte gs:[ebp+4],0
	mov byte gs:[ebp+5],0b10001110
	shr eax,16
	mov word gs:[ebp+6],ax
	
retry_backup:
	mov esi,0
	mov edi,gdt_backup
	mov ecx,128
gdt_backup_loop:
	mov eax,gs:[esi]
	add esi,4
	mov [edi],eax
	add edi,4
	loop gdt_backup_loop
	
	mov esi,0
	mov edi,gdt_backup
	mov ecx,128
gdt_backup_check_loop:
	mov eax,gs:[esi]
	add esi,4
	cmp [edi],eax
	jne retry_backup
	add edi,4
	loop gdt_backup_check_loop
	
post_segment_setup:
	xor eax,eax
	mov [term_cx],ax
	mov [term_bg],eax
	call lcd_clear
	mov eax,0x00FFFFFF
	mov [term_fg],eax
	
	mov eax,str_version_string
	call putstring
	mov eax,str_version_string
	call term_putstring
	call lcd_push
	
	; Now its safe to enable NMI
	wdtclr
	mov dx,cpld_base+(7<<2)
	in eax,dx
	mov edx,cpld_base
	mov eax,16
	out dx,eax
	mov eax,12
	;out dx,eax
	
	mov ecx,16384
smol_delay1:
	nop
	nop
	loop smol_delay1
	
	mov eax,str_memory_map_1
	call putstring
	mov eax,str_memory_map_1+18
	call term_putinfo
	
	mov ecx,code_segment
mem_map_loop:
	mov eax,str_mem_map_entry_begin
	call term_putstring
	mov eax,str_mem_map_entry_begin
	call putstring
	mov ebp,[gdt_start_addr]
	xor eax,eax
	mov al,gs:[ebp+ecx+6]
	and al,0x0F
	shl eax,16
	mov ax,gs:[ebp+ecx]
	shl eax,12
	xor ebx,ebx
	mov bh,gs:[ebp+ecx+7]
	mov bl,gs:[ebp+ecx+4]
	shl ebx,16
	mov bx,gs:[ebp+ecx+2]
	push eax
	mov eax,ebx
	call term_puthex
	call puthex
	pop eax
	add ebx,eax
	dec ebx
	mov eax,str_separator_1
	call term_putstring
	mov eax,str_separator_1
	call putstring
	mov eax,ebx
	call term_puthex
	call puthex
	mov eax,str_name_code
	cmp ecx,ram_segment
	jne mem_map_not_code
	mov eax,str_name_data
mem_map_not_code:
	cmp ecx,rom_segment
	jne mem_map_not_rom
	mov eax,str_name_rom
mem_map_not_rom:
	cmp ecx,stack_segment
	jne mem_map_not_stack
	mov eax,str_name_stack
mem_map_not_stack:
	push eax
	call putstring
	pop eax
	call term_putstring
	add ecx,0x08
	cmp ecx,rom_segment+0x08
	jne mem_map_loop
	
	call lcd_push
	
	mov ecx,8192
smol_delay2:
	nop
	nop
	nop
	loop smol_delay2
	
	call scan_mbr
	call lcd_push
	cmp dword [ext4_firstblock],1
	je error_halt
	call ext4_mount
	cmp al,0
	je mount_okay
	jmp error_halt
mount_okay:
	mov eax,str_mount_success
	call putstring
	mov eax,str_mount_success+18
	call term_putinfo
	mov eax,str_indexing_files
	call putstring
	mov eax,str_indexing_files+18
	call term_putinfo
	call lcd_push
	
	mov ebx,important_files
	mov ebp,inode_cache
	xor esi,esi
file_get_loop:
	mov eax,ebx
	call putstring
	push ebx
	mov ebx,' '
	call putchar
	mov ebx,ss:[esp]
	mov eax,2
	call ext4_path_parser
	pop ebx
	cmp eax,1
	jne file_get_found
	mov eax,str_file_not_found
	call putstring
	mov eax,2
	inc esi
file_get_found:
	cmp eax,0
	je error_halt
	cmp eax,2
	je file_get_print_skip
	call puthex
	call newl
file_get_print_skip:
	mov [ebp],eax
	add ebp,4
file_get_next_str:
	mov al,cs:[ebx]
	inc ebx
	cmp al,0
	jne file_get_next_str
	cmp byte cs:[ebx],0
	jne file_get_loop
	call newl
	cmp esi,0
	je file_get_all_found
	mov eax,str_some_files_missing
	call term_putwarn
	call lcd_push
file_get_all_found:
	mov eax,str_loading_done
	call putstring
	mov eax,str_loading_done+18
	call term_putinfo
	call lcd_push
	mov ecx,32869
smol_delay3:
	nop
	nop
	nop
	nop
	loop smol_delay3
	
;	mov eax,[inode_cache+4]
;	mov edi,gimg1
;	mov dword [edi+qoi_dbuff],gbuff1
;	call qoi_open
;	mov eax,[gimg1+qoi_width]
;	call puthex
;	call newl
;	mov eax,[gimg1+qoi_height]
;	call puthex
;	call newl
	
;	xor eax,eax
;	call lcd_clear
	
;	enter 800*3,0
;	mov ecx,480
;img_test_loop:
;	mov eax,800
;	lea edi,[ebp-800*3]
;	mov esi,gimg1
;	call qoi_getpixels
	
;	mov ebx,edi
;	mov edi,800
;	mov dx,cpld_pxdata
;img_test_inner_loop:
;	mov eax,[ebx]
;	add ebx,3
;	out dx,eax
;	dec edi
;	jnz img_test_inner_loop

;	loop img_test_loop
;	leave
;	call lcd_push

;	xor eax,eax
;	call lcd_clear

;	enter 800*3,0
;	mov eax,[inode_cache+4]
;	mov edi,gimg1
;	call ext4_open_read
;	mov esi,gimg1
	
;	mov ecx,480
;img_test_loop:
;	mov eax,800*3
;	lea edi,[ebp-800*3]
;	call ext4_read
	
;	mov ebx,edi
;	mov edi,800
;	mov dx,cpld_pxdata
;img_test_inner_loop:
;	mov eax,[ebx]
;	add ebx,3
;	out dx,eax
;	dec edi
;	jnz img_test_inner_loop
;	loop img_test_loop
;	leave
;	call lcd_push
	
;loop:

	mov eax,[proc_info]
	call puthex
	call newl
	call newl
	jmp badge_main

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

error_halt:
	nop
	jmp $

irl_breakpoint:
	lock inc dword [0]
	jmp irl_breakpoint

	; Pointer in eax
putstring:
	push ebx
	mov ebx,0
putstring_loop:
	mov bl,fs:[eax]
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

	; Inode in eax
	; xpos in ebx
	; ypos in ecx
	; Clips at screen edges
disp_image_raw:
	; Bold of me to assume the image will not exceed 800 pixels in width
	enter 800*3+ext4_FIL_s_length+8,0
	push eax
	push ebx
	push ecx
	push esi
	push edi
	; Open file
	lea edi,[ebp-800*3-ext4_FIL_s_length-8]
	call ext4_open_read
	cmp eax,0
	je disp_image_raw_ret
	; Compute initial screen address
	mov eax,lcd_width
	mul ecx
	add eax,ebx
	call lcd_busy_wait
	mov dx,cpld_ptr
	out dx,eax
	mov [ebp-4],eax
	; Read & parse header
	mov esi,edi
	lea edi,[ebp-800*3-8]
	mov eax,8
	call ext4_read
	cmp eax,8
	jne disp_image_raw_ret
	mov eax,[edi]
	cmp eax,0x50524843
	jne disp_image_raw_ret
	mov ax,[edi+4] ; Width
	mov [ebp-6],ax
	mov ax,[edi+6] ; Height
	mov [ebp-8],ax
	
	mov ebx,ss:[esp+8]
disp_image_raw_rows_loop:
	; Exit loop if row below screen
	cmp ebx,lcd_height
	jge disp_image_raw_rows_loop_over
	; Read next row of pixels
	xor eax,eax
	mov ax,[ebp-6] ; Width, dirty mul by 3
	add ax,ax
	add ax,[ebp-6]
	lea esi,[ebp-800*3-ext4_FIL_s_length-8]
	lea edi,[ebp-800*3-8]
	call ext4_read
	; Screw it, no length checking
	test eax,0x80000000
	jnz disp_image_raw_ret
	; Skip this whole row if above screen
	test ebx,0x80000000
	jnz disp_image_raw_cols_loop_over
	; Push pixels to screen
	xor ecx,ecx
	mov cx,[ebp-6]
	mov eax,ecx
	add eax,ss:[esp+12]
	cmp eax,lcd_width
	jle disp_i_r_no_x_overflow
	sub eax,lcd_width
	sub ecx,eax
disp_i_r_no_x_overflow:
	mov dx,cpld_pxdata
	lea esi,[ebp-800*3-8]
disp_image_raw_cols_loop:
	mov eax,[esi]
	out dx,eax
	add esi,3
	loop disp_image_raw_cols_loop
disp_image_raw_cols_loop_over:
	mov eax,[ebp-4]
	add eax,lcd_width
	mov [ebp-4],eax
	mov dx,cpld_ptr
	out dx,eax
	inc ebx
	mov eax,ebx
	sub eax,ss:[esp+8]
	cmp ax,[ebp-8]
	jne disp_image_raw_rows_loop
disp_image_raw_rows_loop_over:
	
disp_image_raw_ret:
	pop edi
	pop esi
	pop ecx
	pop ebx
	pop eax
	leave
	wdtclr
	ret
	
	; Inode in eax
	; xpos in ebx
	; ypos in ecx
	; Clips at screen edges
disp_image_qoi:
	enter 800*3+4,0
	push edi
	push esi
	push eax
	push ebx
	push ecx
	
	mov edi,gimg1
	mov dword [edi+qoi_dbuff],gbuff1
	call qoi_open
	cmp eax,0
	je disp_image_qoi_ret
	
	; Compute initial screen address
	mov eax,lcd_width
	mul ecx
	add eax,ebx
	call lcd_busy_wait
	mov dx,cpld_ptr
	out dx,eax
	mov [ebp-4],eax

	mov ebx,ss:[esp]
disp_image_qoi_rows_loop:
	wdtclr
	; Exit loop if row below screen
	cmp ebx,lcd_height
	jge disp_image_qoi_rows_loop_over
	; Read next row of pixels
	mov eax,[gimg1+qoi_width]
	mov esi,gimg1
	lea edi,[ebp-800*3-4]
	call qoi_getpixels
	cmp eax,0
	je disp_image_qoi_ret
	; Skip this whole row if above screen
	test ebx,0x80000000
	jnz disp_image_qoi_cols_loop_over
	; Push pixels to screen
	mov ecx,[gimg1+qoi_width]
	mov eax,ecx
	add eax,ss:[esp+4]
	cmp eax,lcd_width
	jle disp_i_q_no_x_overflow
	sub eax,lcd_width
	sub ecx,eax
disp_i_q_no_x_overflow:
	mov dx,cpld_pxdata
	lea esi,[ebp-800*3-4]
disp_image_qoi_cols_loop:
	mov eax,[esi]
	out dx,eax
	add esi,3
	loop disp_image_qoi_cols_loop
disp_image_qoi_cols_loop_over:
	mov eax,[ebp-4]
	add eax,lcd_width
	mov [ebp-4],eax
	mov dx,cpld_ptr
	out dx,eax
	inc ebx
	mov eax,ebx
	sub eax,ss:[esp]
	cmp ax,[gimg1+qoi_height]
	jne disp_image_qoi_rows_loop
disp_image_qoi_rows_loop_over:

disp_image_qoi_ret:
	pop ecx
	pop ebx
	pop eax
	pop esi
	pop edi
	leave
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
	jmp soft_reset

gp_exception_handler:
	mov eax,str_gp_exception
	jmp chirp_loop

illegal_exception_handler:
	mov eax,str_illegal_exception
	jmp chirp_loop

stack_exception_handler:
	mov eax,str_stack_exception
	jmp chirp_loop

nmi_handler:
	pushf
	push eax
	push edx
	mov dx,cpld_base+(6<<2)
	in eax,dx
	test eax,1
	jnz uart_rec_char
nmi_timer:
	mov edx,cpld_base
	mov eax,16
	out dx,eax
	lock inc dword [uptime]
	lock dec dword [watchdog]
	cmp dword [watchdog],0
	je watchdog_expired
	pop edx
	pop eax
	popf
	iret

uart_rec_char:
	mov dx,cpld_base+(7<<2)
	in eax,dx
	
	mov dx,cpld_base+(6<<2)
	in eax,dx
	test eax,16
	jnz nmi_timer
	pop edx
	pop eax
	popf
	iret

watchdog_expired:
	mov eax,str_watchdog_timeout
	call putstring
	jmp soft_reset

hexchars:
	db "0123456789ABCDEF"
str_hellorld:
	db "Hellorld!",0
str_version_string:
	db "i386 EF badge, build 2024-09-21 21:33:40+02:00",10,0
str_mount_success:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] FS mounted",10,13,0
str_memory_map_1:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] Memory layout:",10,13,0
	db "    0x00000000 - 0x00000FFF : GDT/IDT",10,0
str_mem_map_entry_begin:
	db "    0x",0
str_separator_1:
	db " - 0x",0
str_name_code:
	db " : CODE",10,0
str_name_data:
	db " : DATA",10,0
str_name_stack:
	db " : STACK",10,0
str_name_rom:
	db " : ROM",10,0
str_indexing_files:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] Indexing files...",10,13,0
str_file_not_found:
	db '[',0x1B,"[1;33mWARNING",0x1B,"[0m] File not found!",13,10,0
str_some_files_missing:
	db "Some files could not be found!",0
str_loading_done:
	db '[',0x1B,"[1;34mINFO",0x1B,"[0m] Setup complete!",10,13,0
important_files:
	; Concatenated list of null-terminated strings of commonly used files
	; End indicated by a zero-length string (double null-terminator)
	db "images/awawi.qoi",0
	db "images/tholin2.qoi",0
	db "images/vrc_logo_raw",0
	db "images/cvr_logo_raw",0
	db "images/resonite_logo.qoi",0
	db "images/tholin3_raw",0
	db "images/tholin4.qoi",0
	db "images/tholin8.qoi",0
	db "images/tholin5_raw",0
	db "images/tholin6_raw",0
	db "images/tholin7_raw",0
	db "images/tholin9_raw",0
	db "images/plernert.qoi",0
	db "images/vrcworld1_raw",0
	db "images/vrcworld2_raw",0
	db "images/tech1.qoi",0
	db "images/tech2.qoi",0
	db "images/chip.qoi",0
	db "images/qrcode_raw",0
	db "models/javali.bin",0
	;db "models/tholin.bin",0
	db 0,0
str_generic_exception:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] CPU Exception",13,10,0
str_gp_exception:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] General Protection Exception",13,10,0
str_illegal_exception:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Illegal Instruction Exception",13,10,0
str_stack_exception:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Stack Exception",13,10,0
str_watchdog_timeout:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Watchdog timeout!",13,10,0
%include 'ata.asm'
%include 'graphics.asm'
%include 'ext4.asm'
%include 'qoi.asm'
%include 'badge_stuff.asm'
%include 'three_dee.asm'
