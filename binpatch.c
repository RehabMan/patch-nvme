//
//  binpatch.c
//
//  Created by RehabMan on 01-Jul-2016 (some code from patcho.c)
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

int tohex(unsigned char hex)
{
    if (hex >= '0' && hex <= '9')
        return hex - '0';
    else if (hex >= 'A' && hex <= 'F')
        return hex - 'A' + 10;
    else if (hex >= 'a' && hex <= 'f')
        return hex - 'a' + 10;
    printf("Bad hex character '%c'\n", hex);
    exit(6);
}

void hexStr(const char *hex, unsigned char *str)
{
    u_int64_t j = 0, i = strlen(hex)/2;
    if (i < 1) return;
    while (j < i)
    {
        str[j]=(tohex(hex[j*2])<<4)+tohex(hex[j*2+1]);
        j++;
    }
}

void stripSpaces(char* arg)
{
    char* dest = arg;
    char* src = arg;
    while (*src) {
        if (*src != '\t' && *src != ' ')
            *dest++ = *src;
        ++src;
    }
    *dest = 0;
}

void patchMemory(unsigned char* bytes, u_int64_t count, unsigned char* find, unsigned char* replace, u_int64_t fr_count)
{
    unsigned char* ptr = bytes;
    while (count--)
    {
        if (0 == memcmp(ptr, find, fr_count))
        {
            printf("\tpatching offset: %zu\n", (size_t)(ptr - bytes));
            memcpy(ptr, replace, fr_count);
            ptr += fr_count;
            count -= fr_count;
            continue;
        }
        ptr++;
    }
}

int main(int argc, char * argv[])
{
    if (argc != 4)
    {
        printf ("Usage: %s <hex find> <hex replace> <file>\nExample: %s CAFEBABE CAFE00AB java.exe\nResult: CAFEBABE -> CAFE00AB\n", argv[0], argv[0]);
        exit(1);
    }
    if (access(argv[argc-1], F_OK) != 0)
    {
        printf("File cannot be found\n");
        exit(2);
    }

    char* findArg = argv[1];
    char* replArg = argv[2];
    char* fileArg = argv[3];

    stripSpaces(findArg);
    stripSpaces(replArg);
    printf("\tfind: '%s'\n", findArg);
    printf("\trepl: '%s'\n", replArg);
    if (strlen(findArg) != strlen(replArg))
    {
        printf("Find and Replace sizes do not match\n");
        exit(4);
    }
    if (strlen(findArg) % 2 != 0 || strlen(replArg) % 2 != 0)
    {
        printf("Find and Replace sizes not in whole bytes\n");
        exit(5);
    }

    // read entire file to memory
    FILE* file = fopen(fileArg, "r+b");
    fseek(file, 0, SEEK_END);
    u_int64_t l = ftell(file);
    unsigned char* bytes = malloc(l);
    fseek(file, 0, SEEK_SET);
    fread(bytes, 1, l, file);

    // patch it
    u_int64_t fr_len = strlen(findArg)/2;
    unsigned char find[fr_len];
    unsigned char repl[fr_len];
    hexStr(findArg, find);
    hexStr(replArg, repl);
    patchMemory(bytes, l, find, repl, fr_len);

    // write it back out
    fseek(file, 0, SEEK_SET);
    fwrite(bytes, 1, l, file);
    fclose(file);

    return 0;
}

