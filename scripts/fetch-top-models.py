#!/usr/bin/env python3
"""Fetch the 5 newest models from Anthropic, OpenAI, and Google from OpenRouter
and emit them in the same shape as config/models.json.example so the install
scripts' existing merge logic picks them up.

Usage:
    fetch-top-models.py <output-json-path>

Writes a JSON file with:
    {
      "models": { "<model-id>": { ...entry... }, ... 15 entries ... }
    }

Prints to stdout (for shell `eval` / source):
    DEFAULT_MODEL=<latest claude-sonnet id>
    DEFAULT_MODEL_DISPLAY=<display name>

Stdlib only — no pip dependencies so the install sandbox is preserved.
"""
import json
import sys
import urllib.request

OPENROUTER_URL = 'https://openrouter.ai/api/v1/models'
FAMILIES = ['anthropic', 'openai', 'google']
PER_FAMILY = 5
FETCH_TIMEOUT = 15
# The default model is STATIC — Claude Sonnet 4.6. We don't auto-discover the
# "newest sonnet" because that can drift to a model that isn't yet production-
# ready or that hasn't propagated to OpenRouter yet. If the fetch succeeds, we
# still force the default to this ID (and guarantee it's in the loaded models
# map). If the fetch fails, we fall back to just this one model.
DEFAULT_MODEL_ID = 'anthropic/claude-sonnet-4.6'
DEFAULT_MODEL_DISPLAY = 'Claude Sonnet 4.6'


def make_entry(display_name):
    return {
        'name': display_name,
        'tool_call': True,
        'attachment': True,
        'modalities': {'input': ['text', 'image'], 'output': ['text']},
        'options': {
            'temperature': 0.7,
            'top_p': 0.95,
            'max_tokens': 16384,
            'parallel_tool_calls': False,
        },
    }


def fetch_models():
    req = urllib.request.Request(
        OPENROUTER_URL,
        headers={'Accept': 'application/json'},
    )
    with urllib.request.urlopen(req, timeout=FETCH_TIMEOUT) as response:
        payload = json.loads(response.read())
    data = payload.get('data') or []
    return data if isinstance(data, list) else []


def pick_top(all_models):
    by_family = {f: [] for f in FAMILIES}
    for model in all_models:
        model_id = model.get('id') or ''
        for family in FAMILIES:
            if model_id.startswith(family + '/'):
                by_family[family].append(model)
                break

    for family in FAMILIES:
        by_family[family].sort(key=lambda m: m.get('created') or 0, reverse=True)

    return by_family


def main():
    if len(sys.argv) < 2:
        print('usage: fetch-top-models.py <output-json-path>', file=sys.stderr)
        return 2

    out_path = sys.argv[1]
    models = {}

    try:
        all_models = fetch_models()
    except Exception as error:  # noqa: BLE001 — best-effort during install
        print(f'WARN: OpenRouter fetch failed ({error}); shipping static default only', file=sys.stderr)
        # Guarantee the static default is present even if the API is down.
        models[DEFAULT_MODEL_ID] = make_entry(DEFAULT_MODEL_DISPLAY)
        with open(out_path, 'w') as fh:
            json.dump({'models': models}, fh, indent=2)
        print(f'DEFAULT_MODEL={DEFAULT_MODEL_ID}')
        print(f'DEFAULT_MODEL_DISPLAY={DEFAULT_MODEL_DISPLAY}')
        return 0

    by_family = pick_top(all_models)

    # Take top 5 from each family.
    for family in FAMILIES:
        for model in by_family[family][:PER_FAMILY]:
            model_id = model.get('id')
            if not model_id:
                continue
            display = model.get('name') or model_id
            models[model_id] = make_entry(display)

    # Force the default into the models map even if it wasn't in the top 5 of
    # its family. This is the one model we KNOW the app needs to resolve, so we
    # accept an extra entry to guarantee the picker's default state is valid.
    if DEFAULT_MODEL_ID not in models:
        # Try to find a richer display name from OpenRouter's catalog.
        display = DEFAULT_MODEL_DISPLAY
        for model in all_models:
            if model.get('id') == DEFAULT_MODEL_ID:
                display = model.get('name') or DEFAULT_MODEL_DISPLAY
                break
        models[DEFAULT_MODEL_ID] = make_entry(display)

    with open(out_path, 'w') as fh:
        json.dump({'models': models}, fh, indent=2)

    print(f'OK: wrote {len(models)} models to {out_path} (default={DEFAULT_MODEL_ID})', file=sys.stderr)
    print(f'DEFAULT_MODEL={DEFAULT_MODEL_ID}')
    print(f'DEFAULT_MODEL_DISPLAY={DEFAULT_MODEL_DISPLAY}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
