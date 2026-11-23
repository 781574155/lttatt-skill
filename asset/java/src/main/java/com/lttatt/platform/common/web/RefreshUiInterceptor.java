package com.lttatt.platform.common.web;

import com.lttatt.platform.common.security.MyUserDetails;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.apache.commons.lang3.StringUtils;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.HandlerMapping;
import org.springframework.web.servlet.ModelAndView;
import org.springframework.web.servlet.View;

@Component
@RequiredArgsConstructor
public class RefreshUiInterceptor implements HandlerInterceptor {
  private static final Set<String> REFRESH_METHODS = Set.of("POST", "PUT", "PATCH", "DELETE");
  private static final String COMPLETED_HANDLER = RefreshUiInterceptor.class.getName() + ".handler";

  private final RefreshUiNotifier notifier;

  @Override
  public void postHandle(
      HttpServletRequest request,
      HttpServletResponse response,
      Object handler,
      ModelAndView modelAndView) {
    request.setAttribute(COMPLETED_HANDLER, handler);
  }

  @Override
  public void afterCompletion(
      HttpServletRequest request, HttpServletResponse response, Object handler, Exception ex) {
    if (!(handler instanceof HandlerMethod handlerMethod)
        || handler != request.getAttribute(COMPLETED_HANDLER)
        || ex != null
        || response.getStatus() < 200
        || response.getStatus() >= 300) {
      return;
    }
    var refresh = handlerMethod.getMethodAnnotation(RefreshUi.class);
    var method = request.getMethod();
    if (refresh == null ? !REFRESH_METHODS.contains(method) : refresh.value().length == 0) {
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
    var teamPath = segments.length > 2 && "teams".equals(segments[0]);
    var channel =
        teamPath
            ? RefreshUiNotifier.teamChannel(segments[1])
            : RefreshUiNotifier.userChannel(userDetails.getUserId());
    var variables = pathVariables(request);
    var queryKeys =
        refresh == null
            ? List.of(defaultQueryKey(request, segments, variables))
            : notifier.queryKeys(refresh.value(), variables);
    notifier.send(channel, queryKeys);
  }

  private List<Object> defaultQueryKey(
      HttpServletRequest request, String[] segments, Map<?, ?> variables) {
    var pattern = request.getAttribute(HandlerMapping.BEST_MATCHING_PATTERN_ATTRIBUTE);
    var path =
        Arrays.asList(
            pattern instanceof String template ? StringUtils.split(template, '/') : segments);
    if (!"POST".equals(request.getMethod()) && !path.isEmpty()) {
      path = path.subList(0, path.size() - 1);
    }
    return notifier.queryKey(path, variables);
  }

  private Map<?, ?> pathVariables(HttpServletRequest request) {
    Map<Object, Object> variables =
        new HashMap<>(pathVariables(request, HandlerMapping.URI_TEMPLATE_VARIABLES_ATTRIBUTE));
    variables.putAll(pathVariables(request, View.PATH_VARIABLES));
    return variables;
  }

  private Map<?, ?> pathVariables(HttpServletRequest request, String attribute) {
    return request.getAttribute(attribute) instanceof Map<?, ?> variables ? variables : Map.of();
  }
}
