#!/bin/bash

echo "=== THA Coolify Diagnostics ==="
echo

echo "1. Checking DNS resolution..."
domains=(
    # Removed dw.thehockeyanalytics.com (ClickHouse decommissioned)
    "analytics.thehockeyanalytics.com"
    "coolify.theunnamedroads.com"
)

for domain in "${domains[@]}"; do
    echo -n "  $domain: "
    if nslookup "$domain" >/dev/null 2>&1; then
        echo "✅ Resolves"
    else
        echo "❌ DNS issue"
    fi
done

echo
echo "2. Checking HTTPS connectivity..."
for domain in "${domains[@]}"; do
    echo -n "  https://$domain: "
    if curl -I -s --max-time 10 "https://$domain" >/dev/null 2>&1; then
        echo "✅ Reachable"
    else
        echo "❌ Not reachable"
    fi
done

echo
echo "3. Checking server resources..."
echo -n "  Server ping: "
if ping -c 1 46.62.206.47 >/dev/null 2>&1; then
    echo "✅ Server responding"
else
    echo "❌ Server not responding"
fi

echo
echo "4. Checking Coolify..."
echo -n "  Coolify web: "
if curl -I -s --max-time 10 "https://coolify.theunnamedroads.com" >/dev/null 2>&1; then
    echo "✅ Working"
else
    echo "❌ Not working"
fi

echo
echo "=== Summary ==="
echo "All green ✅ = Everything working"
echo "Any red ❌ = Needs attention"