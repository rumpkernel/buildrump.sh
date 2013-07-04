#include <sys/types.h>

#include <stdio.h>

/*
 * #include <linux.h> & other weird stuff here
 */

#include <rump/rumpuser_component.h>

#include "rumpcomp_user.h"

void
rumpcomp_user_testride(int justnum)
{
	void *cookie;

	cookie = rumpuser_component_unschedule();
	printf("this print comes from the hypercall: %d\n", justnum);
	rumpuser_component_schedule(cookie);
}
