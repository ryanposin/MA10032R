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
        {"REGWE", 1ull, 0},
	{"PCINC", 1ull << 1, 1},
	{"PCDEC", 1ull << 2, 2},
	{"SPINC", 1ull << 3, 3},
	{"SPDEC", 1ull << 4, 4},
	{"SPWE", 1ull << 5, 5},
	{"PAMUX", 0b11ull << 6, 6},
	{"PBMUX", 0b11ull << 8, 8},
	{"ADDRSEL", 1ull << 10, 10},
	{"DATASEL", 1ull << 11, 11},
	{"REQDBUS", 1ull << 12, 12},
	{"REQDBUSDIR", 1ull << 13, 13},
	{"WBMUX", 0b11ull << 14, 14},
	{"EXECMODE", 0b11ull << 16, 16},
	{"EXECOP", 0b1111ull << 18, 18},
	{"MULTMUXAS", 0b11ull << 22, 22},
	{"MULTMUXBS", 0b11ull << 24, 24},
	{"MULTDEMUX", 0b111ull << 26, 26},
	{"MULTACC", 0b1ull << 29, 29},
	{"MULTOUT", 0b1ull << 30, 30},
	{"MULTRESET", 0b1ul << 31, 31},
	{"EXECREADY", 0b1ull << 32, 32},
	{"IMM", 0b11ull << 33, 33},
	{"CONDPC", 0b1ull << 35, 35},
	{"PCCOND", 0b11ull << 36, 36},
	{"RESET", 0b1ull << 38, 38},
	{"PSPRESET", 0b1ull << 39, 39},
	{"PCWE", 0b1ull << 40, 40},
	{"PRGMODE", 0b1ull << 41, 41},
	{"PPAS", 0b1ull << 42, 42},
	{"PPBS", 0b11ull << 43, 43},
	{"BUSWIDTH", 0b11ull << 45, 45},
	{"IRQACK", 0b1ull << 47, 47},
	{"INTERRUPT", 0b1ull << 48, 48},
	{NULL, 0ull, 0}
    };

    FILE *fptr = fopen("microcode.mc", "r");
    char *line = malloc(500);
    uint64_t integer_val;
    uint64_t bits_for_this_line;
	while(fgets(line, 500, fptr)) {
		bits_for_this_line = 0x40010000C002ULL;
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
		printf("%lX\n", bits_for_this_line);

	}

    
    fclose(fptr);
    free(line);
    return EXIT_SUCCESS;
}
