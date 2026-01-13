--------------------------------------------------------------------------------
-- Atuin 동기화 상태 메뉴바 표시
-- 메뉴바에 거북이 아이콘으로 동기화 상태를 표시하고, 클릭 시 메뉴 제공
--------------------------------------------------------------------------------

local M = {}

-- 설정
local lastSyncFile = os.getenv("HOME") .. "/.local/share/atuin/last_sync_time"
local historyDbFile = os.getenv("HOME") .. "/.local/share/atuin/history.db"
local logFile = os.getenv("HOME") .. "/Library/Logs/atuin/sync-monitor.log"
local scriptPath = os.getenv("HOME") .. "/.local/bin/atuin-sync-monitor.sh"
local thresholdHours = 24

-- 상태별 아이콘
local icons = {
    ok = "🐢",
    syncing = "🐢🔄",
    warning = "🐢⚠️",
    error = "🐢❌"
}

-- 내부 상태
local menubar = nil
local currentStatus = "ok"
local lastSyncTime = nil
local lastSyncEpoch = nil
local syncingTimeout = nil
local updateTimer = nil

--------------------------------------------------------------------------------
-- 유틸리티 함수
--------------------------------------------------------------------------------

-- 파일 읽기
local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

-- ISO 8601 UTC 시간을 epoch로 변환
local function parseISOTime(isoString)
    if not isoString then return nil end
    -- "2026-01-13T05:06:16.759844Z" 형식
    local year, month, day, hour, min, sec = isoString:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if not year then return nil end

    -- UTC 시간을 epoch로 변환
    local utcTime = os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec)
    })

    -- os.time은 로컬 시간으로 해석하므로 UTC 오프셋 보정
    local localTime = os.time()
    local utcNow = os.time(os.date("!*t", localTime))
    local offset = localTime - utcNow

    return utcTime + offset
end

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

--------------------------------------------------------------------------------
-- 상태 관리
--------------------------------------------------------------------------------

-- 상태 설정 (외부에서 호출 가능)
function M:setStatus(status)
    -- syncing 타임아웃 처리
    if syncingTimeout then
        syncingTimeout:stop()
        syncingTimeout = nil
    end

    if status == "syncing" then
        -- 5분 후 자동 복구 (스크립트 비정상 종료 대비)
        syncingTimeout = hs.timer.doAfter(300, function()
            self:updateFromFile()
        end)
    end

    currentStatus = status
    if menubar then
        menubar:setTitle(icons[status] or icons.ok)
    end
end

-- 파일에서 상태 업데이트
function M:updateFromFile()
    local content = readFile(lastSyncFile)
    if not content then
        self:setStatus("error")
        lastSyncTime = nil
        lastSyncEpoch = nil
        return
    end

    -- 시간 파싱
    content = content:gsub("%s+", "")  -- 공백 제거
    lastSyncEpoch = parseISOTime(content)

    if not lastSyncEpoch then
        self:setStatus("error")
        lastSyncTime = nil
        return
    end

    -- KST로 변환하여 저장
    lastSyncTime = os.date("%Y-%m-%d %H:%M:%S", lastSyncEpoch)

    -- 임계값 체크
    local now = os.time()
    local diffHours = (now - lastSyncEpoch) / 3600

    if diffHours >= thresholdHours then
        self:setStatus("warning")
    else
        self:setStatus("ok")
    end
end

-- 마지막 동기화 텍스트 생성
function M:getLastSyncText()
    if not lastSyncTime then
        return "동기화 기록 없음"
    end
    return lastSyncTime .. " (" .. getRelativeTime(lastSyncEpoch) .. ")"
end

--------------------------------------------------------------------------------
-- 메뉴 구성
--------------------------------------------------------------------------------

function M:buildMenu()
    local historyCount = getHistoryCount()
    local historyText = historyCount and string.format("히스토리: %s개", hs.styledtext.new(tostring(historyCount)):getString()) or "히스토리: 확인 불가"

    return {
        { title = "마지막 동기화: " .. self:getLastSyncText(), disabled = true },
        { title = "히스토리: " .. (historyCount and string.format("%d개", historyCount) or "확인 불가"), disabled = true },
        { title = "-" },
        { title = "지금 동기화", fn = function()
            self:setStatus("syncing")
            hs.task.new("/bin/bash", function(exitCode, stdOut, stdErr)
                self:updateFromFile()
                -- 완료 알림 직접 발송
                if exitCode == 0 then
                    hs.notify.new({title="🐢✅ Atuin 동기화 OK", informativeText="마지막 동기화: " .. self:getLastSyncText()}):send()
                else
                    hs.notify.new({title="🐢❌ Atuin 동기화 실패", informativeText="오류가 발생했습니다."}):send()
                end
            end, {"-c", scriptPath}):start()
        end },
        { title = "테스트 알림 발송", fn = function()
            -- Hammerspoon 알림 직접 발송
            hs.notify.new({title="🐢🧪 Atuin 테스트", informativeText="테스트 알림 - 마지막 동기화: " .. self:getLastSyncText()}):send()
            -- 스크립트도 실행 (Pushover 등)
            hs.task.new("/bin/bash", function() end, {"-c", scriptPath .. " --test"}):start()
        end },
        { title = "-" },
        { title = "로그 보기", fn = function()
            if hs.fs.attributes(logFile) then
                hs.execute("open -a Console " .. logFile)
            else
                hs.notify.new({title="🐢 Atuin", informativeText="로그 파일이 아직 없습니다.\n먼저 '지금 동기화'를 실행하세요."}):send()
            end
        end },
        { title = "로그 보기 (터미널)", fn = function()
            if not hs.fs.attributes(logFile) then
                hs.notify.new({title="🐢 Atuin", informativeText="로그 파일이 아직 없습니다.\n먼저 '지금 동기화'를 실행하세요."}):send()
                return
            end
            hs.execute("open -a Ghostty")
            hs.timer.doAfter(0.5, function()
                hs.eventtap.keyStroke({}, "return")
                hs.timer.doAfter(0.1, function()
                    local prevClipboard = hs.pasteboard.getContents()
                    hs.pasteboard.setContents("tail -f " .. logFile)
                    hs.eventtap.keyStroke({"cmd"}, "v")
                    hs.eventtap.keyStroke({}, "return")
                    hs.timer.doAfter(0.1, function()
                        if prevClipboard then
                            hs.pasteboard.setContents(prevClipboard)
                        end
                    end)
                end)
            end)
        end },
        { title = "설정 폴더 열기", fn = function()
            hs.execute("open ~/IdeaProjects/nixos-config/modules/darwin/programs/atuin/")
        end },
    }
end

--------------------------------------------------------------------------------
-- 초기화
--------------------------------------------------------------------------------

function M:init()
    -- 메뉴바 생성
    menubar = hs.menubar.new()
    if not menubar then
        hs.notify.new({title="Atuin Menubar", informativeText="메뉴바 생성 실패"}):send()
        return
    end

    -- 메뉴 설정
    menubar:setMenu(function() return self:buildMenu() end)

    -- 초기 상태 설정
    self:updateFromFile()

    -- 1분마다 자동 업데이트
    updateTimer = hs.timer.doEvery(60, function()
        -- syncing 상태가 아닐 때만 업데이트
        if currentStatus ~= "syncing" then
            self:updateFromFile()
        end
    end)

    return self
end

-- 정리 (필요시)
function M:destroy()
    if updateTimer then
        updateTimer:stop()
        updateTimer = nil
    end
    if syncingTimeout then
        syncingTimeout:stop()
        syncingTimeout = nil
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
