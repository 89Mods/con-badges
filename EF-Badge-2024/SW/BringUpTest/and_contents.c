#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

void main(void) {
	uint8_t mask = 0x80;
	
	FILE* infile = fopen("./boot.bin", "rb");
	FILE* outfile = fopen("./anded.bin", "wb");
	uint8_t buffer[512];
	while(1) {
		int read = fread(buffer, 1, 512, infile);
		if(!read) break;
		for(int i = 0; i < read; i++) buffer[i] &= ~mask;
		fwrite(buffer, 1, read, outfile);
	}
	fclose(infile);
	fclose(outfile);
}
