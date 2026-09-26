import { expect, test } from "bun:test";
import { greeting } from "./greeting";

test("greeting", () => {
  expect(greeting("PlaintechLab")).toBe("Hello, PlaintechLab");
});
