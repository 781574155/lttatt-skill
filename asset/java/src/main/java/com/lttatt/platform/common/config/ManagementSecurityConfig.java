package com.lttatt.platform.common.config;

import org.springframework.boot.security.autoconfigure.actuate.web.servlet.EndpointRequest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class ManagementSecurityConfig {
  @Bean
  @Order(0)
  public SecurityFilterChain managementSecurityFilterChain(HttpSecurity http) throws Exception {
    return http
        .securityMatcher(EndpointRequest.toAnyEndpoint())
        .authorizeHttpRequests(
            authorize ->
                authorize
                    .requestMatchers(EndpointRequest.to("health", "prometheus"))
                    .permitAll()
                    .anyRequest()
                    .denyAll())
        .build();
  }
}
