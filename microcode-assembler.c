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
        {"REGWE", 1 << 0, 0},
	{"PCINC", 1 << 1, 1},
	{"PCDEC", 1 << 2, 2},
	{"SPINC", 1 << 3, 3},
	{"SPDEC", 1 << 4, 4},
	{"SPWE", 1 << 5, 5},
	{"PAMUX", 1 << 6, 6},
	{"PBMUX", 0b11 << 7, 7},
	{"ADDRSEL", 1 << 9, 9},
	{"DATASEL", 1 << 10, 10},
	{"REQUESTDBUS", 1 << 11, 11},
	{"DBUSREQDIR", 1 << 12, 12},
	{"WBMUX", 0b11 << 13, 13},
	{"EXECMODE", 0b11 << 15, 15},
	{"EXECOP", 0b1111 << 17, 17},
	{"MULTMUXAS", 0b11 << 21, 21},
	{"MULTMUXBS", 0b11 << 23, 23},
	{"MULTDEMUX", 0b111 << 25, 25},
	{"MULTACC", 1ull << 28, 28},
	{"MULTOUT", 1ull << 29, 29},
	{"MULTRESET", 1ull << 30, 30},
	{"EXECREADY", 1ull << 31, 31},
	{"IMM", 1ull << 32, 32},
	{"CONDPC", 1ull << 33, 33},
	{"PCCOND", 1ull << 34, 34},
	{"RESET", 1ull << 35, 35},
	{"PSPRESET", 1ull << 36, 36},
	{NULL, 0, 0}
    };

    FILE *fptr = fopen("microcode_unassembled.mc", "r");
    char *line;
    char *tok;
    char *integer;
    uint8_t integer_val;
    uint64_t bits_for_this_line;

    while(fgetc(fptr) != EOF) {
        fgets(line, 256, fptr);
        tok = strtok(line, ":");
        tok = strtok(line, " ");
        

	while (tok) {
            if (tok[0] == ';') { break; }
		integer = strtok(tok, "=");
		integer_val = atoi(strtok(tok, "="));
            for (int i = 0; keywords[i].kw; ++i) {
                if (strcasecmp(keywords[i].kw, tok) == 0) {
                    bits_for_this_line &= ~(keywords[i].bits);
                    bits_for_this_line |= tok[i+1] << keywords[i].pos;
                }
            }
        printf("%lX\n",bits_for_this_line);
        }
    }
    fclose(fptr);
    return EXIT_SUCCESS;
}
