	align 16
	; Reads and parses the partition table of the SD's MBR
	; Tries to find the ext4 partition and automatically sets ext4_partition_start and ext4_partition_end once found
	; Args: none
	; Returns: was the partition found (r2)
	; Uses: r1, r2, r3, r4, r5, r6, r7, r8, r10
parse_mbr:
	sw r60, 0(r61) #
	sw r24, -4(r61)
	subi r61, r61, 8
	---
	lliu r16, ext4_blockbuff&0xFFFF
	lui r16, ext4_blockbuff>>16
	xor r17, r17, r17
	---
	lipc r60, zero #
	jalr r60, r60, (sdcard_read_block-$)>>4
	---
	lliu r1, (ext4_blockbuff + 446)&0xFFFF
	lui r1, (ext4_blockbuff + 446)>>16
	liu r2, 3
	---
	lliu r10, sd_capacity&0xFFFF
	lui r10, sd_capacity>>16 #
	lw r10, 0(r10)
	---
parse_mbr_loop:
	; Partition start
	lhu r4, 8(r1) #
	lhu r3, 10(r1)
	---
	slli r3, r3, 16 #
	add r4, r4, r3
	---
	; Partition size
	lhu r5, 12(r1) #
	lhu r3, 14(r1)
	---
	slli r3, r3, 16 #
	add r5, r5, r3 #
	; Partition end
	add r6, r5, r4
	---
	; Partition type
	lbu r7, 4(r1) #
	liu r8, 0x83 #
	bne r7, r8, parse_mbr_loop_continue
	---
	; Bounds check
	subi r6, r6, 1 # ; Fix partition end to be an inclusive range
	bge r6, r10, parse_mbr_partition_weird
	bge r4, r10, parse_mbr_partition_weird
	---
	; Well, we found it!
	lliu r10, ext4_partition_start&0xFFFF
	lui r10, ext4_partition_start>>16 #
	sw r4, 0(r10)
	---
	lliu r10, ext4_partition_end&0xFFFF
	lui r10, ext4_partition_end>>16 #
	sw r6, 0(r10)
	---
	lliu r10, ext4_partition_size&0xFFFF
	lui r10, ext4_partition_size>>16 #
	sw r5, 0(r10)
	---
	xor r2, r2, r2 #
	lliu r2, 1
	bez zero, parse_mbr_return
	---
parse_mbr_partition_weird:
	lliu r16, mbr_text_partition_weird&0xFFFF
	lui r16, mbr_text_partition_weird>>16
	---
	lipc r60, zero #
	jalr r60, r60, (putstr-$)>>4
	---
parse_mbr_loop_continue:
	addi r1, r1, 16
	subi r2, r2, 1
	bnez r2, parse_mbr_loop
	---
	; Not found
	xor r2, r2, r2
	---
parse_mbr_return:
	lw r24, 4(r61) #
	lw r60, 8(r61)
	addi r61, r61, 8
	---
	jalr zero, r60, 0
	---
mbr_text_partition_weird:
	db 0x1B,"[1;31m","Found Linux partition, but its bounds exceed SD card capacity. Bad MBR?",0x1B,"[0m",13,10,0
