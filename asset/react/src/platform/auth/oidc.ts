import { UserManager, WebStorageStateStore } from "oidc-client-ts";
import type { User } from "oidc-client-ts";
import { z } from "zod";
import { getMissingTokenPermissions } from "./permissions";
import { TOKEN_EXPIRED_EVENT } from "./session";

const AUTHORIZATION_ATTEMPT_KEY = "app-authorization-attempt";
const AUTHORIZATION_RETRY_WINDOW_MS = 60_000;
const callbackStateSchema = z.object({ returnTo: z.string(), requiredPermissions: z.array(z.string()).optional() });

type OidcConfig = { authority: string; client_id: string; scope: string };

function safeReturnTo(value: string) {
  const { origin } = window.location;
  if (!URL.canParse(value, origin)) return "/";
  const url = new URL(value, origin);
  if (url.origin !== origin || url.pathname === "/auth/callback" || url.pathname.startsWith("//")) return "/";
  return url.pathname + url.search + url.hash;
}

export function readAuthorizationState(value: unknown) {
  const state = callbackStateSchema.safeParse(value);
  return {
    returnTo: state.success ? safeReturnTo(state.data.returnTo) : "/",
    requiredPermissions: state.success ? state.data.requiredPermissions : undefined,
  };
}

export function isAuthorizedUser(user: User | null): user is User {
  return Boolean(user?.access_token && user.token_type.toLowerCase() === "bearer" && !user.expired && user.profile.sub);
}

export function createOidcClient(getConfig: () => OidcConfig | undefined) {
  let manager: UserManager | undefined;
  let authorizationPromise: Promise<void> | undefined;
  let callbackRequest: { url: string; promise: Promise<string> } | undefined;
  let invalidationPromise: Promise<void> | undefined;

  function getOidcManager() {
    if (manager) return manager;
    const config = getConfig();
    if (!config?.authority.trim() || !config.client_id.trim() || !config.scope.trim()) {
      throw new Error("登录服务暂未配置，请联系管理员。");
    }
    const authority = new URL(config.authority).origin;
    const backendUrl = new URL("/backend-api/", authority);
    manager = new UserManager({
      authority,
      client_id: config.client_id,
      redirect_uri: new URL("/auth/callback", window.location.origin).href,
      response_type: "code",
      response_mode: "query",
      scope: config.scope,
      disablePKCE: false,
      automaticSilentRenew: false,
      monitorSession: false,
      loadUserInfo: false,
      fetchRequestCredentials: "same-origin",
      requestTimeoutInSeconds: 30,
      metadataUrl: new URL(".well-known/openid-configuration", backendUrl).href,
      stateStore: new WebStorageStateStore({ store: window.sessionStorage, prefix: "app-oidc-state:" }),
      userStore: new WebStorageStateStore({ store: window.localStorage, prefix: "app-oidc-user:" }),
    });
    return manager;
  }

  async function clearAuthorization() {
    await getOidcManager().removeUser();
  }

  async function resetAuthorization() {
    sessionStorage.removeItem(AUTHORIZATION_ATTEMPT_KEY);
    authorizationPromise = undefined;
    await clearAuthorization();
  }

  function startAuthorization(returnTo: string, force = false, permissions?: readonly string[]): Promise<void> {
    if (authorizationPromise) return authorizationPromise;
    let redirected = false;
    const attempt: Promise<void> = (async () => {
      const oidcManager = getOidcManager();
      const lastAttempt = Number(sessionStorage.getItem(AUTHORIZATION_ATTEMPT_KEY));
      if (!force && lastAttempt > 0 && Date.now() - lastAttempt < AUTHORIZATION_RETRY_WINDOW_MS) {
        throw new Error("自动授权未能恢复，请重新授权");
      }
      sessionStorage.setItem(AUTHORIZATION_ATTEMPT_KEY, String(Date.now()));
      await clearAuthorization();
      await oidcManager.clearStaleState();
      await oidcManager.signinRedirect({
        ...(permissions ? { scope: permissions.join(" ") } : {}),
        state: { returnTo: safeReturnTo(returnTo), requiredPermissions: permissions },
      });
      redirected = true;
    })().finally(() => {
      if (!redirected && authorizationPromise === attempt) authorizationPromise = undefined;
    });
    authorizationPromise = attempt;
    return attempt;
  }

  async function completeSignin(url: string) {
    const user = await getOidcManager().signinRedirectCallback(url);
    if (!isAuthorizedUser(user)) {
      await clearAuthorization();
      throw new Error("未获取到有效的访问令牌");
    }
    return user;
  }

  function completeAuthorization(url: string): Promise<string> {
    // React StrictMode 会重复执行 Effect，授权码只能兑换一次。
    if (callbackRequest?.url === url) return callbackRequest.promise;
    const promise = completeSignin(url).then(async (user) => {
      const { returnTo, requiredPermissions } = readAuthorizationState(user.state);
      if (getMissingTokenPermissions(user.scope, requiredPermissions ?? []).length > 0) {
        await clearAuthorization();
        throw new Error("未获取到请求的访问权限，请重新授权");
      }
      return returnTo;
    });
    callbackRequest = { url, promise };
    return promise;
  }

  async function getAccessToken() {
    const user = await getOidcManager().getUser();
    if (isAuthorizedUser(user)) return user.access_token;
    await invalidateAccessToken();
    return null;
  }

  function invalidateAccessToken(expectedToken?: string | null): Promise<void> {
    invalidationPromise ??= (async () => {
      const user = await getOidcManager().getUser();
      if (expectedToken !== undefined && isAuthorizedUser(user) && user.access_token !== expectedToken) return;
      await clearAuthorization();
      window.dispatchEvent(new Event(TOKEN_EXPIRED_EVENT));
    })().finally(() => {
      invalidationPromise = undefined;
    });
    return invalidationPromise;
  }

  return {
    clearAuthorization,
    completeAuthorization,
    completeSignin,
    getAccessToken,
    getOidcManager,
    invalidateAccessToken,
    resetAuthorization,
    startAuthorization,
  };
}
