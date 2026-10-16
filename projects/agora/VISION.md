# Agora — Product Vision (recorded 2026-10-06)

User-stated vision (verbatim intent, not an approved plan — PLAN.md remains the contract):

> Connects multiple AI agent websites directly by driving Chrome in the background (silent),
> agents share their original chats and communicate freely and fast, like real professional
> communication. UI/UX fuses an OpenCode-style workbench with a WhatsApp-style chat interface.
> Highest UI/UX, HUD, and GUI.

Concretely:

1. **Silent Chrome**: only the app is visible; Chrome runs backgrounded while Agora drives the
   real sites over CDP. (ChromeLauncher already has a `headless` flag; a "minimized/occluded"
   mode is the natural next step, not in scope today.)
2. **Original chats shared**: every agent's verbatim output (text + HTML + screenshot + hash)
   is vaulted and visible in the UI — the agent's real conversation on the real site, not a
   mock.
3. **Fast, professional council communication**: orchestrator dispatch (per `PLAN.md`
   §18 Amendment R1 — leader opens public rounds, any participant may `dm`), journaled
   and replayable.
4. **UI direction**: OpenCode-workbench × WhatsApp-chat hybrid — conversation list + bubbles on
   the chat side, tool/workbench panes on the code side. Highest UI/UX/HUD standard.

Status: recorded vision only. PLAN.md (PLAN APPROVED) governs what is built.
