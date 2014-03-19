local GamePlayer = require('GamePlayer')
local PokeGame = require('PokeGame')
LocalGameService = class('GameService')

function LocalGameService:ctor()

end

function LocalGameService:enterRoom(roomId, callback)
  local this = self
  local Heads = {'head1', 'head2', 'head3', 'head4', 'head5', 'head6', 'head7', 'head8'}
  local Status = {ddz.PlayerStatus.None, ddz.PlayerStatus.Ready}
  local Roles = {ddz.PlayerRoles.Farmer, ddz.PlayerRoles.Lord, ddz.PlayerRoles.Farmer}
  table.shuffle(Roles)
  local playersInfo = {
    GamePlayer.new({userId=1, name='我自己', role=ddz.PlayerRoles.None, status=ddz.PlayerStatus.None}),
    GamePlayer.new({userId=2, name='张无忌', role=ddz.PlayerRoles.None, status=ddz.PlayerStatus.Ready}),
    GamePlayer.new({userId=3, name='东方不败', role=ddz.PlayerRoles.None, status=ddz.PlayerStatus.Ready})
  }
  for _, playerInfo in pairs(playersInfo) do
    playerInfo.headIcon = Heads[ math.random(#Heads) ]
  end
  table.shuffle(playersInfo)

  self.playersInfo = playersInfo

  callback(playersInfo)
end

function LocalGameService:readyGame(callback)
  local Roles = {ddz.PlayerRoles.Farmer, ddz.PlayerRoles.Lord, ddz.PlayerRoles.Farmer}
  table.shuffle(Roles)
  self.playersInfo[1].role = Roles[1]
  self.playersInfo[2].role = Roles[2]
  self.playersInfo[3].role = Roles[3]
  
  self.pokeGame = PokeGame.new(self.playersInfo)
  self.playersInfo[1].status = ddz.PlayerStatus.None
  self.playersInfo[2].status = ddz.PlayerStatus.None
  self.playersInfo[3].status = ddz.PlayerStatus.None
  if type(callback) == 'function' then
    callback(self.pokeGame)
  end
end

return LocalGameService