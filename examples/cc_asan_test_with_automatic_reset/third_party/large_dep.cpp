// This file is set up to fail when compiled with AddressSanitizer. We use it to
// simulate a large third-party library that shouldn't be instrumented with
// sanitizers.

#ifndef __has_feature
  #define __has_feature(x) 0  // Compatibility with non-clang compilers.
#endif
#if __has_feature(address_sanitizer) || defined(__SANITIZE_ADDRESS__)
#error "large_dep.cpp should not be compiled with ASAN"
#endif
