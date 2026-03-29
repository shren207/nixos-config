# Dropzone 5 — FolderActions UI 프론트엔드 + 즉석 공유 액션
#
# Dropzone 앱은 수동 설치 (Homebrew cask가 아직 v4를 가리키므로 미선언).
# cask가 v5로 업데이트되면 `brew install --cask --adopt dropzone` 후 homebrew.nix에 추가.
#
# bundle 파일만 Nix 관리. 격자 레이아웃/런타임 상태는 관리하지 않음.
# (Dropzone 설정은 비문서화된 내부 상태이므로 Shottr와 달리 defaults 선언 불가)
{
  config,
  lib,
  hostType,
  ...
}:

lib.mkIf (hostType == "personal") (
  let
    homeDir = config.home.homeDirectory;
    folderActionsDir = "${homeDir}/FolderActions";

    # 미검증: 설치 후 `Dropzone 5/Actions/` vs `Dropzone/Actions/` 확인 필요
    dropzoneActionsDir = "Library/Application Support/Dropzone 5/Actions";

    pushoverCredPath = "${config.xdg.configHome}/pushover/claude-code";

    placeholderIcon = ./files/icon-placeholder.png;

    # FolderActions 프론트엔드 액션 정의 (DRY: slug만 다르고 로직 동일)
    # 각 액션은 파일을 ~/FolderActions/<slug>/에 enqueue하고,
    # 기존 launchd WatchPaths 에이전트가 실제 처리를 담당한다.
    folderActionFrontends = {
      compress-video = {
        name = "Compress Video (H.265)";
        description = "FolderActions 프론트엔드: H.265 하드웨어 가속 압축";
      };
      convert-video-to-gif = {
        name = "Convert to GIF";
        description = "FolderActions 프론트엔드: 비디오 → GIF 변환 (15fps, 480px)";
      };
      rename-asset = {
        name = "Rename to Timestamp";
        description = "FolderActions 프론트엔드: 타임스탬프 기반 파일명 변경";
      };
    };

    # FolderActions 프론트엔드 공통 Ruby 템플릿
    # system() 배열 호출: shell injection 방지
    # 임시경로 cp → 원자적 mv: WatchPaths 타이밍 레이스 방지
    mkFolderActionRb = slug: meta: ''
      # Dropzone Action Info
      # Name: ${meta.name}
      # Description: ${meta.description}
      # Handles: Files
      # Events: Dragged
      # Creator: greenhead
      # RunsSandboxed: No

      def dragged
        $dz.begin("Sending to ${meta.name}...")
        target = "${folderActionsDir}/${slug}"
        tmp = "/tmp/dz-enqueue-#{Process.pid}"
        Dir.mkdir(tmp) unless Dir.exist?(tmp)
        begin
          $items.each { |item| system("/bin/cp", item, "#{tmp}/") }
          Dir.glob("#{tmp}/*").each { |f| system("/bin/mv", f, "#{target}/") }
        ensure
          FileUtils.rm_rf(tmp)
        end
        $dz.finish("Queued!")
        $dz.url(false)
      end
    '';

    # FolderActions 프론트엔드 번들의 home.file 엔트리 생성
    folderActionFiles = lib.concatMapAttrs (slug: meta: {
      "${dropzoneActionsDir}/${slug}.dzbundle/action.rb".text = mkFolderActionRb slug meta;
      "${dropzoneActionsDir}/${slug}.dzbundle/icon.png".source = placeholderIcon;
    }) folderActionFrontends;

  in
  {
    home.file = folderActionFiles // {
      # Pushover Text — 텍스트 드래그 → iPhone 푸시 알림
      # 기존 push() 셸 함수(shell/default.nix)와 동일 credential 파일 소비
      # Ruby에서 셸 함수를 안전하게 호출할 수 없으므로 curl 직접 호출
      "${dropzoneActionsDir}/pushover-text.dzbundle/action.rb".text = ''
        # Dropzone Action Info
        # Name: Pushover Text
        # Description: 텍스트를 iPhone으로 푸시 알림 전송
        # Handles: Text
        # Events: Dragged
        # Creator: greenhead
        # RunsSandboxed: No

        def dragged
          $dz.begin("Sending to iPhone...")
          text = $items[0]
          cred_path = "${pushoverCredPath}"

          creds = {}
          File.readlines(cred_path).each do |line|
            key, val = line.strip.split("=", 2)
            creds[key] = val if key && val
          end

          result = system("/usr/bin/curl", "--fail", "--silent", "--max-time", "10",
            "-X", "POST",
            "--data-urlencode", "token=#{creds['PUSHOVER_TOKEN']}",
            "--data-urlencode", "user=#{creds['PUSHOVER_USER']}",
            "--data-urlencode", "message=#{text}",
            "https://api.pushover.net/1/messages.json")

          if result
            $dz.finish("Sent!")
          else
            $dz.fail("Failed to send")
          end
          $dz.url(false)
        end
      '';
      "${dropzoneActionsDir}/pushover-text.dzbundle/icon.png".source = placeholderIcon;
    };
  }
)
