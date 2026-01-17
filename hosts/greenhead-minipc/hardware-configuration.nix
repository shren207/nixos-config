# ⚠️ PLACEHOLDER 파일
# 이 파일은 NixOS 설치 후 실제 내용으로 교체됩니다.
#
# Phase 2 완료 후:
#   1. MiniPC에서: cat /etc/nixos/hardware-configuration.nix
#   2. 그 내용을 이 파일에 복사
#   3. git add && git commit && git push
#   4. sudo nixos-rebuild switch --flake .#greenhead-minipc
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # 일반적인 x86_64 시스템용 기본값 (설치 후 실제 값으로 교체됨)
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  # disko가 파일시스템을 관리하므로 여기서는 정의하지 않음
  # fileSystems는 disko.nix에서 자동 생성됨

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
