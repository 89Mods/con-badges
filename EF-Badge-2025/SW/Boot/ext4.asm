; Error codes
EXT4_OKAY equ 0
EXT4_LAST_EXTENT equ 1
EXT4_TOO_DEEP equ 2
EXT4_IO_ERR equ 3
EXT4_BLOCKS_TOO_BIG equ 4
EXT4_INVALID_MAGIC equ 5
EXT4_INCOMPAT equ 6
EXT4_INVALID_PARAMS equ 7
EXT4_CHECKSUM_BAD equ 8
EXT4_FILE_GAP equ 9
EXT4_EOF equ 10
EXT4_BAD_DIR_START equ 11
EXT4_BAD_ROOT_DIR equ 12
EXT4_BAD_DIR_TREE equ 13
EXT4_FILE_NOT_FOUND equ 15
EXT4_FN_TOO_LONG equ 16
EXT4_OUT_OF_BOUNDS equ 17

	SECTION EXT4
	PUBLIC ext4_open_read
	PUBLIC ext4_read
	PUBLIC ext4_mount
	PUBLIC ext4_partition_start
	PUBLIC ext4_partition_end
	PUBLIC ext4_partition_size
	PUBLIC ext4_blockbuff
	PUBLIC ext4_open_dir
	PUBLIC ext4_dir_next
	PUBLIC ext4_find_file
	PUBLIC ext4_FIL_s_length
	PUBLIC ext4_FIL_position
	PUBLIC ext4_FIL_limit
ext4_lbas_per_block equ 8
ext4_log_lbas_per_block equ 3
ext4_blocksize_bytes equ 4096
ext4_log_blocksize_bytes equ 12
ext4_blocksize_mask equ 0xFFF
ext4_max_etree_depth equ 4
ext4_max_fn equ 32

; Relevant Superblock FS flags
INCOMPAT_FILETYPE equ 0x0002
INCOMPAT_EXTENTS equ 0x0040
INCOMPAT_64BIT equ 0x0080
INCOMPAT_FLEX_BG equ 0x0200
INCOMPAT_CSUM_SEED equ 0x2000
COMPAT_SPARSE_SUPER2 equ 0x200
RO_COMPAT_HUGE_FILE equ 0x0008
RO_COMPAT_ORPHAN_PRESENT equ 0x10000
RO_COMPAT_GDT_CSUM equ 0x0010
RO_COMPAT_METADATA_CSUM equ 0x0400

; Inode struct organization
ext4_s_inode_length equ 100
ext4_inode_mode equ 0 ;u16
ext4_inode_links_count equ 2 ;u16
ext4_inode_uid equ 4 ;u32
ext4_inode_gid equ 8 ;u32
ext4_inode_flags equ 12 ;u32
ext4_inode_size equ 16 ;u64
ext4_inode_blocks equ 24 ;u64
ext4_inode_num equ 32 ;u64
ext4_inode_i_block equ 40 ;u8[60]
ext4_i_block_length equ 60
ext4_i_block_length_words equ 15 ;60/4

; Relevant Inode flags
EXT4_EXTENTS_FL equ 0x80000
EXT4_INDEX_FL equ 0x1000

; extent struct organization
ext4_s_extent_length equ 12
ext4_extent_ee_block equ 0 ;u32
ext4_extent_ee_len equ 4 ;u16
ext4_extent_ee_start_hi equ 6 ;u16
ext4_extent_ee_start_lo equ 8 ;u32

; extent index struct organization
ext4_s_extent_index_length equ 12
ext4_extent_index_ei_block equ 0 ;u32
ext4_extent_index_ei_leaf equ 4 ;u48
ext4_extent_index_ei_unused equ 10 ;u16

; etree entry struct organization
ext4_s_etree_entry_length equ 12
ext4_etree_entry_block equ 0 ;u64
ext4_etree_entry_curr_entry equ 8 ;u16
ext4_etree_entry_padding equ 10 ;u16

; FIL struct organization
ext4_FIL_s_length equ (32+ext4_s_extent_length+(ext4_s_etree_entry_length*ext4_max_etree_depth))
ext4_FIL_inum equ 0 ;u64
ext4_FIL_iflags equ 8 ;u32
ext4_FIL_position equ 12 ;u64
ext4_FIL_limit equ 20 ;u64
ext4_FIL_curr_extent equ 28 ;ext4_s_extent_length
ext4_FIL_path equ (28+ext4_s_extent_length) ;ext4_etree_entry[ext4_max_etree_depth]
ext4_FIL_curr_depth equ (28+ext4_s_extent_length+(ext4_s_etree_entry_length*ext4_max_etree_depth)) ;u32

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
	
	align 16
	; Reads one 4K block from SD card
	; Destination for the read is implicitely ext4_blockbuff
	; Args: block address
	; Returns error code (r23)
	; Uses: r1, r2, r3, r4, r5, r6, r7
ext4_read_block:
	subi r61, r61, 20 #
	sw r60, 4(r61) #
	sw r24, 8(r61)
	---
	sw r25, 12(r61) #
	sw r26, 16(r61) #
	sw r16, 20(r61)
	---
	xor r23, r23, r23
	lliu r2, ext4_lastblock&0xFFFF
	lui r2, ext4_lastblock>>16
	---
	lw r1, 0(r2) #
	be r16, r1, ext4_read_block_return
	slli r16, r16, 3
	---
	lliu r1, ext4_partition_start&0xFFFF
	lui r1, ext4_partition_start>>16 #
	lw r1, 0(r1)
	---
	add r16, r1, r16
	lliu r1, ext4_sb_first_data_block&0xFFFF
	lui r1, ext4_sb_first_data_block>>16 #
	---
	lw r1, 0(r1)
	lliu r26, ext4_blockbuff&0xFFFF
	lui r26, ext4_blockbuff>>16
	---
	slli r1, r1, 3 #
	add r16, r1, r16
	lliu r1, ext4_partition_end&0xFFFF
	---
	lui r1, ext4_partition_end>>16 #
	lliu r23, EXT4_OUT_OF_BOUNDS
	lw r1, 0(r1)
	---
	bge r16, r1, ext4_read_block_return
	addi r24, r16, 0
	liu r25, ext4_lbas_per_block-1
	---
	lli r1, -1 #
	sw r1, 0(r2)
	lliu r23, EXT4_IO_ERR
	---
ext4_read_block_loop:
	cpy r17, r24
	addi r24, r24, 1
	cpy r16, r26
	---
	lipc r60, zero #
	jalr r60, r60, (sdcard_read_block-$)>>4
	addi r26, r26, 512
	---
	bnez r2, ext4_read_block_return
	subi r25, r25, 1
	bnez r25, ext4_read_block_loop
	---
	lliu r23, EXT4_OKAY
	lliu r2, ext4_lastblock&0xFFFF
	lui r2, ext4_lastblock>>16
	---
	addi r24, r24, ext4_lbas_per_block #
	sw r24, 0(r2)
	---
ext4_read_block_return:
	lw r25, 12(r61) #
	lw r60, 4(r61) #
	lw r24, 8(r61)
	---
	lw r26, 16(r61) #
	lw r16, 20(r61) #
	addi r61, r61, 20
	---
	jalr zero, r60, 0
	---

	; Args: inode number
	; Returns pointer to inode data in ext4_blockbuff in r23 (or nullptr on error)
	; Uses: r1, r2, r3, r4, r5, r6, r7
ext4_inode_raw_pointer:
	sw r60, 0(r61) #
	sw r16, -4(r61)
	subi r61, r61, 8
	---
	subi r1, r16, 1
	lliu r2, ext4_vars_start&0xFFFF
	lui r2, ext4_vars_start>>16
	---
	lw r3, ext4_sb_inodes_per_group-ext4_vars_start(r2) #
	divu r4, r1, r3 ; Inode bgroup
	modu r3, r1, r3 ; Inode index
	---
	lw r5, ext4_sb_inode_size-ext4_vars_start(r2) #
	mulu r5, r3, r5 ; Inode address
	lw r1, ext4_sb_desc_size-ext4_vars_start(r2)
	---
	mulu r4, r1, r4 # ; Absolute address
	andi r4, r4, ext4_blocksize_mask ; Address in block
	srli r1, r4, ext4_log_blocksize_bytes ; Block address
	---
	; Need to backup some stuff
	sw r4, 0(r61) # ; Bgroup address in block
	sw r5, -4(r61) ; Inode address
	subi r61, r61, 8
	---
	; Read block containing relevant blockgroup
	addi r16, r1, 1
	lipc r60, zero #
	jalr r60, r60, (ext4_read_block-$)>>4
	---
	lw r4, 8(r61) # ; Bgroup address in block
	lw r5, 4(r61) ; Inode address
	addi r61, r61, 8
	---
	lliu r2, ext4_blockbuff&0xFFFF
	lui r2, ext4_blockbuff>>16 #
	add r2, r2, r4
	---
	; Return nullptr if blockgroup is uninitialized
	lb r1, 0x12(r2) #
	andi r1, r1, 1 #
	pnez p1, r1
	---
	xor r23, r23, r23 [p1]
	be r23, r23, ext4_raw_pointer_ret [p1]
	nop
	---
	srli r16, r5, ext4_log_blocksize_bytes
	lw r1, 0x08(r2) # ; bg_inode_table_lo
	lw r2, 0x28(r2) ; bg_inode_table_hi
	---
	; Technically we should form a 64-bit block address, but unless the SD card is over 16TiB, the entire high word’ll get discarded anyways
	add r16, r16, r1
	andi r5, r5, ext4_blocksize_mask #
	sw r5, 0(r61)
	---
	; Read from inode table for this group
	subi r61, r61, 4
	lipc r60, zero #
	jalr r60, r60, (ext4_read_block-$)>>4
	---
	lw r5, 4(r61)
	addi r61, r61, 4
	---
	; Compute final pointer to the requested inode
	lliu r23, ext4_blockbuff&0xFFFF
	lui r23, ext4_blockbuff>>16 #
	add r23, r23, r5
	---
ext4_raw_pointer_ret:
	lw r60, 8(r61) #
	lw r16, 4(r61)
	---
	addi r61, r61, 8
	jalr zero, r60, 0
	---
	
	; Args: inode raw pointer, inode struct pointer
	; Returns nothing
	; Uses: r1, r2, r3
ext4_parse_inode:
	lh r1, 0x00(r16) #
	sh r1, ext4_inode_mode(r17) #
	lh r1, 0x1A(r16)
	---
	sh r1, ext4_inode_links_count(r17) #
	lhu r1, 0x4+0x74(r16) #
	slli r1, r1, 16
	---
	lhu.l r1, 0x02(r16) #
	sw r1, ext4_inode_uid(r17) #
	lhu r1, 0x6+0x74(r16)
	---
	slli r1, r1, 16 #
	lhu.l r1, 0x18(r16) #
	---
	sw r1, ext4_inode_gid(r17) #
	lw r1, 0x20(r16) #
	sw r1, ext4_inode_flags(r17)
	---
	lw r1, 0x04(r16) #
	sw r1, ext4_inode_size(r17) #
	lw r1, 0x6C(r16)
	---
	sw r1, ext4_inode_size+4(r17) #
	lw r1, 0x1C(r16) #
	sw r1, ext4_inode_blocks(r17)
	---
	lhu r1, 0x0+0x74(r16) #
	sw r1, ext4_inode_blocks+4(r17) #
	---
	addi r1, r17, ext4_inode_i_block
	addi r2, r16, 0x28
	liu r3, ext4_i_block_length_words-1
	---
ext4_parse_inode_copy_loop:
	lw r4, 0(r2) #
	sw r4, 0(r1)
	addi r1, r1, 4
	---
	addi r2, r2, 4
	subi r3, r3, 1
	bnez r3, ext4_parse_inode_copy_loop
	---
	bez zero, ext4_parse_inode_done
	---

	; Args: inode number, inode struct pointer
	; Uses: r1, r2, r3, r4, r5, r6, r7
	; Clears r16 on error
	; TODO: needs to error out if inum is 0
ext4_read_inode:
	sw r60, 0(r61) #
	sw r17, -4(r61)
	subi r61, r61, 8
	---
	lipc r60, zero #
	jalr r60, r60, (ext4_inode_raw_pointer-$)>>4
	---
	lw r17, 4(r61)
	addi r61, r61, 4
	---
	cpy r1, r16
	cpy r16, r23
	bnez r23, ext4_read_inode_cont
	---
	liu r16, 0
	bez zero, ext4_read_inode_ret
	---
ext4_read_inode_cont:
	sw r1, ext4_inode_num(r17) #
	sw zero, ext4_inode_num+4(r17)
	nop
	---
	bez zero, ext4_parse_inode
	---
ext4_parse_inode_done:
ext4_read_inode_ret:
	lw r60, 4(r61) #
	addi r61, r61, 4
	jalr zero, r60, 0
	---

	; Args: ext4_FIL struct pointer
	; Returns: success status (r17)
	; Uses: r1, r2, r3, r4, r5, r6, r7
ext4_find_next_extent:
	subi r61, r61, 16 #
	sw r60, 16(r61) #
	sw r24, 12(r61)
	---
	sw r25, 8(r61) #
	sw r26, 4(r61) #
	liu r17, EXT4_OKAY
	---
	cpy r24, r16 ; r24 holds struct pointer
	---
ext4_find_extent_recurse:
	lw r2, ext4_FIL_curr_depth(r24) #
	muliu r1, r2, ext4_s_etree_entry_length #
	addi r1, r1, ext4_FIL_path
	---
	add r25, r24, r1 # ; r25 = ext4_etree_entry*
	lw r1, ext4_etree_entry_block(r25)
	lli r2, -1
	---
	bne r1, r2, ext4_find_extent_in_block
	lw r1, ext4_etree_entry_block+4(r25) #
	bne r1, r2, ext4_find_extent_in_block
	---
	; Its in the Inode’s i_block, so the inode needs to be accessed
	liu r26, 0
	lw r16, ext4_FIL_inum(r24)
	---
	lipc r60, zero #
	jalr r60, r60, (ext4_inode_raw_pointer-$)>>4
	---
	bez r23, ext4_find_extent_io_err
	addi r23, r23, 0x28
	bez zero, ext4_found_extent_in_iblock
	---
ext4_find_extent_in_block:
	; Its in a dedicated block, so load that block
	lw r16, ext4_etree_entry_block(r25)
	lipc r60, zero #
	jalr r60, r60, (ext4_read_block-$)>>4
	---
	bnez r23, ext4_find_extent_io_err
	---
	liu r26, 1
	lliu r23, ext4_blockbuff&0xFFFF
	lui r23, ext4_blockbuff>>16
	---
ext4_found_extent_in_iblock:
	; r23 now contains pointer to extent header
	lhu r1, ext4_extent_header_magic(r23) #
	subi r1, r1, 0xF30A
	---
	lliu r16, str_bad_eh_magic&0xFFFF
	lui r16, str_bad_eh_magic>>16
	bez r1, ext4_find_extent_good_eh
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	cpy r16, r24
	liu r17, EXT4_INVALID_MAGIC
	bez zero, ext4_find_extent_ret
	---
ext4_find_extent_good_eh:
	cpy r16, r24
	lhu r1, ext4_extent_header_entries(r23) #
	subi r1, r1, 1
	---
	lhu r3, ext4_extent_header_depth(r23) #
	lhu r2, ext4_etree_entry_curr_entry(r25) #
	be r1, r2, ext4_find_extent_last_in_list
	---
	addi r2, r2, 1 #
	andi r2, r2, 0xFFFF
	---
	sw r2, ext4_etree_entry_curr_entry(r25)
	muliu r1, r2, 12
	---
	add r23, r23, r1 #
	addi r23, r23, ext4_extent_header_s_length
	; r23 now points to the extent entry required
	bnez r3, ext4_find_extent_hit_interior_node
	---
	; Cache the whole extent entry to the FIL struct - for later
	lw r1, 0(r23) #
	sw r1, ext4_FIL_curr_extent(r16) #
	lw r1, 4(r23)
	---
	sw r1, ext4_FIL_curr_extent+4(r16) #
	lw r1, 8(r23) #
	sw r1, ext4_FIL_curr_extent+8(r16)
	---
	liu r17, EXT4_OKAY
	---
ext4_find_extent_ret:
	lw r26, 4(r61) #
	lw r25, 8(r61) #
	lw r24, 12(r61)
	---
	lw r60, 16(r61) #
	addi r61, r61, 16
	jalr zero, r60, 0
	---
ext4_find_extent_last_in_list:
	pez p1, r26 #
	liu r17, EXT4_LAST_EXTENT [p1]
	bez zero, ext4_find_extent_ret [p1]
	---
ext4_find_extent_not_last:
	; Go up one level
	lw r2, ext4_FIL_curr_depth(r16) #
	subi r2, r2, 1 #
	sw r1, ext4_FIL_curr_depth(r16)
	---
	bez zero, ext4_find_extent_recurse
	---
ext4_find_extent_hit_interior_node:
	lw r3, ext4_FIL_curr_depth(r16) #
	addi r3, r3, 1 #
	sw r3, ext4_FIL_curr_depth(r16)
	---
	subi r1, r3, ext4_max_etree_depth #
	bn r1, ext4_find_extent_not_too_deep
	---
	lliu r16, str_too_deep&0xFFFF
	lui r16, str_too_deep>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	cpy r16, r24
	liu r17, EXT4_TOO_DEEP
	bez zero, ext4_find_extent_ret
	---
ext4_find_extent_not_too_deep:
	muliu r1, r3, ext4_s_etree_entry_length #
	addi r1, r1, ext4_FIL_path #
	add r25, r16, r1 ; r25 = ext4_etree_entry*
	---
	lli r1, -1 #
	sw r1, ext4_etree_entry_curr_entry(r25) #
	lw r1, ext4_extent_header_s_length+ext4_extent_index_ei_leaf(r23)
	---
	sw r1, ext4_etree_entry_block(r25) #
	lh r1, ext4_extent_header_s_length+ext4_extent_index_ei_leaf+4(r23) #
	sw r1, ext4_etree_entry_block+4(r25)
	---
	bez zero, ext4_find_extent_recurse
	---
ext4_find_extent_io_err:
	lliu r16, str_io_error&0xFFFF
	lui r16, str_io_error>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	cpy r16, r24
	liu r17, EXT4_IO_ERR
	bez zero, ext4_find_extent_ret
	---
	
	; Args: inode number, ext4_FIL pointer
	; Returns: success status (r18)
	; Uses: r1, r2, r3, r4, r5, r6, r7
ext4_open_read:
	subi r61, r61, 16+ext4_s_inode_length #
	sw r60, ext4_s_inode_length+16(r61) #
	sw r24, ext4_s_inode_length+12(r61)
	---
	sw r25, ext4_s_inode_length+8(r61) #
	sw r26, ext4_s_inode_length+4(r61)
	addi r26, r61, 4 ; r26 points to the ext4_inode struct
	---
	cpy r24, r16
	cpy r25, r17 ; r25 now contains ext4_FIL pointer
	---
	cpy r17, r26
	lipc r60, zero #
	jalr r60, r60, (ext4_read_inode-$)>>4
	---
	liu r18, EXT4_IO_ERR
	bez r16, ext4_open_read_ret
	lw r2, ext4_inode_flags(r26)
	---
	andi r1, r2, EXT4_EXTENTS_FL #
	bnez r1, ext4_open_has_extents
	lliu r16, str_no_extents&0xFFFF
	---
	lui r16, str_no_extents>>16
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	liu r18, EXT4_INCOMPAT
	bez zero, ext4_open_read_ret
	---
ext4_open_has_extents:
	lhu r1, ext4_inode_i_block+ext4_extent_header_magic(r26) #
	subi r1, r1, 0xF30A #
	bez r1, ext4_open_read_h_okay
	---
	lliu r16, str_bad_eh_magic&0xFFFF
	lui r16, str_bad_eh_magic>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	liu r18, EXT4_INVALID_MAGIC
	bez zero, ext4_open_read_ret
	---
ext4_open_read_h_okay:
	subi r1, zero, 1 #
	sw r1, ext4_FIL_path+ext4_etree_entry_block(r25) #
	sw r1, ext4_FIL_path+ext4_etree_entry_block+4(r25)
	---
	sh r1, ext4_FIL_path+ext4_etree_entry_curr_entry(r25) #
	lw r1, ext4_inode_num(r26) #
	sw r1, ext4_FIL_inum(r25)
	---
	lw r1, ext4_inode_num+4(r26) #
	sw r1, ext4_FIL_inum+4(r25) #
	sw r2, ext4_FIL_iflags(r25)
	---
	sw zero, ext4_FIL_position(r25) #
	sw zero, ext4_FIL_position+4(r25) #
	sw zero, ext4_FIL_curr_depth(r25)
	---
	lw r1, ext4_inode_size(r26) #
	sw r1, ext4_FIL_limit(r25) #
	lw r1, ext4_inode_size+4(r26)
	---
	sw r1, ext4_FIL_limit+4(r25) #
	lh r1, ext4_inode_i_block+ext4_extent_header_entries(r26) #
	bez r1, ext4_open_read_skip ; Empty file - do nothing more
	---
	cpy r16, r25
	lipc r60, zero #
	jalr r60, r60, (ext4_find_next_extent-$)>>4
	---
	cpy r18, r17
	subi r17, r17, EXT4_OKAY #
	pez p1, r17
	---
	liu r18, EXT4_OKAY [p1]
	---
ext4_open_read_ret:
	cpy r17, r25
	cpy r16, r24
	addi r61, r61, ext4_s_inode_length
	---
	lw r60, 16(r61) #
	lw r24, 12(r61) #
	lw r25, 8(r61)
	---
	lw r26, 4(r61)
	addi r61, r61, 16
	jalr zero, r60, 0
	---
ext4_open_read_skip:
	cpy r1, r1
	liu r18, EXT4_OKAY
	bez zero, ext4_open_read_ret
	---

	; Args: ext4_FIL pointer, buffer pointer, no. bytes to be read
	; Returns: success status (r19), no. bytes read (r20)
	; Uses: r1, r2, r3, r4, r5, r6, r7
	; if the buffer pointer is null, nothing will be written to memory and this function acts as a skip
ext4_read:
	subi r61, r61, 28 #
	sw r60, 28(r61) #
	sw r24, 24(r61)
	---
	sw r25, 20(r61) #
	sw r26, 16(r61) #
	sw r27, 12(r61)
	---
	sw r28, 8(r61) #
	sw r29, 4(r61)
	---
	xor r20, r20, r20
	liu r19, EXT4_OKAY
	lw r1, ext4_FIL_position+4(r16)
	---
	lw r2, ext4_FIL_limit+4(r16) #
	bg r1, r2, ext4_read_ret
	bne r1, r2, ext4_read_skp
	---
	lw r1, ext4_FIL_position(r16) #
	lw r2, ext4_FIL_limit(r16) #
	bge r1, r2, ext4_read_ret
	---
ext4_read_skp:
	bez r18, ext4_read_ret
	liu r24, 0
	liu r25, 1
	---
	; r24 = i
	; r25 = flag
	; r26 = extent_block
	; r27 = block_pos
	; r28 = ext_len
	; r29 = block
ext4_read_loop:
	bge r24, r18, ext4_read_ret
	bez r25, ext4_read_not_flag
	---
ext4_read_flag:
	liu r25, 0
	lh r28, ext4_FIL_curr_extent+ext4_extent_ee_len(r16) #
	subi r2, r28, 32768
	---
	; ee_len <= 32768 ? ee_len : ee_len - 32768
	pgs p1, r2, r0 #
	lw r1, ext4_FIL_curr_extent+ext4_extent_ee_block(r16)
	subi r28, r28, 32768 [p1]
	---
	; temp = ee_block * blocksize
	mulhiu r2, r1, ext4_blocksize_bytes
	muliu r1, r1, ext4_blocksize_bytes #
	lw r6, ext4_FIL_position(r16)
	---
	; temp = position - temp
	; 64-bit subtract, gets a bit weird since no carry flag
	lw r7, ext4_FIL_position+4(r16)
	sub r1, r6, r1
	pg p1, r1, r6
	---
	sub r2, r7, r2 #
	subi r2, r2, 1 [p1]
	---
	andi r27, r1, ext4_blocksize_mask ; block_pos = temp % blocksize
	; 64-bit right-shift, also a bit weird
	srli r1, r1, ext4_log_blocksize_bytes
	slli r3, r2, 32-ext4_log_blocksize_bytes
	---
	or r1, r1, r3
	srli r2, r2, ext4_log_blocksize_bytes #
	cpy r26, r1 ; extent_block = temp / blocksize
	---
	; Read from ee_start + extent_block
	lw r29, ext4_FIL_curr_extent+ext4_extent_ee_start_lo(r16) #
	add r29, r26, r29
	subi r61, r61, 12
	---
	sw r16, 12(r61) #
	sw r17, 8(r61) #
	sw r18, 4(r61)
	---
	cpy r16, r29
	lipc r60, zero #
	jalr r60, r60, (ext4_read_block-$)>>4
	---
	lw r16, 12(r61) #
	lw r17, 8(r61) #
	lw r18, 4(r61)
	---
	addi r61, r61, 12
	cpy r19, r23
	bnez r23, ext4_read_ret
	---
ext4_read_not_flag:
	; diff = limit - position
	lw r1, ext4_FIL_limit(r16) #
	lw r2, ext4_FIL_limit+4(r16) #
	lw r3, ext4_FIL_position(r16)
	---
	lw r4, ext4_FIL_position+4(r16)
	sub r1, r1, r3
	pg p1, r3, r1
	---
	sub r2, r2, r4 #
	subi r2, r2, 1 [p1]
	liu r3, ext4_blocksize_bytes
	---
	sub r3, r3, r27 ; max_copy
	sub r4, r18, r24 # ; remaining
	pl p1, r1, r4
	---
	cpy r4, r1 [p1]
	pl p1, r3, r4 #
	cpy r4, r3 [p1]
	---
	; memcpy(buff, ext4_blockbuff + block_pos, remaining);
	cpy r1, r4
	lliu r2, ext4_blockbuff&0xFFFF
	---
	lui r2, ext4_blockbuff>>16 #
	add r2, r2, r27
	bez r17, ext4_read_skip
	---
	; TODO: use word loads/stores
	nop
	lli r6, 1 #
	sw r6, ICEN(r62) ; Enable icache
	---
ext4_read_copy_loop: ; implicitely: buff += remaining
	lb r3, 0(r2)
	subi r1, r1, 1
	addi r17, r17, 1
	---
	sb r3, -1(r17)
	addi r2, r2, 1
	bnez r1, ext4_read_copy_loop
	---
	nop
	lli r6, 0 #
	sw r6, ICEN(r62) ; Disable icache
	---
ext4_read_skip:
	add r27, r27, r4 ; block_pos += remaining
	; position += remaining
	lw r1, ext4_FIL_position(r16) #
	lw r2, ext4_FIL_position+4(r16)
	---
	lli r3, -1 #
	sub r3, r3, r1 #
	pg p1, r4, r3
	---
	addi r2, r2, 1 [p1]
	add r1, r1, r4 #
	sw r1, ext4_FIL_position(r16)
	---
	sw r2, ext4_FIL_position+4(r16)
	add r20, r20, r4 ; read += remaining
	add r24, r24, r4 ; i += remaining
	---
	; Return if position >= limit
	lw r4, ext4_FIL_limit+4(r16) #
	lw r3, ext4_FIL_limit(r16)
	bg r2, r4, ext4_read_ret
	---
	be r2, r4, ext4_read_skp2
	bge r1, r3, ext4_read_ret
	---
ext4_read_skp2:
	liu r1, ext4_blocksize_bytes #
	bl r27, r1, ext4_read_loop
	---
	; if(block_pos >= blocksize)
	addi r26, r26, 1
	xor r27, r27, r27
	addi r29, r29, 1
	---
	bge r26, r28, ext4_read_case1
	bl r24, r18, ext4_read_case2
	bez zero, ext4_read_loop
	---
ext4_read_case1: ; if(extent_block >= ext_len)
	subi r61, r61, 20 #
	sw r16, 20(r61) #
	sw r17, 16(r61)
	---
	sw r18, 12(r61) #
	sw r19, 8(r61) #
	sw r20, 4(r61)
	---
	lipc r60, zero #
	jalr r60, r60, (ext4_find_next_extent-$)>>4
	---
	cpy r1, r17
	lw r18, 12(r61)
	lw r17, 16(r61) #
	---
	lw r16, 20(r61) #
	lw r19, -8(r61) #
	lw r20, 4(r61)
	---
	addi r61, r61, 20
	liu r2, EXT4_LAST_EXTENT
	---
	be r1, r2, ext4_read_ret
	liu r25, 1
	bez r1, ext4_read_loop
	---
	cpy r19, r1
	bez zero, ext4_read_ret
	---
ext4_read_case2: ; else if(i < count)
	subi r61, r61, 12 #
	sw r16, 12(r61) #
	sw r17, 8(r61)
	---
	sw r18, 4(r61)
	cpy r16, r29
	---
	lipc r60, zero #
	jalr r60, r60, (ext4_read_block-$)>>4
	---
	lw r18, 4(r61) #
	lw r17, 8(r61) #
	lw r16, 12(r61)
	---
	addi r61, r61, 12
	cpy r19, r23
	bez r23, ext4_read_loop
	---
ext4_read_ret:
	lw r29, 4(r61) #
	lw r28, 8(r61) #
	lw r27, 12(r61)
	---
	lw r26, 16(r61) #
	lw r25, 20(r61) #
	lw r24, 24(r61)
	---
	lw r60, 28(r61) #
	addi r61, r61, 28
	jalr zero, r60, 0
	---

	; Args: inode number, ext4_DIR pointer
	; Returns: success status (r18)
	; Uses: r1, r2, r3, r4, r5, r6, r7
ext4_open_dir:
	subi r61, r61, 16 #
	sw r60, 16(r61) #
	sw r24, 12(r61)
	---
	sw r25, 8(r61) #
	sw r26, 4(r61)
	---
	subi r61, r61, ext4_dir_entry2_s_length+4
	subi r26, r61, ext4_dir_entry2_s_length ; data buffer pointer
	cpy r25, r16
	---
	cpy r24, r17 ; ext4_DIR pointer
	lipc r60, zero #
	jalr r60, r60, (ext4_open_read-$)>>4
	---
	bnez r18, ext4_open_dir_ret
	cpy r16, r24
	cpy r17, r26
	---
	liu r18, ext4_dir_entry2_s_length+4
	lipc r60, zero #
	jalr r60, r60, (ext4_read-$)>>4
	---
	cpy r18, r19
	bnez r19, ext4_open_dir_ret
	lhu r1, ext4_dir_entry2_name_len(r26)
	---
	subi r1, r1, 0x0201 # ; Check file_type and name_len at the same time
	liu r18, EXT4_BAD_DIR_START
	bnez r1, ext4_open_dir_ret_bad_dot
	---
	lhu r1, ext4_dir_entry2_s_length(r26) #
	subi r1, r1, 0x002E # ; '.'
	bnez r1, ext4_open_dir_ret_bad_dot
	---
	lw r1, ext4_dir_entry2_inode(r26) #
	sw r1, ext4_DIR_dot_inode(r24)
	liu r18, ext4_dir_entry2_s_length+4
	---
	cpy r16, r24
	cpy r17, r26
	---
	lipc r60, zero #
	jalr r60, r60, (ext4_read-$)>>4
	---
	cpy r18, r19
	bnez r19, ext4_open_dir_ret
	lhu r1, ext4_dir_entry2_name_len(r26)
	---
	subi r1, r1, 0x0202 # ; Check file_type and name_len at the same time
	liu r18, EXT4_BAD_DIR_START
	bnez r1, ext4_open_dir_ret_bad_dot
	---
	lhu r1, ext4_dir_entry2_s_length(r26) #
	subi r1, r1, 0x2E2E # ; '..'
	bnez r1, ext4_open_dir_ret_bad_dot
	---
	lhu r1, ext4_dir_entry2_s_length+2(r26) #
	bnez r1, ext4_open_dir_ret
	---
	lw r1, ext4_dir_entry2_inode(r26) #
	sw r1, ext4_DIR_dotdot_inode(r24)
	---
	cpy r16, r25
	cpy r17, r24
	---
	lipc r60, zero #
	jalr r60, r60, (ext4_open_read-$)>>4
	---
ext4_open_dir_ret:
	cpy r16, r25
	cpy r17, r24
	addi r61, r61, ext4_dir_entry2_s_length+4
	---
	lw r60, 16(r61) #
	lw r24, 12(r61) #
	lw r25, 8(r61)
	---
	lw r26, 4(r61)
	addi r61, r61, 16
	jalr zero, r60, 0
	---
ext4_open_dir_ret_bad_dot:
	lliu r16, str_dir_bad_start&0xFFFF
	lui r16, str_dir_bad_start>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	bez zero, ext4_open_dir_ret
	---

	; Args: ext4_DIR pointer, name buffer pointer
	; Returns: inode number (r18), file type (r19), error code (r20)
	; Uses: r1, r2, r3, r4, r5, r6, r7
	; name buffer pointer may be null, in which case the name will not be returned
ext4_dir_next:
	subi r61, r61, 16 #
	sw r60, 16(r61) #
	sw r40, 12(r61)
	---
	sw r41, 8(r61) #
	sw r42, 4(r61)
	---
	subi r61, r61, 268
	subi r40, r61, 264 ; Data buff pointer
	---
	cpy r41, r16 ; ext4_DIR pointer
	cpy r42, r17 ; name buffer pointer
	---
ext4_dir_next_loop:
	lw r1, ext4_FIL_limit+4(r41) #
	lw r2, ext4_FIL_position+4(r41) #
	bne r1, r2, ext4_dir_loop_cont
	---
	lw r1, ext4_FIL_limit(r41) #
	lw r2, ext4_FIL_position(r41) #
	sub r1, r1, r2
	---
	liu r20, EXT4_EOF
	subi r1, r1, 12 #
	bn r1, ext4_dir_next_ret
	---
ext4_dir_loop_cont:
	cpy r16, r41
	cpy r17, r40
	liu r18, ext4_dir_entry2_s_length
	---
	lipc r60, zero #
	jalr r60, r60, (ext4_read-$)>>4
	---
	subi r1, r20, ext4_dir_entry2_s_length
	liu r20, EXT4_BAD_DIR_TREE #
	bnez r1, ext4_dir_next_ret
	---
	cpy r20, r19
	bnez r19, ext4_dir_next_ret
	---
	lw r1, ext4_dir_entry2_inode(r40) #
	bez r1, ext4_dir_next_loop
	---
	lbu r18, ext4_dir_entry2_name_len(r40) #
	cpy r16, r41
	---
	cpy r17, r42
	lipc r60, zero #
	jalr r60, r60, (ext4_read-$)>>4
	---
	cpy r20, r19
	bnez r19, ext4_dir_next_ret
	bez r42, ext4_dir_next_no_name
	---
	; Zero-pad at end of string to ensure its always null-terminated
	lbu r1, ext4_dir_entry2_name_len(r40) #
	add r2, r1, r42 #
	sb zero, 0(r2)
	---
	; Skip remaining bytes in record
	lhu r2, ext4_dir_entry2_rec_len(r40) #
	sub r2, r2, r1 #
	subi r18, r2, ext4_dir_entry2_s_length
	---
	cpy r16, r41
	xor r17, r1, r1
	---
	lipc r60, zero #
	jalr r60, r60, (ext4_read-$)>>4
	---
ext4_dir_next_no_name:
	lbu r19, ext4_dir_entry2_file_type(r40) #
	lw r18, ext4_dir_entry2_inode(r40)
	liu r20, EXT4_OKAY
	---
ext4_dir_next_ret:
	lw r60, 268+16(r61) #
	lw r40, 268+12(r61) #
	lw r41, 268+8(r61)
	---
	addi r61, r61, 268+16
	lw r42, 268+4(r61)
	jalr zero, r60, 0
	---

	; Args: curr inode, path str pointer
	; Returns: inode number (r18), file type (r19), error code (r20)
	; Uses: r1, r2, r3, r4, r5, r6, r7
ext4_path_parser:
	subi r61, r61, 32 #
	sw r60, 32(r61) #
	sw r40, 28(r61)
	---
	sw r41, 24(r61) #
	sw r42, 20(r61) #
	sw r30, 16(r61)
	---
	sw r31, 12(r61) #
	sw r32, 8(r61) #
	sw r35, 4(r61)
	---
	subi r35, r61, ext4_max_fn+ext4_max_fn+ext4_DIR_s_length-4 ; ext4_DIR_s
	cpy r40, r17 ; path str pointer
	---
	subi r61, r61, ext4_max_fn+ext4_max_fn+ext4_DIR_s_length
	subi r41, r61, ext4_max_fn-4 ; substr
	subi r42, r61, ext4_max_fn+ext4_max_fn-4 ; next_name
	---
	xor r1, r1, r1 ; i
	cpy r4, r40 ; path[i]
	cpy r5, r41 ; substr[i]
	---
	liu r30, 0 ; the_end
	liu r31, 0 ; strlen
	liu r32, 0 ; should_be_dir
	---
ext4_path_parse_loop:
	subi r2, r1, ext4_max_fn-1 #
	bnez r2, ext4_path_parse_loop_cont
	lbu r3, 0(r4)
	---
	bez r3, ext4_path_parse_loop_cont
	---
	liu r20, EXT4_FN_TOO_LONG
	subi r2, r3, '/' #
	bnez r2, ext4_path_parser_ret
	---
ext4_path_parse_loop_cont:
	lbu r3, 0(r4) #
	subi r3, r3, '/' #
	bnez r3, ext4_parse_cond0
	---
	liu r32, 1
	lbu r3, 1(r4) #
	pez p1, r3
	---
	liu r30, 1 [p1]
	bez zero, ext4_path_parse_loop_done
	---
ext4_parse_cond0:
	lbu r3, 0(r4) #
	bnez r3, ext4_parse_cond1
	---
	pez p1, zero
	liu r30, 1
	bez zero, ext4_path_parse_loop_done
	---
ext4_parse_cond1:
	addi r31, r31, 1
	sb r3, 0(r5)
	addi r1, r1, 1
	---
	addi r4, r4, 1
	addi r5, r5, 1
	bez zero, ext4_path_parse_loop
	---
ext4_path_parse_loop_done:
	cpy r17, r35
	lipc r60, zero #
	jalr r60, r60, (ext4_open_dir-$)>>4
	---
	cpy r20, r18
	bnez r18, ext4_path_parser_ret
	subi r1, r31, 1
	---
	bnez r1, ext4_path_parser_not_dot
	---
	lbu r1, 0(r41) #
	subi r1, r1, '.' #
	bnez r1, ext4_path_parser_not_dot
	---
	lw r18, ext4_DIR_dot_inode(r35)
	liu r19, 2
	bez zero, ext4_parse_cond2
	---
ext4_path_parser_not_dot:
	subi r1, r31, 2 #
	bnez r1, ext4_path_parser_not_dotdot
	---
	lbu r1, 0(r41) #
	subi r1, r1, '.' #
	bnez r1, ext4_path_parser_not_dotdot
	---
	lbu r1, 1(r41) #
	subi r1, r1, '.' #
	bnez r1, ext4_path_parser_not_dotdot
	---
	lw r18, ext4_DIR_dotdot_inode(r35)
	liu r19, 2
	bez zero, ext4_parse_cond2
	---
ext4_path_parser_not_dotdot:
ext4_path_parser_search_loop:
	cpy r16, r35
	cpy r17, r42
	---
	lipc r60, zero #
	jalr r60, r60, (ext4_dir_next-$)>>4
	---
	subi r1, r20, EXT4_EOF #
	pez p1, r1
	liu r2, 0 ; i
	---
	liu r20, EXT4_FILE_NOT_FOUND [p1]
	bnez r20, ext4_path_parser_ret
	liu r1, 1 ; found
	---
	cpy r3, r42 ; next_name[i]
	cpy r4, r41 ; substr[i]
	---
ext4_path_parser_comp_loop:
	lbu r5, 0(r3) #
	lbu r6, 0(r4) #
	bez r5, ext4_path_parser_comp_loop_fail
	---
	be r5, r6, ext4_path_parser_comp_loop_continue
	---
ext4_path_parser_comp_loop_fail:
	liu r1, 0
	bez zero, ext4_path_parser_comp_loop_done
	---
ext4_path_parser_comp_loop_continue:
	sub r5, r31, r2 #
	bne r5, r1, ext4_path_parser_comp_loop_cond
	---
	lbu r5, 1(r3) #
	bez r5, ext4_path_parser_comp_loop_done
	---
ext4_path_parser_comp_loop_cond:
	addi r2, r2, 1
	addi r3, r3, 1
	sub r5, r2, r31
	---
	addi r4, r4, 1
	bnez r5, ext4_path_parser_comp_loop
	---
ext4_path_parser_comp_loop_done:
	bez r1, ext4_path_parser_search_loop
	bez r32, ext4_parse_cond2
	subi r5, r19, 2
	---
	bnez r5, ext4_path_parser_ret
	liu r20, EXT4_FILE_NOT_FOUND
	---
ext4_parse_cond2:
	liu r20, EXT4_INCOMPAT
	subi r5, r19, 7 #
	bez r5, ext4_path_parser_ret
	---
	liu r20, EXT4_OKAY
	bnez r30, ext4_path_parser_ret
	cpy r16, r18
	---
	addi r61, r61, ext4_max_fn+ext4_max_fn+ext4_DIR_s_length
	add r17, r40, r31 #
	addi r17, r17, 1
	---
	lipc r60, zero #
	jalr r60, r60, (ext4_path_parser-$)>>4
	---
	subi r61, r61, ext4_max_fn+ext4_max_fn+ext4_DIR_s_length
	---
ext4_path_parser_ret:
	addi r61, r61, ext4_max_fn+ext4_max_fn+ext4_DIR_s_length #
	lw r60, 32(r61) #
	lw r40, 28(r61)
	---
	lw r41, 24(r61) #
	lw r42, 20(r61) #
	lw r30, 16(r61)
	---
	lw r31, 12(r61) #
	lw r32, 8(r61) #
	lw r35, 4(r61)
	---
	addi r61, r61, 32
	jalr zero, r60, 0
	---

	; Args: path str pointer
	; Returns: inode number (r18), file type (r19), error code (r20)
	; Uses: r1, r2, r3, r4, r5, r6, r7
ext4_find_file:
	lb r1, 0(r16) #
	subi r1, r1, '/' #
	bnez r1, ext4_find_file_ret
	---
	addi r17, r16, 1
	liu r16, 2
	bez zero, ext4_path_parser
	---
ext4_find_file_ret:
	liu r20, EXT4_FILE_NOT_FOUND
	jalr zero, r60, 0
	---

	; Args: none
	; Returns: error code (r16)
	; Uses: r1, r2, r3, r4, r5, r6, r7
ext4_mount:
	subi r61, r61, 16 #
	sw r24, 16(r61) #
	sw r60, 12(r61)
	---
	sw r25, 8(r61) #
	sw r26, 4(r61)
	---
	
	liu r1, 0
	lliu r24, ext4_vars_start&0xFFFF
	lui r24, ext4_vars_start>>16
	---
	sw r1, ext4_sb_first_data_block-ext4_vars_start(r24)
	lli r1, -1 #
	sw r1, ext4_lastblock-ext4_vars_start(r24)
	---
	
	liu r16, 0
	lipc r60, zero #
	jalr r60, r60, (ext4_read_block-$)>>4
	---
	cpy r16, r23
	bnez r23, ext4_mount_bad_sb_ret
	lliu r3, (ext4_blockbuff+1024)&0xFFFF
	---
	lui r3, (ext4_blockbuff+1024)>>16 #
	lw r1, 0x14(r3) #
	sw r1, ext4_sb_first_data_block-ext4_vars_start(r24)
	---
	liu r16, EXT4_BLOCKS_TOO_BIG
	lw r1, 0x18(r3) #
	subi r1, r1, 2
	---
	bnez r1, ext4_mount_bad_sb_ret
	lw r1, 0x28(r3) #
	sw r1, ext4_sb_inodes_per_group-ext4_vars_start(r24)
	---
	lh r1, 0x58(r3) #
	sw r1, ext4_sb_inode_size-ext4_vars_start(r24) #
	lh r1, 0xFE(r3)
	---
	sw r1, ext4_sb_desc_size-ext4_vars_start(r24) #
	subi r1, r1, 64 #
	bnez r1, ext4_mount_incompat_ret
	---
	lw r1, 0x20(r3) #
	sw r1, ext4_sb_blocks_per_group-ext4_vars_start(r24)
	---
	lw r5, 0x5C(r3) # ; s_feature_compat
	lw r6, 0x60(r3) # ; s_feature_incompat
	lw r7, 0x64(r3)   ; s_feature_ro_compat
	---
	sw r5, ext4_sb_feature_compat-ext4_vars_start(r24) #
	sw r6, ext4_sb_feature_incompat-ext4_vars_start(r24) #
	sw r7, ext4_sb_feature_ro_compat-ext4_vars_start(r24)
	---
	lhu r1, 0x38(r3) #
	xori r1, r1, 0xEF53
	liu r16, EXT4_INVALID_MAGIC
	---
	lli r2, ~(INCOMPAT_FILETYPE|INCOMPAT_EXTENTS|INCOMPAT_64BIT|INCOMPAT_FLEX_BG|INCOMPAT_CSUM_SEED)
	---
	bnez r1, ext4_mount_bad_sb_ret
	and r1, r6, r2 #
	bnez r1, ext4_mount_incompat_ret
	---
	andi r1, r6, INCOMPAT_EXTENTS #
	bez r1, ext4_mount_incompat_ret
	---
	andi r1, r6, INCOMPAT_64BIT #
	bez r1, ext4_mount_incompat_ret
	---
	lliu r16, str_fs_flags&0xFFFF
	lui r16, str_fs_flags>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	nop
	---
	andi r1, r7, RO_COMPAT_METADATA_CSUM #
	bez r1, ext4_no_metadata_csum
	---
	
ext4_no_metadata_csum:
	andi r1, r7, RO_COMPAT_GDT_CSUM #
	bez r1, ext4_no_gdt_csum
	lliu r16, str_metadata_csum&0xFFFF
	---
	lui r16, str_metadata_csum>>16
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
ext4_no_gdt_csum:
	andi r1, r6, INCOMPAT_FLEX_BG #
	bez r1, ext4_no_flex_bg
	lliu r16, str_gdt_csum&0xFFFF
	---
	lui r16, str_gdt_csum>>16
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
ext4_no_flex_bg:
	andi r1, r5, COMPAT_SPARSE_SUPER2 #
	bez r1, ext4_no_sparse_super2
	lliu r16, str_sparse_super2&0xFFFF
	---
	lui r16, str_sparse_super2>>16
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
ext4_no_sparse_super2:
	andi r1, r7, RO_COMPAT_HUGE_FILE #
	bez r1, ext4_no_huge_file
	lliu r16, str_huge_file&0xFFFF
	---
	lui r16, str_huge_file>>16
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
ext4_no_huge_file:
	andi r1, r7, RO_COMPAT_ORPHAN_PRESENT #
	bez r1, ext4_no_orphanfile
	lliu r16, str_orphanfile&0xFFFF
	---
	lui r16, str_orphanfile>>16
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
ext4_no_orphanfile:
	andi r1, r6, INCOMPAT_64BIT #
	bez r1, ext4_no_64bit
	lliu r16, str_64bit&0xFFFF
	---
	lui r16, str_64bit>>16
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
ext4_no_64bit:
	lipc r60, zero #
	jalr r60, r60, (newl_cachef-$)>>4
	---
	
	lliu r16, str_listing_root&0xFFFF
	lui r16, str_listing_root>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	
	liu r16, 2
	---
	subi r25, r61, ext4_DIR_s_length+ext4_max_fn-4
	subi r61, r61, ext4_DIR_s_length+ext4_max_fn
	subi r24, r61, ext4_DIR_s_length-4
	---
	cpy r17, r24
	lipc r60, zero #
	jalr r60, r60, (ext4_open_dir-$)>>4
	---
	nop
	---
	bez r18, ext4_m_dir_no_err
	lliu r16, str_dir_read_error_could_not_open&0xFFFF
	lui r16, str_dir_read_error_could_not_open>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	nop
	---
	cpy r16, r18
	bez zero, ext4_m_dir_ret
	---
ext4_m_dir_no_err:
	liu r26, 1
	---
ext4_list_loop:
	cpy r16, r24
	cpy r17, r25
	---
	lipc r60, zero #
	jalr r60, r60, (ext4_dir_next-$)>>4
	---
	nop
	---
	subi r1, r20, EXT4_EOF #
	liu r16, EXT4_OKAY
	bez r1, ext4_m_dir_ret
	---
	cpy r16, r20
	bnez r20, ext4_m_dir_ret
	---
	cpy r16, r25
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	nop
	---
	
	subi r26, r26, 1
	bp r26, ext4_list_no_slash
	subi r19, r19, 2
	---
	liu r2, 0
	bnez r19, ext4_list_no_slash
	---
	liu r16, '/' #
	sh r16, F_UDAT(r58)
	---
	lhu r16, F_STAT(r58) #
	andi r16, r16, stat_ubusy #
	bnez r16, $
	---
	liu r2, 1
	---
ext4_list_no_slash:
	cpy r16, r25
	liu r17, 0
	---
ext4_l_aloop:
	lbu r1, 0(r16)
	---
	bez r1, ext4_l_cont
	---
	addi r16, r16, 1
	addi r17, r17, 1
	bez zero, ext4_l_aloop
	---
ext4_l_cont:
	
	add r17, r2, r17
	---
	liu r1, 14 #
	sub r17, r1, r17 #
	ples p1, r17, zero
	---
	liu r17, 1 [p1]
	---
ext4_list_spaces_loop:
	putc ' '
	subi r17, r17, 1 #
	bnez r17, ext4_list_spaces_loop
	---
	putc '-'
	putc '>'
	putc ' '
	cpy r16, r18
	lipc r60, zero #
	jalr r60, r60, (puthex32_cachef-$)>>4
	---
	putc 13
	putc 10
	bez zero, ext4_list_loop
	---
	
	liu r16, EXT4_OKAY
	---
ext4_m_dir_ret:
	addi r61, r61, ext4_DIR_s_length+ext4_max_fn
	---
ext4_mount_ret:
	lipc r60, zero #
	jalr r60, r60, (newl_cachef-$)>>4
	---
	lw r26, 4(r61) #
	lw r25, 8(r61) #
	lw r60, 12(r61)
	---
	lw r24, 16(r61)
	addi r61, r61, 8
	jalr zero, r60, 0
	---
ext4_mount_bad_sb_ret:
	cpy r24, r16
	lliu r16, str_bad_sb&0xFFFF
	lui r16, str_bad_sb>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	cpy r16, r24
	bez zero, ext4_mount_ret
	---
ext4_mount_incompat_ret:
	cpy r24, r16
	lliu r16, str_incompat&0xFFFF
	lui r16, str_incompat>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
	cpy r16, r24
	bez zero, ext4_mount_ret
	---
	
	align 4
ext4_vars_start:
ext4_lastblock:
	dd 0xFFFFFFFF
ext4_partition_start:
	dd 0
ext4_partition_end:
	dd 0
ext4_partition_size:
	dd 0
ext4_sb_first_data_block:
	dd 0
ext4_sb_inodes_per_group:
	dd 0
ext4_sb_inode_size:
	dd 0
ext4_sb_desc_size:
	dd 0
ext4_sb_blocks_per_group:
	dd 0
ext4_sb_feature_compat:
	dd 0
ext4_sb_feature_incompat:
	dd 0
ext4_sb_feature_ro_compat:
	dd 0
ext4_blockbuff:
	dd 0x06210621
	org $+4096
	dd 0
	dd 0x69696969
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
str_io_error:
	db '[',0x1B,"[1;31mFATAL",0x1B,"[0m] IO Error!",13,10,0
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
	ENDSECTION
