import { describe, expect, test, beforeAll, afterAll } from "bun:test";
import { Miniflare } from "miniflare";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { $ } from "bun";

const migration = readFileSync(join(import.meta.dir, "../migrations/0001_init.sql"), "utf8");

describe("api smoke (miniflare + D1)", () => {
  let mf: Miniflare;

  beforeAll(async () => {
    await $`bun build ./src/index.ts --outfile=./dist/index.js --format=esm --target=browser`.cwd(
      join(import.meta.dir, "..")
    );

    mf = new Miniflare({
      modules: true,
      scriptPath: join(import.meta.dir, "../dist/index.js"),
      compatibilityDate: "2025-09-01",
      d1Databases: ["DB"],
      bindings: {
        STARTING_BONES: "1000",
        MIN_BET: "10",
        RESOLVE_GRACE_HOURS: "48",
      },
    });

    const db = await mf.getD1Database("DB");
    for (const stmt of migration
      .split(";")
      .map((s) => s.trim())
      .filter(Boolean)) {
      await db.prepare(stmt).run();
    }
  });

  afterAll(async () => {
    await mf.dispose();
  });

  test("bootstrap → join → market → bets → resolve", async () => {
    const health = await mf.dispatchFetch("http://localhost/health");
    expect(health.status).toBe(200);

    for (const id of ["creator", "alice", "bob"]) {
      const res = await mf.dispatchFetch("http://localhost/users/bootstrap", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ id }),
      });
      expect(res.status).toBe(200);
    }

    const groupRes = await mf.dispatchFetch("http://localhost/groups", {
      method: "POST",
      headers: { "content-type": "application/json", "X-User-Id": "creator" },
      body: JSON.stringify({ id: "group-1", nickname: "Host" }),
    });
    expect(groupRes.status).toBe(201);
    const group = (await groupRes.json()) as { id: string };

    for (const [id, nickname] of [
      ["alice", "Alice"],
      ["bob", "Bob"],
    ] as const) {
      const join = await mf.dispatchFetch(`http://localhost/groups/${group.id}/join`, {
        method: "POST",
        headers: { "content-type": "application/json", "X-User-Id": id },
        body: JSON.stringify({ nickname }),
      });
      expect(join.ok).toBe(true);
    }

    const deadline = new Date(Date.now() + 50).toISOString();
    const marketRes = await mf.dispatchFetch(`http://localhost/groups/${group.id}/markets`, {
      method: "POST",
      headers: { "content-type": "application/json", "X-User-Id": "creator" },
      body: JSON.stringify({
        question: "Will it rain?",
        deadline,
        showAmounts: true,
      }),
    });
    expect(marketRes.status).toBe(201);
    const market = (await marketRes.json()) as { id: string };

    const forbidden = await mf.dispatchFetch(`http://localhost/markets/${market.id}/bets`, {
      method: "POST",
      headers: { "content-type": "application/json", "X-User-Id": "creator" },
      body: JSON.stringify({ side: "yes", stake: 10 }),
    });
    expect(forbidden.status).toBe(400);

    const aliceBet = await mf.dispatchFetch(`http://localhost/markets/${market.id}/bets`, {
      method: "POST",
      headers: { "content-type": "application/json", "X-User-Id": "alice" },
      body: JSON.stringify({ side: "yes", stake: 100 }),
    });
    expect(aliceBet.ok).toBe(true);

    const bobBet = await mf.dispatchFetch(`http://localhost/markets/${market.id}/bets`, {
      method: "POST",
      headers: { "content-type": "application/json", "X-User-Id": "bob" },
      body: JSON.stringify({ side: "no", stake: 50 }),
    });
    expect(bobBet.ok).toBe(true);

    await Bun.sleep(80);

    const resolve = await mf.dispatchFetch(`http://localhost/markets/${market.id}/resolve`, {
      method: "POST",
      headers: { "content-type": "application/json", "X-User-Id": "creator" },
      body: JSON.stringify({ outcome: "yes" }),
    });
    expect(resolve.ok).toBe(true);
    const resolved = (await resolve.json()) as { payouts: Record<string, number> };
    expect(resolved.payouts.alice).toBe(150);

    const members = await mf.dispatchFetch(`http://localhost/groups/${group.id}/members`);
    const body = (await members.json()) as {
      members: Array<{ userId: string; balance: number; lifetimeProfit: number }>;
    };
    const alice = body.members.find((m) => m.userId === "alice")!;
    const bob = body.members.find((m) => m.userId === "bob")!;
    expect(alice.balance).toBe(1000 - 100 + 150);
    expect(alice.lifetimeProfit).toBe(50);
    expect(bob.balance).toBe(1000 - 50);
    expect(bob.lifetimeProfit).toBe(0);
  });
});
