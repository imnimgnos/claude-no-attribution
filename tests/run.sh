#!/usr/bin/env bash
# 실제 서버에 붙지 않고 가짜 ssh · 가짜 홈 폴더로 claude-no-attribution을 시험한다.
#   가짜 호스트: h1(바꿀 곳) · h2(이미 적용) · h3(Claude Code 없음) · bad(깨진 JSON) · auth(키 거부) · down(접속 안 됨)
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
TOOL="$HERE/../claude-no-attribution"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
export HOME="$W/home" FAKEROOT="$W/hosts" PATH="$HERE/fake-bin:$PATH"
unset CLAUDE_CONFIG_DIR
chmod +x "$HERE/fake-bin/ssh" "$TOOL"

pass=0 fail=0
check() { local d=$1; shift; if "$@"; then pass=$((pass + 1)); echo "  통과  $d"; else fail=$((fail + 1)); echo "  실패  $d"; fi; }
has() { printf '%s\n' "$1" | grep -qE -- "$2"; }
# json 파일 확인식: 식은 이 시험 파일에 고정으로 적은 것만 넘긴다(외부 입력 없음)
json() { python3 - "$1" "$2" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
sys.exit(0 if eval(sys.argv[2]) else 1)
PY
}
OFF='{"sessionUrl": False, "commit": "", "pr": ""}'

mkdir -p "$HOME/.claude" "$HOME/.ssh" "$FAKEROOT/h1/.claude" "$FAKEROOT/h2/.claude" "$FAKEROOT/h3" "$FAKEROOT/bad/.claude" "$W/repo"
printf '{"theme":"dark","includeCoAuthoredBy":true,"attribution":{"commit":"made with care"}}\n' > "$HOME/.claude/settings.json"
printf 'Host h1 h2 h3 bad auth down\n  User u\nHost *\n  ServerAliveInterval 30\n' > "$HOME/.ssh/config"
printf '{"model":"opus"}\n' > "$FAKEROOT/h1/.claude/settings.json"
printf '{"attribution":{"sessionUrl":false,"commit":"","pr":""},"includeCoAuthoredBy":false}\n' > "$FAKEROOT/h2/.claude/settings.json"
printf '{"model": oops}\n' > "$FAKEROOT/bad/.claude/settings.json"

echo "== 터미널 없이 옵션 없음"
"$TOOL" >/dev/null 2>&1; rc=$?
check "터미널 없이 -y · -n 없으면 멈춘다(exit 2)" [ "$rc" = 2 ]

echo "== 미리보기(-n)"
out=$("$TOOL" -n 2>&1)
check "이 컴퓨터는 바꿀 예정" has "$out" "바꿀 예정"
check "미리보기는 아무것도 바꾸지 않는다" json "$HOME/.claude/settings.json" 'd["includeCoAuthoredBy"] is True'
check "h1 = 바꿀 곳" has "$out" 'h1 +\[바꿀 곳\]'
check "h2 = 이미 적용" has "$out" 'h2 +\[이미 적용\]'
check "h3 = Claude Code 없음" has "$out" 'h3 +\[Claude Code 없음\]'
check "bad = 오류(깨진 JSON)" has "$out" 'bad +\[오류\]'
check "auth = 키로 접속 안 됨" has "$out" 'auth +\[키로 접속 안 됨\]'
check "down = 접속 안 됨" has "$out" 'down +\[접속 안 됨\]'

echo "== 적용(-y)"
out=$("$TOOL" -y --project "$W/repo" 2>&1); rc=$?
check "exit 0" [ "$rc" = 0 ]
check "이 컴퓨터: 두 설정이 꺼지고 다른 설정은 그대로" json "$HOME/.claude/settings.json" "d['attribution'] == $OFF and d['includeCoAuthoredBy'] is False and d['theme'] == 'dark'"
check "이 컴퓨터: 원본 백업" json "$HOME/.claude/settings.json.bak-attribution" "d['attribution'] == {'commit': 'made with care'}"
check "h1: 적용되고 model은 그대로" json "$FAKEROOT/h1/.claude/settings.json" "d['attribution'] == $OFF and d['model'] == 'opus'"
check "h1: 원본 백업" test -f "$FAKEROOT/h1/.claude/settings.json.bak-attribution"
check "h2: 그대로(백업도 없음)" test ! -e "$FAKEROOT/h2/.claude/settings.json.bak-attribution"
check "h3: .claude를 만들지 않음" test ! -e "$FAKEROOT/h3/.claude"
check "bad: 깨진 파일을 건드리지 않음" grep -q oops "$FAKEROOT/bad/.claude/settings.json"
check "저장소: .claude/settings.json을 만듦" json "$W/repo/.claude/settings.json" "d['attribution'] == $OFF"
check "바꾼 곳 3곳(이 컴퓨터 · h1 · 저장소)" has "$out" "바꾼 곳 3곳"

echo "== 다시(-y)"
out=$("$TOOL" -y --project "$W/repo" 2>&1)
check "두 번째는 바꾼 곳 0곳" has "$out" "바꾼 곳 0곳"
check "이 컴퓨터: 이미 적용됨" has "$out" "이미 적용됨"

echo "== CLAUDE_CONFIG_DIR"
mkdir -p "$W/alt"; printf '{}\n' > "$W/alt/settings.json"
CLAUDE_CONFIG_DIR="$W/alt" "$TOOL" -y --no-ssh >/dev/null 2>&1
check "CLAUDE_CONFIG_DIR의 settings.json에 적용" json "$W/alt/settings.json" "d['attribution'] == $OFF"

echo ""
echo "통과 $pass · 실패 $fail"
[ "$fail" -eq 0 ]
