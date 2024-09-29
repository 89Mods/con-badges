#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <argp.h>
#include <stdint.h>

#include "stb_image.h"

static struct argp_option options[] = {
	{ "if", 'i', "FILE", 0, "Input file."},
	{ "of", 'o', "FILE", 0, "Output file."},
	{ "rlc", 'r', 0, 0, "Enable running-length compression."}, //Not supported on i386, do not use
	{ 0 }
};

struct arguments {
	char *input_file;
	char *output_file;
	char rlc;
};

static error_t parse_opt(int key, char *arg, struct argp_state *state) {
	struct arguments *arguments = state->input;
	
	switch(key) {
		case 'o':
			arguments->output_file = arg;
			break;
		case 'i':
			arguments->input_file = arg;
			break;
		case 'r':
			arguments->rlc = 1;
			break;
		default:
			return ARGP_ERR_UNKNOWN;
	}
	return 0;
}

static struct argp argp = { options, parse_opt, 0, 0 };

int main(int argc, char **argv) {
	struct arguments arguments;
	arguments.output_file = 0;
	arguments.input_file = 0;
	arguments.rlc = 0;
	argp_parse(&argp, argc, argv, 0, 0, &arguments);
	
	if(arguments.output_file == 0 || arguments.input_file == 0) {
		printf("Missing required arguments\n");
		return 1;
	}
	
	FILE *outfile = fopen(arguments.output_file, "wb");
	int32_t width = 0;
	int32_t height = 0;
	int32_t nrChannels = 0;
	unsigned char *data = stbi_load(arguments.input_file, &width, &height, &nrChannels, 0);
	printf("%d %d %d\n", width, height, nrChannels);
	
	if(!data || !outfile) {
		printf("Error opening file\n");
		if(outfile) fclose(outfile);
		return 1;
	}
	
	if(width > 800) {
		printf("WARN: Image wider than display\n");
	}
	if(height > 480) {
		printf("WARN: Image taller than display\n");
	}

	uint8_t wbuff[16];
	wbuff[0] = 'C';
	wbuff[1] = 'H';
	wbuff[2] = 'R';
	wbuff[3] = 'P';
	wbuff[4] = width;
	wbuff[5] = width >> 8;
	wbuff[6] = height;
	wbuff[7] = height >> 8;
	fwrite(wbuff, 1, 8, outfile);

	if(!arguments.rlc) {
		for(uint32_t i = 0; i < height; i++) {
			for(uint32_t j = 0; j < width; j++) {
				uint32_t base_idx = j * nrChannels + i * width * nrChannels;
				uint32_t pxval = data[base_idx+2];
				pxval |= data[base_idx+1] << 8;
				pxval |= data[base_idx] << 16;
				fwrite(&pxval, 1, 3, outfile);
			}
		}
	}else {
		uint32_t running_length_value;
		uint32_t rl_count = 0;
		uint32_t row_data_length;
		uint32_t total_data_pos = 8;
		uint32_t backup_pos = 8;
		for(uint32_t i = 0; i < height; i++) {
			row_data_length = 0;
			backup_pos = total_data_pos;
			fwrite(wbuff, 1, 2, outfile);
			total_data_pos += 2;
			for(uint32_t j = 0; j < width; j++) {
				uint32_t base_idx = j * nrChannels + i * width * nrChannels;
				uint32_t pxval = data[base_idx+2];
				pxval |= data[base_idx+1] << 8;
				pxval |= data[base_idx] << 16;
				if((pxval >> 16) == 0xFE) pxval |= 0xFF0000;
				if(running_length_value != pxval || j == 0 || rl_count >= 250 || j == width - 1) {
					if(rl_count == 0) {}
					else if(rl_count == 1){
						fwrite(&running_length_value, 1, 3, outfile);
						row_data_length += 3;
					}else {
						wbuff[0] = 0xFE;
						wbuff[1] = rl_count;
						fwrite(wbuff, 1, 2, outfile);
						fwrite(&running_length_value, 1, 3, outfile);
						row_data_length += 5;
					}
					running_length_value = pxval;
					rl_count = 1;
				}else {
					rl_count++;
				}
				if(j == width - 1) {
					fwrite(&pxval, 1, 3, outfile);
					row_data_length += 3;
				}
			}
			total_data_pos += row_data_length;
			fseek(outfile, backup_pos, SEEK_SET);
			fwrite(&row_data_length, 1, 2, outfile);
			fseek(outfile, total_data_pos, SEEK_SET);
		}
	}

	stbi_image_free(data);
	fclose(outfile);
}
