package com.lttatt.platform.common.web;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 为 REST Controller 或 MCP 工具方法指定操作成功后要刷新的查询。
 *
 * <ul>
 *   <li>REST 省略注解时，{@code POST} 刷新请求路径，{@code PUT}、{@code PATCH} 和
 *       {@code DELETE} 刷新去掉最后一段后的路径。其他请求方法和未标注的 MCP 工具默认不刷新。
 *   <li>直接使用 {@code @RefreshUi} 时，{@link #value()} 默认为空数组，关闭该方法的刷新通知。
 *   <li>指定一个或多个路径时，这些路径覆盖默认规则。路径从应用根路径开始，不包含 context path。
 *       {@code {变量名}} 在 REST 中引用路径变量，在 MCP 中引用工具方法的参数名。
 *       MCP 的 {@code {teamId}} 来自已授权的团队上下文。
 *   <li>路径展开后按查询键去重，每个查询键向当前频道发送一条通知。MCP 工具成功返回后发送，
 *       有事务时等到事务提交。
 * </ul>
 */
@Documented
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface RefreshUi {
  String[] value() default {};
}
