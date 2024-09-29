CONST_A equ 0x0001AAAB ; width other height of 2D screen (400 / 240)
; For reference: FOV is 35°
CONST_F equ 0x00032BEE ; 1 / tan(phi / 2), where phi is the FOV angle
; For reference: Zfar is 16, Znear is 0.0625
CONST_Q equ 0x00010101 ; Zfar / (Zfar - Znear)
CONST_NEAR_Q equ 0x00001010 ; (Zfar * Znear) / (Zfar - Znear)
CONST_AF equ 0x00054938 ; a * f
;CONST_FRUSTUM_DEPTH_CEIL equ 16
CONST_FRUSTUM_DEPTH_CEIL equ 4

temp_signs equ buffer_space_start
vert_buff equ temp_signs+4
depth_buffer equ vert_buff+128
depth_buffer_size equ 400*240*2 ; About 187.5KiB

test_polygons:
	dd 0x00002000, 0x00000000, 0x00010000
	dd 0xffffdddd, 0x00002000, 0x00010000
	dd 0x00000000, 0xffffdddd, 0x00010000
	dd 0x00000000, 0x00000000, 0x00010000
	dd 0x00000000, 0x00000000, 0x00010000
	dd 0x00000000, 0x0000D051, 0x000094CC
	dd 0xFFFFFF

cube_rotation equ 0

render_test:
	xor eax,eax
	call lcd_clear
	mov esi,vert_buff
	mov ebp,test_polygons
	mov ecx,18
vert_data_copy:
	mov eax,cs:[ebp]
	add ebp,4
	mov [esi],eax
	add esi,4
	loop vert_data_copy
	mov esi,vert_buff
	mov dword [esi+vd_rot],cube_rotation
	mov eax,cs:[ebp]
	mov [esi+vd_color],eax
	mov dword [esi+vd_ld],0x00000000
	mov dword [esi+vd_ld+4],0x00000000
	mov dword [esi+vd_ld+8],0x00010000
	call render_polygon
	
	call lcd_push
	
	call slide_show_del
	ret

javavali_face_count equ 15676
borb_rot equ 0
borb_scale equ 0x00007000
borb_z_offset equ 0x00006000

render_borb:
	xor eax,eax
	call lcd_clear
	call lcd_push
	call clear_depth
	enter ext4_FIL_s_length,0
	mov eax,[inode_cache+76]
	lea edi,[ebp-ext4_FIL_s_length]
	call ext4_open_read
	cmp eax,0
	je render_borb_ret
	
	mov esi,edi
	mov ecx,javavali_face_count
render_borb_loop:
	mov edi,vert_buff
	mov eax,4*3*3*2
	call ext4_read
	test eax,0x80000000
	jnz render_borb_ret
	add edi,4*3*3*2
	mov dword [edi],borb_rot
	add edi,4
	mov eax,4
	call ext4_read
	test eax,0x80000000
	jnz render_borb_ret
	mov dword [edi+4],0x00000000
	mov dword [edi+8],0x00000000
	mov dword [edi+12],0x00010000
	
	push ecx
	push esi
	push edi
	mov esi,vert_buff
	
	; 1
	mov eax,[esi+vd_p1]
	mov ebx,[esi+vd_p1+4]
	mov ecx,[esi+vd_p1+8]
	mov edx,borb_scale
	call scale_vector
	add ecx,borb_z_offset
	mov [esi+vd_p1],eax
	mov [esi+vd_p1+4],ebx
	mov [esi+vd_p1+8],ecx
	; 2
	mov eax,[esi+vd_p2]
	mov ebx,[esi+vd_p2+4]
	mov ecx,[esi+vd_p2+8]
	mov edx,borb_scale
	call scale_vector
	add ecx,borb_z_offset
	mov [esi+vd_p2],eax
	mov [esi+vd_p2+4],ebx
	mov [esi+vd_p2+8],ecx
	; 3
	mov eax,[esi+vd_p3]
	mov ebx,[esi+vd_p3+4]
	mov ecx,[esi+vd_p3+8]
	mov edx,borb_scale
	call scale_vector
	add ecx,borb_z_offset
	mov [esi+vd_p3],eax
	mov [esi+vd_p3+4],ebx
	mov [esi+vd_p3+8],ecx
	
	call render_polygon
	pop edi
	pop esi
	pop ecx
	
	test ecx,0x1F
	jnz render_borb_no_push
	call lcd_push
	
	mov eax,ecx
	call puthex
	call newl
render_borb_no_push:
	dec ecx
	jnz render_borb_loop
	
render_borb_ret:

;	xor eax,eax
;	mov dx,cpld_ptr
;	out dx,eax
;	mov bx,240
;	mov esi,depth_buffer
;	mov edi,0
;show_depth_loop_outer:
;	mov cx,400
;show_depth_loop_inner:
;	mov ah,[esi+1]
;	mov al,ah
;	shl eax,8
;	mov al,ah
;	add esi,2
;	mov dx,cpld_pxdata
;	out dx,eax
;	dec cx
;	jnz show_depth_loop_inner
;	add edi,lcd_width
;	mov dx,cpld_ptr
;	mov eax,edi
;	out dx,eax
;	dec bx
;	jnz show_depth_loop_outer
;	call lcd_push

	call lcd_push
	call slide_show_del
	call slide_show_del
	leave
	ret

	; Pointer to vertex data in esi
	; Vertex data as:
	;	- x1,y1,z1	(16.16 fixed-point each)
	;	- x2,y2,z2
	;	- x3,y3,z3
	;	- nx1,ny1,nz1	(16.16 fixed-point each, but must be normalized)
	;	- nx2,ny2,nz2
	;	- nx3,ny3,nz3
	;	- rot		(16.16 fixed-point)
	;	- color		(RGB padded to 32-bits)
	;	- ldx,ldy,ldz	(light direction, 16.16 fixed-point each, but must be normalized)
	vd_p1 equ 0
	vd_p2 equ 12
	vd_p3 equ 24
	vd_n1 equ 36
	vd_n2 equ 48
	vd_n3 equ 60
	vd_rot equ 72
	vd_color equ 76
	vd_ld equ 80
	
	; Stackframe values
	s_sine_theta equ 4
	s_neg_sine_theta equ 8
	s_cosine_theta equ 12
	s_clip_3 equ 24
	s_clip_2 equ 36
	s_clip_1 equ 48
	s_screenspace_3 equ 56
	s_screenspace_2 equ 64
	s_screenspace_1 equ 72
	s_screenaddr equ 76
	s_depthaddr equ 80
	s_minx equ 82
	s_maxx equ 84
	s_miny equ 86
	s_maxy equ 88
	s_curraddr equ 92
	s_edge_12 equ 96
	s_edge_23 equ 100
	s_edge_31 equ 104
	s_backup1 equ 108
	s_backup2 equ 112
	s_total_area equ 116
	s_final_normal equ 128
	s_final_depth equ 132
	s_curr_depth_addr equ 136
	s_dx1 equ 142
	s_dx2 equ 144
render_polygon:
	enter 144,0
	
	mov eax,[esi+vd_rot]
	call sine
	mov [ebp-s_sine_theta],eax
	not eax
	inc eax
	mov [ebp-s_neg_sine_theta],eax
	mov eax,[esi+vd_rot]
	call cosine
	mov [ebp-s_cosine_theta],eax
	
	mov ebx,[esi+vd_n1]
	mov ecx,[esi+vd_n1+8]
	call rotate_vector_y
	mov [esi+vd_n1],ebx
	mov [esi+vd_n1+8],ecx
	test ecx,0x80000000
	jnz skip_triangle
	
	mov edi,0
triangle_loop:
	;mov eax,[esi+vd_p1+edi]
	;call puthex
	;call newl
	;mov eax,[esi+vd_p1+edi+8]
	;call puthex
	;call newl

	mov ebx,[esi+vd_p1+edi]
	mov ecx,[esi+vd_p1+edi+8]
	call rotate_vector_y
	mov [esi+vd_p1+edi],ebx
	mov [esi+vd_p1+edi+8],ecx
	
	;mov eax,[esi+vd_p1+edi]
	;call puthex
	;mov ebx,','
	;call putchar
	;mov eax,[esi+vd_p1+edi+4]
	;call puthex
	;mov ebx,','
	;call putchar
	;mov eax,[esi+vd_p1+edi+8]
	;call puthex
	;call newl
	
	mov eax,[esi+vd_p1+edi]
	mov ebx,[esi+vd_p1+edi+4]
	mov ecx,[esi+vd_p1+edi+8]
	call project_point
	mov [ebp-s_clip_1+edi],eax
	mov [ebp-s_clip_1+edi+4],ebx
	mov [ebp-s_clip_1+edi+8],ecx
	test ecx,0x80000000
	jnz skip_triangle
	cmp ecx,CONST_FRUSTUM_DEPTH_CEIL<<16
	jge skip_triangle
	
	call cam_point_to_screenspace
	mov edx,[ebp-s_screenspace_2]
	mov [ebp-s_screenspace_1],edx
	mov edx,[ebp-s_screenspace_2+4]
	mov [ebp-s_screenspace_1+4],edx
	mov edx,[ebp-s_screenspace_3]
	mov [ebp-s_screenspace_2],edx
	mov edx,[ebp-s_screenspace_3+4]
	mov [ebp-s_screenspace_2+4],edx
	mov [ebp-s_screenspace_3],eax
	mov [ebp-s_screenspace_3+4],ebx
	
	;mov eax,[ebp-s_screenspace_3]
	;call puthex
	;mov ebx,','
	;call putchar
	;mov eax,[ebp-s_screenspace_3+4]
	;call puthex
	;call newl
	
	;mov edx,[ebp-s_screenspace_3+4]
	;add edx,edx
	;mov eax,lcd_width
	;mul edx
	;mov ecx,[ebp-s_screenspace_3]
	;add eax,ecx
	;add eax,ecx
	;mov edx,cpld_ptr
	;out dx,eax
	;mov eax,0xFFFFFF
	;mov edx,cpld_pxdata
	;out dx,eax
	
	add edi,12
	cmp edi,36
	jne triangle_loop
	
	; Smallest X
	mov dx,[ebp-s_screenspace_3]
	cmp [ebp-s_screenspace_2],dx
	jge not_smallest_1
	mov dx,[ebp-s_screenspace_2]
not_smallest_1:
	cmp [ebp-s_screenspace_1],dx
	jge not_smallest_2
	mov dx,[ebp-s_screenspace_1]
not_smallest_2:
	mov [ebp-s_minx],dx
	
	; Largest X
	mov dx,[ebp-s_screenspace_3]
	cmp [ebp-s_screenspace_2],dx
	jle not_largest_1
	mov dx,[ebp-s_screenspace_2]
not_largest_1:
	cmp [ebp-s_screenspace_1],dx
	jle not_largest_2
	mov dx,[ebp-s_screenspace_1]
not_largest_2:
	mov [ebp-s_maxx],dx
	
	; Smallest Y
	mov dx,[ebp-s_screenspace_3+4]
	cmp [ebp-s_screenspace_2+4],dx
	jge not_smallest_3
	mov dx,[ebp-s_screenspace_2+4]
not_smallest_3:
	cmp [ebp-s_screenspace_1+4],dx
	jge not_smallest_4
	mov dx,[ebp-s_screenspace_1+4]
not_smallest_4:
	mov [ebp-s_miny],dx
	
	; Largest Y
	mov dx,[ebp-s_screenspace_3+4]
	cmp [ebp-s_screenspace_2+4],dx
	jle not_largest_3
	mov dx,[ebp-s_screenspace_2+4]
not_largest_3:
	cmp [ebp-s_screenspace_1+4],dx
	jle not_largest_4
	mov dx,[ebp-s_screenspace_1+4]
not_largest_4:
	mov [ebp-s_maxy],dx
	
	cmp word [ebp-s_maxy],240
	jge maxy_zero
	inc word [ebp-s_maxy]
maxy_zero:
	cmp word [ebp-s_maxx],400
	jge maxx_zero
	inc word [ebp-s_maxx]
maxx_zero:
	cmp word [ebp-s_miny],0
	je miny_zero
	dec word [ebp-s_miny]
miny_zero:
	cmp word [ebp-s_minx],0
	je minx_zero
	dec word [ebp-s_minx]
minx_zero:
	
	xor eax,eax
	mov ax,[ebp-s_miny]
	mov ecx,lcd_width
	add eax,eax
	mul ecx
	xor ecx,ecx
	mov cx,[ebp-s_minx]
	add eax,ecx
	add eax,ecx
	mov [ebp-s_screenaddr],eax
	xor eax,eax
	mov ax,[ebp-s_miny]
	mov ecx,400*2
	mul ecx
	xor ecx,ecx
	mov cx,[ebp-s_minx]
	add eax,ecx
	add eax,ecx
	mov [ebp-s_depthaddr],eax
	
	;push esi
	;push edi
	;mov eax,[ebp-s_clip_3]
	;mov ebx,[ebp-s_clip_3+4]
	;mov ecx,[ebp-s_clip_1]
	;mov edx,[ebp-s_clip_1+4]
	;mov esi,[ebp-s_clip_2]
	;mov edi,[ebp-s_clip_2+4]
	;call edge_function_no_norm
	;pop edi
	;pop esi
	;mov [ebp-s_total_area],eax
	;not eax
	;inc eax
	;cmp eax,0
	;jle skip_triangle
	;test eax,0x80000000
	;jnz skip_triangle
	
	mov dx,[ebp-s_miny]
shading_rows_loop:
	mov [ebp-s_dx1],dx
	mov eax,[ebp-s_screenaddr]
	mov [ebp-s_curraddr],eax
	mov eax,[ebp-s_depthaddr]
	mov [ebp-s_curr_depth_addr],eax

	mov dx,[ebp-s_minx]
shading_cols_loop:
	mov [ebp-s_dx2],dx
	
	mov [ebp-s_backup1],esi
	mov [ebp-s_backup2],edi
	
	; Unrolled loop here
	
	; 1
	xor eax,eax
	mov ax,dx
	xor ebx,ebx
	mov bx,ss:[esp+2]
	shl eax,16
	shl ebx,16
	mov ecx,[ebp-s_clip_2]
	mov edx,[ebp-s_clip_2+4]
	mov esi,[ebp-s_clip_3]
	mov edi,[ebp-s_clip_3+4]
	call edge_function
	mov esi,[ebp-s_backup1]
	mov edi,[ebp-s_backup2]
	test eax,0x80000000
	jz discard_fragment
	not eax
	inc eax
	mov [ebp-s_edge_12],eax
	
	; 2
	xor eax,eax
	mov ax,ss:[esp]
	xor ebx,ebx
	mov bx,ss:[esp+2]
	shl eax,16
	shl ebx,16
	mov ecx,[ebp-s_clip_3]
	mov edx,[ebp-s_clip_3+4]
	mov esi,[ebp-s_clip_1]
	mov edi,[ebp-s_clip_1+4]
	call edge_function
	mov esi,[ebp-s_backup1]
	mov edi,[ebp-s_backup2]
	test eax,0x80000000
	jz discard_fragment
	not eax
	inc eax
	mov [ebp-s_edge_23],eax
	
	; 3
	xor eax,eax
	mov ax,ss:[esp]
	xor ebx,ebx
	mov bx,ss:[esp+2]
	shl eax,16
	shl ebx,16
	mov ecx,[ebp-s_clip_1]
	mov edx,[ebp-s_clip_1+4]
	mov esi,[ebp-s_clip_2]
	mov edi,[ebp-s_clip_2+4]
	call edge_function
	mov esi,[ebp-s_backup1]
	mov edi,[ebp-s_backup2]
	test eax,0x80000000
	jz discard_fragment
	not eax
	inc eax
	mov [ebp-s_edge_31],eax
	
	; Compute total area by summing component areas
	mov eax,[ebp-s_edge_12]
	add eax,[ebp-s_edge_23]
	add eax,[ebp-s_edge_31]
	mov [ebp-s_total_area],eax
	cmp eax,0
	je discard_fragment
	
	; Fragment will be rendered
	; Divide s_edge values by total area
	; 1
	mov eax,[ebp-s_edge_12]
	rol eax,16
	mov dx,ax
	and edx,0x0000FFFF
	and eax,0xFFFF0000
	div dword [ebp-s_total_area]
	mov [ebp-s_edge_12],eax
	; 2
	mov eax,[ebp-s_edge_23]
	rol eax,16
	mov dx,ax
	and edx,0x0000FFFF
	and eax,0xFFFF0000
	div dword [ebp-s_total_area]
	mov [ebp-s_edge_23],eax
	; 3
	mov eax,[ebp-s_edge_31]
	rol eax,16
	mov dx,ax
	and edx,0x0000FFFF
	and eax,0xFFFF0000
	div dword [ebp-s_total_area]
	mov [ebp-s_edge_31],eax
	
	; Compute vertex depth
	; s_clip3.z * s_edge_31 + s_clip2.z * s_edge_23 + s_clip1.z * s_edge_12
	; Code earlier assures all values are positive
	; 1
	mov eax,[ebp-s_clip_3+8]
	mov edx,[ebp-s_edge_31]
	mul edx
	mov ax,dx
	ror eax,16
	push eax
	; 2
	mov eax,[ebp-s_clip_2+8]
	mov edx,[ebp-s_edge_23]
	mul edx
	mov ax,dx
	ror eax,16
	add ss:[esp],eax
	; 3
	mov eax,[ebp-s_clip_1+8]
	mov edx,[ebp-s_edge_12]
	mul edx
	mov ax,dx
	ror eax,16
	add ss:[esp],eax
	pop eax
	
	; Divide by frustum depth to normalize
	; Code earlier assures the result of this will be < 1
	mov ecx,CONST_FRUSTUM_DEPTH_CEIL<<16
	rol eax,16
	mov dx,ax
	and eax,0xFFFF0000
	and edx,0x0000FFFF
	div ecx
	mov [ebp-s_final_depth],eax
	
	; Compare to depth buffer
	mov edx,[ebp-s_curr_depth_addr]
	cmp ax,[depth_buffer+edx]
	jl discard_fragment
	
	; Write to depth buffer
	mov [depth_buffer+edx],ax
	
	; Compute final normal
	; vd_n3 * s_edge_31 + vd_n2 * s_edge_23 + vd_n1 * s_edge_12
	; 1
	mov eax,[esi+vd_n3]
	mov ebx,[esi+vd_n3+4]
	mov ecx,[esi+vd_n3+8]
	mov edx,[ebp-s_edge_31]
	call scale_vector
	mov [ebp-s_final_normal],eax
	mov [ebp-s_final_normal+4],ebx
	mov [ebp-s_final_normal+8],ecx
	; 2
	mov eax,[esi+vd_n2]
	mov ebx,[esi+vd_n2+4]
	mov ecx,[esi+vd_n2+8]
	mov edx,[ebp-s_edge_23]
	call scale_vector
	add [ebp-s_final_normal],eax
	add [ebp-s_final_normal+4],ebx
	add [ebp-s_final_normal+8],ecx
	; 3
	mov eax,[esi+vd_n1]
	mov ebx,[esi+vd_n1+4]
	mov ecx,[esi+vd_n1+8]
	mov edx,[ebp-s_edge_12]
	call scale_vector
	add [ebp-s_final_normal],eax
	add [ebp-s_final_normal+4],ebx
	add [ebp-s_final_normal+8],ecx
	
	; Lighting dot-product between final normal and light dir
	; 1
	mov byte [temp_signs],0
	mov eax,[ebp-s_final_normal]
	mov edx,[esi+vd_ld]
	test eax,0x80000000
	jz lmul_not_neg_1
	lock inc byte [temp_signs]
	not eax
	inc eax
lmul_not_neg_1:
	test edx,0x80000000
	jz lmul_not_neg_2
	lock inc byte [temp_signs]
	not edx
	inc edx
lmul_not_neg_2:
	mul edx
	test byte [temp_signs],1
	jz lmul_not_neg_3
	not eax
	not edx
	add eax,1
	adc edx,0
lmul_not_neg_3:
	mov ax,dx
	ror eax,16
	push eax
	; 2
	mov byte [temp_signs],0
	mov eax,[ebp-s_final_normal+4]
	mov edx,[esi+vd_ld+4]
	test eax,0x80000000
	jz lmul_not_neg_4
	not eax
	inc eax
	lock inc byte [temp_signs]
lmul_not_neg_4:
	test edx,0x80000000
	jz lmul_not_neg_5
	not edx
	lock inc byte [temp_signs]
	inc edx
lmul_not_neg_5:
	mul edx
	test byte [temp_signs],1
	jz lmul_not_neg_6
	not eax
	not edx
	add eax,1
	adc edx,0
lmul_not_neg_6:
	mov ax,dx
	ror eax,16
	add ss:[esp],eax
	; 3
	mov byte [temp_signs],0
	mov eax,[ebp-s_final_normal+8]
	mov edx,[esi+vd_ld+8]
	test eax,0x80000000
	jz lmul_not_neg_7
	not eax
	inc eax
	lock inc byte [temp_signs]
lmul_not_neg_7:
	test edx,0x80000000
	jz lmul_not_neg_8
	not eax
	inc eax
	lock inc byte [temp_signs]
lmul_not_neg_8:
	mul edx
	test byte [temp_signs],1
	jz lmul_not_neg_9
	not eax
	not edx
	add eax,1
	adc edx,0
lmul_not_neg_9:
	mov ax,dx
	ror eax,16
	add ss:[esp],eax
	pop eax
	
	test eax,0x80000000
	jz light_level_not_neg
	xor eax,eax
light_level_not_neg:
	cmp eax,0x00010000
	jl light_level_not_max
	mov eax,0x0000FFFF
light_level_not_max:
	
	mov al,ah
	shl eax,8
	mov al,ah
		
	;mov ah,[ebp-s_edge_12+1]
	;shl eax,8
	;mov ah,[ebp-s_edge_23+1]
	;mov al,[ebp-s_edge_31+1]
		
	call lcd_busy_wait
	push eax
	mov dx,cpld_ptr
	mov eax,[ebp-s_curraddr]
	out dx,eax
	mov eax,ss:[esp]
	mov dx,cpld_pxdata
	out dx,eax
	out dx,eax
	mov dx,cpld_ptr
	mov eax,[ebp-s_curraddr]
	add eax,lcd_width
	out dx,eax
	pop eax
	mov dx,cpld_pxdata
	out dx,eax
	out dx,eax
	
discard_fragment:	
	add dword [ebp-s_curraddr],2
	add dword [ebp-s_curr_depth_addr],2
	mov dx,[ebp-s_dx2]
	inc dx
	cmp dx,[ebp-s_maxx]
	jl shading_cols_loop
	lock add dword [ebp-s_screenaddr],lcd_width*2
	lock add dword [ebp-s_depthaddr],400*2
	mov dx,[ebp-s_dx1]
	inc dx
	cmp dx,[ebp-s_maxy]
	jl shading_rows_loop
	
skip_triangle:
	leave
	ret

	; Takes in a 3D vector (eax, ebx, ecx) and simply multiplies all element by the same scalar (edx)
scale_vector:
	enter 4*4+1,0
	mov [ebp-4-1],eax
	mov [ebp-8-1],ebx
	mov [ebp-12-1],ecx
	mov [ebp-16-1],edx
	mov byte [ebp-1],0
	test edx,0x80000000
	jz scale_vector_not_neg_1
	inc byte [ebp-1]
	not edx
	inc edx
scale_vector_not_neg_1:
	
	; 1
	mov byte [temp_signs],0
	test eax,0x80000000
	jz scale_vector_not_neg_3
	inc byte [temp_signs]
	not eax
	inc eax
scale_vector_not_neg_3:
	mul edx
	test byte [temp_signs],1
	jz scale_vector_not_neg_4
	not eax
	not edx
	add eax,1
	adc edx,0
scale_vector_not_neg_4:
	mov ax,dx
	ror eax,16
	push eax
	
	; 2
	mov byte [temp_signs],0
	mov eax,[ebp-8-1]
	test eax,0x80000000
	jz scale_vector_not_neg_5
	not eax
	inc eax
	inc byte [temp_signs]
scale_vector_not_neg_5:
	mul dword [ebp-16-1]
	test byte [temp_signs],1
	jz scale_vector_not_neg_6
	not eax
	not edx
	add eax,1
	adc edx,0
scale_vector_not_neg_6:
	mov ax,dx
	ror eax,16
	push eax
	
	; 3
	mov byte [temp_signs],0
	mov eax,[ebp-12-1]
	test eax,0x80000000
	jz scale_vector_not_neg_7
	not eax
	inc byte [temp_signs]
	inc eax
scale_vector_not_neg_7:
	mul dword [ebp-16-1]
	test byte [temp_signs],1
	jz scale_vector_not_neg_8
	not edx
	not eax
	add eax,1
	adc edx,0
scale_vector_not_neg_8:
	mov ax,dx
	ror eax,16
	
	mov ecx,eax
	pop ebx
	pop eax
	
	test byte [ebp-1],1
	jz scale_vector_not_neg_2
	not eax
	inc eax
	not ebx
	inc ebx
	not ecx
	inc ecx
scale_vector_not_neg_2:
	mov edx,[ebp-16-1]
	leave
	ret

	; Computes screen-space edge function for given point (eax, ebx)
	; And using two clip-space vertex coordinates (ecx,edx - esi,edi)
	; (P_X - V0_X) * (V1_Y - V0_Y) - (P_Y - V0_Y) * (V1_X - V0_X)
	; Result in eax
edge_function_no_norm:
	enter 3*4,0
	mov [ebp-8],ecx
	mov [ebp-12],edx
	mov [ebp-4],ebx
	jmp edge_skip_ndc
edge_function:
	enter 3*4,0
	mov [ebp-8],ecx
	mov [ebp-12],edx
	
	; First, must convert eax, ebx back into NDC
	rol eax,16
	mov dx,ax
	and eax,0xFFFF0000
	and edx,0x0000FFFF
	mov ecx,400<<16
	div ecx
	sal eax,1
	sub eax,0x00010000
	push eax
	mov eax,ebx
	rol eax,16
	mov dx,ax
	and eax,0xFFFF0000
	and edx,0x0000FFFF
	mov ecx,240<<16
	div ecx
	sal eax,1
	sub eax,0x00010000
	pop ebx
	xchg eax,ebx
	mov ecx,[ebp-8]
	mov [ebp-4],ebx
	
edge_skip_ndc:
	sub eax,ecx
	mov edx,edi
	sub edx,[ebp-12]
	mov byte [temp_signs],0
	test eax,0x80000000
	jz edge_not_neg_4
	not eax
	inc eax
	lock inc byte [temp_signs]
edge_not_neg_4:
	test edx,0x80000000
	jz edge_not_neg_5
	not edx
	inc edx
	lock inc byte [temp_signs]
edge_not_neg_5:
	mul edx
	test byte [temp_signs],1
	jz edge_not_neg_6
	not eax
	not edx
	add eax,1
	adc edx,0
edge_not_neg_6:
	mov ax,dx
	ror eax,16
	push eax ;(P_X - V0_X) * (V1_Y - V0_Y)
	
	mov eax,[ebp-4]
	sub eax,[ebp-12]
	mov edx,esi
	sub edx,[ebp-8]
	mov byte [temp_signs],0
	test eax,0x80000000
	jz edge_not_neg_7
	not eax
	inc eax
	lock inc byte [temp_signs]
edge_not_neg_7:
	test edx,0x80000000
	jz edge_not_neg_8
	not edx
	inc edx
	lock inc byte [temp_signs]
edge_not_neg_8:
	mul edx
	test byte [temp_signs],1
	jz edge_not_neg_9
	not eax
	not edx
	add eax,1
	adc edx,0
edge_not_neg_9:
	mov ax,dx
	ror eax,16
	pop ebx
	sub ebx,eax
	mov eax,ebx
	
	leave
	ret

	; Projects eax, ebx, ecx to clipspace, result in those same registers
	; Uses formula p2 = [(a*f*x)/z, (f*y)/z, z*q - near_q]
project_point:
	push edx
	
	push ecx
	mov byte [temp_signs],0
	mov edx,CONST_AF
	test eax,0x80000000
	jz project_not_neg_1
	lock inc byte [temp_signs]
	not eax
	inc eax
project_not_neg_1:
	mul edx
	and edx,0xFFFF
	test ecx,0x80000000
	jz project_not_neg_2
	lock inc byte [temp_signs]
	not ecx
	inc ecx
project_not_neg_2:
	div ecx
	test byte [temp_signs],1
	jz project_not_neg_3
	not eax
	inc eax
project_not_neg_3:
	pop ecx
	push eax ; p2.x
	
	push ecx
	mov byte [temp_signs],0
	mov eax,CONST_F
	test ebx,0x80000000
	jz project_not_neg_7
	lock inc byte [temp_signs]
	not ebx
	inc ebx
project_not_neg_7:
	mul ebx
	and edx,0xFFFF
	test ecx,0x80000000
	jz project_not_neg_5
	lock inc byte [temp_signs]
	not ecx
	inc ecx
project_not_neg_5:
	div ecx
	test byte [temp_signs],1
	jz project_not_neg_6
	not eax
	inc eax
project_not_neg_6:
	pop ecx
	push eax ; p2.y
	
	mov eax,CONST_Q
	mov byte [temp_signs],0
	test ecx,0x80000000
	jz project_not_neg_4
	lock inc byte [temp_signs]
	not ecx
	inc ecx
project_not_neg_4:
	mul ecx
	test byte [temp_signs],1
	jz project_not_neg_8
	not eax
	not edx
	add eax,1
	adc edx,0
project_not_neg_8:
	mov ax,dx
	ror eax,16
	sub eax,CONST_NEAR_Q
	mov ecx,eax
	pop ebx
	pop eax
	
	pop edx
	ret

	; Converts clipspace point in eax, ebx to screenspace address in eax, ebx
	; Works by adding 1,1 to eax, ebx, then multiplying by 0.5, then multiplying by screen dimensions, so 400, 240
cam_point_to_screenspace:
	enter 2*4,0
	push ecx
	push edx
	
	add eax,0x00010000
	add ebx,0x00010000
	sar eax,1
	sar ebx,1
	
	test eax,0x80000000
	jz to_screenspace_not_neg_1
	xor eax,eax
to_screenspace_not_neg_1:
	test ebx,0x80000000
	jz to_screenspace_not_neg_2
	xor ebx,ebx
to_screenspace_not_neg_2:
	
	mov edx,400
	mul edx
	shr eax,16
	mov [ebp-4],eax
	
	mov eax,ebx
	mov edx,240
	mul edx
	shr eax,16
	mov [ebp-8],eax
	
	cmp dword [ebp-4],399
	jle to_screenspace_le_1
	mov dword [ebp-4],399
to_screenspace_le_1:
	cmp dword [ebp-8],239
	jle to_screenspace_le_2
	mov dword [ebp-8],239
to_screenspace_le_2:
	
	mov eax,[ebp-4]
	mov ebx,[ebp-8]
	
	pop edx
	pop ecx
	leave
	ret

clear_depth:
	push ecx
	mov ecx,0
clear_depth_loop:
	mov word [depth_buffer+ecx],0xFFFF
	add ecx,2
	cmp ecx,depth_buffer_size
	jl clear_depth_loop
	pop ecx
	ret

	; ebx (x), ecx (z) is rotated around Y-Axis
rotate_vector_y:
	push eax
	push edx
	push esi
	push edi
	
	mov byte [temp_signs],0
	mov eax,[ebp-s_cosine_theta]
	mov edi,ebx
	test eax,0x80000000
	jz rotate_not_neg_1
	not eax
	inc eax
	lock inc byte [temp_signs]
rotate_not_neg_1:
	test edi,0x80000000
	jz rotate_not_neg_2
	not edi
	inc edi
	lock inc byte [temp_signs]
rotate_not_neg_2:
	mul edi
	test byte [temp_signs],1
	jz rotate_not_neg_3
	not eax
	not edx
	add eax,1
	adc edx,0
rotate_not_neg_3:
	mov ax,dx
	ror eax,16
	mov esi,eax
	mov eax,[ebp-s_sine_theta]
	mov edi,ecx
	mov byte [temp_signs],0
	test eax,0x80000000
	jz rotate_not_neg_4
	lock inc byte [temp_signs]
	not eax
	inc eax
rotate_not_neg_4:
	test ecx,0x80000000
	jz rotate_not_neg_5
	lock inc byte [temp_signs]
	not edi
	inc edi
rotate_not_neg_5:
	mul edi
	test byte [temp_signs],1
	jz rotate_not_neg_6
	not eax
	not edx
	add eax,1
	adc edx,0
rotate_not_neg_6:
	mov ax,dx
	ror eax,16
	add eax,esi
	push eax
	
	mov eax,[ebp-s_neg_sine_theta]
	mov edi,ebx
	mov byte [temp_signs],0
	test eax,0x80000000
	jz rotate_not_neg_7
	not eax
	inc eax
	lock xor byte [temp_signs],1
rotate_not_neg_7:
	test edi,0x80000000
	jz rotate_not_neg_8
	not edi
	inc edi
	lock xor byte [temp_signs],1
rotate_not_neg_8:
	mul edi
	test byte [temp_signs],1
	jz rotate_not_neg_9
	not eax
	not edx
	add eax,1
	adc edx,0
rotate_not_neg_9:
	mov ax,dx
	ror eax,16
	mov esi,eax
	mov eax,[ebp-s_cosine_theta]
	mov edi,ecx
	mov byte [temp_signs],0
	test eax,0x80000000
	jz rotate_not_neg_10
	lock inc byte [temp_signs]
	not eax
	inc eax
rotate_not_neg_10:
	test edi,0x80000000
	jz rotate_not_neg_11
	lock inc byte [temp_signs]
	not edi
	inc edi
rotate_not_neg_11:
	mul edi
	test byte [temp_signs],1
	jz rotate_not_neg_12
	not eax
	not edx
	add eax,1
	adc edx,0
rotate_not_neg_12:
	mov ax,dx
	ror eax,16
	add eax,esi
	mov ecx,eax
	pop ebx
	
	pop edi
	pop esi
	pop edx
	pop eax
	ret
