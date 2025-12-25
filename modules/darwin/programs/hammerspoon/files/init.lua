-- capslock 한영 전환 시 딜레이 해결  
local FRemap = require('foundation_remapping')  
local remapper = FRemap.new()  
remapper:remap('capslock', 'f18')  
remapper:register()  
  
-- escape 누를 시 영어로 변환 (Global 설정)  
local inputEnglish = "com.apple.keylayout.ABC"  
local inputKorean = "com.apple.inputmethod.Korean.2SetKorean"
local escape_bind
local control_semicolon_bind
local command_shift_space_bind  
local ctrl_b_bind

hs.keycodes.currentSourceID(inputKorean)
local lastSource = inputKorean

function convert_to_eng_with_escape() 
    local inputSource = hs.keycodes.currentSourceID()
    if not (inputSource == inputEnglish) then
        hs.keycodes.currentSourceID(inputEnglish)
    end 
    escape_bind:disable()
    hs.eventtap.keyStroke({}, 'escape')
    escape_bind:enable()
end

function convert_to_eng_with_control_semicolon() 
    local inputSource = hs.keycodes.currentSourceID()
    if not (inputSource == inputEnglish) then
        hs.keycodes.currentSourceID(inputEnglish)
    end  
    control_semicolon_bind:disable()
    hs.eventtap.keyStroke({'ctrl'}, ';')
    control_semicolon_bind:enable()
end

-- Homerow 대응위한 코드
function convert_to_eng_and_trigger_hotkey()  
    local inputSource = hs.keycodes.currentSourceID()  
    if not (inputSource == inputEnglish) then  
       hs.keycodes.currentSourceID(inputEnglish)  
    end  
    -- 1️⃣ 입력소스 한글 -> 영어로 전환  
    hs.eventtap.keyStroke({'cmd', 'shift'}, 'space')  
  
    -- 2️⃣ hammerspoon 바인딩 비활성화하여, homerow를 실행할 수 있도록 함  
    command_shift_space_bind:disable()  
    hs.eventtap.keyStroke({'cmd', 'shift'}, 'space')  
    command_shift_space_bind:enable()  
end  

-- Tmux 대응위한 코드 (Ctrl + B 누르면 영어로 전환)
function convert_to_eng_and_trigger_hotkey_tmux()  
    local inputSource = hs.keycodes.currentSourceID()  
    if not (inputSource == inputEnglish) then  
       hs.keycodes.currentSourceID(inputEnglish)  
    end  
    ctrl_b_bind:disable()
    hs.eventtap.keyStroke({'ctrl'}, 'b')
    ctrl_b_bind:enable()
end  
  
control_semicolon_bind= hs.hotkey.new({'ctrl'}, ';', convert_to_eng_with_control_semicolon):enable()
-- escape_bind = hs.hotkey.new({}, 'escape', convert_to_eng_with_escape):enable()
command_shift_space_bind = hs.hotkey.new({'cmd', 'shift'}, 'space', convert_to_eng_and_trigger_hotkey):enable()
ctrl_b_bind = hs.hotkey.new({'ctrl'}, 'b', convert_to_eng_and_trigger_hotkey_tmux):enable()

-- IntelliJ IDEA 포커스 변경 시 영어로 전환하는 기능 추가
-- local wf = hs.window.filter
-- local idea_filter = wf.new(false):setAppFilter('IntelliJ IDEA', {allowTitles='.*'})

-- function convert_to_eng_on_focus()
--     local inputSource = hs.keycodes.currentSourceID()
--     if not (inputSource == inputEnglish) then
--         hs.keycodes.currentSourceID(inputEnglish)
--     end
-- end

-- idea_filter:subscribe(wf.windowFocused, function(window, appName)
--     convert_to_eng_on_focus()
-- end)

--------------------------------------------------------------------------------
-- Finder → Ghostty 터미널 열기 (Ctrl + Option + Cmd + T)
--------------------------------------------------------------------------------

local function openGhosttyFromFinder()
  local frontApp = hs.application.frontmostApplication()
  local path = nil

  -- Finder에서 실행 시: 현재 디렉토리 가져오기
  if frontApp:bundleID() == "com.apple.finder" then
    local script = [[
      tell application "Finder"
        try
          if (count of windows) > 0 then
            return POSIX path of (target of front window as alias)
          else
            return POSIX path of (path to desktop folder as alias)
          end if
        on error
          return POSIX path of (path to desktop folder as alias)
        end try
      end tell
    ]]
    local ok, result = hs.osascript.applescript(script)
    if ok then
      path = result
    end
  end

  -- Ghostty 새 창 열기
  local ghostty = hs.application.get("Ghostty")

  if ghostty then
    -- 이미 실행 중: 활성화 후 Cmd+N으로 새 창, cd로 경로 이동
    ghostty:activate()
    -- 딜레이 1: Ghostty 활성화 완료 대기 (Cmd+N이 Ghostty에 전달되도록)
    -- 경로가 열리지 않으면 이 값을 늘려보세요 (예: 0.3)
    hs.timer.doAfter(0.2, function()
      hs.eventtap.keyStroke({"cmd"}, "n")
      if path then
        -- 딜레이 2: 새 창이 완전히 열릴 때까지 대기 (cd가 새 창에 입력되도록)
        -- 기존 창에 cd가 입력되면 이 값을 늘려보세요 (예: 0.8)
        hs.timer.doAfter(0.6, function()
          -- 경로를 따옴표로 감싸서 특수문자/공백 처리
          hs.eventtap.keyStrokes('cd "' .. path .. '" && clear')
          hs.eventtap.keyStroke({}, "return")
        end)
      end
    end)
  else
    -- 미실행: open 명령어로 시작
    local args = {"-a", "Ghostty"}
    if path then
      table.insert(args, "--args")
      table.insert(args, "--working-directory=" .. path)
    end
    hs.task.new("/usr/bin/open", nil, args):start()
  end
end

hs.hotkey.bind({"ctrl", "alt", "cmd"}, "t", openGhosttyFromFinder)