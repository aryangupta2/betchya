export type Side = "yes" | "no";

export type BetInput = {
  userId: string;
  side: Side;
  stake: number;
};

/** Parimutuel: winners split the full pot proportional to stake on the winning side. */
export function computePayouts(
  bets: BetInput[],
  outcome: Side
): { payouts: Record<string, number>; pot: number; winningTotal: number } {
  const pot = bets.reduce((sum, b) => sum + b.stake, 0);
  const winning = bets.filter((b) => b.side === outcome);
  const winningTotal = winning.reduce((sum, b) => sum + b.stake, 0);

  if (winningTotal === 0) {
    return { payouts: {}, pot, winningTotal: 0 };
  }

  const payouts: Record<string, number> = {};
  let allocated = 0;
  winning.forEach((b, index) => {
    if (index === winning.length - 1) {
      payouts[b.userId] = pot - allocated;
    } else {
      const share = Math.floor((b.stake * pot) / winningTotal);
      payouts[b.userId] = share;
      allocated += share;
    }
  });

  return { payouts, pot, winningTotal };
}

export function bothSidesPresent(bets: BetInput[]): boolean {
  const yes = bets.some((b) => b.side === "yes");
  const no = bets.some((b) => b.side === "no");
  return yes && no;
}

/** Resolver: subject if tagged, otherwise creator. */
export function resolverId(creatorId: string, subjectId: string | null | undefined): string {
  return subjectId && subjectId.length > 0 ? subjectId : creatorId;
}

export function canUserBet(params: {
  userId: string;
  creatorId: string;
  subjectId: string | null | undefined;
}): boolean {
  return params.userId !== resolverId(params.creatorId, params.subjectId);
}
