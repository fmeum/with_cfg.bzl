#include "cc_asan_test_with_automatic_reset/lib.h"

#include <iostream>

int main() {
  trigger_asan();
  std::cerr << "Did not get expected AddressSanitizer error, is the test instrumented correctly?" << std::endl;
  return 1;
}
