# Milestone 7: a versioned online leaderboard

This lesson describes **M7 as it shipped**, rather than the current game. [Browse the complete milestone source](https://github.com/pelletiermaxime/little-last-light/tree/milestone-7). The short excerpts below come from that tag; full files remain available through the links.

## What changed

After death or End Run, a new survival record offers optional publication with a username. Nothing publishes automatically. The website shows the top 100 for the selected release and updates live.

Energy and turret layouts carry between versions. Survival records are separate, so a balancing change does not mix new scores with those earned under older rules.

## The idea to learn: local state and online state can disagree temporarily

A player can finish a run while offline, retry later, or earn a better record while an earlier request is still travelling. The design keeps a local pending record until a successful response confirms it.

```text
Run ends → Local record + save → Player chooses Publish
                                      ↓
                               Validated HTTP request
                                      ↓
                              Convex stores best score
                                      ↓
                               Website updates live
```

A failure leaves the pending offer available for another attempt.

## 1. Create the offer when a run ends

Main records the best for this release and prepares a score only when it improves:

[main.gd, excerpt](https://github.com/pelletiermaxime/little-last-light/blob/milestone-7/main.gd#L87)

```gdscript
	version_bests[game_version] = best_time
	if last_run.new_best:
		leaderboard_profile.pending = {"version": game_version, "durationMs": maxi(1, int(lantern.elapsed * 1000.0))}
```

The local timer uses seconds; the API uses integer milliseconds. For example, 65.125 seconds becomes 65125. The release version comes from the exported game's version setting, which is distinct from the M7 tag and the save-format number.

Both death and the pause screen's End Run call the same method, so they follow the same record, banking, and saving rules.

## 2. Do not let an old response erase a new record

Before publishing, the panel saves the profile and copies the pending record into `sending`. On success it checks:

[leaderboard_panel.gd, excerpt](https://github.com/pelletiermaxime/little-last-light/blob/milestone-7/leaderboard_panel.gd#L119)

```gdscript
		if main.leaderboard_profile.pending == sending:
			main.leaderboard_profile.pending = {}
```

Suppose you publish 70 seconds, then earn 80 while the request is in flight. The response confirms 70, but the current pending record is 80. They differ, so the newer offer survives.

A network failure also leaves the offer intact. No thanks clears the offer while retaining the local best. The pending slot and chosen username survive reopening.

## 3. Store one best score per save and release

Each save has a random token. The backend hashes it and uses the hash plus version to find the existing entry:

[leaderboard/convex/scores.ts, excerpt](https://github.com/pelletiermaxime/little-last-light/blob/milestone-7/leaderboard/convex/scores.ts#L33)

```typescript
    const previous = await ctx.db.query('scores').withIndex('by_player_version', q => q.eq('playerHash', args.playerHash).eq('version', args.version)).unique()
    if (previous && previous.durationMs >= args.durationMs) return { ok: true }
```

Repeating the same request, or submitting a lower score, succeeds without creating another row. A better score updates the existing row. This makes retrying safe even if the server stored a score but its response never reached the game.

The HTTP layer validates names, versions, tokens, and durations before this mutation. Public results contain rank, username, duration, and achievement time; they omit the identity hash.

## Compatibility and limits

Old saves still load. Their unversioned best is preserved separately rather than assigned to a guessed release. Saved energy and positions retain their existing behavior.

Usernames are display names, not accounts. These are unverified client-reported scores with persistent progression, not equal-start competitive runs. Resetting a save creates another identity. Stronger abuse prevention and account recovery remain future work.

The game and leaderboard website have separate deployment lifecycles. M7 also makes game publication wait for both the game build and leaderboard checks.

## Try it and understand the checks

Complete a personal best, inspect the offer, and choose No thanks if you want to keep it local. Notice that another equal or lower result does not prompt again. A later improved result can be offered.

Verification covered ten Godot checks, seven Python tests, three backend tests, type checking, a production website build, and six desktop/mobile browser checks. The browser tests simulate live updates without publishing fake scores. The added integration test ends a paused run and verifies both banked energy and the pending record survive reopening.

## Full source when you need it

Read [leaderboard_panel.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-7/leaderboard_panel.gd) for requests and retries, [main.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-7/main.gd) for records and migration, [leaderboard/convex/scores.ts](https://github.com/pelletiermaxime/little-last-light/blob/milestone-7/leaderboard/convex/scores.ts) for stored scores, and [tests/check_leaderboard.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-7/tests/check_leaderboard.gd) for integration scenarios. [Deployment instructions](https://github.com/pelletiermaxime/little-last-light/blob/milestone-7/leaderboard/README.md) are separate from this lesson.
