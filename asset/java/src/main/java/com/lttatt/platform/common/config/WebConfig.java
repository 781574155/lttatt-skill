package com.lttatt.platform.common.config;

import jakarta.servlet.Filter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import java.util.Collections;
import java.util.Enumeration;
import java.util.LinkedHashMap;
import java.util.Map;
import org.apache.commons.lang3.StringUtils;
import org.apache.commons.text.CaseUtils;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {
  @Override
  public void addCorsMappings(CorsRegistry registry) {
    registry
        .addMapping("/**")
        .allowedMethods("*")
        .allowedOriginPatterns("*")
        .allowCredentials(true)
        .allowedHeaders("*")
        .exposedHeaders("*");
  }

  @Bean
  public FilterRegistrationBean<Filter> snakeCaseParameterAliasFilter() {
    Filter filter =
        (request, response, chain) -> {
          if (request instanceof HttpServletRequest httpRequest) {
            chain.doFilter(new SnakeCaseParameterAliasRequestWrapper(httpRequest), response);
          } else {
            chain.doFilter(request, response);
          }
        };
    var registration = new FilterRegistrationBean<>(filter);
    registration.setOrder(Ordered.HIGHEST_PRECEDENCE);
    registration.addUrlPatterns("/*");
    return registration;
  }

  private static class SnakeCaseParameterAliasRequestWrapper extends HttpServletRequestWrapper {
    private Map<String, String[]> aliases;

    SnakeCaseParameterAliasRequestWrapper(HttpServletRequest request) {
      super(request);
    }

    @Override
    public String getParameter(String name) {
      var value = super.getParameter(name);
      if (value != null) {
        return value;
      }
      var values = aliases().get(name);
      return values == null || values.length == 0 ? null : values[0];
    }

    @Override
    public String[] getParameterValues(String name) {
      var values = super.getParameterValues(name);
      return values == null ? aliases().get(name) : values;
    }

    @Override
    public Enumeration<String> getParameterNames() {
      return Collections.enumeration(getParameterMap().keySet());
    }

    @Override
    public Map<String, String[]> getParameterMap() {
      var parameters = super.getParameterMap();
      var parameterAliases = aliases();
      if (parameterAliases.isEmpty()) {
        return parameters;
      }
      var result = new LinkedHashMap<>(parameters);
      parameterAliases.forEach(result::putIfAbsent);
      return Collections.unmodifiableMap(result);
    }

    private Map<String, String[]> aliases() {
      if (aliases == null) {
        var parameters = super.getParameterMap();
        var parameterAliases = new LinkedHashMap<String, String[]>();
        parameters.forEach(
            (name, values) -> {
              if (name.contains("_")) {
                var alias = CaseUtils.toCamelCase(name, false, '_');
                if (StringUtils.isNotBlank(alias) && !parameters.containsKey(alias)) {
                  parameterAliases.putIfAbsent(alias, values);
                }
              }
            });
        aliases = parameterAliases;
      }
      return aliases;
    }
  }
}
