package com.lttatt.platform.common.util;

import lombok.experimental.UtilityClass;

import java.util.function.Consumer;

@UtilityClass
public class PatchUtil {

  public <T> void patch(T value, Consumer<T> setter) {
    if (value != null) {
      setter.accept(value);
    }
  }

  public <T> void patchNullable(T value, Boolean nullValue, Consumer<T> setter) {
    if (value != null) {
      setter.accept(value);
    }
    if (Boolean.TRUE.equals(nullValue)) {
      setter.accept(null);
    }
  }
}
