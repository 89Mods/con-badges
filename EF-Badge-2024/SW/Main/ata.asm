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

ata_begin_read:
	push edx
	call ata_busy_wait
	mov dx,ata_reg_sec_number
	out dx,eax
	mov dx,ata_reg_cylinder_low
	mov al,ah
	out dx,eax
	mov dx,ata_reg_cylinder_high
	shr eax,16
	out dx,eax
	mov dx,ata_reg_drv_head
	shr eax,8
	or al,ata_drv_head_base
	out dx,eax
	mov dx,ata_reg_status_cmd
	mov ax,ata_cmd_read_sec
	out dx,eax
	call ata_busy_wait
	mov dx,ata_reg_status_cmd
	in eax,dx
	test al,1
	jnz ata_read_err
	call ata_wait_for_data
	pop edx
	ret

ata_read_buffer:
	push ebx
	push eax
	mov dx,ata_reg_data
	xor ebx,ebx
ata_read_buffer_loop:
	in eax,dx
	mov [edi+ebx*2],ax
	inc ebx
	cmp bl,0
	jne ata_read_buffer_loop
	pop eax
	pop ebx
	ret

ata_write_buffer:
	push ebx
	push eax
	mov dx,ata_reg_data
	xor ebx,ebx
ata_write_buffer_loop:
	mov eax,[ebp+ebx*2]
	out dx,eax
	inc ebx
	cmp bl,0
	jne ata_write_buffer_loop
	pop eax
	pop ebx
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
str_ata_read_err:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] ATA Block Read Error",13,10,0
