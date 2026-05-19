#!/bin/bash
# Build ทั้ง 3 วิธี แล้วตรวจว่า token หลุดเข้า image หรือไม่
set -euo pipefail

cd "$(dirname "$0")/app"

TOKEN_VALUE=$(cat token.txt | tr -d '\n')

build_and_inspect() {
    local name=$1 file=$2
    shift 2
    local tag="lab-secret-${name}:test"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "🔧 Building: $file → $tag"
    echo "════════════════════════════════════════════════════════════════"
    docker build -f "$file" -t "$tag" "$@" . >/dev/null 2>&1

    echo ""
    echo "── docker history (มองหา token leak) ──"
    if docker history --no-trunc "$tag" | grep -q "$TOKEN_VALUE"; then
        echo "❌ LEAK: เจอ token ใน history!"
        docker history --no-trunc "$tag" | grep -o "ghp_[A-Za-z0-9_]*" | head -3 | sed 's/^/   /'
    else
        echo "✅ ไม่เจอ token ใน history"
    fi

    echo ""
    echo "── ค้นในทุก layer ของ image (extract image → walk layers) ──"
    local tmpdir; tmpdir=$(mktemp -d)
    docker save "$tag" -o "$tmpdir/img.tar"
    ( cd "$tmpdir" && tar xf img.tar )
    local found=""
    for blob in "$tmpdir"/blobs/sha256/*; do
        # แต่ละ blob เป็น tar.gz (layer) หรือ JSON metadata — ลอง extract แล้ว grep
        if tar tzf "$blob" >/dev/null 2>&1; then
            if tar xzf "$blob" -O 2>/dev/null | grep -aq "$TOKEN_VALUE"; then
                found="$blob"
                break
            fi
        fi
    done
    if [ -n "$found" ]; then
        echo "❌ LEAK: เจอ token ใน layer $(basename "$found")"
        echo "   ไฟล์ที่มี token: $(tar tzf "$found" 2>/dev/null | grep -v '/$' | head -5)"
    else
        echo "✅ ไม่เจอ token ใน image layers"
    fi
    rm -rf "$tmpdir"
}

# ── 1) bad: ส่งผ่าน ARG ─────────────────────────────────────────────────────
build_and_inspect "bad-arg" "Dockerfile.bad-arg" --build-arg "GITHUB_TOKEN=$TOKEN_VALUE"

# ── 2) bad: COPY ไฟล์ ───────────────────────────────────────────────────────
build_and_inspect "bad-copy" "Dockerfile.bad-copy"

# ── 3) good: --mount=type=secret ────────────────────────────────────────────
build_and_inspect "good" "Dockerfile.good" --secret "id=github_token,src=$(pwd)/token.txt"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "สรุป: เฉพาะวิธี #3 (mount=type=secret) เท่านั้นที่ปลอดภัย"
echo "════════════════════════════════════════════════════════════════"
