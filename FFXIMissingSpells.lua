_addon.name     = 'FFXIMissingSpells'
_addon.author   = 'Jason'
_addon.version  = '1.0'
-- Bare //ms toggles the window. //mt is kept as a back-compat alias so
-- anyone who scripted the older FFXIMissingTrust commands keeps working.
_addon.commands = {'missingspells', 'mspells', 'ms', 'mt', 'mtrust'}

-- =============================================================================
-- FFXIMissingSpells
--
-- Shows which spells your character still needs to learn, broken out by
-- magic-using job. Same idea as FFXIMissingTrust but for the full spell
-- book — twelve job tabs across the top (WHM / BLM / RDM / PLD / DRK /
-- BRD / NIN / SMN / BLU / GEO / SCH / RUN), each listing every spell
-- the job can learn at lv 1-99 with a colored prefix:
--
--   - red  → you don't have this spell scrolled yet
--   + green → already learned
--
-- Filter sub-tabs in the title bar (Missing / Owned / All) cut the list
-- to whichever subset you care about.
--
-- Window:       //ms show | hide | toggle      (or just //ms)
-- Chat summary: //ms count               (current tab)
--               //ms count WHM
-- Chat list:    //ms list  | //ms list WHM    (missing for that job)
--               //ms have  | //ms have BLM    (owned)
--               //ms find <name>              (search across every job)
--
-- The data source is res.spells filtered by `spell.levels[job_id]` ≤ 99
-- (i.e. spells the job CAN learn natively, ignoring sub-job). Trust
-- spells are skipped — they have their own addon (FFXIMissingTrust /
-- now folded here is OPT-IN later; for now, trusts stay separate).
-- =============================================================================

require('luau')
local config = require('config')
local res    = require('resources')
local texts  = require('texts')
local images = require('images')

-- ---------------------------------------------------------------------------
-- Job list (tabs across the top of the window, in this exact order). Each
-- string MUST match res.jobs[id].ens for some id; the lookup below resolves
-- the numeric job id at load time so the rest of the code can stay textual.
-- ---------------------------------------------------------------------------
local JOB_TABS = { 'WHM','BLM','RDM','PLD','DRK','BRD','NIN','SMN','BLU','GEO','SCH','RUN' }

-- ens (e.g. 'WHM') → numeric job id. Populated from res.jobs at load.
local job_id_by_ens = {}
for jid, j in pairs(res.jobs) do
    if j and j.ens then job_id_by_ens[j.ens] = jid end
end

-- ---------------------------------------------------------------------------
-- Settings (persistent — saved to data/settings.xml)
-- ---------------------------------------------------------------------------
local defaults = {
    pos      = { x = 220, y = 220 },
    visible  = false,
    mode     = 'missing',    -- missing | owned | all
    job      = 'WHM',        -- one of JOB_TABS
}
local settings = config.load(defaults)

-- Guard against a stale settings file picking a job we no longer support.
local function is_valid_job(j)
    for _, v in ipairs(JOB_TABS) do if v == j then return true end end
    return false
end
if not is_valid_job(settings.job) then settings.job = 'WHM' end
config.save(settings)

-- ---------------------------------------------------------------------------
-- Visual constants — same family as FFXIMissingTrust (red/pink palette) so
-- the two windows feel like siblings.
-- ---------------------------------------------------------------------------
local BORDER       = 3
local TITLE_BAR_H  = 30
local JOB_TAB_H    = 22       -- new row beneath title bar holding 12 job tabs
local TAB_H        = 22
local TAB_GAP      = 4
local SUMMARY_H    = 26
local ROW_H        = 18
local SCROLL_BTN_H = 20
local PAD          = 8
local PANEL_W      = 640      -- wider than the Trust window to fit 12 job tabs
local VISIBLE_ROWS = 22

-- Colors (alpha, r, g, b)
local C_BORDER     = { 220, 70,  130, 200 }
local C_TITLE_BG   = { 240, 30,  60,  120 }
local C_TITLE_TXT  = { 255, 200, 200, 230 }
local C_BODY_BG    = { 200, 15,  15,  35  }
local C_JOB_BAR_BG = { 220, 20,  30,  60  }      -- background strip behind job tabs
local C_TAB_ON     = { 240, 50,  100, 180 }
local C_TAB_OFF    = { 180, 30,  40,  70  }
local C_TAB_TXT_ON = { 255, 255, 255, 255 }
local C_TAB_TXT_OFF= { 255, 160, 160, 200 }
local C_SUMMARY    = { 255, 230, 230, 150 }
local C_MISSING    = { 255, 255, 130, 130 }
local C_OWNED      = { 255, 130, 230, 130 }
local C_LEVEL      = { 255, 200, 200, 240 }      -- "[Lv 99]" prefix
local C_SKILL      = { 255, 170, 200, 230 }      -- skill-name column on the right
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
-- Data layer
-- ---------------------------------------------------------------------------

-- Friendly label for a spell's "skill" field. spell.skill is a numeric id
-- into res.skills, BUT the IDs in there cover combat skills too (Sword,
-- Hand-to-Hand, etc.) and not every spell has a skill set. Fall back to
-- spell.type (e.g. 'WhiteMagic', 'Ninjutsu', 'Geomancy') which is always
-- populated and is the more useful classification anyway.
local SKILL_LABEL = {
    WhiteMagic   = 'White',
    BlackMagic   = 'Black',
    DarkMagic    = 'Dark',
    DivineMagic  = 'Divine',
    Ninjutsu     = 'Ninjutsu',
    BlueMagic    = 'Blue',
    Geomancy     = 'Geomancy',
    Trust        = 'Trust',
    SummonerPact = 'Summoning',
    BardSong     = 'Song',
}
local function skill_label(spell)
    if not spell then return '' end
    -- Prefer the resource skill name if it's actually a magic skill
    if spell.skill and res.skills and res.skills[spell.skill] and res.skills[spell.skill].en then
        local en = res.skills[spell.skill].en
        -- res.skills mixes combat + magic; only the magic ones are useful here
        if SKILL_LABEL[en] or en:find('Magic') or en:find('Ninjutsu') or en:find('Song') or en:find('Summoning') or en:find('Geomancy') or en:find('Blue') then
            return en
        end
    end
    return SKILL_LABEL[spell.type] or spell.type or ''
end

-- Every spell the given job (ens like 'WHM') can natively learn at lv 1-cap.
-- Returns a list of { id, name, level, skill, type } sorted by level then
-- name. Trust spells are excluded (they have their own addon).
local function all_spells_for_job(ens, lv_cap)
    lv_cap = lv_cap or 99
    local jid = job_id_by_ens[ens]
    if not jid then return {} end
    local out = {}
    for id, spell in pairs(res.spells) do
        if spell and spell.en and spell.levels and spell.type ~= 'Trust' then
            local lv = spell.levels[jid]
            if lv and lv >= 0 and lv <= lv_cap then
                table.insert(out, {
                    id    = id,
                    name  = spell.en,
                    level = lv,
                    skill = skill_label(spell),
                    type  = spell.type or '',
                })
            end
        end
    end
    table.sort(out, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.name < b.name
    end)
    return out
end

local function partition_for_job(ens)
    local known = windower.ffxi.get_spells() or {}
    local owned, missing = {}, {}
    for _, s in ipairs(all_spells_for_job(ens)) do
        if known[s.id] then table.insert(owned, s)
        else                table.insert(missing, s) end
    end
    return owned, missing
end

-- Returns ({rows}, summary_line, row_color) for the current mode + job.
local function rows_for_view()
    local job = settings.job
    local owned, missing = partition_for_job(job)
    local total = #owned + #missing
    if settings.mode == 'owned' then
        return owned,
               string.format('%s   Owned: %d / %d', job, #owned, total),
               C_OWNED
    elseif settings.mode == 'all' then
        local everything = {}
        for _, s in ipairs(all_spells_for_job(job)) do table.insert(everything, s) end
        return everything,
               string.format('%s   All: %d  (owned %d, missing %d)', job, total, #owned, #missing),
               C_SUMMARY
    else
        return missing,
               string.format('%s   Missing: %d / %d', job, #missing, total),
               C_MISSING
    end
end

-- ---------------------------------------------------------------------------
-- Chat output
-- ---------------------------------------------------------------------------

local function chat(color, line) windower.add_to_chat(color, line) end

-- Resolves a user-supplied job arg to a canonical tab name, or nil. Empty
-- arg → falls back to the currently-selected tab so `//ms count` Just Works.
local function resolve_job_arg(arg)
    if not arg or arg == '' then return settings.job end
    arg = arg:upper()
    for _, j in ipairs(JOB_TABS) do if j == arg then return j end end
    return nil
end

local function cmd_count(arg)
    local job = resolve_job_arg(arg)
    if not job then chat(CHAT_MISSING, '[MissingSpells] unknown job "'..tostring(arg)..'"'); return end
    local owned, missing = partition_for_job(job)
    local total = #owned + #missing
    chat(CHAT_HEADER, string.format(
        '[MissingSpells] %s: %d / %d spells learned  (%d still needed)',
        job, #owned, total, #missing))
end

local function cmd_list_chat(arg)
    local job = resolve_job_arg(arg)
    if not job then chat(CHAT_MISSING, '[MissingSpells] unknown job "'..tostring(arg)..'"'); return end
    local _, missing = partition_for_job(job)
    if #missing == 0 then
        chat(CHAT_OWNED, '[MissingSpells] '..job..': every spell learned. Nice.')
        return
    end
    chat(CHAT_HEADER, string.format('[MissingSpells] %s: %d spells still needed:', job, #missing))
    for _, s in ipairs(missing) do
        chat(CHAT_MISSING, string.format('  - [Lv %2d]  %-22s  (%s)', s.level, s.name, s.skill))
    end
end

local function cmd_have_chat(arg)
    local job = resolve_job_arg(arg)
    if not job then chat(CHAT_MISSING, '[MissingSpells] unknown job "'..tostring(arg)..'"'); return end
    local owned = partition_for_job(job)
    if #owned == 0 then
        chat(CHAT_MISSING, '[MissingSpells] '..job..': no spells learned yet.')
        return
    end
    chat(CHAT_HEADER, string.format('[MissingSpells] %s: %d spells learned:', job, #owned))
    for _, s in ipairs(owned) do
        chat(CHAT_OWNED, string.format('  + [Lv %2d]  %-22s  (%s)', s.level, s.name, s.skill))
    end
end

-- Search across every job, since the user might not know which job a given
-- spell name belongs to. Marks each hit with [LEARNED] or [MISSING].
local function cmd_find_chat(query)
    if not query or query == '' then
        chat(CHAT_MISSING, '[MissingSpells] usage: //ms find <name fragment>')
        return
    end
    query = query:lower()
    local known = windower.ffxi.get_spells() or {}
    local hits = 0
    chat(CHAT_HEADER, string.format('[MissingSpells] Spells matching "%s":', query))
    -- Iterate res.spells directly so we get matches across every job, not
    -- only the magic-using ones tabbed in the window.
    local seen = {}
    for id, spell in pairs(res.spells) do
        if spell and spell.en and spell.type ~= 'Trust' and spell.en:lower():find(query, 1, true) and not seen[id] then
            seen[id] = true
            hits = hits + 1
            -- Find which of our tabbed jobs can learn it
            local jobs = {}
            if spell.levels then
                for _, ens in ipairs(JOB_TABS) do
                    local jid = job_id_by_ens[ens]
                    if jid and spell.levels[jid] then
                        table.insert(jobs, string.format('%s@%d', ens, spell.levels[jid]))
                    end
                end
            end
            local job_str = (#jobs > 0) and table.concat(jobs, ' ') or '(no tabbed job)'
            if known[id] then
                chat(CHAT_OWNED,   string.format('  + %-22s  %s   [LEARNED]', spell.en, job_str))
            else
                chat(CHAT_MISSING, string.format('  - %-22s  %s   [MISSING]', spell.en, job_str))
            end
        end
    end
    if hits == 0 then chat(CHAT_ITEM, '  (no spells match)') end
end

-- ---------------------------------------------------------------------------
-- Window UI
-- ---------------------------------------------------------------------------

local ui = {
    el        = {},
    rows      = {},
    scroll    = 0,
    drag      = nil,
    rect      = {},
    total_w   = PANEL_W,
    total_h   = 0,
}

local function calc_dims(row_count)
    local visible = math.min(row_count, VISIBLE_ROWS)
    local body_h  = SUMMARY_H + PAD + (visible * ROW_H)
    if row_count > VISIBLE_ROWS then
        body_h = body_h + PAD + SCROLL_BTN_H + 2 + SCROLL_BTN_H
    end
    body_h = body_h + PAD * 2
    -- Total = borders + title bar + job-tab strip + body
    ui.total_h = BORDER * 2 + TITLE_BAR_H + JOB_TAB_H + body_h
end

local function destroy_window()
    for _, e in pairs(ui.el)   do destroy(e) end
    for _, r in ipairs(ui.rows) do
        destroy(r.bg); destroy(r.lv); destroy(r.name); destroy(r.skill)
    end
    ui.el = {}
    ui.rows = {}
    ui.rect = {}
end

local function build_window()
    destroy_window()

    local rows, summary, row_color = rows_for_view()
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
    ui.el.title_text = make_text('FFXIMissingSpells', tb_x + PAD, tb_y + 7, C_TITLE_TXT, 11, true)
    ui.rect.title_bar = { x = tb_x, y = tb_y, w = tb_w, h = TITLE_BAR_H }

    -- Mode tabs in the title bar (right-aligned): Missing | Owned | All.
    -- 3 equal-width buttons, leaving room for the title text on the left.
    local mode_avail = tb_w - 140
    local mode_tab_w = math.floor((mode_avail - TAB_GAP * 2) / 3)
    local mode_tab_y = tb_y + math.floor((TITLE_BAR_H - TAB_H) / 2)
    local mode_origin_x = tb_x + 140
    -- Push tabs to the right edge of the title bar so the title text stays
    -- visually balanced.
    local mode_total_w = mode_tab_w * 3 + TAB_GAP * 2
    local mode_right_x = tb_x + tb_w - PAD - mode_total_w
    if mode_right_x > mode_origin_x then mode_origin_x = mode_right_x end

    local modes  = { 'missing', 'owned', 'all' }
    local mlabels = { 'Missing', 'Owned', 'All' }
    for i, key in ipairs(modes) do
        local tx = mode_origin_x + (i - 1) * (mode_tab_w + TAB_GAP)
        local on = (settings.mode == key)
        local bg_c  = on and C_TAB_ON  or C_TAB_OFF
        local txt_c = on and C_TAB_TXT_ON or C_TAB_TXT_OFF
        local bg = make_bg(tx, mode_tab_y, mode_tab_w, TAB_H, bg_c)
        local label = mlabels[i]
        local label_x = tx + math.floor(mode_tab_w / 2) - math.floor(#label * 6 / 2) - 2
        local txt = make_text(label, label_x, mode_tab_y + 4, txt_c, 11, on)
        ui.el['mode_bg_' .. key]   = bg
        ui.el['mode_txt_' .. key]  = txt
        ui.rect['mode_' .. key]    = { x = tx, y = mode_tab_y, w = mode_tab_w, h = TAB_H }
    end

    -- Job tab strip (one row of 12 tabs immediately below the title bar)
    local jt_x = tb_x
    local jt_y = tb_y + TITLE_BAR_H
    local jt_w = tb_w
    ui.el.job_bar = make_bg(jt_x, jt_y, jt_w, JOB_TAB_H, C_JOB_BAR_BG)

    local job_avail = jt_w - PAD * 2
    local job_count = #JOB_TABS
    local job_tab_w = math.floor((job_avail - TAB_GAP * (job_count - 1)) / job_count)
    local job_tab_y = jt_y + math.floor((JOB_TAB_H - TAB_H) / 2)
    for i, jb in ipairs(JOB_TABS) do
        local tx = jt_x + PAD + (i - 1) * (job_tab_w + TAB_GAP)
        local on = (settings.job == jb)
        local bg_c  = on and C_TAB_ON  or C_TAB_OFF
        local txt_c = on and C_TAB_TXT_ON or C_TAB_TXT_OFF
        local bg = make_bg(tx, job_tab_y, job_tab_w, TAB_H, bg_c)
        local label = jb
        local label_x = tx + math.floor(job_tab_w / 2) - math.floor(#label * 6 / 2) - 2
        local txt = make_text(label, label_x, job_tab_y + 4, txt_c, 11, on)
        ui.el['jtab_bg_' .. jb]   = bg
        ui.el['jtab_txt_' .. jb]  = txt
        ui.rect['jtab_' .. jb]    = { x = tx, y = job_tab_y, w = job_tab_w, h = TAB_H }
    end

    -- Body background (below the job tab strip)
    local body_y = jt_y + JOB_TAB_H
    local body_h = H - BORDER - TITLE_BAR_H - JOB_TAB_H - BORDER
    ui.el.body_bg = make_bg(tb_x, body_y, tb_w, body_h, C_BODY_BG)
    ui.rect.body = { x = tb_x, y = body_y, w = tb_w, h = body_h }

    -- Summary line at top of body
    ui.el.summary = make_text(summary, tb_x + PAD, body_y + PAD, C_SUMMARY, 11, true)

    -- Visible rows
    local row_x = tb_x + PAD
    local list_y0 = body_y + PAD + SUMMARY_H
    local visible = math.min(#rows, VISIBLE_ROWS)
    ui.scroll = math.min(ui.scroll, math.max(0, #rows - VISIBLE_ROWS))

    if #rows == 0 then
        local msg = (settings.mode == 'missing') and ('No missing spells for ' .. settings.job .. '. Done!')
                 or (settings.mode == 'owned')   and (settings.job .. ': no spells learned yet.')
                 or (settings.job .. ': no spells in resources.')
        ui.el.empty = make_text(msg, row_x, list_y0 + 4, C_OWNED, 11)
    end

    -- Column layout: [Lv NN]   spell name                 (skill)
    --   lv      at row_x
    --   name    at row_x + 70
    --   skill   right-aligned ~ row_x + tb_w - 110
    local lv_col_x    = row_x
    local name_col_x  = row_x + 70
    local skill_col_x = tb_x + tb_w - PAD - 90

    local known = windower.ffxi.get_spells() or {}
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
            -- In ALL mode, color each row by ownership instead of using the
            -- single mode-wide color.
            local color = row_color
            local prefix
            if settings.mode == 'all' then
                color  = known[entry.id] and C_OWNED or C_MISSING
                prefix = known[entry.id] and '+' or '-'
            else
                prefix = (settings.mode == 'missing') and '-' or '+'
            end
            local lv_str    = string.format('%s [Lv %2d]', prefix, entry.level)
            local lv_text   = make_text(lv_str, lv_col_x, ry + 2, C_LEVEL, 10)
            local name_text = make_text(entry.name, name_col_x, ry + 2, color, 10)
            local skill_text= make_text(entry.skill, skill_col_x, ry + 2, C_SKILL, 10, false)
            table.insert(ui.rows, { bg = row_bg, lv = lv_text, name = name_text, skill = skill_text })
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

        local total_scroll = #rows - VISIBLE_ROWS
        local progress = (total_scroll > 0) and math.floor(100 * ui.scroll / total_scroll) or 0
        ui.el.scroll_pos = make_text(
            string.format('%d-%d / %d   %d%%', ui.scroll + 1, ui.scroll + visible, #rows, progress),
            tb_x + PAD, up_y + 4, C_SUMMARY, 10, false)
    end

    -- Show everything
    for _, e in pairs(ui.el) do show(e) end
    for _, r in ipairs(ui.rows) do
        if r.bg then show(r.bg) end
        show(r.lv)
        show(r.name)
        show(r.skill)
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
    local rows = rows_for_view()
    local max_scroll = math.max(0, #rows - VISIBLE_ROWS)
    ui.scroll = math.max(0, math.min(max_scroll, ui.scroll + delta))
    refresh_window()
end

-- Windower mouse event types: 0=move, 1=LMB down, 2=LMB up, 10=wheel.
-- See SESSION-NOTES gotcha F (FFXIMissingTrust) for full mapping.
windower.register_event('mouse', function(mtype, x, y, delta, blocked)
    if not settings.visible then return false end
    if blocked then return false end

    -- Mouse MOVE — follow the drag even if the cursor leaves the window
    if mtype == 0 then
        if ui.drag then
            settings.pos.x = x - ui.drag.dx
            settings.pos.y = y - ui.drag.dy
            build_window()
            return true
        end
        return is_over_window(x, y)
    end

    -- LMB UP — release the drag regardless of cursor position
    if mtype == 2 then
        if ui.drag then
            ui.drag = nil
            config.save(settings)
            return true
        end
        return is_over_window(x, y)
    end

    if not is_over_window(x, y) then return false end

    -- LMB DOWN — mode tab, job tab, scroll button, or start a drag
    if mtype == 1 then
        -- Title-bar mode tabs (Missing / Owned / All)
        if in_rect(x, y, ui.rect.title_bar) then
            for _, key in ipairs({'missing','owned','all'}) do
                if in_rect(x, y, ui.rect['mode_' .. key]) then
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
        end

        -- Job tabs (one row, twelve tabs)
        for _, jb in ipairs(JOB_TABS) do
            if in_rect(x, y, ui.rect['jtab_' .. jb]) then
                if settings.job ~= jb then
                    settings.job = jb
                    ui.scroll = 0
                    config.save(settings)
                    build_window()
                end
                return true
            end
        end

        if ui.rect.scroll_up and in_rect(x, y, ui.rect.scroll_up) and ui.rect.scroll_up.enabled then
            scroll_by(-math.floor(VISIBLE_ROWS / 2))
            return true
        end
        if ui.rect.scroll_dn and in_rect(x, y, ui.rect.scroll_dn) and ui.rect.scroll_dn.enabled then
            scroll_by(math.floor(VISIBLE_ROWS / 2))
            return true
        end
        return true
    end

    -- Scroll wheel
    if mtype == 10 then
        scroll_by(delta > 0 and -3 or 3)
        return true
    end

    return true     -- block stray events over the window (no camera rotation)
end)

-- ---------------------------------------------------------------------------
-- Command dispatch
-- ---------------------------------------------------------------------------

windower.register_event('addon command', function(cmd, ...)
    cmd = (cmd or 'toggle'):lower()
    local args = {...}

    if cmd == 'toggle' or cmd == 't' then
        toggle_window()
    elseif cmd == 'show' or cmd == 'window' or cmd == 'open' or cmd == 'w' then
        show_window()
    elseif cmd == 'hide' or cmd == 'close' then
        hide_window()

    elseif cmd == 'count' or cmd == 'summary' or cmd == 's' then
        cmd_count(args[1])
    elseif cmd == 'list' or cmd == 'missing' or cmd == 'l' then
        cmd_list_chat(args[1])
    elseif cmd == 'have' or cmd == 'owned' or cmd == 'h' then
        cmd_have_chat(args[1])
    elseif cmd == 'find' or cmd == 'search' or cmd == 'f' then
        cmd_find_chat(table.concat(args, ' '))

    -- Direct tab-switch shortcuts: //ms whm, //ms blm, ...
    elseif resolve_job_arg(cmd) then
        settings.job = resolve_job_arg(cmd)
        config.save(settings)
        refresh_window()
        cmd_count(settings.job)

    elseif cmd == 'mode' then
        local m = args[1] and args[1]:lower()
        if m == 'missing' or m == 'owned' or m == 'all' then
            settings.mode = m
            config.save(settings)
            refresh_window()
        else
            chat(CHAT_MISSING, '[MissingSpells] mode is missing | owned | all')
        end

    elseif cmd == 'refresh' or cmd == 'r' then
        refresh_window()
        cmd_count(settings.job)
    elseif cmd == 'help' or cmd == '?' then
        chat(CHAT_HEADER, '[MissingSpells] Commands:')
        chat(CHAT_ITEM, '  //ms              — toggle the window')
        chat(CHAT_ITEM, '  //ms show / hide  — show/hide the window')
        chat(CHAT_ITEM, '  //ms <JOB>        — switch tabs ( //ms blm )')
        chat(CHAT_ITEM, '  //ms count [JOB]  — one-line summary')
        chat(CHAT_ITEM, '  //ms list  [JOB]  — list missing spells in chat')
        chat(CHAT_ITEM, '  //ms have  [JOB]  — list owned spells in chat')
        chat(CHAT_ITEM, '  //ms find <name>  — search across every job')
        chat(CHAT_ITEM, '  //ms mode <missing|owned|all>')
        chat(CHAT_ITEM, '  //ms refresh      — re-read spell book + redraw')
    else
        chat(CHAT_MISSING, '[MissingSpells] unknown command: ' .. cmd)
    end
end)

-- ---------------------------------------------------------------------------
-- Keyboard toggle (U key) — same scancode FFXIMissingTrust used.
-- Skip while chat is open so we don't intercept typing.
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
    coroutine.schedule(function()
        cmd_count(settings.job)
        if settings.visible then build_window() end
    end, 2)
end)

windower.register_event('login', function()
    coroutine.schedule(function()
        cmd_count(settings.job)
        refresh_window()
    end, 3)
end)

windower.register_event('zone change', function()
    coroutine.schedule(refresh_window, 1)
end)

windower.register_event('unload', function()
    destroy_window()
end)
