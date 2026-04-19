# HermesStation Capability Control Plane Design

## Status

Draft

## Date

2026-04-20

## Owner

HermesStation

## Summary

HermesStation should evolve from a native macOS menu bar monitor for Hermes runtime state into a capability control plane for Hermes instances.

Today the product is strongest as an operations surface:

- gateway runtime and process health
- profile switching
- platform connectivity
- model and provider configuration
- memory, skills, tools, cron jobs, and usage inspection

That is already valuable, but the current information architecture is still component-oriented. Users manage `config.yaml`, `.env`, `SOUL.md`, skills, tools, models, and platform bindings as separate pieces. The user has to mentally assemble those pieces into higher-level abilities such as:

- research
- content creation
- messaging automation
- agent memory
- multimodal expression

The opportunity is to make HermesStation the place where a user can answer three questions immediately:

1. What can this Hermes instance do right now?
2. What is missing for a target capability to become production ready?
3. Can HermesStation help me install, verify, and maintain that capability end to end?

The recommended direction is to add a new capability-oriented product layer on top of the existing settings and diagnostics foundation, without replacing the existing deep-control tabs in v1.

## Context

The current app already contains much of the raw substrate needed for this transition:

- `GatewayStore` and `GatewaySnapshot` expose runtime, process, session, and platform truth.
- `HermesProfileStore` exposes Hermes profile state and mutable configuration.
- `SettingsView` already includes tabs for Memory, Skills, Tools, Cron, Usage, Platforms, Models, and Environment.
- `HermesKnowledgeCatalog` already indexes installed memory and skills for the active Hermes profile.

The linked Hermes ecosystem article frames Hermes not as a chat app, but as a layered agent stack:

- identity and memory
- perception
- expression
- efficiency and cost
- ecosystem expansion

That framing is strategically useful because it matches how users think about desired outcomes, not how configuration files are organized.

Relevant source material:

- `README.md`
- existing settings shell in `Sources/HermesStation/SettingsView.swift`
- memory and skill catalog views
- external capability framing from ResearchWang:
  - <https://x.com/ResearchWang/status/2045812932538438001>
  - <https://researchwang13.space/hermes/>

## Problem Statement

HermesStation currently helps users operate Hermes, but it does not yet help them compose Hermes into trusted, reusable capabilities.

This creates four product gaps:

### 1. The app is system-aware, but not capability-aware

Users can inspect model providers, skills, memory files, and platforms, but the app does not tell them whether "research mode" or "content mode" is actually ready.

### 2. The app is configuration-heavy, but outcome-light

The current experience optimizes for editing and diagnosis. It does not provide a capability target, a readiness score, or a recommended path to completion.

### 3. The app exposes ecosystem pieces, but not ecosystem flows

Users still need to discover recipes from blog posts, GitHub repositories, and ecosystem maps, then manually translate them into local Hermes configuration.

### 4. The app can monitor the runtime, but it cannot yet verify real business flows

For example, it can show that a gateway is running and a platform is connected, but it does not validate that:

- search returns cited results
- a webpage can be fetched and normalized
- a PDF can be converted into usable markdown
- memory retrieval is functioning
- a scheduled automation can actually complete

## Goals

- Reframe HermesStation around user-visible capabilities rather than only internal subsystems.
- Make capability readiness legible at a glance for the active Hermes profile.
- Provide one-click or guided installation for opinionated recipe packs.
- Add end-to-end capability verification, not just runtime health checks.
- Keep the current advanced controls available for users who need direct access to Hermes internals.
- Build on existing app architecture first, rather than requiring deep Hermes backend changes.

## Non-Goals

- Replacing Hermes CLI as the mutation source of truth in v1.
- Rebuilding the entire app navigation in one release.
- Creating a public cloud marketplace in the first iteration.
- Designing a generic cross-platform Hermes admin app outside macOS.
- Inventing new Hermes runtime schemas before the UI proves what abstractions are needed.

## Assumptions

- HermesStation remains a native macOS app with a menu bar first-run posture.
- Hermes CLI remains the preferred write path for profile mutations where possible.
- Existing tabs such as Models, Memory, Skills, Tools, Cron, Platforms, and Environment should remain accessible as advanced surfaces.
- Some capability evaluations will be derived purely from local config and file inspection in v1.
- Some higher-trust verification flows may require controlled probe runs and lightweight test prompts in later phases.

## Product Principles

### 1. Lead with abilities, not files

The first screen should describe what Hermes can do, not which files exist.

### 2. Derived truth first

Whenever possible, capability status should be computed from existing runtime, config, and catalog data rather than requiring users to maintain another checklist.

### 3. CLI-compatible writes

If Hermes CLI already defines the safe mutation path, HermesStation should prefer it over inventing a parallel configuration writer.

### 4. Readiness beats decoration

Every capability surface should answer:

- what is configured
- what is missing
- what is broken
- what should happen next

### 5. Progressive disclosure

Users should be able to start at a capability card and drill down into the exact Models, Skills, Tools, Memory, Platform, or Environment detail page that explains the status.

### 6. Verification is part of the product

A capability is not "enabled" because a toggle exists. It is enabled when HermesStation can prove the full loop works.

## Approaches Considered

### Option A: Keep the existing app structure and only add summary cards

Description:

- Add a few top-level cards to the current Hermes tab.
- Keep all current tabs unchanged.
- Use cards mostly as shortcuts into existing detail panes.

Pros:

- Lowest implementation cost
- Minimal migration risk
- Easy to ship incrementally

Cons:

- Feels additive, not strategic
- Does not change the user's mental model
- Risks becoming a shallow dashboard layer with limited product differentiation

### Option B: Add a capability control plane layer above current detail tabs

Description:

- Introduce a new capability-oriented home and readiness system.
- Keep current tabs as advanced deep links and configuration panels.
- Add recipe packs and verification flows in phased rollouts.

Pros:

- Reframes the product clearly
- Reuses current architecture
- Supports staged rollout
- Preserves power-user control

Cons:

- Requires new derived data models
- Needs careful information architecture to avoid duplication

### Option C: Fully rebuild the app around recipes and workflows

Description:

- Replace current tabs with a workflow-centric product.
- Treat file-level and config-level surfaces as implementation details only.

Pros:

- Strongest conceptual leap
- Highest chance of appearing category-defining

Cons:

- Highest execution risk
- Likely to regress current power-user workflows
- Too much unknown product surface for one cycle

## Recommendation

Adopt Option B.

HermesStation should become a capability control plane by adding a capability-oriented shell above the current advanced controls. This preserves the app's current operational strength while giving it a clear new product identity.

In practice:

- the current `Hermes` tab becomes the launchpad for capability readiness
- the existing tabs remain and become the advanced subsystem views
- new capability cards, recipe packs, and doctor flows become the primary orientation layer

## Proposed Information Architecture

### New top-level framing

The app should distinguish between:

- `Capability surfaces`: what Hermes can do
- `Advanced surfaces`: how Hermes is configured

### Proposed navigation model

Keep the current settings window, but reposition the experience:

1. `Overview`
2. `Capabilities`
3. `Recipes`
4. `Verify`
5. `Advanced`

In v1, this can be implemented without deleting current tabs by:

- renaming the current `Hermes` tab to function as the overview
- adding capability and recipe sections inside that top-level shell
- grouping current subsystem tabs under an "Advanced" mental model in copy and navigation

### Capability domains

The recommended first set of domains is:

1. Identity
2. Memory
3. Perception
4. Expression
5. Automation
6. Cost and Observability

Rationale:

- These domains match the external capability framing.
- They map well to existing HermesStation data sources.
- They are broad enough to support recipes without becoming too abstract.

### Domain definitions

#### Identity

Scope:

- `SOUL.md`
- role packs
- active profile meaning
- model defaults and routing intent

Primary question:

- Does this Hermes instance know who it is supposed to be?

#### Memory

Scope:

- built-in memory files
- external memory backend configuration
- memory freshness and usage traces

Primary question:

- Can Hermes remember and retrieve durable context across sessions?

#### Perception

Scope:

- search backend
- content fetching
- browser automation
- document conversion
- platform ingress

Primary question:

- Can Hermes reliably gather and normalize information from the outside world?

#### Expression

Scope:

- text output quality presets
- image generation providers
- speech recognition
- TTS
- multimodal model coverage

Primary question:

- Can Hermes produce the forms of output this profile needs?

#### Automation

Scope:

- cron jobs
- platform triggers
- scheduled routines
- durable recipes

Primary question:

- Can Hermes perform repeated work without manual babysitting?

#### Cost and Observability

Scope:

- usage
- token breakdown
- provider health
- runtime diagnostics
- verification history

Primary question:

- Is this Hermes instance efficient, explainable, and trustworthy?

## Capability Home

### Purpose

Provide one screen that tells the truth about the active Hermes profile as a system of abilities.

### UI model

The new home should center on capability cards.

Each card should show:

- capability name
- readiness status
- short explanation
- key dependencies
- current provider or tool choices
- last verification result
- primary action
- deep-link actions

### Readiness states

Recommended state model:

- `Ready`
- `Partial`
- `Blocked`
- `Unverified`
- `Degraded`

### Example card content

#### Perception card

- Status: `Partial`
- Search: Tavily configured
- Fetch: Jina-based fetch available
- Browser: not configured
- Docs: Marker missing
- Last verify: never run
- CTA: `Complete Setup`

#### Memory card

- Status: `Ready`
- Local memory files found
- External backend: Hindsight configured
- Recent memory write observed
- Last verify: passed 2 days ago
- CTA: `Inspect Memory`

## Recipe Packs

### Purpose

Turn ecosystem best practices into installable, repeatable bundles.

Instead of making users translate community blog posts into a series of manual steps, HermesStation should offer opinionated packs.

### Proposed pack model

Each pack contains:

- use case
- required capabilities
- required dependencies
- recommended providers
- install steps
- verification steps
- expected ongoing cost signals

### Initial pack candidates

1. Research Pack
2. Content Pack
3. Messaging Ops Pack
4. Coding Pack
5. Lightweight Personal Assistant Pack

### Research Pack example

Includes:

- identity preset for research assistant posture
- search backend
- single-page fetch tool
- deep crawl option
- PDF to markdown tooling
- browser automation optional dependency
- memory configuration recommendation
- verification flow for search, fetch, convert, summarize

### Content Pack example

Includes:

- writing persona setup
- image generation provider wiring
- optional speech-to-text
- publishing or social workflow skills
- memory for brand or voice persistence

### Installation behavior

Recipe installation should be guided, not magical.

For each step HermesStation should show:

- what it is about to change
- which Hermes command or file mutation it will use
- whether secrets are required
- how to undo the change

## Capability Doctor

### Purpose

Move from subsystem diagnostics to workflow diagnostics.

Today HermesStation can tell the user whether the gateway is loaded and whether platforms are connected. Tomorrow it should also tell the user whether the target capability actually works.

### Verification model

Each capability domain gets a doctor flow made of checks:

- static checks
- dependency checks
- runtime checks
- end-to-end probe checks

### Static checks

Examples:

- required file exists
- environment variable present
- CLI dependency installed
- toolset enabled
- skill installed

### Runtime checks

Examples:

- gateway reachable
- provider responds
- platform session binding exists
- cron entry enabled

### End-to-end checks

Examples:

- search returns result with citations
- URL fetch returns normalized markdown
- PDF is converted successfully
- memory note can be written and then retrieved
- scheduled task executes and logs completion

### Verification history

HermesStation should persist a lightweight history of:

- capability verified
- checks run
- result
- duration
- timestamp
- profile

This becomes the trust layer behind readiness states.

## Advanced Surfaces Mapping

The existing tabs should remain, but with clearer mapping into capability domains.

### Current to future mapping

- `Models` -> Identity, Expression, Cost and Observability
- `Sessions` -> Automation, Cost and Observability
- `Memory` -> Memory
- `Skills` -> all domains, especially pack prerequisites
- `Tools` -> Perception and Expression
- `Cron` -> Automation
- `Usage` -> Cost and Observability
- `Platforms` -> Perception and Automation
- `Environment` -> cross-cutting infrastructure

This prevents wasteful rewrites and gives users a stable deep-control layer.

## Data Model Proposal

The first version should be mostly additive and derived.

### New read models

```swift
struct CapabilityDomain: Identifiable, Codable {
    let id: String
    let title: String
    let summary: String
    let category: CapabilityCategory
}

enum CapabilityReadiness: String, Codable {
    case ready
    case partial
    case blocked
    case unverified
    case degraded
}

struct CapabilityDependency: Identifiable, Codable {
    let id: String
    let title: String
    let kind: DependencyKind
    let status: DependencyStatus
    let detail: String
    let deepLink: CapabilityDeepLink?
}

struct CapabilityStatusCard: Identifiable, Codable {
    let id: String
    let domainID: String
    let readiness: CapabilityReadiness
    let summary: String
    let dependencies: [CapabilityDependency]
    let currentProviders: [String]
    let lastVerification: CapabilityVerificationSummary?
    let recommendedAction: CapabilityAction?
}

struct RecipePack: Identifiable, Codable {
    let id: String
    let title: String
    let outcome: String
    let domains: [String]
    let steps: [RecipeStep]
    let verifyPlan: [CapabilityDoctorCheck]
}

struct CapabilityVerificationRun: Identifiable, Codable {
    let id: UUID
    let profileID: UUID
    let domainID: String
    let startedAt: Date
    let finishedAt: Date?
    let result: VerificationResult
    let checks: [CapabilityDoctorCheckResult]
}
```

### New evaluators

Recommended new internal services:

- `CapabilityEvaluator`
- `RecipeRegistry`
- `RecipeInstaller`
- `CapabilityDoctor`
- `VerificationHistoryStore`

### Data source mapping

`CapabilityEvaluator` should initially derive status from:

- `AppSettings`
- `GatewaySnapshot`
- `HermesProfileStore.snapshot`
- `HermesKnowledgeCatalog`
- file existence checks in `HermesPaths`
- targeted CLI probes via `CommandRunner`

## Storage Proposal

### Phase 1

Avoid introducing Hermes-side schema changes.

Store HermesStation-owned metadata locally in app support, for example:

- `capability_verifications.json`
- `recipe_installs.json`

Continue deriving most state at runtime from Hermes config and runtime files.

### Phase 2

If capability concepts prove stable, consider folding some metadata into `settings.json`, but only after validating that profile-scoped semantics are correct.

## UX Flows

### Flow 1: First-time user wants a research-ready Hermes

1. Open HermesStation
2. Overview shows `Perception` and `Memory` are blocked or partial
3. User opens `Research Pack`
4. HermesStation shows prerequisites, secrets needed, and planned mutations
5. User confirms setup
6. HermesStation installs or configures dependencies
7. HermesStation runs capability doctor
8. Overview card updates to `Ready` or `Partial`

### Flow 2: Existing user sees degraded content capability

1. Overview shows `Expression` is degraded
2. Card indicates image provider key missing and speech tools outdated
3. User deep-links into the exact provider pane or environment file
4. User fixes configuration
5. User reruns verification
6. Card returns to `Ready`

### Flow 3: Power user wants deep control

1. User starts on capability home
2. User clicks `Inspect Memory`
3. App deep-links into the current memory pane
4. User edits or inspects exact artifacts
5. User returns to overview without losing the higher-level framing

## Menu Bar Experience

The menu bar popover should remain a glance layer, not a full configuration shell.

Recommended evolution:

- keep gateway and platform health
- add one compact capability strip
- surface the top 1 to 3 degraded capabilities
- expose quick actions like `Run Doctor`, `Complete Setup`, or `Open Recipe`

This lets the menu bar express capability posture without overcrowding the popover.

## Technical Architecture

### V1 implementation strategy

### Layer 1: Capability derivation

Add an app-side capability evaluator that computes status from current sources of truth.

This is mostly read-only and low risk.

### Layer 2: Recipe metadata

Ship a bundled recipe registry in the app.

This can be a local JSON or markdown-backed manifest describing:

- pack metadata
- required dependencies
- install commands
- verify commands
- deep links

### Layer 3: Guided mutation

Reuse existing stores and `CommandRunner` for writes.

Examples:

- enable a toolset with Hermes CLI
- install or open a skill
- deep-link to `.env`
- run doctor command
- open a setup instruction for a missing external tool

### Layer 4: Verification execution

Add lightweight doctor jobs that can be run on demand and later on schedule.

### Why this architecture fits the repo

- It respects the existing separation between settings, profile state, and gateway state.
- It keeps HermesStation additive rather than invasive.
- It allows partial rollout without redesigning every tab.
- It creates product leverage from code the app already owns.

## Rollout Plan

### Phase 0: Foundation and copy

- Define capability taxonomy
- Add domain copy and card framing
- Map existing tabs to capability domains
- Add internal evaluator scaffolding

### Phase 1: Capability Home

- Ship capability cards on the main Hermes overview surface
- Compute readiness from existing local state
- Add deep links into current tabs

Success criteria:

- users can understand readiness without opening multiple tabs
- the top missing dependency is obvious

### Phase 2: Recipe Packs

- Ship 2 to 3 first-party recipe packs
- Show guided install steps and planned mutations
- Persist pack install state locally

Success criteria:

- users can complete a useful Hermes setup with fewer manual external steps

### Phase 3: Capability Doctor

- Add on-demand verification flows
- Persist verification history
- Show last verified timestamps on capability cards

Success criteria:

- readiness becomes evidence-backed rather than inferred

### Phase 4: Ecosystem Layer

- Add community recipe discovery
- support importable packs
- add trust signals such as source, maintenance, and dependency risk

Success criteria:

- HermesStation becomes the preferred ecosystem entry point

## Success Metrics

### Product metrics

- time from clean profile to first usable capability
- number of profiles with at least one verified capability
- recipe completion rate
- doctor rerun rate after failure
- percentage of active users who use overview cards before advanced tabs

### Quality metrics

- false positive rate in readiness evaluation
- verification success rate per capability
- support incidents caused by destructive or unclear automated setup

## Risks

### 1. Readiness oversimplification

If readiness states are too optimistic, trust in the whole product drops.

Mitigation:

- separate `configured` from `verified`
- show evidence behind each state

### 2. Duplication with advanced tabs

Users may feel the same information exists twice.

Mitigation:

- capability surfaces summarize and recommend
- advanced tabs inspect and edit

### 3. Unsafe automation

One-click setup is powerful but risky when secrets, third-party dependencies, or OS-level installs are involved.

Mitigation:

- guided installs
- explicit preview of mutations
- clear rollback story

### 4. Ecosystem volatility

Tools and skills in the Hermes ecosystem will change rapidly.

Mitigation:

- prefer bundled first-party packs first
- add versioning and trust metadata before community pack automation

## Open Questions

1. Should recipe packs live entirely in HermesStation, or eventually be exportable and shareable as repository artifacts?
2. What level of automatic dependency installation is acceptable on macOS before the app becomes too intrusive?
3. Should verification history remain HermesStation-local, or eventually become a Hermes profile artifact?
4. Is the long-term top-level navigation best modeled as tabs, or should the overview become a sidebar shell with capability sections?
5. Which three recipe packs best represent the HermesStation brand in the first public release?

## Immediate Next Steps

1. Align on capability taxonomy and the first three recipe packs.
2. Design the `Capability Home` card layout and deep-link behavior.
3. Implement a read-only `CapabilityEvaluator` with no mutation side effects.
4. Test whether existing app data is sufficient to produce trustworthy readiness states.
5. Only after that, implement guided recipe installation and doctor flows.

## Recommendation in One Sentence

HermesStation should define the Hermes user experience around verified capabilities, while preserving its existing strengths as the advanced operations console underneath.
