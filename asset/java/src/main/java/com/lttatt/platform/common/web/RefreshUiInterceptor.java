package com.lttatt.platform.common.web;

import com.lttatt.client.notify.backend.NotifyInternalResourceClient;
import com.lttatt.client.notify.backend.rep.RefreshUiReq;
import com.lttatt.platform.common.security.MyUserDetails;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.apache.commons.lang3.StringUtils;
import org.springframework.core.env.Environment;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

@Component
@RequiredArgsConstructor
public class RefreshUiInterceptor implements HandlerInterceptor {
  private static final Set<String> REFRESH_METHODS = Set.of("POST", "PUT", "PATCH", "DELETE");

  private final NotifyInternalResourceClient notifyClient;
  private final Environment environment;

  @Override
  public void afterCompletion(
      HttpServletRequest request, HttpServletResponse response, Object handler, Exception ex) {
    if (!(handler instanceof HandlerMethod)
        || ex != null
        || response.getStatus() < 200
        || response.getStatus() >= 300) {
      return;
    }
    if (!REFRESH_METHODS.contains(request.getMethod())) {
      return;
    }
    var authentication = SecurityContextHolder.getContext().getAuthentication();
    if (authentication == null
        || !authentication.isAuthenticated()
        || !(authentication.getPrincipal() instanceof MyUserDetails userDetails)
        || StringUtils.isBlank(userDetails.getUserId())) {
      return;
    }
    var path = request.getRequestURI().substring(request.getContextPath().length());
    var segments = StringUtils.split(path, '/');
    var queryKey = new ArrayList<>();
    queryKey.add(environment.getRequiredProperty("spring.application.name"));
    queryKey.addAll(List.of(segments));
    if ("POST".equals(request.getMethod())) {
      if (queryKey.size() > 2 && "move".equals(queryKey.getLast())) {
        queryKey.removeLast();
        queryKey.removeLast();
      }
    } else if (queryKey.size() > 1) {
      queryKey.removeLast();
    }

    var teamPath = segments.length > 2 && "teams".equals(segments[0]);
    var channel =
        teamPath ? "notify:team:" + segments[1] : "notify:user:" + userDetails.getUserId();
    notifyClient.refreshUi(new RefreshUiReq(queryKey, List.of(channel)));
  }
}
