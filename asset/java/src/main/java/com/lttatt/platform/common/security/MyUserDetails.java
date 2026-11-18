package com.lttatt.platform.common.security;

import java.io.Serial;
import java.io.Serializable;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import com.lttatt.platform.common.gor.GeneralOperationResultException;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.core.DefaultOAuth2AuthenticatedPrincipal;
import org.springframework.security.oauth2.core.OAuth2AuthenticatedPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;

public final class MyUserDetails implements OAuth2AuthenticatedPrincipal, Serializable {
  @Serial private static final long serialVersionUID = 1L;

  private final DefaultOAuth2AuthenticatedPrincipal principal;

  public MyUserDetails(Jwt jwt, Collection<? extends GrantedAuthority> authorities) {
    principal =
        new DefaultOAuth2AuthenticatedPrincipal(
            jwt.getSubject(), jwt.getClaims(), List.copyOf(authorities));
  }

  public String getUserId() {
    return principal.getName();
  }

  public int getUserLevel() {
    return switch (getAttributes().get("user_level")) {
      case Integer level -> level;
      case Long level -> level.intValue();
      default -> throw new GeneralOperationResultException("访问令牌缺少有效的用户等级，请重新获取访问令牌");
    };
  }

  @Override
  public Map<String, Object> getAttributes() {
    return principal.getAttributes();
  }

  @Override
  public Collection<? extends GrantedAuthority> getAuthorities() {
    return principal.getAuthorities();
  }

  @Override
  public String getName() {
    return principal.getName();
  }
}
