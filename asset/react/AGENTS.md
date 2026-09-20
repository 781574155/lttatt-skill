# AGENTS.md

## 必须遵守

- 不要修改 `README.md`。
- 开发功能时，不要额外生成解释该功能的文档文件，文件格式包括但不限于 `.md`、`.txt`。
- 不要写 examples。
- 不要写过多代码注释；只在复杂逻辑、非显而易见的兼容处理、轮询/拖拽/上传等容易误解的地方写简短注释。
- 除非明确要求，否则不要编写测试代码。React 项目需要测试时，只写 Playwright e2e 测试，不写单元测试。
- `src/http/api` 下的文件由后端 OpenAPI 规范自动生成，并且会在 CI 中自动生成覆盖，绝对不要手工修改。
- 不要修改 `*.module.css.d.ts`，这类文件由工具自动生成。
- 当发现现有后端接口无法满足功能实现要求时，直接中断执行并提示需要后端添加接口，不要在前端绕过或硬编码实现。
- 调用后端接口后，一般不要再调用 `message.success`。HTTP 响应拦截器已经根据后端 `message` 做成功提示，重复调用会造成重复通知。

## 项目技术栈

- 使用 `pnpm` 作为包管理器。
- 项目使用 Vite 7 + React 19 + TypeScript 5.9，并启用 React Compiler。
- UI 主要使用 Ant Design 6、`@ant-design/icons`；AI 对话、Markdown 渲染和模型交互使用 Ant Design X 2 及其 `x-markdown`、`x-sdk`。
- 路由使用 React Router 7（`react-router-dom`），入口路由集中在 `src/App.tsx`。
- HTTP 请求使用 Axios 1，统一封装在 `src/http/request.ts`；SSE 流式请求使用 `@microsoft/fetch-event-source`，实时消息使用 Centrifuge。
- 服务端状态管理使用 TanStack React Query 5，客户端共享状态管理使用 Zustand 5。
- 表单使用 React Hook Form 7，数据校验和类型推导使用 Zod 4。
- 样式使用 Tailwind CSS 4，并与 Ant Design 组件体系配合使用；局部样式使用 CSS Modules，类型声明由 `typed-css-modules` 生成。
- 节点画布和流程编排使用 `@xyflow/react`，拖拽排序和交互使用 `@dnd-kit/react`。
- 日期处理使用 Day.js，通用数据处理使用 Lodash，MD5 摘要使用 `js-md5`。
- 后端接口客户端和 `API.*` 类型通过 `@easyfollow/openapi` 根据 OpenAPI 规范生成。
- e2e 测试使用 Playwright 1，配置在 `playwright.config.ts`，用例放在 `e2e`；代码质量工具使用 ESLint 9 和 Prettier 3。
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
- `src/components` 放跨页面复用组件。多个页面使用相同组件时，必须提取到公共组件，不要在页面内重复实现。
- `src/theme/index.ts` 维护 Ant Design 全局主题，`src/theme/tokens.ts` 维护品牌基础色；通用视觉调整优先走 theme token。
- `src/styles/app.css` 是唯一全局样式入口，只能由 `src/main.tsx` 引入；`src/styles` 下按 token、基础样式、浏览器兼容、通用工具和全局覆写分层。
- `src/utils` 放纯工具、枚举展示映射、上传/CDN 等跨模块逻辑。
- `src/http/request.ts`、`src/http/session.ts`、`src/http/local_storage.ts` 维护请求、登录态和本地存储基础设施。
- `public` 放静态资源；代码中引用公开资源时使用根路径。
- 不要提交或依赖 `node_modules`、`dist`、`out`、`test-results` 等生成目录。

## 前端目录分层

### `src/components`

- 存放跨业务、跨页面复用的通用组件，以及不属于某个具体业务域的基础交互组件。
- 典型内容包括通用上传、媒体预览、确认弹窗、头像下拉、批量操作栏、通用卡片和基础选择器。
- 组件应通过 props、children、回调和明确的数据类型对外提供能力，不直接读取某个页面的路由参数或依赖具体业务页面状态。
- `components` 可以依赖 `utils`、`http`、`theme` 和其他更基础的公共组件，但不能依赖 `pages`。
- 如果一个组件只被某个 feature 或页面使用，不要提前放入 `components`；先放在对应业务目录，出现真实的跨业务复用后再提升。

### `src/features`

- 按业务能力组织可复用的领域模块，一个 feature 应表达完整且稳定的业务概念，例如生成、设置、积分、情绪、文件映射、剧集项目等。
- feature 可以包含 `components`、hooks、类型、常量、状态、请求封装和纯业务工具；不要把 feature 简化成只转发文件的目录。
- feature 内只被一个组件使用的子组件和样式放在该组件附近；被 feature 内多个组件复用的内容再提升到 feature 的公共层。
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
- 提取或移动文件时同步更新该模块的公开入口和所有导入路径，不保留长期兼容转发文件，也不要通过跨目录 CSS 导入掩盖结构问题。

## TypeScript 与 React 规范

- 编写和修改的代码必须满足项目 ESLint 与 SonarQube 规则，不得通过禁用规则、忽略告警或降低检查级别绕过代码质量要求。
- 遵守当前 TypeScript strict 配置：避免新增未使用变量、未使用参数和隐式不安全类型。
- 类型导入使用 `import type`。
- 页面和组件使用函数组件与 Hooks，保持现有默认导出风格。
- 不要把单个文件写得过大；页面逻辑、局部组件、弹窗、抽屉、表格列配置、工具函数等达到明显复杂度时，及时拆分到独立文件。
- 当 `.tsx` 文件超过 2000 行时，视为文件过大，需要及时拆分，将其中的组件提取到单独文件后再引用。
- 只被一个页面使用的组件，如果所在页面文件已经很大，也要拆到同一业务目录下的独立组件文件中。
- 需要被 `useEffect`、子组件 props 或轮询逻辑复用的函数，优先用 `useCallback` 固定引用。
- `setInterval`、DOM 事件监听、轮询、拖拽状态、文件上传状态必须有清理逻辑，避免页面切换后继续执行。
- 业务常量、状态标签、枚举 label map 放在组件外层，避免每次渲染重复创建。
- 代码中的中文字符串直接写中文，不要使用反斜杠加 `u` 开头的统一码转义。
- 新增表单优先使用 `react-hook-form`，并通过 `zod` schema 统一完成校验和类型推导；维护现有 Ant Design Form 时沿用 `Form.useForm()` 和 `validateFields()`。
- 异步表单提交使用 `try/catch/finally` 或 React Query mutation 状态维护 loading，避免重复提交。
- 后端请求数据、缓存、刷新和失效统一通过 React Query 管理；仅组件内部使用的临时 UI 状态保留在组件中，跨页面或跨组件共享的客户端状态使用 Zustand。
- 与后端交互的数据类型优先使用 `API.*` 生成类型；只有生成类型不完整时，才做局部类型收窄或极少量断言。
- 不要为了绕过类型错误引入大范围 `any`、`// @ts-ignore` 或关闭规则。

## 接口调用规范

- 业务代码调用生成接口时，统一从 `@/http/api` 具名导入对应 `*Resource`；调用时使用 `Resource.method()` 形式。
- WebSocket 是已加载服务端状态的唯一更新来源：首次加载、搜索和分页可以正常发起 Query，后续刷新统一由 `user-{userId}` 频道的 `RefreshUI.data.query_key` 触发 React Query 缓存失效；禁止业务代码在 mutation 后主动调用 `read`、`readAll`、`refetch` 获取最新内容，禁止使用 `refetchInterval`、`setInterval` 或其他轮询刷新服务端状态，也不要将接口响应手工同步为服务端状态副本。
- 后端接口变化时，使用 `pnpm openapi2ts` 重新生成 `src/http/api`，不要直接编辑生成文件；该目录会在 CI 中自动生成覆盖，手工改动不会被保留。
- 如果生成接口缺少页面实现所需的能力、字段或请求参数，停止当前实现并说明需要后端补充接口，不要通过手写请求、修改生成文件或前端假数据绕过。
- 响应数据按现有模式读取：`res.data?.data`；分页列表通常读取 `content` 和 `page.total_elements`。
- Ant Design Table 的分页页码是从 1 开始，后端 pageable 通常按 `page - 1` 传参。
- 接口错误交给 `src/http/request.ts` 的响应拦截器处理，业务代码 `catch` 中一般只保持静默或做必要状态恢复。
- 成功提示默认交给响应拦截器；只有明确需要禁用时，传 `{ noMessageSuccess: true }`。
- 需要拿原始响应或自行处理成功/失败时，传 `{ noResponseInterceptor: true }`，并在调用处完整处理状态。
- 上传文件优先复用 `src/utils/uploadUtil.ts`、`Upload` 的 `beforeUpload` 模式，并返回 `false` 阻止浏览器自动上传。

## UI 与交互规范

- 项目只面向一个标准屏幕尺寸设计和开发；不要编写针对多个屏幕尺寸、分辨率或断点的响应式 CSS 和适配代码。
- 不要实现无障碍功能或添加无障碍专用属性、语义和交互；仅在 E2E 测试需要稳定定位元素时允许添加相关属性。
- 页面 UI 优先使用 Ant Design 组件和 `@ant-design/icons`，不要手写已有图标。
- 页面布局和局部样式优先使用 Tailwind CSS；Ant Design 组件的主题级视觉调整仍使用 theme token。
- TSX 中需要动态读取颜色、圆角、阴影和间距时优先使用 `theme.useToken()`；CSS 中优先使用 Ant Design 生成的 `--qishu-*` 变量，保持当前黑色背景、橙色强调色的视觉体系。
- 管理后台列表页保持现有模式：顶部标题和操作区、`Table`、`Modal`/`Drawer` 表单、`Popconfirm` 删除确认、`rowKey="id"`、必要时设置横向 `scroll`。
- 破坏性操作必须有确认；长耗时操作必须有 loading、禁用态或进度反馈。
- 首页、登录注册等独立视觉页面可以使用 Tailwind CSS 或局部 CSS；普通后台页面优先使用 Tailwind CSS 完成布局，并使用 Ant Design token 保持主题一致。
- 全屏创作、画布、分镜等沉浸式页面可以使用固定布局，但要确保页面切换时清理轮询、事件监听和临时状态。
- 所有面向用户的文案保持中文，表单校验提示也使用中文。

## 路由与权限

- `/`、`/login`、`/register` 是公开入口；登录注册页面挂在 `AuthLayout` 下。
- 常规页面挂在 `IndexLayout` 下。
- 剧集详情、分镜详情、画布等独立业务界面挂在 `DramaLayout` 下。
- 管理后台入口受 `ROLE_ADMIN` 控制：新增 `/admin` 页面时，同步检查菜单过滤和非管理员重定向逻辑。
- 登录态通过 `src/http/session.ts` 管理，接口请求头由拦截器自动添加 `TQ-Authorization`。

## 样式与格式化

- 遵守 `.prettierrc`：双引号、分号、2 空格缩进、尾随逗号、120 列。
- 不要引入与现有格式冲突的自动格式化配置。
- Tailwind CSS 类名保持简洁，重复或过长的样式组合应提取为组件，不要滥用任意值。
- 全局 CSS 修改要谨慎，避免影响 Ant Design 组件和全站布局。
- 局部页面样式尽量贴近已有页面的密度、间距和暗色主题，不要引入不一致的大面积新视觉体系。

## CSS 设计规范

### 样式职责

- Ant Design Theme Token 负责全局品牌色、背景层级、文本层级、边框、圆角、阴影以及 Ant Design 组件的默认外观。
- Tailwind CSS 负责布局、间距、尺寸、响应式、常用 flex/grid 和简单视觉工具类；不要用超长 Tailwind 类名表达复杂组件状态。
- CSS Modules 是页面和组件局部样式的默认方案，负责普通局部视觉以及伪元素、动画、复杂状态、画布、时间轴、拖拽、媒体预览和局部第三方组件覆写。
- 内联 `style` 只用于坐标、进度、缩放、拖拽位置、动态尺寸等运行时数据；固定的颜色、边框、间距、布局和字体禁止写成内联样式。
- 全局 CSS 只负责应用基础设施和确实需要全站生效的规则，业务组件样式不得放入全局入口。

### 全局样式分层

- `src/styles/app.css` 是唯一全局入口，并保持 `theme → base → components → utilities` 的级联层顺序。
- `src/styles/tokens.css` 只维护 CSS 语义变量和 Tailwind `@theme` 映射；品牌基础色的 TS 来源维护在 `src/theme/tokens.ts`。
- `src/styles/base.css` 只维护 `html`、`body`、`#root`、字体和基础页面行为。
- `src/styles/browser.css` 只维护滚动条等浏览器兼容样式。
- `src/styles/utilities.css` 只放少量、稳定、跨业务通用的工具类；业务语义类不能放入该文件。
- `src/styles/overrides` 只放确实需要全站生效的第三方组件修正；能用 Ant Design Component Token 解决的，不写 CSS 覆盖。
- 当前 Tailwind 入口有意不引入 Preflight，避免改变 Ant Design 和存量页面基础样式；未经明确评估不要启用 Preflight。

### Token 与颜色

- 新增颜色、圆角、阴影、字体层级前，先检查 `src/theme/index.ts`、`src/theme/tokens.ts` 和 Ant Design Token 是否已经提供对应语义。
- CSS 中优先使用 `--qishu-color-primary`、`--qishu-color-text`、`--qishu-color-bg-container` 等 Ant Design CSS Variables，禁止在多个文件重复维护同一品牌色字面量。
- Tailwind 需要消费主题值时，在 `src/styles/tokens.css` 使用 `@theme inline` 映射为语义工具类，不要在 JSX 中反复使用任意颜色值。
- 业务专属颜色可以定义在组件根节点的 CSS 自定义属性中；只被一个组件使用的变量不要提升到全局 token。
- 不要仅按具体色值命名变量，例如 `--orange-color`；使用 `brand`、`surface`、`text`、`border`、`danger` 等语义命名。

### 组件样式与作用域

- 页面和组件的局部样式默认与所属页面或组件同目录维护并使用 `*.module.css`，由拥有该样式的 TSX 文件直接通过 `import styles from "./Component.module.css"` 引入；每个 TSX 文件最多只能直接导入一个 CSS Module，且统一命名为 `styles`，禁止使用 `fooStyles`、`barStyles` 等其他命名；需要多个独立视觉单元时拆分为子组件，由各子组件直接持有自己的样式；页面和组件的专属样式不得放入 `src/styles` 或全局入口，也不能依靠普通 CSS 副作用导入或其他页面已加载的 CSS 产生隐式全局效果。
- Vite 的 `css.modules.localsConvention` 使用 `camelCaseOnly`，TSX 中的静态模块类名直接使用 `className={styles.root}`、`className={styles.className}`；不要使用 `styles["class-name"]`。多个类名使用模板字符串、数组或现有类名组合工具拼接。只有运行时才能确定完整类名时，才允许把对应的 styles 对象显式传给模块类名解析工具；不要通过预绑定的 `cx("class-name")` 隐藏 styles 引用，不要把静态 Module 类名重新写成字符串常量，也不要依赖构建后生成的类名。
- 新增局部样式禁止使用 `import "./Component.css"` 这类副作用导入，以免选择器进入全局作用域；只有 `src/styles/app.css`、第三方库样式和存量迁移聚合入口允许普通 CSS 副作用导入。
- CSS Module 类名使用简短语义名称，例如 `root`、`header`、`toolbar`、`selectedItem`；存量普通 CSS 继续使用带业务前缀的 BEM 风格，迁移时不要新增无前缀全局类。
- 组件状态优先通过 `data-state`、`data-selected`、`aria-selected`、`aria-disabled` 或 CSS Module 状态类表达，避免不断叠加全局 `is-*` 类。
- 页面或组件不能导入其他业务页面、弹窗的 CSS 来复用视觉；应提取公共组件，或在当前组件内建立自己的样式边界。
- 多个页面共享样式时，必须连同结构和行为提取为 `src/components` 下的公共组件，不要只共享一份业务 CSS。
- 业务 CSS 不要集中导入到 `src/styles/app.css`；保持组件级导入，以保留路由和组件代码拆分能力。

### Ant Design 覆写

- 优先通过 `ConfigProvider` 的全局 Token 或 Component Token 调整 Ant Design，不要直接覆盖 `.ant-*` 内部类。
- 必须覆写 Ant Design 内部结构时，先给组件设置专属 `rootClassName`、`popupClassName` 或 `classNames`，所有选择器都必须限制在该根类下。
- CSS Module 中覆盖 Ant Design 使用 `.root :global(.ant-*)`；禁止新增裸 `.ant-modal`、`.ant-input`、`.ant-select` 等全局业务规则。
- Modal、Select、Dropdown、Popover、Image Preview 等 Portal 内容无法依赖页面祖先选择器，必须通过组件提供的 popup/root class API 建立明确作用域。
- 除浏览器兼容、第三方库内联样式或确认无法通过作用域和 Token 解决的情况外，不新增 `!important`。

### 文件规模与组织

- 样式文件按视觉单元拆分，页面壳、列表、卡片、详情、工具栏、时间轴、编辑工作区等明显独立区域应分别维护。
- 新增或重构后的单个 CSS 文件超过 600 行时应继续评估拆分；超过 1000 行时必须拆分，不能继续追加规则。
- 拆分存量 CSS 时先保持选择器和加载顺序不变，再逐步迁移作用域、Token 和 CSS Module，避免一次同时改变结构、优先级和视觉。
- 动画名称、CSS 自定义属性和存量全局类必须带业务前缀，避免跨页面重名。
- 媒体查询尽量靠近对应组件规则；同一断点的重复规则较多时再在组件文件内集中，不要提升为全局业务样式。

## 测试与验证

- 除非明确要求，不新增测试代码。
- 如果要求为 React 功能补测试，只写 Playwright 测试，放在 `e2e`。
- Playwright 测试按模块拆分为不同的 `*.spec.ts` 文件，使用文件作为分组边界；测试文件内不要使用 `test.describe` 分组。
- 不要在测试代码中设置或覆盖超时时间，包括但不限于 `test.setTimeout()`、`testInfo.setTimeout()` 以及为断言、轮询、页面操作或等待方法传入 `timeout`；所有测试统一遵循 `playwright.config.ts` 中配置的全局超时时间。
- Playwright 测试默认走真实前后端访问，不要使用 mock 数据、`route.fulfill` 伪造接口响应或前端假数据绕过真实接口行为；确需为测试场景补充请求参数时，可以用 `page.route` 修改请求后 `route.continue` 继续访问真实后端，例如验证码发送传 `send:false`。
- Playwright E2E 测试禁止通过 `page.waitForResponse()`、`isXxxResponse` 等方式等待或断言具体后端接口；业务结果必须通过页面可见内容、组件状态或页面跳转验证。`APIRequestContext` 只用于测试数据准备和清理，不作为页面功能成功的断言依据。
- Playwright 测试不要使用 CSS 选择器，直接使用中文名称定位；如果组件没有中文名称，可以使用 `aria-label`。
- Playwright 用例优先复用 `e2e/helpers/auth.ts` 的登录辅助和 `e2e/vars.env` 凭据。
- 本地运行 e2e 时需要设置 `E2E_TEST_BASE_URL`，或通过 `ci-test.sh` 传入目标地址。
- 修改 TypeScript/React 代码后，不要运行 `pnpm lint` 和 `pnpm build` 等命令做验证。代码修改完成就算开发完成了，不要运行命令进行验证。
