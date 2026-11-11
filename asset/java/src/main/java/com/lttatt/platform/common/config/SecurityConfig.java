package com.lttatt.platform.common.config;

import com.lttatt.platform.common.security.MyUserDetails;
import com.lttatt.platform.common.security.TeamRoleAllowed;
import com.lttatt.platform.common.security.TeamRoleAuthorizationManager;
import org.springframework.aop.Advisor;
import org.springframework.aop.support.annotation.AnnotationMatchingPointcut;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.config.BeanDefinition;
import org.springframework.boot.context.properties.PropertyMapper;
import org.springframework.boot.security.oauth2.server.resource.autoconfigure.OAuth2ResourceServerProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Role;
import org.springframework.security.authorization.method.AuthorizationInterceptorsOrder;
import org.springframework.security.authorization.method.AuthorizationManagerBeforeMethodInterceptor;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfig {
  @Bean
  @Role(BeanDefinition.ROLE_INFRASTRUCTURE)
  public static Advisor teamRoleAllowedAdvisor(
      ObjectProvider<TeamRoleAuthorizationManager> manager) {
    var pointcut = new AnnotationMatchingPointcut(null, TeamRoleAllowed.class, true);
    var interceptor =
        new AuthorizationManagerBeforeMethodInterceptor(
            pointcut,
            (authentication, invocation) ->
                manager.getObject().authorize(authentication, invocation));
    interceptor.setOrder(AuthorizationInterceptorsOrder.PRE_AUTHORIZE.getOrder() + 1);
    return interceptor;
  }

  @Bean
  public JwtAuthenticationConverter jwtAuthenticationConverter(
      OAuth2ResourceServerProperties properties) {
    var jwtProperties = properties.getJwt();
    var authoritiesConverter = new JwtGrantedAuthoritiesConverter();
    var mapper = PropertyMapper.get();
    mapper.from(jwtProperties::getAuthorityPrefix).to(authoritiesConverter::setAuthorityPrefix);
    mapper
        .from(jwtProperties::getAuthoritiesClaimName)
        .to(authoritiesConverter::setAuthoritiesClaimName);
    mapper
        .from(jwtProperties::getAuthoritiesClaimDelimiter)
        .to(authoritiesConverter::setAuthoritiesClaimDelimiter);
    var converter = new JwtAuthenticationConverter();
    converter.setJwtGrantedAuthoritiesConverter(authoritiesConverter);
    converter.setJwtPrincipalConverter(
        jwt -> new MyUserDetails(jwt, authoritiesConverter.convert(jwt)));
    return converter;
  }

  @Bean
  public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    return http
        .cors(Customizer.withDefaults())
        .csrf(csrf -> csrf.ignoringRequestMatchers("/pub/**"))
        .authorizeHttpRequests(
            authorize ->
                authorize
                    .requestMatchers(
                        "/pub/**",
                        "/",
                        "/swagger-ui.html",
                        "/swagger-ui/**",
                        "/v3/api-docs",
                        "/v3/api-docs/**",
                        "/v3/api-docs.yaml")
                    .permitAll()
                    .anyRequest()
                    .authenticated())
        .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()))
        .build();
  }
}
