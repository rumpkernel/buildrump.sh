#include "common.c"

#include <unistd.h>

#include <rump/rump.h>
#include <rump/rump_syscalls.h>

int
main()
{
	unsigned i;
	int fd;
	unsigned char buf[32];
	ssize_t nread;

	rump_init();
	for (i = 0; i < 10000; i++) {
		(void)alarm(2);
		if ((fd = rump_sys_open("/dev/random", RUMP_O_RDONLY)) == -1)
			die("open /dev/random");
		if ((nread = rump_sys_read(fd, buf, sizeof buf)) == -1)
			die("read");
		(void)rump_sys_close(fd);
	}
	rump_sys_reboot(0, NULL);

	return 0;
}
