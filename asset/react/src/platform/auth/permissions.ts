export const NOTIFY_USER_PERMISSION = "notify-backend.user";
export const OIDC_PROTOCOL_SCOPES = new Set(["openid", "profile", "email", "phone", "address"]);

type AccountPermissions = { login?: boolean; permissions?: readonly string[] };

export function hasAccountPermission(account: AccountPermissions | undefined, permission: string) {
  return account?.login === true && account.permissions?.includes(permission) === true;
}

export function parsePermissionScopes(scope?: string) {
  return (scope ?? "").split(/\s+/).filter(Boolean);
}

export function hasTokenPermission(scope: string | undefined, permission: string) {
  return scope?.split(/\s+/).includes(permission) === true;
}

export function getMissingTokenPermissions(scope: string | undefined, required: readonly string[]) {
  const granted = new Set(parsePermissionScopes(scope));
  return required.filter((permission) => !granted.has(permission));
}

export function getAuthorizationPermissions(
  scope: string | undefined,
  allowedPermissions: readonly string[] | undefined,
  requestedPermissions: readonly string[],
) {
  const allowed = new Set(allowedPermissions);
  return [...new Set([...parsePermissionScopes(scope), ...requestedPermissions])].filter(
    (permission) => OIDC_PROTOCOL_SCOPES.has(permission) || allowed.has(permission),
  );
}
