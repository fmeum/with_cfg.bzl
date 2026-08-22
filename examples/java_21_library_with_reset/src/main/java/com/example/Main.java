package com.example;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.List;

public class Main {
  public static void main(String[] args)
      throws ClassNotFoundException,
          NoSuchMethodException,
          InvocationTargetException,
          IllegalAccessException {
    if (Runtime.version().feature() < 21) {
      System.err.println(
          "This java_binary compiles with JDK 11 or higher, but requires Java 21 at runtime.");
      System.exit(1);
    }
    Method primesUpTo = Class.forName("com.example.Primes").getMethod("upTo", int.class);
    ((List<String>) primesUpTo.invoke(null, 1000)).forEach(System.out::println);
  }
}
