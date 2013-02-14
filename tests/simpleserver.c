#include "common.c"

#include <rump/rump.h>

int
main(int argc, char *argv[])
{

	unsetenv("RUMP_VERBOSE");
	if (rump_daemonize_begin() != 0)
		die("daemonize init");
        rump_init();
	if (rump_init_server(argv[1]) != 0)
		die("server init");
	if (rump_daemonize_done(0) != 0)
		die("daemonize fini");
	pause();
	return 0;
}
