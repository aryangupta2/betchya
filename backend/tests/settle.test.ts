import { describe, expect, test } from "bun:test";
import {
  bothSidesPresent,
  canUserBet,
  computePayouts,
  resolverId,
} from "../src/settle";

describe("computePayouts", () => {
  test("splits pot proportional to winning stakes", () => {
    const { payouts, pot } = computePayouts(
      [
        { userId: "a", side: "yes", stake: 100 },
        { userId: "b", side: "yes", stake: 100 },
        { userId: "c", side: "no", stake: 100 },
      ],
      "yes"
    );
    expect(pot).toBe(300);
    expect(payouts.a + payouts.b).toBe(300);
    expect(payouts.a).toBe(150);
    expect(payouts.b).toBe(150);
    expect(payouts.c).toBeUndefined();
  });

  test("assigns remainder to last winner to avoid dust loss", () => {
    const { payouts, pot } = computePayouts(
      [
        { userId: "a", side: "yes", stake: 10 },
        { userId: "b", side: "yes", stake: 20 },
        { userId: "c", side: "no", stake: 5 },
      ],
      "yes"
    );
    expect(pot).toBe(35);
    expect(payouts.a + payouts.b).toBe(35);
  });

  test("empty winning side yields no payouts", () => {
    const { payouts } = computePayouts([{ userId: "a", side: "yes", stake: 50 }], "no");
    expect(payouts).toEqual({});
  });
});

describe("market rules helpers", () => {
  test("bothSidesPresent", () => {
    expect(bothSidesPresent([{ userId: "a", side: "yes", stake: 10 }])).toBe(false);
    expect(
      bothSidesPresent([
        { userId: "a", side: "yes", stake: 10 },
        { userId: "b", side: "no", stake: 10 },
      ])
    ).toBe(true);
  });

  test("resolver is subject when tagged else creator", () => {
    expect(resolverId("creator", null)).toBe("creator");
    expect(resolverId("creator", "subject")).toBe("subject");
  });

  test("resolver cannot bet", () => {
    expect(canUserBet({ userId: "creator", creatorId: "creator", subjectId: null })).toBe(false);
    expect(canUserBet({ userId: "friend", creatorId: "creator", subjectId: null })).toBe(true);
    expect(canUserBet({ userId: "subject", creatorId: "creator", subjectId: "subject" })).toBe(
      false
    );
    expect(canUserBet({ userId: "creator", creatorId: "creator", subjectId: "subject" })).toBe(
      true
    );
  });
});
