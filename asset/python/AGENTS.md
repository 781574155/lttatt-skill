# AGENTS.md

## 项目结构

- 本项目是 Python 项目，Python 业务代码放在 `tanqi/` 目录下。
- 根目录 `main.py` 仅作为 FastAPI 轻入口，保留应用初始化、router 注册、`/healthy` 和启动代码；其他接口实现放在 `tanqi/app/` 下对应的 app 层 resource 文件。
- `tanqi/app/` 是应用层，负责 FastAPI 路由、请求参数合法性校验、响应组装、依赖注入与异常到 HTTP 响应的转换。路由文件名以 `_resource.py` 结尾。
- Resource 文件中的 `APIRouter` 变量统一命名为 `api_router`；在 `main.py` 导入时再通过 `as` 改成具体业务 router 名称。
- `tanqi/service/` 是服务层，负责业务编排和外部服务调用，不依赖 `app` 层。服务文件名以 `_service.py` 结尾。
- `tanqi/eao/` 是数据访问层，负责持久化读写，不依赖 `service` 和 `app` 层。数据访问文件名以 `_repository.py` 结尾。
- `tanqi/dependency/` 专门放 FastAPI 依赖注入定义，统一使用 `Annotated[..., Depends(...)]` 类型别名。
- 分层调用方向保持 `app` -> `service` -> `eao`；对于简单查询或简单数据读写逻辑，允许 `app` -> `eao`，禁止 `service` 或 `eao` 反向依赖 `app`。
- 依赖注入链通常保持 DB -> Repository -> Service -> Resource；Repository 依赖 DB，Service 依赖 Repository。Resource 可以根据场景依赖 Service 或 Repository，不是必须依赖 Service；简单逻辑和简单业务逻辑可以直接写在 Resource 中，没必要走 Service 或 Repository，涉及业务编排、外部服务调用、持久化读写或复杂规则时再拆到对应层。
- 一般不要新增 `__init__.py`，除非当前目录确实需要显式包初始化逻辑。
- `tanqi/mq/types.py` 是根据后端接口的 OpenAPI 规范自动生成的文件，不要修改。

## 类型定义

- 类型定义统一放在所属层目录的 `types.py` 中。
- 应用层请求、响应模型放在 `tanqi/app/types.py`。
- 服务层内部业务传输类型放在 `tanqi/service/types.py`。
- 数据访问实体类型放在 `tanqi/eao/types.py`。
- `Req` 和 `Resp` 后缀仅用于应用层请求、响应模型，Service 层和 Repository 层不要使用这些命名后缀。
- Service 层和 Repository 层的参数一般直接写在函数原型中，无需单独定义类来传递。
- 应用层请求类型命名以 `Req` 结尾。
- 应用层应答类型命名以 `Resp` 结尾。
- 持久化实体类型命名以 `Entity` 结尾。
- 查询或数据访问类命名以 `Repository` 结尾。
- 不要在路由、服务、Repository 文件中散落定义可复用类型。

## Python 代码风格

- 简单函数不要写 Docstrings。
- 不要过多代码注释；只有复杂逻辑需要简短说明时再写注释。
- 优先使用 Python 3.12+ 的现代语法，例如 `str | None`、内置泛型 `list[str]`、`dict[str, Any]`。
- 新增请求、响应 DTO 优先使用 Pydantic `BaseModel`。
- 数据访问层持久化实体使用 SQLAlchemy ORM 定义。
- JSON 字段使用下划线命名，不要使用驼峰命名；对接第三方接口必须使用其指定字段时除外。
- 网络请求默认假设远程服务器能正常返回，直接使用返回结果；不要总是捕获异常或校验状态码，避免代码到处都是 `try except` 和重复状态码判断。只有确实需要把网络错误转换为特定业务响应、补充上下文信息或执行特殊降级逻辑时，才添加异常捕获或状态码校验。

## 依赖管理

- 添加 Python 依赖包时在 `requirements.in` 中添加，不要直接修改 `requirements.txt`。
- 更新锁定依赖时运行 `uv pip compile requirements.in -o requirements.txt`。

## 测试与文档

- 不要修改 `README.md` 文件，除非用户明确要求。
- 开发功能时，不要生成针对该功能进行解释的 Markdown 文件。
- 不要写 examples。
- 除非用户明确要求，否则不要编写测试代码。
- 代码修改完成即视为开发完成，不要运行命令进行验证。
- 新增 hurl 用例时，所有 JSON 字段使用下划线命名。
