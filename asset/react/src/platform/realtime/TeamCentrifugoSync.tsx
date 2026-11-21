import { useCallback, useEffect, useRef } from "react";
import type { ReactNode } from "react";
import { useQueryClient } from "@tanstack/react-query";
import type { UserManager } from "oidc-client-ts";
import { startCentrifugoSync } from "./centrifugo";
import type { WebsocketResource } from "./centrifugo";
import { TeamChannelContext } from "./teamChannel";

type TeamCentrifugoSyncProps = {
  children: ReactNode;
  userId: string | undefined;
  resource: WebsocketResource;
  getOidcManager: () => UserManager;
  service: string;
  collection: string;
};

export function TeamCentrifugoSync({
  children,
  userId,
  resource,
  getOidcManager,
  service,
  collection,
}: TeamCentrifugoSyncProps) {
  const queryClient = useQueryClient();
  const connection = useRef<ReturnType<typeof startCentrifugoSync> | null>(null);
  const selectedTeamId = useRef<string | undefined>(undefined);

  const setTeamId = useCallback((teamId: string | undefined) => {
    selectedTeamId.current = teamId;
    connection.current?.setTeamId(teamId);
  }, []);

  useEffect(() => {
    if (!userId) return;
    const sync = startCentrifugoSync(queryClient, resource, userId, {
      initialTeamId: selectedTeamId.current,
      mapTeamQueryKey: (key, teamId) =>
        key.length >= 5 && key[0] === service && key[1] === "teams" && key[2] === teamId && key[3] === collection
          ? key.slice(0, 5)
          : key,
    });
    connection.current = sync;
    const removeUnloadedListener = getOidcManager().events.addUserUnloaded(sync.stop);
    return () => {
      connection.current = null;
      removeUnloadedListener();
      sync.stop();
    };
  }, [collection, getOidcManager, queryClient, resource, service, userId]);

  return <TeamChannelContext value={setTeamId}>{children}</TeamChannelContext>;
}
