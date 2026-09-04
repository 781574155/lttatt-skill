#!/usr/bin/env bash

set -uo pipefail

sonar_host_url="${1%/}"
sonar_auth_token="$2"
project_key="$3"
report_directory="out/sonarqube"

mkdir -p "$report_directory"

sonar_get() {
	local endpoint="$1"
	local output="$2"
	shift 2

	local curl_args=()

	if [[ -n "$sonar_auth_token" ]]; then
		curl_args+=(--user "${sonar_auth_token}:")
	fi

	curl --fail --silent --show-error --get "$sonar_host_url/$endpoint" \
		--output "$output" "${curl_args[@]}" "$@"
}

print_json_report() {
	local output
	# 中文通过标准输入传入，结果由 Bash 输出，避免 Windows jq 的编码转换。
	output="$(jq -b -r "$@")" || return
	printf '%s\n' "$output"
}

print_quality_gate_details() {
	print_json_report --slurpfile report "$1" '
      def format_value($metric; $value):
        if $value == null then "-"
        elif ($metric | endswith("coverage") or endswith("duplicated_lines_density")) then "\($value)%"
        else "\($value)"
        end;

      . as $labels
      | ($report[0].projectStatus.conditions // [])
      | if length == 0 then $labels.empty
        else $labels.title, (
          .[]
          | "- \(.metricKey): \($labels.actual): \(format_value(.metricKey; .actualValue)), \($labels.required): \(format_value(.metricKey; .errorThreshold)), \($labels.status): \(.status)"
        ) end
    ' <<'JSON' || echo "解析质量门禁详情失败。"
{"empty":"SonarQube 未返回质量指标。","title":"质量指标:","actual":"实际值","required":"要求","status":"状态"}
JSON
}

print_issue_details() {
	print_json_report --slurpfile report "$1" \
		--arg sonar_host_url "$sonar_host_url" \
		--arg project_key "$project_key" \
		'
      . as $labels
      | $report[0]
      | "\($labels.total): \(.paging.total // .total // (.issues | length)) \($labels.count) (\($labels.shown) \(.issues | length) \($labels.count))",
      (if (.issues | length) > 0 then $labels.title else empty end),
      (.issues
      | to_entries[]
      | .key as $index
      | .value as $issue
      | (($issue.component // "-") | sub("^[^:]*:"; "")) as $file
      | ($issue.line // $issue.textRange.startLine) as $line
      | "\($index + 1). [\($issue.severity // "-")] \($file)\(if $line == null then "" else ":\($line)" end)\n"
        + "   \($labels.type): \($issue.type // "-"), \($labels.rule): \($issue.rule // "-")\n"
        + (if ($issue.impacts | length) > 0 then
            "   \($labels.impact): \($issue.impacts | map("\(.softwareQuality):\(.severity)") | join(", "))\n"
          else "" end)
        + "   \($issue.message // "-")\n"
        + "   \($sonar_host_url)/project/issues?id=\($project_key)&open=\($issue.key)")
    ' <<'JSON' || echo "解析 SonarQube 问题详情失败。"
{"total":"全部代码未解决问题","count":"个","shown":"本次最多展示","title":"问题详情:","type":"类型","rule":"规则","impact":"影响"}
JSON
}

print_failed_metric_issues() {
	local metric="$1"
	local issues_file="$report_directory/issues-${metric}.json"
	local query_args=(
		--data-urlencode "componentKeys=$project_key"
		--data-urlencode 'resolved=false'
		--data-urlencode 'ps=500'
	)
	local severity

	case "$metric" in
	software_quality_blocker_issues | software_quality_high_issues | software_quality_medium_issues | software_quality_low_issues | software_quality_info_issues)
		severity="${metric#software_quality_}"
		severity="${severity%_issues}"
		query_args+=(--data-urlencode "impactSeverities=${severity^^}")
		;;
	blocker_violations | critical_violations | major_violations | minor_violations | info_violations)
		severity="${metric%_violations}"
		query_args+=(--data-urlencode "severities=${severity^^}")
		;;
	violations) ;;
	bugs)
		query_args+=(--data-urlencode 'types=BUG')
		;;
	vulnerabilities)
		query_args+=(--data-urlencode 'types=VULNERABILITY')
		;;
	code_smells)
		query_args+=(--data-urlencode 'types=CODE_SMELL')
		;;
	*)
		echo "指标 ${metric} 未通过，无法直接映射为问题列表，请查看上方指标详情。"
		return
		;;
	esac

	echo "失败指标 ${metric} 对应的问题:"
	if sonar_get api/issues/search "$issues_file" "${query_args[@]}"; then
		print_issue_details "$issues_file"
	else
		echo "获取指标 ${metric} 对应的问题失败，请检查 API 权限或 SonarQube 版本。"
	fi
}

quality_gate_file="$report_directory/quality-gate.json"
if ! sonar_get api/qualitygates/project_status "$quality_gate_file" \
	--data-urlencode "projectKey=$project_key"; then
	echo "获取质量门禁详情失败，请检查 SonarQube Web API 是否可访问。"
	exit 0
fi

if ! quality_gate_status="$(jq -er '.projectStatus.status | select(type == "string" and length > 0)' "$quality_gate_file")"; then
	echo "解析质量门禁状态失败，无法判断是否通过。"
	exit 0
fi

echo "========================================"
case "$quality_gate_status" in
OK)
	echo "SonarQube Quality Gate 已通过"
	;;
ERROR)
	echo "SonarQube Quality Gate 未通过"
	;;
*)
	echo "SonarQube Quality Gate 状态：${quality_gate_status}，无法判断是否通过。"
	;;
esac
echo "========================================"

print_quality_gate_details "$quality_gate_file"

if [[ "$quality_gate_status" != "ERROR" ]]; then
	exit 0
fi

if ! failed_metrics="$(jq -r '[.projectStatus.conditions[]? | select(.status == "ERROR") | .metricKey] | unique[]' "$quality_gate_file")"; then
	echo "解析失败指标失败，无法筛选对应问题。"
	exit 0
fi

while IFS= read -r metric; do
	[[ -n "$metric" ]] || continue
	print_failed_metric_issues "$metric"
done <<< "$failed_metrics"
