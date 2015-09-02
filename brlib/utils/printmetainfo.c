#include <sys/stat.h>

#include <stdio.h>
#include <stdlib.h>

int
main(int argc, char *argv[])
{
	struct stat sb;

	if (argc != 2) {
		fprintf(stderr, "usage: printmetainfo file\n");
		exit(1);
	}
	if (stat(argv[1], &sb) == -1) {
		fprintf(stderr, "could not stat %s\n", argv[1]);
		exit(1);
	}

	printf("%lld%lld%lld%lld%lld\n",
	    (long long)sb.st_ctim.tv_sec, (long long)sb.st_ctim.tv_sec,
	    (long long)sb.st_mtim.tv_sec, (long long)sb.st_mtim.tv_sec,
	    (long long)sb.st_size);

	return 0;
}
