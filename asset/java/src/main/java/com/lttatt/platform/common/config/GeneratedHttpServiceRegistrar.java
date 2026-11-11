package com.lttatt.platform.common.config;

import org.springframework.beans.factory.annotation.AnnotatedBeanDefinition;
import org.springframework.beans.factory.config.BeanDefinition;
import org.springframework.context.annotation.ClassPathScanningCandidateComponentProvider;
import org.springframework.core.type.AnnotationMetadata;
import org.springframework.util.ClassUtils;
import org.springframework.web.service.annotation.HttpExchange;
import org.springframework.web.service.registry.AbstractHttpServiceRegistrar;
import org.springframework.web.service.registry.HttpServiceGroup.ClientType;

import java.util.Objects;

public class GeneratedHttpServiceRegistrar extends AbstractHttpServiceRegistrar {
  private static final String CLIENT_PACKAGE = "com.lttatt.client";
  private static final String CLIENT_PACKAGE_PREFIX = CLIENT_PACKAGE + ".";

  @Override
  protected void registerHttpServices(GroupRegistry registry, AnnotationMetadata metadata) {
    var scanner =
        new ClassPathScanningCandidateComponentProvider(false) {
          @Override
          protected boolean isCandidateComponent(AnnotatedBeanDefinition beanDefinition) {
            var candidate = beanDefinition.getMetadata();
            return candidate.isIndependent() && candidate.isInterface();
          }
        };
    scanner.addIncludeFilter(
        (reader, factory) -> {
          var candidate = reader.getAnnotationMetadata();
          return candidate.getAnnotations().isPresent(HttpExchange.class)
              || candidate.hasAnnotatedMethods(HttpExchange.class.getName());
        });

    scanner.findCandidateComponents(CLIENT_PACKAGE).stream()
        .map(BeanDefinition::getBeanClassName)
        .filter(Objects::nonNull)
        .forEach(
            typeName -> {
              var packageName = ClassUtils.getPackageName(typeName);
              if (packageName.startsWith(CLIENT_PACKAGE_PREFIX)) {
                var groupName = packageName.substring(CLIENT_PACKAGE_PREFIX.length());
                registry
                    .forGroup(groupName.replace('.', '-'), ClientType.WEB_CLIENT)
                    .registerTypeNames(typeName);
              }
            });
  }
}
