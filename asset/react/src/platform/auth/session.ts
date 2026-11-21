export const SESSION_EXPIRED_EVENT = "app-session-expired";
export const TOKEN_EXPIRED_EVENT = "app-token-expired";

export function expireSession() {
  window.dispatchEvent(new Event(SESSION_EXPIRED_EVENT));
}
