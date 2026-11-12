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

## 项目结构

- 本项目是 Python 项目，Python 业务代码放在 `tanqi/` 目录下。
- 根目录 `main.py` 仅作为 FastAPI 轻入口，保留应用初始化、router 注册、`/healthy` 和启动代码；其他接口实现放在 `tanqi/app/` 下对应的 app 层 resource 文件。
- `tanqi/app/` 是应用层，负责 FastAPI 路由、请求参数合法性校验、响应组装、依赖注入与异常到 HTTP 响应的转换。路由文件名以 `_resource.py` 结尾。
- Resource 文件中的 `APIRouter` 变量统一命名为 `api_router`；在 `main.py` 导入时再通过 `as` 改成具体业务 router 名称。
- OpenAPI 接口按所在文件设置 tag。tag 名取不含 `.py` 的文件名并转换为首字母大写的驼峰形式，例如 `monitor_task_resource.py` 使用 `MonitorTaskResource`；Resource 文件统一在 `APIRouter` 的 `tags` 参数中设置，`main.py` 中的接口使用 `Main`。
- `tanqi/service/` 是服务层，负责业务编排和外部服务调用，不依赖 `app` 层。服务文件名以 `_service.py` 结尾。
- `tanqi/dependency/` 专门放 FastAPI 依赖注入定义，统一使用 `Annotated[..., Depends(...)]` 类型别名。
- 分层调用方向为 `app` -> `service`。
- 简单逻辑可以直接写在 Resource 中。涉及业务编排、外部服务调用或复杂规则时，由 Resource 依赖 Service。
- 一般不要新增 `__init__.py`，除非当前目录确实需要显式包初始化逻辑。

## 类型定义

- 类型定义统一放在所属层目录的 `types.py` 中。
- 应用层请求、响应模型放在 `tanqi/app/types.py`。
- 服务层内部业务传输类型放在 `tanqi/service/types.py`。
- `Req` 和 `Resp` 后缀仅用于应用层请求、响应模型。
- Service 层的参数一般直接写在函数原型中，无需单独定义类来传递。
- 应用层请求类型命名以 `Req` 结尾。
- 应用层应答类型命名以 `Resp` 结尾。
- 不要在路由和服务文件中散落定义可复用类型。

## Python 代码风格

- 简单函数不要写 Docstrings。
- 不要过多代码注释；只有复杂逻辑需要简短说明时再写注释。
- 优先使用 Python 3.12+ 的现代语法，例如 `str | None`、内置泛型 `list[str]`、`dict[str, Any]`。
- 新增请求、响应 DTO 优先使用 Pydantic `BaseModel`。
- JSON 字段使用下划线命名，不要使用驼峰命名；对接第三方接口必须使用其指定字段时除外。
- 网络请求默认直接使用返回结果，让原始异常向上传播。仅在确实需要将网络错误转换为特定业务响应、补充上下文信息或执行特殊降级逻辑时校验状态码。

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
