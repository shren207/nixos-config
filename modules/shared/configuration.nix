# 공유 Nix 설정 (Darwin + Linux 공통)
{ pkgs, ... }:

{
  # Nix 설정
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      warn-dirty = false;
    };

    # 스토어 최적화 (auto-optimise-store 대신 사용)
    optimise.automatic = true;

    # 가비지 컬렉션
    gc = {
      automatic = true;
      interval = { Weekday = 0; Hour = 2; Minute = 0; };
      options = "--delete-older-than 30d";
    };
  };

  # 프로그램 활성화
  programs.zsh.enable = true;
}
