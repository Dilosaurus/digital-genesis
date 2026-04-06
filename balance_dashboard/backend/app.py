"""
app.py — Flask backend for the Balance Dashboard.

Endpoints:
  GET  /api/cards             Return all cards (supports ?type= filter)
  GET  /api/relics            Return all relics (supports ?rarity= filter)
  GET  /api/equipment         Return all equipment (supports ?slot= filter)
  GET  /api/gems              Return all gems
  GET  /api/skill-tree        Return skill tree data (supports ?tier= filter)
  GET  /api/enemies           Return all enemies (supports ?name= partial match)
  GET  /api/corruption        Return corruption data
  GET  /api/graph             Build and return the React Flow dependency graph
  POST /api/simulate          Accept loadout JSON, run simulator, return results
  POST /api/reload            Re-read JSON files from disk, return fresh data

  Write-back endpoints:
  PATCH  /api/cards/<id>                        Update card fields
  PATCH  /api/relics/<id>                       Update relic fields
  PATCH  /api/equipment/<id>                    Update equipment fields
  PATCH  /api/gems/<id>                         Update gem fields
  PATCH  /api/enemies/<id>                      Update enemy fields
  POST   /api/equipment/<id>/modifiers          Add modifier
  PATCH  /api/equipment/<id>/modifiers/<mod_id> Edit modifier
  DELETE /api/equipment/<id>/modifiers/<mod_id> Remove modifier
  POST   /api/gems/<id>/modifiers               Add modifier
  PATCH  /api/gems/<id>/modifiers/<mod_id>      Edit modifier
  DELETE /api/gems/<id>/modifiers/<mod_id>      Remove modifier
  PUT    /api/enemies/<id>/intents              Replace intent pool
  GET    /api/changelog                         Recent changes
  POST   /api/changelog/undo/<index>            Undo a change

Run with:
  python app.py
"""

import os
from pathlib import Path

from flask import Flask, jsonify, request, send_file, send_from_directory, abort
from flask_cors import CORS

from data_loader import load_all, reload, get_by_id
from simulator import simulate as run_simulate
from graph_builder import build_graph
from tres_writer import (
    update_entity,
    update_modifier,
    add_modifier_to_entity,
    remove_modifier_from_entity,
    update_enemy_intents,
    resolve_tres_path,
    parse_tres_file,
)
from export_from_tres import reexport_entity_type
from change_log import (
    log_change,
    log_modifier_change,
    log_intent_change,
    get_recent as get_recent_changes,
)

app = Flask(__name__)
CORS(app)

# Path to Godot card assets — env vars override for production (Docker/Cloud Run)
_default_card_art = Path(__file__).resolve().parent.parent.parent / "card_game" / "assets" / "cards"
_CARD_ART_ROOT = Path(os.environ.get("CARD_ART_ROOT", str(_default_card_art)))
_CARD_FRAMES_DIR = _CARD_ART_ROOT / "frames"
_CARD_ILLUSTRATIONS_DIR = _CARD_ART_ROOT / "illustrations"

_default_item_art = Path(__file__).resolve().parent.parent.parent / "card_game" / "assets" / "items" / "illustrations"
_ITEM_ART_ROOT = Path(os.environ.get("ITEM_ART_ROOT", str(_default_item_art)))

# Optional: serve built frontend from this directory (production)
_FRONTEND_DIST = os.environ.get("FRONTEND_DIST")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _filter_list(items: list, query_params: dict) -> list:
    """
    Generic key=value filter.  All comparisons are case-insensitive string
    matches against the item's field.  Unknown keys are ignored.
    """
    result = items
    for key, value in query_params.items():
        value_lower = value.lower()
        result = [
            item for item in result
            if str(item.get(key, "")).lower() == value_lower
        ]
    return result


# ---------------------------------------------------------------------------
# Card art routes
# ---------------------------------------------------------------------------

@app.route("/api/card-art/<card_id>", methods=["GET"])
def get_card_art(card_id: str):
    """Serve the base illustration PNG for a card."""
    safe_id = card_id.replace("..", "").replace("/", "").replace("\\", "")
    img_path = _CARD_ILLUSTRATIONS_DIR / safe_id / f"{safe_id}_base.png"
    if not img_path.is_file():
        abort(404)
    return send_file(str(img_path), mimetype="image/png")


@app.route("/api/item-art/<item_id>", methods=["GET"])
def get_item_art(item_id: str):
    """Serve the illustration PNG for an item (equipment, gem, or relic)."""
    safe_id = item_id.replace("..", "").replace("/", "").replace("\\", "")
    img_path = _ITEM_ART_ROOT / safe_id / f"{safe_id}.png"
    if not img_path.is_file():
        abort(404)
    return send_file(str(img_path), mimetype="image/png")


@app.route("/api/card-frame/<frame_type>", methods=["GET"])
def get_card_frame(frame_type: str):
    """Serve a card frame overlay PNG (attack, skill, power, curse)."""
    safe_type = frame_type.replace("..", "").replace("/", "").replace("\\", "")
    img_path = _CARD_FRAMES_DIR / f"frame_{safe_type}.png"
    if not img_path.is_file():
        abort(404)
    return send_file(str(img_path), mimetype="image/png")


# ---------------------------------------------------------------------------
# Data routes
# ---------------------------------------------------------------------------

@app.route("/api/cards", methods=["GET"])
def get_cards():
    data = load_all()
    cards = data.get("cards", [])

    # Supported query param: ?type=attack|skill|power|status|curse
    params = {}
    if request.args.get("type"):
        params["type"] = request.args["type"]

    return jsonify(_filter_list(cards, params))


@app.route("/api/relics", methods=["GET"])
def get_relics():
    data = load_all()
    relics = data.get("relics", [])

    # Supported query param: ?rarity=common|uncommon|rare|boss
    params = {}
    if request.args.get("rarity"):
        params["rarity"] = request.args["rarity"]

    return jsonify(_filter_list(relics, params))


@app.route("/api/equipment", methods=["GET"])
def get_equipment():
    data = load_all()
    equipment = data.get("equipment", [])

    # Supported query param: ?slot=weapon|armor|accessory|boots
    params = {}
    if request.args.get("slot"):
        params["slot"] = request.args["slot"]

    return jsonify(_filter_list(equipment, params))


@app.route("/api/gems", methods=["GET"])
def get_gems():
    data = load_all()
    return jsonify(data.get("gems", []))


@app.route("/api/skill-tree", methods=["GET"])
def get_skill_tree():
    data = load_all()
    skills = data.get("skill_tree", [])

    # Supported query param: ?tier=0|1|2|3
    params = {}
    if request.args.get("tier"):
        params["tier"] = request.args["tier"]

    # skill_tree.json may be a list or a dict with a "skills" key
    if isinstance(skills, dict):
        skill_list = skills.get("skills", [])
        filtered = _filter_list(skill_list, params)
        return jsonify({**skills, "skills": filtered})

    return jsonify(_filter_list(skills, params))


@app.route("/api/enemies", methods=["GET"])
def get_enemies():
    data = load_all()
    enemies = data.get("enemies", [])

    # Supported query param: ?name=<partial match, case-insensitive>
    name_filter = request.args.get("name", "").lower()
    if name_filter:
        enemies = [e for e in enemies if name_filter in e.get("name", "").lower()]

    return jsonify(enemies)


@app.route("/api/corruption", methods=["GET"])
def get_corruption():
    data = load_all()
    return jsonify(data.get("corruption", []))


# ---------------------------------------------------------------------------
# Graph route
# ---------------------------------------------------------------------------

@app.route("/api/graph", methods=["GET"])
def get_graph():
    data = load_all()

    skill_tree = data.get("skill_tree", [])
    if isinstance(skill_tree, dict):
        skill_list = skill_tree.get("skills", [])
    else:
        skill_list = skill_tree

    graph = build_graph(
        cards=data.get("cards", []),
        relics=data.get("relics", []),
        equipment=data.get("equipment", []),
        gems=data.get("gems", []),
        skills=skill_list,
        enemies=data.get("enemies", []),
    )
    return jsonify(graph)


# ---------------------------------------------------------------------------
# Simulate route
# ---------------------------------------------------------------------------

@app.route("/api/simulate", methods=["POST"])
def post_simulate():
    """
    Accept a loadout JSON body and return per-card simulation results.

    Expected body:
    {
        "relics": ["relic_id_1", ...],
        "equipment": {"weapon": "eq_id", "armor": "eq_id", ...},
        "gems": {"card_id": ["gem_id", ...]},
        "skills": ["skill_id", ...],
        "corruption_tier": 0,
        "strength": 0,
        "dexterity": 0,
        "context": {"vulnerable": false, "weak": false}
    }
    """
    loadout = request.get_json(silent=True)
    if not loadout:
        return jsonify({"error": "Invalid or missing JSON body"}), 400

    data = load_all()

    skill_tree = data.get("skill_tree", [])
    if isinstance(skill_tree, dict):
        skill_list = skill_tree.get("skills", [])
    else:
        skill_list = skill_tree

    results = run_simulate(
        loadout=loadout,
        cards=data.get("cards", []),
        relics=data.get("relics", []),
        equipment=data.get("equipment", []),
        gems=data.get("gems", []),
        skills=skill_list,
    )
    return jsonify(results)


# ---------------------------------------------------------------------------
# Reload route
# ---------------------------------------------------------------------------

@app.route("/api/reload", methods=["POST"])
def post_reload():
    """Re-read all JSON files from disk and return the refreshed data."""
    fresh = reload()
    return jsonify({
        "status": "ok",
        "counts": {key: len(val) if isinstance(val, list) else 1
                   for key, val in fresh.items()},
    })


# ---------------------------------------------------------------------------
# Write-back helpers
# ---------------------------------------------------------------------------

def _patch_entity(entity_type: str, entity_id: str):
    """Generic PATCH handler for entity scalar fields."""
    updates = request.get_json(silent=True)
    if not updates:
        return jsonify({"error": "Invalid or missing JSON body"}), 400

    try:
        # Get old values for changelog
        data = load_all()
        entities = data.get(entity_type, [])
        old_entity = get_by_id(entities, entity_id)

        backup_path = update_entity(entity_type, entity_id, updates)

        # Log each field change
        for field, new_val in updates.items():
            old_val = old_entity.get(field) if old_entity else None
            log_change(entity_type, entity_id, field, old_val, new_val,
                       str(backup_path))

        # Re-export and reload
        reexport_entity_type(entity_type)
        reload()

        # Return updated entity
        fresh = load_all()
        updated = get_by_id(fresh.get(entity_type, []), entity_id)
        return jsonify(updated)

    except (ValueError, FileNotFoundError) as exc:
        return jsonify({"error": str(exc)}), 400
    except Exception as exc:
        return jsonify({"error": f"Internal error: {exc}"}), 500


# ---------------------------------------------------------------------------
# Write-back routes: Entity PATCH
# ---------------------------------------------------------------------------

@app.route("/api/cards/<entity_id>", methods=["PATCH"])
def patch_card(entity_id: str):
    return _patch_entity("cards", entity_id)


@app.route("/api/relics/<entity_id>", methods=["PATCH"])
def patch_relic(entity_id: str):
    return _patch_entity("relics", entity_id)


@app.route("/api/equipment/<entity_id>", methods=["PATCH"])
def patch_equipment(entity_id: str):
    return _patch_entity("equipment", entity_id)


@app.route("/api/gems/<entity_id>", methods=["PATCH"])
def patch_gem(entity_id: str):
    return _patch_entity("gems", entity_id)


@app.route("/api/enemies/<entity_id>", methods=["PATCH"])
def patch_enemy(entity_id: str):
    return _patch_entity("enemies", entity_id)


# ---------------------------------------------------------------------------
# Write-back routes: Modifier CRUD (equipment + gems)
# ---------------------------------------------------------------------------

@app.route("/api/equipment/<entity_id>/modifiers", methods=["POST"])
@app.route("/api/gems/<entity_id>/modifiers", methods=["POST"])
def add_modifier(entity_id: str):
    entity_type = "gems" if "/gems/" in request.path else "equipment"
    body = request.get_json(silent=True)
    if not body:
        return jsonify({"error": "Invalid or missing JSON body"}), 400

    mod_id = body.pop("id", None)
    if not mod_id:
        return jsonify({"error": "Modifier 'id' is required"}), 400

    try:
        backup = add_modifier_to_entity(entity_type, entity_id, mod_id, body)
        log_modifier_change("add", entity_type, entity_id, mod_id, body,
                            str(backup))
        reexport_entity_type(entity_type)
        reload()

        fresh = load_all()
        updated = get_by_id(fresh.get(entity_type, []), entity_id)
        return jsonify(updated), 201

    except (ValueError, FileNotFoundError) as exc:
        return jsonify({"error": str(exc)}), 400
    except Exception as exc:
        return jsonify({"error": f"Internal error: {exc}"}), 500


@app.route("/api/equipment/<entity_id>/modifiers/<mod_id>", methods=["PATCH"])
@app.route("/api/gems/<entity_id>/modifiers/<mod_id>", methods=["PATCH"])
def edit_modifier(entity_id: str, mod_id: str):
    entity_type = "gems" if "/gems/" in request.path else "equipment"
    updates = request.get_json(silent=True)
    if not updates:
        return jsonify({"error": "Invalid or missing JSON body"}), 400

    try:
        backup = update_modifier(entity_type, entity_id, mod_id, updates)
        log_modifier_change("edit", entity_type, entity_id, mod_id, updates,
                            str(backup))
        reexport_entity_type(entity_type)
        reload()

        fresh = load_all()
        updated = get_by_id(fresh.get(entity_type, []), entity_id)
        return jsonify(updated)

    except (ValueError, FileNotFoundError) as exc:
        return jsonify({"error": str(exc)}), 400
    except Exception as exc:
        return jsonify({"error": f"Internal error: {exc}"}), 500


@app.route("/api/equipment/<entity_id>/modifiers/<mod_id>", methods=["DELETE"])
@app.route("/api/gems/<entity_id>/modifiers/<mod_id>", methods=["DELETE"])
def delete_modifier(entity_id: str, mod_id: str):
    entity_type = "gems" if "/gems/" in request.path else "equipment"

    try:
        backup = remove_modifier_from_entity(entity_type, entity_id, mod_id)
        log_modifier_change("delete", entity_type, entity_id, mod_id,
                            backup_path=str(backup))
        reexport_entity_type(entity_type)
        reload()

        fresh = load_all()
        updated = get_by_id(fresh.get(entity_type, []), entity_id)
        return jsonify(updated)

    except (ValueError, FileNotFoundError) as exc:
        return jsonify({"error": str(exc)}), 400
    except Exception as exc:
        return jsonify({"error": f"Internal error: {exc}"}), 500


# ---------------------------------------------------------------------------
# Write-back routes: Enemy intent pool
# ---------------------------------------------------------------------------

@app.route("/api/enemies/<entity_id>/intents", methods=["PUT"])
def put_intents(entity_id: str):
    intents = request.get_json(silent=True)
    if not isinstance(intents, list):
        return jsonify({"error": "Body must be an array of intent objects"}), 400

    try:
        # Get old intents for changelog
        data = load_all()
        old_enemy = get_by_id(data.get("enemies", []), entity_id)
        old_intents = old_enemy.get("intent_pool", []) if old_enemy else []

        backup = update_enemy_intents(entity_id, intents)
        log_intent_change(entity_id, old_intents, intents, str(backup))
        reexport_entity_type("enemies")
        reload()

        fresh = load_all()
        updated = get_by_id(fresh.get("enemies", []), entity_id)
        return jsonify(updated)

    except (ValueError, FileNotFoundError) as exc:
        return jsonify({"error": str(exc)}), 400
    except Exception as exc:
        return jsonify({"error": f"Internal error: {exc}"}), 500


# ---------------------------------------------------------------------------
# Changelog routes
# ---------------------------------------------------------------------------

@app.route("/api/changelog", methods=["GET"])
def get_changelog():
    limit = request.args.get("limit", 100, type=int)
    return jsonify(get_recent_changes(limit))


# ---------------------------------------------------------------------------
# SPA static file serving (production)
# ---------------------------------------------------------------------------

if _FRONTEND_DIST:
    _dist = Path(_FRONTEND_DIST)

    @app.route("/", defaults={"path": ""})
    @app.route("/<path:path>")
    def serve_frontend(path: str):
        # Serve actual static files (JS, CSS, images, etc.)
        full = _dist / path
        if path and full.is_file():
            return send_from_directory(str(_dist), path)
        # SPA fallback — serve index.html for all other routes
        return send_from_directory(str(_dist), "index.html")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    app.run(port=5000, debug=True)
