import { isPlainObject } from "lodash";

export type FieldPrefixMapping = { prefix: string; replacement: string };

export function replaceFieldPrefixes<T>(
  data: T,
  rules: readonly FieldPrefixMapping[] = [],
  direction: "request" | "response" = "response",
): T {
  const mappings = rules
    .filter(({ prefix, replacement }) => prefix && replacement)
    .map((mapping) =>
      direction === "response" ? mapping : { prefix: mapping.replacement, replacement: mapping.prefix },
    )
    .sort((first, second) => second.prefix.length - first.prefix.length);
  if (mappings.length === 0) return data;

  function replaceString(value: string): string {
    const mapping = mappings.find(({ prefix }) => value.startsWith(prefix));
    return mapping ? mapping.replacement + value.slice(mapping.prefix.length) : value;
  }

  function replace(value: unknown): unknown {
    if (typeof value === "string") return replaceString(value);
    if (value instanceof URLSearchParams) {
      const params = new URLSearchParams();
      value.forEach((field, key) => params.append(key, replaceString(field)));
      return params;
    }
    if (value instanceof FormData) {
      const form = new FormData();
      value.forEach((field, key) => form.append(key, typeof field === "string" ? replaceString(field) : field));
      return form;
    }
    if (Array.isArray(value)) return value.map(replace);
    if (value !== null && typeof value === "object" && isPlainObject(value)) {
      return Object.fromEntries(Object.entries(value).map(([key, field]) => [key, replace(field)]));
    }
    return value;
  }

  return replace(data) as T;
}
