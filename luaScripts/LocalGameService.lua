local GamePlayer = require('GamePlayer')
local PokeGame = require('PokeGame')
local scheduler = require('framework.scheduler')
local AI = require('PokecardAI')

LocalGameService = class('GameService')

function LocalGameService:ctor(msgReceiver)
  self.msgReceiver = msgReceiver or {}
end

function LocalGameService:enterRoom(roomId, callback)
  local this = self
  local Heads = {'head1', 'head2', 'head3', 'head4', 'head5', 'head6', 'head7', 'head8'}
  local Status = {ddz.PlayerStatus.None, ddz.PlayerStatus.Ready}
  local Roles = {ddz.PlayerRoles.Farmer, ddz.PlayerRoles.Lord, ddz.PlayerRoles.Farmer}
  table.shuffle(Roles)
  local playersInfo = {
    GamePlayer.new({userId=1, name='我自己', role=ddz.PlayerRoles.None, status=ddz.PlayerStatus.None}),
    GamePlayer.new({userId=2, name='张无忌', robot=true, role=ddz.PlayerRoles.None, status=ddz.PlayerStatus.Ready}),
    GamePlayer.new({userId=3, name='东方不败', robot=true, role=ddz.PlayerRoles.None, status=ddz.PlayerStatus.Ready})
  }
  for _, playerInfo in pairs(playersInfo) do
    playerInfo.headIcon = Heads[ math.random(#Heads) ]
  end
  table.shuffle(playersInfo)

  self.playersInfo = playersInfo

  self.playersMap = {
    [playersInfo[1].userId] = playersInfo[1],
    [playersInfo[2].userId] = playersInfo[2],
    [playersInfo[3].userId] = playersInfo[3]
  }

  callback(playersInfo)
end

function LocalGameService:readyGame(callback)
  local Roles = {ddz.PlayerRoles.Farmer, ddz.PlayerRoles.Lord, ddz.PlayerRoles.Farmer}
  table.shuffle(Roles)
  self.playersInfo[1].role = ddz.PlayerRoles.None
  self.playersInfo[2].role = ddz.PlayerRoles.None
  self.playersInfo[3].role = ddz.PlayerRoles.None
  
  local pokeGame = PokeGame.new(self.playersInfo)
  self.playersInfo[1]:analyzePokecards()
  self.playersInfo[2]:analyzePokecards()
  self.playersInfo[3]:analyzePokecards()
  self:onServerStartNewGameMsg({pokeGame = pokeGame})
  -- if type(callback) == 'function' then
  --   callback(self.pokeGame)
  -- end
end

function LocalGameService:grabLord(userId, lordActionValue)
  self:onServerGrabbingLordMsg({userId = userId, lordActionValue = lordActionValue})
end

function LocalGameService:playCard(userId, pokeIdChars, callback)
  self:onServerPlayCardMsg({userId = userId, pokeIdChars = pokeIdChars})
end

function LocalGameService:onServerGrabbingLordMsg(data)
  local this = self
  local userId = data.userId
  local player = self.playersMap[userId]
  local pokeGame = self.pokeGame
  --player.lordValue = data.lordValue
  if pokeGame.grabbingLord.lordValue == 0 then
    if data.lordActionValue == ddz.Actions.GrabbingLord.None then
      player.status = ddz.PlayerStatus.NoGrabLord
    else
      player.status = ddz.PlayerStatus.GrabLord
      pokeGame.grabbingLord.lordValue = 3
    end
  else
    if data.lordActionValue == ddz.Actions.GrabbingLord.None then
      player.status = ddz.PlayerStatus.PassGrabLord
    else
      player.status = ddz.PlayerStatus.ReGrabLord
      pokeGame.grabbingLord.lordValue = pokeGame.grabbingLord.lordValue * 2
    end
  end

  local nextPlayer = self.pokeGame:setToNextPlayer()

  local isGiveup = (self.pokeGame.grabbingLord.firstPlayer == nextPlayer) and 
                    (self.pokeGame.grabbingLord.lordValue == 0)

  if self.msgReceiver.onGrabbingLordMsg then
    self.msgReceiver:onGrabbingLordMsg(userId, nextPlayer.userId, isGiveup)
  end

  if isGiveup then
    -- 流局
    scheduler.performWithDelayGlobal(function() 
        this.pokeGame:restart()
        this:onServerStartNewGameMsg({pokeGame = self.pokeGame})
      end, 0.7)

     return
  end

  if nextPlayer.robot then
    AI.grabLord(self, self.pokeGame, nextPlayer)
  end  

end

function LocalGameService:onServerStartNewGameMsg(data)
  local this = self
  self.pokeGame = data.pokeGame
  local nextPlayer = self.pokeGame.currentPlayer
  self.playersInfo[1].status = ddz.PlayerStatus.None
  self.playersInfo[2].status = ddz.PlayerStatus.None
  self.playersInfo[3].status = ddz.PlayerStatus.None
  if self.msgReceiver.onStartNewGameMsg then
    self.msgReceiver:onStartNewGameMsg(self.pokeGame, nextPlayer.userId)
  end

  if nextPlayer.robot then
    AI.grabLord(self, self.pokeGame, nextPlayer)
  end

  -- if nextPlayer.robot then
  --   scheduler.performWithDelayGlobal(function() 
  --     local pokeCards = table.copy(nextPlayer.pokeCards, 1, 1)
  --     this:playCard(nextPlayer.userId, PokeCard.getIdChars(pokeCards))
  --   end, math.random(5) - 0.5)
  -- end

end


function LocalGameService:onServerPlayCardMsg(data)
  local this = self
  local userId = data.userId
  local pokeIdChars = data.pokeIdChars
  local player = self.playersMap[userId]
  table.removeItems(player.pokeCards, PokeCard.getByPokeChars(pokeIdChars))
  local nextPlayer = self.pokeGame:setToNextPlayer()

  if self.msgReceiver.onPlayCardMsg then
    self.msgReceiver:onPlayCardMsg(userId, pokeIdChars)
  end

  if nextPlayer.robot then
    scheduler.performWithDelayGlobal(function() 
      local pokeCards = table.copy(nextPlayer.pokeCards, 1, 1)
      this:playCard(nextPlayer.userId, PokeCard.getIdChars(pokeCards))
    end, math.random(2) - 0.5)
  end

end

return LocalGameService