-- 断粮
duanliang_skill = {}
duanliang_skill.name = "duanliang"
table.insert(sgs.ai_skills, duanliang_skill)
duanliang_skill.getTurnUseCard = function(self)
	local cards = self.player:getCards("he")
	cards = sgs.QList2Table(cards)

	local card
	self:sortByUseValue(cards, true)

	for _, acard in ipairs(cards) do
		if (acard:isBlack()) and (acard:isKindOf("BasicCard") or acard:isKindOf("EquipCard")) and (self:getUsePriority(acard) < sgs.ai_use_value.SupplyShortage)then
			card = acard
			break
		end
	end

	if not card then return nil end
	local suit = card:getSuitString()
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	local card_str = ("supply_shortage:duanliang[%s:%s]=%d"):format(suit, number, card_id)
	local skillcard = sgs.Card_Parse(card_str)

	assert(skillcard)
	return skillcard
end

sgs.ai_cardneed.duanliang = function(to, card, self)
	return card:isBlack() and card:getTypeId() ~= sgs.Card_TypeTrick and getKnownCard(to, self.player, "black", false) < 2
end

sgs.duanliang_suit_value = {
	spade = 3.9,
	club = 3.9
}

-- 行殇
sgs.ai_skill_invoke.xingshang = sgs.ai_skill_invoke.jizhi

--放逐
function SmartAI:toTurnOver(player, n, reason)
	if not player then global_room:writeToConsole(debug.traceback()) return end
	n = n or 0
	if self:isEnemy(player) then
		local manchong = self.room:findPlayerBySkillName("junxing")
		if manchong and self:isFriend(player, manchong) and self:playerGetRound(manchong) < self:playerGetRound(player)
			and manchong:faceUp() and not self:willSkipPlayPhase(manchong)
			and not (manchong:isKongcheng() and self:willSkipDrawPhase(manchong)) then
			return false
		end
	end
	if reason and reason == "fangzhu" and player:getHp() == 1 and sgs.ai_AOE_data then
		local use = sgs.ai_AOE_data:toCardUse()
		if use.to:contains(player) and self:aoeIsEffective(use.card, player)
			and self:playerGetRound(player) > self:playerGetRound(self.player)
			and player:isKongcheng() then
			return false
		end
	end
	if player:hasUsed("ShenfenCard") and player:faceUp() and player:getPhase() == sgs.Player_Play
		and (not player:hasUsed("ShenfenCard") and player:getMark("@wrath") >= 6 or player:hasFlag("ShenfenUsing")) then
		return false
	end
	if n > 1 and player:hasSkill("jijiu") and not hasManjuanEffect(player) then
		return false
	end
	if not player:faceUp() and not player:hasFlag("ShenfenUsing") and not player:hasFlag("GuixinUsing") then
		return false
	end
	if (player:hasSkills("jushou|nosjushou|kuiwei") and player:getPhase() <= sgs.Player_Finish)
		or (player:hasSkill("lihun") and not player:hasUsed("LihunCard") and player:faceUp() and player:getPhase() == sgs.Player_Play) then
		return false
	end
	return true
end

sgs.ai_skill_playerchosen.fangzhu = function(self, targets)
	self:updatePlayers()
	self:sort(self.friends_noself, "handcard")
	local target = nil
	local n = self.player:getLostHp()
	for _, friend in ipairs(self.friends_noself) do
		if not self:toTurnOver(friend, n, "fangzhu") then
			target = friend
			break
		end
	end

	if not target then
		if n >= 3 then
			target = self:findPlayerToDraw(false, n)
			if not target then
				for _, enemy in ipairs(self.enemies) do
					if self:toTurnOver(enemy, n, "fangzhu") and hasManjuanEffect(enemy) then
						target = enemy
						break
					end
				end
			end
		else
			self:sort(self.enemies)
			for _, enemy in ipairs(self.enemies) do
				if self:toTurnOver(enemy, n, "fangzhu") and hasManjuanEffect(enemy) then
					target = enemy
					break
				end
			end
			if not target then
				for _, enemy in ipairs(self.enemies) do
					if self:toTurnOver(enemy, n, "fangzhu") and enemy:hasSkills(sgs.priority_skill) then
						target = enemy
						break
					end
				end
			end
			if not target then
				for _, enemy in ipairs(self.enemies) do
					if self:toTurnOver(enemy, n, "fangzhu") then
						target = enemy
						break
					end
				end
			end
		end
	end
	return target
end

sgs.ai_playerchosen_intention.fangzhu = function(self, from, to)
	if hasManjuanEffect(to) then sgs.updateIntention(from, to, 80) end
	local intention = 80 / math.max(from:getLostHp(), 1)
	if not self:toTurnOver(to, from:getLostHp()) then intention = -intention end
	if from:getLostHp() < 3 then
		sgs.updateIntention(from, to, intention)
	else
		sgs.updateIntention(from, to, math.min(intention, -30))
	end
end

sgs.ai_need_damaged.fangzhu = function(self, attacker, player)
	local friends = self:getFriendsNoself(player)
	self:sort(friends)
	for _, friend in ipairs(friends) do
		if not self:toTurnOver(friend, player:getLostHp() + 1) then return true end
	end
	if not player:isWounded() and sgs.turncount > 2 and #(self:getEnemies(player)) > 0 then return true end
	return false
end

-- 颂威
sgs.ai_skill_playerchosen.songwei = function(self, targets)
	targets = sgs.QList2Table(targets)
	for _, target in ipairs(targets) do
		if self:isFriend(target) and target:isAlive() then
			return target
		end
	end
	return nil
end

sgs.ai_playerchosen_intention.songwei = -50

-- 再起
sgs.ai_skill_invoke.zaiqi = function(self, data)
	local lostHp = 2
	if self.player:hasSkills("rende|nosrende") and #self.friends_noself > 0 and not self:willSkipPlayPhase() then lostHp = 3 end
	return self.player:getLostHp() >= lostHp
end

-- 烈刃
sgs.ai_skill_invoke.lieren = function(self, data)
	if self.player:getHandcardNum() == 1 then
		local card = self.player:getHandcards():first()
		if card:isKindOf("Jink") or card:isKindOf("Peach") then return end
	end
	local damage = data:toDamage()
	if self:isEnemy(damage.to) then
		if self.player:getHandcardNum() >= self.player:getHp() then return true
		else return false
		end
	end

	return false
end

function sgs.ai_skill_pindian.lieren(minusecard, self, requestor)
	local cards = sgs.QList2Table(self.player:getHandcards())
	self:sortByKeepValue(cards)
	if requestor:objectName() == self.player:objectName() then
		return cards[1]:getId()
	end
	return self:getMaxCard(self.player):getId()
end

sgs.ai_cardneed.lieren = function(to, card, self)
	return isCard("Slash", card, to) and getKnownCard(to, self.player, "Slash", true) == 0
end

-- 英魂
sgs.ai_skill_playerchosen.yinghun = function(self, targets)
	local x = self.player:getLostHp()
	local n = x - 1
	self:updatePlayers()
	if x == 1 and #self.friends == 1 then
		for _, enemy in ipairs(self.enemies) do
			if enemy:hasSkill("manjuan") then
				return enemy
			end
		end
		return nil
	end

	self.yinghun = nil

	if x == 1 then
		self:sort(self.friends_noself, "handcard")
		self.friends_noself = sgs.reverse(self.friends_noself)
		for _, friend in ipairs(self.friends_noself) do
			if friend:hasSkills(sgs.lose_equip_skill) and friend:getCards("e"):length() > 0
				and not friend:hasSkill("manjuan") then
				self.yinghun = friend
				break
			end
		end
		if not self.yinghun then
			for _, friend in ipairs(self.friends_noself) do
				if friend:hasSkills("tuntian+zaoxian") and not friend:hasSkill("manjuan") then
					self.yinghun = friend
					break
				end
			end
		end
		if not self.yinghun then
			for _, friend in ipairs(self.friends_noself) do
				if self:needToThrowArmor(friend) and not friend:hasSkill("manjuan") then
					self.yinghun = friend
					break
				end
			end
		end
		if not self.yinghun then
			for _, enemy in ipairs(self.enemies) do
				if enemy:hasSkill("manjuan") then
					return enemy
				end
			end
		end
		if not self.yinghun then
			for _, friend in ipairs(self.friends_noself) do
				if friend:getCards("he"):length() > 0 and not friend:hasSkill("manjuan") then
					self.yinghun = friend
					break
				end
			end
		end
		if not self.yinghun then
			for _, friend in ipairs(self.friends_noself) do
				if not friend:hasSkill("manjuan") then
					self.yinghun = friend
					break
				end
			end
		end
	elseif #self.friends > 1 then
		self:sort(self.friends_noself)
		for _, friend in ipairs(self.friends_noself) do
			if friend:hasSkills(sgs.lose_equip_skill) and friend:getCards("e"):length() > 0
				and not friend:hasSkill("manjuan") then
				self.yinghun = friend
				break
			end
		end
		if not self.yinghun then
			for _, friend in ipairs(self.friends_noself) do
				if friend:hasSkills("tuntian+zaoxian") and not friend:hasSkill("manjuan") then
					self.yinghun = friend
					break
				end
			end
		end
		if not self.yinghun then
			for _, friend in ipairs(self.friends_noself) do
				if self:needToThrowArmor(friend) and not friend:hasSkill("manjuan") then
					self.yinghun = friend
					break
				end
			end
		end
		if not self.yinghun and #self.enemies > 0 then
			local wf
			if self.player:isLord() then
				if self:isWeak() and (self.player:getHp() < 2 and self:getCardsNum("Peach") < 1) then
					wf = true
				end
			end
			if not wf then
				for _, friend in ipairs(self.friends_noself) do
					if self:isWeak(friend) then
						wf = true
						break
					end
				end
			end
			if not wf then
				self:sort(self.enemies)
				for _, enemy in ipairs(self.enemies) do
					if enemy:getCards("he"):length() == n
						and not self:doNotDiscard(enemy, "nil", true, n) then
						self.yinghunchoice = "d1tx"
						return enemy
					end
				end
				for _, enemy in ipairs(self.enemies) do
					if enemy:getCards("he"):length() >= n
						and not self:doNotDiscard(enemy, "nil", true, n)
						and enemy:hasSkills(sgs.cardneed_skill) then
						self.yinghunchoice = "d1tx"
						return enemy
					end
				end
			end
		end
		if not self.yinghun then
			self.yinghun = self:findPlayerToDraw(false, n)
		end
		if not self.yinghun then
			for _, friend in ipairs(self.friends_noself) do
				if not friend:hasSkill("manjuan") then
					self.yinghun = friend
					break
				end
			end
		end
		if self.yinghun then self.yinghunchoice = "dxt1" end
	end
	if x > 1 and not self.yinghun and #self.enemies > 0 then
		self:sort(self.enemies, "handcard")
		for _, enemy in ipairs(self.enemies) do
			if enemy:getCards("he"):length() >= n
				and not self:doNotDiscard(enemy, "nil", true, n) then
				self.yinghunchoice = "d1tx"
				return enemy
			end
		end
		self.enemies = sgs.reverse(self.enemies)
		for _, enemy in ipairs(self.enemies) do
			if not enemy:isNude()
				and not (enemy:hasSkills(sgs.lose_equip_skill) and enemy:getCards("e"):length() > 0)
				and not self:needToThrowArmor(enemy)
				and not enemy:hasSkills("tuntian+zaoxian") then
				self.yinghunchoice = "d1tx"
				return enemy
			end
		end
		for _, enemy in ipairs(self.enemies) do
			if not enemy:isNude()
				and not (enemy:hasSkills(sgs.lose_equip_skill) and enemy:getCards("e"):length() > 0)
				and not self:needToThrowArmor(enemy)
				and not (enemy:hasSkills("tuntian+zaoxian") and x < 3 and enemy:getCards("he"):length() < 2) then
				self.yinghunchoice = "d1tx"
				return enemy
			end
		end
	end

	return self.yinghun
end

sgs.ai_skill_choice.yinghun = function(self, choices)
	return self.yinghunchoice
end

sgs.ai_playerchosen_intention.yinghun = function(self, from, to)
	if from:getLostHp() > 1 then return end
	local intention = -80
	if to:hasSkill("manjuan") then intention = -intention end
	sgs.updateIntention(from, to, intention)
end

sgs.ai_choicemade_filter.skillChoice.yinghun = function(self, player, promptlist)
	local to
	for _, p in sgs.qlist(self.room:getOtherPlayers(player)) do
		if p:hasFlag("YinghunTarget") then
			to = p
			break
		end
	end
	local choice = promptlist[#promptlist]
	local intention = (choice == "dxt1") and -80 or 80
	sgs.updateIntention(player, to, intention)
end

-- 好施
local function getLowerBoundOfHandcard(self)
	local least = math.huge
	local players = self.room:getOtherPlayers(self.player)
	for _, player in sgs.qlist(players) do
		least = math.min(player:getHandcardNum(), least)
	end

	return least
end

local function getBeggar(self)
	self:updatePlayers()
	local least = getLowerBoundOfHandcard(self)

	self:sort(self.friends_noself)
	for _, friend in ipairs(self.friends_noself) do
		if friend:getHandcardNum() == least then
			return friend
		end
	end

	for _, player in sgs.qlist(self.room:getOtherPlayers(self.player)) do
		if player:getHandcardNum() == least then
			return player
		end
	end
end

sgs.ai_skill_invoke.haoshi = function(self, data)
	local extra = 0
	if self.player:hasSkill("yongsi") then
		local kingdoms = {}
		for _, p in sgs.qlist(self.room:getAlivePlayers()) do
			kingdoms[p:getKingdom()] = true
		end
		extra = extra + #kingdoms
	end
	local draw_skills = {
						["yingzi"] = 1, ["nosyingzi"] = 1, ["zishou"] = self.player:getLostHp(), ["shenwei"] = 2, ["juejing"] = self.player:getLostHp(),
						["nosluoyi"] = -1, ["zhaolie"] = -1, ["hongyuan"] = -1, ["dujin"] = math.floor(self.player:getEquips():length() / 2 + 1)
						}
	for skill_name, n in ipairs(draw_skills) do
		if self.player:hasSkill(skill_name) then
			local skill = sgs.Sanguosha:getSkill(skill_name)
			if skill and skill:getFrequency() == sgs.Skill_Compulsory then
				extra = extra + n
			elseif self:askForSkillInvoke(skill_name, data) then
				extra = extra + n
			end
		end
	end
	if self.player:getHandcardNum() + extra <= 1 then
		return true
	end

	local beggar = getBeggar(self)
	return self:isFriend(beggar) and not beggar:hasSkill("manjuan")
end

sgs.ai_skill_use["@@haoshi!"] = function(self, prompt)
	local beggar = getBeggar(self)

	local cards = self.player:getHandcards()
	cards = sgs.QList2Table(cards)
	self:sortByUseValue(cards, true)
	local card_ids = {}
	for i = 1, math.floor(#cards / 2) do
		table.insert(card_ids, cards[i]:getEffectiveId())
	end

	return "@HaoshiCard=" .. table.concat(card_ids, "+") .. "->" .. beggar:objectName()
end

sgs.ai_card_intention.HaoshiCard = -80

function sgs.ai_cardneed.haoshi(to, card, self)
	return not self:willSkipDrawPhase(to)
end

-- 缔盟
dimeng_skill = {}
dimeng_skill.name = "dimeng"
table.insert(sgs.ai_skills, dimeng_skill)
dimeng_skill.getTurnUseCard = function(self)
	if self.player:hasUsed("DimengCard") then return end
	card = sgs.Card_Parse("@DimengCard=.")
	return card
end

local function DimengDiscard(self, discard_num, cards)
	local to_discard = {}

	local aux_func = function(card)
		local place = self.room:getCardPlace(card:getEffectiveId())
		if place == sgs.Player_PlaceEquip then
			if card:isKindOf("SilverLion") and self.player:isWounded() then return -2
			elseif card:isKindOf("OffensiveHorse") then return 1
			elseif card:isKindOf("Weapon") then return 2
			elseif card:isKindOf("DefensiveHorse") then return 3
			elseif card:isKindOf("Armor") then return 4
			end
		elseif self:getUseValue(card) >= 6 then return 3
		elseif self.player:hasSkills(sgs.lose_equip_skill) then return 5
		else return 0
		end
		return 0
	end

	local compare_func = function(a, b)
		if aux_func(a) ~= aux_func(b) then
			return aux_func(a) < aux_func(b)
		end
		return self:getKeepValue(a) < self:getKeepValue(b)
	end

	table.sort(cards, compare_func)
	for _, card in ipairs(cards) do
		if not self.player:isJilei(card) then table.insert(to_discard, card:getId()) end
		if #to_discard >= discard_num then break end
	end
	return to_discard
end

local function getDimengCard(self, from, to, mycards)
	local num = math.abs(from:getHandcardNum() - to:getHandcardNum())
	if num == 0 then return sgs.Card_Parse("@DimengCard=.")
	else
		local to_discard = DimengDiscard(self, num, mycards)
		if #to_discard == num then return sgs.Card_Parse("@DimengCard=" .. table.concat(to_discard, "+"))
		end
	end
end

function DimengIsWorth(self, friend, enemy, mycards, myequips)
	local e_hand1, e_hand2 = enemy:getHandcardNum(), enemy:getHandcardNum() - self:getLeastHandcardNum(enemy)
	local f_hand1, f_hand2 = friend:getHandcardNum(), friend:getHandcardNum() - self:getLeastHandcardNum(friend)
	local e_peach, f_peach = getCardsNum("Peach", enemy, self.player), getCardsNum("Peach", friend, self.player)
	if e_hand1 < f_hand1 then
		return false
	elseif e_hand2 <= f_hand2 and e_peach <= f_peach then
		return false
	elseif e_peach < f_peach and e_peach < 1 then
		return false
	elseif e_hand1 == f_hand1 and e_hand1 > 0 then
		return friend:hasSkills("tuntian+zaoxian")
	end
	local cardNum = #mycards
	local delt = e_hand1 - f_hand1 --assert: delt>0
	if delt > cardNum then
		return false
	end
	local equipNum = #myequips
	if equipNum > 0 then
		if self.player:hasSkills("xuanfeng|xiaoji|nosxuanfeng") then
			return true
		end
	end
	--now e_hand1>f_hand1 and delt<=cardNum
	local soKeep = 0
	local soUse = 0
	local marker = math.ceil(delt / 2)
	for i = 1, delt, 1 do
		local card = mycards[i]
		local keepValue = self:getKeepValue(card)
		if keepValue > 4 then
			soKeep = soKeep + 1
		end
		local useValue = self:getUseValue(card)
		if useValue >= 6 then
			soUse = soUse + 1
		end
	end
	if soKeep > marker then
		return false
	end
	if soUse > marker then
		return false
	end
	return true
end

sgs.ai_skill_use_func.DimengCard = function(card, use, self)
	local cardNum = 0
	local mycards = {}
	local myequips = {}
	local keepaslash
	for _, c in sgs.qlist(self.player:getHandcards()) do
		if not self.player:isJilei(c) then
			local shouldUse
			if not keepaslash and isCard("Slash", c, self.player) then
				local dummy_use = { isDummy = true, to = sgs.SPlayerList() }
				self:useBasicCard(c, dummy_use)
				if dummy_use.card and (dummy_use.to:length() > 1 or (not dummy_use.to:isEmpty() and dummy_use.to:first():getHp() <= 1)) then
					shouldUse = true
					keepaslash = true
				end
			end
			if not shouldUse then
				cardNum = cardNum + 1
				table.insert(mycards, c)
			end
		end
	end
	for _, c in sgs.qlist(self.player:getEquips()) do
		if not self.player:isJilei(c) then
			cardNum = cardNum + 1
			table.insert(mycards, c)
			table.insert(myequips, c)
		end
	end
	self:sortByKeepValue(mycards)

	self:sort(self.enemies, "handcard")
	local friends = {}
	for _, player in ipairs(self.friends_noself) do
		if not player:hasSkill("manjuan") then
			table.insert(friends, player)
		end
	end
	if #friends == 0 then return end

	self:sort(friends, "defense")
	local function cmp_HandcardNum(a, b)
		local x = a:getHandcardNum() - self:getLeastHandcardNum(a)
		local y = b:getHandcardNum() - self:getLeastHandcardNum(b)
		return x < y
	end
	table.sort(friends, cmp_HandcardNum)

	self:sort(self.enemies, "defense")
	for _,enemy in ipairs(self.enemies) do
		if enemy:hasSkill("manjuan") then
			local e_hand = enemy:getHandcardNum()
			for _, friend in ipairs(friends) do
				local f_peach, f_hand = getCardsNum("Peach", friend, self.player), friend:getHandcardNum()
				if (e_hand > f_hand - 1) and (e_hand - f_hand) <= #mycards and (f_hand > 0 or e_hand > 0) and f_peach <= 2 then
					if e_hand == f_hand then
						use.card = card
					else
						local discard_num = e_hand - f_hand
						local discards = DimengDiscard(self, discard_num, mycards)
						if #discards > 0 then use.card = sgs.Card_Parse("@DimengCard=" .. table.concat(discards, "+")) end
					end
					if use.card and use.to then
						use.to:append(enemy)
						use.to:append(friend)
					end
					return
				end
			end
		end
	end

	for _, enemy in ipairs(self.enemies) do
		local e_hand = enemy:getHandcardNum()
		for _, friend in ipairs(friends) do
			local f_hand = friend:getHandcardNum()
			if DimengIsWorth(self, friend, enemy, mycards, myequips) and (e_hand > 0 or f_hand > 0) then
				if e_hand == f_hand then
					use.card = card
				else
					local discard_num = math.abs(e_hand - f_hand)
					local discards = DimengDiscard(self, discard_num, mycards)
					if #discards > 0 then use.card = sgs.Card_Parse("@DimengCard=" .. table.concat(discards, "+")) end
				end
				if use.to then
					use.to:append(enemy)
					use.to:append(friend)
					end
				return
			end
		end
	end
end

sgs.ai_card_intention.DimengCard = function(self, card, from, to)
	local compare_func = function(a, b)
		return a:getHandcardNum() < b:getHandcardNum()
	end
	table.sort(to, compare_func)
	if to[1]:getHandcardNum() < to[2]:getHandcardNum() then
		sgs.updateIntention(from, to[2], (to[2]:getHandcardNum() - to[1]:getHandcardNum()) * 20 + 40)
	end
end

sgs.ai_use_value.DimengCard = 3.5
sgs.ai_use_priority.DimengCard = 2.8

-- 酒池
jiuchi_skill = {}
jiuchi_skill.name = "jiuchi"
table.insert(sgs.ai_skills, jiuchi_skill)
jiuchi_skill.getTurnUseCard = function(self)
	local cards = self.player:getCards("h")
	for _, id in sgs.qlist(self.player:getPile("wooden_ox")) do
		cards:prepend(sgs.Sanguosha:getCard(id))
	end
	cards = sgs.QList2Table(cards)

	local card

	self:sortByUseValue(cards, true)

	for _, acard in ipairs(cards) do
		if acard:getSuit() == sgs.Card_Spade then
			card = acard
			break
		end
	end

	if not card then return nil end
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	local card_str = ("analeptic:jiuchi[spade:%s]=%d"):format(number, card_id)
	local analeptic = sgs.Card_Parse(card_str)

	if sgs.Analeptic_IsAvailable(self.player, analeptic) then
		assert(analeptic)
		return analeptic
	end
end

sgs.ai_view_as.jiuchi = function(card, player, card_place)
	local suit = card:getSuitString()
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	if card_place == sgs.Player_PlaceHand then
		if card:getSuit() == sgs.Card_Spade then
			return ("analeptic:jiuchi[%s:%s]=%d"):format(suit, number, card_id)
		end
	end
end

function sgs.ai_cardneed.jiuchi(to, card, self)
	return card:getSuit() == sgs.Card_Spade and getKnownCard(to, self.player, "spade") < 2
end

sgs.jiuchi_suit_value = {
	spade = 5,
}

-- 肉林
function sgs.ai_cardneed.roulin(to, card, self)
	for _, enemy in ipairs(self.enemies) do
		if isCard("Slash", card, to) and to:canSlash(enemy) and self:slashIsEffective(card, enemy)
			and sgs.isGoodTarget(enemy, self.enemies, self) and not self:slashProhibit(card, enemy) and enemy:isFemale() then
			return getKnownCard(to, self.player, "Slash", true) == 0
		end
	end
end


-- 崩坏
sgs.ai_skill_choice.benghuai = function(self, choices)
	for _, friend in ipairs(self.friends) do
		if friend:hasSkill("tianxiang") and (self.player:getHp() >= 3 or (self:getCardsNum("Peach") + self:getCardsNum("Analeptic") > 0 and self.player:getHp() > 1)) then
			return "hp"
		end
	end
	if self.player:getMaxHp() >= self.player:getHp() + 2 then
		local enemy_num = self:getEnemyNumBySeat(self.room:getCurrent(), self.player, self.player)
		local least_hp = self.player:isLord() and (1 + enemy_num) or 1
		if self.player:getMaxHp() > 4
			and (self.player:hasSkills("nosmiji|fuluan|juejing|zaiqi|nosshangshi")
				or (self.player:hasSkill("miji") and self:findPlayerToDraw(false))
				or (self.player:hasSkill("yinghun") and (self:findPlayerToDraw(false) or self:findPlayerToDiscard("he", false))))
			and (self:getCardsNum("Peach") + self:getCardsNum("Analeptic") + self.player:getHp() > least_hp) then
			return "hp"
		end
		return "maxhp"
	else
		return "hp"
	end
end


-- 暴虐
sgs.ai_skill_playerchosen.baonue = function(self, targets)
	targets = sgs.QList2Table(targets)
	for _, target in ipairs(targets) do
		if self:isFriend(target) and target:isAlive() then
			if target:isWounded() then
				return target
			end
			local zhangjiao = self.room:findPlayerBySkillName("guidao")
			if zhangjiao and self:isFriend(zhangjiao) then
				return target
			end
		end
	end
	return nil
end

sgs.ai_playerchosen_intention.baonue = -50


-- 完杀

-- 乱舞
luanwu_skill = {}
luanwu_skill.name = "luanwu"
table.insert(sgs.ai_skills, luanwu_skill)
luanwu_skill.getTurnUseCard = function(self)
	if self.player:getMark("@chaos") <= 0 then return end
	local good, bad = 0, 0
	local lord = self.room:getLord()
	if self.role ~= "rebel" and lord and self:isWeak(lord) then return end
	for _, player in sgs.qlist(self.room:getOtherPlayers(self.player)) do
		if self:isWeak(player) then
			if self:isFriend(player) then bad = bad + 1
			else good = good + 1
			end
		end
	end
	if good == 0 then return end

	for _, player in sgs.qlist(self.room:getOtherPlayers(self.player)) do
		local hp = math.max(player:getHp(), 1)
		if getCardsNum("Analeptic", player, self.player) > 0 then
			if self:isFriend(player) then good = good + 1.0 / hp
			else bad = bad + 1.0 / hp
			end
		end

		local has_slash = (getCardsNum("Slash", player, self.player) > 0)
		local can_slash = false
		if not can_slash then
			for _, p in sgs.qlist(self.room:getOtherPlayers(player)) do
				if player:inMyAttackRange(p) then can_slash = true break end
			end
		end
		if not has_slash or not can_slash then
			if self:isFriend(player) then good = good + math.max(getCardsNum("Peach", player, self.player), 1)
			else bad = bad + math.max(getCardsNum("Peach", player, self.player), 1)
			end
		end

		if getCardsNum("Jink", player) == 0 then
			local lost_value = 0
			if player:hasSkills(sgs.masochism_skill) then lost_value = player:getHp() / 2 end
			local hp = math.max(player:getHp(), 1)
			if self:isFriend(player) then bad = bad + (lost_value + 1) / hp
			else good = good + (lost_value + 1) / hp
			end
		end
	end

	if good > bad then return sgs.Card_Parse("@LuanwuCard=.") end
end

sgs.ai_skill_use_func.LuanwuCard = function(card, use, self)
	use.card = card
end

sgs.dynamic_value.damage_card.LuanwuCard = true

-- 帷幕
