local UIPokecardPickPlugin = {}

function UIPokecardPickPlugin.bind( theClass )
  local lastIndexBegin, lastIndexEnd = nil, nil
  local thisObj = nil

  --[[-----------------------------------------------------------
  获取loc坐标所在的牌, 由于牌是从大到小排序的显示的，小的牌显示在前面。
  所以需要从最后一个元素开始往回找。
  返回：找到就返回牌在数组中的index, -1 表示该位置无牌 
  --]]-----------------------------------------------------------
  local function getCardIndex(loc)
    local result = -1
    for index = #thisObj.pokeCards, 1, -1 do
      local pokeCard = thisObj.pokeCards[index]
      local cardBoundingBox = pokeCard.card_sprite:getBoundingBox()
      if cc.rectContainsPoint(cardBoundingBox, loc) then
        result = index
        break
      else
      end
    end
    return result
  end

  --[[-----------------------------------------------------------
  显示手指划过的牌的效果
  --]]-----------------------------------------------------------
  local function move_check(indexBegin, indexEnd)
    -- 确保 indexBegin <= indexEnd
    if indexBegin > indexEnd then
      indexBegin, indexEnd = indexEnd, indexBegin
    end

    for index = #thisObj.pokeCards, 1, -1 do
      local pokeCard = thisObj.pokeCards[index]
      if index > indexEnd or index < indexBegin then
        -- 不在本次手指划过范围内的牌，恢复正常状态
        if pokeCard.card_sprite:getTag() ~= ddz.PokecardPickTags.Unpicked then
          pokeCard.card_sprite:setColor(ddz.PokecardPickColors.Normal)
          pokeCard.card_sprite:setTag(ddz.PokecardPickTags.Unpicked)
        end
      else
        -- 在本次划过范围内的牌，如果还没设置选取标志的，设置牌划过效果和标志
        if pokeCard.card_sprite:getTag() ~= ddz.PokecardPickTags.Picked then
          pokeCard.card_sprite:setColor(ddz.PokecardPickColors.Selected)
          pokeCard.card_sprite:setTag(ddz.PokecardPickTags.Picked)
        end
      end
    end
  end

  
  --[[-----------------------------------------------------------
  手指点击开始
  --]]-----------------------------------------------------------
  local function onTouchBegan(touch, event)
    -- 如果当前还没有牌，直接返回false
    if thisObj.pokeCards == nil then
      return false
    end

    -- 转换触点坐标
    local locationInNode = thisObj:convertToNodeSpace(touch:getLocation())
    -- 取该点的牌index
    lastIndexBegin = getCardIndex(locationInNode)
    if lastIndexBegin > 0 then
      -- 有牌，显示效果
      move_check(lastIndexBegin, lastIndexBegin)
    end

    return true
  end

  --[[-----------------------------------------------------------
  手指移动, 每次移动都判断位置变化并更新划过的牌的效果
  --]]-----------------------------------------------------------
  local function onTouchMoved(touch, event)
    -- 转换触点坐标
    local locationInNode = thisObj:convertToNodeSpace(touch:getLocation())
    -- 取该点的牌index
    local curIndex = getCardIndex(locationInNode)
    if curIndex < 0 or curIndex == lastIndexEnd then
      -- 如果没牌，或在同一张牌上划动，直接返回
      return
    end

    -- 记下本次的牌位置为lastIndexEnd
    lastIndexEnd = curIndex
    -- 如果还没有lastIndexBegin
    if lastIndexBegin < 0 then
      lastIndexBegin = curIndex
    end
    -- 更新划过效果
    move_check(lastIndexBegin , lastIndexEnd)
  end

  
  --[[-----------------------------------------------------------
  手指移动结束， 对所划过的牌进行抽牌、退牌处理
  --]]-----------------------------------------------------------
  local function onTouchEnded(touch, event)
    local indexBegin, indexEnd = lastIndexBegin , lastIndexEnd
    -- 重置划牌index
    lastIndexBegin , lastIndexEnd = -1, -1

    -- 如果没有牌被划过，直接返回
    if (indexBegin == nil or indexBegin < 0) then
      return
    end

    if indexEnd == nil or indexEnd < 0 then
      indexEnd = indexBegin
    end

    -- 确保 indexBegin <= indexEnd
    if indexBegin > indexEnd then
      indexBegin, indexEnd = indexEnd, indexBegin
    end

    for i = indexBegin, indexEnd do
      local pokeCard = thisObj.pokeCards[i]
      -- 取消牌划过效果
      pokeCard.card_sprite:setTag(ddz.PokecardPickTags.Unpicked)
      pokeCard.card_sprite:setColor(ddz.PokecardPickColors.Normal)
      -- 如果当前牌未被选取，做抽牌处理
      if pokeCard.picked ~= true then
        pokeCard.picked = true
        pokeCard.card_sprite:runAction(cc.MoveBy:create(0.07, cc.p(0, 30)))
      else
        -- 牌已被选取，做退牌处理
        pokeCard.picked = false
        pokeCard.card_sprite:runAction(cc.MoveBy:create(0.07, cc.p(0, -30)))
      end
    end
  end

  --[[-----------------------------------------------------------
  设置扑克层的触摸事件，做选牌处理
  --]]-----------------------------------------------------------
  function theClass:initPokeCardsLayerTouchHandler()
    thisObj = self

    local listener = cc.EventListenerTouchOneByOne:create()
    self._listener = listener
    listener:setSwallowTouches(true)

    listener:registerScriptHandler(onTouchBegan,cc.Handler.EVENT_TOUCH_BEGAN )
    listener:registerScriptHandler(onTouchMoved,cc.Handler.EVENT_TOUCH_MOVED )
    listener:registerScriptHandler(onTouchEnded,cc.Handler.EVENT_TOUCH_ENDED )

    local eventDispatcher = self:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(listener, thisObj.pokeCardsLayer)
  end
  
  --------------------------------------------------------------
  -- 显示牌:
  -------------------------------------------------------------
  function theClass:showCards()
    local p = cc.p(20, (self.visibleSize.height - self.cardContentSize.height)/2)
    p.y = 0
    
    for index, pokeCard in pairs(self.pokeCards) do
      local cardSprite = pokeCard.card_sprite
      local cardValue = pokeCard.index
  
      cardSprite:setTag(0)
      cardSprite:setPosition( cc.p((self.visibleSize.width - self.cardContentSize.width)/2, p.y) )
      cardSprite:setScale(GlobalSetting.content_scale_factor)
      cardSprite:setVisible(true)
    end
    self:alignCards()
  end
  
  --[[---------------------------------------------------
  -- 根据牌的数量重新排列展示
  --]]----------------------------------------------------
  function theClass:alignCards() 
    -- 无牌？返回
    if #self.pokeCards < 1 then
      return
    end
    
    local p = cc.p(0, 0) 
    local cardWidth = self.cardContentSize.width --* GlobalSetting.content_scale_factor
    --print("cardWidth", cardWidth)
    -- 计算牌之间的覆盖位置，最少遮盖30% 即显示面积最多为70%
    local step = (self.visibleSize.width) / (#self.pokeCards + 1)
    if step > cardWidth * 0.7 then
      step = cardWidth * 0.7
    end
  
    -- 计算中心点
    local poke_size = cardWidth / 2
    local center_point = cc.p(self.visibleSize.width/2, 0)
    
    -- 第一张牌的起始位置，必须大于等于0
    local start_x = center_point.x - (step * #self.pokeCards/2 + poke_size / 2)
    if start_x < 0 then
      start_x = 0
    end
    
    p.x = start_x
    
    -- 排列并产生移动效果
    for index, pokeCard in pairs(self.pokeCards) do 
      if pokeCard.card_sprite:getParent() then
        pokeCard.card_sprite:setLocalZOrder(index)
        --card.card_sprite:getParent():reorderChild(card.card_sprite, index)
      end
      pokeCard.picked = false
      pokeCard.card_sprite:runAction( CCMoveTo:create(0.3, p ) )
      p.x = p.x + step
    end   
  end
  
  --[[
  提取选中的牌
  --]]
  function theClass:getPickedPokecards()
    local picked = {}
    for _, pokeCard in pairs(self.pokeCards) do
      if pokeCard.picked then
        table.insert(picked, pokeCard)
      end
    end
    
    table.sort(picked, sortAscBy('index'))
    return picked
  end
end

return UIPokecardPickPlugin