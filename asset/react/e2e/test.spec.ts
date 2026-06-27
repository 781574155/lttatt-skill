import { test, expect } from "@playwright/test";

test.describe("测试", () => {
  test("访问首页", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("networkidle");
    await expect(page).toHaveURL("/");
  });
});
