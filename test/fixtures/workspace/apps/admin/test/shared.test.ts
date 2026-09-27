import { expect, test } from "bun:test";
import { greeting } from "@fixture/shared";

test("shared greeting", () => {
  expect(greeting("admin")).toBe("Hello, admin");
});
