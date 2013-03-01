#include <sys/param.h>

#include "rump_private.h"
#include "rumpcomp_user.h"

RUMP_COMPONENT(RUMP_COMPONENT_POSTINIT)
{

	/* execute hypercall */
	printf("before hypercall\n");
	rumpcomp_user_testride(37);
}

void moretest(void);
void
moretest(void)
{

	printf("you never get called\n");
}
