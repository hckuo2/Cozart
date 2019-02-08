#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h>

int main(int argc, char **argv) {
	char *ptr = NULL;
	if(argc == 1) {
		ptr = mmap(0x333333333000, 0x1000, PROT_READ|PROT_WRITE|PROT_EXEC,
				MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
	}
	else {
		ptr = mmap(0x222222222000, 0x1000, PROT_READ|PROT_WRITE|PROT_EXEC,
				MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
	}

	memset(ptr, 0xc3, 0x1000);
	((void(*)())ptr)();
	printf("ptr: %p\n", ptr);

}
