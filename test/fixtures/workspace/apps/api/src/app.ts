import { greeting } from "@fixture/shared";
import { Elysia } from "elysia";

export const app = new Elysia()
  .get("/", () => ({ message: greeting("api") }))
  .get("/health", () => ({ status: "ok" }));
