package com.lttatt.platform.common.service;

import com.lttatt.platform.common.eao.SortOrderEntity;
import com.lttatt.platform.common.eao.SortOrderRepository;
import com.lttatt.platform.common.eao.SortOrderScope;
import com.lttatt.platform.common.gor.GeneralOperationResultException;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

import java.util.Objects;
import java.util.Optional;

@Service
public class SortOrderService {
  private static final long SORT_STEP = 1000L;

  private final Sort sort = Sort.by(Sort.Direction.DESC, "sortOrder");

  public <I, T extends SortOrderEntity> Long nextSortOrder(SortOrderRepository<T, I> repository) {
    return nextSortOrder(repository, SortOrderScope.all());
  }

  public <I, T extends SortOrderEntity> Long nextSortOrder(
      SortOrderRepository<T, I> repository, SortOrderScope<T> scope) {
    var maxOrder = findMaxOrder(repository, scope);
    if (maxOrder <= Long.MAX_VALUE - SORT_STEP) {
      return maxOrder + SORT_STEP;
    }
    rebalance(repository, scope);
    return findMaxOrder(repository, scope) + SORT_STEP;
  }

  public <I, T extends SortOrderEntity> void move(
      SortOrderRepository<T, I> repository, I id, I prevId, I nextId) {
    move(repository, id, prevId, nextId, SortOrderScope.all());
  }

  public <I, T extends SortOrderEntity> void move(
      SortOrderRepository<T, I> repository,
      I id,
      I prevId,
      I nextId,
      SortOrderScope<T> scope) {
    if (prevId == null && nextId == null) {
      throw new GeneralOperationResultException("prev_id和next_id不能同时为空");
    }
    if (prevId != null && Objects.equals(prevId, nextId)) {
      throw new GeneralOperationResultException("prev_id和next_id不能相同");
    }
    if (Objects.equals(id, prevId) || Objects.equals(id, nextId)) {
      throw new GeneralOperationResultException("不能移动到自身旁边");
    }

    var entity =
        findById(repository, id, scope)
            .orElseThrow(() -> new GeneralOperationResultException("资源不存在, id = " + id));
    var prevOrder =
        prevId != null
            ? findById(repository, prevId, scope)
            .orElseThrow(
                () -> new GeneralOperationResultException("上一个资源不存在， prevId = " + prevId))
            .getSortOrder()
            : null;
    var nextOrder =
        nextId != null
            ? findById(repository, nextId, scope)
            .orElseThrow(
                () -> new GeneralOperationResultException("下一个资源不存在, nextId = " + nextId))
            .getSortOrder()
            : null;

    var newOrder = calcOrder(prevOrder, nextOrder);

    if (needsRebalance(newOrder, prevOrder, nextOrder)) {
      rebalance(repository, scope);
      if (prevId != null) {
        prevOrder = findById(repository, prevId, scope).orElseThrow().getSortOrder();
      }
      if (nextId != null) {
        nextOrder = findById(repository, nextId, scope).orElseThrow().getSortOrder();
      }
      newOrder = calcOrder(prevOrder, nextOrder);
    }

    entity.setSortOrder(newOrder);
    repository.save(entity);
  }

  public <T extends SortOrderEntity> void moveToEnd(
      SortOrderRepository<T, Integer> repository, Integer id, SortOrderScope<T> scope) {
    var otherEntities =
        scope.and((root, query, criteriaBuilder) -> criteriaBuilder.notEqual(root.get("id"), id));
    repository.findAll(otherEntities, PageRequest.of(0, 1, sort.reverse())).stream()
        .findFirst()
        .ifPresent(last -> move(repository, id, last.getId(), null, scope));
  }

  public <I, T extends SortOrderEntity> void reverse(SortOrderRepository<T, I> repository) {
    reverse(repository, SortOrderScope.all());
  }

  public <I, T extends SortOrderEntity> void reverse(
      SortOrderRepository<T, I> repository, SortOrderScope<T> scope) {
    var entities = repository.findAll(scope, sort);
    if (entities.size() < 2) {
      return;
    }
    var order = SORT_STEP;
    for (var entity : entities) {
      entity.setSortOrder(order);
      order += SORT_STEP;
    }
    repository.saveAll(entities);
  }

  private <I, T extends SortOrderEntity> long findMaxOrder(
      SortOrderRepository<T, I> repository, SortOrderScope<T> scope) {
    return repository.findAll(scope, PageRequest.of(0, 1, sort)).stream()
        .findFirst()
        .map(T::getSortOrder)
        .orElse(0L);
  }

  private <I, T extends SortOrderEntity> Optional<T> findById(
      SortOrderRepository<T, I> repository, I id, SortOrderScope<T> scope) {
    return repository.findOne(
        scope.and((root, query, criteriaBuilder) -> criteriaBuilder.equal(root.get("id"), id)));
  }

  private <I, T extends SortOrderEntity> void rebalance(
      SortOrderRepository<T, I> repository, SortOrderScope<T> scope) {
    var all = repository.findAll(scope, sort);
    var order = (long) all.size() * SORT_STEP;
    for (var entity : all) {
      entity.setSortOrder(order);
      order -= SORT_STEP;
    }
    repository.saveAll(all);
  }

  private long calcOrder(Long prevOrder, Long nextOrder) {
    if (prevOrder == null && nextOrder == null) {
      return SORT_STEP;
    }
    if (prevOrder == null) {
      return nextOrder > Long.MAX_VALUE - SORT_STEP ? -1L : nextOrder + SORT_STEP;
    }
    if (nextOrder == null) {
      return prevOrder / 2;
    }
    return nextOrder + (prevOrder - nextOrder) / 2;
  }

  private boolean needsRebalance(long newOrder, Long prevOrder, Long nextOrder) {
    if (newOrder <= 0) {
      return true;
    }
    if (prevOrder != null && newOrder >= prevOrder) {
      return true;
    }
    return nextOrder != null && newOrder <= nextOrder;
  }
}
