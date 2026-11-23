package com.lttatt.platform.common.web;

import com.lttatt.client.notify.backend.NotifyInternalResourceClient;
import com.lttatt.client.notify.backend.rep.RefreshUiReq;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.regex.Pattern;
import lombok.RequiredArgsConstructor;
import org.apache.commons.lang3.StringUtils;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class RefreshUiNotifier {
  private static final Pattern PATH_VARIABLE = Pattern.compile("\\{([^{}]+)\\}");

  private final NotifyInternalResourceClient notifyClient;
  private final Environment environment;

  public static String userChannel(String userId) {
    return "notify:user:" + userId;
  }

  public static String teamChannel(String teamId) {
    return "notify:team:" + teamId;
  }

  public List<List<Object>> queryKeys(String[] templates, Map<?, ?> variables) {
    return Arrays.stream(templates)
        .map(template -> queryKey(Arrays.asList(StringUtils.split(template, '/')), variables))
        .distinct()
        .toList();
  }

  public void send(String channel, List<List<Object>> queryKeys) {
    send(List.of(channel), queryKeys);
  }

  public void send(List<String> channels, List<List<Object>> queryKeys) {
    for (var queryKey : queryKeys) {
      notifyClient.refreshUi(new RefreshUiReq(queryKey, channels));
    }
  }

  List<Object> queryKey(List<String> segments, Map<?, ?> variables) {
    var queryKey = new ArrayList<>(segments.size() + 1);
    queryKey.add(environment.getRequiredProperty("spring.application.name"));
    for (var segment : segments) {
      var variable = PATH_VARIABLE.matcher(segment);
      if (variable.matches()) {
        var name = variable.group(1);
        queryKey.add(
            Objects.requireNonNull(
                variables.get(name), "Missing refresh UI path variable: " + name));
      } else {
        queryKey.add(segment);
      }
    }
    return List.copyOf(queryKey);
  }
}
