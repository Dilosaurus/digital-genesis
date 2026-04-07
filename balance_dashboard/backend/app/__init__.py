"""deus.exe // codex backend.

FastAPI application that reads .tres files from card_game/ and serves them
as JSON for the React frontend. Read-only with respect to .tres files.
Edits live in a SQLite draft overlay.
"""
