CC = gcc
LD = gcc

CCFLAGS += -O2 -g -Wall
LDFLAGS += -lm

all: main

OBJS=main.o stb_image.o

%.o: %.c
	$(CC) $(CCFLAGS) -c -o $@ $<

main: $(OBJS)
	$(LD) -o main $^ $(LDFLAGS)

clean:
	rm -rf *.o main

.PHONY: all echo clean
