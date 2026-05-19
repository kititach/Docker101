#!/bin/sh
echo "=== Container Identity ==="
id
echo ""
echo "=== Sensitive Files Write Tests ==="
printf "Write to /etc/passwd:  "
echo "x" >> /etc/passwd 2>/dev/null && echo "YES (danger!)" || echo "no (safe)"

printf "Write to /etc/shadow:  "
echo "x" >> /etc/shadow 2>/dev/null && echo "YES (danger!)" || echo "no (safe)"

printf "Modify /bin/sh:        "
echo "x" >> /bin/sh 2>/dev/null && echo "YES (danger!)" || echo "no (safe)"

printf "Write to /tmp:         "
echo "x" > /tmp/test 2>/dev/null && echo "yes (expected)" || echo "no"

echo ""
echo "=== Privileged Operations ==="
printf "apk add curl:          "
apk add --no-cache curl >/dev/null 2>&1 && echo "YES (root)" || echo "no (unprivileged)"

printf "Bind to port 80:       "
nc -l -p 80 -e /bin/sh </dev/null >/dev/null 2>&1 &
PID=$!
sleep 0.3
if kill -0 $PID 2>/dev/null; then
  echo "YES"
  kill $PID 2>/dev/null
else
  echo "no (port < 1024 needs privilege)"
fi
