# disko 디스크 파티셔닝 설정
#
# ⚠️ 중요: NVMe(/dev/nvme0n1)만 포맷합니다!
#    HDD(/dev/sda)는 disko 설정에 포함되지 않으므로 기존 데이터가 보존됩니다.
#
# disko 실행 전 반드시 확인:
#   lsblk -o NAME,SIZE,MODEL,TYPE
#
# 예상 출력:
#   nvme0n1     476.9G  HighRel_SSD_512GB  disk  ← 포맷 대상
#   sda           1.8T  ST2000LM007        disk  ← 보존!
{
  disko.devices = {
    disk = {
      nvme = {
        type = "disk";
        device = "/dev/nvme0n1"; # NVMe만 대상
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            swap = {
              size = "8G"; # 16GB RAM의 절반
              content = {
                type = "swap";
                resumeDevice = true;
              };
            };
            root = {
              size = "100%"; # 나머지 전체 (~468GB)
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
      # HDD는 여기에 포함하지 않음 - 기존 데이터 보존!
      # HDD 마운트는 hosts/greenhead-minipc/default.nix에서 fileSystems로 설정
    };
  };
}
