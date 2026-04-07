---
title: Auth and deploy
status: planned
order: 11
phase: 9
tag: infra
---

## auth and deploy

deus.exe // codex is designed to be **web-deployable** from day one — Docker, persistent state, multi-user capable. Phase 9 makes that real:

- **FastAPI-Users** with email/password local auth. No OAuth, no SSO, no enterprise identity brokers. The user base is expected to be 1–10 people (Chris, a few close collaborators, maybe a designer down the line).
- **User** model in SQLModel, stored alongside the drafts DB.
- **/admin** page for user management.
- **Docker Compose** for production: nginx fronting the React build, uvicorn running the backend, SQLite volume mount for drafts + users, `card_game/` mounted read-only.
- **deploy.sh** updated for the new compose layout.
- **Documentation** — a single README page that explains the deploy process, the source-of-truth principle, and the draft-promotion workflow.

Not planned: reconnection UI, password reset via email, rate limiting, audit logging, or anything else that would make sense at scale but is overkill for a design tool with a handful of users.
