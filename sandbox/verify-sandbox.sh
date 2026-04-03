#!/bin/sh
# Verify the sandbox is working correctly.
# Run this after `docker compose -f sandbox/docker-compose.sandbox.yml up -d`
#
# It exec's into the copilot-api container and attempts connections that
# should succeed (GitHub) and should fail (example.com, httpbin, etc.)

set -e

COMPOSE_FILE="sandbox/docker-compose.sandbox.yml"
CONTAINER="copilot-api"

echo "=== Sandbox Verification ==="
echo ""

# Helper: run a command inside the copilot-api container
run_in_container() {
  docker compose -f "$COMPOSE_FILE" exec -T "$CONTAINER" sh -c "$1" 2>&1
}

pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; }
fail() { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; }

echo "--- Connections that SHOULD SUCCEED ---"

# Test allowed domain via proxy
if run_in_container "wget -q -O /dev/null --timeout=5 https://api.github.com/zen" >/dev/null 2>&1; then
  pass "api.github.com (allowed)"
else
  fail "api.github.com (allowed) -- should have succeeded"
fi

echo ""
echo "--- Connections that SHOULD FAIL ---"

# Test direct connection (bypass proxy) -- should fail because network is internal
if run_in_container "wget -q -O /dev/null --timeout=5 --no-proxy https://example.com" >/dev/null 2>&1; then
  fail "direct to example.com (no proxy) -- should have been blocked"
else
  pass "direct to example.com blocked (internal network working)"
fi

# Test disallowed domain through proxy
if run_in_container "wget -q -O /dev/null --timeout=5 https://httpbin.org/get" >/dev/null 2>&1; then
  fail "httpbin.org via proxy -- should have been blocked by squid"
else
  pass "httpbin.org blocked by squid allowlist"
fi

# Test disallowed domain through proxy
if run_in_container "wget -q -O /dev/null --timeout=5 https://evil-exfil.example.com" >/dev/null 2>&1; then
  fail "evil-exfil.example.com -- should have been blocked"
else
  pass "evil-exfil.example.com blocked"
fi

echo ""
echo "--- Summary ---"
echo "If all tests show PASS, the sandbox is working correctly."
echo "The copilot-api container can ONLY reach GitHub/Copilot/Anthropic endpoints."
