import { Elysia } from "elysia";

export const app = new Elysia()
  .get("/", () => ({ name: "fixture-elysia" }))
  .get("/health", () => ({ status: "ok" }));
