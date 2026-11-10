# AGENTS.md

## 必须遵守

- 不要修改 `README.md`。
- 开发功能时，不要额外生成解释该功能的文档文件，文件格式包括但不限于 `.md`、`.txt`。
- 不要写 examples。
- 不要重复发明轮子。已有知名、成熟的开源库提供所需功能或函数时，优先复用项目已有的依赖，也可以按需添加依赖并直接调用库提供的 API。
- 不要写代码注释；只在复杂逻辑和容易误解的地方写简短注释。
- 除非明确要求，否则不要编写测试代码。需要测试时，只写 e2e 测试，不写单元测试。
- 当发现现有上游接口无法满足功能实现要求时，直接中断执行并提示需要上游添加或调整接口，不要在本项目中绕过或硬编码实现。
- 当发现上游返回的数据有误或不符合规范，立即停止当前实现，指出具体差异并要求上游修正。不要在本项目中强行适配、兜底或硬编码绕过问题。
- 不要编写异常捕获代码，让原始异常向上传播，避免掩盖失败原因或增加复杂处理逻辑。
- 同名方法或函数的重载签名必须连续声明，实现紧跟在最后一个重载签名之后。要注意新插入的方法不要打破原有的这个规则

## 构建与验证

- 代码修改完成就算开发完成了，不要运行命令进行验证。
- 不要执行 `mvn install`。
- hurl 用例通过 `./ci-test.sh <base_url> "--test" <file-or-dir>` 或 `--very-verbose` 执行；除非用户明确要求，不主动新增或运行 e2e 用例。

## 包与依赖

- `com.lttatt.platform.common` 放全局配置、通用响应、异常、通用 DTO、通用 eao/service 等基础设施，不依赖业务代码。

## 分层约定

- 保持 `eao` -> `service` -> `app` 的方向：上层可调用下层，下层不能调用上层。
- `eao`：实体、Repository、Specification、数据库/Redis/Mongo 类型、查询 DTO，不写接口层逻辑。
- `service`：业务流程、事务、事件监听、外部服务调用；复杂或可复用流程优先沉到 Service。
- `app`：REST 接口层，负责路由、权限、参数合法性、资源归属校验和请求/响应 DTO 转换。
- 合法性校验主要放在 `app` 层；领域流程中的状态校验和跨实体一致性校验放在 `service` 层。
- 简单 CRUD 可沿用现有 Resource 直接调用 Repository 的风格；一旦涉及多实体写入、异步、副作用或复用，就提到 Service。
- `service` 层方法优先复用适用的现有 Entity。参数不超过 3 个时直接传参，超过 3 个且需要封装时才定义以 `Data` 结尾的参数类型。

## 包与命名

- REST 控制器命名保持 `*Resource.java`。
- 用户接口放 `app/`，管理员接口放 `app/admin/`，公开接口放 `app/pub/`。
- REST 请求/响应 DTO 放对应的 `app/**/rep/` 目录。请求为 `*Req`，响应为 `*Resp`，尽量使用 `record`。
- JPA 实体和 Repository 放 `eao/`；枚举放 `eao/type/`；Repository 查询投影 DTO 放 `eao/type/dto/`；Specification 放 `eao/spec/`。
- 配置属性类放 `service/prop/` 或已有的配置包，命名保持 `*Properties.java`。
- Spring event 类型放 `service/type/event/`。

## REST 接口规范

- 需要登录的用户接口路径一般以 `user/...` 开头。
- 管理接口路径一般以 `admin/...` 开头。
- 公开接口使用 `pub/...`。
- 当前用户通过 `@AuthenticationPrincipal MyUserDetails userDetails` 获取。
- Controller 使用 `@Tag`，接口方法使用 `@Operation(summary = "...")`，说明保持简洁。
- 请求体使用 `@Valid @RequestBody XxxReq`，路径和查询参数用 Spring MVC 标准注解。
- 资源归属校验必须在接口层完成；嵌套路由要校验子资源确实属于父资源，不要泄露其他用户资源是否存在。
- 由 `GeneralOperationResultAdvice` 包装的响应直接返回业务结果。包装规则适用于符合条件的 HTTP 200 JSON 响应，跳过 `/internal/**`、文件响应和 OpenAPI 文档。
- 对适用响应包装的 `void` 接口返回“操作成功”；查询不到资源时使用 `GeneralOperationResultException.resourceNotExist()`。
- 业务错误优先抛 `GeneralOperationResultException`，不要随意引入新的异常响应格式。

## Resource 标准写法

- Resource 类名按资源和入口命名：用户接口 `XxxResource`，管理接口 `XxxAdminResource`，公开接口 `XxxPubResource`。
- `@Tag(name = "...")` 的 name 与类名保持一致；`description` 使用简短中文名称，后台接口可加“(后台)”。
- 类级路径使用 kebab-case，集合资源使用复数资源名。
- 标准 CRUD 方法名保持：列表 `readAll`，单个 `read`，创建 `create`，全量修改 `update`，局部修改 `patch`，删除 `delete`。
- 列表查询统一返回 `Page<XxxResp>`，参数使用 `Pageable`；需要默认排序时使用 `@PageableDefault`。
- Resource 中列表查询参数可能为 `null` 时，优先使用 Specification 按非空参数组合查询条件；不要为了不同参数组合调用多个 Repository 查询方法，也不要在 JPQL 中写 `:param is null or ...` 这类参数判空逻辑。
- 单个资源路径使用 `"{id}"`；子动作路径使用 `"{id}/xxx"`，动词动作优先使用 `@PostMapping`。
- `patch` 接口先查询 Entity，再在 Java 中判断请求参数是否为 `null`；不为 `null` 时设置到 Entity 并保存，不要通过 JPQL 直接更新。
- `patch` 接口需要同时区分“未修改”和“将可空字段清空为 `null`”时，在 `PatchReq` 中为该字段增加 `Boolean nullXxx` 标记（例如 `audioUrl` 对应 `nullAudioUrl`）：字段和标记均未传时保持原值，字段非 `null` 时更新字段，`nullXxx` 为 `true` 时将字段设为 `null`；若字段值与清空标记同时传入，以清空为准。

## DTO 与 JSON

- 后缀为 `Req`、`Resp` 的类使用 `record`。
- `Resp` 中从 Entity/DTO 构造响应时，沿用 `static newInstance(...)` 工厂方法。
- Repository 查询投影 DTO 中如果字段要返回 `List<String>`，record 字段保持 `List<String>`；JPQL 聚合值用额外构造器接收 `Object`，在构造器内转成字符串后用 `StringUtils.tokenizeToStringArray(..., ",")` 和 `List.of(...)` 转成列表。
- Java 字段使用 camelCase；外部 JSON 由 `spring.jackson.property-naming-strategy=SNAKE_CASE` 统一转为下划线。
- hurl 断言中的 JSON 字段使用下划线，例如 `screen_ratio`、`create_time`。
- 枚举对外默认使用枚举名；实体字段使用 `@Enumerated(EnumType.STRING)`。
- 请求参数校验优先用 `jakarta.validation` 注解和已有自定义校验注解。

## 持久化与数据库

- 后缀为 `Entity` 的类使用 Lombok `@Data` 和 JPA `@Entity`，简单字段不加 `@Table`、`@Column` 等映射注解。
- Entity 只保留必要的 JPA 注解：`@Id`、`@GeneratedValue`、`@Enumerated(EnumType.STRING)` 等。
- 所有 Entity 都必须包含 `id` 和 `createTime` 字段，写法保持：

  ```java
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Integer id;

  @NotNull private LocalDateTime createTime = LocalDateTime.now();
  ```

- 数据库唯一索引、字段类型调整为 `TEXT`/`MEDIUMTEXT`、字段名等，都放到 Liquibase SQL，不要靠 Entity 注解表达。
- 创建数据库表时，一般不指定字段默认值；对于不能为空且有默认值的字段，一般在 Java 的 Entity 字段上指定默认值。
- 现有实体倾向使用显式外键 id 字段，不使用复杂 JPA 关联映射；新增模型优先延续这个风格。
- Repository 通常继承 `JpaRepository<Entity, Integer>`；复杂查询优先使用 JPQL `@Query`、Specification 或投影 DTO。
- Redis KV 放 `eao/redis/`，Mongo 文档放 `eao/mongo/`，按已有 Spring Data 注解组织。
- 新增时间字段优先使用 `LocalDateTime`，命名沿用 `createTime`、`updateTime`。

## 拖动排序

- 需要拖动排序的 JPA 实体实现 `SortOrderEntity`，保留 `id`、`sortOrder` 的 getter/setter，并新增 `@NotNull private Long sortOrder = 1000L;`。
- 对应 Repository 继承 `SortOrderRepository<Entity, Integer>`；如果还需要自定义查询，直接在该 Repository 中继续声明。
- Liquibase 中新增或调整 `sort_order BIGINT NOT NULL DEFAULT 1000`，并为 `sort_order` 增加索引；不要通过 Entity 映射注解表达字段名、默认值或索引。
- 创建新数据时注入 `SortOrderService`，全表排序用 `sortOrderService.nextSortOrder(repository)` 设置 `sortOrder`，分组排序传入对应 `SortOrderScope`；不要手写固定值或自行查询最大值。
- 列表接口按 `sortOrder` 降序返回；公开查询可用 `OrderBySortOrderDesc` 风格的方法名。
- 拖动接口使用 `POST {id}/move`，请求体使用公共 `MoveReq`，方法加 `@Transactional`，实现只调用 `sortOrderService.move(repository, id, req.prevId(), req.nextId())`；分组排序需要传入对应 `SortOrderScope`。
- 前端拖动后传目标位置相邻节点：移动到列表顶部时 `prev_id` 为空、`next_id` 为后一条 id；移动到底部时 `prev_id` 为前一条 id、`next_id` 为空；移动到中间时二者都传；二者不能同时为空，也不能等于当前 id。
- 顺序反转接口使用 `POST reverse`，不需要请求体，方法加 `@Transactional`，实现只调用 `sortOrderService.reverse(repository)`；分组排序需要传入对应 `SortOrderScope`，只反转当前分组，不得影响其他分组。
- 不要为单个实体重复实现排序间隔、反转、重排或边界校验逻辑，统一复用 `SortOrderService`，拖动请求统一使用 `MoveReq`。

## Liquibase

- SQL 文件使用 `--liquibase formatted sql`。
- 编写 SQL 时，不要使用 `COMMENT` 添加注释。一般不要使用 `DEFAULT` 设置列默认值；需要默认值时，一般直接在 Java 的 Entity 字段上设置。
- 表结构变更放在 `src/main/resources/db/changelog/` 下，文件名使用 `*_entity.sql`。
- 新增 changelog 后，同步更新 `db.changelog-master.yaml` 的 `include`。
- 可回滚的 changeset 写 `--rollback`。
- 表名、列名、索引名使用 snake_case；唯一索引优先用 SQL 中的 `UNIQUE KEY` 或 `CONSTRAINT`。
- `user_id` 字段需要添加引用用户表的外键；删除策略一般使用 `ON DELETE CASCADE`，根据业务情况也可以使用 `ON DELETE SET NULL`，此时字段必须允许为 `NULL`。
- 涉及外键时按所有权关系考虑 `ON DELETE CASCADE`，延续现有表设计。

## 事件

- 应用内副作用优先使用 Spring event：发布用 `ApplicationEventPublisher`，监听放在 Service 中使用 `@EventListener`。

## 配置与安全

- 配置属性类使用 `@ConfigurationProperties(prefix = "...")`、`@Configuration`、Lombok `@Data`，默认值写在字段上。
- `application.properties` 中配置项使用 kebab-case，并尽量保留可本地覆盖的默认值。
- 新增敏感配置不要硬编码真实密钥，优先通过外部配置或已有 `spring.config.import` 机制覆盖。
- 认证授权沿用 OAuth2 Resource Server JWT、`Authorization: Bearer …`、`MyUserDetails`、`@PreAuthorize` 和 `@TeamRoleAllowed`。

## Java 风格

- Java 版本为 21，尽量使用较新的语言特性。
- 编写或修改的代码必须满足 SonarQube、Checkstyle 和 PMD 的要求。
- 优先使用 `var`、lambda 和 Stream API，但不要为了“现代”牺牲可读性。
- 不要在代码中使用完整限定名，统一通过 `import` 导入后使用类名，例如使用 `StringUtils`，不要写 `org.apache.commons.lang3.StringUtils`。
- 编码遵循 Google Java Style Guide，代码格式使用 google-java-format，Java 缩进为 2 空格，单行不超过 100 个字符。
- 依赖注入使用 `final` 字段和 Lombok `@RequiredArgsConstructor` 进行构造器注入。
- 如果一个功能已有现成库函数可用，优先使用成熟库函数，不要自己实现；通用功能和知名库已提供的能力尤其如此。
- 判断字符串是否为空时，统一使用 `StringUtils.isBlank` 或 `StringUtils.isNotBlank`。
- 日志使用 Lombok `@Slf4j` 和 `{}` 占位符，不打印密码、token、密钥等敏感信息。
- 简单函数不要写 Javadocs；只有复杂业务规则才添加少量解释性注释。
- 不做无关重构，不顺手改包名、格式、导入顺序或历史风格。

## hurl 用例

- 所有 JSON 字段使用下划线命名，不要使用驼峰命名。
- `e2e/vars.env` 中维护 `context_path=backend-api`，新增 hurl 用例时保持与 `application.properties` 的 `server.servlet.context-path=/backend-api` 一致。
- 使用 `GeneralOperationResult` 的接口按 `$.success`、`$.data`、`$.message` 断言；其他接口按实际响应结构断言。
