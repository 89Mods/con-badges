AS = nasm
OBJECTS = boot.bin prot.bin
TARGETS=$(OBJECTS) combined

all: $(TARGETS)

%.bin: %.asm
	$(AS) -l a.l -f bin $< -o $@

combined: $(OBJECTS)
	../a.out --boot boot.bin --main prot.bin -o combined.bin -e 262144

clean:
	rm *.bin
