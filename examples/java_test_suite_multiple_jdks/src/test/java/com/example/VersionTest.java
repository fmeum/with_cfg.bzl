package com.example;

import java.util.List;
import org.junit.jupiter.api.Test;

public class VersionTest {

  @Test
  public void test() {
    List<String> properties = List.of("java.specification.version", "java.vm.vendor", "java.home");
    for (String property : properties) {
      System.out.printf("%s: %s\n", property, System.getProperty(property));
    }
  }
}
