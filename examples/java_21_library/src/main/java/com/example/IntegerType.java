package com.example;

public sealed interface IntegerType permits IntegerType.Prime, IntegerType.Composite {

  record Composite(int n, int divisor) implements IntegerType {}

  record Prime(int n) implements IntegerType {}

  static IntegerType of(int n) {
    if (n < 2) {
      throw new IllegalArgumentException("n must be >= 2");
    }
    for (int i = 2; i < n; i++) {
      if (n % i == 0) {
        return new Composite(n, i);
      }
    }
    return new Prime(n);
  }
}
