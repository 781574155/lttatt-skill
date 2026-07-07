# AGENTS.md

## 项目边界

- 不要修改 `README.md`。
- 开发功能时，不要新增针对该功能进行解释的 `.md` 文件。
- 不要写 `examples`，也不要新增 `examples/` 目录。
- 除非用户明确要求，否则不要编写测试代码。
- 不要过多添加代码注释；简单函数不要写 Docstring/Javadoc。

## 构建与验证

- 代码修改完成就算开发完成了，不要运行命令进行验证。
- 不要执行 `mvn install`，根 `pom.xml` 的 `install` 阶段会触发 Docker build/tag/push。
- hurl 用例通过 `./ci-test.sh <base_url> "--test" <file-or-dir>` 或 `--very-verbose` 执行；除非用户明确要求，不主动新增或运行 e2e 用例。

## 模块与依赖

- 这是 Maven 多模块项目，实际依赖方向为：
  `common` -> `user` -> `file` / `chat` -> `app`。
- `common` 放通用能力：全局配置、通用响应、异常、通用 DTO、通用 eao/service，不依赖业务模块。
- `user` 放用户、认证授权、支付、用户校验等能力，可依赖 `common`。
- `file` 放文件上传、MinIO、文件映射等能力，当前依赖 `user`。
- `chat` 放聊天会话、聊天记录、聊天用量等能力，当前依赖 `user`。
- `app` 是业务聚合和启动模块，放主应用入口、剧集业务、模型、MQ 配置以及总 Liquibase master，可依赖 `user`、`file`、`chat`。
- 新增代码放到所属模块，禁止为了调用方便引入反向依赖；跨模块共享类型放到下层模块或 `export/type/**`。

## 分层约定

- 保持 `eao` -> `service` -> `app` 的方向：上层可调用下层，下层不能调用上层。
- `eao`：实体、Repository、Specification、数据库/Redis/Mongo 类型、查询 DTO，不写接口层逻辑。
- `service`：业务流程、事务、事件监听、MQ 收发、外部服务调用；复杂或可复用流程优先沉到 Service。
- `app`：REST 接口层，负责路由、权限、参数合法性、资源归属校验和请求/响应 DTO 转换。
- 合法性校验主要放在 `app` 层；领域流程中的状态校验和跨实体一致性校验放在 `service` 层。
- 简单 CRUD 可沿用现有 Resource 直接调用 Repository 的风格；一旦涉及多实体写入、异步、副作用或复用，就提到 Service。
- `service` 层使用的参数类型后缀命名为 `Data`；`Req` 中可以提供 `toData` 方法，`Data` 中可以提供 `toEntity` 方法，用于完成对应层级之间的转换。

## 包与命名

- REST 控制器命名保持 `*Resource.java`。
- 用户接口放 `app/`，管理员接口放 `app/admin/`，公开接口放 `app/pub/`。
- 请求/响应 DTO 放对应模块的 `app/**/rep/` 目录。请求为 `*Req`，响应为 `*Resp`，尽量使用 `record`。
- JPA 实体和 Repository 放 `eao/`；枚举放 `eao/type/`；Repository 查询投影 DTO 放 `eao/type/dto/`；Specification 放 `eao/spec/`。
- 配置属性类放 `service/prop/` 或已有的配置包，命名保持 `*Properties.java`。
- Spring event 类型放 `service/type/event/`；MQ 消息类型放 `export/type/mq/`。

## REST 接口规范

- 需要登录的用户接口使用 `@Login`，路径一般以 `user/...` 开头。
- 管理接口使用 `@Admin`，路径一般以 `admin/...` 开头。
- 公开接口使用 `pub/...` 或沿用已有根路径约定，例如 `login2`。
- 当前用户通过 `@AuthenticationPrincipal MyUserDetails userDetails` 获取。
- Controller 使用 `@Tag`，接口方法使用 `@Operation(summary = "...")`，说明保持简洁。
- 请求体使用 `@Valid @RequestBody XxxReq`，路径和查询参数用 Spring MVC 标准注解。
- 资源归属校验必须在接口层完成；嵌套路由要校验子资源确实属于父资源，不要泄露其他用户资源是否存在。
- 不要手动把正常返回值包装成 `GeneralOperationResult`；`GeneralOperationResultAdvice` 会统一包装 JSON 响应。
- `void` 接口会被统一包装为“操作成功”；查询不到资源时使用 `GeneralOperationResultException.resourceNotExist()` 或 `AssertUtil.assertExist`。
- 业务错误优先抛 `GeneralOperationResultException`，不要随意引入新的异常响应格式。

## Resource 标准写法

- Resource 类名按资源和入口命名：用户接口 `XxxResource`，管理接口 `XxxAdminResource`，公开接口 `XxxPubResource`。
- `@Tag(name = "...")` 的 name 与类名保持一致；`description` 使用简短中文名称，后台接口可加“(后台)”。
- 类级路径使用复数资源名和 kebab-case，例如 `@RequestMapping("admin/banners")`、`@RequestMapping("user/ai-calls")`。
- 标准 CRUD 方法名保持：列表 `readAll`，单个 `read`，创建 `create`，全量修改 `update`，局部修改 `patch`，删除 `delete`。
- 列表查询统一返回 `Page<XxxResp>`，参数使用 `Pageable`；需要默认排序时使用 `@PageableDefault`。
- 单个资源路径使用 `"{id}"`；子动作路径使用 `"{id}/xxx"`，动词动作优先使用 `@PostMapping`。
- `patch` 接口先查询 Entity，再在 Java 中判断请求参数是否为 `null`；不为 `null` 时设置到 Entity 并保存，不要通过 JPQL 直接更新。
- 新增 Resource 优先按以下形态组织：

  ```java
  @Tag(name = "BannerAdminResource", description = "轮播图管理(后台)")
  @Admin
  @RestController
  @RequestMapping("admin/banners")
  public class BannerAdminResource {
    @GetMapping
    @Operation(summary = "查看轮播图(列表)")
    public Page<BannerResp> readAll(Pageable pageable) {
      return bannerRepository.findAll(pageable).map(BannerResp::newInstance);
    }

    @GetMapping("{id}")
    @Operation(summary = "查看轮播图(单个)")
    public BannerResp read(@PathVariable Integer id) {
      return bannerRepository
          .findById(id)
          .map(BannerResp::newInstance)
          .orElseThrow(GeneralOperationResultException::resourceNotExist);
    }

    @PostMapping
    @Operation(summary = "创建轮播图")
    public BannerResp create(@Valid @RequestBody BannerCreateReq req) {
      return BannerResp.newInstance(bannerRepository.save(entity));
    }

    @PutMapping("{id}")
    @Operation(summary = "修改轮播图")
    public void update(@PathVariable Integer id, @Valid @RequestBody BannerUpdateReq req) {}

    @PatchMapping("{id}")
    @Operation(summary = "修改轮播图(部分)")
    public void patch(@PathVariable Integer id, @Valid @RequestBody BannerPatchReq req) {}

    @DeleteMapping("{id}")
    @Operation(summary = "删除轮播图")
    public void delete(@PathVariable Integer id) {}
  }
  ```

## DTO 与 JSON

- 后缀为 `Req`、`Resp` 的类使用 `record`。
- `Resp` 中从 Entity/DTO 构造响应时，沿用 `static newInstance(...)` 工厂方法。
- Repository 查询投影 DTO 中如果字段要返回 `List<String>`，record 字段保持 `List<String>`；JPQL 聚合值用额外构造器接收 `Object`，在构造器内转成字符串后用 `StringUtils.tokenizeToStringArray(..., ",")` 和 `List.of(...)` 转成列表，写法参考 `UserProfileDto`。
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
- Liquibase 中新增或调整 `sort_order BIGINT NOT NULL DEFAULT 1000`，不要通过 Entity 映射注解表达字段名或默认值。
- 创建新数据时注入 `SortOrderService`，用 `sortOrderService.nextSortOrder(repository)` 设置 `sortOrder`，不要手写固定值或自行查询最大值。
- 列表接口按 `sortOrder` 升序、`createTime` 降序返回：`Sort.by(Sort.Direction.ASC, "sortOrder").and(Sort.by(Sort.Direction.DESC, "createTime"))`；公开查询可用 `OrderBySortOrderAscCreateTimeDesc` 风格的方法名。
- 拖动接口使用 `POST {id}/move`，请求体使用公共 `MoveReq`，方法加 `@Transactional`，实现只调用 `sortOrderService.move(repository, id, req.prevId(), req.nextId(), "实体中文名")`。
- 前端拖动后传目标位置相邻节点：移动到列表顶部时 `prev_id` 为空、`next_id` 为后一条 id；移动到底部时 `prev_id` 为前一条 id、`next_id` 为空；移动到中间时二者都传；二者不能同时为空，也不能等于当前 id。
- 不要为单个实体重复实现排序间隔、重排或边界校验逻辑，统一复用 `SortOrderService` 和 `MoveReq`。

## Liquibase

- SQL 文件使用 `--liquibase formatted sql`。
- 表结构变更放在所属模块的 `src/main/resources/db/changelog/` 下，文件名保持 `*_entity.sql` 风格。
- 新增 changelog 后，同步更新 `db.changelog-master.yaml` 的 `include`。
- changeset 继续使用仓库已有的作者前缀和递增编号风格；可回滚的变更写 `--rollback`。
- 表名、列名、索引名使用 snake_case；唯一索引优先用 SQL 中的 `UNIQUE KEY` 或 `CONSTRAINT`。
- 涉及外键时按所有权关系考虑 `ON DELETE CASCADE`，延续现有表设计。

## 异步、事件与消息

- 模块内或下游副作用优先使用 Spring event：发布用 `ApplicationEventPublisher`，监听放在 Service 中使用 `@EventListener`。
- RabbitMQ 队列名集中维护在 `RabbitmqConfig.QUEUE_NAMES`。
- 发送 MQ 优先走 `MqService`，消息体放 `export/type/mq/`，并使用 `@Valid` 校验。
- 新增监听器使用 `@RabbitListener(queues = "...")`，队列名必须先加入 `RabbitmqConfig`。
- 异步状态字段优先复用 `AssetStatus`，并保持 `WaitingProcess`、`Processing`、`ProcessSuccess`、`ProcessFailed`、`ProcessCancelled` 的语义一致。

## 配置与安全

- 配置属性类使用 `@ConfigurationProperties(prefix = "...")`、`@Configuration`、Lombok `@Data`，默认值写在字段上。
- `application.properties` 中配置项使用 kebab-case，并尽量保留可本地覆盖的默认值。
- 新增敏感配置不要硬编码真实密钥，优先通过外部配置或已有 `spring.config.import` 机制覆盖。
- 认证授权沿用 `@Login`、`@Admin`、`Roles`、`MyUserDetails`、`Tq-Authorization` 的现有体系。

## Java 风格

- Java 版本为 21，尽量使用较新的语言特性。
- 优先使用 `var`、lambda 和 Stream API，但不要为了“现代”牺牲可读性。
- 代码格式遵循 google-java-format，当前 Java 缩进表现为 2 空格。
- 依赖注入沿用 `jakarta.inject.Inject` 字段注入风格。
- 如果一个功能已有现成库函数可用，优先使用成熟库函数，不要自己实现；通用功能和知名库已提供的能力尤其如此。
- 判断字符串是否为空时，统一使用 `StringUtils.isBlank` 或 `StringUtils.isNotBlank`。
- 日志使用 Lombok `@Slf4j` 和 `{}` 占位符，不打印密码、token、密钥等敏感信息。
- 简单函数不要写 Javadocs；只有复杂业务规则才添加少量解释性注释。
- 不做无关重构，不顺手改包名、格式、导入顺序或历史风格。

## hurl 用例

- 所有 JSON 字段使用下划线命名，不要使用驼峰命名。
- `e2e/vars.env` 中维护 `context_path=backend-api`，新增 hurl 用例时保持与 `application.properties` 的 `server.servlet.context-path=/backend-api` 一致。
- 新增用户的用户名统一为 `u{{timestamp}}`。
- 登录后用 `[Captures]` 保存 token，后续请求使用 `Tq-Authorization: {{..._token}}`。
- 响应断言围绕统一包装结构：`$.success`、`$.data`、`$.message`。
