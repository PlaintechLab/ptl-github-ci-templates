import { greeting } from "@fixture/shared";

export default function Home() {
  return <h1>{greeting("web")}</h1>;
}
