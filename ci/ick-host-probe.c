#define _POSIX_C_SOURCE 200809L

#include <dirent.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

static int fail(const char *operation)
{
    fprintf(stderr, "%s: %s\n", operation, strerror(errno));
    return 1;
}

int main(void)
{
    DIR *directory;
    struct dirent *entry;
    struct stat readme;
    FILE *os_release;
    char *line = NULL;
    size_t capacity = 0;
    ssize_t length;
    size_t entries = 0;
    char *copy;
    void *scratch;

    directory = opendir(".");
    if (directory == NULL)
        return fail("opendir");

    errno = 0;
    while ((entry = readdir(directory)) != NULL) {
        (void)entry;
        ++entries;
    }
    if (errno != 0) {
        closedir(directory);
        return fail("readdir");
    }
    if (closedir(directory) != 0)
        return fail("closedir");

    if (stat("README.md", &readme) != 0)
        return fail("stat README.md");
    if (!S_ISREG(readme.st_mode)) {
        fprintf(stderr, "README.md is not a regular file\n");
        return 1;
    }

    os_release = fopen("/etc/os-release", "r");
    if (os_release == NULL)
        return fail("fopen /etc/os-release");
    length = getline(&line, &capacity, os_release);
    if (length <= 0) {
        fclose(os_release);
        free(line);
        fprintf(stderr, "/etc/os-release has no first line\n");
        return 1;
    }
    if (fclose(os_release) != 0) {
        free(line);
        return fail("fclose /etc/os-release");
    }

    copy = strdup(line);
    if (copy == NULL) {
        free(line);
        return fail("strdup");
    }

    scratch = malloc(64);
    if (scratch == NULL) {
        free(copy);
        free(line);
        return fail("malloc");
    }
    memset(scratch, 0x5a, 64);

    printf("catfood-ick-host-probe\tPASS\tentries=%zu\treadme_bytes=%lld\tos_release_first_line_bytes=%zd\n",
           entries, (long long)readme.st_size, length);

    free(scratch);
    free(copy);
    free(line);
    return 0;
}
