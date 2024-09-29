AS = nasm
OBJECTS = main.bin
TARGETS=$(OBJECTS)
LE_TIME=$(shell date --rfc-3339=seconds)

all: $(TARGETS)

%.bin: %.asm
	sed -iE "s/20[0-9]\{2\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}.[0-9]\{2\}:[0-9]\{2\}/$(LE_TIME)/" $<
	$(AS) -l a.l -f bin $< -o $@

clean:
	rm -f *.bin
