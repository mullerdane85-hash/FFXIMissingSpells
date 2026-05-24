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
-- Trust → Job mapping
--
-- FFXI's spell data doesn't expose which combat job each trust represents
-- (the `jobs` field on spells.lua is the list of jobs that can CAST it, and
-- for trusts that's effectively all jobs at level 1). So we hardcode the
-- association here. Entries with "?" are obscure / Voidwatch trusts whose
-- in-game job I'm not 100% sure of — feel free to edit this table.
--
-- This is in alphabetical order to make it easy to update.
-- ---------------------------------------------------------------------------
local JOB_BY_TRUST = {
    -- AA-prefix trusts (Vagary "Five Atma Avatars" — best-effort)
    ["AAEV"]             = "?",
    ["AAGK"]             = "?",
    ["AAHM"]             = "?",
    ["AAMR"]             = "?",
    ["AATT"]             = "?",

    ["Abenzio"]          = "THF",
    ["Abquhbah"]         = "WAR",
    ["Adelheid"]         = "SCH",
    ["Ajido-Marujido"]   = "BLM",
    ["Aldo"]             = "THF",
    ["Aldo (UC)"]        = "THF",
    ["Amchuchu"]         = "RUN",
    ["Apururu (UC)"]     = "WHM",
    ["Arciela"]          = "RDM",
    ["Arciela II"]       = "RDM",
    ["Areuhat"]          = "DRK",
    ["August"]           = "PLD",
    ["Ayame"]            = "SAM",
    ["Ayame (UC)"]       = "SAM",
    ["Babban"]           = "DNC",
    ["Balamor"]          = "DRK",
    ["Brygid"]           = "WHM",
    ["Chacharoon"]       = "THF",
    ["Cherukiki"]        = "WHM",
    ["Cid"]              = "WAR",
    ["Cornelia"]         = "MNK",
    ["Curilla"]          = "PLD",
    ["D. Shantotto"]     = "BLM",
    ["Darrcuiln"]        = "WAR",
    ["Elivira"]          = "RDM",
    ["Excenmille"]       = "PLD",
    ["Excenmille [S]"]   = "PLD",
    ["Fablinix"]         = "THF",
    ["Ferreous Coffin"]  = "WHM",
    ["Flaviria (UC)"]    = "DRG",
    ["Gadalar"]          = "BLM",
    ["Gessho"]           = "NIN",
    ["Gilgamesh"]        = "SAM",
    ["Halver"]           = "PLD",
    ["I. Shield (UC)"]   = "PLD",
    ["Ingrid"]           = "PLD",
    ["Ingrid II"]        = "PLD",
    ["Iroha"]            = "SAM",
    ["Iroha II"]         = "SAM",
    ["Iron Eater"]       = "WAR",
    ["Jakoh (UC)"]       = "WAR",
    ["Joachim"]          = "BRD",
    ["Karaha-Baruha"]    = "WHM",
    ["Kayeel-Payeel"]    = "BLM",
    ["King of Hearts"]   = "PLD",
    ["Klara"]            = "WAR",
    ["Koru-Moru"]        = "RDM",
    ["Kukki-Chebukki"]   = "THF",
    ["Kupipi"]           = "WHM",
    ["Kupofried"]        = "GEO",
    ["Kuyin Hathdenna"]  = "DRG",
    ["Lehko Habhoka"]    = "THF",
    ["Leonoyne"]         = "DRG",
    ["Lhe Lhangavo"]     = "MNK",
    ["Lhu Mhakaracca"]   = "BST",
    ["Lilisette"]        = "DNC",
    ["Lilisette II"]     = "DNC",
    ["Lion"]             = "THF",
    ["Lion II"]          = "THF",
    ["Luzaf"]            = "COR",
    ["Maat"]             = "MNK",
    ["Maat (UC)"]        = "MNK",
    ["Makki-Chebukki"]   = "THF",
    ["Margret"]          = "RNG",
    ["Matsui-P"]         = "GEO",
    ["Maximilian"]       = "PLD",
    ["Mayakov"]          = "DNC",
    ["Mihli Aliapoh"]    = "WHM",
    ["Mildaurion"]       = "WHM",
    ["Mnejing"]          = "WAR",
    ["Monberaux"]        = "WHM",
    ["Moogle"]           = "RDM",
    ["Morimar"]          = "BST",
    ["Mumor"]            = "DNC",
    ["Mumor II"]         = "BRD",
    ["Naja (UC)"]        = "WAR",
    ["Naja Salaheem"]    = "WAR",
    ["Najelith"]         = "RNG",
    ["Naji"]             = "THF",
    ["Nanaa Mihgo"]      = "THF",
    ["Nashmeira"]        = "WHM",
    ["Nashmeira II"]     = "PUP",
    ["Noillurie"]        = "WHM",
    ["Ovjang"]           = "RDM",
    ["Pieuje (UC)"]      = "WHM",
    ["Prishe"]           = "MNK",
    ["Prishe II"]        = "MNK",
    ["Qultada"]          = "COR",
    ["Rahal"]            = "PLD",
    ["Rainemard"]        = "RDM",
    ["Robel-Akbel"]      = "BLM",
    ["Romaa Mihgo"]      = "THF",
    ["Rongelouts"]       = "PLD",
    ["Rosulatia"]        = "SCH",
    ["Rughadjeen"]       = "PLD",
    ["Sakura"]           = "NIN",
    ["Selh'teus"]        = "DRG",
    ["Semih Lafihna"]    = "RNG",
    ["Shantotto"]        = "BLM",
    ["Shantotto II"]     = "BLM",
    ["Shikaree Z"]       = "RNG",
    ["Star Sibyl"]       = "WHM",
    ["Sylvie (UC)"]      = "GEO",
    ["Tenzen"]           = "SAM",
    ["Tenzen II"]        = "SAM",
    ["Teodor"]           = "BLM",
    ["Trion"]            = "PLD",
    ["Uka Totlihn"]      = "DNC",
    ["Ullegore"]         = "DRK",
    ["Ulmia"]            = "BRD",
    ["Valaineral"]       = "PLD",
    ["Volker"]           = "WAR",
    ["Ygnas"]            = "WAR",
    ["Yoran-Oran (UC)"]  = "WHM",
    ["Zazarg"]           = "MNK",
    ["Zeid"]             = "DRK",
    ["Zeid II"]          = "DRK",
}

local function trust_job(name) return JOB_BY_TRUST[name] or "?" end

-- ---------------------------------------------------------------------------
-- Trust → Role descriptor
--
-- Format kept deliberately short:
--   "Tank"
--   "Healer"
--   "DPS Melee <weapon>"   (H2H, Sword, GA, GS, Scythe, Dagger, Katana, GK,
--                           Polearm, Axe, Club, Staff)
--   "DPS Ranged <weapon>"  (Bow, Gun)
--   "DPS Magic"
--   "Support"              (alone if generic)
--   "Support <aura>"       (e.g. Honor March, Refresh, Haste II)
--
-- Role categorization from BG-Wiki; weapon from each trust's wiki page.
-- Source: https://www.bg-wiki.com/ffxi/BGWiki:Trusts
-- ---------------------------------------------------------------------------
local DESC_BY_TRUST = {
    -- Ark Angel (Vagary) trusts — Five Race Avatars
    ["AAEV"]              = "Tank",                  -- Elvaan, PLD-style
    ["AAGK"]              = "DPS Melee GA",          -- Galka, WAR-style
    ["AAHM"]              = "Tank",                  -- Hume male, SAM/PLD
    ["AAMR"]              = "DPS Melee Dagger",      -- Mithra
    ["AATT"]              = "DPS Magic",             -- Tarutaru BLM

    ["Abenzio"]           = "DPS Melee Dagger",
    ["Abquhbah"]          = "DPS Melee Axe",
    ["Adelheid"]          = "DPS Magic",             -- SCH, nukes + stun
    ["Ajido-Marujido"]    = "DPS Magic",
    ["Aldo"]              = "DPS Melee Dagger",
    ["Amchuchu"]          = "Tank",
    ["Areuhat"]           = "DPS Melee Scythe",
    ["Arciela"]           = "Support Debuffs",
    ["Arciela II"]        = "Support Debuffs",
    ["August"]            = "Tank",
    ["Ayame"]             = "DPS Melee GK",
    ["Babban"]            = "DPS Melee Dagger",
    ["Balamor"]           = "DPS Melee Sword",
    ["Brygid"]            = "Support Erase",
    ["Chacharoon"]        = "DPS Melee Dagger",
    ["Cherukiki"]         = "Healer",
    ["Cid"]               = "DPS Melee GA",
    ["Cornelia"]          = "DPS Melee H2H",
    ["Curilla"]           = "Tank",
    ["D. Shantotto"]      = "DPS Magic",
    ["Darrcuiln"]         = "DPS Melee H2H",         -- beastform
    ["Elivira"]           = "DPS Ranged Bow",
    ["Excenmille"]        = "Tank",
    ["Excenmille [S]"]    = "Tank",
    ["Fablinix"]          = "DPS Melee Dagger",
    ["Ferreous Coffin"]   = "Healer",
    ["Gadalar"]           = "DPS Magic",
    ["Gessho"]            = "Tank",                  -- NIN tank, shadows
    ["Gilgamesh"]         = "DPS Melee GK",
    ["Halver"]            = "Tank",
    ["Ingrid"]            = "DPS Magic",
    ["Ingrid II"]         = "DPS Melee Sword",
    ["Iroha"]             = "DPS Melee GK",
    ["Iroha II"]          = "DPS Melee GK",
    ["Iron Eater"]        = "DPS Melee GA",
    ["Joachim"]           = "Support Honor March",
    ["Karaha-Baruha"]     = "Healer",
    ["Kayeel-Payeel"]     = "DPS Magic",
    ["King of Hearts"]    = "Support Haste",
    ["Klara"]             = "DPS Ranged Gun",
    ["Koru-Moru"]         = "Support Haste II/Refresh II",
    ["Kukki-Chebukki"]    = "DPS Magic",
    ["Kupipi"]            = "Healer",
    ["Kupofried"]         = "Support Refresh",
    ["Kuyin Hathdenna"]   = "Support",
    ["Lehko Habhoka"]     = "DPS Melee Dagger",
    ["Leonoyne"]          = "DPS Magic",
    ["Lhe Lhangavo"]      = "DPS Melee H2H",
    ["Lhu Mhakaracca"]    = "DPS Melee + Pet",       -- BST
    ["Lilisette"]         = "DPS Melee Dagger",
    ["Lilisette II"]      = "DPS Melee Dagger",
    ["Lion"]              = "DPS Melee Dagger",
    ["Lion II"]           = "DPS Melee Dagger",
    ["Luzaf"]             = "DPS Ranged Gun",
    ["Maat"]              = "DPS Melee H2H",
    ["Makki-Chebukki"]    = "DPS Ranged Bow",
    ["Margret"]           = "DPS Ranged Bow",
    ["Matsui-P"]          = "Support GEO",
    ["Maximilian"]        = "Tank",
    ["Mayakov"]           = "DPS Melee Dagger",
    ["Mihli Aliapoh"]     = "Healer",
    ["Mildaurion"]        = "DPS Melee Sword",
    ["Mnejing"]           = "Tank",
    ["Monberaux"]         = "Healer",
    ["Moogle"]            = "Support",
    ["Morimar"]           = "DPS Melee + Pet",       -- BST
    ["Mumor"]             = "DPS Melee Dagger",
    ["Mumor II"]          = "Support Songs",
    ["Naja Salaheem"]     = "DPS Melee GA",
    ["Najelith"]          = "DPS Ranged Bow",
    ["Naji"]              = "DPS Melee Dagger",
    ["Nanaa Mihgo"]       = "DPS Melee Dagger",
    ["Nashmeira"]         = "DPS Melee Sword",
    ["Nashmeira II"]      = "DPS Melee + Auto",      -- PUP
    ["Noillurie"]         = "DPS Melee H2H",
    ["Ovjang"]            = "Support Debuffs",
    ["Prishe"]            = "DPS Melee H2H",
    ["Prishe II"]         = "DPS Melee H2H",
    ["Qultada"]           = "Support COR Rolls",
    ["Rahal"]             = "Tank",
    ["Rainemard"]         = "DPS Melee Sword",
    ["Robel-Akbel"]       = "DPS Magic",
    ["Romaa Mihgo"]       = "DPS Melee Dagger",
    ["Rongelouts"]        = "Tank",
    ["Rosulatia"]         = "DPS Magic",
    ["Rughadjeen"]        = "Tank",
    ["Sakura"]            = "DPS Melee Katana",
    ["Selh'teus"]         = "DPS Melee Polearm",
    ["Semih Lafihna"]     = "DPS Ranged Bow",
    ["Shantotto"]         = "DPS Magic",
    ["Shantotto II"]      = "DPS Magic",
    ["Shikaree Z"]        = "DPS Ranged Bow",
    ["Star Sibyl"]        = "Support",
    ["Tenzen"]            = "DPS Melee GK",
    ["Tenzen II"]         = "DPS Ranged Bow",
    ["Teodor"]            = "DPS Magic",
    ["Trion"]             = "Tank",
    ["Uka Totlihn"]       = "DPS Melee Dagger",
    ["Ullegore"]          = "DPS Magic",
    ["Ulmia"]             = "Support Songs",
    ["Valaineral"]        = "Tank",
    ["Volker"]            = "DPS Melee GA",
    ["Ygnas"]             = "Healer",
    ["Zazarg"]            = "DPS Melee H2H",
    ["Zeid"]              = "DPS Melee GS",
    ["Zeid II"]           = "DPS Melee GS",
}

local function trust_desc(name) return DESC_BY_TRUST[name] or "" end

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
local PANEL_W      = 560
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

-- Unity Concord (UC) trusts are awarded via Unity rank with their respective
-- leader, NOT via ciphers / quests / the regular trust acquisition path. They
-- don't belong in a "what trusts do I still need" list — filter them out at
-- the source so Missing / Owned / All views and the count are all consistent.
local function is_unity_concord(spell_name)
    return spell_name:find('%(UC%)') ~= nil
end

local function all_trusts()
    local out = {}
    for id, spell in pairs(res.spells) do
        if spell.type == 'Trust' and not is_unity_concord(spell.en) then
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
    for _, t in ipairs(missing) do
        chat(CHAT_MISSING, string.format('  - %-22s [%s]  %s',
            t.name, trust_job(t.name), trust_desc(t.name)))
    end
end

local function cmd_have_chat()
    local owned = partition()
    if #owned == 0 then
        chat(CHAT_MISSING, '[MissingTrust] You have no trusts learned yet.')
        return
    end
    chat(CHAT_HEADER, string.format('[MissingTrust] %d trusts learned:', #owned))
    for _, t in ipairs(owned) do
        chat(CHAT_OWNED, string.format('  + %-22s [%s]  %s',
            t.name, trust_job(t.name), trust_desc(t.name)))
    end
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
            local job = trust_job(t.name)
            local desc = trust_desc(t.name)
            if known[t.id] then
                chat(CHAT_OWNED,   string.format('  + %-22s [%s]  %s   (learned)', t.name, job, desc))
            else
                chat(CHAT_MISSING, string.format('  - %-22s [%s]  %s   (missing)', t.name, job, desc))
            end
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
    for _, r in ipairs(ui.rows) do destroy(r.bg); destroy(r.text); destroy(r.job); destroy(r.desc) end
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

    -- Column layout: name | job | role+style descriptor
    --   name starts at row_x
    --   job column at row_x + 170 (~22 chars of name fits)
    --   desc column at row_x + 220 (5 chars for job)
    local name_col_x = row_x
    local job_col_x  = row_x + 170
    local desc_col_x = row_x + 215

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
            local name_text = make_text(prefix .. entry.name, name_col_x, ry + 2, color, 10)
            local job_text  = make_text(trust_job(entry.name), job_col_x, ry + 2, C_SUMMARY, 10, true)
            local desc_text = make_text(trust_desc(entry.name), desc_col_x, ry + 2, C_SUMMARY, 10, false)
            table.insert(ui.rows, { bg = row_bg, text = name_text, job = job_text, desc = desc_text })
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
        if r.job then show(r.job) end
        if r.desc then show(r.desc) end
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

-- Windower mouse event types (verified from GSUI's handler):
--   0  = mouse move
--   1  = left button down
--   2  = left button up
--   3  = right button down
--   4  = right button up
--   5  = middle button down
--   6  = middle button up
--   10 = scroll wheel  (delta > 0 = up, delta < 0 = down)
windower.register_event('mouse', function(mtype, x, y, delta, blocked)
    if not settings.visible then return false end
    if blocked then return false end

    -- Mouse MOVE — follow the drag even if the cursor leaves the window
    -- bounds; otherwise a fast drag would "lose" the window when the
    -- cursor outraces the redraw.
    if mtype == 0 then
        if ui.drag then
            settings.pos.x = x - ui.drag.dx
            settings.pos.y = y - ui.drag.dy
            build_window()
            return true
        end
        return is_over_window(x, y)  -- swallow hovers over our window only
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

    -- The remaining events only apply when the cursor is over the window
    if not is_over_window(x, y) then return false end

    -- LMB DOWN — tab click, scroll buttons, or start drag
    if mtype == 1 then
        if in_rect(x, y, ui.rect.title_bar) then
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
            -- Title bar but not a tab — start drag
            ui.drag = { dx = x - settings.pos.x, dy = y - settings.pos.y }
            return true
        end

        if ui.rect.scroll_up and in_rect(x, y, ui.rect.scroll_up) and ui.rect.scroll_up.enabled then
            scroll_by(-math.floor(VISIBLE_ROWS / 2))
            return true
        end
        if ui.rect.scroll_dn and in_rect(x, y, ui.rect.scroll_dn) and ui.rect.scroll_dn.enabled then
            scroll_by(math.floor(VISIBLE_ROWS / 2))
            return true
        end
        return true  -- swallow stray clicks on the panel
    end

    -- SCROLL WHEEL — delta > 0 means wheel-up (scroll list up = earlier items)
    if mtype == 10 then
        scroll_by(delta > 0 and -3 or 3)
        return true
    end

    return true  -- block right-click etc. when over the window so it doesn't rotate the camera
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
