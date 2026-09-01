#!/usr/bin/env bash
# pi-gateway-doctor.sh -- audit + fix Pi's AI Gateway routing on this machine.
#
# Context (2026-07-27, PHYREXIA incident): a Pi update added the new Claude
# models to the ANTHROPIC provider's catalog. Any machine that (a) exports an
# Anthropic-shaped env var (ANTHROPIC_AUTH_TOKEN / ANTHROPIC_API_KEY) that
# does NOT hold a real Anthropic-direct credential, or (b) has an unqualified
# defaultModel in ~/.pi/agent/settings.json, can resolve new sessions to
# anthropic-direct and die with:
#   401 {"type":"error","error":{"type":"authentication_error",
#        "message":"Invalid bearer token"}}
#
# This script is idempotent and machine-agnostic (PHYREXIA already fixed by
# hand; primary audience is CHAOS and future hosts). It:
#   1. verifies the dotfiles claude() wrapper is present (gateway routing is
#      per-invocation now, never global env)
#   2. audits shell env / tmux global env / local rc files for
#      Anthropic-shaped exports and (with --apply) purges the tmux globals
#   3. pins defaultProvider + provider-qualified defaultModel in Pi settings
#   4. registers the gateway in Pi's auth.json via env interpolation
#      (no secret material written to disk)
#   5. smoke-tests a fresh non-interactive Pi session
#
# Usage:
#   pi-gateway-doctor.sh              # dry-run: report only
#   pi-gateway-doctor.sh --apply     # apply fixes + smoke test
#
# Tunables (env or flags):
#   --provider <id>      target provider        (default: vercel-ai-gateway)
#   --model <id>         provider-local model id (default: anthropic/claude-fable-5.1)
#   --gateway-env <VAR>  env var holding the gateway key (default: AI_GATEWAY_API_KEY)

set -euo pipefail

PROVIDER="${PROVIDER:-vercel-ai-gateway}"
MODEL="${MODEL:-anthropic/claude-fable-5.1}"
GATEWAY_ENV="${GATEWAY_ENV:-AI_GATEWAY_API_KEY}"
APPLY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply) APPLY=1 ;;
        --provider) PROVIDER="$2"; shift ;;
        --model) MODEL="$2"; shift ;;
        --gateway-env) GATEWAY_ENV="$2"; shift ;;
        -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
        *) echo "[ERROR] unknown arg: $1" >&2; exit 1 ;;
    esac
    shift
done

PI_DIR="${PI_AGENT_DIR:-$HOME/.pi/agent}"
SETTINGS="$PI_DIR/settings.json"
AUTH="$PI_DIR/auth.json"
MODE_LABEL="dry-run"; [[ $APPLY -eq 1 ]] && MODE_LABEL="apply"
FAILS=0
ADVISORIES=0

echo "[INFO] pi-gateway-doctor ($MODE_LABEL) host=$(hostname -s) provider=$PROVIDER model=$MODEL key-env=\$$GATEWAY_ENV"

# --- 1. dotfiles wrapper present -------------------------------------------
if grep -q "CLAUDE_GATEWAY_TOKEN" "$HOME/.dotfiles/bash/.bash_ai" 2>/dev/null; then
    echo "[OK]   1/5 dotfiles: claude() gateway wrapper present (.bash_ai)"
else
    echo "[WARN] 1/5 dotfiles: wrapper missing -- run: cd ~/.dotfiles && git pull"
    FAILS=$((FAILS + 1))
fi

# --- 2. Anthropic-shaped env audit ------------------------------------------
POISON=0
for v in ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_BASE_URL; do
    if [[ -n "${!v:-}" ]]; then
        echo "[WARN] 2/5 env: $v is set in this shell (Pi will treat anthropic-direct as authed)"
        POISON=1
        ADVISORIES=$((ADVISORIES + 1))
    fi
done
if command -v tmux &>/dev/null && tmux info &>/dev/null; then
    TMUX_HITS=$(tmux show-environment -g 2>/dev/null | grep -cE "^ANTHROPIC" || true)
    if [[ "$TMUX_HITS" -gt 0 ]]; then
        echo "[WARN] 2/5 tmux: $TMUX_HITS ANTHROPIC_* var(s) in global env (new panes inherit)"
        POISON=1
        if [[ $APPLY -eq 1 ]]; then
            for v in ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_BASE_URL; do
                tmux set-environment -gr "$v" 2>/dev/null || true
            done
            echo "[OK]   2/5 tmux: purged ANTHROPIC_* from global env"
        fi
    fi
fi
RC_HITS=$(grep -rln "export ANTHROPIC" "$HOME/.bashrc.local" "$HOME/.bash_exports.local" \
    "$HOME/.profile.local" 2>/dev/null || true)
if [[ -n "$RC_HITS" ]]; then
    echo "[WARN] 2/5 rc: Anthropic exports found in local rc file(s) -- fix by hand (scope to a wrapper):"
    echo "$RC_HITS" | sed 's/^/       /'
    FAILS=$((FAILS + 1))
fi
[[ $POISON -eq 0 && -z "$RC_HITS" ]] && echo "[OK]   2/5 env: no Anthropic-shaped exports found"

# --- 3. Pi settings: pinned provider-qualified default ----------------------
if [[ ! -f "$SETTINGS" ]]; then
    echo "[WARN] 3/5 settings: $SETTINGS missing -- is Pi installed/run on this host?"
    FAILS=$((FAILS + 1))
else
    NEED=$(python3 - "$SETTINGS" "$PROVIDER" "$MODEL" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
ok = d.get("defaultProvider") == sys.argv[2] and d.get("defaultModel") == sys.argv[3]
print("ok" if ok else "fix")
PY
)
    if [[ "$NEED" == "ok" ]]; then
        echo "[OK]   3/5 settings: defaultProvider/defaultModel already pinned"
    elif [[ $APPLY -eq 1 ]]; then
        cp "$SETTINGS" "$SETTINGS.bak"
        python3 - "$SETTINGS" "$PROVIDER" "$MODEL" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["defaultProvider"] = sys.argv[2]
d["defaultModel"] = sys.argv[3]
json.dump(d, open(p, "w"), indent=2)
PY
        echo "[OK]   3/5 settings: pinned (backup at $SETTINGS.bak)"
    else
        echo "[WARN] 3/5 settings: would pin defaultProvider=$PROVIDER defaultModel=$MODEL"
    fi
fi

# --- 4. Pi auth.json: a usable gateway credential exists ---------------------
# Hosts differ legitimately: PHYREXIA interpolates "$AI_GATEWAY_API_KEY" from
# op-injected env; CHAOS (no op) stores a literal key via /login -- auth.json
# is Pi's source of truth either way. Accept any usable entry; only fall back
# to requiring the env var when nothing is configured at all.
STATE=$(python3 - "$AUTH" "$PROVIDER" <<'PY'
import json, sys, os
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    d = {}
cur = d.get(sys.argv[2], {})
key = cur.get("key", "")
if not cur:
    print("missing")
elif cur.get("type") != "api_key":
    print("other")  # oauth or future types -- assume pi manages it
elif key.startswith("$"):
    print("env-ok" if os.environ.get(key[1:]) else "env-dangling:" + key[1:])
elif key:
    print("literal")
else:
    print("missing")
PY
)
case "$STATE" in
    literal)
        echo "[OK]   4/5 auth: $PROVIDER has a stored key in auth.json (via /login) -- nothing to do" ;;
    other)
        echo "[OK]   4/5 auth: $PROVIDER has a non-api_key credential (pi-managed) -- nothing to do" ;;
    env-ok)
        echo "[OK]   4/5 auth: $PROVIDER registered (env-interpolated, no secret on disk)" ;;
    env-dangling:*)
        echo "[WARN] 4/5 auth: $PROVIDER interpolates \$${STATE#env-dangling:} but that var is unset"
        echo "       in this shell -- fix the env or /login a literal key"
        FAILS=$((FAILS + 1)) ;;
    missing)
        if [[ -z "${!GATEWAY_ENV:-}" ]]; then
            echo "[WARN] 4/5 auth: no $PROVIDER credential in auth.json and \$$GATEWAY_ENV is not set --"
            echo "       either run /login inside pi (stores a literal key), or re-run with"
            echo "       --gateway-env <VAR> naming the env var this host uses (nothing written)"
            FAILS=$((FAILS + 1))
        elif [[ $APPLY -eq 1 ]]; then
            [[ -f "$AUTH" ]] && cp "$AUTH" "$AUTH.bak"
            python3 - "$AUTH" "$PROVIDER" "$GATEWAY_ENV" <<'PY'
import json, sys
p = sys.argv[1]
try:
    d = json.load(open(p))
except Exception:
    d = {}
d[sys.argv[2]] = {"type": "api_key", "key": "$" + sys.argv[3]}
json.dump(d, open(p, "w"), indent=2)
PY
            chmod 600 "$AUTH"
            echo "[OK]   4/5 auth: registered $PROVIDER -> \$$GATEWAY_ENV (backup at $AUTH.bak)"
        else
            echo "[WARN] 4/5 auth: would register $PROVIDER -> \$$GATEWAY_ENV in $AUTH"
        fi ;;
esac

# --- 5. smoke test -----------------------------------------------------------
if [[ $APPLY -eq 1 ]]; then
    if ! command -v pi &>/dev/null; then
        echo "[WARN] 5/5 smoke: pi not on PATH -- skipped"
        FAILS=$((FAILS + 1))
    else
        echo "[INFO] 5/5 smoke: running a fresh non-interactive session..."
        RESULT=$(env -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_API_KEY -u ANTHROPIC_BASE_URL \
            pi -p --mode json --no-session "Reply with exactly: OK" 2>&1 | python3 -c "
import json, sys
provider = model = None
for line in sys.stdin:
    try:
        d = json.loads(line.strip())
    except Exception:
        continue
    m = d.get('message', {})
    if isinstance(m, dict) and m.get('model'):
        provider, model = m.get('provider'), m.get('model')
        break
print(f'{provider} / {model}' if provider else 'no-model-resolved')
" || true)
        if [[ "$RESULT" == "$PROVIDER / $MODEL" ]]; then
            echo "[OK]   5/5 smoke: session used $RESULT"
        else
            echo "[ERROR] 5/5 smoke: session used '$RESULT' (expected '$PROVIDER / $MODEL')"
            FAILS=$((FAILS + 1))
        fi
    fi
else
    echo "[INFO] 5/5 smoke: skipped in dry-run (runs with --apply)"
fi

# --- summary -----------------------------------------------------------------
if [[ $FAILS -eq 0 ]]; then
    if [[ $ADVISORIES -gt 0 ]]; then
        echo "[DONE] no blocking issues ($MODE_LABEL), $ADVISORIES advisory warning(s):"
        echo "       this shell's own env predates the fix -- unset the ANTHROPIC_* vars"
        echo "       here or use a fresh shell/pane; the doctor cannot fix its parent."
    else
        echo "[DONE] all checks green ($MODE_LABEL). Note: shells/panes opened before"
        echo "       any tmux purge keep their env until they cycle."
    fi
else
    echo "[DONE] $FAILS item(s) need attention (see WARN/ERROR above)."
    exit 1
fi
