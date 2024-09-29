#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <argp.h>

static struct argp_option options[] = {
	{ "boot", 'b', "FILE", 0, "Boot binary" },
	{ "main", 'm', "FILE", 0, "Main binary" },
	{ "of", 'o', "FILE", 0, "Output file" },
	{ "ol", 'e', "NUM", 0, "Total output length" },
	{ "val", 'v', "NUM", 0, "Pad value" },
	{ 0 }
};

struct arguments {
	char *input_file_boot;
	char *input_file_main;
	char *output_file;
	int end_len;
	int val;
};

static error_t parse_opt(int key, char *arg, struct argp_state *state) {
	struct arguments *arguments = state->input;
	
	switch(key) {
		case 'b':
			arguments->input_file_boot = arg;
			break;
		case 'm':
			arguments->input_file_main = arg;
			break;
		case 'o':
			arguments->output_file = arg;
			break;
		case 'e':
			arguments->end_len = atoi(arg);
			if(arguments->end_len < 0) arguments->end_len = 0;
			break;
		case 'v':
			arguments->val = atoi(arg);
			if(arguments->val > 255) arguments->val = 255;
			if(arguments->val < 0) arguments->val = 0;
			break;
		default:
			return ARGP_ERR_UNKNOWN;
	}
	return 0;
}

static struct argp argp = { options, parse_opt, 0, 0 };

int main(int argc, char **argv) {
	struct arguments arguments;
	arguments.input_file_boot = 0;
	arguments.output_file = 0;
	arguments.input_file_main = 0;
	arguments.end_len = 0;
	arguments.val = 0xFF;
	argp_parse(&argp, argc, argv, 0, 0, &arguments);
	
	if(arguments.output_file == 0 || arguments.input_file_boot == 0 || arguments.input_file_main == 0) {
		printf("Must specify input and output files\n");
		return 1;
	}
	
	FILE *infile_boot = fopen(arguments.input_file_boot, "rb");
	FILE *infile_main = fopen(arguments.input_file_main, "rb");
	FILE *outfile = fopen(arguments.output_file, "wb");
	
	//FILE *test = fopen("/run/media/tholin/8a6b8802-051e-45a8-8492-771202e4c08a/EF-Badge-2024/SW/Main/main.bin", "rb");
	
	if(!infile_boot || !outfile || !infile_main/* || !test*/) {
		printf("Error opening file\n");
		if(infile_main) fclose(infile_main);
		if(infile_boot) fclose(infile_boot);
		if(outfile) fclose(outfile);
		return 1;
	}
	
	uint8_t buffer[512];
	int written = 0;
	int i;
	while(1) {
		i = fread(buffer, 1, 512, infile_main);
		if(i == 0) break;
		written += fwrite(buffer, 1, i, outfile);
	}
	fclose(infile_main);
	/*while(1) {
		i = fread(buffer, 1, 512, test);
		if(i == 0) break;
		written += fwrite(buffer, 1, i, outfile);
	}
	fclose(test);*/
	
	int boot_start = arguments.end_len - 0x200;
	if(written >= boot_start) {
		printf("Err: main binary too big, cannot fit boot binary\n");
		fclose(outfile);
		fclose(infile_boot);
		return 1;
	}
	
	memset(buffer, arguments.val, 512);
	while(written < boot_start) {
		int diff = boot_start - written;
		written += fwrite(buffer, 1, diff < 512 ? diff : 512, outfile);
	}
	
	while(1) {
		i = fread(buffer, 1, 512, infile_boot);
		if(i == 0) break;
		fwrite(buffer, 1, i, outfile);
		written += i;
	}
	
	memset(buffer, arguments.val, 512);
	while(written < arguments.end_len) {
		int diff = arguments.end_len - written;
		written += fwrite(buffer, 1, diff < 512 ? diff : 512, outfile);
	}
	
	fclose(infile_boot);
	fclose(outfile);
	return 0;
}
