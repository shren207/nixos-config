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