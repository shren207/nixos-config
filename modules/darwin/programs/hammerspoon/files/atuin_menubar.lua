--------------------------------------------------------------------------------
-- Atuin 동기화 상태 메뉴바 표시
-- 메뉴바에 거북이 아이콘으로 동기화 상태를 표시하고, 클릭 시 메뉴 제공
-- 참고: 실제 sync는 atuin 내장 auto_sync가 담당 (sync_frequency = 1m)
--------------------------------------------------------------------------------

local M = {}

-- 파일 경로
local historyDbFile = os.getenv("HOME") .. "/.local/share/atuin/history.db"
local monitorConfigFile = os.getenv("HOME") .. "/.config/atuin-monitor/config.json"
local atuinPath = "/etc/profiles/per-user/" .. os.getenv("USER") .. "/bin/atuin"

-- 내부 상태
local menubar = nil
local currentStatus = "ok"
local lastSyncTime = nil
local lastSyncEpoch = nil
local lastCmdTime = nil
local lastCmdEpoch = nil
local updateTimer = nil

-- watchdog 스크립트 경로
local watchdogPath = os.getenv("HOME") .. "/.local/bin/atuin-watchdog.sh"

-- 설정값 (loadConfig에서 로드)
local config = {
    syncCheckInterval = 600,      -- watchdog 상태 체크 주기 (초)
    syncThresholdMinutes = 5      -- 경고 임계값 (분)
}

--------------------------------------------------------------------------------
-- 설정 파일 읽기
--------------------------------------------------------------------------------

-- 파일 읽기
local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

-- JSON 설정 파일 읽기 (nix에서 생성)
local function loadMonitorConfig()
    local content = readFile(monitorConfigFile)
    if not content then return nil end
    local success, result = pcall(function() return hs.json.decode(content) end)
    if success then return result end
    return nil
end

-- 설정 로드
local function loadConfig()
    local loaded = loadMonitorConfig()
    if loaded then
        config = loaded
    end
end

--------------------------------------------------------------------------------
-- 유틸리티 함수
--------------------------------------------------------------------------------

-- 상대 시간 텍스트 생성
local function getRelativeTime(epoch)
    if not epoch then return "알 수 없음" end

    local now = os.time()
    local diff = now - epoch

    if diff < 60 then
        return "방금 전"
    elseif diff < 3600 then
        return string.format("%d분 전", math.floor(diff / 60))
    elseif diff < 86400 then
        return string.format("%d시간 전", math.floor(diff / 3600))
    else
        return string.format("%d일 전", math.floor(diff / 86400))
    end
end

-- 히스토리 개수 조회 (sqlite3 사용)
local function getHistoryCount()
    if not hs.fs.attributes(historyDbFile) then return nil end

    local output, status = hs.execute("sqlite3 '" .. historyDbFile .. "' 'SELECT COUNT(*) FROM history;' 2>/dev/null")
    if status and output then
        local count = output:match("(%d+)")
        if count then
            return tonumber(count)
        end
    end
    return nil
end

-- 시간 간격을 한국어로 변환
local function formatInterval(seconds)
    if seconds >= 3600 then
        return string.format("%d시간마다", seconds / 3600)
    else
        return string.format("%d분마다", seconds / 60)
    end
end

--------------------------------------------------------------------------------
-- 상태 관리
--------------------------------------------------------------------------------

-- 상태 설정 (외부에서 호출 가능)
function M:setStatus(status)
    currentStatus = status
    -- 아이콘은 항상 🐢로 고정
    if menubar then
        menubar:setTitle("🐢")
    end
end

-- 상태 문장 생성
function M:getStatusText()
    if currentStatus == "ok" then
        return "✅ 정상"
    elseif currentStatus == "warning" then
        -- 새 로직: 마지막 CLI 입력 후 N분 미동기화
        if lastCmdEpoch and lastSyncEpoch then
            local diffMinutes = math.floor((lastCmdEpoch - lastSyncEpoch) / 60)
            return "⚠️ 동기화 지연 (CLI 입력 후 " .. diffMinutes .. "분 미동기화)"
        else
            return "⚠️ 동기화 지연"
        end
    else
        return "❌ 오류 발생"
    end
end

-- watchdog.sh --status 호출하여 상태 업데이트 (Single Source of Truth)
function M:updateFromWatchdog()
    local output, status = hs.execute(watchdogPath .. " --status 2>/dev/null")
    if not status or not output then
        self:setStatus("error")
        lastSyncTime = nil
        lastSyncEpoch = nil
        lastCmdTime = nil
        lastCmdEpoch = nil
        return
    end

    -- JSON 파싱
    local success, data = pcall(function() return hs.json.decode(output) end)
    if not success or not data then
        self:setStatus("error")
        return
    end

    -- 상태 설정
    self:setStatus(data.status or "error")

    -- epoch 값 저장
    if data.lastSyncEpoch and data.lastSyncEpoch > 0 then
        lastSyncEpoch = data.lastSyncEpoch
        lastSyncTime = os.date("%Y-%m-%d %H:%M:%S", lastSyncEpoch)
    else
        lastSyncEpoch = nil
        lastSyncTime = nil
    end

    if data.lastCmdEpoch and data.lastCmdEpoch > 0 then
        lastCmdEpoch = data.lastCmdEpoch
        lastCmdTime = os.date("%Y-%m-%d %H:%M:%S", lastCmdEpoch)
    else
        lastCmdEpoch = nil
        lastCmdTime = nil
    end
end

-- 마지막 동기화 텍스트 생성
function M:getLastSyncText()
    if not lastSyncTime then
        return "동기화 기록 없음"
    end
    return lastSyncTime .. " (" .. getRelativeTime(lastSyncEpoch) .. ")"
end

-- 마지막 CLI 커맨드 입력 텍스트 생성
function M:getLastCmdText()
    if not lastCmdTime then
        return "기록 없음"
    end
    return lastCmdTime .. " (" .. getRelativeTime(lastCmdEpoch) .. ")"
end

--------------------------------------------------------------------------------
-- 메뉴 구성
--------------------------------------------------------------------------------

function M:buildMenu()
    local historyCount = getHistoryCount()

    return {
        -- 상태 문장 (최상단)
        { title = self:getStatusText(), disabled = true },
        { title = "-" },
        -- 시간 정보
        { title = "마지막 CLI 커맨드 입력: " .. self:getLastCmdText(), disabled = true },
        { title = "마지막 동기화: " .. self:getLastSyncText(), disabled = true },
        { title = "히스토리: " .. (historyCount and string.format("%d개", historyCount) or "확인 불가"), disabled = true },
        { title = "-" },
        -- 설정값
        { title = "상태 체크 주기: " .. formatInterval(config.syncCheckInterval), disabled = true },
        { title = "동기화 경고 임계값: " .. config.syncThresholdMinutes .. "분", disabled = true },
        { title = "-" },
        -- 팁
        { title = "💡 터미널에서 명령 실행 시 자동 동기화 (1분 간격)", disabled = true },
    }
end

--------------------------------------------------------------------------------
-- 초기화
--------------------------------------------------------------------------------

function M:init()
    -- 설정 로드
    loadConfig()

    -- 메뉴바 생성
    menubar = hs.menubar.new()
    if not menubar then
        hs.notify.new({title="Atuin Menubar", informativeText="메뉴바 생성 실패"}):send()
        return
    end

    -- 메뉴 설정
    menubar:setMenu(function() return self:buildMenu() end)

    -- 초기 상태 설정
    self:updateFromWatchdog()

    -- 1분마다 자동 업데이트
    updateTimer = hs.timer.doEvery(60, function()
        self:updateFromWatchdog()
    end)

    return self
end

-- 정리 (필요시)
function M:destroy()
    if updateTimer then
        updateTimer:stop()
        updateTimer = nil
    end
    if menubar then
        menubar:delete()
        menubar = nil
    end
end

--------------------------------------------------------------------------------
-- 전역 노출 및 초기화
--------------------------------------------------------------------------------

M:init()
_G.atuinMenubar = M

return M
