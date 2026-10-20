import { sqliteTable, text, integer, primaryKey } from "drizzle-orm/sqlite-core";

export const users = sqliteTable("users", {
  id: text("id").primaryKey(),
  createdAt: text("created_at").notNull(),
});

export const groups = sqliteTable("groups", {
  id: text("id").primaryKey(),
  createdBy: text("created_by").notNull(),
  createdAt: text("created_at").notNull(),
});

export const groupMembers = sqliteTable(
  "group_members",
  {
    groupId: text("group_id").notNull(),
    userId: text("user_id").notNull(),
    nickname: text("nickname").notNull(),
    balance: integer("balance").notNull(),
    lifetimeProfit: integer("lifetime_profit").notNull().default(0),
    createdAt: text("created_at").notNull(),
  },
  (t) => [primaryKey({ columns: [t.groupId, t.userId] })]
);

export const markets = sqliteTable("markets", {
  id: text("id").primaryKey(),
  groupId: text("group_id").notNull(),
  question: text("question").notNull(),
  deadline: text("deadline").notNull(),
  creatorId: text("creator_id").notNull(),
  subjectId: text("subject_id"),
  showAmounts: integer("show_amounts").notNull().default(0),
  status: text("status").notNull().default("open"),
  outcome: text("outcome"),
  createdAt: text("created_at").notNull(),
});

export const bets = sqliteTable(
  "bets",
  {
    marketId: text("market_id").notNull(),
    userId: text("user_id").notNull(),
    side: text("side").notNull(),
    stake: integer("stake").notNull(),
    createdAt: text("created_at").notNull(),
  },
  (t) => [primaryKey({ columns: [t.marketId, t.userId] })]
);

export const ledgerEntries = sqliteTable("ledger_entries", {
  id: text("id").primaryKey(),
  groupId: text("group_id").notNull(),
  userId: text("user_id").notNull(),
  marketId: text("market_id"),
  kind: text("kind").notNull(),
  amount: integer("amount").notNull(),
  createdAt: text("created_at").notNull(),
});
