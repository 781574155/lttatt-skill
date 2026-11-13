package com.lttatt.platform.common.config;

import java.util.ArrayList;
import org.apache.commons.lang3.StringUtils;
import org.apache.commons.text.CaseUtils;
import org.jspecify.annotations.Nullable;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.config.BeanPostProcessor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.MethodParameter;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableHandlerMethodArgumentResolver;
import org.springframework.data.web.SortHandlerMethodArgumentResolver;
import org.springframework.data.web.config.PageableHandlerMethodArgumentResolverCustomizer;
import org.springframework.data.web.config.SortHandlerMethodArgumentResolverCustomizer;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;
import org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter;

@Configuration
public class PageableConfig {
  @Bean
  public static BeanPostProcessor pageableSnakeCaseBeanPostProcessor(
      ObjectProvider<PageableHandlerMethodArgumentResolverCustomizer> pageableCustomizer,
      ObjectProvider<SortHandlerMethodArgumentResolverCustomizer> sortCustomizer) {
    return new BeanPostProcessor() {
      @Override
      public Object postProcessAfterInitialization(Object bean, String beanName) {
        if (!(bean instanceof RequestMappingHandlerAdapter adapter)) {
          return bean;
        }
        var resolvers = adapter.getArgumentResolvers();
        if (resolvers == null || resolvers.isEmpty()) {
          return bean;
        }

        var sortResolver = new SnakeCaseSortHandlerMethodArgumentResolver();
        sortCustomizer.ifAvailable(customizer -> customizer.customize(sortResolver));
        var pageableResolver = new PageableHandlerMethodArgumentResolver(sortResolver);
        pageableCustomizer.ifAvailable(customizer -> customizer.customize(pageableResolver));

        var updatedResolvers = new ArrayList<HandlerMethodArgumentResolver>(resolvers.size());
        for (var resolver : resolvers) {
          if (resolver instanceof PageableHandlerMethodArgumentResolver) {
            updatedResolvers.add(pageableResolver);
          } else if (resolver instanceof SortHandlerMethodArgumentResolver) {
            updatedResolvers.add(sortResolver);
          } else {
            updatedResolvers.add(resolver);
          }
        }
        adapter.setArgumentResolvers(updatedResolvers);
        return bean;
      }
    };
  }

  private static class SnakeCaseSortHandlerMethodArgumentResolver
      extends SortHandlerMethodArgumentResolver {
    @Override
    public Sort resolveArgument(
        MethodParameter parameter,
        @Nullable ModelAndViewContainer mavContainer,
        NativeWebRequest webRequest,
        @Nullable WebDataBinderFactory binderFactory) {
      var sort = super.resolveArgument(parameter, mavContainer, webRequest, binderFactory);
      if (sort.isUnsorted()) {
        return sort;
      }
      return Sort.by(sort.stream().map(this::normalizeOrder).toList());
    }

    private Sort.Order normalizeOrder(Sort.Order order) {
      var property = order.getProperty();
      if (!property.contains("_")) {
        return order;
      }
      var camelCaseProperty = CaseUtils.toCamelCase(property, false, '_');
      return StringUtils.isBlank(camelCaseProperty) ? order : order.withProperty(camelCaseProperty);
    }
  }
}
