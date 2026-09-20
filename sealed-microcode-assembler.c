#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>

int main(void) {
	struct kw_map {
        char *kw;
        uint64_t bits;
        uint64_t pos;
    };
    
    struct kw_map keywords[] = {
        {"REGWE", 1ull << 0, 0},
	{"PCINC", 1ull << 1, 1},
	{"PCDEC", 1ull << 2, 2},
	{"SPINC", 1ull << 3, 3},
	{"SPDEC", 1ull << 4, 4},
	{"SPWE", 1ull << 5, 5},
	{"PAMUX", 1ull << 6, 6},
	{"PBMUX", 0b11ull << 7, 7},
	{"ADDRSEL", 1ull << 9, 9},
	{"DATASEL", 1ull << 10, 10},
	{"REQDBUS", 1ull << 11, 11},
	{"REQDBUSDIR", 1ull << 12, 12},
	{"WBMUX", 0b11ull << 13, 13},
	{"EXECMODE", 0b11ull << 15, 15},
	{"EXECOP", 0b1111ull << 17, 17},
	{"MULTMUXAS", 0b11ull << 21, 21},
	{"MULTMUXBS", 0b11ull << 23, 23},
	{"MULTDEMUX", 0b111ull << 25, 25},
	{"MULTACC", 1ull << 28, 28},
	{"MULTOUT", 1ull << 29, 29},
	{"MULTRESET", 1ul << 30, 30},
	{"EXECREADY", 1ull << 31, 31},
	{"IMM", 1ull << 32, 32},
	{"CONDPC", 1ull << 34, 34},
	{"PCCOND", 1ull << 35, 35},
	{"RESET", 1ull << 37, 37},
	{"PSPRESET", 1ull << 38, 38},
	{NULL, 0ull, 0}
    };

    FILE *fptr = fopen("microcode.mc", "r");
    char *line = malloc(300);
    uint8_t integer_val;
    uint64_t bits_for_this_line;
	while(fgets(line, 300, fptr)) {
		bits_for_this_line = 0x80006002UL;
		char *saveptr1;
		char *label = strtok_r(line, ":", &saveptr1);
	//	printf("label: %s\n", label);
		char *tok = strtok_r(NULL, " ", &saveptr1);
		while (tok && (tok[0] != ';')) {
			char *saveptr2;
			char *signal = strtok_r(tok ,"=", &saveptr2);
			char *integer = strtok_r(NULL,"=",&saveptr2);
			if (!integer) {
				fprintf(stderr, "Expected <signal>=<integer>, got %s\n", tok);
				break;
			}
			integer_val = atoi(integer);
			if (!signal || (signal[0] == ';')) { break; }
			for (int i = 0; keywords[i].kw; i++) {
				if (strcasecmp(keywords[i].kw, signal) == 0) {
					bits_for_this_line &= ~(keywords[i].bits);
					bits_for_this_line |= ( integer_val << keywords[i].pos);
				}
			}
			tok = strtok_r(NULL, " ", &saveptr1);
		}
		printf("bits = %lX\n", bits_for_this_line);
	}

    
    fclose(fptr);
    free(line);
    return EXIT_SUCCESS;
}
