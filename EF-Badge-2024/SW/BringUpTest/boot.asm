[org 0xFFFFFE00]
[bits 16]
;extra:
;    mov eax, cr0
;    and eax, 0x7FFFFFFF ;Disable paging
;    mov cr0, eax
;	mov eax,0x55555555
;loop:
;	mov dx,8192
;	out dx,eax
;	mov ebx, 22
;	mov word [bx],0xFFFF
;delay_loop:
;	nop
;	nop
;	nop
;	nop
;	dec word [bx]
;	jne delay_loop
;	not eax
;	jmp loop
;times 0x1F0-($-$$) db 0
;	cli
;	cli
;	nop
;	jmp extra
gdt_base equ 0
ram_base equ 0
ram_limit equ 1048576
ram_limit_pages equ ram_limit>>12
rom_base equ 0x80000000
rom_limit equ 262144
rom_limit_pages equ rom_limit>>12

ram_segment equ 0x08
stack_segment equ 0x10
rom_segment equ 0x18

[org 0xFFFFFE00]
[bits 16]
idt:
i_div:
    dd 0
    dd 0
i_dbg:
    dd 0
    dd 0
i_nmi:
    dd 0
    dd 0
i_onebyte:
    dd 0
    dd 0
i_ovf:
    dd 0
    dd 0
i_bound:
    dd 0
    dd 0
i_illegal:
    dd 0
    dd 0
i_no_dev:
    dd 0
    dd 0
i_double:
    dd 0
    dd 0
i_overrun:
    dd 0
    dd 0
i_invalid_tss:
    dd 0
    dd 0
i_segment_gone:
    dd 0
    dd 0
i_stackf:
    dd 0
    dd 0
i_gp:
    dd 0
    dd 0
i_reserved:
    dd 0
    dd 0
i_pf:
    dd 0
    dd 0
i_coproc:
    dd 0
    dd 0
    times 0x100-($-$$) db 0
gdt:
null_segment:
    dd 0
    dd 0
ram_descriptor:
    dw ram_limit_pages&0xFFFF
    dw ram_base&0xFFFF
    db (ram_base>>16)&0xFF
    db 0b10010010
    db ((ram_limit_pages>>16)&0xF)|0xC0
    db (ram_base>>24)&0xFF
    ;For now just a copy of the RAM segment
stack_descriptor:
    dw ram_limit_pages&0xFFFF
    dw ram_base&0xFFFF
    db (ram_base>>16)&0xFF
    db 0b10010010
    db ((ram_limit_pages>>16)&0xF)|0xC0
    db (ram_base>>24)&0xFF
rom_descriptor:
    dw rom_limit_pages&0xFFFF
    dw rom_base&0xFFFF
    db (rom_base>>16)&0xFF
    db 0b10011010
    db ((rom_limit_pages>>16)&0xF)|0xC0
    db (rom_base>>24)&0xFF
    dd 0
    dd 0
placeholder:
	dd 0
	dd 0
	dd 0
	dd 0
	dd 0
	dd 0
	dd 0
	dd 0
	dd 0
	dd 0
	dd 0
	dd 0
	dd 0
	dd 0
	dw 0
	dd 0
gdt_descriptor:
    dw placeholder-gdt-1
    dd gdt-idt+gdt_base
idt_descriptor:
    dw 256
    dd idt-idt+gdt_base
end_descriptors:
times 0x1A0-($-$$) db 0
extra:
    mov eax, cr0
    and eax, 0x7FFFFFFF ;Disable paging
    mov cr0, eax
    ;0xFFFF0000 is code segment base after reset
    ;Copy GDT structures to beginning of RAM since lgdt cannot
    ;Accesses addresses past 0x00FFFFFF (ROM starts at 0x80000000)
    mov eax, idt-0xFFFF0000
    mov ebx, gdt_base
copy_loop:
        mov ecx, cs:[eax]
        mov [ebx], ecx
        inc ebx
        inc eax
        cmp eax, end_descriptors-0xFFFF0000
        jne copy_loop
    lgdt [gdt_descriptor-idt+gdt_base]
    lidt [idt_descriptor-idt+gdt_base]
    mov eax, cr0
    or eax, 5 ;Enable protection and disable co-processor interface
    mov cr0, eax
    mov ebx, placeholder-0xFFFFFE00+8
    jmp rom_segment:0
times 0x1F0-($-$$) db 0
    cli
    cli
    nop
    jmp extra
times 0x200-($-$$) db 0x90
