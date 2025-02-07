package com.example;

import static org.junit.Assert.assertTrue;

import org.junit.Test;

public final class LegacyIllegalArgumentExceptionTest {
  @Test
  public void legacyIllegalArgumentException() {
    assertTrue(IllegalArgumentException.class.isAssignableFrom(LegacyIllegalArgumentException.class));
  }
}
