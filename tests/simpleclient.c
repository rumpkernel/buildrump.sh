#include "common.c"

#include <rump/rumpclient.h>
#include <rump/rump_syscalls.h>

int
main()
{

	if (rumpclient_init() == -1)
		die("rumpclient init failed, error %d", errno);
	if (rump_sys_getpid() < 2)
		die("something went wrong! (\"what\" left as an exercise)");
	rump_sys_reboot(0, NULL);
	return 0;
}
