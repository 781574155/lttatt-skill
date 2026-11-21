import type { QueryClient, QueryKey } from "@tanstack/react-query";
import { Centrifuge, UnauthorizedError } from "centrifuge";
import type { Subscription } from "centrifuge";
import { z } from "zod";
import { SESSION_EXPIRED_EVENT, TOKEN_EXPIRED_EVENT } from "../auth/session";
import { createRefreshUiScheduler } from "./refreshUiQueries";

const refreshUiSchema = z.object({
  type: z.literal("RefreshUI"),
  data: z.object({ query_key: z.array(z.unknown()).min(1) }),
});

type WebsocketRequest = { signal: AbortSignal; noMessageSuccess: true };
export type WebsocketResource = {
  getReadQueryKey: () => QueryKey;
  getReadTokenQueryKey: () => QueryKey;
  read: (options: WebsocketRequest) => Promise<{ data?: { data?: { url?: string } } }>;
  readToken: (options: WebsocketRequest) => Promise<{ data?: { data?: { token?: string } } }>;
};

type RealtimeOptions = {
  initialTeamId?: string;
  mapTeamQueryKey?: (queryKey: QueryKey, teamId: string) => QueryKey;
  onRefresh?: (queryKey: QueryKey) => void;
};

function resolveCentrifugoEndpoint(url: string) {
  const endpoint = new URL(url.trim(), window.location.origin);
  if (endpoint.protocol === "https:") endpoint.protocol = "wss:";
  if (endpoint.protocol === "http:") endpoint.protocol = "ws:";
  if (endpoint.protocol !== "ws:" && endpoint.protocol !== "wss:") {
    throw new Error("实时通知连接地址无效");
  }
  const pathname = endpoint.pathname.replace(/\/+$/, "");
  endpoint.pathname = pathname.endsWith("/connection/websocket") ? pathname : pathname + "/connection/websocket";
  return endpoint.toString();
}

function stopOnSessionExpiry(stop: () => void) {
  window.addEventListener(SESSION_EXPIRED_EVENT, stop);
  window.addEventListener(TOKEN_EXPIRED_EVENT, stop);
  return () => {
    window.removeEventListener(SESSION_EXPIRED_EVENT, stop);
    window.removeEventListener(TOKEN_EXPIRED_EVENT, stop);
  };
}

export function startCentrifugoSync(
  queryClient: QueryClient,
  resource: WebsocketResource,
  userId: string,
  { initialTeamId, mapTeamQueryKey, onRefresh }: RealtimeOptions = {},
) {
  const controller = new AbortController();
  const scheduler = createRefreshUiScheduler(queryClient);
  const configQueryKey = [...resource.getReadQueryKey(), { user_id: userId }] as const;
  const tokenQueryKey = [...resource.getReadTokenQueryKey(), { user_id: userId }] as const;
  let client: Centrifuge | null = null;
  let userSubscription: Subscription | null = null;
  let teamSubscription: Subscription | null = null;
  let teamId = initialTeamId;

  function subscribe(connection: Centrifuge, channel: "user" | "team", id: string) {
    const subscription = connection.newSubscription("notify:" + channel + ":" + id);
    subscription.on("publication", ({ data }) => {
      if (controller.signal.aborted) return;
      const event = refreshUiSchema.safeParse(data);
      if (!event.success) return;
      const queryKey = event.data.data.query_key;
      scheduler.schedule(channel === "team" && mapTeamQueryKey ? mapTeamQueryKey(queryKey, id) : queryKey);
      onRefresh?.(queryKey);
    });
    subscription.subscribe();
    return subscription;
  }

  function removeSubscription(subscription: Subscription | null) {
    if (!subscription) return;
    subscription.removeAllListeners("publication");
    client?.removeSubscription(subscription);
  }

  function setTeamId(nextTeamId: string | undefined) {
    if (controller.signal.aborted || nextTeamId === teamId) return;
    teamId = nextTeamId;
    removeSubscription(teamSubscription);
    teamSubscription = client && teamId ? subscribe(client, "team", teamId) : null;
  }

  function stop() {
    if (controller.signal.aborted) return;
    controller.abort();
    scheduler.dispose();
    removeSessionListeners();
    void queryClient.cancelQueries({ queryKey: configQueryKey, exact: true });
    void queryClient.cancelQueries({ queryKey: tokenQueryKey, exact: true });
    removeSubscription(teamSubscription);
    removeSubscription(userSubscription);
    client?.disconnect();
    teamSubscription = null;
    userSubscription = null;
    client = null;
  }

  async function getConnectionToken() {
    if (controller.signal.aborted) throw new UnauthorizedError("实时通知连接已停止");
    const response = await queryClient.fetchQuery({
      queryKey: tokenQueryKey,
      queryFn: ({ signal }) =>
        resource.readToken({
          signal: AbortSignal.any([signal, controller.signal]),
          noMessageSuccess: true,
        }),
      staleTime: 0,
    });
    if (controller.signal.aborted) throw new UnauthorizedError("实时通知连接已停止");
    const token = response.data?.data?.token;
    if (!token) throw new UnauthorizedError("未获取到实时通知连接令牌");
    return token;
  }

  async function initialize() {
    try {
      const response = await queryClient.fetchQuery({
        queryKey: configQueryKey,
        queryFn: ({ signal }) =>
          resource.read({
            signal: AbortSignal.any([signal, controller.signal]),
            noMessageSuccess: true,
          }),
        staleTime: 0,
      });
      if (controller.signal.aborted) return;
      const url = response.data?.data?.url;
      if (!url?.trim()) throw new Error("未获取到实时通知连接地址");

      client = new Centrifuge(resolveCentrifugoEndpoint(url), { getToken: getConnectionToken });
      userSubscription = subscribe(client, "user", userId);
      if (teamId) teamSubscription = subscribe(client, "team", teamId);
      client.connect();
    } catch (error) {
      if (controller.signal.aborted) return;
      console.error("实时通知连接初始化失败：", error);
      stop();
    }
  }

  const removeSessionListeners = stopOnSessionExpiry(stop);
  void initialize();
  return { setTeamId, stop };
}
