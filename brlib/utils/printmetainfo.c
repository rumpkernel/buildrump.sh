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

	/*
	 * XXX: you'd think that printing subsecond resultions from
	 * struct stat would be easy.  lol, guess again.  The new
	 * POSIX standard isn't implemented everywhere, and neither is
	 * the old de facto standard, so we have an "autoconf'ish"
	 * synergy with buildrump.sh to get this compiling.
	 * kiroileva siili 277-279 and all that.
	 */
	printf("%lld-%lld-%lld-%lld-%lld\n",
	    (long long)sb.st_ctime, (long long)sb.st_mtime,
#if defined(STATHACK1)
	    (long long)sb.st_ctim.tv_nsec, (long long)sb.st_mtim.tv_nsec,
#elif defined(STATHACK2)
	    (long long)sb.st_ctimensec, (long long)sb.st_mtimensec,
#elif defined(STATHACK3)
	    0LL, 0LL,
#else
#error compile with buildrump.sh
#endif
	    (long long)sb.st_size);

	return 0;
}
