package com.lttatt.platform.common.eao;

import org.springframework.data.jpa.domain.Specification;

@FunctionalInterface
public interface SortOrderScope<T> extends Specification<T> {

  @Override
  default SortOrderScope<T> and(Specification<T> other) {
    var specification = Specification.super.and(other);
    return specification::toPredicate;
  }

  static <T> SortOrderScope<T> all() {
    return (root, query, criteriaBuilder) -> criteriaBuilder.conjunction();
  }

  static <T> SortOrderScope<T> equal(String field, Object value) {
    if (value == null) {
      return (root, query, criteriaBuilder) -> criteriaBuilder.isNull(root.get(field));
    }
    return (root, query, criteriaBuilder) -> criteriaBuilder.equal(root.get(field), value);
  }
}
