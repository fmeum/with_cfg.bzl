#include <cstdlib>

#include <iostream>
#include <string>

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

  std::cout << "Hello, " << NAME << "!" << std::endl;
  return 0;
}
