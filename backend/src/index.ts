import { Hono } from "hono";
import { cors } from "hono/cors";
import { eq, and, desc } from "drizzle-orm";
import { drizzle } from "drizzle-orm/d1";
import * as schema from "./schema";
import {
  bothSidesPresent,
  canUserBet,
  computePayouts,
  resolverId,
  type Side,
} from "./settle";

type Vars = { userId: string };

const app = new Hono<{ Bindings: Env; Variables: Vars }>();

app.use("*", cors());

app.get("/health", (c) => c.json({ ok: true, service: "betchya-api" }));

function nowIso() {
  return new Date().toISOString();
}

function newId() {
  return crypto.randomUUID();
}

function startingBones(env: Env) {
  return Number(env.STARTING_BONES ?? 1000);
}

function minBet(env: Env) {
  return Number(env.MIN_BET ?? 10);
}

function requireUser(c: { req: { header: (n: string) => string | undefined } }) {
  const userId = c.req.header("X-User-Id");
  if (!userId) throw new Error("missing_user");
  return userId;
}

app.onError((err, c) => {
  const message = err.message || "error";
  const status =
    message === "missing_user" || message === "not_found"
      ? 404
      : message.startsWith("forbidden") || message.startsWith("invalid")
        ? 400
        : 400;
  return c.json({ error: message }, status);
});

app.post("/users/bootstrap", async (c) => {
  const body = await c.req.json<{ id?: string }>();
  const id = body.id ?? newId();
  const db = drizzle(c.env.DB, { schema });
  const existing = await db.select().from(schema.users).where(eq(schema.users.id, id)).get();
  if (!existing) {
    await db.insert(schema.users).values({ id, createdAt: nowIso() });
  }
  return c.json({ id });
});

app.post("/groups", async (c) => {
  const userId = requireUser(c);
  const body = await c.req.json<{ id?: string; nickname: string }>();
  if (!body.nickname?.trim()) throw new Error("invalid_nickname");

  const db = drizzle(c.env.DB, { schema });
  await ensureUser(db, userId);

  const id = body.id ?? newId();
  const createdAt = nowIso();
  await db.insert(schema.groups).values({ id, createdBy: userId, createdAt });
  await db.insert(schema.groupMembers).values({
    groupId: id,
    userId,
    nickname: body.nickname.trim(),
    balance: startingBones(c.env),
    lifetimeProfit: 0,
    createdAt,
  });
  await db.insert(schema.ledgerEntries).values({
    id: newId(),
    groupId: id,
    userId,
    marketId: null,
    kind: "starting_grant",
    amount: startingBones(c.env),
    createdAt,
  });

  return c.json({ id }, 201);
});

app.post("/groups/:groupId/join", async (c) => {
  const userId = requireUser(c);
  const groupId = c.req.param("groupId");
  const body = await c.req.json<{ nickname: string }>();
  if (!body.nickname?.trim()) throw new Error("invalid_nickname");

  const db = drizzle(c.env.DB, { schema });
  await ensureUser(db, userId);

  const group = await db.select().from(schema.groups).where(eq(schema.groups.id, groupId)).get();
  if (!group) throw new Error("not_found");

  const member = await db
    .select()
    .from(schema.groupMembers)
    .where(and(eq(schema.groupMembers.groupId, groupId), eq(schema.groupMembers.userId, userId)))
    .get();

  if (member) {
    await db
      .update(schema.groupMembers)
      .set({ nickname: body.nickname.trim() })
      .where(and(eq(schema.groupMembers.groupId, groupId), eq(schema.groupMembers.userId, userId)));
    return c.json({
      groupId,
      userId,
      nickname: body.nickname.trim(),
      balance: member.balance,
      lifetimeProfit: member.lifetimeProfit,
      joined: false,
    });
  }

  const createdAt = nowIso();
  const balance = startingBones(c.env);
  await db.insert(schema.groupMembers).values({
    groupId,
    userId,
    nickname: body.nickname.trim(),
    balance,
    lifetimeProfit: 0,
    createdAt,
  });
  await db.insert(schema.ledgerEntries).values({
    id: newId(),
    groupId,
    userId,
    marketId: null,
    kind: "starting_grant",
    amount: balance,
    createdAt,
  });

  return c.json({ groupId, userId, nickname: body.nickname.trim(), balance, lifetimeProfit: 0, joined: true }, 201);
});

app.get("/groups/:groupId/members", async (c) => {
  const groupId = c.req.param("groupId");
  const db = drizzle(c.env.DB, { schema });
  const members = await db
    .select()
    .from(schema.groupMembers)
    .where(eq(schema.groupMembers.groupId, groupId));
  return c.json({
    members: members.map((m) => ({
      userId: m.userId,
      nickname: m.nickname,
      balance: m.balance,
      lifetimeProfit: m.lifetimeProfit,
    })),
  });
});

app.get("/groups/:groupId/leaderboard", async (c) => {
  const groupId = c.req.param("groupId");
  const db = drizzle(c.env.DB, { schema });
  const members = await db
    .select()
    .from(schema.groupMembers)
    .where(eq(schema.groupMembers.groupId, groupId))
    .orderBy(desc(schema.groupMembers.lifetimeProfit));
  return c.json({
    entries: members.map((m) => ({
      userId: m.userId,
      nickname: m.nickname,
      lifetimeProfit: m.lifetimeProfit,
      balance: m.balance,
    })),
  });
});

app.post("/groups/:groupId/markets", async (c) => {
  const userId = requireUser(c);
  const groupId = c.req.param("groupId");
  const body = await c.req.json<{
    question: string;
    deadline: string;
    subjectId?: string | null;
    showAmounts?: boolean;
  }>();

  if (!body.question?.trim()) throw new Error("invalid_question");
  if (!body.deadline) throw new Error("invalid_deadline");

  const db = drizzle(c.env.DB, { schema });
  const member = await requireMember(db, groupId, userId);

  if (body.subjectId) {
    const subject = await db
      .select()
      .from(schema.groupMembers)
      .where(
        and(eq(schema.groupMembers.groupId, groupId), eq(schema.groupMembers.userId, body.subjectId))
      )
      .get();
    if (!subject) throw new Error("invalid_subject");
  }

  const id = newId();
  const createdAt = nowIso();
  await db.insert(schema.markets).values({
    id,
    groupId,
    question: body.question.trim(),
    deadline: body.deadline,
    creatorId: userId,
    subjectId: body.subjectId ?? null,
    showAmounts: body.showAmounts ? 1 : 0,
    status: "open",
    outcome: null,
    createdAt,
  });

  return c.json(await marketPayload(db, id, member.userId), 201);
});

app.get("/groups/:groupId/markets", async (c) => {
  const groupId = c.req.param("groupId");
  const db = drizzle(c.env.DB, { schema });
  const rows = await db.select().from(schema.markets).where(eq(schema.markets.groupId, groupId));
  const markets = [];
  for (const row of rows) {
    markets.push(await marketPayload(db, row.id));
  }
  return c.json({ markets });
});

app.get("/markets/:marketId", async (c) => {
  const db = drizzle(c.env.DB, { schema });
  return c.json(await marketPayload(db, c.req.param("marketId")));
});

app.post("/markets/:marketId/bets", async (c) => {
  const userId = requireUser(c);
  const marketId = c.req.param("marketId");
  const body = await c.req.json<{ side: Side; stake: number }>();
  const side = body.side;
  const stake = Number(body.stake);

  if (side !== "yes" && side !== "no") throw new Error("invalid_side");
  if (!Number.isInteger(stake) || stake < minBet(c.env)) throw new Error("invalid_stake");

  const db = drizzle(c.env.DB, { schema });
  const market = await db.select().from(schema.markets).where(eq(schema.markets.id, marketId)).get();
  if (!market) throw new Error("not_found");
  if (market.status !== "open") throw new Error("invalid_market_closed");
  if (new Date(market.deadline).getTime() <= Date.now()) throw new Error("invalid_past_deadline");

  if (!canUserBet({ userId, creatorId: market.creatorId, subjectId: market.subjectId })) {
    throw new Error("forbidden_resolver_cannot_bet");
  }

  const existing = await db
    .select()
    .from(schema.bets)
    .where(and(eq(schema.bets.marketId, marketId), eq(schema.bets.userId, userId)))
    .get();
  if (existing) throw new Error("invalid_bet_locked");

  const member = await requireMember(db, market.groupId, userId);
  if (member.balance < stake) throw new Error("invalid_insufficient_bones");

  const createdAt = nowIso();
  await c.env.DB.batch([
    c.env.DB.prepare(
      "UPDATE group_members SET balance = balance - ? WHERE group_id = ? AND user_id = ?"
    ).bind(stake, market.groupId, userId),
    c.env.DB.prepare(
      "INSERT INTO bets (market_id, user_id, side, stake, created_at) VALUES (?, ?, ?, ?, ?)"
    ).bind(marketId, userId, side, stake, createdAt),
    c.env.DB.prepare(
      "INSERT INTO ledger_entries (id, group_id, user_id, market_id, kind, amount, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
    ).bind(newId(), market.groupId, userId, marketId, "bet_lock", -stake, createdAt),
  ]);

  return c.json(await marketPayload(db, marketId, userId));
});

app.post("/markets/:marketId/resolve", async (c) => {
  const userId = requireUser(c);
  const marketId = c.req.param("marketId");
  const body = await c.req.json<{ outcome: Side }>();
  const outcome = body.outcome;
  if (outcome !== "yes" && outcome !== "no") throw new Error("invalid_outcome");

  const db = drizzle(c.env.DB, { schema });
  const market = await db.select().from(schema.markets).where(eq(schema.markets.id, marketId)).get();
  if (!market) throw new Error("not_found");
  if (market.status !== "open" && market.status !== "locked") throw new Error("invalid_market_status");

  const allowed = resolverId(market.creatorId, market.subjectId);
  if (userId !== allowed) throw new Error("forbidden_not_resolver");

  if (new Date(market.deadline).getTime() > Date.now()) {
    throw new Error("invalid_before_deadline");
  }

  const marketBets = await db.select().from(schema.bets).where(eq(schema.bets.marketId, marketId));
  const betInputs = marketBets.map((b) => ({
    userId: b.userId,
    side: b.side as Side,
    stake: b.stake,
  }));

  if (!bothSidesPresent(betInputs)) throw new Error("invalid_one_sided");

  const { payouts } = computePayouts(betInputs, outcome);
  const createdAt = nowIso();
  const statements = [
    c.env.DB.prepare("UPDATE markets SET status = ?, outcome = ? WHERE id = ?").bind(
      "resolved",
      outcome,
      marketId
    ),
  ];

  for (const [winnerId, payout] of Object.entries(payouts)) {
    const stake = betInputs.find((b) => b.userId === winnerId)?.stake ?? 0;
    const profit = payout - stake;
    statements.push(
      c.env.DB.prepare(
        "UPDATE group_members SET balance = balance + ?, lifetime_profit = lifetime_profit + ? WHERE group_id = ? AND user_id = ?"
      ).bind(payout, profit, market.groupId, winnerId)
    );
    statements.push(
      c.env.DB.prepare(
        "INSERT INTO ledger_entries (id, group_id, user_id, market_id, kind, amount, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
      ).bind(newId(), market.groupId, winnerId, marketId, "payout", payout, createdAt)
    );
  }

  // Losing stakes already deducted at bet time; record zero-profit closure optionally skipped.
  await c.env.DB.batch(statements);

  return c.json({
    market: await marketPayload(db, marketId, userId),
    payouts,
  });
});

async function ensureUser(
  db: ReturnType<typeof drizzle<typeof schema>>,
  userId: string
) {
  const existing = await db.select().from(schema.users).where(eq(schema.users.id, userId)).get();
  if (!existing) {
    await db.insert(schema.users).values({ id: userId, createdAt: nowIso() });
  }
}

async function requireMember(
  db: ReturnType<typeof drizzle<typeof schema>>,
  groupId: string,
  userId: string
) {
  const member = await db
    .select()
    .from(schema.groupMembers)
    .where(and(eq(schema.groupMembers.groupId, groupId), eq(schema.groupMembers.userId, userId)))
    .get();
  if (!member) throw new Error("forbidden_not_member");
  return member;
}

async function marketPayload(
  db: ReturnType<typeof drizzle<typeof schema>>,
  marketId: string,
  _viewerId?: string
) {
  const market = await db.select().from(schema.markets).where(eq(schema.markets.id, marketId)).get();
  if (!market) throw new Error("not_found");

  const marketBets = await db.select().from(schema.bets).where(eq(schema.bets.marketId, marketId));
  const members = await db
    .select()
    .from(schema.groupMembers)
    .where(eq(schema.groupMembers.groupId, market.groupId));
  const nick = Object.fromEntries(members.map((m) => [m.userId, m.nickname]));

  const yesTotal = marketBets.filter((b) => b.side === "yes").reduce((s, b) => s + b.stake, 0);
  const noTotal = marketBets.filter((b) => b.side === "no").reduce((s, b) => s + b.stake, 0);

  return {
    id: market.id,
    groupId: market.groupId,
    question: market.question,
    deadline: market.deadline,
    creatorId: market.creatorId,
    subjectId: market.subjectId,
    showAmounts: market.showAmounts === 1,
    status: market.status,
    outcome: market.outcome,
    yesTotal,
    noTotal,
    pot: yesTotal + noTotal,
    bets: marketBets.map((b) => ({
      userId: b.userId,
      nickname: nick[b.userId] ?? null,
      side: b.side,
      stake: market.showAmounts === 1 ? b.stake : null,
    })),
  };
}

export default app;
