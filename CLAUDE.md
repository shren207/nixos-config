# nixos-config

macOS와 NixOS 개발 환경을 nix-darwin/NixOS + Home Manager로 선언적 관리하는 프로젝트

## 실행 환경

| Platform | 현재 환경 | 다른 머신 접속 |
|----------|----------|---------------|
| `darwin` | Mac | `ssh minipc` |
| `linux` | MiniPC (NixOS) | `ssh mac` |

**현재 환경에 SSH 접속 금지.** Platform: darwin이면 `ssh mac` 금지, linux이면 `ssh minipc` 금지.

## 빌드

`nrs`를 사용. `darwin-rebuild`/`nixos-rebuild` 직접 실행 금지.

## 상수

하드코딩된 IP, 경로, SSH 키, UID 등은 `libraries/constants.nix`를 우선 확인.

## 스킬 문서 불일치

스킬 문서의 CLI 명령이 에러나면 `--help`로 확인 후 차이를 사용자에게 보고.
승인 없이 문서를 우회해 진행하지 않는다.
