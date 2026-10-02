# claude-no-attribution

Claude Code가 git 커밋 · PR에 붙이는 표시를 **한 번에 끄는 대화형 스크립트**입니다.
이 컴퓨터, SSH로 붙는 서버들, 저장소(클라우드 세션용)까지 차례로 물어 가며 적용합니다.

| 끄는 것 | 예 | 바꾸는 설정 |
|---|---|---|
| 공동 작성자 줄 | `Co-Authored-By: Claude …`, `Generated with Claude Code` | `attribution.commit = ""`, `attribution.pr = ""` + 옛 버전용 `includeCoAuthoredBy = false` |
| 세션 링크 | 커밋의 `Claude-Session: https://claude.ai/code/session_…`, PR 끝의 링크 | `attribution.sessionUrl = false` |

공식 설정 설명: [Claude Code settings · attribution](https://code.claude.com/docs/en/settings)

## 설치

```bash
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/imnimgnos/claude-no-attribution/main/claude-no-attribution -o ~/.local/bin/claude-no-attribution
chmod +x ~/.local/bin/claude-no-attribution
```

또는 저장소째:

```bash
git clone https://github.com/imnimgnos/claude-no-attribution.git
install -m 755 claude-no-attribution/claude-no-attribution ~/.local/bin/
```

`~/.local/bin`이 PATH에 없다면 PATH에 있는 다른 폴더(예: `/usr/local/bin`)에 두거나 저장소 안에서 `./claude-no-attribution`으로 실행하세요.

## 쓰는 법

```bash
claude-no-attribution          # 차례로 물어 가며 적용
claude-no-attribution -n       # 미리보기(아무것도 바꾸지 않음)
```

대화 순서:

1. **이 컴퓨터**: 지금 상태를 보여 주고 적용할지 묻습니다.
2. **SSH 호스트**: `~/.ssh/config`(Include 포함)에서 호스트를 모아(같은 곳을 가리키는 별칭은 하나로) 키로 바로 붙는지, Claude Code(`~/.claude`)가 있는지, 지금 상태가 어떤지를 병렬로 점검해 번호 붙은 표로 보여 줍니다.
   ```
     1  build-server         [바꿀 곳] build-01: 바꿀 예정 · attribution null -> {...}
     2  gpu-box              [이미 적용] gpu-01: 이미 적용됨
     3  db-01                [Claude Code 없음] db-01: /home/me/.claude 없음
     4  old-server           [키로 접속 안 됨] me@10.0.0.4: Permission denied (publickey,password).
     5  vpn-only             [접속 안 됨] ssh: connect to host … Operation timed out
   ```
   - 바꿀 곳 중 적용할 번호를 고릅니다(엔터 = 전부).
   - 키로 못 붙은 곳은 원하면 **비밀번호로 시도**합니다(접속을 다시 써서 호스트당 한 번만 묻습니다).
   - 목록에 없는 호스트도 `user@host` 또는 `user@host:port`로 더할 수 있습니다.
3. **저장소(선택)**: 클라우드(claude.ai/code) 세션은 개인 설정을 읽지 않고 저장소에 커밋된 `.claude/settings.json`만 읽습니다. 넣을 저장소를 고르면(엔터 = 지금 있는 저장소) 그 파일에 넣고, 커밋하라고 알려 줍니다.

### 옵션

| 옵션 | 뜻 |
|---|---|
| `-n`, `--dry-run` | 바꾸지 않고 무엇이 바뀔지만 |
| `-y`, `--yes` | 묻지 않고 기본값으로: 이 컴퓨터 + 키로 붙는 호스트 중 바꿀 곳 전부(비밀번호 시도 · 추가 호스트는 하지 않음) |
| `host1 host2 …` | SSH 점검을 이 호스트들로만(별칭 또는 `user@host:port`) |
| `--no-ssh` | SSH 단계를 건너뜀 |
| `--project DIR` | 이 저장소의 `.claude/settings.json`에도(여러 번 줄 수 있음) |
| `-h`, `--help` | 도움말 |

터미널 없이(파이프 · cron 등) 실행할 때는 `-y`나 `-n`을 주어야 합니다.

## 무엇을 어떻게 바꾸나

```jsonc
// ~/.claude/settings.json (다른 설정은 그대로)
{
  "includeCoAuthoredBy": false,
  "attribution": { "sessionUrl": false, "commit": "", "pr": "" }
}
```

- **다른 설정은 건드리지 않습니다.** 처음 바꿀 때 원본을 `settings.json.bak-attribution`으로 남깁니다.
- 심볼릭 링크(dotfiles)면 링크가 아니라 실제 파일을 고칩니다. 임시 파일에 쓴 뒤 바꿔 끼워, 쓰다 끊겨도 파일이 반쯤 깨지지 않습니다.
- JSON이 깨져 있으면 쓰지 않고 알려 줍니다.
- 여러 번 돌려도 결과가 같습니다("이미 적용됨").
- `attribution`이 이미 `false`(전부 끔)면 그대로 둡니다.
- `CLAUDE_CONFIG_DIR`로 설정 폴더를 옮긴 환경이면 그 폴더를 씁니다.
- 실행 중인 Claude Code 세션도 설정 파일을 다시 읽어 **재시작 없이 반영**됩니다.

### 되돌리기

```bash
mv ~/.claude/settings.json.bak-attribution ~/.claude/settings.json
```

(원본에 `settings.json`이 없던 곳은 백업이 없습니다. 그곳은 `attribution` · `includeCoAuthoredBy` 두 항목만 지우면 됩니다.)

## 요구 사항

- 실행하는 컴퓨터: macOS 또는 Linux, bash 3.2 이상, Python 3.7 이상(`python3` 또는 `python`), OpenSSH 클라이언트
- 각 SSH 호스트: Python 3(`python3` → `python` → `py -3` 순서로 시도. Python이 있는 Windows OpenSSH 서버도 됩니다)

## 알려진 한계

- 관리자 정책(`managed-settings.json`)이 정한 값은 바꾸지 못합니다(정책이 우선).
- 저장소 설정은 커밋해서 푸시해야 클라우드 세션에 반영됩니다.
- `~/.ssh/config`의 `Match` 블록과 IPv6 주소(`user@[::1]:22`)는 따로 다루지 않습니다.
- 비밀번호로 시도하는 단계는 터미널에서 실행할 때만 나옵니다.

## 시험

```bash
tests/run.sh
```

가짜 `ssh`와 가짜 홈 폴더로 다음을 확인합니다(실제 서버에 접속하지 않음): 바꿀 곳 · 이미 적용 · Claude Code 없음 · 키 거부 · 접속 안 됨 · 셸이 시작 글을 찍는 서버 · 깨진 JSON · 다른 설정 보존 · 백업 · 두 번 돌려도 같음 · 저장소.
