package com.lttatt.platform.common.util;

import lombok.experimental.UtilityClass;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.ArrayList;
import java.util.List;

@UtilityClass
public class RepositoryUtil {

  private static final int DEFAULT_BATCH_SIZE = 100;

  public <T, I> List<T> saveAll(JpaRepository<T, I> repository, List<T> entities) {
    return saveAll(repository, entities, DEFAULT_BATCH_SIZE);
  }

  public <T, I> List<T> saveAll(JpaRepository<T, I> repository, List<T> entities, int batchSize) {
    var saved = new ArrayList<T>(entities.size());
    for (int i = 0; i < entities.size(); i += batchSize) {
      var batch = entities.subList(i, Math.min(i + batchSize, entities.size()));
      saved.addAll(repository.saveAll(batch));
    }
    return saved;
  }
}
