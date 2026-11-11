package com.lttatt.platform.common.config;

import java.util.Map;
import org.springframework.boot.context.properties.bind.Bindable;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.core.env.Environment;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.oauth2.client.AuthorizedClientServiceOAuth2AuthorizedClientManager;
import org.springframework.security.oauth2.client.OAuth2AuthorizedClientService;
import org.springframework.security.oauth2.client.registration.ClientRegistrationRepository;
import org.springframework.security.oauth2.client.web.reactive.function.client.ServletOAuth2AuthorizedClientExchangeFilterFunction;
import org.springframework.security.oauth2.core.AuthorizationGrantType;
import org.springframework.web.reactive.function.client.support.WebClientHttpServiceGroupConfigurer;

@Configuration
@Import(GeneratedHttpServiceRegistrar.class)
public class HttpServiceClientConfig {
  @Bean
  public WebClientHttpServiceGroupConfigurer httpServiceOauth2Configurer(
      ClientRegistrationRepository registrations,
      OAuth2AuthorizedClientService authorizedClients,
      Environment environment) {
    var groupRegistrations =
        Binder.get(environment)
            .bind("app.oauth2.client-registrations", Bindable.mapOf(String.class, String.class))
            .orElse(Map.of());
    var manager =
        new AuthorizedClientServiceOAuth2AuthorizedClientManager(registrations, authorizedClients);
    return groups ->
        groups.forEachClient(
            (group, builder) -> {
              var registrationId = groupRegistrations.getOrDefault(group.name(), group.name());
              var registration = registrations.findByRegistrationId(registrationId);
              if (registration == null
                  || !AuthorizationGrantType.CLIENT_CREDENTIALS.equals(
                      registration.getAuthorizationGrantType())) {
                return;
              }
              var oauth2 = new ServletOAuth2AuthorizedClientExchangeFilterFunction(manager);
              var principal =
                  UsernamePasswordAuthenticationToken.unauthenticated(
                      registration.getClientId(), null);
              oauth2.setDefaultClientRegistrationId(registrationId);
              oauth2.setPrincipalResolver(request -> principal);
              builder.apply(oauth2.oauth2Configuration());
            });
  }
}
