#include "cc_asan_test_with_manual_reset/lib.h"

int trigger_asan() {
  int* array = new int[100] {};
  delete[] array;
  // Triggers a heap-use-after-free error.
  return array[0];
}
