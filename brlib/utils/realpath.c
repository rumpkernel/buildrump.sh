/*-
 * Copyright (c) 2015 Antti Kantee
 * All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <sys/types.h>

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * So we want to use realpath(), which conveniently doesn't provide
 * any way to pass the buffer length.  Newer versions of POSIX mandate
 * that by passing a NULL buffer the path will be allocated for you,
 * but passing a NULL buffer to an older version might be bad.
 * So, we just pass an obnoxiously large buffer, and leave
 * the consequences of that approach in intended scenarios as an
 * exercise to the reader.
 */

#define MYMAXPATHLEN (64*1024)
static char thepath[MYMAXPATHLEN];

int
main(int argc, char *argv[])
{

	if (argc != 2) {
		fprintf(stderr, "usage: brrealpath path\n");
		exit(1);
	}
	if (realpath(argv[1], thepath) == NULL) {
		fprintf(stderr, "realpath failed: %s\n", strerror(errno));
		exit(1);
	}
	printf("%s\n", thepath);

	return 0;
}
