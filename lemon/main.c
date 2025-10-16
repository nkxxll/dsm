#include "grammar.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef DEBUG_PRINT
#define DEBUG
#ifdef DEBUG
#define DEBUG_PRINT(fmt, ...)                                                  \
  fprintf(stderr, "[DEBUG] %s:%d:%s(): " fmt "\n", __FILE__, __LINE__,         \
          __func__, ##__VA_ARGS__)
#else
#define DEBUG_PRINT(fmt, ...)                                                  \
  do {                                                                         \
  } while (0)
#endif
#endif
// to make it work without proper header files
// dont do that at home
extern char *linenumber;
extern char *curtoken;
extern char *curtype;
extern char *parse_to_string(char *input);

int main(int argc, char *argv[]) {
  DEBUG_PRINT("Starting main function");
  size_t capacity = 1024;
  size_t size = 0;
  char *buffer = malloc(capacity);
  if (!buffer) {
    perror("Could not allocate buffer with capacity");
    exit(EXIT_FAILURE);
  }
  DEBUG_PRINT("Initial buffer allocated");

  int c;
  while ((c = fgetc(stdin)) != EOF) {
    if (size + 1 >= capacity) {
      capacity *= 2;
      char *newbuf = realloc(buffer, capacity);
      if (!newbuf) {
        free(buffer);
        perror("Could not reallocate buffer with capacity");
        exit(EXIT_FAILURE);
      }
      buffer = newbuf;
    }
    buffer[size++] = (char)c;
  }

  buffer[size] = '\0'; // null-terminate
  DEBUG_PRINT("Stdin read. Content: %s", buffer);

  char *res = parse_to_string(buffer);
  printf("RESULT:\n%s\n", res);
  free(res);
  return EXIT_SUCCESS;
}
