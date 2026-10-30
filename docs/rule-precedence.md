# Rule precedence

Several rules can target the same app. For every app on screen, OpenBlock
evaluates its rules in this order and stops at the first match:

1. **Ignored rules.** A rule is skipped when it is disabled or temporarily
   paused from the Rules screen. (Snoozes written by 0.1.0 are honoured until
   they expire.)
2. **Exceptions win.** If an active *Exception* (`allowException`) exists for
   the app, the app is allowed and no other rule applies — not even a focus
   session.
3. **Whole-app block.** An active *Block app* rule (`scheduledBlock`) blocks
   the app. If it is active because of a focus session the intervention says
   so and offers to end the session.
4. **Daily limit.** An active *Daily limit* rule (`appLimit`) blocks the app
   once today's measured usage is at or above the limit. If usage cannot be
   measured (no usage access), the limit is not enforced and the app shows a
   warning.
5. **Feed block.** Active *Block feed* rules (`selectiveFeed`) block the union
   of their feeds. The intervention only appears while an adapter detects one
   of those feeds on screen.
6. **Pause screen.** An active *Pause screen* rule (`pauseScreen`) shows the
   countdown. After "Continue", it does not appear again until you leave the
   app.

When two rules of the same type apply, the one listed first wins.

## When is a rule active?

- **Focus only** rules are active only while a focus session that includes them
  is running.
- Other rules are active on their schedule, and **also** while a running focus
  session includes them.
- A schedule without weekdays applies every day. A schedule without a time
  window applies all day. A window with the same start and end time also means
  all day.
- Time windows include the start minute and exclude the end minute
  (09:00–17:00 is active at 09:00 and inactive at 17:00).
- Overnight windows (for example 22:00–06:00) belong to the weekday they start
  on: a Friday-only 22:00–06:00 window is active on Saturday at 05:59 but not
  on Friday at 05:00.

## Examples

| Rules for YouTube | Situation | Result |
|---|---|---|
| Block app (weekdays 09:00–17:00) + Exception (weekends) | Saturday 10:00 | Allowed (exception active; the block is outside its schedule anyway) |
| Block app (all day) + Exception (weekends) | Saturday 10:00 | Allowed (exception wins) |
| Daily limit 30 min + Block feed (Shorts) | 35 min used | Whole app blocked (limit beats feed) |
| Daily limit 30 min + Block feed (Shorts) | 10 min used, watching Shorts | Shorts blocked |
| Block feed + Pause screen | Opening the app | No pause screen: the feed rule takes precedence, so the app opens normally and only Shorts are blocked |
| Block app (focus only) | No focus session | Allowed |

These cases (and more) are encoded in `test/fixtures/rule_engine_vectors.json`
and checked against both the Dart and the Kotlin engine.
