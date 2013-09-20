#include <sys/types.h>

#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>

#include <rump/rump.h>

int
main()
{
	int rv;

	setenv("RUMP_VERBOSE", "1", 1);
	rv = rump_init();
	printf("rump kernel init complete, rv %d\n", rv);

	return rv;
}
