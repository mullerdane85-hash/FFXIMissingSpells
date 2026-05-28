-- Hand-curated acquisition entries for spells that weren't in the original
-- formatted_spells.csv. These cover summoner avatar quests, BLM/RDM +ga and
-- -V tier upgrades, BRD higher-tier songs, NIN scroll lines, and a handful
-- of WHM upgrades.
--
-- Where the exact quest name is well-known I list it; where it's a class
-- of source (RoE, Job Point gift, etc.) the entry just notes the category.
-- BG-Wiki is the authoritative source for the specifics — if anything
-- here is wrong, the in-line short tag is generic enough that it still
-- points the user in the right direction.
--
-- Sourced from FFXI common knowledge; cross-check on BG-Wiki for exact
-- text if you need to follow up on a specific lookup.
return {

    -- ========================================================================
    -- Summoner avatars (SummonerPact) — all unlocked by completing the
    -- avatar's "Trial" quest at the home nation or via expansion mission.
    -- ========================================================================
    ['Carbuncle']   = 'Quest [ Carbuncle\'s Ruby — SMN job-unlock quest ]',
    ['Shiva']       = 'Quest [ Trial by Ice — Cloister of Frost (Fei\'Yin) ]',
    ['Garuda']      = 'Quest [ Trial by Wind — Cloister of Gales (Cape Teriggan) ]',
    ['Ifrit']       = 'Quest [ Trial by Fire — Cloister of Flames (Ifrit\'s Cauldron) ]',
    ['Titan']       = 'Quest [ Trial by Earth — Cloister of Tremors (Yhoator Jungle) ]',
    ['Leviathan']   = 'Quest [ Trial by Water — Cloister of Tides (Sea Serpent Grotto) ]',
    ['Ramuh']       = 'Quest [ Trial by Lightning — Cloister of Storms (Sanctuary of Zi\'Tah) ]',
    ['Fenrir']      = 'Quest [ Trial Size Fenrir then Fenrir — Eternal Echo (San d\'Oria) ]',
    ['Diabolos']    = 'Mission [ Chains of Promathia — Lufaise Meadows mission ]',
    ['Atomos']      = 'Quest [ Atomos\'s Powers — Wings of the Goddess (Whitegate) ]',
    ['Cait Sith']   = 'Quest [ Cait Sith — Wings of the Goddess WotG quest ]',
    ['Alexander']   = 'Quest [ A Crystalline Prophecy: Path of Light — ACP add-on ]',
    ['Odin']        = 'Quest [ Ark Angels mid-WotG / ZNM access ]',
    ['Siren']       = 'Quest [ A Crystalline Prophecy: Mother Goddess — ACP add-on ]',

    -- ========================================================================
    -- BLM / RDM / WHM upgraded -ga and -V tier spells
    -- (Most modern V-tier scrolls are RoE objective rewards or Records of
    -- Eminence "Mastering" rewards; some come from specific NPCs in
    -- Adoulin or Aht Urhgan. Bio/Dia/Banishga III+ are quest/scroll vendor.)
    -- ========================================================================
    ['Aeroga V']      = 'RoE [ Records of Eminence reward ]',
    ['Blizzaga V']    = 'RoE [ Records of Eminence reward ]',
    ['Firaga V']      = 'RoE [ Records of Eminence reward ]',
    ['Stonega V']     = 'RoE [ Records of Eminence reward ]',
    ['Thundaga V']    = 'RoE [ Records of Eminence reward ]',
    ['Waterga V']     = 'RoE [ Records of Eminence reward ]',
    ['Banish V']      = 'RoE [ WHM Records of Eminence reward ]',
    ['Banishga III']  = 'Quest [ A Lady\'s Heart — Tavnazian Safehold ] or Vendor',
    ['Banishga IV']   = 'RoE [ Records of Eminence — Mastering the Job WHM ]',
    ['Banishga V']    = 'RoE [ Records of Eminence reward ]',
    ['Bio IV']        = 'RoE [ DRK / BLM Records of Eminence reward ]',
    ['Bio V']         = 'RoE [ Records of Eminence reward ]',
    ['Dia IV']        = 'RoE [ WHM / RDM Records of Eminence reward ]',
    ['Dia V']         = 'RoE [ Records of Eminence reward ]',
    ['Diaga II']      = 'Vendor [ WHM scroll vendor — Jeuno / starter cities ]',
    ['Diaga III']     = 'Quest / Vendor [ Adoulin RDM/WHM scroll line ]',
    ['Diaga IV']      = 'RoE [ Records of Eminence reward ]',
    ['Diaga V']       = 'RoE [ Records of Eminence reward ]',
    ['Meteor II']     = 'Job Point [ BLM Master gift — Job Point tier-V reward ]',
    ['Curse']         = 'Vendor / Drop [ DRK / RDM scroll — older expansion ]',
    ['Virus']         = 'Vendor [ DRK scroll vendor — Ru\'Lude Gardens / Jeuno ]',
    ['Poison III']    = 'Vendor [ BLM scroll vendor — Aht Urhgan Whitegate ]',
    ['Poison IV']     = 'RoE [ BLM Records of Eminence reward ]',
    ['Poison V']      = 'RoE [ Records of Eminence reward ]',
    ['Poisonga III']  = 'Vendor [ BLM scroll vendor ]',
    ['Poisonga IV']   = 'RoE [ Records of Eminence reward ]',
    ['Poisonga V']    = 'RoE [ Records of Eminence reward ]',
    ['Bindga']        = 'Vendor [ BLM scroll vendor ] or RoE',
    ['Blindga']       = 'Vendor [ BLM scroll vendor ]',
    ['Silencega']     = 'Vendor [ WHM / RDM scroll vendor — Jeuno ]',
    ['Slowga']        = 'Vendor [ RDM scroll vendor — Jeuno ]',
    ['Graviga']       = 'RoE [ RDM Records of Eminence reward ]',
    ['Paralyga']      = 'Vendor [ WHM / RDM scroll vendor ]',

    -- Base elemental Tier I starter scrolls (free with job activation for
    -- their respective jobs, also widely sold)
    ['Fire']          = 'Vendor [ default BLM starter spell — countless vendors ]',
    ['Water']         = 'Vendor [ default BLM starter spell — countless vendors ]',

    -- ========================================================================
    -- BRD higher-tier songs
    -- ========================================================================
    ['Army\'s Paeon VII']  = 'Job Point [ BRD Job Point reward ]',
    ['Army\'s Paeon VIII'] = 'Job Point [ BRD Job Point reward ]',
    ['Foe Requiem VIII']   = 'Job Point [ BRD Job Point reward ]',
    ['Devotee Serenade']   = 'Job Point [ BRD Job Point reward ]',
    ['Jester\'s Operetta'] = 'Vendor / Quest [ BRD song scroll — Adoulin ]',
    ['Cactuar Fugue']      = 'Special Event [ time-limited BRD song from a Tamas event ]',
    ['Chocobo Hum']        = 'Quest [ Riding on the Clouds / chocobo-related BRD quest ]',

    -- ========================================================================
    -- NIN higher-tier scrolls (-: Ni and -: San variants)
    -- ========================================================================
    ['Dokumori: Ni']  = 'Vendor [ Ninjutsu scroll vendor — Norg / Aht Urhgan ]',
    ['Dokumori: San'] = 'Quest / Vendor [ NIN scroll — Adoulin ]',
    ['Hojo: San']     = 'Quest / Vendor [ NIN scroll — Adoulin ]',
    ['Jubaku: Ni']    = 'Vendor [ Ninjutsu scroll vendor ]',
    ['Jubaku: San']   = 'Quest / Vendor [ NIN scroll — Adoulin ]',
    ['Kurayami: San'] = 'Quest / Vendor [ NIN scroll — Adoulin ]',

    -- ========================================================================
    -- Other singletons
    -- ========================================================================
    ['Tractor II']    = 'Job Point [ WHM Job Point reward ]',
}
