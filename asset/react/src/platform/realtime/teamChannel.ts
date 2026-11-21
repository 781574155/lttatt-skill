import { createContext, useContext, useEffect } from "react";

export const TeamChannelContext = createContext<((teamId: string | undefined) => void) | null>(null);

export function useTeamChannel(teamId: string) {
  const setTeamId = useContext(TeamChannelContext);
  if (!setTeamId) throw new Error("请在实时通知上下文中订阅团队频道");

  useEffect(() => {
    setTeamId(teamId);
    return () => setTeamId(undefined);
  }, [setTeamId, teamId]);
}
