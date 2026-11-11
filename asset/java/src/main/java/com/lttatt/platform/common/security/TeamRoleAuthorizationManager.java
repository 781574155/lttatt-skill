package com.lttatt.platform.common.security;

import com.lttatt.client.team.backend.TeamMembershipInternalResourceClient;
import com.lttatt.client.team.backend.rep.TeamMembershipResolveReq;
import com.lttatt.platform.common.type.TeamMemberRole;
import java.util.Map;
import java.util.Objects;
import java.util.function.Supplier;
import java.util.regex.Pattern;
import lombok.RequiredArgsConstructor;
import org.aopalliance.intercept.MethodInvocation;
import org.springframework.aop.support.AopUtils;
import org.springframework.core.annotation.AnnotatedElementUtils;
import org.springframework.security.authorization.AuthorizationDecision;
import org.springframework.security.authorization.AuthorizationManager;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;
import org.springframework.web.servlet.HandlerMapping;

@Component
@RequiredArgsConstructor
public class TeamRoleAuthorizationManager implements AuthorizationManager<MethodInvocation> {
  private static final Pattern TEAM_ID_PATTERN =
      Pattern.compile("[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}");

  private final TeamMembershipInternalResourceClient membershipClient;

  @Override
  public AuthorizationDecision authorize(
      Supplier<? extends Authentication> authentication, MethodInvocation invocation) {
    var current = authentication.get();
    if (current == null
        || !current.isAuthenticated()
        || !(current.getPrincipal() instanceof MyUserDetails userDetails)
        || Boolean.TRUE.equals(userDetails.getAttributes().get("service_token"))) {
      return new AuthorizationDecision(false);
    }

    var target = invocation.getThis();
    var method =
        AopUtils.getMostSpecificMethod(
            invocation.getMethod(), target == null ? null : AopUtils.getTargetClass(target));
    var allowed = AnnotatedElementUtils.findMergedAnnotation(method, TeamRoleAllowed.class);
    var teamId = readTeamId();
    if (allowed == null || teamId == null) {
      return new AuthorizationDecision(false);
    }

    var membership =
        membershipClient.resolve(teamId, new TeamMembershipResolveReq(userDetails.getUserId()));
    if (!Objects.requireNonNull(membership.isMember())) {
      return new AuthorizationDecision(false);
    }
    var role = TeamMemberRole.valueOf(membership.role().getValue());
    return new AuthorizationDecision(role.includes(allowed.value()));
  }

  private String readTeamId() {
    if (RequestContextHolder.getRequestAttributes() instanceof ServletRequestAttributes request
        && request.getRequest().getAttribute(HandlerMapping.URI_TEMPLATE_VARIABLES_ATTRIBUTE)
            instanceof Map<?, ?> pathVariables
        && pathVariables.get("teamId") instanceof String teamId
        && TEAM_ID_PATTERN.matcher(teamId).matches()) {
      return teamId;
    }
    return null;
  }
}
