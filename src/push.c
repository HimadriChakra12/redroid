/* droid-push — push files into the redroid container's Download folder.
 *
 * Standalone on purpose: no dependency on this repo's Makefile/scripts,
 * just adb on PATH. Goes over the adb protocol, so no host filesystem
 * permissions on the container's bind-mounted /data are involved — fully
 * sudoless regardless of how that directory is owned inside the container.
 *
 * Usage:
 *   droid-push file1 [file2 ...]
 *
 * Device is 127.0.0.1:5555 by default; override with ADB_HOST / ADB_PORT
 * env vars if your setup uses something else.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

#define DEST_DIR "/sdcard/Download"

static const char *get_host(void) {
    const char *h = getenv("ADB_HOST");
    return (h && *h) ? h : "127.0.0.1";
}

static const char *get_port(void) {
    const char *p = getenv("ADB_PORT");
    return (p && *p) ? p : "5555";
}

/* Runs adb with the given argv (NULL-terminated), waits for it, and
 * returns its exit status (0 on success). */
static int run_adb(char *const argv[]) {
    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        return 1;
    }
    if (pid == 0) {
        execvp("adb", argv);
        perror("execvp adb (is it on PATH?)");
        _exit(127);
    }
    int status;
    if (waitpid(pid, &status, 0) < 0) {
        perror("waitpid");
        return 1;
    }
    if (WIFEXITED(status))
        return WEXITSTATUS(status);
    return 1;
}

static int ensure_dest_dir(const char *serial) {
    char *argv[] = {
        "adb", "-s", (char *)serial, "shell", "mkdir", "-p", DEST_DIR, NULL
    };
    return run_adb(argv);
}

static int push_one(const char *serial, const char *path) {
    if (access(path, R_OK) != 0) {
        fprintf(stderr, "[droid-push] can't read '%s', skipping\n", path);
        return 1;
    }
    char *argv[] = {
        "adb", "-s", (char *)serial, "push", (char *)path, DEST_DIR "/", NULL
    };
    return run_adb(argv);
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s <file> [file...]\n", argv[0]);
        fprintf(stderr, "  pushes files into the device's %s over adb.\n", DEST_DIR);
        fprintf(stderr, "  override device with ADB_HOST/ADB_PORT env vars (default 127.0.0.1:5555)\n");
        return 1;
    }

    char serial[256];
    snprintf(serial, sizeof(serial), "%s:%s", get_host(), get_port());

    if (ensure_dest_dir(serial) != 0) {
        fprintf(stderr, "[droid-push] couldn't reach device at %s (is it booted? 'make up'?)\n", serial);
        return 1;
    }

    int failures = 0;
    for (int i = 1; i < argc; i++) {
        fprintf(stderr, "[droid-push] pushing %s\n", argv[i]);
        if (push_one(serial, argv[i]) != 0) {
            fprintf(stderr, "[droid-push] FAILED: %s\n", argv[i]);
            failures++;
        }
    }

    if (failures) {
        fprintf(stderr, "[droid-push] %d of %d file(s) failed\n", failures, argc - 1);
        return 1;
    }
    fprintf(stderr, "[droid-push] done — %d file(s) in Download on the device\n", argc - 1);
    return 0;
}
