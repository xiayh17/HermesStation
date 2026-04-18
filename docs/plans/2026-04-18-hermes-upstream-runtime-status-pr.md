# Hermes Upstream Runtime Status PR Prep

## Goal

Prepare a clean upstream PR against Hermes backend so HermesStation no longer has to guess live agent activity from indirect signals.

The upstream fix should make runtime state files reflect `_running_agents` changes promptly and deterministically.

## Why This Exists

HermesStation currently reads multiple local artifacts:

- `gateway_state.json`
- `sessions/sessions.json`
- `state.db`
- session transcript mtimes
- gateway process PID / process tree

Only `gateway_state.json.active_agents` is intended to represent the true live in-memory agent count.

Right now that field is stale in practice. The gateway backend only writes it during coarse runtime status updates, so the menubar can show `0` even while a session is actively being processed.

HermesStation has a temporary fallback heuristic:

- Prefer backend `active_agents`
- If backend says `0`, estimate from recent active session activity
- Display estimate as `~N`

That is intentionally a stopgap, not the final architecture.

## Local Evidence

### Observed backend behavior

Current runtime file:

- `/Users/xiayh/Projects/install_hermers/.hermes-home/profiles/yong/gateway_state.json`

Observed values:

- `active_agents: 0`
- `active_sessions` contains bound Feishu / Weixin sessions

This proves the runtime file can retain useful binding state while still failing to represent actual live `_running_agents` correctly.

### Relevant HermesStation workaround code

Menu currently shows `Active` using a true-value-first / estimate-second display:

- [MenuContentView.swift](/Users/xiayh/Projects/hermes-station-menubar/Sources/HermesStation/MenuContentView.swift#L152)

Snapshot assembly loads bindings and computes fallback recent activity:

- [GatewayStore.swift](/Users/xiayh/Projects/hermes-station-menubar/Sources/HermesStation/GatewayStore.swift#L589)
- [GatewayStore.swift](/Users/xiayh/Projects/hermes-station-menubar/Sources/HermesStation/GatewayStore.swift#L1200)

Derived display logic:

- [GatewaySnapshot.swift](/Users/xiayh/Projects/hermes-station-menubar/Sources/HermesStation/GatewaySnapshot.swift#L242)

These should be considered compatibility scaffolding until upstream runtime reporting is trustworthy.

## Root Cause Summary

Backend location:

- `hermes-agent/gateway/run.py`
- `hermes-agent/gateway/status.py`

Current behavior:

- `_running_agents` is the real in-memory truth
- `_running_agent_count()` returns `len(self._running_agents)`
- `_update_runtime_status(...)` writes `active_agents=self._running_agent_count()`
- But `_update_runtime_status(...)` is only called at lifecycle milestones such as `starting`, `running`, `draining`, `stopped`

Consequence:

- `active_agents` is not refreshed when `_running_agents` changes during ordinary message handling
- A session can start, run, and finish without `gateway_state.json` being updated at the right moments

## Upstream Fix Scope

### Required behavior

Whenever `_running_agents` changes, the runtime file should be refreshed.

Specifically:

1. When a session is claimed with `_AGENT_PENDING_SENTINEL`
2. When a real agent instance replaces the sentinel
3. When an agent is interrupted and force-cleared
4. When an agent finishes normally and is removed
5. When stale `_running_agents` entries are evicted
6. When shutdown cleanup empties the running set

### Preferred implementation

Add a tiny helper in `gateway/run.py`, conceptually:

```python
def _sync_running_agent_runtime_status(self, gateway_state: Optional[str] = None) -> None:
    self._update_runtime_status(gateway_state=gateway_state)
```

Then call it immediately after every mutation to:

- `self._running_agents`
- `self._running_agents_ts`

This keeps the patch narrow and avoids inventing a second runtime status file unless necessary.

### Non-goals

- Do not redesign session storage
- Do not change `sessions.json` schema
- Do not change `state.db` schema
- Do not rely on frontend heuristics as the canonical fix

## Candidate Upstream Files

- `hermes-agent/gateway/run.py`
- `hermes-agent/gateway/status.py`

Potentially inspect, but avoid patching unless needed:

- `hermes-agent/gateway/session.py`
- `hermes-agent/hermes_cli/status.py`

## Backward Compatibility

The PR should preserve:

- existing `gateway_state.json` keys
- existing `active_agents` semantics
- existing platform status reporting
- existing session binding reporting via `active_sessions`

HermesStation and any other client should benefit automatically without changing file format expectations.

## Suggested Test Plan For Upstream PR

### Manual

1. Start gateway
2. Confirm `gateway_state.json.active_agents == 0`
3. Trigger a platform message that starts an agent
4. While the agent is actively running, confirm `gateway_state.json.active_agents >= 1`
5. Let the run finish
6. Confirm `gateway_state.json.active_agents` returns to `0`
7. Repeat for interrupt / `/stop` / `/new`
8. Repeat with two concurrent session keys if backend supports it

### Regression checks

1. `gateway_state.json.platforms` still updates normally
2. `active_sessions` still reflects persisted bindings
3. Shutdown path still writes `draining` / `stopped`
4. No excessive write storms or corrupted runtime file

## PR Message Skeleton

### Title

`gateway: refresh runtime active_agents when running agent set changes`

### Summary

- Fix stale `gateway_state.json.active_agents`
- Sync runtime status when `_running_agents` is added, replaced, or removed
- Preserve existing runtime file schema

### Motivation

Frontend clients such as HermesStation use `gateway_state.json` as the canonical runtime health surface. The current implementation writes `active_agents` only at coarse lifecycle boundaries, which causes long-lived false zero readings during normal message handling.

### Validation

- verified `active_agents` increments when a session starts running
- verified `active_agents` decrements when the run ends or is force-stopped
- verified no runtime schema changes

## HermesStation Follow-up After Upstream Merge

After upstream lands and is deployed locally:

1. Re-test menu count against true backend value
2. Keep heuristic fallback for one release as compatibility
3. If backend proves stable, reduce prominence of estimate mode
4. Optionally expose a debug line in UI when frontend is using fallback instead of backend truth

## Current Status

- Document prepared
- HermesStation currently contains temporary fallback logic
- Upstream backend patch authored in local branch `fix/runtime-active-agents-refresh`
- Backend commit: `5ff801d` (`fix: refresh runtime active_agents on running-agent changes`)
- Upstream PR opened: `NousResearch/hermes-agent#11867`
- PR URL: `https://github.com/NousResearch/hermes-agent/pull/11867`
