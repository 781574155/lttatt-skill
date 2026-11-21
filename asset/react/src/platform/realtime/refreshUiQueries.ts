import { hashKey } from "@tanstack/react-query";
import type { QueryClient, QueryKey } from "@tanstack/react-query";

const REFRESH_MERGE_DELAY = 1000;

type RefreshTask = {
  queryKey: QueryKey;
  timer: ReturnType<typeof setTimeout> | null;
  running: boolean;
  pending: boolean;
};

async function invalidateRefreshUiQueries(queryClient: QueryClient, queryKey: QueryKey, isActive: () => boolean) {
  const initialRequests = queryClient
    .getQueryCache()
    .findAll({ queryKey })
    .filter((query) => query.state.data === undefined && query.state.fetchStatus === "fetching")
    .map((query) => ({ query, promise: query.promise }));

  await queryClient.invalidateQueries({ queryKey });
  await Promise.all(
    initialRequests.map(async ({ query, promise }) => {
      // 首次查询会复用在途请求，旧快照返回后需要补刷新。
      await Promise.allSettled([promise]);
      if (!isActive()) return;
      const cachedQuery = queryClient.getQueryCache().find({ queryKey: query.queryKey, exact: true });
      if (cachedQuery !== query || !query.isActive()) return;
      await queryClient.invalidateQueries({ queryKey: query.queryKey, exact: true });
    }),
  );
}

export function createRefreshUiScheduler(queryClient: QueryClient) {
  const tasks = new Map<string, RefreshTask>();
  let disposed = false;
  const isActive = () => !disposed;

  function flushRefresh(key: string, task: RefreshTask) {
    if (disposed || task.timer !== null || task.running) return;
    if (!task.pending) {
      tasks.delete(key);
      return;
    }
    void runRefresh(key, task);
  }

  async function runRefresh(key: string, task: RefreshTask) {
    if (disposed) return;
    task.pending = false;
    task.running = true;
    task.timer = setTimeout(() => {
      task.timer = null;
      flushRefresh(key, task);
    }, REFRESH_MERGE_DELAY);
    try {
      await invalidateRefreshUiQueries(queryClient, task.queryKey, isActive);
    } catch (error) {
      if (!disposed) console.error("刷新缓存失败：", error);
    } finally {
      task.running = false;
      flushRefresh(key, task);
    }
  }

  return {
    schedule(queryKey: QueryKey) {
      if (disposed) return;
      const key = hashKey(queryKey);
      const existing = tasks.get(key);
      if (existing) {
        existing.pending = true;
        return;
      }
      const task: RefreshTask = { queryKey, timer: null, running: false, pending: true };
      tasks.set(key, task);
      flushRefresh(key, task);
    },
    dispose() {
      disposed = true;
      tasks.forEach((task) => {
        if (task.timer !== null) clearTimeout(task.timer);
      });
      tasks.clear();
    },
  };
}
