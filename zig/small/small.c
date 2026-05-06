#include "small.h"

static char nonnull_str[] = "the once was a ship that put to sea";

char *get_null_str() { return 0; }
char *get_nonnull_str() { return nonnull_str; }
