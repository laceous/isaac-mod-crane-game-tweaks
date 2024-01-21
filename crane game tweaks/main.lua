local mod = RegisterMod('Crane Game Tweaks', 1)
local json = require('json')
local game = Game()

mod.onGameStartHasRun = false
mod.slotMachineVariant = 1
mod.fortuneTellingVariant = 3
mod.shellGameVariant = 6
mod.craneGameVariant = 16
mod.rngShiftIdx = 35
mod.craneWiggles = {}

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
  
  mod.onGameStartHasRun = true
  mod:onNewRoom()
end

function mod:onGameExit(shouldSave)
  if shouldSave then
    mod:save()
    mod:clearCraneItems()
  else
    mod:clearCraneItems()
    mod:save()
  end
  
  mod.onGameStartHasRun = false
  mod:clearCraneWiggles()
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

function mod:clearCraneWiggles()
  for k, _ in pairs(mod.craneWiggles) do
    mod.craneWiggles[k] = nil
  end
end

-- not using MC_PRE_ROOM_ENTITY_SPAWN because it doesn't work with custom stage api rooms
-- not using MC_PRE_ENTITY_SPAWN because allowing the option to change percentages along with re-entering rooms leads to inconsistent behavior
function mod:onNewRoom()
  if not mod.onGameStartHasRun then
    return
  end
  
  local room = game:GetRoom()
  mod:clearCraneWiggles()
  
  if room:IsFirstVisit() then
    for _, slot in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT, -1, -1, false, false)) do
      local rng = RNG()
      rng:SetSeed(slot.InitSeed, mod.rngShiftIdx)
      
      if slot.Variant == mod.slotMachineVariant then
        if rng:RandomInt(100) < mod.state.slotPercent then
          mod:replaceSlot(slot, mod.craneGameVariant, slot.InitSeed, false)
        end
      elseif slot.Variant == mod.fortuneTellingVariant then
        if rng:RandomInt(100) < mod.state.fortunePercent then
          mod:replaceSlot(slot, mod.craneGameVariant, slot.InitSeed, false)
        end
      elseif slot.Variant == mod.shellGameVariant then
        if rng:RandomInt(100) < mod.state.shellGamePercent then
          mod:replaceSlot(slot, mod.craneGameVariant, slot.InitSeed, false)
        end
      end
    end
  end
end

function mod:onPreGetCollectible(itemPoolType, decrease, seed)
  if itemPoolType == ItemPoolType.POOL_CRANE_GAME and mod.state.itemPoolType ~= ItemPoolType.POOL_CRANE_GAME then
    for _, crane in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT, mod.craneGameVariant, -1, true, false)) do
      if crane.DropSeed == seed then
        local itemPool = game:GetItemPool()
        return itemPool:GetCollectible(mod.state.itemPoolType, false, seed, CollectibleType.COLLECTIBLE_BUDDY_IN_A_BOX) -- false rather than decrease/true gives better d6 behavior
      end
    end
  end
end

-----------------
-- Vanilla API --
-----------------
-- this callback (and the pre version) can override the collectible
-- it can't be 100% trusted, but it's the best we have
-- this won't be called if the player has tmtrainer (glitched items)
function mod:onPostGetCollectible(collectible, itemPoolType, decrease, seed)
  if itemPoolType == mod.state.itemPoolType then
    for _, crane in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT, mod.craneGameVariant, -1, true, false)) do
      if crane.DropSeed == seed then
        mod:updateCraneItemsAfterSelection(crane, collectible)
        break
      end
    end
  end
end

function mod:onUpdate()
  -- this is ugly but slot machines don't have very good api support
  for _, crane in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT, mod.craneGameVariant, -1, true, false)) do
    -- State : Animation
    -- 1 : Idle
    -- 2 : Initiate, Wiggle, NoPrize, Prize, Regenerate
    -- 3 : Death, Broken
    -- 4 : OutOfPrizes
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
      -- this can be delayed during a payout
      -- the bomb will act on the next item put in the crane game
      mod:payOutWhenBombed(crane)
    end
  end
end
------------------
-- /Vanilla API --
------------------

--------------------
-- Repentogon API --
--------------------
-- filtered to CRANE_GAME
-- called after: MC_POST_GET_COLLECTIBLE/MC_PRE_SLOT_SET_PRIZE_COLLECTIBLE/SetPrizeCollectible
-- called when you re-enter rooms w/ crane games, works with tmtrainer
function mod:onPostSlotSetPrizeCollectible(entitySlot, collectible)
  mod:updateCraneItemsAfterSelection(entitySlot, collectible)
end

-- filtered to CRANE_GAME
function mod:onPreSlotCreateExplosionDrops(entitySlot)
  -- State : Animation
  -- 1 : Death
  -- 3 : Idle, Wiggle, NoPrize, Prize, Regenerate
  -- 4 : OutOfPrizes
  local state = entitySlot:GetState()
  local animation = entitySlot:GetSprite():GetAnimation()
  
  -- bomb, not paying out a prize
  if state == 3 and animation ~= 'Prize' then
    if animation == 'Wiggle' then -- could be Prize or NoPrize
      mod.craneWiggles[GetPtrHash(entitySlot)] = mod.state.craneItems[tostring(entitySlot.InitSeed)]
    else
      mod:payOutWhenBombed(entitySlot)
      
      -- stops extra drops from spawning
      -- blocks MC_POST_SLOT_CREATE_EXPLOSION_DROPS
      --return false
    end
  end
  
  mod.state.craneItems[tostring(entitySlot.InitSeed)] = nil
end

function mod:onSlotUpdate(entitySlot)
  local entitySlotHash = GetPtrHash(entitySlot)
  local craneWiggle = mod.craneWiggles[entitySlotHash]
  
  if craneWiggle then
    local state = entitySlot:GetState()
    local animation = entitySlot:GetSprite():GetAnimation()
    
    if state == 3 then
      if animation == 'Wiggle' then
        -- nothing to do yet
      elseif animation == 'NoPrize' then
        mod.state.craneItems[tostring(entitySlot.InitSeed)] = craneWiggle
        mod:payOutWhenBombed(entitySlot)
        mod.craneWiggles[entitySlotHash] = nil
      else -- Prize
        mod.craneWiggles[entitySlotHash] = nil
      end
    else
      mod.craneWiggles[entitySlotHash] = nil
    end
  end
end
---------------------
-- /Repentogon API --
---------------------

-- filtered to: COLLECTIBLE_D6, COLLECTIBLE_ETERNAL_D6
-- this will also trigger for other items that use these: d100, perthro, etc
function mod:onUseItem(collectible, rng, player, useFlags, activeSlot, varData)
  -- block 2nd roll from car battery which can cause multiple crane games to spawn (glitch/lag)
  if mod.state.enableReroll and not (useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY) then
    for _, crane in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT, mod.craneGameVariant, -1, true, false)) do
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
          craneRng:SetSeed(crane.InitSeed, mod.rngShiftIdx)
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
      if (slot.Variant == mod.slotMachineVariant or slot.Variant == mod.fortuneTellingVariant) and slot.FrameCount == 0 then
        local rng = RNG()
        rng:SetSeed(slot.InitSeed, mod.rngShiftIdx)
        
        if rng:RandomInt(100) < mod.state.wheelOfFortunePercent then
          mod:replaceSlot(slot, mod.craneGameVariant, slot.InitSeed, true)
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
    
    -- if repentogon: don't allow more than 3 wins when re-rolling
    if REPENTOGON and slot.Variant == SlotVariant.CRANE_GAME and entity.Variant == SlotVariant.CRANE_GAME then
      entity:ToSlot():SetDonationValue(slot:ToSlot():GetDonationValue())
    end
    
    entity:Update() -- otherwise sad onion is shown for a split second
  end
end

function mod:payOutWhenBombed(crane)
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

-- potential repentogon update: use GetPtrHash(crane) instead of InitSeed
function mod:updateCraneItemsAfterSelection(crane, collectible)
  -- seed should be unique enough
  mod.state.craneItems[tostring(crane.InitSeed)] = collectible
  mod.state.craneItems[crane.InitSeed .. '|' .. crane.DropSeed] = collectible
  
  -- let eid know about the item
  mod:updateEid(crane, collectible)
end

function mod:updateEid(crane, collectible)
  if EID then
    EID.CraneItemType[tostring(crane.InitSeed)] = collectible
    EID.CraneItemType[crane.InitSeed .. 'Drop' .. crane.DropSeed] = collectible
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
mod:AddCallback(ModCallbacks.MC_PRE_GET_COLLECTIBLE, mod.onPreGetCollectible) -- Repentogon: MC_PRE_SLOT_SET_PRIZE_COLLECTIBLE
if REPENTOGON then
  mod:AddCallback(ModCallbacks.MC_POST_SLOT_SET_PRIZE_COLLECTIBLE, mod.onPostSlotSetPrizeCollectible, SlotVariant.CRANE_GAME)
  mod:AddCallback(ModCallbacks.MC_PRE_SLOT_CREATE_EXPLOSION_DROPS, mod.onPreSlotCreateExplosionDrops, SlotVariant.CRANE_GAME)
  mod:AddCallback(ModCallbacks.MC_POST_SLOT_UPDATE, mod.onSlotUpdate, SlotVariant.CRANE_GAME)
else
  mod:AddCallback(ModCallbacks.MC_POST_GET_COLLECTIBLE, mod.onPostGetCollectible)
  mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)
end
mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.onUseItem, CollectibleType.COLLECTIBLE_D6)
mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.onUseItem, CollectibleType.COLLECTIBLE_ETERNAL_D6)
mod:AddCallback(ModCallbacks.MC_USE_CARD, mod.onUseCard, Card.CARD_WHEEL_OF_FORTUNE)

if ModConfigMenu then
  mod:setupModConfigMenu()
end