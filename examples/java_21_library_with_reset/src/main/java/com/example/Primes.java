package com.example;

import java.util.List;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.stream.IntStream;

import static java.util.stream.Collectors.toList;

public class Primes {

  public static List<String> upTo(int limit) {
    if (limit < 2) {
      throw new IllegalArgumentException("limit must be >= 2");
    }
    try (ExecutorService executorService = Executors.newVirtualThreadPerTaskExecutor()) {
      return executorService
          .submit(
              () ->
                  IntStream.range(2, limit)
                      .parallel()
                      .mapToObj(IntegerType::of)
                      .map(type -> switch (type) {
                        case IntegerType.Prime(int n) -> "%d is prime".formatted(n);
                        case IntegerType.Composite(int n, int divisor) -> "%d is divisible by %d".formatted(n, divisor);
                      })
                      .collect(toList()))
          .get();
    } catch (ExecutionException | InterruptedException e) {
      throw new RuntimeException(e);
    }
  }
}
