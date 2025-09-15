TOOLCHAIN_PATH=/usr/bin/

TOOLCHAIN_PREFIX=riscv64-unknown-elf
ARCH=rv32i_zicsr

.SUFFIXES:

PATTERN = blink

hex:  ${PATTERN:=.hex}
bin:  ${PATTERN:=.bin}

%.elf: %.c ../../caravel_board/firmware/chipignite/sections.lds ../../caravel_board/firmware/chipignite/crt0_vex.S
	$(TOOLCHAIN_PATH)$(TOOLCHAIN_PREFIX)-gcc -I../../caravel_board/firmware/chipignite/ -I../../caravel_board/firmware/chipignite/generated/ -O2 -mabi=ilp32 -march=$(ARCH) -D__vexriscv__ -Wl,-Bstatic,-T,../../caravel_board/firmware/chipignite/sections.lds,--strip-debug -ffreestanding -nostdlib -o $@ ../../caravel_board/firmware/chipignite/crt0_vex.S ../../caravel_board/firmware/chipignite/isr.c $<
	${TOOLCHAIN_PATH}$(TOOLCHAIN_PREFIX)-objdump -D blink.elf > blink.lst

%.hex: %.elf
	$(TOOLCHAIN_PATH)$(TOOLCHAIN_PREFIX)-objcopy -O verilog $< $@
	sed -ie 's/@1000/@0000/g' $@

%.bin: %.elf
	$(TOOLCHAIN_PATH)$(TOOLCHAIN_PREFIX)-objcopy -O binary $< $@
	java ExpandROM.java $@ 131072

flash: blink.bin
	sudo flashrom --programmer ch341a_spi --write expanded.bin

clean:
	rm -f *.elf *.hex *.bin *.vvp *.vcd

.PHONY: clean hex all flash

