package com.lttatt.platform.common.eao;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.repository.NoRepositoryBean;

@NoRepositoryBean
public interface SortOrderRepository<T extends SortOrderEntity, I>
    extends JpaRepository<T, I>, JpaSpecificationExecutor<T> {}
