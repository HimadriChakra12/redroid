/* droid-launch — run a redroid Makefile target from anywhere.
 *
 * The repo path is baked in at compile time (see Makefile: -DREPO_DIR),
 * so once built and installed on PATH this needs no cwd, no env vars,
 * no config file. Just execs `make -C $REPO_DIR <target>` and forwards
 * its exit status.
 *
 * Usage:
 *   droid-launch            # defaults to `run` (up + scrcpy window)
 *   droid-launch <target>   # any Makefile target: setup, up, stop, shell...
 */

#include <stdio.h>
#include <unistd.h>

#ifndef REPO_DIR
#define REPO_DIR "."
#endif

int main(int argc, char **argv) {
    const char *target = (argc > 1) ? argv[1] : "run";

    fprintf(stderr, "[droid-launch] make -C %s %s\n", REPO_DIR, target);

    execlp("make", "make", "-C", REPO_DIR, target, (char *)NULL);
    perror("execlp make (is it on PATH?)");
    return 127;
}
