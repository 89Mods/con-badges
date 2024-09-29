ext4_lbas_per_block equ 8
ext4_log_lbas_per_block equ 3
ext4_blocksize_bytes equ 4096
ext4_log_blocksize_bytes equ 12
ext4_blocksize_mask equ 0xFFF
ext4_max_etree_depth equ 4
ext4_max_fn equ 32

; Superblock FS flags
INCOMPAT_FILETYPE equ 0x0002
INCOMPAT_EXTENTS equ 0x0040
INCOMPAT_64BIT equ 0x0080
INCOMPAT_FLEX_BG equ 0x0200
INCOMPAT_64BIT equ 0x0080
COMPAT_SPARSE_SUPER2 equ 0x200
RO_COMPAT_HUGE_FILE equ 0x0008
RO_COMPAT_ORPHAN_PRESENT equ 0x10000
RO_COMPAT_GDT_CSUM equ 0x0010
RO_COMPAT_METADATA_CSUM equ 0x0400

; Inode struct organization
ext4_s_inode_length equ 100
ext4_inode_mode equ 0 ;u16
ext4_inode_uid equ 2 ;u32
ext4_inode_size equ 6 ;u64
ext4_inode_gid equ 14 ;u32
ext4_inode_links_count equ 18 ;u16
ext4_inode_blocks equ 20 ;u64
ext4_inode_flags equ 28 ;u32
ext4_inode_num equ 32 ;u64
ext4_inode_i_block equ 40 ;u8[60]
ext4_i_block_length equ 60
ext4_i_block_length_words equ 15 ;60/4

; Inode flags
EXT4_EXTENTS_FL equ 0x80000
EXT4_INDEX_FL equ 0x1000

; extent struct organization
ext4_s_extent_length equ 12
ext4_extent_ee_block equ 0 ;u32
ext4_extent_ee_len equ 4 ;u16
ext4_extent_ee_start equ 6 ;u48

; extent index struct organization
ext4_s_extent_index_length equ 12
ext4_extent_index_ei_block equ 0 ;u32
ext4_extent_index_ei_leaf equ 4 ;u48
ext4_extent_index_ei_unused equ 10 ;u16

; etree entry struct organization
ext4_s_etree_entry_length equ 10
ext4_etree_entry_block equ 0 ;u64
ext4_etree_entry_curr_entry equ 8 ;u16

; FIL struct organization
ext4_FIL_s_length equ (29+ext4_s_extent_length+(ext4_s_etree_entry_length*ext4_max_etree_depth))
ext4_FIL_inum equ 0 ;u64
ext4_FIL_iflags equ 8 ;u32
ext4_FIL_position equ 12 ;u64
ext4_FIL_limit equ 20 ;u64
ext4_FIL_curr_extent equ 28 ;ext4_s_extent_length
ext4_FIL_path equ (28+ext4_s_extent_length) ;ext4_etree_entry[ext4_max_etree_depth]
ext4_FIL_curr_depth equ (28+ext4_s_extent_length+(ext4_s_etree_entry_length*ext4_max_etree_depth)) ;u8

; DIR struct organization
; This is just a FIL struct with two u32s slapped at the end to cache '.' and '..'
ext4_DIR_s_length equ (ext4_FIL_s_length+8)
ext4_DIR_dot_inode equ (ext4_FIL_s_length) ;u32
ext4_DIR_dotdot_inode equ (ext4_FIL_s_length+4) ;u32

; dir entry 2 struct organization
ext4_dir_entry2_s_length equ 8
ext4_dir_entry2_inode equ 0 ;u32
ext4_dir_entry2_rec_len equ 4 ;u16
ext4_dir_entry2_name_len equ 6 ;u8
ext4_dir_entry2_file_type equ 7 ;u8

; extent header struct organization
ext4_extent_header_s_length equ 12
ext4_extent_header_magic equ 0 ;u16
ext4_extent_header_entries equ 2 ;u16
ext4_extent_header_max equ 4 ;u16
ext4_extent_header_depth equ 6 ;u16
ext4_extent_header_generation equ 8 ;u32

scan_mbr:
    enter 512,0
    xor eax,eax
    mov [ext4_firstblock],eax
    mov [swap_firstblock],eax
    inc eax
    mov dx,ata_reg_sec_count
    out dx,eax
    dec eax
    call ata_begin_read
    mov edi,ebp
    sub edi,512
    call ata_read_buffer
    
    cmp byte [edi+510],0x55
    jne invalid_mbr
    cmp byte [edi+511],0xAA
    je valid_mbr
invalid_mbr:
    mov eax,str_invalid_mbr
    call putstring
    mov eax,str_invalid_mbr+19
    call term_putfatal
    mov dword [ext4_firstblock],1
    jmp scan_mbr_ret
valid_mbr:
    
    mov cl,4
    add edi,446
partition_scan_loop:
    mov al,[edi+4] ; Partition type
    cmp al,0
    je partition_scan_continue
    mov ebx,[edi+8] ; Start block
    mov edx,[edi+12] ; Size in blocks
    cmp al,0x83
    je partition_found_ext4
partition_found_swap:
    mov [swap_firstblock],ebx
    mov [swap_length],edx
    jmp partition_scan_continue
partition_found_ext4:
    mov [ext4_firstblock],ebx
    mov [ext4_length],edx
    add ebx,edx
    mov [ext4_lastblock],ebx
partition_scan_continue:
    add edi,16
    dec cl
    jne partition_scan_loop
    
    cmp dword [ext4_firstblock],0
    je bad_partitions
    cmp dword [swap_firstblock],0
    je bad_partitions
    mov eax,[ext4_lastblock]
    cmp eax,[swap_firstblock]
    jl bad_partitions
    
    jmp scan_mbr_ret
bad_partitions:
    mov eax,str_bad_partitions
    call putstring
    mov eax,str_bad_partitions+19
    call term_putfatal
    mov dword [ext4_firstblock],1
scan_mbr_ret:
    leave
    ret

    ; Block num in eax
    ; TODO: accept 64-bit block numbers
ext4_read_block:
	cmp eax,[ext4_lub]
	je ext4_read_skipall
	mov [ext4_lub],eax
    push eax
    push ebx
    push ecx
    push edi
    add eax,[ext4_sb_first_datablock]
    shl eax,ext4_log_lbas_per_block
    add eax,[ext4_firstblock]
    mov edi,eax
    mov ax,ext4_lbas_per_block
    mov dx,ata_reg_sec_count
    out dx,eax
    mov eax,edi
    call ata_begin_read
    mov ecx,ext4_lbas_per_block
    mov edi,ext4_buff
ext4_read_block_loop:
    call ata_wait_for_data
    call ata_read_buffer
    add edi,512
    loop ext4_read_block_loop
    pop edi
    pop ecx
    pop ebx
    pop eax
ext4_read_skipall:
    ret

    ; Inode number in eax
    ; Pointer to inode data in ext4_buff returned in esi
ext4_inode_raw_pointer:
    push eax
    push edi
    push ebx
    push ecx
    
    xor edx,edx
    dec eax
    div dword [ext4_sb_inodes_per_group]
    mov ecx,eax ; Inode bgroup
    
    mov eax,edx
    xor edx,edx
    mov dx,[ext4_sb_inode_size]
    mul edx
    push eax ; Inode address
    
    mov eax,ecx
    xor edx,edx
    mov dx,[ext4_sb_desc_size]
    mul edx
    
    mov ecx,ext4_blocksize_bytes
    div ecx
    inc eax
    ; Block no. in eax, address in block in edx
    push edx
    call ext4_read_block
    pop edx
    mov edi,ext4_buff
    add edi,edx
    
    test word [edi+0x12],0x1
    jz ext4_raw_pointer_bg_okay
    xor esi,esi
    pop eax
    jmp ext4_inode_raw_pointer_ret
ext4_raw_pointer_bg_okay:
    
    pop eax
    xor edx,edx
    mov ecx,ext4_blocksize_bytes
    div ecx
    push edx
    
    xor edx,edx
    add eax,[edi+0x08] ; bg_inode_table_lo
    adc edx,[edi+0x28] ; bg_inode_table_hi ; TODO: not on 32-bit FS
    
    call ext4_read_block
    mov esi,ext4_buff
    pop edx
    mov eax,edx
    add esi,edx
    
ext4_inode_raw_pointer_ret:
    pop ecx
    pop ebx
    pop edi
    pop eax
    ret
    
    ; Inode raw pointer in esi
    ; Inode struct pointer in edi
ext4_parse_inode:
    push eax
    push ebx
    mov ax,[esi+0x00]
    mov [edi+ext4_inode_mode],ax
    mov eax,[esi+0x02]
    mov [edi+ext4_inode_uid],eax
    mov eax,[esi+0x04]
    mov [edi+ext4_inode_size],eax
    mov eax,[esi+0x18]
    mov [edi+ext4_inode_gid],eax
    mov ax,[esi+0x1A]
    mov [edi+ext4_inode_links_count],ax
    mov eax,[esi+0x1C]
    mov [edi+ext4_inode_blocks],eax
    mov eax,[esi+0x20]
    mov [edi+ext4_inode_flags],eax
    
    mov dword [edi+ext4_inode_size+4],0
    mov dword [edi+ext4_inode_blocks+4],0
    cmp word [ext4_sb_inode_size],128
    jle ext4_parse_inode_no_extra
    mov eax,[esi+0x6C]
    mov [edi+ext4_inode_size+4],eax
    mov eax,[esi+0x72]
    mov [edi+ext4_inode_blocks+4],eax
ext4_parse_inode_no_extra:
    ; Copy i_block
    mov ax,es
    mov bx,ram_segment
    mov es,bx
    push esi
    push edi
    add esi,0x28
    add edi,ext4_inode_i_block
    push ecx
    mov ecx,ext4_i_block_length_words
    cld
    rep movsd
    pop ecx
    pop edi
    pop esi
    mov es,ax
    
    pop ebx
    pop eax
    ret
    
    ; Inode number in eax
    ; Pointer to inode struct in edi
ext4_read_inode:
    call ext4_inode_raw_pointer
    cmp esi,0
    je ext4_read_inode_err_ret
    mov [edi+ext4_inode_num],eax
    mov dword [edi+ext4_inode_num+4],0
    call ext4_parse_inode
    ret
ext4_read_inode_err_ret:
    xor eax,eax
    ret

    ; ext4_FIL struct pointer in edi
ext4_find_next_extent:
    push eax
    push ebp
    push esi
ext4_find_extent_recurse: ;Actually a loop, but whatever
    
    xor eax,eax
    mov al,ext4_s_etree_entry_length
    mul byte [ext4_FIL_curr_depth]
    lea ebp,[edi+ext4_FIL_path+eax]
    mov eax,[ebp+ext4_etree_entry_block]
    cmp eax,0xFFFFFFFF
    jne ext4_find_extent_inblock
    cmp dword [ebp+ext4_etree_entry_block+4],0xFFFFFFFF
    jne ext4_find_extent_inblock
    ; Its in the Inode’s i_block, so the inode needs to be accessed
    mov eax,[edi+ext4_FIL_inum]
    call ext4_inode_raw_pointer
    cmp esi,0
    je ext4_find_extent_err_ret
    add esi,0x28
    jmp ext4_find_extent_in_iblock
ext4_find_extent_inblock:
    ; Its in a dedicated block, so load that block
    call ext4_read_block
    mov esi,ext4_buff
ext4_find_extent_in_iblock:
    ; esi now contains pointer to extent header
    cmp word [esi+ext4_extent_header_magic],0xF30A
    je ext4_find_good_header
    mov eax,str_bad_eh_magic
    call putstring
    jmp ext4_find_extent_err_ret
ext4_find_good_header:
    mov ax,[esi+ext4_extent_header_entries]
    dec ax
    cmp ax,[ebp+ext4_etree_entry_curr_entry]
    je ext4_find_extent_last_in_list
    mov ax,[esi+ext4_extent_header_depth]
    push ax
    
    xor eax,eax
    inc word [ebp+ext4_etree_entry_curr_entry]
    mov ax,12
    mul word [ebp+ext4_etree_entry_curr_entry]
    shl edx,16
    or eax,edx
    lea esi,[esi+eax+ext4_extent_header_s_length]
    
    pop ax
    cmp ax,0
    jne ext4_find_extent_hit_interior_node
    ; Finally, I have obtained extent!
    mov eax,[esi]
    mov [edi+ext4_FIL_curr_extent],eax
    mov eax,[esi+4]
    mov [edi+ext4_FIL_curr_extent+4],eax
    mov eax,[esi+8]
    mov [edi+ext4_FIL_curr_extent+8],eax
ext4_find_extent_ret:
    pop esi
    pop ebp
    pop eax
    ret
ext4_find_extent_err_ret:
    xor edi,edi
    jmp ext4_find_extent_ret
ext4_find_extent_last_in_list:
    cmp byte [edi+ext4_FIL_curr_depth],0
    je ext4_find_extent_last
    ; Either its the end of the file, or we need to go back to the previous interior node
    cmp dword [ebp+ext4_etree_entry_block],0xFFFFFFFF
    jne ext4_find_extent_not_last
    cmp dword [ebp+ext4_etree_entry_block+4],0xFFFFFFFF
    jne ext4_find_extent_not_last
ext4_find_extent_last:
    xor edi,edi
    inc edi
    jmp ext4_find_extent_ret
ext4_find_extent_not_last:
    ; Go up one level
    dec byte [edi+ext4_FIL_curr_depth]
    jmp ext4_find_extent_recurse
ext4_find_extent_hit_interior_node:
    ; Its an interior node! Gotta figure out where to go next!
    mov al,[edi+ext4_FIL_curr_depth]
    inc al
    mov [edi+ext4_FIL_curr_depth],al
    cmp al,ext4_max_etree_depth
    jne ext4_find_not_too_deep
    mov eax,str_too_deep
    call putstring
    jmp ext4_find_extent_err_ret
ext4_find_not_too_deep:
    xor eax,eax
    mov al,ext4_s_etree_entry_length
    mul byte [edi+ext4_FIL_curr_depth]
    lea ebp,[edi+ext4_FIL_path+eax]
    mov word [ebp+ext4_etree_entry_curr_entry],0xFFFF
    mov eax,[esi+ext4_extent_index_ei_leaf]
    mov [ebp+ext4_etree_entry_block],eax
    xor eax,eax
    mov ax,[esi+ext4_extent_index_ei_leaf+4]
    mov [ebp+ext4_etree_entry_block+4],eax
    jmp ext4_find_extent_recurse
    
    ; Inode number in eax
    ; ext4_FIL struct pointer in edi
ext4_open_read:
    enter ext4_s_inode_length+12,0
    push ecx
    push ebx
    push eax
    
    mov [ebp-4],edi
    mov edi,ebp
    sub edi,ext4_s_inode_length+12
    call ext4_read_inode
    cmp eax,0
    je ext4_open_read_error
    mov ebx,[edi+ext4_inode_size]
    mov [ebp-8],ebx
    mov ebx,[edi+ext4_inode_size+4]
    mov [ebp-12],ebx
    mov ebx,[edi+ext4_inode_flags]
    test ebx,EXT4_EXTENTS_FL
    jnz ext4_open_has_extents
    mov eax,str_no_extents
    call putstring
    jmp ext4_open_read_error
ext4_open_has_extents:
    cmp word [edi+ext4_inode_i_block+ext4_extent_header_magic],0xF30A
    je ext4_open_read_h_okay
    mov eax,str_bad_eh_magic
    call putstring
    jmp ext4_open_read_error
ext4_open_read_h_okay:
    mov ch,[edi+ext4_inode_i_block+ext4_extent_header_entries]
    ; Setup root entry
    mov edi,[ebp-4]
    mov dword [edi+ext4_FIL_path+ext4_etree_entry_block],0xFFFFFFFF
    mov dword [edi+ext4_FIL_path+ext4_etree_entry_block+4],0xFFFFFFFF
    mov word [edi+ext4_FIL_path+ext4_etree_entry_curr_entry],0xFFFF
    ; Setup all other parameters
    mov eax,ss:[esp]
    mov [edi+ext4_FIL_inum],eax
    mov dword [edi+ext4_FIL_inum+4],0
    mov [edi+ext4_FIL_iflags],ebx
    xor eax,eax
    mov [edi+ext4_FIL_position],eax
    mov [edi+ext4_FIL_position+4],eax
    mov [edi+ext4_FIL_curr_depth],al
    mov ebx,[ebp-8]
    mov [edi+ext4_FIL_limit],ebx
    mov ebx,[ebp-12]
    mov [edi+ext4_FIL_limit+4],ebx
    cmp ch,0
    je ext4_open_read_skip ; Empty file - do nothing more
    call ext4_find_next_extent ; Find initial extent
    cmp edi,0
    je ext4_open_read_error
ext4_open_read_skip:
    pop eax
    pop ebx
    pop ecx
    leave
    ret
ext4_open_read_error:
    pop eax
    xor eax,eax
    pop ebx
    pop ecx
    leave
    ret

    ; FIL pointer in esi
    ; buffer pointer in edi
    ; no. bytes to be read in eax
    ; no. bytes actually read returned in eax (or 0xFFFFFFFF if error)
ext4_read:
    enter 27,0
    push ebx
    push edx
    push ecx
    push edi
    mov dword [ebp-27],0
    mov [ebp-5],eax
    mov eax,[esi+ext4_FIL_position]
    mov ebx,[esi+ext4_FIL_position+4]
    sub eax,[esi+ext4_FIL_limit]
    sbb ebx,[esi+ext4_FIL_limit+4]
    jc ext4_read_bytes_left
    xor eax,eax
    jmp ext4_read_ret
ext4_read_bytes_left:
    mov byte [ebp-1],1
    xor ecx,ecx
ext4_read_loop:
	cmp ecx,[ebp-5]
	jge ext4_read_loop_over
	push ecx
	cmp byte [ebp-1],1
	jne ext4_read_no_flag
		mov byte [ebp-1],0
		mov ax,[esi+ext4_FIL_curr_extent+ext4_extent_ee_len]
		cmp ax,32768
		jle ext4_read_eelen
		sub ax,32768
	ext4_read_eelen:
		mov [ebp-7],ax ;ext_len
		mov eax,[esi+ext4_FIL_curr_extent+ext4_extent_ee_block]
		mov edx,ext4_blocksize_bytes
		mul edx
		; With a 4096 block size, this SHOULD always fit into a 32-bit int, even with a maximum extent length
		mov edx,[esi+ext4_FIL_position]
		sub edx,eax
		mov eax,edx
		xor edx,edx
		mov ecx,ext4_blocksize_bytes
		div ecx
		mov [ebp-15],eax ;extent_block
		mov [ebp-11],edx ;block_pos
		xor edx,edx
		mov dx,[esi+ext4_FIL_curr_extent+ext4_extent_ee_start]
		add eax,[esi+ext4_FIL_curr_extent+ext4_extent_ee_start+2]
		adc edx,0
		mov [ebp-19],eax ;block (lo)
		mov [ebp-23],edx ;block (hi)
		call ext4_read_block
ext4_read_no_flag:
	mov eax,4096
	sub eax,[ebp-11]
	mov ecx,[ebp-5]
	sub ecx,ss:[esp]
	cmp eax,ecx
	jge ext4_read_rem
	mov ecx,eax
ext4_read_rem:
    mov eax,[esi+ext4_FIL_limit]
    mov ebx,[esi+ext4_FIL_limit+4]
    sub eax,[esi+ext4_FIL_position]
    sbb ebx,[esi+ext4_FIL_position+4]
    jnz ext4_read_nolimit
    cmp eax,ecx
    jge ext4_read_nolimit
    mov ecx,eax
ext4_read_nolimit:
	cld
	mov eax,ecx
	
	push esi
	mov esi,ext4_buff
	add esi,[ebp-11]
	test ecx,0xFFFFFFFC
	jz ext4_read_no_words
	shr ecx,2
	rep movsd
	mov ecx,eax
ext4_read_no_words:
	and ecx,3
	jz ext4_read_no_bytes
	rep movsb
ext4_read_no_bytes:
	mov ecx,eax
	pop esi
	
	add [ebp-27],eax
	add [esi+ext4_FIL_position],eax
	adc dword [esi+ext4_FIL_position+4],0
	add [ebp-11],eax
	add ss:[esp],eax
	
    mov eax,[esi+ext4_FIL_position]
    mov ebx,[esi+ext4_FIL_position+4]
    sub eax,[esi+ext4_FIL_limit]
    sbb ebx,[esi+ext4_FIL_limit+4]
    jc ext4_read_loop_bytes_left
    pop ecx
    jmp ext4_read_loop_over
ext4_read_loop_bytes_left:
	cmp dword [ebp-11],ext4_blocksize_bytes
	jne ext4_read_idkwhattonamethis
	inc dword [ebp-15]
	mov dword [ebp-11],0
	add dword [ebp-19],1
	adc dword [ebp-23],0
	xor eax,eax
	mov ax,[ebp-7]
	cmp [ebp-15],eax
	jl ext4_read_aaa
	push edi
	mov edi,esi
	call ext4_find_next_extent
	cmp edi,0
	jne ext4_read_no_err1
	pop edi
	pop ecx
	mov eax,[ebp-27]
	or eax,0x80000000
	jmp ext4_read_ret
ext4_read_no_err1:
	pop edi
	mov byte [ebp-1],1
	jmp ext4_read_idkwhattonamethis
ext4_read_aaa:
	mov eax,[ebp-5]
	cmp ss:[esp],eax
	jge ext4_read_idkwhattonamethis
	mov eax,[ebp-19]
	call ext4_read_block
ext4_read_idkwhattonamethis:
	pop ecx
	jmp ext4_read_loop
ext4_read_loop_over:
    mov eax,[ebp-27]
ext4_read_ret:
	pop edi
    pop ecx
    pop edx
    pop ebx
    leave
    ret

    ; Inode number in eax
    ; ext4_DIR struct pointer in edi
ext4_open_dir:
    call ext4_open_read
    cmp eax,0
    je ext4_open_dir_could_not_open
    enter ext4_dir_entry2_s_length+4,0
    push eax
    push esi
    push edi
    ; Check first directory entry, HAS to be '.' according to spec
    mov esi,edi
    mov edi,ebp
    sub edi,ext4_dir_entry2_s_length+4
    mov eax,ext4_dir_entry2_s_length+4
    call ext4_read
    cmp eax,ext4_dir_entry2_s_length+4
    jne ext4_open_dir_read_error
    cmp word [edi+ext4_dir_entry2_rec_len],0x0C
    jne ext4_open_dir_bad_dir_start
    cmp byte [edi+ext4_dir_entry2_file_type],0x02
    jne ext4_open_dir_bad_dir_start
    cmp dword [edi+ext4_dir_entry2_s_length],0x0000002E
    jne ext4_open_dir_bad_dir_start
    mov eax,[edi+ext4_dir_entry2_inode]
    mov [esi+ext4_DIR_dot_inode],eax

    ; Check second directory entry, HAS to be '..' according to spec
    mov eax,ext4_dir_entry2_s_length+4
    call ext4_read
    cmp eax,ext4_dir_entry2_s_length+4
    jne ext4_open_dir_read_error

    ;cmp word [edi+ext4_dir_entry2_rec_len],0x0C
    ;jne ext4_open_dir_bad_dir_start
    cmp byte [edi+ext4_dir_entry2_file_type],0x02
    jne ext4_open_dir_bad_dir_start
    cmp dword [edi+ext4_dir_entry2_s_length],0x00002E2E
    jne ext4_open_dir_bad_dir_start
    mov eax,[edi+ext4_dir_entry2_inode]
    mov [esi+ext4_DIR_dotdot_inode],eax
    pop edi
    pop esi
    pop eax
    leave
    ret
ext4_open_dir_err_ret1:
    xor eax,eax
    ret
ext4_open_dir_read_error:
    mov eax,str_dir_read_error
    call putstring
	jmp ext4_open_dir_err_ret2
ext4_open_dir_could_not_open:
    mov eax,str_dir_read_error_could_not_open
    call putstring
ext4_open_dir_err_ret2:
    pop edi
    pop esi
    pop eax
    xor eax,eax
    leave
    ret
ext4_open_dir_bad_dir_start:
    mov eax,str_dir_bad_start
    call putstring
    jmp ext4_open_dir_err_ret2

    ; ext4_DIR struct pointer in esi
    ; Inode num returned in eax (or 0 if error or EOF)
    ; File type returned in ebx (0xFFFF in bx means EOF)
    ; Pointer to name buffer in edi, or 0 if name is not to be read
ext4_dir_next:
    enter 275,0
    push edx
    push ecx
    push edi
    mov byte [ebp-271],0
    mov [ebp-275],edi

    test dword [esi+ext4_FIL_iflags],EXT4_INDEX_FL
    jnz ext4_dir_unsupported
ext4_dir_loop:
    mov eax,[esi+ext4_FIL_limit]
    mov ebx,[esi+ext4_FIL_limit+4]
    sub eax,[esi+ext4_FIL_position]
    sbb ebx,[esi+ext4_FIL_position+4]
    js ext4_dir_eof
    cmp ebx,0
    jne ext4_dir_loop_continue
    cmp eax,ext4_dir_entry2_s_length+4 ;Minimum length of a entry with valid FN
    jle ext4_dir_eof
ext4_dir_loop_continue:
    lea edi,[ebp-ext4_dir_entry2_s_length]
    mov eax,ext4_dir_entry2_s_length
    call ext4_read
    cmp eax,ext4_dir_entry2_s_length
    jnz ext4_dir_read_error

    cmp dword [edi+ext4_dir_entry2_inode],0
    je ext4_dir_loop_continue
    ; Push inode num and file type to stack
    mov eax,[edi+ext4_dir_entry2_inode]
    push eax
    xor eax,eax
    mov al,[edi+ext4_dir_entry2_file_type]
    push eax

    mov ax,[edi+ext4_dir_entry2_rec_len]
    sub ax,ext4_dir_entry2_s_length
    mov ebx,[esi+ext4_FIL_limit]
    mov ecx,[esi+ext4_FIL_limit+4]
    sub ebx,eax
    sbb ecx,0
    sub ebx,[esi+ext4_FIL_position]
    sbb ecx,[esi+ext4_FIL_position+4]
    jnz ext4_not_final_entry
    cmp ebx,12
    jg ext4_not_final_entry
    mov byte [ebp-271],1
    mov ax,0
    mov al,[edi+ext4_dir_entry2_name_len]
ext4_not_final_entry:

    cmp ax,0
    je ext4_dir_name_read_end
    ; Read filename
    push eax
    lea edi,[ebp-270]
    call ext4_read
    pop ebx
    mov edi,[ebp-275]
    cmp eax,ebx
    je ext4_dir_no_read_error
    pop eax
    pop eax
    jmp ext4_dir_read_error
ext4_dir_no_read_error:
    cmp edi,0
    je ext4_dir_next_ret
    push esi
    lea esi,[ebp-270]
    cld
    mov ecx,ebx
    rep movsb
    pop esi
ext4_dir_name_read_end:
    mov byte [edi],0

ext4_dir_next_ret:
    cmp byte [ebp-271],1
    jne ext4_dir_no_spoof
    ; Spoof EOF
    mov ebx,[esi+ext4_FIL_limit]
    mov eax,[esi+ext4_FIL_limit+4]
    sub ebx,0x0C
    sbb eax,0
    mov [esi+ext4_FIL_position],ebx
    mov [esi+ext4_FIL_position+4],eax
ext4_dir_no_spoof:
    pop ebx
    pop eax
ext4_dir_ret:
    pop edi
    pop ecx
    pop edx
    leave
    ret
ext4_dir_eof:
    pop edi
    pop ecx
    pop edx
    xor eax,eax
    mov ebx,0xFFFFFFFF
    leave
    ret
ext4_dir_unsupported:
    mov eax,str_dir_unsupported
    call putstring
    jmp ext4_dir_err_ret
ext4_dir_read_error:
    mov eax,str_dir_read_error
    call putstring
ext4_dir_err_ret:
    pop edi
    pop ecx
    pop edx
    leave
    xor eax,eax
    xor ebx,ebx
    ret

    ; Current inode in eax
    ; Pointer to path string in ebx
    ; Found inode returned in eax (zero if error, one if not found)
    ; Found file type returned in ebx
ext4_path_parser:
    enter ext4_max_fn*2+ext4_DIR_s_length+12,0
    push ecx
    push esi
    push edi
    push ebx

	; ebp-4 is strlen
    mov dword [ebp-4],0 ; ebp-1 is should_be_dir and ebp-2 is the_end

    lea edi,[ebp-ext4_DIR_s_length-ext4_max_fn*2-12]

    push eax
    xor ecx,ecx
ext4_path_substr_loop:
    mov al,fs:[ebx+ecx]
    cmp al,'/'
    jne ext4_p_substr_not_slash
    mov byte [ebp-1],1
    mov al,fs:[ebx+ecx+1]
    cmp al,0
    jne ext4_p_substr_break
    mov byte [ebp-2],1
    jmp ext4_p_substr_break
ext4_p_substr_not_slash:
    cmp al,0
    jne ext4_p_substr_not_zero
    mov byte [ebp-2],1
    jmp ext4_p_substr_break
ext4_p_substr_not_zero:
    inc word [ebp-4]
    mov [edi+ecx],al
    inc cx
    cmp cx,ext4_max_fn
    jne ext4_path_substr_loop
ext4_p_substr_break:
    pop eax
    cmp cx,ext4_max_fn
    jne ext4_path_no_overflow
    cmp word [ebp-2],0
    jne ext4_path_no_overflow
    mov eax,str_fn_too_long
    call putstring
    jmp ext4_path_parser_err_ret
ext4_path_no_overflow:
    mov ecx,edi
    lea edi,[ebp-ext4_DIR_s_length-12]
    call ext4_open_dir
    cmp eax,0
    je ext4_path_parser_err_ret
    ; Good to go with scanning for the required FN
    cmp word [ebp-4],1
    jne ext4_path_not_dot
    cmp byte [ecx],'.'
    jne ext4_path_not_dot
        ; skip with dot inode as found
        mov eax,[edi+ext4_DIR_dot_inode]
        mov ebx,2
        jmp ext4_path_search_loop_over
ext4_path_not_dot:
	cmp word [ebp-4],2
	jne ext4_path_not_dotdot
    cmp word [ecx],0x2E2E
    jne ext4_path_not_dotdot
        ; skip with dotdot inode as found
        mov eax,[edi+ext4_DIR_dotdot_inode]
        mov ebx,2
        jmp ext4_path_search_loop_over
ext4_path_not_dotdot:

ext4_path_search_loop:
    lea esi,[ebp-ext4_DIR_s_length-12]
    lea edi,[ebp-ext4_DIR_s_length-ext4_max_fn-12]
    call ext4_dir_next
    cmp bx,0xFFFF
    je ext4_path_parser_ret_not_found
    cmp eax,0
    jne ext4_p_search_l_no_err
    ; TODO: error message
    jmp ext4_path_parser_err_ret
ext4_p_search_l_no_err:
    mov [ebp-8],eax
    mov [ebp-12],ebx
    mov bl,1
    lea esi,[ebp-ext4_DIR_s_length-ext4_max_fn*2-12]
    xor ecx,ecx
ext4_p_s_strcmp_loop:
        mov al,[edi+ecx]
        cmp al,0
        je ext4_p_s_strcmp_f
        cmp al,[esi+ecx]
        je ext4_p_s_strcmp_nf
ext4_p_s_strcmp_f:
        mov bl,0
        jmp ext4_p_s_strcmp_loop_over
ext4_p_s_strcmp_nf:
        mov eax,ecx
        inc eax
        cmp ax,[ebp-4]
        jne ext4_p_s_strcmp_cont
        cmp byte [edi+eax],0
        je ext4_p_s_strcmp_loop_over
ext4_p_s_strcmp_cont:
        inc cx
        cmp cx,[ebp-4]
        jne ext4_p_s_strcmp_loop
ext4_p_s_strcmp_loop_over:
    cmp bl,1
    jne ext4_path_search_loop
    mov eax,[ebp-8]
    mov ebx,[ebp-12]
ext4_path_search_loop_over:
    cmp byte [ebp-1],0
    je ext4_path_no_dir_err
    cmp ebx,0x02
    je ext4_path_no_dir_err
    ; TODO: error message
    jmp ext4_path_parser_err_ret
ext4_path_no_dir_err:
    cmp ebx,0x07
    jne ext4_path_no_link_err
    mov eax,str_symlinks_unsupported
    call putstring
    jmp ext4_path_parser_err_ret
ext4_path_no_link_err:
    cmp byte [ebp-2],0
    jne ext4_path_return_result
	; Must recurse
    pop ebx
    pop edi
    pop esi
    pop ecx
    push eax
    xor eax,eax
    mov ax,[ebp-4]
    add ebx,eax
    inc ebx
    pop eax
    leave
    jmp ext4_path_parser
ext4_path_return_result:
    mov [ebp-4],ebx
    pop ebx
    pop edi
    pop esi
    pop ecx
    mov ebx,[ebp-4]
    leave
    ret
ext4_path_parser_err_ret:
    pop ebx
    pop edi
    pop esi
    pop ecx
    xor eax,eax
    mov ebx,eax
    leave
    ret
ext4_path_parser_ret_not_found:
    pop ebx
    pop edi
    pop esi
    pop ecx
    mov ebx,0xFFFFFFFF
    mov eax,1
    leave
    ret

    ; No arguments - mounts/remounts ext4 partition
    ; al is 0 if no error
    ; trashes a bunch of registers lol
ext4_mount:
    mov dword [ext4_sb_first_datablock],0
    xor eax,eax
    mov dword [ext4_lub],0xFFFFFFFF
    call ext4_read_block
    mov ebp,ext4_buff+1024
    mov eax,[ebp+0x14]
    mov [ext4_sb_first_datablock],eax
    mov eax,[ebp+0x28]
    mov [ext4_sb_inodes_per_group],eax
    mov ax,[ebp+0x58]
    mov [ext4_sb_inode_size],ax
    mov ax,[ebp+0xFE]
    mov [ext4_sb_desc_size],ax
    mov eax,[ebp+0x20]
    mov [ext4_sb_blocks_per_group],eax
    mov eax,[ebp+0x5C]
    mov [ext4_sb_feature_compat],eax
    mov eax,[ebp+0x60]
    mov [ext4_sb_feature_incompat],eax
    mov eax,[ebp+0x64]
    mov [ext4_sb_feature_ro_compat],eax
    cmp word [ebp+0x38],0xEF53
    jne ext4_bad_sb
    cmp dword [ebp+0x18],2
    jne ext4_incompat
    
    test dword [ext4_sb_feature_incompat],~(INCOMPAT_FILETYPE | INCOMPAT_EXTENTS | INCOMPAT_64BIT | INCOMPAT_FLEX_BG)
    jnz ext4_incompat
    
    test dword [ext4_sb_feature_incompat],INCOMPAT_EXTENTS
    jz ext4_incompat
    cmp word [ext4_sb_desc_size],64
    jne ext4_incompat
    
    mov eax,str_fs_flags
    call putstring
    mov eax,str_fs_flags+18
    call term_putinfo
    
    test dword [ext4_sb_feature_ro_compat],RO_COMPAT_METADATA_CSUM
    jz ext4_no_metadata_csum
    mov eax,str_metadata_csum
    call putstring
    mov eax,str_metadata_csum
    call term_putstring
ext4_no_metadata_csum:
    test dword [ext4_sb_feature_ro_compat],RO_COMPAT_GDT_CSUM
    jz ext4_no_gdt_csum
    mov eax,str_gdt_csum
    call putstring
    mov eax,str_gdt_csum
    call term_putstring
ext4_no_gdt_csum:
    test dword [ext4_sb_feature_incompat],INCOMPAT_FLEX_BG
    jz ext4_no_flex_bg
    mov eax,str_flex_bg
    call putstring
    mov eax,str_flex_bg
    call term_putstring
ext4_no_flex_bg:
    test dword [ext4_sb_feature_compat],COMPAT_SPARSE_SUPER2
    jz ext4_no_sparse_super2
    mov eax,str_sparse_super2
    call putstring
    mov eax,str_sparse_super2
    call term_putstring
ext4_no_sparse_super2:
    test dword [ext4_sb_feature_ro_compat],RO_COMPAT_HUGE_FILE
    jz ext4_no_hugefile
    mov eax,str_huge_file
    call putstring
    mov eax,str_huge_file
    call term_putstring
ext4_no_hugefile:
    test dword [ext4_sb_feature_ro_compat],RO_COMPAT_ORPHAN_PRESENT
    jz ext4_no_orphanfile
    mov eax,str_orphanfile
    call putstring
    mov eax,str_orphanfile
    call term_putstring
ext4_no_orphanfile:
    test dword [ext4_sb_feature_incompat],INCOMPAT_64BIT
    jz ext4_no_64bit
    mov eax,str_64bit
    call putstring
    mov eax,str_64bit
    call term_putstring
ext4_no_64bit:
    call newl
    mov bl,10
    call term_putchar
    call lcd_push
    
    enter ext4_DIR_s_length+256,0
    mov eax,2
    mov edi,ebp
    sub edi,ext4_DIR_s_length
    call ext4_open_dir
    cmp eax,0
    je ext4_mount_bad_root
    cmp dword [edi+ext4_DIR_dot_inode],2
    jne ext4_mount_bad_root
    cmp dword [edi+ext4_DIR_dotdot_inode],2
    jne ext4_mount_bad_root
    cmp dword [edi+ext4_FIL_position],0x18
    jne ext4_mount_bad_root

    mov eax,str_listing_root
    call putstring
    mov eax,str_listing_root+18
    call term_putinfo
    call ext4_debug_putspaces
    mov ebx,'.'
    call putchar
    call term_putchar
    mov eax,[edi+ext4_DIR_dot_inode]
    mov ecx,11
    call ext4_debug_print_inode
    call ext4_debug_putspaces
    mov ebx,'.'
    call putchar
    call putchar
    call term_putchar
    call term_putchar
    mov eax,[edi+ext4_DIR_dotdot_inode]
    mov ecx,10
    call ext4_debug_print_inode
    call lcd_push

    mov esi,edi
ext4_debug_loop:
    lea edi,[ebp-256-ext4_DIR_s_length]
    call ext4_dir_next
    cmp bx,0xFFFF
    je ext4_debug_loop_over
    cmp eax,0
    je ext4_mount_bad_root
    call ext4_debug_putspaces
    mov ecx,12
ext4_debug_printname:
    mov bl,[edi]
    inc edi
    cmp bl,0
    je ext4_debug_printname_over
    dec ecx
    call putchar
    call term_putchar
    jmp ext4_debug_printname
ext4_debug_printname_over:
    call ext4_debug_print_inode
    jmp ext4_debug_loop
ext4_debug_loop_over:
    leave

    ; Find file
    mov eax,2
    mov ebx,test_path
    call ext4_path_parser
    ; DEBUG: print inode number and file type
    call puthex
    call newl
    mov eax,ebx
    call puthex
    call newl
    
    xor al,al
    ret
ext4_bad_sb:
    mov eax,str_bad_sb
    call putstring
    mov eax,str_bad_sb+19
    call term_putfatal
    mov al,1
    ret
ext4_mount_bad_root:
    leave
    mov eax,str_bad_root
    call putstring
    mov eax,str_bad_root+19
    call term_putfatal
    mov al,1
    ret
ext4_incompat:
    mov eax,str_incompat
    call putstring
    mov eax,str_incompat+19
    call term_putfatal
    mov al,1
    ret

ext4_debug_putspaces:
    mov ebx,' '
    call putchar
    call putchar
    call putchar
    call putchar
    call term_putchar
    call term_putchar
    call term_putchar
    call term_putchar
    ret

ext4_debug_print_inode:
    test ecx,0x80000000
    jz ext4_debug_print_inode_spaces_okay
    mov ecx,1
ext4_debug_print_inode_spaces_okay:
    mov ebx,' '
    call putchar
    call term_putchar
    loop ext4_debug_print_inode_spaces_okay
    mov ebx,' '
    call putchar
    call term_putchar
    mov ebx,'-'
    call putchar
    call term_putchar
    mov ebx,'>'
    call putchar
    call term_putchar
    mov ebx,' '
    call putchar
    call term_putchar
    call puthex
    call term_puthex
    call newl
    mov ebx,10
    call term_putchar
    ret

str_invalid_mbr:
    db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Invalid MBR!",13,10,0
str_bad_partitions:
    db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Missing/invalid disk partitions!",13,10,0
str_bad_sb:
    db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Bad Superblock!",13,10,0
str_incompat:
    db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Incompatible FS features!",13,10,0
str_fs_flags:
    db '[',0x1B,"[1;34mINFO",0x1B,"[0m] FS Flags:",10,13,0
str_listing_root:
    db '[',0x1B,"[1;34mINFO",0x1B,"[0m] Root directory listing:",10,13,0
str_flex_bg:
    db "Flexible BGs | ",0
str_sparse_super2:
    db "Sparse SBs | ",0
str_huge_file:
    db "Huge files | ",0
str_orphanfile:
    db "Orphan file | ",0
str_64bit:
    db "64-bit | ",0
str_gdt_csum:
    db "GDT checksums | ",0
str_metadata_csum:
    db "Metadata csums | ",0
str_bad_eh_magic:
    db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Encountered bad extent header.",13,10,0
str_too_deep:
    db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] TOO DEEP!",13,10,0
str_dir_read_error:
    db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Error reading directory file!",13,10,0
str_dir_read_error_could_not_open:
    db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Error reading directory file (Could not open file)!",13,10,0
str_no_extents:
    db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Files not using extents not supported!",13,10,0
str_dir_bad_start:
    db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Bad directory start (missing/corrupted '.' and '..' entries).",13,10,0
str_bad_root:
    db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Bad root dir.",13,10,0
str_dir_unsupported:
    db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Directory trees are not supported.",13,10,0
str_fn_too_long:
    db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Filename too long.",13,10,0
str_symlinks_unsupported:
    db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] Symlinks are not supported.",13,10,0
test_path:
    db "images/something_idk.txt",0
