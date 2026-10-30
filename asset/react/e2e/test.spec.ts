import { test, expect } from "./fixtures";

test("访问首页", async ({ page }) => {
  await page.goto("/");
  await page.waitForLoadState("networkidle");
  await expect(page).toHaveURL("/");
});
