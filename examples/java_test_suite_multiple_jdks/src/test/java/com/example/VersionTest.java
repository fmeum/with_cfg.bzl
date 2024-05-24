package com.example;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;

public class VersionTest {

  @Test
  public void test() {
    // something has gone wrong if the JVM running this test is not 17 or 21, based on the
    // configuration in BUILD.bazel
    assertTrue(
        Set.of("17", "21").contains(System.getProperty("java.specification.version")),
        "expected test to only be run on JDK version 17 or 21");

    List<String> properties = List.of("java.specification.version", "java.vm.vendor", "java.home");
    for (String property : properties) {
      System.out.printf("%s: %s\n", property, System.getProperty(property));
    }
  }
}
