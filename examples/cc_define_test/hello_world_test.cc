#include <cstdlib>

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <memory>

#include "tools/cpp/runfiles/runfiles.h"

using bazel::tools::cpp::runfiles::Runfiles;

#ifdef _MSC_VER
#define EXPECTED_GREETING "Hello, MSVC!\n"
#else
#define EXPECTED_GREETING "Hello, with_cfg.bzl!\n"
#endif

int main(int argc, char** argv) {
  if (std::string(std::getenv("MY_VAR")) != "my_value") {
    std::cerr << "MY_VAR is not set to 'my_value'" << std::endl;
    return 1;
  }
  if (argc != 3) {
    std::cerr << "Expected 2 arguments, got " << argc - 1 << std::endl;
    return 1;
  }
  if (std::string(argv[1]) != "arg1" || std::string(argv[2]) != "arg2") {
    std::cerr << "Expected arguments 'arg1' and 'arg2', got '" << argv[1]
              << "' and '" << argv[2] << "'" << std::endl;
    return 1;
  }

  std::string error;
  std::unique_ptr<Runfiles> runfiles(Runfiles::Create(argv[0], BAZEL_CURRENT_REPOSITORY, &error));
  if (runfiles == nullptr) {
    std::cerr << "Failed to create Runfiles: " << error << std::endl;
    return 1;
  }

  std::string greeting_path = runfiles->Rlocation(std::getenv("GREETING_RLOCATIONPATH"));
  std::ifstream greeting_file(greeting_path);
  if (!greeting_file.good()) {
    std::cerr << "Failed to open greeting file: " << greeting_path << std::endl;
    return 1;
  }

  std::stringstream buffer;
  buffer << greeting_file.rdbuf();
  std::string greeting = buffer.str();

  if (greeting != EXPECTED_GREETING) {
    std::cerr << "Expected greeting '" << EXPECTED_GREETING << "', got '"
            << greeting << "'" << std::endl;
    return 1;
  }

  std::cout << greeting << std::endl;
  return 0;
}
