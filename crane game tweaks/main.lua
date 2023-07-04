local mod = RegisterMod('Crane Game Tweaks', 1)
local json = require('json')
local game = Game()

mod.craneGame = 16
mod.rngShiftIdx = 35

mod.itemPoolTypes = {
  [ItemPoolType.POOL_TREASURE]       = 'treasure',       -- 0
  [ItemPoolType.POOL_SHOP]           = 'shop',           -- 1
  [ItemPoolType.POOL_BOSS]           = 'boss',           -- 2
  [ItemPoolType.POOL_DEVIL]          = 'devil',          -- 3
  [ItemPoolType.POOL_ANGEL]          = 'angel',          -- 4
  [ItemPoolType.POOL_SECRET]         = 'secret',         -- 5
  [ItemPoolType.POOL_LIBRARY]        = 'library',        -- 6
  [ItemPoolType.POOL_SHELL_GAME]     = 'shell game',     -- 7
  [ItemPoolType.POOL_GOLDEN_CHEST]   = 'golden chest',   -- 8
  [ItemPoolType.POOL_RED_CHEST]      = 'red chest',      -- 9
  [ItemPoolType.POOL_BEGGAR]         = 'beggar',         -- 10
  [ItemPoolType.POOL_DEMON_BEGGAR]   = 'demon beggar',   -- 11
  [ItemPoolType.POOL_CURSE]          = 'curse',          -- 12
  [ItemPoolType.POOL_KEY_MASTER]     = 'key bum',        -- 13
  [ItemPoolType.POOL_BATTERY_BUM]    = 'battery bum',    -- 14
  [ItemPoolType.POOL_MOMS_CHEST]     = 'mom\'s chest',   -- 15
  [ItemPoolType.POOL_GREED_TREASURE] = 'greed treasure', -- 16
  [ItemPoolType.POOL_GREED_BOSS]     = 'greed boss',     -- 17
  [ItemPoolType.POOL_GREED_SHOP]     = 'greed shop',     -- 18
  [ItemPoolType.POOL_GREED_DEVIL]    = 'greed devil',    -- 19
  [ItemPoolType.POOL_GREED_ANGEL]    = 'greed angel',    -- 20
  [ItemPoolType.POOL_GREED_CURSE]    = 'greed curse',    -- 21
  [ItemPoolType.POOL_GREED_SECRET]   = 'greed secret',   -- 22
  [ItemPoolType.POOL_CRANE_GAME]     = 'crane game',     -- 23
  [ItemPoolType.POOL_ULTRA_SECRET]   = 'ultra secret',   -- 24
  [ItemPoolType.POOL_BOMB_BUM]       = 'bomb bum',       -- 25
  [ItemPoolType.POOL_PLANETARIUM]    = 'planetarium',    -- 26
  [ItemPoolType.POOL_OLD_CHEST]      = 'old chest',      -- 27
  [ItemPoolType.POOL_BABY_SHOP]      = 'baby shop',      -- 28
  [ItemPoolType.POOL_WOODEN_CHEST]   = 'wooden chest',   -- 29
  [ItemPoolType.POOL_ROTTEN_BEGGAR]  = 'rotten beggar',  -- 30
}

mod.state = {}
mod.state.bombPercent = 25
mod.state.glitchPercent = 25
mod.state.slotPercent = 0
mod.state.fortunePercent = 0
mod.state.shellGamePercent = 0
mod.state.wheelOfFortunePercent = 0
mod.state.itemPoolType = ItemPoolType.POOL_CRANE_GAME
mod.state.enableReroll = false
mod.state.craneItems = {}

function mod:onGameStart(isContinue)
  if mod:HasData() then
    local _, state = pcall(json.decode, mod:LoadData())
    
    if type(state) == 'table' then
      if isContinue and type(state.craneItems) == 'table' then
        for k, v in pairs(state.craneItems) do
          if type(k) == 'string' and math.type(v) == 'integer' then
            mod.state.craneItems[k] = v
          end
        end
      end
      for _, v in ipairs({ 'bombPercent', 'glitchPercent', 'slotPercent', 'fortunePercent', 'shellGamePercent', 'wheelOfFortunePercent' }) do
        if math.type(state[v]) == 'integer' and state[v] >= 0 and state[v] <= 100 then
          mod.state[v] = state[v]
        end
      end
      if math.type(state.itemPoolType) == 'integer' and state.itemPoolType >= 0 and state.itemPoolType < ItemPoolType.NUM_ITEMPOOLS then
        mod.state.itemPoolType = state.itemPoolType
      end
      if type(state.enableReroll) == 'boolean' then
        mod.state.enableReroll = state.enableReroll
      end
    end
  end
end

function mod:onGameExit(shouldSave)
  if shouldSave then
    mod:save()
    mod:clearCraneItems()
  else
    mod:clearCraneItems()
    mod:save()
  end
end

function mod:save(settingsOnly)
  if settingsOnly then
    local _, state
    if mod:HasData() then
      _, state = pcall(json.decode, mod:LoadData())
    end
    if type(state) ~= 'table' then
      state = {}
    end
    
    state.bombPercent = mod.state.bombPercent
    state.glitchPercent = mod.state.glitchPercent
    state.slotPercent = mod.state.slotPercent
    state.fortunePercent = mod.state.fortunePercent
    state.shellGamePercent = mod.state.shellGamePercent
    state.wheelOfFortunePercent = mod.state.wheelOfFortunePercent
    state.itemPoolType = mod.state.itemPoolType
    state.enableReroll = mod.state.enableReroll
    
    mod:SaveData(json.encode(state))
  else
    mod:SaveData(json.encode(mod.state))
  end
end

function mod:clearCraneItems()
  for k, _ in pairs(mod.state.craneItems) do
    mod.state.craneItems[k] = nil
  end
end

-- not using MC_PRE_ROOM_ENTITY_SPAWN because it doesn't work with custom stage api rooms
-- not using MC_PRE_ENTITY_SPAWN because allowing the option to change percentages along with re-entering rooms leads to inconsistent behavior
function mod:onNewRoom()
  local room = game:GetRoom()
  
  if room:IsFirstVisit() then
    for _, slot in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT, -1, -1, false, false)) do
      local rng = RNG()
      rng:SetSeed(slot.InitSeed, mod.rngShiftIdx)
      
      if slot.Variant == 1 then -- slot machine
        if rng:RandomInt(100) < mod.state.slotPercent then
          mod:replaceSlot(slot, mod.craneGame, slot.InitSeed, false)
        end
      elseif slot.Variant == 3 then -- fortune telling machine
        if rng:RandomInt(100) < mod.state.fortunePercent then
          mod:replaceSlot(slot, mod.craneGame, slot.InitSeed, false)
        end
      elseif slot.Variant == 6 then -- shell game
        if rng:RandomInt(100) < mod.state.shellGamePercent then
          mod:replaceSlot(slot, mod.craneGame, slot.InitSeed, false)
        end
      end
    end
  end
end

function mod:onUpdate()
  -- this is ugly but slot machines don't have very good api support
  for _, crane in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT, mod.craneGame, -1, true, false)) do
    local sprite = crane:GetSprite()
    
    if sprite:IsPlaying('Idle') or sprite:IsPlaying('Regenerate') then
      if mod.state.craneItems[crane.InitSeed .. '|' .. crane.DropSeed] then
        if mod.state.craneItems[tostring(crane.InitSeed)] ~= mod.state.craneItems[crane.InitSeed .. '|' .. crane.DropSeed] then
          -- glowing hourglass is stupid
          mod.state.craneItems[tostring(crane.InitSeed)] = mod.state.craneItems[crane.InitSeed .. '|' .. crane.DropSeed]
        end
      elseif mod.state.craneItems[tostring(crane.InitSeed)] then
        if not mod.state.craneItems[crane.InitSeed .. '|' .. crane.DropSeed] then
          mod.state.craneItems[crane.InitSeed .. '|' .. crane.DropSeed] = mod.state.craneItems[tostring(crane.InitSeed)]
        end
      else
        -- set default item so this works with tmtrainer
        mod.state.craneItems[tostring(crane.InitSeed)] = CollectibleType.COLLECTIBLE_SAD_ONION
        mod.state.craneItems[crane.InitSeed .. '|' .. crane.DropSeed] = CollectibleType.COLLECTIBLE_SAD_ONION
      end
    elseif sprite:IsPlaying('Prize') then
      if mod.state.craneItems[tostring(crane.InitSeed)] then
        mod.state.craneItems[tostring(crane.InitSeed)] = nil
      end
    elseif sprite:IsPlaying('Broken') then -- IsEventTriggered('Explosion') doesn't work for all cases
      local craneItem = mod.state.craneItems[tostring(crane.InitSeed)]
      
      if craneItem then
        local rng = RNG()
        rng:SetSeed(crane.InitSeed, mod.rngShiftIdx)
        
        if rng:RandomInt(100) < mod.state.bombPercent then
          local entity = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, craneItem, crane.Position, Vector.Zero, nil)
          entity.TargetPosition = crane.TargetPosition
          
          -- there isn't a built-in collectible base for crane games: entity:GetSprite():SetOverlayFrame('Alternates', x)
          -- you could probably add one, but i like the way this currently looks: normal base + broken crane game
          
          if rng:RandomInt(100) < mod.state.glitchPercent then
            entity:AddEntityFlags(EntityFlag.FLAG_GLITCH)
          end
        end
        
        mod.state.craneItems[tostring(crane.InitSeed)] = nil
      end
    end
  end
end

function mod:onPreGetCollectible(itemPoolType, decrease, seed)
  if itemPoolType == ItemPoolType.POOL_CRANE_GAME and mod.state.itemPoolType ~= ItemPoolType.POOL_CRANE_GAME then
    for _, crane in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT, mod.craneGame, -1, true, false)) do
      if crane.DropSeed == seed then
        local itemPool = game:GetItemPool()
        return itemPool:GetCollectible(mod.state.itemPoolType, false, seed, CollectibleType.COLLECTIBLE_BUDDY_IN_A_BOX) -- false rather than decrease/true gives better d6 behavior
      end
    end
  end
end

-- this callback (and the pre version) can override the collectible
-- it can't be 100% trusted, but it's the best we have
-- this won't be called if the player has tmtrainer (glitched items)
function mod:onPostGetCollectible(collectible, itemPoolType, decrease, seed)
  if itemPoolType == mod.state.itemPoolType then
    for _, crane in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT, mod.craneGame, -1, true, false)) do
      if crane.DropSeed == seed then
        -- seed should be unique enough
        mod.state.craneItems[tostring(crane.InitSeed)] = collectible
        mod.state.craneItems[crane.InitSeed .. '|' .. crane.DropSeed] = collectible
        
        -- if we changed the item pool type, let eid know about it
        if itemPoolType ~= ItemPoolType.POOL_CRANE_GAME then
          mod:updateEid(crane.InitSeed, collectible)
        end
        
        break
      end
    end
  end
end

-- filtered to: COLLECTIBLE_D6, COLLECTIBLE_ETERNAL_D6
-- this will also trigger for other items that use these: d100, perthro, etc
function mod:onUseItem(collectible, rng, player, useFlags, activeSlot, varData)
  -- block 2nd roll from car battery which can cause multiple crane games to spawn (glitch/lag)
  if mod.state.enableReroll and not (useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY) then
    for _, crane in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT, mod.craneGame, -1, true, false)) do
      local sprite = crane:GetSprite()
      
      if sprite:IsPlaying('Idle') then
        mod.state.craneItems[tostring(crane.InitSeed)] = nil
        
        -- use crane rng rather than d6 rng
        local craneRng = RNG()
        craneRng:SetSeed(crane.InitSeed, mod.rngShiftIdx)
        
        if collectible == CollectibleType.COLLECTIBLE_ETERNAL_D6 and craneRng:RandomFloat() < 0.25 then -- 25%
          sprite:Play('Death', true) -- OutOfPrizes takes too long, you can still spend another 5c
        else
          -- Play('Regenerate') doesn't work
          mod:replaceSlot(crane, crane.Variant, craneRng:Next(), true)
        end
      end
    end
  end
end

-- filtered to CARD_WHEEL_OF_FORTUNE
function mod:onUseCard(card, player, useFlags)
  -- block tarot cloth which causes issues (related to removing/spawning, there's no morph here)
  if not (useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY) then
    for _, slot in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT, -1, -1, false, false)) do
      -- slot machine or fortune teller
      if (slot.Variant == 1 or slot.Variant == 3) and slot.FrameCount == 0 then
        local rng = RNG()
        rng:SetSeed(slot.InitSeed, mod.rngShiftIdx)
        
        if rng:RandomInt(100) < mod.state.wheelOfFortunePercent then
          mod:replaceSlot(slot, mod.craneGame, slot.InitSeed, true)
        end
      end
    end
  end
end

function mod:replaceSlot(slot, variant, seed, appear)
  -- check exists just in case replaceSlot gets called twice in the same frame
  if slot:Exists() then
    slot:Remove()
    
    local entity = game:Spawn(slot.Type, variant, slot.Position, slot.Velocity, slot.SpawnerEntity, slot.SubType, seed)
    entity.TargetPosition = slot.TargetPosition -- otherwise you can push the machine around when re-rolling
    if appear then
      entity:AddEntityFlags(EntityFlag.FLAG_APPEAR)
    else
      entity:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
    end
    entity:Update() -- otherwise sad onion is shown for a split second
  end
end

function mod:updateEid(seed, collectible)
  if EID then
    EID.CraneItemType[tostring(seed)] = collectible
  end
end

-- start ModConfigMenu --
function mod:setupModConfigMenu()
  for _, v in ipairs({ 'Settings', 'Advanced' }) do
    ModConfigMenu.RemoveSubcategory(mod.Name, v)
  end
  ModConfigMenu.AddText(mod.Name, 'Settings', 'Pull items from which pool:')
  ModConfigMenu.AddSetting(
    mod.Name,
    'Settings',
    {
      Type = ModConfigMenu.OptionType.NUMBER,
      CurrentSetting = function()
        return mod.state.itemPoolType
      end,
      Minimum = 0,
      Maximum = ItemPoolType.NUM_ITEMPOOLS - 1,
      Display = function()
        local itemPoolType = mod.itemPoolTypes[mod.state.itemPoolType]
        return itemPoolType or tostring(mod.state.itemPoolType)
      end,
      OnChange = function(n)
        mod.state.itemPoolType = n
        mod:save(true)
      end,
      Info = { 'Default: crane game' }
    }
  )
  ModConfigMenu.AddSpace(mod.Name, 'Settings')
  for _, v in ipairs({
                       { text = 'Chance to get items by bombing'    , field = 'bombPercent' },
                       { text = 'Chance that items will be glitched', field = 'glitchPercent' }
                    })
  do
    ModConfigMenu.AddText(mod.Name, 'Settings', v.text .. ':')
    ModConfigMenu.AddSetting(
      mod.Name,
      'Settings',
      {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function()
          return mod.state[v.field]
        end,
        Minimum = 0,
        Maximum = 100,
        Display = function()
          return mod.state[v.field] .. '%'
        end,
        OnChange = function(n)
          mod.state[v.field] = n
          mod:save(true)
        end,
        Info = { 'Default: 25%' }
      }
    )
  end
  ModConfigMenu.AddText(mod.Name, 'Advanced', 'Re-roll crane game items:')
  ModConfigMenu.AddSetting(
    mod.Name,
    'Advanced',
    {
      Type = ModConfigMenu.OptionType.BOOLEAN,
      CurrentSetting = function()
        return mod.state.enableReroll
      end,
      Display = function()
        return (mod.state.enableReroll and 'enabled' or 'disabled')
      end,
      OnChange = function(b)
        mod.state.enableReroll = b
        mod:save(true)
      end,
      Info = { 'Default: disabled' }
    }
  )
  ModConfigMenu.AddSpace(mod.Name, 'Advanced')
  ModConfigMenu.AddText(mod.Name, 'Advanced', 'Chance to replace slots with crane games:')
  for _, v in ipairs({
                       { obj = 'slot machine'           , field = 'slotPercent'          , info = { 'Default: 0%', 'Calculated on your first visit to each room' } },
                       { obj = 'fortune telling machine', field = 'fortunePercent'       , info = { 'Default: 0%', 'Calculated on your first visit to each room' } },
                       { obj = 'shell game'             , field = 'shellGamePercent'     , info = { 'Default: 0%', 'Calculated on your first visit to each room' } },
                       { obj = 'x - wheel of fortune'   , field = 'wheelOfFortunePercent', info = { 'Default: 0%', 'Calculated on card use' } }
                    })
  do
    ModConfigMenu.AddSetting(
      mod.Name,
      'Advanced',
      {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function()
          return mod.state[v.field]
        end,
        Minimum = 0,
        Maximum = 100,
        Display = function()
          return v.obj .. ': ' .. mod.state[v.field] .. '%'
        end,
        OnChange = function(n)
          mod.state[v.field] = n
          mod:save(true)
        end,
        Info = v.info
      }
    )
  end
end
-- end ModConfigMenu --

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.onNewRoom)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)
mod:AddCallback(ModCallbacks.MC_PRE_GET_COLLECTIBLE, mod.onPreGetCollectible)
mod:AddCallback(ModCallbacks.MC_POST_GET_COLLECTIBLE, mod.onPostGetCollectible)
mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.onUseItem, CollectibleType.COLLECTIBLE_D6)
mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.onUseItem, CollectibleType.COLLECTIBLE_ETERNAL_D6)
mod:AddCallback(ModCallbacks.MC_USE_CARD, mod.onUseCard, Card.CARD_WHEEL_OF_FORTUNE)

if ModConfigMenu then
  mod:setupModConfigMenu()
end