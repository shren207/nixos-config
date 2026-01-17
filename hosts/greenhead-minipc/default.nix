# greenhead-minipc 호스트 설정
{
  config,
  lib,
  pkgs,
  inputs,
  username,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix # placeholder → 설치 후 실제 내용으로 교체
    ./disko.nix
  ];

  # SSH 공개키 (Mac에서 접속용)
  users.users.${username}.openssh.authorizedKeys.keys = [
    # Mac의 ~/.ssh/id_ed25519.pub 내용
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDN048Qg9ABnM26jU0X0w2mG9pqcrwuVrcihvDbkRVX8 greenhead-home-mac-2025-10"
  ];

  # HDD 마운트 (기존 데이터 유지)
  # ⚠️ 중요: 이 HDD는 NixOS 설치 시 포맷하지 않음!
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/3f1111d9-1641-4d5e-9e40-af54f4ce7870";
    fsType = "ext4";
    options = [
      "defaults"
      "nofail"
    ];
  };
}
