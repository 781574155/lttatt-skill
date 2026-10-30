# AGENTS.md

## 必须遵守

- 不要修改 `README.md`。
- 开发功能时，不要额外生成解释该功能的文档文件，文件格式包括但不限于 `.md`、`.txt`。
- 不要写 examples。
- 不要写过多代码注释；只在复杂逻辑、非显而易见的兼容处理、轮询/拖拽/上传等容易误解的地方写简短注释。
- 除非明确要求，否则不要编写测试代码。React 项目需要测试时，只写 Playwright e2e 测试，不写单元测试。
- `src/http/api` 下的文件由后端 OpenAPI 规范自动生成，并且会在 CI 中自动生成覆盖，绝对不要手工修改。
- 页面和组件开发统一使用 Tailwind CSS，不新增自定义 `.css`、`.module.css` 或样式类型声明文件。
- 当发现现有后端接口无法满足功能实现要求时，直接中断执行并提示需要后端添加接口，不要在前端绕过或硬编码实现。
- 调用后端接口后，一般不要再调用 `toast.add` 做成功提示。HTTP 响应拦截器已经根据后端 `message` 做成功提示，重复调用会造成重复通知。

## 项目技术栈

- 使用 `pnpm` 作为包管理器。
- 项目使用 Vite 8 + React 19 + TypeScript 6，通过 `@vitejs/plugin-react` 和 `@rolldown/plugin-babel` 启用 React Compiler。
- UI 使用 shadcn/ui，配置在 `components.json`，采用 `base-nova` 风格和 `@base-ui/react` 交互原语；优先复用 `src/components/ui` 中的组件。
- 通用图标使用 `lucide-react`；业务 IconFont 使用 `src/components/IconFont.tsx`。
- 消息提示统一使用 `@/components/ui/toast` 导出的 `toast`，由 `src/App.tsx` 中的 `Toaster` 展示。
- 路由使用 React Router 7（`react-router-dom`），入口路由集中在 `src/App.tsx`。
- HTTP 请求使用 Axios 1，统一封装在 `src/http/request.ts`；已安装 Centrifuge，实时订阅按具体业务接入。当前没有独立 SSE 客户端依赖，不要假定已有流式请求封装。
- 服务端状态管理使用 TanStack React Query 5；当前入口尚未挂载 `QueryClientProvider`，接入 Query 时在全局 Provider 层统一初始化。
- 客户端状态优先使用 React Hooks、状态提升和 Context；当前未安装 Zustand，不要直接引用或为简单状态引入新的状态管理依赖。
- 表单使用 React Hook Form 7，通过 `@hookform/resolvers` 对接 Zod 4，统一完成校验和类型推导。
- 样式使用 Tailwind CSS 4，组件沿用现有 shadcn/ui 和 Base UI 体系；不使用 CSS Modules，也不需要样式类型生成依赖。
- 日期处理使用 Day.js，通用数据处理使用 Lodash；不要假定未出现在 `package.json` 中的库已经可用。
- 后端接口客户端和 `API.*` 类型通过 `@easyfollow/openapi` 根据 OpenAPI 规范生成。
- e2e 测试使用 Playwright 1，配置在 `playwright.config.ts`，用例放在 `e2e`；代码质量工具使用 ESLint 10、typescript-eslint 8 和 Prettier 3，CI 接入 SonarQube。
- 使用 `@` 指向 `src` 的路径别名，业务代码优先使用 `@/...` 导入。

## 常用命令

- 安装依赖：`pnpm install`
- 本地开发：`pnpm dev`（启动 Vite）
- 类型检查和构建：`pnpm build`（先运行 `pnpm lint`，再执行 Vite 构建）
- 类型检查和 ESLint：`pnpm lint`（执行 `tsc -b` 和 ESLint）
- 格式化：`pnpm format`
- 根据 OpenAPI 重新生成接口：`pnpm openapi2ts`

## 目录约定

- 以下目录分层是持续保留的架构设计，尚未创建的目录按业务需要建立，不为补齐目录树创建空目录或占位文件。
- `src/App.tsx` 只承担全局 Provider、路由注册、页面布局和 `Toaster` 挂载等职责。后续接入 `IndexLayout` 后，新增页面路由时同步确认是否需要加入菜单。
- `src/layouts` 保留页面外壳和登录保护逻辑的目录设计；后续普通登录后页面使用 `IndexLayout`，独立全屏业务页使用 `DramaLayout`，登录注册页使用 `AuthLayout`。这些布局按业务需要创建。
- `src/pages` 放业务页面。复杂页面优先在同一业务目录内拆分局部组件、弹窗、抽屉和工具函数。
- `src/components` 放跨页面复用组件；其中 `src/components/ui` 放 shadcn/ui 基础组件。多个页面使用相同组件时，必须提取到公共组件，不要在页面内重复实现。
- `src/theme` 保留 TypeScript 主题配置和主题工具的目录设计，按需创建；当前主题 token 及 Tailwind 映射由 `src/styles/tokens.css` 和 `src/styles/shadcn-theme.css` 维护，不另建重复的颜色来源。
- `src/styles/app.css` 是唯一全局样式入口，只能由 `src/main.tsx` 引入；`src/styles` 仅维护 Tailwind 入口、全局主题 token 和基础页面行为，不放业务组件样式。
- `src/utils` 放纯工具、枚举展示映射、上传/CDN 等跨模块逻辑。
- `src/http/request.ts`、`src/http/session.ts`、`src/http/local_storage.ts` 维护请求、登录态和本地存储基础设施。
- `public` 放静态资源；代码中引用公开资源时使用根路径。
- 不要提交或依赖 `node_modules`、`dist`、`out`、`test-results` 等生成目录。

## 前端目录分层

### `src/components`

- 存放跨业务、跨页面复用的通用组件，以及不属于某个具体业务域的基础交互组件。
- `ui` 子目录维护基础组件及其变体；业务无关的组合组件放在 `components` 对应目录，不把业务请求和页面状态塞入基础 UI。
- 典型内容包括通用上传、媒体预览、确认弹窗、头像下拉、批量操作栏、通用卡片和基础选择器。
- 组件应通过 props、children、回调和明确的数据类型对外提供能力，不直接读取某个页面的路由参数或依赖具体业务页面状态。
- `components` 可以依赖 `utils`、`http`、`theme` 和其他更基础的公共组件，但不能依赖 `pages`。
- 如果一个组件只被某个 feature 或页面使用，不要提前放入 `components`；先放在对应业务目录，出现真实的跨业务复用后再提升。

### `src/features`

- 按业务能力组织可复用的领域模块，一个 feature 应表达完整且稳定的业务概念，例如生成、设置、积分、情绪、文件映射、剧集项目等。
- feature 可以包含 `components`、hooks、类型、常量、状态、请求封装和纯业务工具；不要把 feature 简化成只转发文件的目录。
- feature 内只被一个组件使用的子组件放在该组件附近；被 feature 内多个组件复用的内容再提升到 feature 的公共层。
- feature 对外通过自身的 `index.ts` 暴露稳定公共 API；页面优先从 `@/features/<feature>` 导入，不要跨层引用另一个 feature 的深层内部文件。
- feature 可以依赖 `components`、`utils`、`http`、`theme` 和经过公开入口暴露的其他 feature，但不能依赖 `pages`。
- 不要为了消除少量重复就让两个 feature 相互依赖；共同能力应下沉到 `components`、`utils`，或提取为边界清晰的新 feature。
- feature 中调用后端接口时仍使用 React Query 和生成的 `*Resource`，服务端状态不要封装成重复的本地状态副本。

### `src/pages`

- 存放与路由对应的页面入口和页面级编排，负责读取路由参数、组合 feature/公共组件、组织页面布局以及处理页面级权限和导航。
- 页面目录可以包含只服务于该页面的局部组件、弹窗、抽屉、hooks、类型、常量和工具；这些内容不应直接提升到全局目录。
- 页面入口文件应侧重编排，不应长期承载大段可复用业务逻辑；复杂区域应拆成同页面目录下的局部组件，具备跨页面复用价值后再提升到 feature。
- `pages` 可以依赖 `features`、`components`、`layouts`、`utils`、`http` 和 `theme`；任何 `components`、`features`、`layouts`、`utils` 都不能反向依赖 `pages`。
- 页面之间禁止直接导入彼此的组件、样式或内部工具；需要共享时应提取到对应 feature、公共 component 或 utils。

### 归属判断与依赖方向

- 只服务一个页面的内容放 `pages/<Page>`；服务同一业务域多个页面或入口的内容放 `features/<feature>`；跨业务复用且不携带领域含义的内容放 `components`。
- 纯函数、格式转换、枚举映射等无 React 和业务状态依赖的能力放 `utils`，不要为了复用工具函数创建无意义组件或 feature。
- 推荐依赖方向为 `pages → features → components → utils/theme/http`；允许页面直接使用基础公共层，但禁止产生反向依赖和循环依赖。
- 提取或移动文件时同步更新该模块的公开入口和所有导入路径，不保留长期兼容转发文件。

## TypeScript 与 React 规范

- 编写和修改的代码必须满足项目 ESLint 与 SonarQube 规则，不得通过禁用规则、忽略告警或降低检查级别绕过代码质量要求。
- 遵守当前 TypeScript strict 配置：避免新增未使用变量、未使用参数和隐式不安全类型。
- 类型导入使用 `import type`。
- 页面和组件使用函数组件与 Hooks；页面沿用默认导出，`src/components/ui` 基础组件沿用现有具名导出风格。
- 不要把单个文件写得过大；页面逻辑、局部组件、弹窗、抽屉、表格列配置、工具函数等达到明显复杂度时，及时拆分到独立文件。
- 当 `.tsx` 文件超过 2000 行时，视为文件过大，需要及时拆分，将其中的组件提取到单独文件后再引用。
- 只被一个页面使用的组件，如果所在页面文件已经很大，也要拆到同一业务目录下的独立组件文件中。
- 遵守 React Compiler 和 Hooks 规则，避免在渲染中产生副作用；仅在 Effect 依赖、订阅或外部 API 确实要求稳定引用时使用 `useCallback`，不要机械添加手动记忆化。
- `setInterval`、DOM 事件监听、轮询、拖拽状态、文件上传状态必须有清理逻辑，避免页面切换后继续执行。
- 业务常量、状态标签、枚举 label map 放在组件外层，避免每次渲染重复创建。
- 代码中的中文字符串直接写中文，不要使用反斜杠加 `u` 开头的统一码转义。
- 表单使用 `react-hook-form` 和 `zod` schema，通过 `zodResolver` 统一校验；Base UI 等受控表单组件通过 `Controller` 对接，校验提示使用中文。
- 异步表单提交使用 `try/catch/finally` 或 React Query mutation 状态维护 loading，避免重复提交。
- 后端请求数据、缓存、刷新和失效统一通过 React Query 管理；临时 UI 状态保留在组件中，共享客户端状态优先提升到共同父组件或通过 Context 管理，不复制服务端状态。
- 与后端交互的数据类型优先使用 `API.*` 生成类型；只有生成类型不完整时，才做局部类型收窄或极少量断言。
- 不要为了绕过类型错误引入大范围 `any`、`// @ts-ignore` 或关闭规则。

## 接口调用规范

- 业务代码调用生成接口时，统一从 `@/http/api` 具名导入对应 `*Resource`；调用时使用 `Resource.method()` 形式。
- 实时刷新沿用服务端事件驱动的设计：首次加载、搜索和分页可以正常发起 Query，后续刷新由 `user-{userId}` 频道的 `RefreshUI.data.query_key` 触发 React Query 缓存失效。当前尚未接入订阅基础设施，相关功能应统一接入，不在页面中各自建立连接。
- 禁止业务代码在 mutation 后主动调用 `read`、`readAll`、`refetch` 获取最新内容，禁止使用 `refetchInterval`、`setInterval` 或其他轮询刷新服务端状态，也不要将接口响应手工同步为服务端状态副本。
- 后端接口变化时，使用 `pnpm openapi2ts` 重新生成 `src/http/api`，不要直接编辑生成文件；该目录会在 CI 中自动生成覆盖，手工改动不会被保留。
- 如果生成接口缺少页面实现所需的能力、字段或请求参数，停止当前实现并说明需要后端补充接口，不要通过手写请求、修改生成文件或前端假数据绕过。
- 响应数据按现有模式读取：`res.data?.data`；分页列表通常读取 `content` 和 `page.total_elements`。
- 页面分页展示统一从 1 开始，调用后端 pageable 时按生成接口的参数定义转换，后端从 0 开始时传 `page - 1`。
- 接口错误交给 `src/http/request.ts` 的响应拦截器处理，业务代码 `catch` 中一般只保持静默或做必要状态恢复。
- 成功提示默认交给响应拦截器；只有明确需要禁用时，传 `{ noMessageSuccess: true }`。
- 需要拿原始响应或自行处理成功/失败时，传 `{ noResponseInterceptor: true }`，并在调用处完整处理状态。
- 文件上传使用生成的 `UploadFileResource` 和文件选择交互；跨页面复用的上传逻辑可提取到 `src/utils/uploadUtil.ts`，该工具当前尚未创建。上传必须处理 loading、重复提交和组件卸载后的清理。

## UI 与交互规范

- 项目只面向一个标准屏幕尺寸设计和开发；不要编写针对多个屏幕尺寸、分辨率或断点的响应式 CSS 和适配代码。
- 不要实现无障碍功能或添加无障碍专用属性、语义和交互；仅在 E2E 测试需要稳定定位元素时允许添加相关属性。
- 页面 UI 优先复用 `@/components/ui` 中的 shadcn/ui 组件，缺少基础组件时沿用 `components.json` 配置和 Base UI 体系补充，不引入第二套组件库。
- 图标优先使用 `lucide-react`，业务图标复用 `IconFont`，不要手写已有图标。
- 页面布局和局部样式统一使用 Tailwind CSS；基础组件外观通过现有语义 token、组件变体和 `className` 调整。
- 页面和组件使用全局主题映射的 Tailwind 语义类，保持现有暗色主题；不要在组件中重复定义颜色、圆角、阴影和字体 token。
- 管理后台列表页保留顶部标题和操作区、列表、分页、弹窗或抽屉表单的结构设计；基于 shadcn/ui 和 Base UI 实现，列表使用稳定的业务 `id` 作为 key，删除操作使用确认弹窗。
- 破坏性操作必须有确认；长耗时操作必须有 loading、禁用态或进度反馈。
- 首页、登录注册、普通后台等页面统一使用 Tailwind CSS 完成布局和局部视觉，复用现有全局主题 token。
- 全屏创作、画布、分镜等沉浸式页面可以使用固定布局，但要确保页面切换时清理轮询、事件监听和临时状态。
- 所有面向用户的文案保持中文，表单校验提示也使用中文。

## 路由与权限

- 当前使用 `BrowserRouter`，仅注册 `/` 首页，未知路由重定向到 `/`。
- 保留后续路由设计：`/`、`/login`、`/register` 为公开入口；登录注册页挂在 `AuthLayout` 下，普通登录后页面挂在 `IndexLayout` 下，独立全屏业务页挂在 `DramaLayout` 下。
- 新增登录后页面时同步接入登录保护；新增 `/admin` 页面时按后端角色字段实施 `ROLE_ADMIN` 校验，并同步处理菜单过滤和非管理员重定向，不能假定已有权限守卫。
- 登录态通过 `src/http/session.ts` 管理，接口请求头由拦截器自动添加 `TQ-Authorization`。

## 样式与格式化

- 遵守 `.prettierrc`：双引号、分号、2 空格缩进、尾随逗号、120 列。
- 不要引入与现有格式冲突的自动格式化配置。
- Tailwind CSS 类名保持简洁，重复或过长的样式组合应提取为组件，不要滥用任意值。
- 全局主题和基础样式修改要谨慎，避免影响现有组件和全站布局。
- 局部页面样式尽量贴近已有页面的密度、间距和暗色主题，不要引入不一致的大面积新视觉体系。

## 样式开发规范

### 样式职责

- 页面和组件统一通过 `className` 使用 Tailwind CSS，不新增自定义 `.css`、`.module.css`、CSS-in-JS 样式文件或组件内 `<style>`。
- 布局、间距、尺寸、颜色、边框、伪元素、状态和动画优先使用 Tailwind 工具类及其变体。
- 组件变体沿用 `class-variance-authority`，条件类名合并沿用 `cn`，不要引入新的样式框架。
- 内联 `style` 只用于坐标、进度、缩放、拖拽位置、动态尺寸等运行时数据；固定视觉使用 Tailwind 类名。
- 重复或过长的样式组合应随结构和行为提取为可复用组件，不通过新建样式文件复用。

### 全局主题与基础样式

- 保留 `src/styles/app.css` 作为唯一全局入口，负责加载 Tailwind、shadcn、字体以及现有全局主题和基础样式。
- `src/styles/tokens.css` 维护全局设计 token 和 Tailwind 语义映射，`src/styles/shadcn-theme.css` 维护 shadcn 主题映射。
- `src/styles/base.css` 仅维护全局基础页面行为，禁止追加业务组件选择器。
- 全局样式文件只用于基础设施和主题维护，不作为组件开发的样式扩展入口。
- 新增颜色、圆角、阴影和字体层级前，先检查现有主题 token；优先使用 `bg-background`、`text-foreground`、`border-border` 等语义类。
- 不在组件中重复定义品牌色或全局 token，不通过更换文件扩展名或注入样式字符串绕过组件样式约束。

### 组件样式与复用

- 页面和组件不得导入业务 `.css` 或 `.module.css`；第三方库的必要样式由应用入口统一引入。
- 状态通过 Tailwind 的 `hover:`、`disabled:`、`data-*` 等变体表达，不新增全局状态类或业务选择器。
- Base UI 组件优先通过公开的 `render`、状态属性和 `className` 组合结构与交互；链接按钮沿用现有 `render` 与 `nativeButton={false}` 的组合方式。
- 基础组件保留现有 props 透传、`data-slot` 和状态属性，样式通过 Tailwind 变体表达，不依赖第三方内部 DOM 或生成类名。
- 条件类名统一从 `cn` 包导入 `cn`，不要假定 `@/utils/cn` 已存在。
- 多个页面需要相同结构和视觉时，提取到公共组件；只在同一业务域复用时，放在对应 feature。
- 不恢复 CSS Modules 的 Vite 配置、类型生成脚本、监听进程或相关依赖。

## 测试与验证

- 除非明确要求，不新增测试代码。
- 如果要求为 React 功能补测试，只写 Playwright 测试，放在 `e2e`。
- Playwright 测试按模块拆分为不同的 `*.spec.ts` 文件，使用文件作为分组边界；测试文件内不要使用 `test.describe` 分组。
- 不要在测试代码中设置或覆盖超时时间，包括但不限于 `test.setTimeout()`、`testInfo.setTimeout()` 以及为断言、轮询、页面操作或等待方法传入 `timeout`；所有测试统一遵循 `playwright.config.ts` 中配置的全局超时时间。
- Playwright 测试默认走真实前后端访问，不要使用 mock 数据、`route.fulfill` 伪造接口响应或前端假数据绕过真实接口行为；确需为测试场景补充请求参数时，可以用 `page.route` 修改请求后 `route.continue` 继续访问真实后端，例如验证码发送传 `send:false`。
- Playwright E2E 测试禁止通过 `page.waitForResponse()`、`isXxxResponse` 等方式等待或断言具体后端接口；业务结果必须通过页面可见内容、组件状态或页面跳转验证。`APIRequestContext` 只用于测试数据准备和清理，不作为页面功能成功的断言依据。
- Playwright 测试不要使用 CSS 选择器，直接使用中文名称定位；如果组件没有中文名称，可以使用 `aria-label`。
- Playwright 用例按需使用 `e2e/vars.env` 中的测试配置；涉及登录时将可复用辅助提取到 `e2e/helpers/auth.ts`，该辅助当前尚未创建，不在用例中重复实现。
- 本地运行 e2e 时需要设置 `E2E_TEST_BASE_URL`，或通过 `ci-test.sh` 传入目标地址。
- 修改 TypeScript/React 代码后，不要运行 `pnpm lint` 和 `pnpm build` 等命令做验证。代码修改完成就算开发完成了，不要运行命令进行验证。
