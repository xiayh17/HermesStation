- [ ] Continue strengthening profile semantics in the UI so the switcher feels like choosing an isolated Hermes runtime, not just a display name.
  Show per-profile scope summaries directly in switch menus/cards.
  Consider surfacing provider/model/gateway status alongside `-p <profile-id>`.

- [ ] Prepare upstream Hermes backend PR for stale `active_agents` reporting.
  Tracking doc: `docs/plans/2026-04-18-hermes-upstream-runtime-status-pr.md`
  Goal: make `gateway_state.json.active_agents` refresh on `_running_agents` mutations so HermesStation can stop relying on fallback estimation.
