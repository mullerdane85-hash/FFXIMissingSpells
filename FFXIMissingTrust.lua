_addon.name     = 'FFXIMissingTrust'
_addon.author   = 'Jason'
_addon.version  = '1.1'
_addon.commands = {'missingtrust', 'mtrust', 'mt'}

-- =============================================================================
-- FFXIMissingTrust
--
-- Reports which trust magic spells the character still needs to learn, in
-- both chat-output and a draggable GSUI-style window.
--
-- Window:        //mt show | hide | toggle      (or just //mt with no args)
-- Chat summary:  //mt count
-- Chat list:     //mt list (missing) | //mt have (owned) | //mt find <name>
--
-- The data source is res.spells filtered to type == 'Trust', compared
-- against windower.ffxi.get_spells(). Unity Concord (UC) variants are
-- separate spell IDs and listed independently.
-- =============================================================================

require('luau')
local config = require('config')
local res    = require('resources')
local texts  = require('texts')
local images = require('images')

-- ---------------------------------------------------------------------------
-- Settings (persistent — saved to data/settings.xml)
-- ---------------------------------------------------------------------------
local defaults = {
    pos      = { x = 220, y = 220 },
    visible  = false,
    mode     = 'missing',    -- missing | owned | all
}
local settings = config.load(defaults)
config.save(settings)

-- ---------------------------------------------------------------------------
-- Visual constants — match GSUI's look
-- ---------------------------------------------------------------------------
local BORDER       = 3
local TITLE_BAR_H  = 30
local TAB_H        = 22
local TAB_GAP      = 4
local SUMMARY_H    = 26
local ROW_H        = 18
local SCROLL_BTN_H = 20
local PAD          = 8
local PANEL_W      = 320
local VISIBLE_ROWS = 22

-- Colors (alpha, r, g, b)
local C_BORDER     = { 220, 70,  130, 200 }
local C_TITLE_BG   = { 240, 30,  60,  120 }
local C_TITLE_TXT  = { 255, 200, 200, 230 }
local C_BODY_BG    = { 200, 15,  15,  35  }
local C_TAB_ON     = { 240, 50,  100, 180 }
local C_TAB_OFF    = { 180, 30,  40,  70  }
local C_TAB_TXT_ON = { 255, 255, 255, 255 }
local C_TAB_TXT_OFF= { 255, 160, 160, 200 }
local C_SUMMARY    = { 255, 230, 230, 150 }
local C_MISSING    = { 255, 255, 130, 130 }
local C_OWNED      = { 255, 130, 230, 130 }
local C_SCROLL_BG  = { 200, 40,  50,  90  }
local C_SCROLL_TXT = { 255, 255, 255, 255 }
local C_SCROLL_OFF = { 80,  40,  50,  90  }
local C_SCROLL_TXT_OFF = { 100, 200, 200, 200 }

-- ---------------------------------------------------------------------------
-- Chat colors (used by chat commands)
-- ---------------------------------------------------------------------------
local CHAT_HEADER  = 207
local CHAT_OWNED   = 158
local CHAT_MISSING = 167
local CHAT_ITEM    = 160

-- ---------------------------------------------------------------------------
-- UI element factories — same shape as GSUI's make_bg / make_text
-- ---------------------------------------------------------------------------
local function make_bg(x, y, w, h, c)
    return images.new({
        color = { alpha = c[1], red = c[2], green = c[3], blue = c[4] },
        pos   = { x = x, y = y },
        size  = { width = w, height = h },
        draggable = false,
    })
end

local function make_text(content, x, y, c, size, bold)
    local t = texts.new({
        text = { size = size or 10, font = 'Consolas',
            alpha = c[1] or 255, red = c[2] or 255, green = c[3] or 255, blue = c[4] or 255,
            stroke = { width = 1, alpha = 180, red = 0, green = 0, blue = 0 },
        },
        bg = { alpha = 0 },
        pos = { x = x, y = y },
        flags = { draggable = false, bold = bold or false },
    })
    t:text(content)
    return t
end

local function show(el)   if el and el.show then el:show() end end
local function hide(el)   if el and el.hide then el:hide() end end
local function destroy(el)
    if not el then return end
    if el.hide then el:hide() end
    if el.destroy then el:destroy() end
end

-- ---------------------------------------------------------------------------
-- Data
-- ---------------------------------------------------------------------------

local function all_trusts()
    local out = {}
    for id, spell in pairs(res.spells) do
        if spell.type == 'Trust' then
            table.insert(out, { id = id, name = spell.en })
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

local function partition()
    local known = windower.ffxi.get_spells() or {}
    local owned, missing = {}, {}
    for _, t in ipairs(all_trusts()) do
        if known[t.id] then table.insert(owned, t)
        else                table.insert(missing, t) end
    end
    return owned, missing
end

-- Returns ({rows}, summary_line, row_color) for the current mode.
local function rows_for_mode()
    local owned, missing = partition()
    local total = #owned + #missing
    if settings.mode == 'owned' then
        return owned,
               string.format('Owned: %d / %d', #owned, total),
               C_OWNED
    elseif settings.mode == 'all' then
        local everything = {}
        for _, t in ipairs(all_trusts()) do table.insert(everything, t) end
        return everything,
               string.format('All trusts: %d  (owned %d, missing %d)', total, #owned, #missing),
               C_SUMMARY
    else
        return missing,
               string.format('Missing: %d / %d', #missing, total),
               C_MISSING
    end
end

-- ---------------------------------------------------------------------------
-- Chat output (unchanged from v1.0)
-- ---------------------------------------------------------------------------

local function chat(color, line) windower.add_to_chat(color, line) end

local function cmd_count()
    local owned, missing = partition()
    local total = #owned + #missing
    chat(CHAT_HEADER, string.format(
        '[MissingTrust] %d / %d trusts learned  (%d still needed)',
        #owned, total, #missing))
end

local function cmd_list_chat()
    local _, missing = partition()
    if #missing == 0 then
        chat(CHAT_OWNED, '[MissingTrust] You have every trust in the game. Nice.')
        return
    end
    chat(CHAT_HEADER, string.format('[MissingTrust] %d trusts still needed:', #missing))
    for _, t in ipairs(missing) do chat(CHAT_MISSING, '  - ' .. t.name) end
end

local function cmd_have_chat()
    local owned = partition()
    if #owned == 0 then
        chat(CHAT_MISSING, '[MissingTrust] You have no trusts learned yet.')
        return
    end
    chat(CHAT_HEADER, string.format('[MissingTrust] %d trusts learned:', #owned))
    for _, t in ipairs(owned) do chat(CHAT_OWNED, '  + ' .. t.name) end
end

local function cmd_find_chat(query)
    if not query or query == '' then
        chat(CHAT_MISSING, '[MissingTrust] usage: //mt find <name fragment>')
        return
    end
    query = query:lower()
    local known = windower.ffxi.get_spells() or {}
    local hits = 0
    chat(CHAT_HEADER, string.format('[MissingTrust] Trusts matching "%s":', query))
    for _, t in ipairs(all_trusts()) do
        if t.name:lower():find(query, 1, true) then
            hits = hits + 1
            if known[t.id] then chat(CHAT_OWNED,   '  + ' .. t.name .. '   (learned)')
            else                chat(CHAT_MISSING, '  - ' .. t.name .. '   (missing)') end
        end
    end
    if hits == 0 then chat(CHAT_ITEM, '  (no trusts match)') end
end

-- ---------------------------------------------------------------------------
-- Window UI
-- ---------------------------------------------------------------------------

local ui = {
    el        = {},           -- all element references for show/hide/destroy
    rows      = {},           -- per-row {bg, text} pairs (re-used while window is up)
    scroll    = 0,            -- top index into the current rows list
    drag      = nil,          -- { dx, dy } during a drag, else nil
    rect      = {},           -- hit-test rects: title_bar, tab_miss, tab_have, tab_all, body, scroll_up, scroll_down
    total_w   = PANEL_W,
    total_h   = 0,
}

-- Recompute total window height for current row count
local function calc_dims(row_count)
    local visible = math.min(row_count, VISIBLE_ROWS)
    local body_h  = SUMMARY_H + PAD + (visible * ROW_H)
    if row_count > VISIBLE_ROWS then
        body_h = body_h + PAD + SCROLL_BTN_H + 2 + SCROLL_BTN_H
    end
    body_h = body_h + PAD * 2
    ui.total_h = BORDER * 2 + TITLE_BAR_H + body_h
end

local function destroy_window()
    for _, e in pairs(ui.el)   do destroy(e) end
    for _, r in ipairs(ui.rows) do destroy(r.bg); destroy(r.text) end
    ui.el = {}
    ui.rows = {}
    ui.rect = {}
end

local function build_window()
    destroy_window()

    local rows, summary, row_color = rows_for_mode()
    calc_dims(#rows)

    local x, y = settings.pos.x, settings.pos.y
    local W, H = ui.total_w, ui.total_h

    -- Border frame
    ui.el.border_top    = make_bg(x,             y,             W,      BORDER, C_BORDER)
    ui.el.border_bottom = make_bg(x,             y + H - BORDER,W,      BORDER, C_BORDER)
    ui.el.border_left   = make_bg(x,             y,             BORDER, H,      C_BORDER)
    ui.el.border_right  = make_bg(x + W - BORDER,y,             BORDER, H,      C_BORDER)

    -- Title bar
    local tb_x = x + BORDER
    local tb_y = y + BORDER
    local tb_w = W - BORDER * 2
    ui.el.title_bar  = make_bg(tb_x, tb_y, tb_w, TITLE_BAR_H, C_TITLE_BG)
    ui.el.title_text = make_text('FFXIMissingTrust', tb_x + PAD, tb_y + 7, C_TITLE_TXT, 11, true)
    ui.rect.title_bar = { x = tb_x, y = tb_y, w = tb_w, h = TITLE_BAR_H }

    -- Tab buttons inside the title bar — three equal tabs, right-aligned
    -- Leave room on the left for the title text (~110px)
    local tab_avail = tb_w - 120
    local tab_w = math.floor((tab_avail - TAB_GAP * 2) / 3)
    local tab_h = TAB_H
    local tab_y = tb_y + math.floor((TITLE_BAR_H - tab_h) / 2)
    local tabs = { 'missing', 'owned', 'all' }
    local labels = { 'Missing', 'Owned', 'All' }

    for i, key in ipairs(tabs) do
        local tx = tb_x + 120 + (i - 1) * (tab_w + TAB_GAP)
        local on = (settings.mode == key)
        local bg_c  = on and C_TAB_ON  or C_TAB_OFF
        local txt_c = on and C_TAB_TXT_ON or C_TAB_TXT_OFF
        local bg = make_bg(tx, tab_y, tab_w, tab_h, bg_c)
        local label_text = labels[i]
        -- center text within the tab
        local label_x = tx + math.floor(tab_w / 2) - math.floor(#label_text * 6 / 2) - 2
        local txt = make_text(label_text, label_x, tab_y + 4, txt_c, 11, on)
        ui.el['tab_bg_' .. key]   = bg
        ui.el['tab_txt_' .. key]  = txt
        ui.rect['tab_' .. key]    = { x = tx, y = tab_y, w = tab_w, h = tab_h }
    end

    -- Body background
    local body_y = tb_y + TITLE_BAR_H
    local body_h = H - BORDER - TITLE_BAR_H - BORDER
    ui.el.body_bg = make_bg(tb_x, body_y, tb_w, body_h, C_BODY_BG)
    ui.rect.body = { x = tb_x, y = body_y, w = tb_w, h = body_h }

    -- Summary line at top of body
    ui.el.summary = make_text(summary,
        tb_x + PAD,
        body_y + PAD,
        C_SUMMARY, 11, true)

    -- Visible rows
    local row_x = tb_x + PAD
    local list_y0 = body_y + PAD + SUMMARY_H
    local visible = math.min(#rows, VISIBLE_ROWS)
    ui.scroll = math.min(ui.scroll, math.max(0, #rows - VISIBLE_ROWS))

    if #rows == 0 then
        local msg = (settings.mode == 'missing') and 'No missing trusts. Done!'
                 or (settings.mode == 'owned')   and 'No trusts learned yet.'
                 or 'No trusts in resources.'
        ui.el.empty = make_text(msg, row_x, list_y0 + 4, C_OWNED, 11)
    end

    for i = 1, visible do
        local data_idx = ui.scroll + i
        local entry = rows[data_idx]
        if entry then
            local ry = list_y0 + (i - 1) * ROW_H
            -- Subtle alternating row tint
            local row_bg
            if i % 2 == 0 then
                row_bg = make_bg(row_x - 2, ry - 1, tb_w - PAD * 2 + 4, ROW_H,
                                  { 90, 30, 40, 75 })
            end
            local prefix = (settings.mode == 'missing') and '- '
                        or (settings.mode == 'owned')   and '+ '
                        or '  '
            local known = windower.ffxi.get_spells() or {}
            local color = row_color
            if settings.mode == 'all' then
                color = known[entry.id] and C_OWNED or C_MISSING
                prefix = known[entry.id] and '+ ' or '- '
            end
            local row_txt = make_text(prefix .. entry.name, row_x, ry + 2, color, 10)
            table.insert(ui.rows, { bg = row_bg, text = row_txt })
        end
    end

    -- Scroll buttons (only when needed)
    if #rows > VISIBLE_ROWS then
        local btn_w = 40
        local btn_x = tb_x + tb_w - PAD - btn_w
        local up_y  = list_y0 + visible * ROW_H + PAD
        local dn_y  = up_y + SCROLL_BTN_H + 2

        local can_up = ui.scroll > 0
        local can_dn = ui.scroll < #rows - VISIBLE_ROWS

        ui.el.scroll_up_bg = make_bg(btn_x, up_y, btn_w, SCROLL_BTN_H,
            can_up and C_SCROLL_BG or C_SCROLL_OFF)
        ui.el.scroll_up_txt = make_text('▲', btn_x + 14, up_y + 3,
            can_up and C_SCROLL_TXT or C_SCROLL_TXT_OFF, 11, true)
        ui.rect.scroll_up = { x = btn_x, y = up_y, w = btn_w, h = SCROLL_BTN_H, enabled = can_up }

        ui.el.scroll_dn_bg = make_bg(btn_x, dn_y, btn_w, SCROLL_BTN_H,
            can_dn and C_SCROLL_BG or C_SCROLL_OFF)
        ui.el.scroll_dn_txt = make_text('▼', btn_x + 14, dn_y + 3,
            can_dn and C_SCROLL_TXT or C_SCROLL_TXT_OFF, 11, true)
        ui.rect.scroll_dn = { x = btn_x, y = dn_y, w = btn_w, h = SCROLL_BTN_H, enabled = can_dn }

        -- Position indicator
        local total = #rows - VISIBLE_ROWS
        local progress = (total > 0) and math.floor(100 * ui.scroll / total) or 0
        ui.el.scroll_pos = make_text(
            string.format('%d-%d / %d   %d%%', ui.scroll + 1, ui.scroll + visible, #rows, progress),
            tb_x + PAD, up_y + 4, C_SUMMARY, 10, false)
    end

    -- Show everything
    for _, e in pairs(ui.el) do show(e) end
    for _, r in ipairs(ui.rows) do
        if r.bg then show(r.bg) end
        show(r.text)
    end
end

local function show_window()
    settings.visible = true
    config.save(settings)
    build_window()
end

local function hide_window()
    settings.visible = false
    config.save(settings)
    destroy_window()
end

local function toggle_window()
    if settings.visible then hide_window() else show_window() end
end

local function refresh_window()
    if settings.visible then build_window() end
end

-- ---------------------------------------------------------------------------
-- Hit testing & mouse handling
-- ---------------------------------------------------------------------------

local function in_rect(x, y, r)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function is_over_window(x, y)
    if not settings.visible then return false end
    local W, H = ui.total_w, ui.total_h
    return x >= settings.pos.x and x <= settings.pos.x + W
        and y >= settings.pos.y and y <= settings.pos.y + H
end

local function scroll_by(delta)
    local rows = rows_for_mode()
    local max_scroll = math.max(0, #rows - VISIBLE_ROWS)
    ui.scroll = math.max(0, math.min(max_scroll, ui.scroll + delta))
    refresh_window()
end

windower.register_event('mouse', function(mtype, x, y, delta, blocked)
    if not settings.visible then return false end
    if blocked then return false end
    if not is_over_window(x, y) then return false end

    -- mtype: 1=move, 2=lmb_down, 3=lmb_up, 4=mmb_down, 5=mmb_up, 6=rmb_down,
    -- 7=rmb_up, 8=mouse_drag, 9=mwheel (delta = direction)
    if mtype == 1 then
        if ui.drag then
            settings.pos.x = x - ui.drag.dx
            settings.pos.y = y - ui.drag.dy
            build_window()  -- redraw at new pos
        end
        return true
    elseif mtype == 2 then  -- LMB down
        if in_rect(x, y, ui.rect.title_bar) then
            -- Check if click is on a tab first, otherwise start drag
            for _, key in ipairs({'missing','owned','all'}) do
                if in_rect(x, y, ui.rect['tab_' .. key]) then
                    if settings.mode ~= key then
                        settings.mode = key
                        ui.scroll = 0
                        config.save(settings)
                        build_window()
                    end
                    return true
                end
            end
            ui.drag = { dx = x - settings.pos.x, dy = y - settings.pos.y }
            return true
        elseif in_rect(x, y, ui.rect.scroll_up) and ui.rect.scroll_up.enabled then
            scroll_by(-VISIBLE_ROWS / 2)
            return true
        elseif in_rect(x, y, ui.rect.scroll_dn) and ui.rect.scroll_dn.enabled then
            scroll_by(VISIBLE_ROWS / 2)
            return true
        end
        return true  -- swallow click anywhere over the window
    elseif mtype == 3 then  -- LMB up
        if ui.drag then
            ui.drag = nil
            config.save(settings)
        end
        return true
    elseif mtype == 9 then  -- mouse wheel
        scroll_by(delta > 0 and -3 or 3)
        return true
    end

    return true  -- block all other mouse events that land on the window
end)

-- ---------------------------------------------------------------------------
-- Command dispatch
-- ---------------------------------------------------------------------------

windower.register_event('addon command', function(cmd, ...)
    cmd = (cmd or 'toggle'):lower()
    local args = {...}

    -- Bare //mt = toggle the window (most natural single-keystroke usage)
    if cmd == 'toggle' or cmd == 't' then
        toggle_window()
    elseif cmd == 'show' or cmd == 'window' or cmd == 'open' or cmd == 'w' then
        show_window()
    elseif cmd == 'hide' or cmd == 'close' then
        hide_window()
    elseif cmd == 'count' or cmd == 'summary' or cmd == 's' then
        cmd_count()
    elseif cmd == 'list' or cmd == 'missing' or cmd == 'l' then
        cmd_list_chat()
    elseif cmd == 'have' or cmd == 'owned' or cmd == 'h' then
        cmd_have_chat()
    elseif cmd == 'find' or cmd == 'search' or cmd == 'f' then
        cmd_find_chat(table.concat(args, ' '))
    elseif cmd == 'refresh' or cmd == 'r' then
        refresh_window()
        cmd_count()
    elseif cmd == 'help' or cmd == '?' then
        chat(CHAT_HEADER, '[MissingTrust] Commands:')
        chat(CHAT_ITEM, '  //mt              — toggle the window')
        chat(CHAT_ITEM, '  //mt show / hide  — show/hide the window')
        chat(CHAT_ITEM, '  //mt count        — one-line summary in chat')
        chat(CHAT_ITEM, '  //mt list         — list missing trusts in chat')
        chat(CHAT_ITEM, '  //mt have         — list owned trusts in chat')
        chat(CHAT_ITEM, '  //mt find <name>  — search by name fragment')
        chat(CHAT_ITEM, '  //mt refresh      — re-read spell book + redraw')
    else
        chat(CHAT_MISSING, '[MissingTrust] unknown command: ' .. cmd)
    end
end)

-- ---------------------------------------------------------------------------
-- Keyboard toggle (U key)
--
-- DIK_U = 22 (0x16). Toggle the window on U key DOWN, but skip the toggle
-- if chat is open so we don't intercept the user typing the letter 'u'.
-- The field name is `chat_open` (underscore) — see SESSION-NOTES gotcha F.
-- ---------------------------------------------------------------------------
local DIK_U = 22

windower.register_event('keyboard', function(dik, pressed, flags, blocked)
    if blocked then return end
    if not pressed then return end
    if dik ~= DIK_U then return end

    local info = windower.ffxi.get_info()
    if info and info.chat_open then return end

    toggle_window()
end)

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

windower.register_event('load', function()
    -- Defer a moment so the spell book is populated before we count
    coroutine.schedule(function()
        cmd_count()
        if settings.visible then build_window() end
    end, 2)
end)

windower.register_event('login', function()
    coroutine.schedule(function()
        cmd_count()
        refresh_window()
    end, 3)
end)

windower.register_event('zone change', function()
    -- Spell book can update from quests/zones — redraw quietly
    coroutine.schedule(refresh_window, 1)
end)

windower.register_event('unload', function()
    destroy_window()
end)
