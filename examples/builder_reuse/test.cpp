#include <cstdlib>
#include <iostream>
#include <string>

int main() {
  if (std::string(C_VALUE) != getenv("C_VALUE")) {
    std::cerr << "C_VALUE mismatch, got: " << C_VALUE << ", want: " << getenv("C_VALUE") << std::endl;
    return 1;
  }
  if (std::string(CXX_VALUE) != getenv("CXX_VALUE")) {
    std::cerr << "CXX_VALUE mismatch, got: " << CXX_VALUE << ", want: " << getenv("CXX_VALUE") << std::endl;
    return 1;
  }
}
