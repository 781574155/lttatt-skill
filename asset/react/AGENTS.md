# AGENTS.md

## 必须遵守

- 不要修改 `README.md`。
- 开发功能时，不要额外生成解释该功能的文档文件，文件格式包括但不限于 `.md`、`.txt`。
- 不要写 examples。
- 不要写过多代码注释；只在复杂逻辑、非显而易见的兼容处理、轮询/拖拽/上传等容易误解的地方写简短注释。
- 除非明确要求，否则不要编写测试代码。React 项目需要测试时，只写 Playwright e2e 测试，不写单元测试。
- `src/http/api` 下的文件由后端 OpenAPI 规范自动生成，并且会在 CI 中自动生成覆盖，绝对不要手工修改。
- 当发现现有后端接口无法满足功能实现要求时，直接中断执行并提示需要后端添加接口，不要在前端绕过或硬编码实现。
- 调用后端接口后，一般不要再调用 `message.success`。HTTP 响应拦截器已经根据后端 `message` 做成功提示，重复调用会造成重复通知。

## 项目技术栈

- 使用 `pnpm` 作为包管理器。
- 项目是 Vite + React 19 + TypeScript，UI 主要使用 Ant Design 6、`@ant-design/icons`。
- 路由使用 `react-router-dom`，入口路由集中在 `src/App.tsx`。
- HTTP 请求使用 `axios`，统一封装在 `src/http/request.ts`。
- e2e 测试使用 Playwright，配置在 `playwright.config.ts`，用例放在 `e2e`。
- 使用 `@` 指向 `src` 的路径别名，业务代码优先使用 `@/...` 导入。

## 常用命令

- 安装依赖：`pnpm install`
- 本地开发：`pnpm dev`
- 类型检查和构建：`pnpm build`
- ESLint：`pnpm lint`
- 格式化：`pnpm format`
- 根据 OpenAPI 重新生成接口：`pnpm openapi2ts`

## 目录约定

- `src/App.tsx` 只承担全局 Provider、路由注册、页面布局挂载等职责。新增页面路由时，同步确认是否需要加入 `IndexLayout` 菜单。
- `src/layouts` 放页面外壳和登录保护逻辑。普通登录后页面使用 `IndexLayout`，独立全屏业务页使用 `DramaLayout`。
- `src/pages` 放业务页面。复杂页面优先在同一业务目录内拆分局部组件、弹窗、抽屉和工具函数。
- `src/components` 放跨页面复用组件。
- `src/theme/index.ts` 维护 Ant Design 全局主题；通用视觉调整优先走 theme token。
- `src/index.css` 只放全局样式、滚动条、全局组件覆写等影响全站的样式。
- `src/utils` 放纯工具、枚举展示映射、上传/CDN 等跨模块逻辑。
- `src/http/request.ts`、`src/http/session.ts`、`src/http/local_storage.ts` 维护请求、登录态和本地存储基础设施。
- `public` 放静态资源；代码中引用公开资源时使用根路径。
- 不要提交或依赖 `node_modules`、`dist`、`out`、`test-results` 等生成目录。

## TypeScript 与 React 规范

- 遵守当前 TypeScript strict 配置：避免新增未使用变量、未使用参数和隐式不安全类型。
- 类型导入使用 `import type`。
- 页面和组件使用函数组件与 Hooks，保持现有默认导出风格。
- 需要被 `useEffect`、子组件 props 或轮询逻辑复用的函数，优先用 `useCallback` 固定引用。
- `setInterval`、DOM 事件监听、轮询、拖拽状态、文件上传状态必须有清理逻辑，避免页面切换后继续执行。
- 业务常量、状态标签、枚举 label map 放在组件外层，避免每次渲染重复创建。
- 表单提交统一使用 `Form.useForm()`、`validateFields()` 和 `try/catch/finally` 维护 loading。
- 与后端交互的数据类型优先使用 `API.*` 生成类型；只有生成类型不完整时，才做局部类型收窄或极少量断言。
- 不要为了绕过类型错误引入大范围 `any`、`// @ts-ignore` 或关闭规则。

## 接口调用规范

- 业务页面从 `@/http/api/*Resource` 导入生成函数，不要手写同类请求封装。
- 后端接口变化时，使用 `pnpm openapi2ts` 重新生成 `src/http/api`，不要直接编辑生成文件；该目录会在 CI 中自动生成覆盖，手工改动不会被保留。
- 如果生成接口缺少页面实现所需的能力、字段或请求参数，停止当前实现并说明需要后端补充接口，不要通过手写请求、修改生成文件或前端假数据绕过。
- 响应数据按现有模式读取：`res.data?.data`；分页列表通常读取 `content` 和 `page.total_elements`。
- Ant Design Table 的分页页码是从 1 开始，后端 pageable 通常按 `page - 1` 传参。
- 接口错误交给 `src/http/request.ts` 的响应拦截器处理，业务代码 `catch` 中一般只保持静默或做必要状态恢复。
- 成功提示默认交给响应拦截器；只有明确需要禁用时，传 `{ noMessageSuccess: true }`。
- 需要拿原始响应或自行处理成功/失败时，传 `{ noResponseInterceptor: true }`，并在调用处完整处理状态。
- 上传文件优先复用 `src/utils/uploadUtil.ts`、`Upload` 的 `beforeUpload` 模式，并返回 `false` 阻止浏览器自动上传。

## UI 与交互规范

- 页面 UI 优先使用 Ant Design 组件和 `@ant-design/icons`，不要手写已有图标。
- 颜色、圆角、阴影、间距优先使用 `theme.useToken()`，保持当前黑色背景、橙色强调色的视觉体系。
- 管理后台列表页保持现有模式：顶部标题和操作区、`Table`、`Modal`/`Drawer` 表单、`Popconfirm` 删除确认、`rowKey="id"`、必要时设置横向 `scroll`。
- 破坏性操作必须有确认；长耗时操作必须有 loading、禁用态或进度反馈。
- 首页、登录注册等独立视觉页面可以使用局部 CSS；普通后台页面优先使用 Ant Design token 和内联布局样式。
- 全屏创作、画布、分镜等沉浸式页面可以使用固定布局，但要确保页面切换时清理轮询、事件监听和临时状态。
- 所有面向用户的文案保持中文，表单校验提示也使用中文。
- 图片、视频、素材 URL 展示前优先经过 `withCdn`，除非调用处明确需要原始地址。

## 路由与权限

- `/`、`/login`、`/register` 是公开入口；登录注册页面挂在 `AuthLayout` 下。
- 常规页面挂在 `IndexLayout` 下。
- 剧集详情、分镜详情、画布等独立业务界面挂在 `DramaLayout` 下。
- 管理后台入口受 `ROLE_ADMIN` 控制：新增 `/admin` 页面时，同步检查菜单过滤和非管理员重定向逻辑。
- 登录态通过 `src/http/session.ts` 管理，接口请求头由拦截器自动添加 `TQ-Authorization`。

## 样式与格式化

- 遵守 `.prettierrc`：双引号、分号、2 空格缩进、尾随逗号、120 列。
- 不要引入与现有格式冲突的自动格式化配置。
- 全局 CSS 修改要谨慎，避免影响 Ant Design 组件和全站布局。
- 局部页面样式尽量贴近已有页面的密度、间距和暗色主题，不要引入不一致的大面积新视觉体系。

## 测试与验证

- 除非明确要求，不新增测试代码。
- 如果要求为 React 功能补测试，只写 Playwright 测试，放在 `e2e`。
- Playwright 用例优先复用 `e2e/helpers/auth.ts` 的登录辅助和 `e2e/vars.env` 凭据。
- 本地运行 e2e 时需要设置 `E2E_TEST_BASE_URL`，或通过 `ci-test.sh` 传入目标地址。
- 修改 TypeScript/React 代码后，不要运行 `pnpm lint` 和 `pnpm build` 等命令做验证。代码修改完成就算开发完成了，不要运行命令进行验证。
