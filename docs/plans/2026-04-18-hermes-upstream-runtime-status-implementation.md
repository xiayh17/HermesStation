# Hermes Runtime Status Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Hermes backend update `gateway_state.json.active_agents` whenever `_running_agents` changes, so HermesStation can rely on backend truth instead of estimation.

**Architecture:** Keep the fix narrow inside Hermes backend. Do not add a new state file unless absolutely necessary. Reuse existing `write_runtime_status(...)` and add a tiny helper that is called after every `_running_agents` mutation path.

**Tech Stack:** Python, Hermes gateway runtime, local filesystem state (`gateway_state.json`), manual runtime verification.

---

### Task 1: Create a backend patch branch in the Hermes repo

**Files:**
- Modify: `/Users/xiayh/Projects/install_hermers/hermes-agent`

**Step 1: Check the backend repo status**

Run:

```bash
cd /Users/xiayh/Projects/install_hermers/hermes-agent
git status --short
```

Expected:
- Clean enough to branch safely, or at least understand unrelated local changes before touching runtime logic.

**Step 2: Create a focused branch**

Run:

```bash
cd /Users/xiayh/Projects/install_hermers/hermes-agent
git checkout -b fix/runtime-active-agents-refresh
```

Expected:
- New branch created for the upstreamable backend patch.

**Step 3: Record the exact base commit**

Run:

```bash
cd /Users/xiayh/Projects/install_hermers/hermes-agent
git rev-parse --short HEAD
```

Expected:
- A commit hash to include in the PR notes and local testing log.

**Step 4: Commit**

No commit yet for this task.

### Task 2: Identify every `_running_agents` mutation site

**Files:**
- Inspect: `/Users/xiayh/Projects/install_hermers/hermes-agent/gateway/run.py`

**Step 1: Search all mutation points**

Run:

```bash
cd /Users/xiayh/Projects/install_hermers/hermes-agent
rg -n "_running_agents\\[|del self\\._running_agents|_running_agents\\.pop" gateway/run.py
```

Expected:
- A full list of add / replace / delete paths.

**Step 2: Group mutation sites into categories**

Document categories inside your working notes:

- session claim with `_AGENT_PENDING_SENTINEL`
- replacement of sentinel with real agent
- normal completion cleanup
- forced stop / reset cleanup
- stale entry eviction
- shutdown / drain cleanup

**Step 3: Verify the current status writer call sites**

Run:

```bash
cd /Users/xiayh/Projects/install_hermers/hermes-agent
rg -n "_update_runtime_status\\(" gateway/run.py
```

Expected:
- Very few coarse lifecycle calls, proving why `active_agents` drifts.

**Step 4: Commit**

No commit yet for this task.

### Task 3: Add a dedicated helper for running-agent status sync

**Files:**
- Modify: `/Users/xiayh/Projects/install_hermers/hermes-agent/gateway/run.py`

**Step 1: Write the helper next to `_update_runtime_status`**

Add a tiny wrapper immediately below `_update_runtime_status(...)`, conceptually:

```python
    def _sync_running_agent_runtime_status(
        self,
        gateway_state: Optional[str] = None,
    ) -> None:
        self._update_runtime_status(gateway_state=gateway_state)
```

Notes:
- Keep it intentionally thin.
- Do not fork runtime schema.
- Do not add extra arguments unless you discover a real need while patching.

**Step 2: Keep the helper name boring and explicit**

Requirement:
- The name should say exactly what it does.
- Avoid new abstractions that hide `_running_agents` ownership.

**Step 3: Run a syntax-only sanity check**

Run:

```bash
cd /Users/xiayh/Projects/install_hermers/hermes-agent
python3 -m py_compile gateway/run.py
```

Expected:
- No syntax errors.

**Step 4: Commit**

Wait until Tasks 4-6 are done so the runtime change lands in one coherent commit.

### Task 4: Refresh runtime status when the session is first claimed

**Files:**
- Modify: `/Users/xiayh/Projects/install_hermers/hermes-agent/gateway/run.py`
- Relevant area: the block where `_AGENT_PENDING_SENTINEL` is assigned

**Step 1: Patch the claim path**

Right after:

```python
self._running_agents[_quick_key] = _AGENT_PENDING_SENTINEL
self._running_agents_ts[_quick_key] = time.time()
```

call the helper:

```python
self._sync_running_agent_runtime_status()
```

**Step 2: Patch the `finally` cleanup for lingering sentinels**

When the sentinel is removed in the `finally` block, call the helper again after the deletion so `active_agents` drops immediately.

**Step 3: Re-run syntax check**

Run:

```bash
cd /Users/xiayh/Projects/install_hermers/hermes-agent
python3 -m py_compile gateway/run.py
```

Expected:
- Pass.

**Step 4: Commit**

Still wait.

### Task 5: Refresh runtime status when a real agent replaces or leaves `_running_agents`

**Files:**
- Modify: `/Users/xiayh/Projects/install_hermers/hermes-agent/gateway/run.py`
- Relevant areas:
  - `track_agent()` callback
  - normal completion cleanup

**Step 1: Patch the real-agent registration path**

Right after:

```python
self._running_agents[session_key] = agent_holder[0]
```

call:

```python
self._sync_running_agent_runtime_status(
    "draining" if self._draining else None
)
```

Reason:
- Preserve existing draining semantics when applicable.
- Still refresh `active_agents` even when not draining.

**Step 2: Patch the normal completion cleanup**

After:

```python
if session_key and session_key in self._running_agents:
    del self._running_agents[session_key]
```

call the same helper.

**Step 3: Verify no path leaves `_running_agents` changed without a sync**

Run:

```bash
cd /Users/xiayh/Projects/install_hermers/hermes-agent
rg -n "_running_agents\\[|del self\\._running_agents|_running_agents\\.pop" gateway/run.py
```

Expected:
- You can manually account for every mutation site.

**Step 4: Commit**

Still wait.

### Task 6: Patch force-stop, reset, stale-eviction, and shutdown cleanup paths

**Files:**
- Modify: `/Users/xiayh/Projects/install_hermers/hermes-agent/gateway/run.py`

**Step 1: Patch stale eviction**

Find stale cleanup like:

```python
del self._running_agents[_quick_key]
```

Add helper call immediately after deletion.

**Step 2: Patch stop / reset / new-session forced cleanup**

Any path that force-deletes `_running_agents[...]` must call the helper after deletion.

**Step 3: Patch shutdown or drain cleanup**

Any final cleanup that clears or deletes `_running_agents` entries must refresh runtime status after mutation.

**Step 4: Run syntax check**

Run:

```bash
cd /Users/xiayh/Projects/install_hermers/hermes-agent
python3 -m py_compile gateway/run.py
```

Expected:
- Pass.

**Step 5: Commit**

```bash
cd /Users/xiayh/Projects/install_hermers/hermes-agent
git add gateway/run.py
git commit -m "fix: refresh runtime active_agents on running-agent changes"
```

### Task 7: Validate the backend behavior manually

**Files:**
- Inspect: `/Users/xiayh/Projects/install_hermers/.hermes-home/profiles/yong/gateway_state.json`
- Inspect: `/Users/xiayh/Projects/install_hermers/.hermes-home/profiles/yong/sessions/sessions.json`

**Step 1: Restart the gateway cleanly**

Run:

```bash
cd /Users/xiayh/Projects/install_hermers
./run-hermes-local.sh -p yong gateway restart
```

Expected:
- Gateway returns to running state.

**Step 2: Confirm baseline**

Run:

```bash
cat /Users/xiayh/Projects/install_hermers/.hermes-home/profiles/yong/gateway_state.json
```

Expected:
- `active_agents` should be `0` when idle.

**Step 3: Trigger a real inbound run**

Use one of your existing messaging platforms or a reproducible local trigger.

Expected:
- While the run is ongoing, `active_agents` should become `>= 1`.

**Step 4: Watch the runtime file during execution**

Run:

```bash
watch -n 0.5 'cat /Users/xiayh/Projects/install_hermers/.hermes-home/profiles/yong/gateway_state.json'
```

Expected:
- Count rises promptly on claim / start
- Count drops promptly on completion / forced stop

**Step 5: Test an interrupt path**

Use `/stop` or another real interrupt path.

Expected:
- `active_agents` returns to `0` immediately after cleanup.

**Step 6: Commit**

No new commit unless manual validation requires a fix.

### Task 8: Re-verify HermesStation against true backend status

**Files:**
- Inspect: `/Users/xiayh/Projects/hermes-station-menubar/Sources/HermesStation/MenuContentView.swift`
- Inspect: `/Users/xiayh/Projects/hermes-station-menubar/Sources/HermesStation/GatewayStore.swift`

**Step 1: Rebuild HermesStation**

Run:

```bash
cd /Users/xiayh/Projects/hermes-station-menubar
swift build
```

Expected:
- Build succeeds.

**Step 2: Launch HermesStation**

Run:

```bash
cd /Users/xiayh/Projects/hermes-station-menubar
./.build/debug/HermesStation
```

Expected:
- Menu `Active` count matches real backend `active_agents`
- Estimate mode should no longer be needed in ordinary runs

**Step 3: Note whether fallback still triggers**

If HermesStation still shows `~N` during normal use, the backend patch is incomplete.

**Step 4: Commit**

If HermesStation fallback logic needs cleanup later, do that in a separate commit after backend truth is proven stable.

### Task 9: Prepare the upstream PR payload

**Files:**
- Reference: `/Users/xiayh/Projects/hermes-station-menubar/docs/plans/2026-04-18-hermes-upstream-runtime-status-pr.md`

**Step 1: Generate a concise diff summary**

Run:

```bash
cd /Users/xiayh/Projects/install_hermers/hermes-agent
git show --stat --oneline HEAD
```

**Step 2: Capture the exact changed hunks**

Run:

```bash
cd /Users/xiayh/Projects/install_hermers/hermes-agent
git diff origin/main...HEAD -- gateway/run.py
```

**Step 3: Draft the PR body**

Use the prepared notes in:

- `/Users/xiayh/Projects/hermes-station-menubar/docs/plans/2026-04-18-hermes-upstream-runtime-status-pr.md`

**Step 4: Ensure the PR remains narrowly scoped**

Checklist:
- only runtime status sync logic
- no schema changes
- no unrelated cleanup
- no frontend changes mixed into the backend PR

**Step 5: Commit**

No extra commit if the branch is already clean.

### Task 10: Archive local validation evidence

**Files:**
- Create or update: `/Users/xiayh/Projects/hermes-station-menubar/docs/plans/2026-04-18-hermes-upstream-runtime-status-pr.md`

**Step 1: Append validation notes**

Record:
- backend branch name
- backend commit hash
- whether active count rose during live runs
- whether stop/reset paths dropped back to zero correctly
- whether HermesStation still needed estimate mode

**Step 2: Commit local documentation update**

```bash
cd /Users/xiayh/Projects/hermes-station-menubar
git add docs/plans/2026-04-18-hermes-upstream-runtime-status-pr.md docs/plans/2026-04-18-hermes-upstream-runtime-status-implementation.md TODO.md
git commit -m "docs: prepare upstream runtime status implementation plan"
```

---

## Execution Status

- Backend branch created: `fix/runtime-active-agents-refresh`
- Backend commit created: `5ff801d`
- Backend patch scope:
  - `gateway/run.py`
  - `tests/gateway/test_session_race_guard.py`
- Manual validation completed with a direct Python harness:
  - sentinel claim / release path refreshed runtime status
  - `/stop` force-clean path refreshed runtime status
- Upstream PR opened:
  - `NousResearch/hermes-agent#11867`
  - `https://github.com/NousResearch/hermes-agent/pull/11867`
