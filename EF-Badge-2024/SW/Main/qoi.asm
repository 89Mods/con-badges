; image struct organization
qoi_struct_length equ (208+ext4_FIL_s_length+6)
qoi_width equ 0 ;u32
qoi_height equ 4 ;u32
qoi_last_px equ 8 ;u32
qoi_dbuff equ 12 ;u32
qoi_index equ 16 ;192 bytes (3*64)
qoi_fil equ (16+192) ;ext4_FIL_s_length
qoi_pos equ (16+192+ext4_FIL_s_length) ;u8
qoi_run_px equ (16+192+ext4_FIL_s_length+1) ;u32
qoi_run_remaining equ (16+192+ext4_FIL_s_length+5) ;u8

	; inode number in eax
	; QOI struct pointer in edi
qoi_open:
	enter 18,0
	push eax
	push esi
	mov [ebp-18],edi
	add edi,qoi_fil
	call ext4_open_read
	mov esi,edi
	cmp eax,0
	je qoi_open_err
	lea edi,[ebp-14]
	mov eax,14
	call ext4_read
	cmp eax,14
	jne qoi_open_err
	mov esi,edi
	mov edi,[ebp-18]
	; Check magic num
	cmp dword [esi],0x66696F71
	jne qoi_open_err
	; Get width/height
	mov al,[esi+4]
	mov [edi+qoi_width+3],al
	mov al,[esi+5]
	mov [edi+qoi_width+2],al
	mov al,[esi+6]
	mov [edi+qoi_width+1],al
	mov al,[esi+7]
	mov [edi+qoi_width],al
	mov al,[esi+8]
	mov [edi+qoi_height+3],al
	mov al,[esi+9]
	mov [edi+qoi_height+2],al
	mov al,[esi+10]
	mov [edi+qoi_height+1],al
	mov al,[esi+11]
	mov [edi+qoi_height],al
	
	mov byte [edi+qoi_pos],0
	mov byte [edi+qoi_run_remaining],255
	mov dword [esi+qoi_run_px],0
	mov dword [esi+qoi_last_px],0
	
	mov eax,3*64
qoi_open_clr_index:
	mov byte [edi+qoi_index+eax-1],0
	dec eax
	jnz qoi_open_clr_index
	
	pop esi
	pop eax
	leave
	ret
qoi_open_err:
	mov edi,[ebp-18]
	pop esi
	pop eax
	xor eax,eax
	leave
	ret

	; read pixels of an image
	; number of pixels to be read in eax
	; QOI struct pointer in esi
	; pixel array pointer in edi
	; if edi is null, the pixels won’t actually be written
	; so, this can also be used to skip over pixels
qoi_getpixels:
	push ebx
	push ecx
	push edi
	push eax
	push ebp
	push eax
	mov ebp,[esi+qoi_dbuff]
	
	xor edx,edx
	mov dl,[esi+qoi_pos]
	mov ch,[esi+qoi_run_remaining]
	cmp ch,255
	jne qoi_buffokay_1
	call qoi_fill_buffer
	xor ch,ch
qoi_buffokay_1:
	mov ebx,[esi+qoi_run_px]
	
qoi_pixels_loop:
	cmp ch,0
	je qoi_not_run
	dec ch
	jmp qoi_post_put_index
qoi_not_run:
	mov cl,[ebp+edx]
	inc dl
	jnz qoi_buffokay_2
	call qoi_fill_buffer
qoi_buffokay_2:
	xor eax,eax
	mov al,cl
	cmp cl,0xFE
	jne qoi_not_OP_RGB
		call qoi_op_rgb
		jmp qoi_post_op
qoi_not_OP_RGB:
	cmp cl,0xFF
	jne qoi_not_OP_RGBA
		call qoi_op_rgb
		inc dl
		jnz qoi_buffokay_6
		call qoi_fill_buffer
	qoi_buffokay_6:
		jmp qoi_post_op
qoi_not_OP_RGBA:
	mov al,cl
	and al,0xC0
	jnz qoi_not_OP_INDEX
		xor eax,eax
		mov al,cl
		add al,al
		add al,cl
		mov ebx,[esi+qoi_index+eax]
		jmp qoi_post_put_index
qoi_not_OP_INDEX:
	cmp al,0x40
	jne qoi_not_OP_DIFF
		mov al,cl
		and al,3
		sub bl,2
		add bl,al
		mov al,cl
		shr al,2
		and al,3
		sub bh,2
		add bh,al
		xor eax,eax
		mov ah,cl
		shr ah,4
		and ah,3
		sub ebx,0x00020000
		shl eax,8
		add ebx,eax
		jmp qoi_post_op
qoi_not_OP_DIFF:
	cmp al,0x80
	jne qoi_not_OP_LUMA
		mov ch,[ebp+edx]
		inc dl
		jnz qoi_buffokay_7
		call qoi_fill_buffer
	qoi_buffokay_7:
		and cl,0x3F
		sub cl,32
		add bh,cl
		sub cl,8
		mov al,ch
		and al,0x0F
		add al,cl
		add bl,al
		xor eax,eax
		shr ch,4
		add ch,cl
		mov ah,ch
		shl eax,8
		add ebx,eax
		mov ch,0
		jmp qoi_post_op
qoi_not_OP_LUMA:
	cmp al,0xC0
	jne qoi_not_OP_RUN
		and cl,0x3F
		mov ch,cl
		jmp qoi_post_op
qoi_not_OP_RUN:
qoi_post_op:
	; Compute color hash
	mov eax,ebx
	push ecx
	xor eax,eax
	mov al,bl
	mov ecx,eax
	shl eax,3
	sub eax,ecx
	push eax
	xor eax,eax
	mov al,bh
	mov ecx,eax
	shl eax,2
	add eax,ecx
	push eax
	mov eax,ebx
	shr eax,16
	xor ah,ah
	mov ecx,eax
	add eax,eax
	add eax,ecx
	pop ecx
	add eax,ecx
	pop ecx
	add eax,ecx
	add eax,2805
	and eax,0x3F
	; Put pixel in index buffer
	mov ecx,eax
	add eax,eax
	add eax,ecx
	mov ecx,ebx
	mov [esi+qoi_index+eax],cl
	shr ecx,8
	mov [esi+qoi_index+eax+1],cx
	pop ecx
qoi_post_put_index:
	cmp edi,0
	je qoi_dont_put_pixel
	mov eax,ebx
	mov [edi],bl
	shr eax,8
	mov [edi+1],ax
	add edi,3
qoi_dont_put_pixel:
	
	dec dword ss:[esp]
	jnz qoi_pixels_loop
	mov [esi+qoi_pos],dl
	mov [esi+qoi_run_px],ebx
	mov [esi+qoi_run_remaining],ch
	pop eax
	pop ebp
	pop eax
	pop edi
	pop ecx
	pop ebx
	ret
qoi_getpixels_err_ret:
	mov [esi+qoi_pos],dl
	mov [esi+qoi_run_px],ebx
	mov [esi+qoi_run_remaining],ch
	pop eax
	pop ebp
	pop eax
	pop edi
	pop ecx
	pop ebx
	xor eax,eax
	ret

qoi_op_rgb:
	mov bl,[ebp+edx]
	shl ebx,8
	inc dl
	jnz qoi_buffokay_3
	call qoi_fill_buffer
qoi_buffokay_3:
	mov bl,[ebp+edx]
	shl ebx,8
	inc dl
	jnz qoi_buffokay_4
	call qoi_fill_buffer
qoi_buffokay_4:
	mov bl,[ebp+edx]
	inc dl
	jnz qoi_buffokay_5
	call qoi_fill_buffer
qoi_buffokay_5:
	ret

qoi_fill_buffer:
	push esi
	push eax
	push edi
	push edx
	mov edi,[esi+qoi_dbuff]
	add esi,qoi_fil
	mov eax,256
	call ext4_read
	test eax,0x80000000
	pop edx
	pop edi
	pop eax
	pop esi
	jne chirp
	ret
chirp:
	add esp,4
	jmp qoi_getpixels_err_ret
