-- 奸雄
sgs.ai_skill_choice.jianxiong = function(self, choices, data)
	local function getChoice(id)
		local card = sgs.Sanguosha:getCard(id)
		if card:isKindOf("Lightning") then
			local dummy = { isDummy = true }
			self:useCardLightning(card, dummy)
			return (dummy.card and dummy.card:isKindOf("Lightning")) and "obtain" or "draw"
		elseif card:isKindOf("Slash") then
			if self:getCardsNum("Slash") >= 1
				and ((not self.player:hasSkills("paoxiao|xianzhen") and not self.player:hasWeapon("crossbow") and not self.player:hasWeapon("vs_crossbow"))
					or self:willSkipPlayPhase()) then
				return "draw"
			end
			return "obtain"
		elseif self:willSkipPlayPhase() or self:isWeak() then
			return self:isValuableCard(card) and "obtain" or "draw"
		else
			return "obtain"
		end
	end

	local choice_table = choices:split("+")
	if not table.contains(choice_table, "obtain") then
		return self:needKongcheng(self.player, true) and "cancel" or "draw"
	else
		local damage = data:toDamage()
		if self.player:isKongcheng() and damage.from and damage.from:isAlive() and damage.from:getPhase() == sgs.Player_Play
			and damage.from:hasSkills("longdan+chongzhen") and self:slashIsAvailable(damage.from)
			and card:isKindOf("Jink") and getKnownCard(damage.from, self.player, "Jink", false) > 0 then
			return getKnownCard(self.player, self.player, "Jink", false) >= 2 and "cancel" or "draw"
		end
		local len = damage.card:isVirtualCard() and damage.card:subcardsLength() or 1
		if len >= 3 then return "obtain"
		elseif len == 2 then
			for _, card in sgs.qlist(damage.card:getSubcards()) do
				if self:isValuableCard(card) then return "obtain" end
			end
		end
		if self:needKongcheng(self.player, true) then return "cancel" end
		if len == 2 then
			for _, card in sgs.qlist(damage.card:getSubcards()) do
				local id = card:getEffectiveId()
				if getChoice(id) == "obtain" then return "obtain" end
			end
			return "draw"
		else
			local id = damage.card:getEffectiveId()
			return getChoice(id)
		end
	end
	return "cancel"
end

-- 护驾
table.insert(sgs.ai_global_flags, "hujiasource")

sgs.ai_skill_invoke.hujia = function(self, data)
	local asked = data:toStringList()
	local prompt = asked[2]
	if self:askForCard("jink", prompt, 1) == "." then return false end

	local cards = self.player:getHandcards()
	if sgs.hujiasource then return false end
	for _, friend in ipairs(self.friends_noself) do
		if friend:getKingdom() == "wei" and self:hasEightDiagramEffect(friend) then return true end
	end

	local current = self.room:getCurrent()
	if self:isFriend(current) and current:getKingdom() == "wei" and self:getOverflow(current) > 2 then
		return true
	end

	for _, card in sgs.qlist(cards) do
		if isCard("Jink", card, self.player) then
			return false
		end
	end
	local lieges = self.room:getLieges("wei", self.player)
	if lieges:isEmpty() then return end
	local has_friend = false
	for _, p in sgs.qlist(lieges) do
		if not self:isEnemy(p) then
			has_friend = true
			break
		end
	end
	return has_friend
end

sgs.ai_choicemade_filter.skillInvoke.hujia = function(self, player, promptlist)
	if promptlist[#promptlist] == "yes" then
		sgs.hujiasource = player
	end
end

function sgs.ai_slash_prohibit.hujia(self, from, to)
	if self:isFriend(to, from) then return false end
	local guojia = self.room:findPlayerBySkillName("tiandu")
	if guojia and guojia:getKingdom() == "wei" and self:isFriend(to, guojia) then return sgs.ai_slash_prohibit.tiandu(self, from, guojia) end
end

sgs.ai_choicemade_filter.cardResponded["@hujia-jink"] = function(self, player, promptlist)
	if promptlist[#promptlist] ~= "_nil_" then
		sgs.updateIntention(player, sgs.hujiasource, -80)
		sgs.hujiasource = nil
	elseif sgs.hujiasource then
		if self:isFriend(player, sgs.hujiasource) then sgs.card_lack[player:objectName()]["Jink"] = 1 end
		if player:objectName() == self.room:getLieges("wei", sgs.hujiasource):last():objectName() then sgs.hujiasource = nil end
	end
end

sgs.ai_skill_cardask["@hujia-jink"] = function(self)
	if not self:isFriend(sgs.hujiasource) then return "." end
	if self:needBear() then return "." end
	local bgm_zhangfei = self.room:findPlayerBySkillName("dahe")
	if bgm_zhangfei and bgm_zhangfei:isAlive() and sgs.hujiasource:hasFlag("dahe") then
		for _, card in ipairs(self:getCards("Jink")) do
			if card:getSuit() == sgs.Card_Heart then
				return card:toString()
			end
		end
		return "."
	end
	return self:getCardId("Jink") or "."
end

-- 反馈
sgs.ai_skill_invoke.fankui = function(self, data)
	local target = data:toPlayer()
	if sgs.ai_need_damaged.fankui(self, target, self.player) then return true end

	if self:isFriend(target) then
		if self:getOverflow(target) > 2 then return true end
		return (target:hasSkills("kofxiaoji|xiaoji") and not target:getEquips():isEmpty()) or self:needToThrowArmor(target)
	end
	if self:isEnemy(target) then				---fankui without zhugeliang and luxun
		if target:hasSkills("tuntian+zaoxian") and target:getPhase() == sgs.Player_NotActive then return false end
		if (self:needKongcheng(target) or self:getLeastHandcardNum(target) == 1) and target:getHandcardNum() == 1 then
			if not target:getEquips():isEmpty() then return true
			else return false
			end
		end
	end
	return true
end

sgs.ai_skill_cardchosen.fankui = function(self, who, flags)
	local suit = sgs.ai_need_damaged.fankui(self, who, self.player)
	if not suit then return nil end

	local cards = sgs.QList2Table(who:getEquips())
	local handcards = sgs.QList2Table(who:getHandcards())
	if #handcards == 1 and handcards[1]:hasFlag("visible") then table.insert(cards, handcards[1]) end

	for i = 1, #cards, 1 do
		if (cards[i]:getSuit() == suit and suit ~= sgs.Card_Spade)
			or (cards[i]:getSuit() == suit and suit == sgs.Card_Spade and cards[i]:getNumber() >= 2 and cards[i]:getNumber() <= 9) then
			return cards[i]:getEffectiveId()
		end
	end
	return nil
end

sgs.ai_need_damaged.fankui = function(self, attacker, player)
	if not attacker or not player:hasSkills("guicai|nosguicai") then return false end
	local need_retrial = function(splayer)
		local alive_num = self.room:alivePlayerCount()
		return alive_num + splayer:getSeat() % alive_num > self.room:getCurrent():getSeat()
				and splayer:getSeat() < alive_num + self.player:getSeat() % alive_num
	end
	local retrial_card ={ ["spade"] = nil, ["heart"] = nil, ["club"] = nil }
	local attacker_card ={ ["spade"] = nil, ["heart"]= nil, ["club"] = nil }

	local handcards = sgs.QList2Table(player:getHandcards())
	for i = 1, #handcards, 1 do
		local flag = string.format("%s_%s_%s", "visible", attacker:objectName(), player:objectName())
		if player:objectName() == self.player:objectName() or handcards[i]:hasFlag("visible") or handcards[1]:hasFlag(flag) then
			if handcards[i]:getSuit() == sgs.Card_Spade and handcards[i]:getNumber() >= 2 and handcards[i]:getNumber() <= 9 then
				retrial_card.spade = true
			end
			if handcards[i]:getSuit() == sgs.Card_Heart then
				retrial_card.heart = true
			end
			if handcards[i]:getSuit() == sgs.Card_Club then
				retrial_card.club = true
			end
		end
	end

	local cards = sgs.QList2Table(attacker:getEquips())
	local handcards = sgs.QList2Table(attacker:getHandcards())
	if #handcards == 1 and handcards[1]:hasFlag("visible") then table.insert(cards, handcards[1]) end

	for i = 1, #cards, 1 do
		if cards[i]:getSuit() == sgs.Card_Spade and cards[i]:getNumber() >= 2 and cards[i]:getNumber() <= 9 then
			attacker_card.spade = sgs.Card_Spade
		end
		if cards[i]:getSuit() == sgs.Card_Heart then
			attacker_card.heart = sgs.Card_Heart
		end
		if cards[i]:getSuit() == sgs.Card_Club then
			attacker_card.club = sgs.Card_Club
		end
	end

	local players = self.room:getOtherPlayers(player)
	for _, p in sgs.qlist(players) do
		if p:containsTrick("lightning") and self:getFinalRetrial(p) == 1 and need_retrial(p) then
			if not retrial_card.spade and attacker_card.spade then return attacker_card.spade end
		end

		if self:isFriend(p, player) and not p:containsTrick("YanxiaoCard") and not p:hasSkill("qiaobian") then
			if p:containsTrick("indulgence") and self:getFinalRetrial(p) == 1 and need_retrial(p) and p:getHandcardNum() >= p:getHp() then
				if not retrial_card.heart and attacker_card.heart then return attacker_card.heart end
			end
			if p:containsTrick("supply_shortage") and self:getFinalRetrial(p) == 1 and need_retrial(p) and p:hasSkill("yongsi") then
				if not retrial_card.club and attacker_card.club then return attacker_card.club end
			end
		end
	end
	return false
end

sgs.ai_choicemade_filter.skillInvoke.fankui = function(self, player, promptlist)
	local damage = self.room:getTag("CurrentDamageStruct"):toDamage()
	if damage.from and damage.to and promptlist[#promptlist] ~= "yes" then
		if not self:doNotDiscard(damage.from, "he") then
			sgs.updateIntention(damage.to, damage.from, -40)
		end
	end
end

sgs.ai_choicemade_filter.cardChosen.fankui = function(self, player, promptlist)
	local damage = self.room:getTag("CurrentDamageStruct"):toDamage()
	if damage.from and damage.to then
		local id = tonumber(promptlist[3])
		local place = self.room:getCardPlace(id)
		if sgs.ai_need_damaged.fankui(self, damage.from, damage.to) then
		elseif damage.from:getArmor() and self:needToThrowArmor(damage.from) and id == damage.from:getArmor():getEffectiveId() then
		elseif self:getOverflow(damage.from) > 2 or (damage.from:hasSkills(sgs.lose_equip_skill) and place == sgs.Player_PlaceEquip) then
		else
			sgs.updateIntention(damage.to, damage.from, 60)
		end
	end
end

-- 鬼才
sgs.ai_skill_cardask["@guicai-card"] = function(self, data)
	local judge = data:toJudge()

	if self.room:getMode():find("_mini_46") and not judge:isGood() then return "$" .. self.player:handCards():first() end
	if self:needRetrial(judge) then
		local cards = sgs.QList2Table(self.player:getHandcards())
		for _, id in sgs.qlist(self.player:getPile("wooden_ox")) do
			cards:prepend(sgs.Sanguosha:getCard(id))
		end
		local card_id = self:getRetrialCardId(cards, judge)
		if card_id ~= -1 then
			return "$" .. card_id
		end
	end

	return "."
end

function sgs.ai_cardneed.guicai(to, card, self)
	for _, player in sgs.qlist(self.room:getAllPlayers()) do
		if self:getFinalRetrial(to) == 1 then
			if player:containsTrick("lightning") and not player:containsTrick("YanxiaoCard") then
				return card:getSuit() == sgs.Card_Spade and card:getNumber() >= 2 and card:getNumber() <= 9 and not self.player:hasSkills("hongyan|wuyan")
			end
			if self:isFriend(player) and self:willSkipDrawPhase(player) then
				return card:getSuit() == sgs.Card_Club
			end
			if self:isFriend(player) and self:willSkipPlayPhase(player) then
				return card:getSuit() == sgs.Card_Heart
			end
		end
	end
end

sgs.guicai_suit_value = {
	heart = 3.9,
	club = 3.9,
	spade = 3.5
}

-- 刚烈
sgs.ai_skill_invoke.ganglie = function(self, data)
	local damage = data:toDamage()
	if not damage.from then
		local zhangjiao = self.room:findPlayerBySkillName("guidao")
		return zhangjiao and self:isFriend(zhangjiao) and not zhangjiao:isNude()
	end
	return not self:isFriend(damage.from) and self:canAttack(damage.from) and (damage.from:isNude() or not self:doNotDiscard(damage.from, "he"))
end

sgs.ai_need_damaged.ganglie = function(self, attacker, player)
	if not attacker then return false end
	if self:isEnemy(attacker) and self:isWeak(attacker) and sgs.isGoodTarget(attacker, self:getEnemies(attacker), self) then
		return true
	end
	return false
end

function sgs.ai_slash_prohibit.ganglie(self, from, to)
	if self:isFriend(from, to) then return false end
	if from:hasSkill("jueqing") or (from:hasSkill("nosqianxi") and from:distanceTo(to) == 1) then return false end
	if from:hasFlag("NosJiefanUsed") then return false end
	return self:isWeak(from)
end

sgs.ai_choicemade_filter.skillInvoke.ganglie = function(self, player, promptlist)
	local damage = self.room:getTag("CurrentDamageStruct"):toDamage()
	if damage.from and damage.to then
		if promptlist[#promptlist] == "yes" then
			if not self:getDamagedEffects(damage.from, player) and not self:needToLoseHp(damage.from, player)
				and (damage.from:isNude() or not self:doNotDiscard(damage.from, "he")) then
				sgs.updateIntention(damage.to, damage.from, 40)
			end
		elseif self:canAttack(damage.from) then
			sgs.updateIntention(damage.to, damage.from, -40)
		end
	end
end

-- 清俭
sgs.ai_skill_askforyiji.qingjian = function(self, card_ids)
	local move_skill = self.player:getTag("QingjianCurrentMoveSkill"):toString()
	if move_skill == "rende" or move_skill == "nosrende" then return nil, -1 end
	return sgs.ai_skill_askforyiji.nosyiji(self, card_ids)
end

function SmartAI:getTuxiTargets(reason, isDummy)
	if self.player:getPile("yiji"):length() > 1 then return {} end

	reason = reason or "tuxi"
	self:sort(self.enemies, "handcard")
	local upperlimit = (reason == "tuxi") and self.player:getMark("tuxi") or (reason == "koftuxi" and 1 or 2)
	local targets = {}

	local zhugeliang = self.room:findPlayerBySkillName("kongcheng")
	local luxun = self.room:findPlayerBySkillName("lianying")
	local nosluxun = self.room:findPlayerBySkillName("noslianying")
	local dengai = self.room:findPlayerBySkillName("tuntian")
	local jiangwei = self.room:findPlayerBySkillName("zhiji")

	local add_player = function(player, isfriend)
		if player:getHandcardNum() == 0 or player:objectName() == self.player:objectName() then return #targets end
		if reason == "tuxi" and player:getHandcardNum() < self.player:getHandcardNum() then return #targets end
		if reason == "koftuxi" and player:getHandcardNum() <= self.player:getHandcardNum() then return #targets end
		if self:objectiveLevel(player) == 0 and player:isLord() and sgs.current_mode_players["rebel"] > 1 then return #targets end
		if #targets == 0 then
			table.insert(targets, player:objectName())
		elseif #targets > 0 then
			if not table.contains(targets, player:objectName()) then
				table.insert(targets, player:objectName())
			end
		end
		if not isDummy and isfriend and isfriend == 1 then
			self.player:setFlags("AI_TuxiToFriend_" .. player:objectName())
		end
		return #targets
	end

	local lord = self.room:getLord()
	if lord and self:isEnemy(lord) and sgs.turncount <= 1 and not lord:isKongcheng() then
		add_player(lord)
	end

	if jiangwei and self:isFriend(jiangwei) and jiangwei:getMark("zhiji") == 0 and jiangwei:getHandcardNum()== 1
		and self:getEnemyNumBySeat(self.player, jiangwei) <= (jiangwei:getHp() >= 3 and 1 or 0) then
		if add_player(jiangwei, 1) == upperlimit then return targets end
	end
	if dengai and dengai:hasSkill("zaoxian") and self:isFriend(dengai) and (not self:isWeak(dengai) or self:getEnemyNumBySeat(self.player, dengai) == 0)
		and dengai:getMark("zaoxian") == 0 and dengai:getPile("field"):length() == 2 and add_player(dengai, 1) == upperlimit then
		return targets
	end

	if zhugeliang and self:isFriend(zhugeliang) and zhugeliang:getHandcardNum() == 1 and self:getEnemyNumBySeat(self.player, zhugeliang) > 0 then
		if zhugeliang:getHp() <= 2 then
			if add_player(zhugeliang, 1) == upperlimit then return targets end
		else
			local flag = string.format("%s_%s_%s", "visible", self.player:objectName(), zhugeliang:objectName())
			local cards = sgs.QList2Table(zhugeliang:getHandcards())
			if #cards == 1 and (cards[1]:hasFlag("visible") or cards[1]:hasFlag(flag)) then
				if cards[1]:isKindOf("TrickCard") or cards[1]:isKindOf("Slash") or cards[1]:isKindOf("EquipCard") then
					if add_player(zhugeliang, 1) == upperlimit then return targets end
				end
			end
		end
	end

	if luxun and self:isFriend(luxun) and luxun:getHandcardNum() == 1 and self:getEnemyNumBySeat(self.player, luxun) > 0 then
		local flag = string.format("%s_%s_%s", "visible", self.player:objectName(), luxun:objectName())
		local cards = sgs.QList2Table(luxun:getHandcards())
		if #cards == 1 and (cards[1]:hasFlag("visible") or cards[1]:hasFlag(flag)) then
			if cards[1]:isKindOf("TrickCard") or cards[1]:isKindOf("Slash") or cards[1]:isKindOf("EquipCard") then
				if add_player(luxun, 1) == upperlimit then return targets end
			end
		end
	end

	if nosluxun and self:isFriend(nosluxun) and nosluxun:getHandcardNum() == 1 and self:getEnemyNumBySeat(self.player, nosluxun) > 0 then
		local flag = string.format("%s_%s_%s", "visible", self.player:objectName(), nosluxun:objectName())
		local cards = sgs.QList2Table(nosluxun:getHandcards())
		if #cards == 1 and (cards[1]:hasFlag("visible") or cards[1]:hasFlag(flag)) then
			if cards[1]:isKindOf("TrickCard") or cards[1]:isKindOf("Slash") or cards[1]:isKindOf("EquipCard") then
				if add_player(nosluxun, 1) == upperlimit then return targets end
			end
		end
	end

	for i = 1, #self.enemies, 1 do
		local p = self.enemies[i]
		local cards = sgs.QList2Table(p:getHandcards())
		local flag = string.format("%s_%s_%s", "visible", self.player:objectName(), p:objectName())
		for _, card in ipairs(cards) do
			if (card:hasFlag("visible") or card:hasFlag(flag)) and (card:isKindOf("Peach") or card:isKindOf("Nullification") or card:isKindOf("Analeptic")) then
				if add_player(p) == upperlimit then return targets end
			end
		end
	end

	for i = 1, #self.enemies, 1 do
		local p = self.enemies[i]
		if p:hasSkills("jijiu|qingnang|xinzhan|leiji|jieyin|beige|kanpo|liuli|qiaobian|zhiheng|guidao|longhun|xuanfeng|tianxiang|noslijian|lijian") then
			if add_player(p) == upperlimit then return targets end
		end
	end

	for i = 1, #self.enemies, 1 do
		local p = self.enemies[i]
		local x = p:getHandcardNum()
		local good_target = true
		if x == 1 and p:hasSkills(sgs.need_kongcheng) then good_target = false end
		if x >= 2 and p:hasSkills("tuntian+zaoxian") then good_target = false end
		if good_target and add_player(p) == upperlimit then return targets end
	end

	if luxun and add_player(luxun, (self:isFriend(luxun) and 1 or nil)) == upperlimit then
		return targets
	end

	if dengai and self:isFriend(dengai) and (not self:isWeak(dengai) or self:getEnemyNumBySeat(self.player, dengai) == 0) and add_player(dengai, 1) == upperlimit then
		return targets
	end

	local others = self.room:getOtherPlayers(self.player)
	for _, other in sgs.qlist(others) do
		if self:objectiveLevel(other) >= 0 and other:hasSkills("tuntian+zaoxian") and add_player(other) == upperlimit then
			return targets
		end
	end

	if reason ~= "nostuxi" then return targets end

	for _, other in sgs.qlist(others) do
		if self:objectiveLevel(other) >= 0 and not other:hasSkills("tuntian+zaoxian") and add_player(other) == 1 and math.random(0, 5) <= 1 then
			return targets
		end
	end

	return {}
end

-- 突袭
sgs.ai_skill_use["@@tuxi"] = function(self, prompt)
	local targets = self:getTuxiTargets()
	if #targets > 0 then return "@TuxiCard=.->" .. table.concat(targets, "+") end
	return "."
end

sgs.ai_card_intention.TuxiCard = function(self, card, from, tos)
	local lord = self.room:getLord()
	if sgs.evaluatePlayerRole(from) == "neutral" and sgs.evaluatePlayerRole(tos[1]) == "neutral"
		and (not tos[2] or sgs.evaluatePlayerRole(tos[2]) == "neutral") and lord and not lord:isKongcheng()
		and not (lord:hasSkills("kongcheng|zhiji") and lord:getHandcardNum() == 1)
		and self:hasLoseHandcardEffective(lord) and not lord:hasSkills("tuntian+zaoxian") and from:aliveCount() >= 4 then
		sgs.updateIntention(from, lord, -35)
		return
	end
	if from:getState() == "online" then
		for _, to in ipairs(tos) do
			if (to:hasSkills("kongcheng|zhiji|lianying|noslianying") and to:getHandcardNum() == 1) or to:hasSkills("tuntian+zaoxian") then
			else
				sgs.updateIntention(from, to, 80)
			end
		end
	else
		for _, to in ipairs(tos) do
			local intention = from:hasFlag("AI_TuxiToFriend_" .. to:objectName()) and -5 or 80
			sgs.updateIntention(from, to, intention)
		end
	end
end

-- 裸衣
sgs.ai_skill_invoke.luoyi = function(self)
	if self.player:getPile("yiji"):length() > 1 then return false end
	local diaochan = self.room:findPlayerBySkillName("lijian") or self.room:findPlayerBySkillName("noslijian")
	if diaochan and self:isEnemy(diaochan) then
		for _, friend in ipairs(self.friends_noself) do
			if self:isWeak(friend) or friend:getHp() <= 2 then return false end
		end
	end
	return not self:isWeak()
end

function sgs.ai_cardneed.luoyi(to, card, self)
	local slash_num = 0
	local target
	local slash = sgs.cloneCard("slash")

	local cards = to:getHandcards()
	local need_slash = true
	for _, c in sgs.qlist(cards) do
		local flag = string.format("%s_%s_%s", "visible", self.room:getCurrent():objectName(), to:objectName())
		if c:hasFlag("visible") or c:hasFlag(flag) then
			if isCard("Slash", c, to) then
				need_slash = false
				break
			end
		end
	end

	self:sort(self.enemies, "defenseSlash")
	for _, enemy in ipairs(self.enemies) do
		if to:canSlash(enemy) and not self:slashProhibit(slash, enemy) and self:slashIsEffective(slash, enemy) and sgs.getDefenseSlash(enemy, self) <= 2 then
			target = enemy
			break
		end
	end

	if need_slash and target and isCard("Slash", card, to) then return true end
	return isCard("Duel", card, to)
end

sgs.luoyi_keep_value = {
	Peach = 6,
	Analeptic = 5.8,
	Jink = 5.2,
	Duel = 5.5,
	FireSlash = 5.6,
	Slash = 5.4,
	ThunderSlash = 5.5,
	Axe = 5,
	Blade = 4.9,
	Spear = 4.9,
	Fan = 4.8,
	KylinBow = 4.7,
	Halberd = 4.6,
	MoonSpear = 4.5,
	SPMoonSpear = 4.5,
	DefensiveHorse = 4
}

-- 天妒
sgs.ai_skill_invoke.tiandu = function(self, data)
	return not self:needKongcheng(self.player, true)
end

function sgs.ai_slash_prohibit.tiandu(self, from, to)
	if self:isEnemy(to, from) and self:hasEightDiagramEffect(to) then return true end
end

-- 遗计
sgs.ai_skill_invoke.yiji = function(self)
	local sb_diaochan = self.room:getCurrent()
	if sb_diaochan and sb_diaochan:hasSkill("lihun") and not sb_diaochan:hasUsed("LihunCard") and not self:isFriend(sb_diaochan) and sb_diaochan:getPhase() == sgs.Player_Play then
		return #self.friends_noself > 0
	end
	return true
end

sgs.ai_skill_use["@@yiji"] = function(self, prompt)
	self.yiji = {}
	if self.player:getHandcardNum() <= 2 then return "." end
	local friends = {}
	for _, friend in ipairs(self.friends_noself) do
		if not self:willSkipDrawPhase(friend) then table.insert(friends, friend) end
	end
	if #friends == 0 then return "." end
	local friend_table = {}
	local cards = sgs.QList2Table(self.player:getHandcards())
	while true do
		local card, friend = self:getCardNeedPlayer(cards, friends, false)
		if not (card and friend) then break end
		if not self.yiji[friend:objectName()] then
			self.yiji[friend:objectName()] = { card:getEffectiveId() }
		else
			table.insert(self.yiji[friend:objectName()], card:getEffectiveId())
		end
		cards = self:resetCards(cards, card)
		if #self.yiji[friend:objectName()] == 2 then
			table.insert(friend_table, friend:objectName())
			local temp = {}
			for _, f in ipairs(friends) do
				if f:objectName() ~= friend:objectName() then table.insert(temp, f) end
			end
			friends = temp
		end
		if #cards == 0 or #friend_table == 2 then break end
	end
	if #friend_table > 0 then return "@YijiCard=.->" .. table.concat(friend_table, "+") end
	return "."
end

sgs.ai_card_intention.YijiCard = -80

sgs.ai_skill_discard.yiji = function(self)
	local target = self.player:getTag("YijiTarget"):toString()
	return self.yiji[target]
end

-- 洛神
function SmartAI:willSkipPlayPhase(player, no_null)
	local player = player or self.player
	if player:isSkipped(sgs.Player_Play) then return true end

	local fuhuanghou = self.room:findPlayerBySkillName("noszhuikong")
	if fuhuanghou and fuhuanghou:objectName() ~= player:objectName() and self:isEnemy(player, fuhuanghou)
		and fuhuanghou:isWounded() and fuhuanghou:getHandcardNum() > 1 and not player:isKongcheng() and not self:isWeak(fuhuanghou) then
		local max_card = self:getMaxCard(fuhuanghou)
		local player_max_card = self:getMaxCard(player)
		local max_number = max_card and max_card:getNumber() or 0
		local player_max_number = player_max_card and player_max_card:getNumber() or 0
		if fuhuanghou:hasSkill("yingyang") then max_number = math.max(max_number + 3, 13) end
		if player:hasSkill("yingyang") then player_max_number = math.max(player_max_number + 3, 13) end
		if (max_card and player_max_card and max_number > player_max_number) or max_number >= 12 then return true end
	end

	if self.player:containsTrick("YanxiaoCard") or self.player:hasSkill("keji") or (self.player:hasSkill("qiaobian") and not self.player:isKongcheng()) then return false end
	local friend_null, friend_snatch_dismantlement = 0, 0
	if self.player:getPhase() == sgs.Player_Play and self.player:objectName() ~= player:objectName() and self:isFriend(player) then
		for _, hcard in sgs.qlist(self.player:getCards("he")) do
			local objectName
			if isCard("Snatch", hcard, self.player) then objectName = "snatch"
			elseif isCard("Dismantlement", hcard, self.player) then objectName = "dismantlement" end
			if objectName then
				local trick = sgs.cloneCard(objectName, hcard:getSuit(), hcard:getNumber())
				local targets = self:exclude({ player }, trick)
				if #targets > 0 then friend_snatch_dismantlement = friend_snatch_dismantlement + 1 end
			end
		end
	end
	if not no_null then
		for _, p in sgs.qlist(self.room:getOtherPlayers(self.player)) do
			if self:isFriend(p) then friend_null = friend_null + getCardsNum("Nullification", p, self.player) end
			if self:isEnemy(p) then friend_null = friend_null - getCardsNum("Nullification", p, self.player) end
		end
		friend_null = friend_null + self:getCardsNum("Nullification")
	end
	return self.player:containsTrick("indulgence") and friend_null + friend_snatch_dismantlement <= 1
end

function SmartAI:willSkipDrawPhase(player, no_null)
	local player = player or self.player
	if player:isSkipped(sgs.Player_Draw) then return false end
	if self.player:containsTrick("YanxiaoCard") or (self.player:hasSkill("qiaobian") and not self.player:isKongcheng()) then return false end
	local friend_null, friend_snatch_dismantlement = 0, 0
	if self.player:getPhase() == sgs.Player_Play and self.player:objectName() ~= player:objectName() and self:isFriend(player) then
		for _, hcard in sgs.qlist(self.player:getCards("he")) do
			local objectName
			if isCard("Snatch", hcard, self.player) then objectName = "snatch"
			elseif isCard("Dismantlement", hcard, self.player) then objectName = "dismantlement" end
			if objectName then
				local trick = sgs.cloneCard(objectName, hcard:getSuit(), hcard:getNumber())
				local targets = self:exclude({ player }, trick)
				if #targets > 0 then friend_snatch_dismantlement = friend_snatch_dismantlement + 1 end
			end
		end
	end
	if not no_null then
		for _, p in sgs.qlist(self.room:getOtherPlayers(self.player)) do
			if self:isFriend(p) then friend_null = friend_null + getCardsNum("Nullification", p, self.player) end
			if self:isEnemy(p) then friend_null = friend_null - getCardsNum("Nullification", p, self.player) end
		end
		friend_null = friend_null + self:getCardsNum("Nullification")
	end
	return self.player:containsTrick("supply_shortage") and friend_null + friend_snatch_dismantlement <= 1
end

sgs.ai_skill_invoke.luoshen = function(self, data)
 	if self:willSkipPlayPhase() then
		local erzhang = self.room:findPlayerBySkillName("guzheng")
		if erzhang and self:isEnemy(erzhang) then return false end
		if self.player:getPile("incantation"):length() > 0 then
			local card = sgs.Sanguosha:getCard(self.player:getPile("incantation"):first())
			if not self.player:getJudgingArea():isEmpty() and not self.player:containsTrick("YanxiaoCard") and not self:hasWizard(self.enemies, true) then
				local trick = self.player:getJudgingArea():last()
				if trick:isKindOf("Indulgence") then
					if card:getSuit() == sgs.Card_Heart or (self.player:hasSkill("hongyan") and card:getSuit() == sgs.Card_Spade) then return false end
				elseif trick:isKindOf("SupplyShortage") then
					if card:getSuit() == sgs.Card_Club then return false end
				end
			end
			local zhangbao = self.room:findPlayerBySkillName("yingbing")
			if zhangbao and self:isEnemy(zhangbao) and not zhangbao:hasSkill("manjuan")
				and (card:isRed() or (self.player:hasSkill("hongyan") and card:getSuit() == sgs.Card_Spade)) then return false end
		end
 	end
 	return true
end

-- 倾国
sgs.ai_view_as.qingguo = function(card, player, card_place)
	local suit = card:getSuitString()
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	if card:isBlack() and card_place == sgs.Player_PlaceHand then
		return ("jink:qingguo[%s:%s]=%d"):format(suit, number, card_id)
	end
end

function sgs.ai_cardneed.qingguo(to, card)
	return to:getCards("h"):length() < 2 and card:isBlack()
end

sgs.qingguo_suit_value = {
	spade = 4.1,
	club = 4.2
}

-- 恂恂
sgs.ai_skill_invoke.xunxun = function(self, data)
	return true
end

-- 忘隙
function sgs.ai_skill_invoke.wangxi(self, data)
	local target = data:toPlayer()
	if self:isFriend(target) then
		return not self:needKongcheng(target, true) and not (hasManjuanEffect(self.player) and hasManjuanEffect(target))
	else
		if hasManjuanEffect(self.player) then return false end
		return self:needKongcheng(target, true) or hasManjuanEffect(target)
	end
end

sgs.ai_choicemade_filter.skillInvoke.wangxi = function(self, player, promptlist)
	local damage = self.room:getTag("CurrentDamageStruct"):toDamage()
	local target = nil
	if damage.from and damage.from:objectName() == player:objectName() then
		target = damage.to
	elseif damage.to and damage.to:objectName() == player:objectName() then
		target = damage.from
	end
	if target and promptlist[#promptlist] == "yes" then
		if self:needKongcheng(target, true) then sgs.updateIntention(player, target, 10)
		elseif not hasManjuanEffect(target) and player:getState() == "robot" then sgs.updateIntention(player, target, -60)
		end
	end
end

-- 仁德
function SmartAI:resetCards(cards, except)
	local result = {}
	for _, c in ipairs(cards) do
		if c:getEffectiveId() ~= except:getEffectiveId() then table.insert(result, c) end
	end
	return result
 end

function SmartAI:shouldUseRende()
	if (self:hasCrossbowEffect() or self:getCardsNum("Crossbow") > 0) and self:getCardsNum("Slash") > 0 then
		self:sort(self.enemies, "defense")
		for _, enemy in ipairs(self.enemies) do
			local inAttackRange = self.player:distanceTo(enemy) == 1 or self.player:distanceTo(enemy) == 2
									and self:getCardsNum("OffensiveHorse") > 0 and not self.player:getOffensiveHorse()
			if inAttackRange and sgs.isGoodTarget(enemy, self.enemies, self) then
				local slashs = self:getCards("Slash")
				local slash_count = 0
				for _, slash in ipairs(slashs) do
					if not self:slashProhibit(slash, enemy) and self:slashIsEffective(slash, enemy) then
						slash_count = slash_count + 1
					end
				end
				if slash_count >= enemy:getHp() then return false end
			end
		end
	end
	for _, enemy in ipairs(self.enemies) do
		if enemy:canSlash(self.player) and not self:slashProhibit(nil, self.player, enemy) then
			if enemy:hasWeapon("guding_blade") and self.player:getHandcardNum() == 1 and getCardsNum("Slash", enemy, self.player) >= 1 then
				return
			elseif self:hasCrossbowEffect(enemy) and getCardsNum("Slash", enemy, self.player) > 1 and self:getOverflow() <= 0 then
				return
			end
		end
	end

	for _, player in ipairs(self.friends_noself) do
		if (player:hasSkill("haoshi") and not player:containsTrick("supply_shortage")) or player:hasSkill("jijiu") then
			return true
		end
	end
	if ((self.player:hasSkill("rende") and self.player:getMark("rende") < 2)
		or (self.player:hasSkill("nosrende") and self.player:getMark("nosrende") < 2)
		or self:getOverflow() > 0) then
		return true
	end
	if self.player:getLostHp() < 2 then
		return true
	end
end

local rende_skill = {}
rende_skill.name = "rende"
table.insert(sgs.ai_skills, rende_skill)
rende_skill.getTurnUseCard = function(self)
	if self.player:hasUsed("RendeCard") or self.player:isKongcheng() then return end
	local mode = string.lower(global_room:getMode())
	if self.player:getMark("rende") > 1 and mode:find("04_1v3") then return end

	if self:shouldUseRende() then
		return sgs.Card_Parse("@RendeCard=.")
	end
end

sgs.ai_skill_use_func.RendeCard = function(card, use, self)
	local cards = sgs.QList2Table(self.player:getHandcards())
	self:sortByUseValue(cards, true)

	local notFound
	for i = 1, #cards do
		local card, friend-- = self:getCardNeedPlayer(cards)
		if card and friend then
			cards = self:resetCards(cards, card)
		else
			notFound = true
			break
		end

		if friend:objectName() == self.player:objectName() or not self.player:getHandcards():contains(card) then continue end
		local canJijiang = self.player:hasLordSkill("jijiang") and friend:getKingdom() == "shu"
		if card:isAvailable(self.player) and ((card:isKindOf("Slash") and not canJijiang) or card:isKindOf("Duel") or card:isKindOf("Snatch") or card:isKindOf("Dismantlement")) then
			local dummy_use = { isDummy = true, to = sgs.SPlayerList() }
			local cardtype = card:getTypeId()
			self["use" .. sgs.ai_type_name[cardtype + 1] .. "Card"](self, card, dummy_use)
			if dummy_use.card and dummy_use.to:length() > 0 then
				if card:isKindOf("Slash") or card:isKindOf("Duel") then
					local t1 = dummy_use.to:first()
					if dummy_use.to:length() > 1 then continue
					elseif t1:getHp() == 1 or sgs.card_lack[t1:objectName()]["Jink"] == 1
							or t1:isCardLimited(sgs.cloneCard("jink"), sgs.Card_MethodResponse) then continue
					end
				elseif (card:isKindOf("Snatch") or card:isKindOf("Dismantlement")) and self:getEnemyNumBySeat(self.player, friend) > 0 then
					local hasDelayedTrick
					for _, p in sgs.qlist(dummy_use.to) do
						if self:isFriend(p) and (self:willSkipDrawPhase(p) or self:willSkipPlayPhase(p)) then hasDelayedTrick = true break end
					end
					if hasDelayedTrick then continue end
				end
			end
		elseif card:isAvailable(self.player) and self:getEnemyNumBySeat(self.player, friend) > 0 and (card:isKindOf("Indulgence") or card:isKindOf("SupplyShortage")) then
			local dummy_use = { isDummy = true }
			self:useTrickCard(card, dummy_use)
			if dummy_use.card then continue end
		end

		if friend:hasSkill("enyuan") and #cards >= 1 and not (self.room:getMode() == "04_1v3" and self.player:getMark("rende") == 1) then
			use.card = sgs.Card_Parse("@RendeCard=" .. card:getId() .. "+" .. cards[1]:getId())
		else
			use.card = sgs.Card_Parse("@RendeCard=" .. card:getId())
		end
		if use.to then use.to:append(friend) end
		return
	end

	if notFound then
		local pangtong = self.room:findPlayerBySkillName("manjuan")
		if not pangtong then return end
		local cards = sgs.QList2Table(self.player:getHandcards())
		self:sortByUseValue(cards, true)
		if self.player:isWounded() and self.player:getHandcardNum() > 3 and self.player:getMark("rende") < 2 then
			local to_give = {}
			for _, card in ipairs(cards) do
				if not isCard("Peach", card, self.player) and not isCard("ExNihilo", card, self.player) then table.insert(to_give, card:getId()) end
				if #to_give == 2 - self.player:getMark("rende") then break end
			end
			if #to_give > 0 then
				use.card = sgs.Card_Parse("@RendeCard=" .. table.concat(to_give, "+"))
				if use.to then use.to:append(pangtong) end
			end
		end
	end
end

sgs.ai_use_value.RendeCard = 8.5
sgs.ai_use_priority.RendeCard = 8.8

sgs.ai_card_intention.RendeCard = function(self, card, from, tos)
	local to = tos[1]
	local intention = -70
	if hasManjuanEffect(to) then
		intention = 0
	elseif to:hasSkill("kongcheng") and to:isKongcheng() then
		intention = 30
	end
	sgs.updateIntention(from, to, intention)
end

sgs.dynamic_value.benefit.RendeCard = true

sgs.ai_skill_use["@@rende"] = function(self, prompt)
	local cards = {}
	local rende_list = self.player:property("rende"):toString():split("+")
	for _, id in ipairs(rende_list) do
		local num_id = tonumber(id)
		local hcard = sgs.Sanguosha:getCard(num_id)
		if hcard then table.insert(cards, hcard) end
	end
	if #cards == 0 then return "." end
	self:sortByUseValue(cards, true)
	for i = 1, #cards do
		local card, friend = self:getCardNeedPlayer(cards)
		if card and friend then
			cards = self:resetCards(cards, card)
		else return "." end

		if friend:objectName() == self.player:objectName() or not self.player:getHandcards():contains(card) then continue end
		local canJijiang = self.player:hasLordSkill("jijiang") and friend:getKingdom() == "shu"
		if card:isAvailable(self.player) and ((card:isKindOf("Slash") and not canJijiang) or card:isKindOf("Duel") or card:isKindOf("Snatch") or card:isKindOf("Dismantlement")) then
			local dummy_use = { isDummy = true, to = sgs.SPlayerList() }
			local cardtype = card:getTypeId()
			self["use" .. sgs.ai_type_name[cardtype + 1] .. "Card"](self, card, dummy_use)
			if dummy_use.card and dummy_use.to:length() > 0 then
				if card:isKindOf("Slash") or card:isKindOf("Duel") then
					local t1 = dummy_use.to:first()
					if dummy_use.to:length() > 1 then continue
					elseif t1:getHp() == 1 or sgs.card_lack[t1:objectName()]["Jink"] == 1
							or t1:isCardLimited(sgs.cloneCard("jink"), sgs.Card_MethodResponse) then continue
					end
				elseif (card:isKindOf("Snatch") or card:isKindOf("Dismantlement")) and self:getEnemyNumBySeat(self.player, friend) > 0 then
					local hasDelayedTrick
					for _, p in sgs.qlist(dummy_use.to) do
						if self:isFriend(p) and (self:willSkipDrawPhase(p) or self:willSkipPlayPhase(p)) then hasDelayedTrick = true break end
					end
					if hasDelayedTrick then continue end
				end
			end
		elseif card:isAvailable(self.player) and self:getEnemyNumBySeat(self.player, friend) > 0 and (card:isKindOf("Indulgence") or card:isKindOf("SupplyShortage")) then
			local dummy_use = { isDummy = true }
			self:useTrickCard(card, dummy_use)
			if dummy_use.card then continue end
		end

		local usecard
		if friend:hasSkill("enyuan") and #cards >= 1 and not (self.room:getMode() == "04_1v3" and self.player:getMark("nosrende") == 1) then
			usecard = "@RendeCard=" .. card:getId() .. "+" .. cards[1]:getId()
		else
			usecard = "@RendeCard=" .. card:getId()
		end
		if usecard then return usecard .. "->" .. friend:objectName() end
	end
end

-- 激将
table.insert(sgs.ai_global_flags, "jijiangsource")
local jijiang_filter = function(self, player, carduse)
	if carduse.card:isKindOf("JijiangCard") or carduse.card:isKindOf("QinwangCard") then
		sgs.jijiangsource = player
	else
		sgs.jijiangsource = nil
	end
end

table.insert(sgs.ai_choicemade_filter.cardUsed, jijiang_filter)

sgs.ai_skill_invoke.jijiang = function(self, data)
	if sgs.jijiangsource then return false end
	local asked = data:toStringList()
	local prompt = asked[2]
	if self:askForCard("slash", prompt, 1) == "." then return false end

	local current = self.room:getCurrent()
	if self:isFriend(current) and current:getKingdom() == "shu" and self:getOverflow(current) > 2 and not self:hasCrossbowEffect(current) then
		return true
	end

	local cards = self.player:getHandcards()
	for _, card in sgs.qlist(cards) do
		if isCard("Slash", card, self.player) then
			return false
		end
	end

	local lieges = self.room:getLieges("shu", self.player)
	if lieges:isEmpty() then return false end
	local has_friend = false
	for _, p in sgs.qlist(lieges) do
		if not self:isEnemy(p) then
			has_friend = true
			break
		end
	end
	return has_friend
end

sgs.ai_choicemade_filter.skillInvoke.jijiang = function(self, player, promptlist)
	if promptlist[#promptlist] == "yes" then
		sgs.jijiangsource = player
	end
end

local jijiang_skill = {}
jijiang_skill.name = "jijiang"
table.insert(sgs.ai_skills, jijiang_skill)
jijiang_skill.getTurnUseCard = function(self)
	if not self.player:hasLordSkill("jijiang") then return end
	local lieges = self.room:getLieges("shu", self.player)
	if lieges:isEmpty() then return end
	local has_friend
	for _, p in sgs.qlist(lieges) do
		if self:isFriend(p) then
			has_friend = true
			break
		end
	end
	if not has_friend then return end
	if self.player:hasUsed("JijiangCard") or self.player:hasFlag("Global_JijiangFailed") or not self:slashIsAvailable() then return end
	local card_str = "@JijiangCard=."
	local slash = sgs.Card_Parse(card_str)
	assert(slash)
	return slash
end

sgs.ai_skill_use_func.JijiangCard = function(card, use, self)
	self:sort(self.enemies, "defenseSlash")

	if not sgs.jijiangtarget then table.insert(sgs.ai_global_flags, "jijiangtarget") end
	sgs.jijiangtarget = {}

	local dummy_use = { isDummy = true }
	dummy_use.to = sgs.SPlayerList()
	if self.player:hasFlag("slashTargetFix") then
		for _, p in sgs.qlist(self.room:getOtherPlayers(self.player)) do
			if p:hasFlag("SlashAssignee") then
				dummy_use.to:append(p)
			end
		end
	end
	local slash = sgs.cloneCard("slash")
	self:useCardSlash(slash, dummy_use)
	if dummy_use.card and dummy_use.to:length() > 0 then
		use.card = card
		for _, p in sgs.qlist(dummy_use.to) do
			table.insert(sgs.jijiangtarget, p)
			if use.to then use.to:append(p) end
		end
	end
end

sgs.ai_use_value.JijiangCard = 8.5
sgs.ai_use_priority.JijiangCard = 2.45

sgs.ai_card_intention.JijiangCard = function(self, card, from, tos)
	if not from:isLord() and global_room:getCurrent():objectName() == from:objectName() then
		return sgs.ai_card_intention.Slash(self, card, from, tos)
	end
end

sgs.ai_choicemade_filter.cardResponded["@jijiang-slash"] = function(self, player, promptlist)
	if promptlist[#promptlist] ~= "_nil_" then
		sgs.updateIntention(player, sgs.jijiangsource, -40)
		sgs.jijiangsource = nil
		sgs.jijiangtarget = nil
	elseif sgs.jijiangsource then
		if self:isFriend(player, sgs.jijiangsource) then sgs.card_lack[player:objectName()]["Slash"] = 1 end
		if player:objectName() == player:getRoom():getLieges("shu", sgs.jijiangsource):last():objectName() then
			sgs.jijiangsource = nil
			sgs.jijiangtarget = nil
		end
	end
end

sgs.ai_skill_cardask["@jijiang-slash"] = function(self, data)
	for _,p in sgs.qlist(self.room:getAllPlayers()) do
		if p:hasFlag("qinwangjijiang") then
			sgs.jijiangsource = p
		end
	end

	if not sgs.jijiangsource or not self:isFriend(sgs.jijiangsource) then return "." end
	if self:needBear() then return "." end

	local jijiangtargets = {}
	for _, player in sgs.qlist(self.room:getAllPlayers()) do
		if player:hasFlag("JijiangTarget") then
			if self:isFriend(player) and not (self:needToLoseHp(player, sgs.jijiangsource, true) or self:getDamagedEffects(player, sgs.jijiangsource, true)) then return "." end
			table.insert(jijiangtargets, player)
		end
	end

	if #jijiangtargets == 0 then
		return self:getCardId("Slash") or "."
	end

	self:sort(jijiangtargets, "defenseSlash")
	local slashes = self:getCards("Slash")
	for _, slash in ipairs(slashes) do
		for _, target in ipairs(jijiangtargets) do
			if not self:slashProhibit(slash, target, sgs.jijiangsource) and self:slashIsEffective(slash, target, sgs.jijiangsource) then
				return slash:toString()
			end
		end
	end
	return "."
end

function sgs.ai_cardsview_valuable.jijiang(self, class_name, player, need_lord)
	if class_name == "Slash" and sgs.Sanguosha:getCurrentCardUseReason() == sgs.CardUseStruct_CARD_USE_REASON_RESPONSE_USE
		and not player:hasFlag("Global_JijiangFailed") and (need_lord == false or player:hasLordSkill("jijiang")) then
		local current = self.room:getCurrent()
		if self:isFriend(current, player) and current:getKingdom() == "shu" and self:getOverflow(current) > 2 and not self:hasCrossbowEffect(current) then
			return "@JijiangCard=."
		end

		local cards = player:getHandcards()
		for _, card in sgs.qlist(cards) do
			if isCard("Slash", card, player) then return end
		end

		local lieges = self.room:getLieges("shu", player)
		if lieges:isEmpty() then return end
		local has_friend = false
		for _, p in sgs.qlist(lieges) do
			if self:isFriend(p, player) then
				has_friend = true
				break
			end
		end
		if has_friend then return "@JijiangCard=." end
	end
end

function SmartAI:getJijiangSlashNum(player)
	if not player then self.room:writeToConsole(debug.traceback()) return 0 end
	if not player:hasLordSkill("jijiang") then return 0 end
	local slashs = 0
	for _, p in sgs.qlist(self.room:getOtherPlayers(player)) do
		if p:getKingdom() == "shu" and ((sgs.turncount <= 1 and sgs.ai_role[p:objectName()] == "neutral") or self:isFriend(player, p)) then
			slashs = slashs + getCardsNum("Slash", p, self.player)
		end
	end
	return slashs
end

-- 武圣
sgs.ai_view_as.wusheng = function(card, player, card_place)
	local suit = card:getSuitString()
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	if card_place ~= sgs.Player_PlaceSpecial and card:isRed() and not card:isKindOf("Peach") and not card:hasFlag("using") then
		return ("slash:wusheng[%s:%s]=%d"):format(suit, number, card_id)
	end
end

local wusheng_skill = {}
wusheng_skill.name = "wusheng"
table.insert(sgs.ai_skills, wusheng_skill)
wusheng_skill.getTurnUseCard = function(self, inclusive)
	local cards = self.player:getCards("he")
	for _, id in sgs.qlist(self.player:getPile("wooden_ox")) do
		cards:prepend(sgs.Sanguosha:getCard(id))
	end
	cards = sgs.QList2Table(cards)

	local red_card
	self:sortByUseValue(cards, true)
	for _, card in ipairs(cards) do
		if card:isRed() and not card:isKindOf("Slash")
			and not isCard("Peach", card, self.player) and not isCard("ExNihilo", card, self.player)
			and (self:getUseValue(card) < sgs.ai_use_value.Slash or inclusive or sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_Residue, self.player, sgs.cloneCard("slash")) > 0) then
			red_card = card
			break
		end
	end

	if red_card then
		local suit = red_card:getSuitString()
		local number = red_card:getNumberString()
		local card_id = red_card:getEffectiveId()
		local card_str = ("slash:wusheng[%s:%s]=%d"):format(suit, number, card_id)
		local slash = sgs.Card_Parse(card_str)

		assert(slash)
		return slash
	end
end

sgs.ai_cardneed.wusheng = function(to, card)
	return to:getHandcardNum() < 3 and card:isRed()
end

-- 义绝
local yijue_skill = {}
yijue_skill.name = "yijue"
table.insert(sgs.ai_skills, yijue_skill)
yijue_skill.getTurnUseCard = function(self)
	if not self.player:hasUsed("YijueCard") and not self.player:isKongcheng() then return sgs.Card_Parse("@YijueCard=.") end
end

sgs.ai_skill_use_func.YijueCard = function(card, use, self)
	self:sort(self.enemies, "handcard")
	local max_card = self:getMaxCard()
	if not max_card then return end
	local max_point = max_card:getNumber()
	if self.player:hasSkill("yingyang") then max_point = math.min(max_point + 3, 13) end
	if self.player:hasSkill("kongcheng") and self.player:getHandcardNum() == 1 then
		for _, enemy in ipairs(self.enemies) do
			if not enemy:isKongcheng() and self:hasLoseHandcardEffective(enemy) and not (enemy:hasSkills("tuntian+zaoxian") and enemy:getHandcardNum() > 2) then
				sgs.ai_use_priority.YijueCard = 1.2
				self.tianyi_card = max_card:getId()
				use.card = sgs.Card_Parse("@YijueCard=.")
				if use.to then use.to:append(enemy) end
				return
			end
		end
	end
	for _, enemy in ipairs(self.enemies) do
		if enemy:hasFlag("AI_HuangtianPindian") and enemy:getHandcardNum() == 1 then
			sgs.ai_use_priority.YijueCard = 7.2
			self.yijue_card = max_card:getId()
			use.card = sgs.Card_Parse("@YijueCard=.")
			if use.to then
				use.to:append(enemy)
				enemy:setFlags("-AI_HuangtianPindian")
			end
			return
		end
	end

	local zhugeliang = self.room:findPlayerBySkillName("kongcheng")

	sgs.ai_use_priority.YijueCard = 7.2
	self:sort(self.enemies)
	self.enemies = sgs.reverse(self.enemies)
	for _, enemy in ipairs(self.enemies) do
		if not (enemy:hasSkill("kongcheng") and enemy:getHandcardNum() == 1) and not enemy:isKongcheng() then
			local enemy_max_card = self:getMaxCard(enemy)
			local enemy_max_point = enemy_max_card and enemy_max_card:getNumber() or 100
			if enemy_max_card and enemy:hasSkill("yingyang") then enemy_max_point = math.min(enemy_max_point + 3, 13) end
			if max_point > enemy_max_point then
				self.yijue_card = max_card:getId()
				use.card = sgs.Card_Parse("@YijueCard=.")
				if use.to then use.to:append(enemy) end
				return
			end
		end
	end
	for _, enemy in ipairs(self.enemies) do
		if not (enemy:hasSkill("kongcheng") and enemy:getHandcardNum() == 1) and not enemy:isKongcheng() then
			if max_point >= 10 then
				self.yijue_card = max_card:getId()
				use.card = sgs.Card_Parse("@YijueCard=.")
				if use.to then use.to:append(enemy) end
				return
			end
		end
	end

	sgs.ai_use_priority.YijueCard = 1.2
	local min_card = self:getMinCard()
	if not min_card then return end
	local min_point = min_card:getNumber()
	if self.player:hasSkill("yingyang") then min_point = math.max(min_point - 3, 1) end

	local wounded_friends = self:getWoundedFriend()
	if #wounded_friends > 0 then
		for _, wounded in ipairs(wounded_friends) do
			if wounded:getHandcardNum() > 1 and wounded:getLostHp() / wounded:getMaxHp() >= 0.3 then
				local w_max_card = self:getMaxCard(wounded)
				local w_max_number = w_max_card and w_max_card:getNumber() or 0
				if w_max_card and wounded:hasSkill("yingyang") then w_max_number = math.min(w_max_number + 3, 13) end
				if (w_max_card and w_max_number >= min_point) or min_point <= 4 then
					self.yijue_card = min_card:getId()
					use.card = sgs.Card_Parse("@YijueCard=.")
					if use.to then use.to:append(wounded) end
					return
				end
			end
		end
	end

	if zhugeliang and self:isFriend(zhugeliang) and zhugeliang:getHandcardNum() == 1 and zhugeliang:objectName() ~= self.player:objectName() then
		if min_point <= 4 then
			self.yijue_card = min_card:getId()
			use.card = sgs.Card_Parse("@YijueCard=.")
			if use.to then use.to:append(zhugeliang) end
			return
		end
		local cards = sgs.QList2Table(self.player:getHandcards())
		self:sortByUseValue(cards, true)
		if self:getEnemyNumBySeat(self.player, zhugeliang) >= 1 then
			if isCard("Jink", cards[1], self.player) and self:getCardsNum("Jink") == 1 then return end
			self.yijue_card = cards[1]:getId()
			use.card = sgs.Card_Parse("@YijueCard=.")
			if use.to then use.to:append(zhugeliang) end
			return
		end
	end
end

function sgs.ai_skill_pindian.yijue(minusecard, self, requestor)
	if requestor:getHandcardNum() == 1 then
		local cards = sgs.QList2Table(self.player:getHandcards())
		self:sortByKeepValue(cards)
		return cards[1]
	end
	return self:getMaxCard()
end

sgs.ai_cardneed.yijue = function(to, card, self)
	local cards = to:getHandcards()
	local has_big = false
	for _, c in sgs.qlist(cards) do
		local flag = string.format("%s_%s_%s", "visible", self.room:getCurrent():objectName(), to:objectName())
		if c:hasFlag("visible") or c:hasFlag(flag) then
			if c:getNumber() > 10 then
				has_big = true
				break
			end
		end
	end
	return not has_big and card:getNumber() > 10
end

sgs.ai_card_intention.YijueCard = 0
sgs.ai_use_value.YijueCard = 8.5

sgs.ai_choicemade_filter.skillChoice.yijue = function(self, player, promptlist)
	local choice = promptlist[#promptlist]
	local intention = (choice == "recover") and -30 or 30
	local target = nil
	for _, p in sgs.qlist(self.room:getOtherPlayers(player)) do
		if p:hasFlag("YijueTarget") then
			target = p
			break
		end
	end
	if not target then return end
	sgs.updateIntention(player, target, intention)
end

-- 咆哮
function sgs.ai_cardneed.paoxiao(to, card, self)
	local cards = to:getHandcards()
	local has_weapon = to:getWeapon() and not to:getWeapon():isKindOf("Crossbow")
	local slash_num = 0
	for _, c in sgs.qlist(cards) do
		local flag = string.format("%s_%s_%s", "visible", self.room:getCurrent():objectName(), to:objectName())
		if c:hasFlag("visible") or c:hasFlag(flag) then
			if c:isKindOf("Weapon") and not c:isKindOf("Crossbow") then
				has_weapon = true
			end
			if c:isKindOf("Slash") then slash_num = slash_num + 1 end
		end
	end
	if not has_weapon then
		return card:isKindOf("Weapon") and not card:isKindOf("Crossbow")
	else
		return to:hasWeapon("spear") or card:isKindOf("Slash") or (slash_num > 1 and card:isKindOf("Analeptic"))
	end
end

sgs.paoxiao_keep_value = {
	Peach = 6,
	Analeptic = 5.8,
	Jink = 5.7,
	FireSlash = 5.6,
	Slash = 5.4,
	ThunderSlash = 5.5,
	ExNihilo = 4.7
}

-- 替身
sgs.ai_skill_invoke.tishen = function(self, data)
	local x = data:toInt()
	return x >= 2 and not self:willSkipPlayPhase()
end

-- 观星
sgs.ai_skill_invoke.guanxing = function(self)
	return true
end
dofile "lua/ai/guanxing-ai.lua"

-- 龙胆
local longdan_skill = {}
longdan_skill.name = "longdan"
table.insert(sgs.ai_skills, longdan_skill)
longdan_skill.getTurnUseCard = function(self)
	local cards = self.player:getCards("h")
	for _, id in sgs.qlist(self.player:getPile("wooden_ox")) do
		cards:prepend(sgs.Sanguosha:getCard(id))
	end
	cards = sgs.QList2Table(cards)

	local jink_card

	self:sortByUseValue(cards, true)

	for _, card in ipairs(cards) do
		if card:isKindOf("Jink") then
			jink_card = card
			break
		end
	end

	if not jink_card then return nil end
	local suit = jink_card:getSuitString()
	local number = jink_card:getNumberString()
	local card_id = jink_card:getEffectiveId()
	local card_str = ("slash:longdan[%s:%s]=%d"):format(suit, number, card_id)
	local slash = sgs.Card_Parse(card_str)
	assert(slash)

	return slash
end

sgs.ai_view_as.longdan = function(card, player, card_place)
	local suit = card:getSuitString()
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	if card_place == sgs.Player_PlaceHand then
		if card:isKindOf("Jink") then
			return ("slash:longdan[%s:%s]=%d"):format(suit, number, card_id)
		elseif card:isKindOf("Slash") then
			return ("jink:longdan[%s:%s]=%d"):format(suit, number, card_id)
		end
	end
end

sgs.longdan_keep_value = {
	Peach = 6,
	Analeptic = 5.8,
	Jink = 5.7,
	FireSlash = 5.7,
	Slash = 5.6,
	ThunderSlash = 5.5,
	ExNihilo = 4.7
}

-- 涯角
sgs.ai_skill_invoke.yajiao = true

sgs.ai_skill_playerchosen.yajiao = function(self, targets)
	local id = self.player:getMark("yajiao")
	local card = sgs.Sanguosha:getCard(id)
	local cards = { card }
	local c, friend = self:getCardNeedPlayer(cards, self.friends)
	if friend then return friend end

	self:sort(self.friends)
	for _, friend in ipairs(self.friends) do
		if self:isValuableCard(card, friend) and not hasManjuanEffect(friend) and not self:needKongcheng(friend, true) then return friend end
	end
	for _, friend in ipairs(self.friends) do
		if self:isWeak(friend) and not hasManjuanEffect(friend) and not self:needKongcheng(friend, true) then return friend end
	end
	local trash = card:isKindOf("Disaster") or card:isKindOf("GodSalvation") or card:isKindOf("AmazingGrace")
	if trash then
		for _, enemy in ipairs(self.enemies) do
			if enemy:getPhase() > sgs.Player_Play and self:needKongcheng(enemy, true) and not hasManjuanEffect(enemy) then return enemy end
		end
	end
	for _, friend in ipairs(self.friends) do
		if not hasManjuanEffect(friend) and not self:needKongcheng(friend, true) then return friend end
	end
end

sgs.ai_playerchosen_intention.yajiao = function(self, from, to)
	if not self:needKongcheng(to, true) and not hasManjuanEffect(to) then sgs.updateIntention(from, to, -50) end
end

sgs.ai_skill_choice.yajiao = function(self, choices, data)
	local card = data:toCard()
	local valuable = self:isValuableCard(card)
	local current = self.room:getCurrent()
	if not current then return "throw" end -- avoid potential errors
	if current:isAlive() then
		local currentMayObtain = getKnownCard(current, self.player, "ExNihilo") + getKnownCard(current, self.player, "IronChain") > 0
		if currentMayObtain then
			local valuable = self:isValuableCard(card, current)
			return (self:isFriend(current) == valuable) and "cancel" or "throw"
		end
	end

	local hasLightning, hasIndulgence, hasSupplyShortage
	local nextAlive = current:getNextAlive()
	local tricks = nextAlive:getJudgingArea()
	if not tricks:isEmpty() and not nextAlive:containsTrick("YanxiaoCard") and not nextAlive:hasSkill("qianxi") then
		local trick = tricks:at(tricks:length() - 1)
		if self:hasTrickEffective(trick, nextAlive) then
			if trick:isKindOf("Lightning") then hasLightning = true
			elseif trick:isKindOf("Indulgence") then hasIndulgence = true
			elseif trick:isKindOf("SupplyShortage") then hasSupplyShortage = true
			end
		end
	end

	if nextAlive:hasSkill("luoshen") then
		local valid = card:isRed()
		return (self:isFriend(nextAlive) == valid) and "throw" or "cancel"
	end
	if nextAlive:hasSkill("yinghun") and nextAlive:isWounded() then
		return self:isFriend(nextAlive) and "cancel" or "throw"
	end
	if hasLightning then
		local valid = (card:getSuit() == sgs.Card_Spade and card:getNumber() >= 2 and card:getNumber() <= 9)
		return (self:isFriend(nextAlive) == valid) and "throw" or "cancel"
	end
	if hasIndulgence then
		local valid = (card:getSuit() ~= sgs.Card_Heart)
		return (self:isFriend(nextAlive) == valid) and "throw" or "cancel"
	end
	if hasSupplyShortage then
		local valid = (card:getSuit() ~= sgs.Card_Club)
		return (self:isFriend(nextAlive) == valid) and "throw" or "cancel"
	end

	if self:isFriend(nextAlive) and not self:willSkipDrawPhase(nextAlive) and not self:willSkipPlayPhase(nextAlive)
		and not nextAlive:hasSkill("luoshen")
		and not nextAlive:hasSkills("tuxi|nostuxi") and not (nextAlive:hasSkill("qiaobian") and nextAlive:getHandcardNum() > 0) then
		if self:isValuableCard(card, nextAlive) then
			return "cancel"
		end
		if card:isKindOf("Jink") and getCardsNum("Jink", nextAlive, self.player) < 1 then
			return "cancel"
		end
		if card:isKindOf("Nullification") and getCardsNum("Nullification", nextAlive, self.player) < 1 then
			return "cancel"
		end
		if card:isKindOf("Slash") and self:hasCrossbowEffect(nextAlive) then
			return "cancel"
		end
		for _, skill in ipairs(sgs.getPlayerSkillList(nextAlive)) do
			if sgs.ai_cardneed[skill:objectName()] and sgs.ai_cardneed[skill:objectName()](nextAlive, card) then return "cancel" end
		end
	end

	local trash = card:isKindOf("Disaster") or card:isKindOf("AmazingGrace") or card:isKindOf("GodSalvation")
	if trash and self:isEnemy(nextAlive) then return "cancel" end
	return "throw"
end

-- 铁骑
-- @todo: TieJi AI
sgs.ai_skill_invoke.tieji = function(self, data)
	local target = data:toPlayer()
	return not self:isFriend(target)
end

sgs.ai_skill_cardask["@tieji-discard"] = function(self, data, pattern)
	local suit = pattern:split("|")[2]
	local use = data:toCardUse()
	if self:needToThrowArmor() and self.player:getArmor():getSuitString() == suit then return "$" .. self.player:getArmor():getEffectiveId() end
	if not self:slashIsEffective(use.card, self.player, use.from)
		or (not self:hasHeavySlashDamage(use.from, use.card, self.player)
			and (self:getDamagedEffects(self.player, use.from, true) or self:needToLoseHp(self.player, use.from, true))) then return "." end
	if not self:hasHeavySlashDamage(use.from, use.card, self.player) and self:getCardsNum("Peach") > 0 then return "." end
	if self:getCardsNum("Jink") == 0 or not sgs.isJinkAvailable(use.from, self.player, use.card, true) then return "." end

	local equip_index = { 3, 0, 2, 4, 1 }
	if self.player:hasSkills(sgs.lose_equip_skill) then
		for _, i in ipairs(equip_index) do
			if i == 4 then break end
			if self.player:getEquip(i) and self.player:getEquip(i):getSuitString() == suit then return "$" .. self.player:getEquip(i):getEffectiveId() end
		end
	end

	local jiangqin = self.room:findPlayerBySkillName("niaoxiang")
	local need_double_jink = use.from:hasSkill("wushuang")
							or (use.from:hasSkill("roulin") and self.player:isFemale())
							or (self.player:hasSkill("roulin") and use.from:isFemale())
							or (jiangqin and jiangqin:isAdjacentTo(self.player) and use.from:isAdjacentTo(self.player) and self:isEnemy(jiangqin))

	local cards = sgs.QList2Table(self.player:getHandcards())
	self:sortByKeepValue(cards)
	for _, card in ipairs(cards) do
		if card:getSuitString() ~= suit or (not self:isWeak() and (self:getKeepValue(card) > 8 or self:isValuableCard(card)))
			or (isCard("Jink", card, self.player) and self:getCardsNum("Jink") - 1 < (need_double_jink and 2 or 1)) then continue end
		return "$" .. card:getEffectiveId()
	end

	for _, i in ipairs(equip_index) do
		if self.player:getEquip(i) and self.player:getEquip(i):getSuitString() == suit then
			if not (i == 1 and self:evaluateArmor() > 3)
				and not (i == 4 and self.player:getTreasure():isKindOf("WoodenOx") and self.player:getPile("wooden_ox"):length() >= 3) then
				return "$" .. self.player:getEquip(i):getEffectiveId()
			end
		end
	end
end

sgs.ai_choicemade_filter.skillInvoke.tieji = function(self, player, promptlist)
	if promptlist[#promptlist] == "yes" then
		local target = findPlayerByObjectName(self.room, promptlist[#promptlist - 1])
		if target then sgs.updateIntention(player, target, 50) end
	end
end

-- 集智
function SmartAI:isValuableCard(card, player)
	player = player or self.player
	if (isCard("Peach", card, player) and getCardsNum("Peach", player, self.player) <= 2)
		or (self:isWeak(player) and isCard("Analeptic", card, player))
		or (player:getPhase() ~= sgs.Player_Play
			and ((isCard("Nullification", card, player) and getCardsNum("Nullification", player, self.player) < 2 and player:hasSkills("jizhi|nosjizhi|jilve"))
				or (isCard("Jink", card, player) and getCardsNum("Jink", player, self.player) < 2)))
		or (player:getPhase() == sgs.Player_Play and isCard("ExNihilo", card, player) and not player:isLocked(card)) then
		return true
	end
	local dangerous = self:getDangerousCard(player)
	if dangerous and card:getEffectiveId() == dangerous then return true end
	local valuable = self:getValuableCard(player)
	if valuable and card:getEffectiveId() == valuable then return true end
end

sgs.ai_skill_invoke.jizhi = function(self, data)
	return not self:needKongcheng(self.player, true)
end


sgs.ai_skill_cardask["@jizhi-exchange"] = function(self, data)
	local card = data:toCard()
	local handcards = sgs.QList2Table(self.player:getHandcards())
	if self.player:getPhase() ~= sgs.Player_Play then
		if hasManjuanEffect(self.player) then return "." end
		self:sortByKeepValue(handcards)
		for _, card_ex in ipairs(handcards) do
			if self:getKeepValue(card_ex) < self:getKeepValue(card) and not self:isValuableCard(card_ex) then
				return "$" .. card_ex:getEffectiveId()
			end
		end
	else
		if card:isKindOf("Slash") and not self:slashIsAvailable() then return "." end
		self:sortByUseValue(handcards)
		for _, card_ex in ipairs(handcards) do
			if self:getUseValue(card_ex) < self:getUseValue(card) and not self:isValuableCard(card_ex) then
				return "$" .. card_ex:getEffectiveId()
			end
		end
	end
	return "."
end

function sgs.ai_cardneed.jizhi(to, card)
	return card:getTypeId() == sgs.Card_TypeTrick
end

sgs.jizhi_keep_value = {
	Peach = 6,
	Analeptic = 5.9,
	Jink = 5.8,
	ExNihilo = 5.7,
	Snatch = 5.7,
	Dismantlement = 5.6,
	IronChain = 5.5,
	SavageAssault = 5.4,
	Duel = 5.3,
	ArcheryAttack = 5.2,
	AmazingGrace = 5.1,
	Collateral = 5,
	FireAttack = 4.9
}

-- 诛害
sgs.ai_skill_cardask["@zhuhai-slash"] = function(self, data, pattern, target, target2)
	for _, slash in ipairs(self:getCards("Slash")) do
		if self:isFriend(target2) and self:slashIsEffective(slash, target2) then
			if self:findLeijiTarget(target2, 50, self.player) then return slash:toString() end
			if self:getDamagedEffects(target2, self.player, true) then return slash:toString() end
		end

		local nature = sgs.DamageStruct_Normal
		if slash:isKindOf("FireSlash") then nature = sgs.DamageStruct_Fire
		elseif slash:isKindOf("ThunderSlash") then nature = sgs.DamageStruct_Thunder end
		if self:isEnemy(target2) and self:slashIsEffective(slash, target2) and self:canAttack(target2, self.player, nature)
			and not self:getDamagedEffects(target2, self.player, true) and not self:findLeijiTarget(target2, 50, self.player) then
			return slash:toString()
		end
	end
	return "."
end

-- 荐言
local jianyan_skill = {}
jianyan_skill.name = "jianyan"
table.insert(sgs.ai_skills, jianyan_skill)
jianyan_skill.getTurnUseCard = function(self)
	if not self.player:hasUsed("JianyanCard") then return sgs.Card_Parse("@JianyanCard=.") end
end

sgs.ai_skill_use_func.JianyanCard = function(card, use, self)
	self.jianyan_choice = nil
	self.jianyan_enemy = nil
	sgs.ai_use_priority.JianyanCard = 9.5
	self:sort(self.friends)
	local use_card
	for _, friend in ipairs(self.friends) do
		if friend:isMale() and not hasManjuanEffect(friend) and not self:needKongcheng(friend, true) then
			if self:isWeak(friend) then self.jianyan_choice = "basic" end
			use_card = true
		end
	end
	if use_card then
		use.card = card
		return
	end

	sgs.ai_use_priority.JianyanCard = 0.5
	for _, enemy in ipairs(self.enemies) do
		if enemy:isMale() and not hasManjuanEffect(enemy) and self:needKongcheng(enemy, true) then
			self.jianyan_choice = "equip"
			self.jianyan_enemy = enemy
			use.card = card
			return
		end
	end
end

sgs.ai_use_priority.JianyanCard = 9.5

sgs.ai_skill_choice.jianyan = function(self, choices)
	if self.jianyan_choice then return self.jianyan_choice end
	for _, friend in ipairs(self.friends) do
		if friend:isMale() and not hasManjuanEffect(friend) and not self:needKongcheng(friend, true) then
			if friend:getHandcardNum() < 3 and friend:getEquips():length() < 2 then return "equip" end
		end
	end
	for _, friend in ipairs(self.friends) do
		if friend:isMale() and not hasManjuanEffect(friend) and not self:needKongcheng(friend, true) then
			if friend:hasSkills("jizhi|nosjizhi|jilve") then return "trick" end
		end
	end
	local rand = math.random(0, 100)
	if rand > 60 then return "trick"
	elseif rand > 35 then return "red"
	elseif rand > 10 then return "equip"
	elseif rand > 2 then return "basic"
	else return "black"
	end
end

sgs.ai_skill_playerchosen.jianyan = function(self, targets)
	if self.jianyan_enemy then return self.jianyan_enemy end

	local id = self.player:getMark("jianyan")
	local card = sgs.Sanguosha:getCard(id)
	local cards = { card }
	local c, friend = self:getCardNeedPlayer(cards, self.friends)
	if friend then return friend end

	self:sort(self.friends)
	for _, friend in ipairs(self.friends) do
		if friend:isMale() and self:isValuableCard(card, friend) and not hasManjuanEffect(friend) and not self:needKongcheng(friend, true) then return friend end
	end
	for _, friend in ipairs(self.friends) do
		if friend:isMale() and self:isWeak(friend) and not hasManjuanEffect(friend) and not self:needKongcheng(friend, true) then return friend end
	end
	local trash = card:isKindOf("EquipCard") or card:isKindOf("Disaster") or card:isKindOf("GodSalvation") or card:isKindOf("AmazingGrace") or card:isKindOf("Slash")
	if trash then
		for _, enemy in ipairs(self.enemies) do
			if enemy:isMale() and enemy:getPhase() > sgs.Player_Play and self:needKongcheng(enemy, true) and not hasManjuanEffect(enemy) then return enemy end
		end
	end
	for _, friend in ipairs(self.friends) do
		if friend:isMale() and not hasManjuanEffect(friend) and not self:needKongcheng(friend, true) then return friend end
	end
end

-- 制衡
local zhiheng_skill = {}
zhiheng_skill.name = "zhiheng"
table.insert(sgs.ai_skills, zhiheng_skill)
zhiheng_skill.getTurnUseCard = function(self)
	if not self.player:hasUsed("ZhihengCard") then
		return sgs.Card_Parse("@ZhihengCard=.")
	end
end

sgs.ai_skill_use_func.ZhihengCard = function(card, use, self)
	local unpreferedCards = {}
	local cards = sgs.QList2Table(self.player:getHandcards())

	if self.player:getHp() < 3 then
		local zcards = self.player:getCards("he")
		local use_slash, keep_jink, keep_analeptic, keep_weapon = false, false, false
		for _, zcard in sgs.qlist(zcards) do
			if not isCard("Peach", zcard, self.player) and not isCard("ExNihilo", zcard, self.player) then
				local shouldUse = true
				if isCard("Slash", zcard, self.player) and not use_slash then
					local dummy_use = { isDummy = true, to = sgs.SPlayerList() }
					self:useBasicCard(zcard, dummy_use)
					if dummy_use.card then
						if keep_slash then shouldUse = false end
						if dummy_use.to then
							for _, p in sgs.qlist(dummy_use.to) do
								if p:getHp() <= 1 then
									shouldUse = false
									if self.player:distanceTo(p) > 1 then keep_weapon = self.player:getWeapon() end
									break
								end
							end
							if dummy_use.to:length() > 1 then shouldUse = false end
						end
						if not self:isWeak() then shouldUse = false end
						if not shouldUse then use_slash = true end
					end
				end
				if zcard:getTypeId() == sgs.Card_TypeTrick then
					local dummy_use = { isDummy = true }
					self:useTrickCard(zcard, dummy_use)
					if dummy_use.card then shouldUse = false end
				end
				if zcard:getTypeId() == sgs.Card_TypeEquip and not self.player:hasEquip(zcard) then
					local dummy_use = { isDummy = true }
					self:useEquipCard(zcard, dummy_use)
					if dummy_use.card then shouldUse = false end
					if keep_weapon and zcard:getEffectiveId() == keep_weapon:getEffectiveId() then shouldUse = false end
				end
				if self.player:hasEquip(zcard) and zcard:isKindOf("Armor") and not self:needToThrowArmor() then shouldUse = false end
				if self.player:hasTreasure(zcard:objectName()) then shouldUse = false end
				if isCard("Jink", zcard, self.player) and not keep_jink then
					keep_jink = true
					shouldUse = false
				end
				if self.player:getHp() == 1 and isCard("Analeptic", zcard, self.player) and not keep_analeptic then
					keep_analeptic = true
					shouldUse = false
				end
				if shouldUse then table.insert(unpreferedCards, zcard:getId()) end
			end
		end
	end

	if #unpreferedCards == 0 then
		local use_slash_num = 0
		self:sortByKeepValue(cards)
		for _, card in ipairs(cards) do
			if card:isKindOf("Slash") then
				local will_use = false
				if use_slash_num <= sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_Residue, self.player, card) then
					local dummy_use = { isDummy = true }
					self:useBasicCard(card, dummy_use)
					if dummy_use.card then
						will_use = true
						use_slash_num = use_slash_num + 1
					end
				end
				if not will_use then table.insert(unpreferedCards, card:getId()) end
			end
		end

		local num = self:getCardsNum("Jink") - 1
		if self.player:getArmor() then num = num + 1 end
		if num > 0 then
			for _, card in ipairs(cards) do
				if card:isKindOf("Jink") and num > 0 then
					table.insert(unpreferedCards, card:getId())
					num = num - 1
				end
			end
		end
		for _, card in ipairs(cards) do
			if (card:isKindOf("Weapon") and self.player:getHandcardNum() < 3) or card:isKindOf("OffensiveHorse")
				or self:getSameEquip(card, self.player) or card:isKindOf("Lightning") then
				table.insert(unpreferedCards, card:getId())
			end
		end

		if self.player:getWeapon() and self.player:getHandcardNum() < 3 then
			table.insert(unpreferedCards, self.player:getWeapon():getId())
		end

		if self:needToThrowArmor() then
			table.insert(unpreferedCards, self.player:getArmor():getId())
		end

		if self.player:getOffensiveHorse() and self.player:getWeapon() then
			table.insert(unpreferedCards, self.player:getOffensiveHorse():getId())
		end

		for _, card in ipairs(cards) do
			if card:isNDTrick() then
				local dummy_use = { isDummy = true }
				self:useTrickCard(card, dummy_use)
				if not dummy_use.card then table.insert(unpreferedCards, card:getId()) end
			end
		end
	end

	local use_cards = {}
	for index = #unpreferedCards, 1, -1 do
		if not self.player:isJilei(sgs.Sanguosha:getCard(unpreferedCards[index])) then table.insert(use_cards, unpreferedCards[index]) end
	end

	if #use_cards > 0 then
		if self.room:getMode() == "02_1v1" and sgs.GetConfig("1v1/Rule", "Classical") ~= "Classical" then
			local use_cards_kof = { use_cards[1] }
			if #use_cards > 1 then table.insert(use_cards_kof, use_cards[2]) end
			use.card = sgs.Card_Parse("@ZhihengCard=" .. table.concat(use_cards_kof, "+"))
			return
		else
			use.card = sgs.Card_Parse("@ZhihengCard=" .. table.concat(use_cards, "+"))
			return
		end
	end
end

sgs.ai_use_value.ZhihengCard = 9
sgs.ai_use_priority.ZhihengCard = 2.61
sgs.dynamic_value.benefit.ZhihengCard = true

function sgs.ai_cardneed.zhiheng(to, card)
	return not card:isKindOf("Jink")
end

-- 奇袭
local qixi_skill = {}
qixi_skill.name = "qixi"
table.insert(sgs.ai_skills, qixi_skill)
qixi_skill.getTurnUseCard = function(self, inclusive)
	local cards = self.player:getCards("he")
	for _, id in sgs.qlist(self.player:getPile("wooden_ox")) do
		cards:prepend(sgs.Sanguosha:getCard(id))
	end
	cards = sgs.QList2Table(cards)

	local black_card
	self:sortByUseValue(cards, true)
	local has_weapon = false

	for _, card in ipairs(cards) do
		if card:isKindOf("Weapon") and card:isBlack() then has_weapon = true end
	end

	for _, card in ipairs(cards) do
		if card:isBlack() and ((self:getUseValue(card) < sgs.ai_use_value.Dismantlement) or inclusive or self:getOverflow() > 0) then
			local shouldUse = true
			if card:isKindOf("Armor") then
				if not self.player:getArmor() then shouldUse = false
				elseif self.player:hasEquip(card) and not self:needToThrowArmor() then shouldUse = false
				end
			end

			if card:isKindOf("Weapon") then
				if not self.player:getWeapon() then shouldUse = false
				elseif self.player:hasEquip(card) and not has_weapon then shouldUse = false
				end
			end

			if card:isKindOf("Slash") then
				local dummy_use = { isDummy = true }
				if self:getCardsNum("Slash") == 1 then
					self:useBasicCard(card, dummy_use)
					if dummy_use.card then shouldUse = false end
				end
			end

			if self:getUseValue(card) > sgs.ai_use_value.Dismantlement and card:isKindOf("TrickCard") then
				local dummy_use = { isDummy = true }
				self:useTrickCard(card, dummy_use)
				if dummy_use.card then shouldUse = false end
			end

			if shouldUse then
				black_card = card
				break
			end

		end
	end

	if black_card then
		local suit = black_card:getSuitString()
		local number = black_card:getNumberString()
		local card_id = black_card:getEffectiveId()
		local card_str = ("dismantlement:qixi[%s:%s]=%d"):format(suit, number, card_id)
		local dismantlement = sgs.Card_Parse(card_str)

		assert(dismantlement)

		return dismantlement
	end
end

sgs.qixi_suit_value = {
	spade = 3.9,
	club = 3.9
}

function sgs.ai_cardneed.qixi(to, card)
	return card:isBlack()
end

-- 奋威
local function getFenweiValue(self, who, card, from)
	if not self:hasTrickEffective(card, who, from) then return 0 end
	if card:isKindOf("AOE") then
		if not self:isFriend(who) then return 0 end
		local value = self:getAoeValueTo(card, who, from)
		if value < 0 then return -value / 30 end
	elseif card:isKindOf("GodSalvation") then
		if not self:isEnemy(who) or not who:isWounded() or who:getHp() >= getBestHp(who) then return 0 end
		if self:isWeak(who) then return 1.2 end
		if who:hasSkills(sgs.masochism_skill) then return 1.0 end
		return 0.9
	elseif card:isKindOf("AmazingGrace") then
		if not self:isEnemy(who) or hasManjuanEffect(who) then return 0 end
		local v = 1.2
		local p = self.room:getCurrent()
		while p:objectName() ~= who:objectName() do
			v = v * 0.9
			p = p:getNextAlive()
		end
		return v
	end
	return 0
end

sgs.ai_skill_use["@@fenwei"] = function(self, prompt)
	local liuxie = self.room:findPlayerBySkillName("huangen")
	if liuxie and self:isFriend(liuxie) and not self:isWeak(liuxie) then return "." end

	local card = self.player:getTag("fenwei"):toCardUse().card
	local from = self.player:getTag("fenwei"):toCardUse().from

	local players = sgs.QList2Table(self.room:getAllPlayers())
	self:sort(players, "defense")
	local target_table = {}
	local targetslist = self.player:property("fenwei_targets"):toString():split("+")
	local value = 0
	for _, player in ipairs(players) do
		if not player:hasSkill("danlao") and table.contains(targetslist, player:objectName()) then
			local val = getFenweiValue(self, player, card, from)
			if val > 0 then
				value = value + val
				table.insert(target_table, player:objectName())
			end
		end
	end
	if #target_table == 0 or value / (self.room:alivePlayerCount() - 1) < 0.55 then return "." end
	return "@FenweiCard=.->" .. table.concat(target_table, "+")
end

sgs.ai_card_intention.FenweiCard = function(self, card, from, tos)
	local cardx = self.player:getTag("fenwei"):toCardUse().card
	local from = self.player:getTag("fenwei"):toCardUse().from
	if not cardx then return end
	local intention = (cardx:isKindOf("AOE") and -50 or 50)
	for _, to in ipairs(tos) do
		if to:hasSkill("danlao") or not self:hasTrickEffective(cardx, to, from) then continue end
		if cardx:isKindOf("GodSalvation") and not to:isWounded() then continue end
		sgs.updateIntention(from, to, intention)
	end
end

-- 克己
sgs.ai_skill_invoke.keji = function(self)
	return true
end

-- 攻心
local gongxin_skill={}
gongxin_skill.name="gongxin"
table.insert(sgs.ai_skills,gongxin_skill)
gongxin_skill.getTurnUseCard=function(self)
	if self.player:hasUsed("GongxinCard") then return end
	local gongxin_card = sgs.Card_Parse("@GongxinCard=.")
	assert(gongxin_card)
	return gongxin_card
end

sgs.ai_skill_use_func.GongxinCard=function(card,use,self)
	self:sort(self.enemies, "handcard")
	self.enemies = sgs.reverse(self.enemies)

	for _, enemy in ipairs(self.enemies) do
		if not enemy:isKongcheng() and self:objectiveLevel(enemy) > 0
			and (self:hasSuit("heart", false, enemy) or self:getKnownNum(eneny) ~= enemy:getHandcardNum()) then
			use.card = card
			if use.to then
				use.to:append(enemy)
			end
			return
		end
	end
end

sgs.ai_skill_askforag.gongxin = function(self, card_ids)
	self.gongxinchoice = nil
	local target = self.player:getTag("gongxin"):toPlayer()
	if not target or self:isFriend(target) then return -1 end
	local nextAlive = self.player
	repeat
		nextAlive = nextAlive:getNextAlive()
	until nextAlive:faceUp()

	local peach, ex_nihilo, jink, nullification, slash
	local valuable
	for _, id in ipairs(card_ids) do
		local card = sgs.Sanguosha:getCard(id)
		if card:isKindOf("Peach") then peach = id end
		if card:isKindOf("ExNihilo") then ex_nihilo = id end
		if card:isKindOf("Jink") then jink = id end
		if card:isKindOf("Nullification") then nullification = id end
		if card:isKindOf("Slash") then slash = id end
	end
	valuable = peach or ex_nihilo or jink or nullification or slash or card_ids[1]
	local card = sgs.Sanguosha:getCard(valuable)
	if self:isEnemy(target) and target:hasSkill("tuntian") then
		local zhangjiao = self.room:findPlayerBySkillName("guidao")
		if zhangjiao and self:isFriend(zhangjiao, target) and self:canRetrial(zhangjiao, target) and self:isValuableCard(card, zhangjiao) then
			self.gongxinchoice = "discard"
		else
			self.gongxinchoice = "put"
		end
		return valuable
	end

	local willUseExNihilo, willRecast
	if self:getCardsNum("ExNihilo") > 0 then
		local ex_nihilo = self:getCard("ExNihilo")
		if ex_nihilo then
			local dummy_use = { isDummy = true }
			self:useTrickCard(ex_nihilo, dummy_use)
			if dummy_use.card then willUseExNihilo = true end
		end
	elseif self:getCardsNum("IronChain") > 0 then
		local iron_chain = self:getCard("IronChain")
		if iron_chain then
			local dummy_use = { to = sgs.SPlayerList(), isDummy = true }
			self:useTrickCard(iron_chain, dummy_use)
			if dummy_use.card and dummy_use.to:isEmpty() then willRecast = true end
		end
	end
	if willUseExNihilo or willRecast then
		local card = sgs.Sanguosha:getCard(valuable)
		if card:isKindOf("Peach") then
			self.gongxinchoice = "put"
			return valuable
		end
		if card:isKindOf("TrickCard") or card:isKindOf("Indulgence") or card:isKindOf("SupplyShortage") then
			local dummy_use = { isDummy = true }
			self:useTrickCard(card, dummy_use)
			if dummy_use.card then
				self.gongxinchoice = "put"
				return valuable
			end
		end
		if card:isKindOf("Jink") and self:getCardsNum("Jink") == 0 then
			self.gongxinchoice = "put"
			return valuable
		end
		if card:isKindOf("Nullification") and self:getCardsNum("Nullification") == 0 then
			self.gongxinchoice = "put"
			return valuable
		end
		if card:isKindOf("Slash") and self:slashIsAvailable() then
			local dummy_use = { isDummy = true }
			self:useBasicCard(card, dummy_use)
			if dummy_use.card then
				self.gongxinchoice = "put"
				return valuable
			end
		end
		self.gongxinchoice = "discard"
		return valuable
	end

	local hasLightning, hasIndulgence, hasSupplyShortage
	local tricks = nextAlive:getJudgingArea()
	if not tricks:isEmpty() and not nextAlive:containsTrick("YanxiaoCard") then
		local trick = tricks:at(tricks:length() - 1)
		if self:hasTrickEffective(trick, nextAlive) then
			if trick:isKindOf("Lightning") then hasLightning = true
			elseif trick:isKindOf("Indulgence") then hasIndulgence = true
			elseif trick:isKindOf("SupplyShortage") then hasSupplyShortage = true
			end
		end
	end

	if self:isEnemy(nextAlive) and nextAlive:hasSkill("luoshen") and valuable then
		self.gongxinchoice = "put"
		return valuable
	end
	if nextAlive:hasSkill("yinghun") and nextAlive:isWounded() then
		self.gongxinchoice = self:isFriend(nextAlive) and "put" or "discard"
		return valuable
	end
	if target:hasSkill("hongyan") and hasLightning and self:isEnemy(nextAlive) and not (nextAlive:hasSkill("qiaobian") and nextAlive:getHandcardNum() > 0) then
		for _, id in ipairs(card_ids) do
			local card = sgs.Sanguosha:getEngineCard(id)
			if card:getSuit() == sgs.Card_Spade and card:getNumber() >= 2 and card:getNumber() <= 9 then
				self.gongxinchoice = "put"
				return id
			end
		end
	end
	if hasIndulgence and self:isFriend(nextAlive) then
		self.gongxinchoice = "put"
		return valuable
	end
	if hasSupplyShortage and self:isEnemy(nextAlive) and not (nextAlive:hasSkill("qiaobian") and nextAlive:getHandcardNum() > 0) then
		local enemy_null = 0
		for _, p in sgs.qlist(self.room:getOtherPlayers(self.player)) do
			if self:isFriend(p) then enemy_null = enemy_null - getCardsNum("Nullification", p) end
			if self:isEnemy(p) then enemy_null = enemy_null + getCardsNum("Nullification", p) end
		end
		enemy_null = enemy_null - self:getCardsNum("Nullification")
		if enemy_null < 0.8 then
			self.gongxinchoice = "put"
			return valuable
		end
	end

	if self:isFriend(nextAlive) and not self:willSkipDrawPhase(nextAlive) and not self:willSkipPlayPhase(nextAlive)
		and not nextAlive:hasSkill("luoshen")
		and not nextAlive:hasSkill("tuxi") and not (nextAlive:hasSkill("qiaobian") and nextAlive:getHandcardNum() > 0) then
		if (peach and valuable == peach) or (ex_nihilo and valuable == ex_nihilo) then
			self.gongxinchoice = "put"
			return valuable
		end
		if jink and valuable == jink and getCardsNum("Jink", nextAlive) < 1 then
			self.gongxinchoice = "put"
			return valuable
		end
		if nullification and valuable == nullification and getCardsNum("Nullification", nextAlive) < 1 then
			self.gongxinchoice = "put"
			return valuable
		end
		if slash and valuable == slash and self:hasCrossbowEffect(nextAlive) then
			self.gongxinchoice = "put"
			return valuable
		end
	end

	local card = sgs.Sanguosha:getCard(valuable)
	local keep = false
	if card:isKindOf("Slash") or card:isKindOf("Jink")
		or card:isKindOf("EquipCard")
		or card:isKindOf("Disaster") or card:isKindOf("GlobalEffect") or card:isKindOf("Nullification")
		or target:isLocked(card) then
		keep = true
	end
	self.gongxinchoice = (target:objectName() == nextAlive:objectName() and keep) and "put" or "discard"
	return valuable
end

sgs.ai_skill_choice.gongxin = function(self, choices)
	return self.gongxinchoice or "discard"
end

sgs.ai_use_value.GongxinCard = 8.5
sgs.ai_use_priority.GongxinCard = 9.5
sgs.ai_card_intention.GongxinCard = 80

-- 苦肉
local function getKurouCard(self, not_slash)
	local card_id
	local hold_crossbow = (self:getCardsNum("Slash") > 1)
	local cards = self.player:getHandcards()
	cards = sgs.QList2Table(cards)
	self:sortByKeepValue(cards)
	local lightning = self:getCard("Lightning")

	if self:needToThrowArmor() then
		card_id = self.player:getArmor():getId()
	elseif self.player:getHandcardNum() > self.player:getHp() then
		if lightning and not self:willUseLightning(lightning) then
			card_id = lightning:getEffectiveId()
		else
			for _, acard in ipairs(cards) do
				if (acard:isKindOf("BasicCard") or acard:isKindOf("EquipCard") or acard:isKindOf("AmazingGrace"))
					and not self:isValuableCard(acard) and not (acard:isKindOf("Crossbow") and hold_crossbow)
					and not (acard:isKindOf("Slash") and not_slash) then
					card_id = acard:getEffectiveId()
					break
				end
			end
		end
	elseif not self.player:getEquips():isEmpty() then
		local player = self.player
		if player:getOffensiveHorse() then card_id = player:getOffensiveHorse():getId()
		elseif player:getWeapon() and self:evaluateWeapon(self.player:getWeapon()) < 3
				and not (player:getWeapon():isKindOf("Crossbow") and hold_crossbow) then card_id = player:getWeapon():getId()
		elseif player:getArmor() and self:evaluateArmor(self.player:getArmor()) < 2 then card_id = player:getArmor():getId()
		end
	end
	if not card_id then
		if lightning and not self:willUseLightning(lightning) then
			card_id = lightning:getEffectiveId()
		else
			for _, acard in ipairs(cards) do
				if (acard:isKindOf("BasicCard") or acard:isKindOf("EquipCard") or acard:isKindOf("AmazingGrace"))
					and not self:isValuableCard(acard) and not (acard:isKindOf("Crossbow") and hold_crossbow)
					and not (acard:isKindOf("Slash") and not_slash) then
					card_id = acard:getEffectiveId()
					break
				end
			end
		end
	end
	return card_id
end

local kurou_skill = {}
kurou_skill.name = "kurou"
table.insert(sgs.ai_skills, kurou_skill)
kurou_skill.getTurnUseCard = function(self, inclusive)
	if self.player:hasUsed("KurouCard") or not self.player:canDiscard(self.player, "he") or not self.player:hasSkill("zhaxiang")
		or (self.player:getHp() == 2 and self.player:hasSkill("chanyuan")) then return end
	if (self.player:getHp() > 3 and self.player:getHandcardNum() > self.player:getHp())
		or (self.player:getHp() - self.player:getHandcardNum() >= 2) then
		local id = getKurouCard(self)
		if id then return sgs.Card_Parse("@KurouCard=" .. id) end
	end

	local function can_kurou_with_cb(self)
		if self.player:getHp() > 1 then return true end
		local has_save = false
		local huatuo = self.room:findPlayerBySkillName("jijiu")
		if huatuo and self:isFriend(huatuo) then
			for _, equip in sgs.qlist(huatuo:getEquips()) do
				if equip:isRed() then has_save = true break end
			end
			if not has_save then has_save = (huatuo:getHandcardNum() > 3) end
		end
		if has_save then return true end
		local handang = self.room:findPlayerBySkillName("nosjiefan")
		if handang and self:isFriend(handang) and getCardsNum("Slash", handang, self.player) >= 1 then return true end
		return false
	end

	local slash = sgs.cloneCard("slash")
	if (self.player:hasWeapon("crossbow") or self:getCardsNum("Crossbow") > 0) or self:getCardsNum("Slash") > 1 then
		for _, enemy in ipairs(self.enemies) do
			if self.player:canSlash(enemy) and self:slashIsEffective(slash, enemy)
				and sgs.isGoodTarget(enemy, self.enemies, self, true) and not self:slashProhibit(slash, enemy) and can_kurou_with_cb(self) then
				local id = getKurouCard(self, true)
				if id then return sgs.Card_Parse("@KurouCard=" .. id) end
			end
		end
	end

	if self.player:getHp() <= 1 and self:getCardsNum("Analeptic") + self:getCardsNum("Peach") > 1 then
		local id = getKurouCard(self)
		if id then return sgs.Card_Parse("@KurouCard=.") end
 	end
end

sgs.ai_skill_use_func.KurouCard = function(card, use, self)
	use.card = card
end

sgs.ai_use_priority.KurouCard = 6.8

-- 反间
local fanjian_skill = {}
fanjian_skill.name = "fanjian"
table.insert(sgs.ai_skills, fanjian_skill)
fanjian_skill.getTurnUseCard = function(self)
	if self.player:isKongcheng() or self.player:hasUsed("FanjianCard") then return nil end
	return sgs.Card_Parse("@FanjianCard=.")
end

sgs.ai_skill_use_func.FanjianCard = function(card, use, self)
	local cards = sgs.QList2Table(self.player:getHandcards())
	self:sortByUseValue(cards, true)
	self:sort(self.enemies, "defense")

	if self:getCardsNum("Slash") > 0 then
		local slash = self:getCard("Slash")
		local dummy_use = { isDummy = true, to = sgs.SPlayerList() }
		self:useCardSlash(slash, dummy_use)
		if dummy_use.card and dummy_use.to:length() > 0 then
			sgs.ai_use_priority.FanjianCard = sgs.ai_use_priority.Slash + 0.15
			local target = dummy_use.to:first()
			if self:isEnemy(target) and sgs.card_lack[target:objectName()]["Jink"] ~= 1 and target:getMark("yijue") == 0
				and not target:isKongcheng() and (self:getOverflow() > 0 or target:getHandcardNum() > 2)
				and not (self.player:hasSkill("liegong") and (target:getHandcardNum() >= self.player:getHp() or target:getHandcardNum() <= self.player:getAttackRange()))
				and not (self.player:hasSkill("kofliegong") and target:getHandcardNum() >= self.player:getHp()) then
				if target:hasSkill("qingguo") then
					for _, card in ipairs(cards) do
						if self:getUseValue(card) < 6 and card:isBlack() then
							use.card = sgs.Card_Parse("@FanjianCard=" .. card:getEffectiveId())
							if use.to then use.to:append(target) end
							return
						end
					end
				end
				for _, card in ipairs(cards) do
					if self:getUseValue(card) < 6 and card:getSuit() == sgs.Card_Diamond then
						use.card = sgs.Card_Parse("@FanjianCard=" .. card:getEffectiveId())
						if use.to then use.to:append(target) end
						return
					end
				end
			end
		end
	end

	if self:getOverflow() <= 0 then return end
	sgs.ai_use_priority.FanjianCard = 0.2
	local suit_table = { "spade", "club", "heart", "diamond" }
	local equip_val_table = { 1.2, 1.5, 0.5, 1, 1.3 }
	for _, enemy in ipairs(self.enemies) do
		if enemy:getHandcardNum() > 2 then
			local max_suit_num, max_suit = 0, {}
			for i = 0, 3, 1 do
				local suit_num = getKnownCard(enemy, self.player, suit_table[i + 1])
				for j = 0, 4, 1 do
					if enemy:getEquip(j) and enemy:getEquip(j):getSuit() == i then
						local val = equip_val_table[j + 1]
						if j == 1 and self:needToThrowArmor(enemy) then val = -0.5
						else
							if enemy:hasSkills(sgs.lose_equip_skill) then val = val / 8 end
							if enemy:getEquip(j):getEffectiveId() == self:getValuableCard(enemy) then val = val * 1.1 end
							if enemy:getEquip(j):getEffectiveId() == self:getDangerousCard(enemy) then val = val * 1.1 end
						end
						suit_num = suit_num + j
					end
				end
				if suit_num > max_suit_num then
					max_suit_num = suit_num
					max_suit = { i }
				elseif suit_num == max_suit_num then
					table.insert(max_suit, i)
				end
			end
			if max_suit_num == 0 then
				max_suit = {}
				local suit_value = { 1, 1, 1.3, 1.5 }
				for _, skill in ipairs(sgs.getPlayerSkillList(enemy)) do
					if sgs[skill:objectName() .. "_suit_value"] then
						for i = 1, 4, 1 do
							local v = sgs[skill:objectName() .. "_suit_value"][suit_table[i]]
							if v then suit_value[i] = suit_value[i] + v end
						end
					end
				end
				local max_suit_val = 0
				for i = 0, 3, 1 do
					local suit_val = suit_value[i + 1]
					if suit_val > max_suit_val then
						max_suit_val = suit_val
						max_suit = { i }
					elseif suit_val == max_suit_val then
						table.insert(max_suit, i)
					end
				end
			end
			for _, card in ipairs(cards) do
				if self:getUseValue(card) < 6 and table.contains(max_suit, card:getSuit()) then
					use.card = sgs.Card_Parse("@FanjianCard=" .. card:getEffectiveId())
					if use.to then use.to:append(enemy) end
					return
				end
			end
			if getCardsNum("Peach", enemy, self.player) < 2 then
				for _, card in ipairs(cards) do
					if self:getUseValue(card) < 6 and not self:isValuableCard(card) then
						use.card = sgs.Card_Parse("@FanjianCard=" .. card:getEffectiveId())
						if use.to then use.to:append(enemy) end
						return
					end
				end
			end
		end
	end
	for _, friend in ipairs(self.friends_noself) do
		if friend:hasSkill("hongyan") then
			for _, card in ipairs(cards) do
				if self:getUseValue(card) < 6 and card:getSuit() == sgs.Card_Spade then
					use.card = sgs.Card_Parse("@FanjianCard=" .. card:getEffectiveId())
					if use.to then use.to:append(friend) end
					return
				end
			end
		end
		if friend:hasSkill("zhaxiang") and not self:isWeak(friend) and not (friend:getHp() == 2 and friend:hasSkill("chanyuan")) then
			for _, card in ipairs(cards) do
				if self:getUseValue(card) < 6 then
					use.card = sgs.Card_Parse("@FanjianCard=" .. card:getEffectiveId())
					if use.to then use.to:append(friend) end
					return
				end
			end
		end
	end
end

sgs.ai_card_intention.FanjianCard = function(self, card, from, tos)
	local to = tos[1]
	if to:hasSkill("zhaxiang") then
	elseif card:getSuit() == sgs.Card_Spade and to:hasSkill("hongyan") then
		sgs.updateIntention(from, to, -10)
	else
		sgs.updateIntention(from, to, 60)
	end
end

sgs.ai_use_priority.FanjianCard = 0.2

sgs.ai_skill_invoke.fanjian_discard = function(self, data)
	if self:getCardsNum("Peach") >= 1 and not self:willSkipPlayPhase() then return false end
	if not self:isWeak() and self.player:hasSkill("zhaxiang") and not (self.player:getHp() == 2 and self.player:hasSkill("chanyuan")) then return false end
	if self.player:getHandcardNum() <= 3 or self:isWeak() then return true end
	local suit = self.player:getMark("FanjianSuit")
	local count = 0
	for _, card in sgs.qlist(self.player:getHandcards()) do
		if card:getSuit() == suit then
			count = count + 1
			if self:isValuableCard(card) then count = count + 0.5 end
		end
	end
	local equip_val_table = { 2, 2.5, 1, 1.5, 2.2 }
	for i = 0, 4, 1 do
		if self.player:getEquip(i) and self.player:getEquip(i):getSuit() == suit then
			if i == 1 and self:needToThrowArmor() then
				count = count - 1
			else
				count = equip_val_table[i + 1]
				if self.player:hasSkills(sgs.lose_equip_skill) then count = count + 0.5 end
			end
		end
	end
	return count / self.player:getCardCount(true) <= 0.6
end

-- 国色
local guose_skill = {}
guose_skill.name = "guose"
table.insert(sgs.ai_skills, guose_skill)
guose_skill.getTurnUseCard = function(self, inclusive)
	if self.player:hasUsed("GuoseCard") then return end
	local cards = self.player:getCards("he")
	for _, id in sgs.qlist(self.player:getPile("wooden_ox")) do
		local c = sgs.Sanguosha:getCard(id)
		cards:prepend(c)
	end
	cards = sgs.QList2Table(cards)

	self:sortByUseValue(cards, true)
	local card = nil
	local has_weapon, has_armor = false, false

	for _, acard in ipairs(cards) do
		if acard:isKindOf("Weapon") and not (acard:getSuit() == sgs.Card_Diamond) then has_weapon = true end
	end

	for _, acard in ipairs(cards) do
		if acard:isKindOf("Armor") and not (acard:getSuit() == sgs.Card_Diamond) then has_armor = true end
	end

	for _, acard in ipairs(cards) do
		if (acard:getSuit() == sgs.Card_Diamond) and ((self:getUseValue(acard) < sgs.ai_use_value.Indulgence) or inclusive) then
			local shouldUse = true

			if acard:isKindOf("Armor") then
				if not self.player:getArmor() then shouldUse = false
				elseif self.player:hasEquip(acard) and not has_armor and self:evaluateArmor() > 0 then shouldUse = false
				end
			end

			if acard:isKindOf("Weapon") then
				if not self.player:getWeapon() then shouldUse = false
				elseif self.player:hasEquip(acard) and not has_weapon then shouldUse = false
				end
			end

			if shouldUse then
				card = acard
				break
			end
		end
	end

	if not card then return nil end
	return sgs.Card_Parse("@GuoseCard=" .. card:getEffectiveId())
end

sgs.ai_skill_use_func.GuoseCard = function(card, use, self)
	self:sort(self.friends)
	local id = card:getEffectiveId()
	local indul_only = self.player:handCards():contains(id)
	local rcard = sgs.Sanguosha:getCard(id)
	if not indul_only and not self.player:isJilei(rcard) then
		sgs.ai_use_priority.GuoseCard = 5.5
		for _, friend in ipairs(self.friends) do
			if friend:containsTrick("indulgence") and self:willSkipPlayPhase(friend)
				and not friend:hasSkills("shensu|qingyi|qiaobian") and (self:isWeak(friend) or self:getOverflow(friend) > 1) then
				for _, c in sgs.qlist(friend:getJudgingArea()) do
					if c:isKindOf("Indulgence") and self.player:canDiscard(friend, card:getEffectiveId()) then
						use.card = card
						if use.to then use.to:append(friend) end
						return
					end
				end
			end
		end
	end

	local indulgence = sgs.cloneCard("indulgence")
	indulgence:addSubcard(id)
	if not self.player:isLocked(indulgence) then
		sgs.ai_use_priority.GuoseCard = sgs.ai_use_priority.Indulgence
		local dummy_use = { isDummy = true, to = sgs.SPlayerList() }
		self:useCardIndulgence(indulgence, dummy_use)
		if dummy_use.card and dummy_use.to:length() > 0 then
			use.card = card
			if use.to then use.to:append(dummy_use.to:first()) end
			return
		end
	end

	sgs.ai_use_priority.GuoseCard = 5.5
	if not indul_only and not self.player:isJilei(rcard) then
		for _, friend in ipairs(self.friends) do
			if friend:containsTrick("indulgence") and self:willSkipPlayPhase(friend) then
				for _, c in sgs.qlist(friend:getJudgingArea()) do
					if c:isKindOf("Indulgence") and self.player:canDiscard(friend, card:getEffectiveId()) then
						use.card = card
						if use.to then use.to:append(friend) end
						return
					end
				end
			end
		end
	end

	if not indul_only and not self.player:isJilei(rcard) then
		for _, friend in ipairs(self.friends) do
			if friend:containsTrick("indulgence") then
				for _, c in sgs.qlist(friend:getJudgingArea()) do
					if c:isKindOf("Indulgence") and self.player:canDiscard(friend, card:getEffectiveId()) then
						use.card = card
						if use.to then use.to:append(friend) end
						return
					end
				end
			end
		end
	end
end

sgs.ai_use_priority.GuoseCard = 5.5
sgs.ai_use_value.GuoseCard = 5
sgs.ai_card_intention.GuoseCard = -60

function sgs.ai_cardneed.guose(to, card)
	return card:getSuit() == sgs.Card_Diamond
end

sgs.guose_suit_value = {
	diamond = 3.9
}

-- 流离
sgs.ai_skill_use["@@liuli"] = function(self, prompt, method)
	local others = self.room:getOtherPlayers(self.player)
	local slash = self.player:getTag("liuli-card"):toCard()
	others = sgs.QList2Table(others)
	local source
	for _, player in ipairs(others) do
		if player:hasFlag("LiuliSlashSource") then
			source = player
			break
		end
	end
	self:sort(self.enemies, "defense")

	local doLiuli = function(who)
		if not self:isFriend(who) and who:hasSkill("leiji")
			and (self:hasSuit("spade", true, who) or who:getHandcardNum() >= 3)
			and (getKnownCard(who, self.player, "Jink", true) >= 1 or self:hasEightDiagramEffect(who)) then
			return "."
		end

		local cards = self.player:getCards("h")
		cards = sgs.QList2Table(cards)
		self:sortByKeepValue(cards)
		for _, card in ipairs(cards) do
			if not self.player:isCardLimited(card, method) and self.player:canSlash(who) then
				if self:isFriend(who) and not (isCard("Peach", card, self.player) or isCard("Analeptic", card, self.player)) then
					return "@LiuliCard=" .. card:getEffectiveId() .. "->" .. who:objectName()
				else
					return "@LiuliCard=" .. card:getEffectiveId() .. "->" .. who:objectName()
				end
			end
		end

		local cards = self.player:getCards("e")
		cards = sgs.QList2Table(cards)
		self:sortByKeepValue(cards)
		for _, card in ipairs(cards) do
			local range_fix = 0
			if card:isKindOf("Weapon") then range_fix = range_fix + sgs.weapon_range[card:getClassName()] - self.player:getAttackRange(false) end
			if card:isKindOf("OffensiveHorse") then range_fix = range_fix + 1 end
			if not self.player:isCardLimited(card, method) and self.player:canSlash(who, nil, true, range_fix) then
				return "@LiuliCard=" .. card:getEffectiveId() .. "->" .. who:objectName()
			end
		end
		return "."
	end

	for _, enemy in ipairs(self.enemies) do
		if not (source and source:objectName() == enemy:objectName()) then
			local ret = doLiuli(enemy)
			if ret ~= "." then return ret end
		end
	end

	for _, player in ipairs(others) do
		if self:objectiveLevel(player) == 0 and not (source and source:objectName() == player:objectName()) then
			local ret = doLiuli(player)
			if ret ~= "." then return ret end
		end
	end

	self:sort(self.friends_noself, "defense")
	self.friends_noself = sgs.reverse(self.friends_noself)

	for _, friend in ipairs(self.friends_noself) do
		if not self:slashIsEffective(slash, friend) or self:findLeijiTarget(friend, 50, source) then
			if not (source and source:objectName() == friend:objectName()) then
				local ret = doLiuli(friend)
				if ret ~= "." then return ret end
			end
		end
	end

	for _, friend in ipairs(self.friends_noself) do
		if self:needToLoseHp(friend, source, true) or self:getDamagedEffects(friend, source, true) then
			if not (source and source:objectName() == friend:objectName()) then
				local ret = doLiuli(friend)
				if ret ~= "." then return ret end
			end
		end
	end

	if (self:isWeak() or self:hasHeavySlashDamage(source, slash)) and source:hasWeapon("axe") and source:getCards("he"):length() > 2
		and not self:getCardId("Peach") and not self:getCardId("Analeptic") then
		for _, friend in ipairs(self.friends_noself) do
			if not self:isWeak(friend) then
				if not (source and source:objectName() == friend:objectName()) then
					local ret = doLiuli(friend)
					if ret ~= "." then return ret end
				end
			end
		end
	end

	if (self:isWeak() or self:hasHeavySlashDamage(source, slash)) and not self:getCardId("Jink") then
		for _, friend in ipairs(self.friends_noself) do
			if not self:isWeak(friend) or (self:hasEightDiagramEffect(friend) and getCardsNum("Jink", friend, self.player) >= 1) then
				if not (source and source:objectName() == friend:objectName()) then
					local ret = doLiuli(friend)
					if ret ~= "." then return ret end
				end
			end
		end
	end
	return "."
end

sgs.ai_card_intention.LiuliCard = function(self, card, from, to)
	if not self:isWeak(from) or getCardsNum("Jink", from, to) > 0 then sgs.updateIntention(from, to[1], 50) end
end

function sgs.ai_slash_prohibit.liuli(self, from, to, card)
	if self:isFriend(to, from) then return false end
	if from:hasFlag("NosJiefanUsed") then return false end
	if to:isNude() then return false end
	for _, friend in ipairs(self:getFriendsNoself(from)) do
		if to:canSlash(friend, card) and self:slashIsEffective(card, friend, from) then return true end
	end
end

function sgs.ai_cardneed.liuli(to, card)
	return to:getCards("he"):length() <= 2
end

-- 谦逊
sgs.ai_skill_invoke.qianxun = function(self, data)
	local effect = data:toCardEffect()
	if effect.card:isKindOf("Collateral") and self.player:getWeapon() then
		local victim = self.player:getTag("collateralVictim"):toPlayer()
		if victim and sgs.ai_skill_cardask["collateral-slash"](self, nil, nil, victim, effect.from) ~= "." then return false end
	end
	if self.player:getPhase() == sgs.Player_Judge then
		if effect.card:isKindOf("Lightning") and self:isWeak() and self:getCardsNum("Peach") + self:getCardsNum("Analeptic") > 0 then return false end
		return true
	end
	local current = self.room:getCurrent()
	if current and self:isFriend(current) and effect.from and self:isFriend(effect.from) then return true end
	if effect.card:isKindOf("Duel") and sgs.ai_skill_cardask["duel-slash"](self, data, nil, effect.from) ~= "." then return false end
	if effect.card:isKindOf("AOE") and sgs.ai_skill_cardask.aoe(self, data, nil, effect.from, effect.card:objectName()) ~= "." then return false end
	if self.player:getHandcardNum() < self:getLeastHandcardNum(self.player) then return true end
	local l_lim, u_lim = math.max(2, self:getLeastHandcardNum(self.player)), math.max(5, #self.friends)
	if u_lim <= l_lim then u_lim = l_lim + 1 end
	return math.random(0, 100) >= (self.player:getHandcardNum() - l_lim) / (u_lim - l_lim + 1) * 100
end

-- 连营
sgs.ai_skill_use["@@lianying"] = function(self, prompt)
	local move = self.player:getTag("LianyingMoveData"):toMoveOneTime()
	local effect = nil
	if move.reason.m_skillName == "qianxun" then effect = self.player:getTag("QianxunEffectData"):toCardEffect() end
	local upperlimit = self.player:getMark("lianying")

	local targets = {}
	if self.player:getPhase() <= sgs.Player_Play then
		table.insert(targets, self.player:objectName())
		if upperlimit == 1 then return "@LianyingCard=.->" .. self.player:objectName() end
	end
	local exclude_self, sn_dis_eff = false
	if effect and (effect.card:isKindOf("Snatch") or effect.card:isKindOf("Dismantlement"))
		and effect.from:isAlive() and self:isEnemy(effect.from) then
		if self.player:getEquips():isEmpty() then
			exclude_self = true
		else
			sn_dis_eff = true
		end
	end
	if hasManjuanEffect(self.player) then exclude_self = true end
	if not exclude_self and effect and effect.card:isKindOf("FireAttack") and effect.from:isAlive()
		and not effect.from:isKongcheng() and self:isEnemy(effect.from) then
		exclude_self = true
	end

	local getValue = function(friend)
		local def = sgs.getDefense(friend)
		if friend:objectName() == self.player:objectName() then
			if sn_dis_eff then def = def + 5 else def = def - 2 end
		end
		return def
	end
	local cmp = function(a, b)
		return getValue(a) < getValue(b)
	end
	table.sort(self.friends, cmp)

	for _, friend in ipairs(self.friends) do
		if not hasManjuanEffect(friend) and not self:needKongcheng(friend, true) and not table.contains(targets, friend:objectName())
			and not (exclude_self and friend:objectName() == self.player:objectName()) then
			table.insert(targets, friend:objectName())
			if #targets == upperlimit then break end
		end
	end
	if #targets > 0 then return "@LianyingCard=.->" .. table.concat(targets, "+") end
	return "."
end

-- 结姻
local jieyin_skill = {}
jieyin_skill.name = "jieyin"
table.insert(sgs.ai_skills, jieyin_skill)
jieyin_skill.getTurnUseCard = function(self)
	if self.player:getHandcardNum() < 2 then return nil end
	if self.player:hasUsed("JieyinCard") then return nil end

	local cards = self.player:getHandcards()
	cards = sgs.QList2Table(cards)

	local first, second
	self:sortByUseValue(cards, true)
	for _, card in ipairs(cards) do
		if card:isKindOf("TrickCard") then
			local dummy_use = { isDummy = true }
			self:useTrickCard(card, dummy_use)
			if not dummy_use.card then
				if not first then first = card:getEffectiveId()
				elseif first and not second then second = card:getEffectiveId()
				end
			end
			if first and second then break end
		end
	end
	for _, card in ipairs(cards) do
		if card:getTypeId() ~= sgs.Card_TypeEquip and (not self:isValuableCard(card) or self.player:isWounded()) then
			if not first then first = card:getEffectiveId()
			elseif first and first ~= card:getEffectiveId() and not second then second = card:getEffectiveId()
			end
		end
		if first and second then break end
	end

	if not first or not second then return end
	local card_str = ("@JieyinCard=%d+%d"):format(first, second)
	assert(card_str)
	return sgs.Card_Parse(card_str)
end

function SmartAI:getWoundedFriend(maleOnly, include_self)
	local friends = include_self and self.friends or self.friends_noself
	self:sort(friends, "hp")
	local list1 = {}  -- need help
	local list2 = {}  -- do not need help
	local addToList = function(p, index)
		if (not maleOnly or p:isMale()) and p:isWounded() then
			table.insert(index == 1 and list1 or list2, p)
		end
	end

	local getCmpHp = function(p)
		local hp = p:getHp()
		if p:isLord() and self:isWeak(p) then hp = hp - 10 end
		if p:objectName() == self.player:objectName() and self:isWeak(p) and p:hasSkill("qingnang") then hp = hp - 5 end
		if p:hasSkill("buqu") and p:getPile("buqu"):length() > 0 then hp = hp + math.max(0, 5 - p:getPile("buqu"):length()) end
		if p:hasSkill("nosbuqu") and p:getPile("nosbuqu"):length() > 0 then hp = hp + math.max(0, 5 - p:getPile("nosbuqu"):length()) end
		if p:hasSkills("nosrende|rende|kuanggu|kofkuanggu|zaiqi") and p:getHp() >= 2 then hp = hp + 5 end
		return hp
	end

	local cmp = function (a, b)
		if getCmpHp(a) == getCmpHp(b) then
			return sgs.getDefenseSlash(a, self) < sgs.getDefenseSlash(b, self)
		else
			return getCmpHp(a) < getCmpHp(b)
		end
	end

	for _, friend in ipairs(friends) do
		if friend:isLord() then
			if friend:getMark("hunzi") == 0 and friend:hasSkill("hunzi")
				and self:getEnemyNumBySeat(self.player, friend) <= (friend:getHp() >= 2 and 1 or 0) then
				addToList(friend, 2)
			elseif friend:getHp() >= getBestHp(friend) then
				addToList(friend, 2)
			elseif not sgs.isLordHealthy() then
				addToList(friend, 1)
			end
		else
			addToList(friend, friend:getHp() >= getBestHp(friend) and 2 or 1)
		end
	end
	table.sort(list1, cmp)
	table.sort(list2, cmp)
	return list1, list2
end

sgs.ai_skill_use_func.JieyinCard = function(card, use, self)
	local arr1, arr2 = self:getWoundedFriend(true)
	table.removeOne(arr1, self.player)
	table.removeOne(arr2, self.player)
	local target = nil

	repeat
		if #arr1 > 0 and (self:isWeak(arr1[1]) or self:isWeak() or self:getOverflow() >= 1) then
			target = arr1[1]
			break
		end
		if #arr2 > 0 and self:isWeak() then
			target = arr2[1]
			break
		end
	until true

	if not target and self:isWeak() and self:getOverflow() >= 2 and (self.role == "lord" or self.role == "renegade") then
		local others = self.room:getOtherPlayers(self.player)
		for _, other in sgs.qlist(others) do
			if other:isWounded() and other:isMale() then
				if not other:hasSkills(sgs.masochism_skill) then
					target = other
					self.player:setFlags("AI_JieyinToEnemy_" .. other:objectName())
					break
				end
			end
		end
	end

	if target then
		use.card = card
		if use.to then use.to:append(target) end
		return
	end
end

sgs.ai_use_priority.JieyinCard = 3.0

sgs.ai_card_intention.JieyinCard = function(self, card, from, tos)
	if not from:hasFlag("AI_JieyinToEnemy_" .. tos[1]:objectName()) then
		sgs.updateIntention(from, tos[1], -80)
	end
end

sgs.dynamic_value.benefit.JieyinCard = true

-- 枭姬
sgs.ai_skill_invoke.xiaoji = sgs.ai_skill_invoke.jizhi

sgs.xiaoji_keep_value = {
	Peach = 6,
	Jink = 5.1,
	Weapon = 4.9,
	Armor = 5,
	OffensiveHorse = 4.8,
	DefensiveHorse = 5
}

sgs.ai_cardneed.xiaoji = sgs.ai_cardneed.equip

-- 除疠
local chuli_skill = {}
chuli_skill.name = "chuli"
table.insert(sgs.ai_skills, chuli_skill)
chuli_skill.getTurnUseCard = function(self, inclusive)
	if not self.player:canDiscard(self.player, "he") or self.player:hasUsed("ChuliCard") then return nil end

	local cards = self.player:getCards("he")
	cards = sgs.QList2Table(cards)
	self:sortByUseValue(cards, true)

	if self:needToThrowArmor() then return sgs.Card_Parse("@ChuliCard=" .. self.player:getArmor():getEffectiveId()) end
	for _, card in ipairs(cards) do
		if not self:isValuableCard(card) then
			if card:getSuit() == sgs.Card_Spade then return sgs.Card_Parse("@ChuliCard=" .. card:getEffectiveId()) end
		end
	end
	for _, card in ipairs(cards) do
		if not self:isValuableCard(card) and not (self.player:hasSkill("jijiu") and card:isRed() and self:getOverflow() < 2) then
			if card:getSuit() == sgs.Card_Spade then return sgs.Card_Parse("@ChuliCard=" .. card:getEffectiveId()) end
		end
	end
end

sgs.ai_skill_use_func.ChuliCard = function(card, use, self)
	self.chuli_id_choice = {}
	local players = self:findPlayerToDiscard("he", false, true, nil, true)
	local kingdoms = {}
	local targets = {}
	for _, player in ipairs(players) do
		if self:isFriend(player) and not table.contains(kingdoms, player:getKingdom()) then
			table.insert(targets, player)
			table.insert(kingdoms, player:getKingdom())
		end
	end
	for _, player in ipairs(players) do
		if not table.contains(targets, player, true) and not table.contains(kingdoms, player:getKingdom()) then
			table.insert(targets, player)
			table.insert(kingdoms, player:getKingdom())
		end
	end
	if #targets == 0 then return end
	for _, p in ipairs(targets) do
		local id = self:askForCardChosen(p, "he", "dummyreason", sgs.Card_MethodDiscard)
		local chosen_card
		if id then chosen_card = sgs.Sanguosha:getCard(id) end
		if id and chosen_card and (self:isFriend(p) or not p:hasEquip(chosen_card) or sgs.Sanguosha:getCard(id):getSuit() ~= sgs.Card_Spade) then
			if not use.card then use.card = card end
			self.chuli_id_choice[p:objectName()] = id
			if use.to then use.to:append(p) end
		end
	end
end

sgs.ai_use_value.ChuliCard = 5
sgs.ai_use_priority.ChuliCard = 4.6

sgs.ai_card_intention.ChuliCard = function(self, card, from, tos)
	for _, to in ipairs(tos) do
		if self.chuli_id_choice and self.chuli_id_choice[to:objectName()] then
			local em_prompt = { "cardChosen", "chuli", tostring(self.chuli_id_choice[to:objectName()]), from:objectName(), to:objectName() }
			sgs.ai_choicemade_filter.cardChosen.snatch(self, nil, em_prompt)
		end
	end
end

-- 急救
sgs.ai_view_as.jijiu = function(card, player, card_place)
	local suit = card:getSuitString()
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	if card_place ~= sgs.Player_PlaceSpecial and card:isRed() and player:getPhase() == sgs.Player_NotActive
		and player:getMark("Global_PreventPeach") == 0 then
		return ("peach:jijiu[%s:%s]=%d"):format(suit, number, card_id)
	end
end

sgs.jijiu_suit_value = {
	heart = 6,
	diamond = 6
}

sgs.ai_cardneed.jijiu = function(to, card)
	return card:isRed()
end

-- 无双
function SmartAI:canUseJieyuanDecrease(damage_from, player)
	if not damage_from then return false end
	local player = player or self.player
	if player:hasSkill("jieyuan") and damage_from:getHp() >= player:getHp() then
		for _, card in sgs.qlist(player:getHandcards()) do
			local flag = string.format("%s_%s_%s", "visible", self.room:getCurrent():objectName(), player:objectName())
			if player:objectName() == self.player:objectName() or card:hasFlag("visible") or card:hasFlag(flag) then
				if card:isRed() and not isCard("Peach", card, player) then return true end
			end
		end
	end
	return false
end


sgs.ai_skill_cardask["@wushuang-slash-1"] = function(self, data, pattern, target)
	if sgs.ai_skill_cardask.nullfilter(self, data, pattern, target) then return "." end
	if self:canUseJieyuanDecrease(target) then return "." end
	if not target:hasSkill("jueqing") and (self.player:hasSkill("wuyan") or target:hasSkill("wuyan")) then return "." end
	if self:getCardsNum("Slash") < 2 and not (self.player:getHandcardNum() == 1 and self.player:hasSkills(sgs.need_kongcheng)) then return "." end
end

sgs.ai_skill_cardask["@multi-jink-start"] = function(self, data, pattern, target, target2, arg)
	local rest_num = tonumber(arg)
	if rest_num == 1 then return sgs.ai_skill_cardask["slash-jink"](self, data, pattern, target) end
	if sgs.ai_skill_cardask.nullfilter(self, data, pattern, target) then return "." end
	if self:canUseJieyuanDecrease(target) then return "." end
	if sgs.ai_skill_cardask["slash-jink"](self, data, pattern, target) == "." then return "." end
	if self.player:hasSkill("kongcheng") then
		if self.player:getHandcardNum() == 1 and self:getCardsNum("Jink") == 1 and target:hasWeapon("guding_blade") then return "." end
	else
		if self:getCardsNum("Jink") < rest_num and self:hasLoseHandcardEffective() then return "." end
	end
end

sgs.ai_skill_cardask["@multi-jink"] = sgs.ai_skill_cardask["@multi-jink-start"]

-- 利驭
local function getPriorFriendsOfLiyu(self, lvbu)
	lvbu = lvbu or self.player
	local prior_friends = {}
	if not string.startsWith(self.room:getMode(), "06_") and not sgs.GetConfig("EnableHegemony", false) then
		if lvbu:isLord() then
			for _, friend in ipairs(self:getFriendsNoself(lvbu)) do
				if sgs.evaluatePlayerRole(friend) == "loyalist" then table.insert(prior_friends, friend) end
			end
		elseif lvbu:getRole() == "loyalist" then
			local lord = self.room:getLord()
			if lord then prior_friends = { lord } end
		elseif self.room:getMode() == "couple" then
			local diaochan = self.room:getPlayer("diaochan")
			if diaochan then prior_friends = { diaochan } end
		end
	elseif self.room:getMode() == "06_3v3" then
		if lvbu:getRole() == "loyalist" then
			for _, friend in ipairs(self:getFriendsNoself(lvbu)) do
				if friend:getRole() == "lord" then table.insert(prior_friends, friend) break end
			end
		elseif lvbu:getRole() == "rebel" then
			for _, friend in ipairs(self:getFriendsNoself(lvbu)) do
				if friend:getRole() == "renegade" then table.insert(prior_friends, friend) break end
			end
		end
	elseif self.room:getMode() == "06_XMode" then
		local leader = lvbu:getTag("XModeLeader"):toPlayer()
		local backup = 0
		if leader then
			backup = #leader:getTag("XModeBackup"):toStringList()
			if backup == 0 then
				prior_friends = self:getFriendsNoself(lvbu)
			end
		end
	end
	return prior_friends
end

function SmartAI:hasLiyuEffect(target, slash)
	local upperlimit = (self.player:hasSkill("wushuang") and 2 or 1)
	if #self.friends_noself == 0 or self.player:hasSkill("jueqing") then return false end
	if not self:slashIsEffective(slash, target, self.player) then return false end

	local targets = { target }
	if not self.player:hasSkill("jueqing") and target:isChained() and slash:isKindOf("NatureSlash") then
		for _, p in sgs.qlist(self.room:getOtherPlayers(target)) do
			if p:isChained() and p:objectName() ~= self.player:objectName() then table.insert(targets, p) end
		end
	end
	local unsafe = false
	for _, p in ipairs(targets) do
		if self:isEnemy(target) and not target:isNude() then
			unsafe = true
			break
		end
	end
	if not unsafe then return false end

	local duel = sgs.cloneCard("Duel")
	if self.player:isLocked(duel) then return false end

	local enemy_null = 0
	for _, p in sgs.qlist(self.room:getOtherPlayers(self.player)) do
		if self:isFriend(p) then enemy_null = enemy_null - getCardsNum("Nullification", p, self.player) end
		if self:isEnemy(p) then enemy_null = enemy_null + getCardsNum("Nullification", p, self.player) end
	end
	enemy_null = enemy_null - self:getCardsNum("Nullification")
	if enemy_null <= -1 then return false end

	local prior_friends = getPriorFriendsOfLiyu(self)
	if #prior_friends == 0 then return false end
	for _, friend in ipairs(prior_friends) do
		if self:hasTrickEffective(duel, friend, self.player) and self:isWeak(friend) and (getCardsNum("Slash", friend, self.player) < upperlimit or self:isWeak()) then
			return true
		end
	end

	if sgs.isJinkAvailable(self.player, target, slash) and getCardsNum("Jink", target, self.player) >= upperlimit
		and not self:needToLoseHp(target, self.player, true) and not self:getDamagedEffects(target, self.player, true) then return false end
	if slash:hasFlag("AIGlobal_KillOff") or (target:getHp() == 1 and self:isWeak(target) and self:getSaveNum() < 1) then return false end

	if self.player:hasSkill("wumou") and self.player:getMark("@wrath") == 0 and (self:isWeak() or not self.player:hasSkill("zhaxiang")) then return true end
	if self.player:hasSkills("jizhi|nosjizhi") or (self.player:hasSkill("jilve") and self.player:getMark("@bear") > 0) then return false end
	if not string.startsWith(self.room:getMode(), "06_") and not sgs.GetConfig("EnableHegemony", false) and self.role ~= "rebel" then
		for _, friend in ipairs(self.friends_noself) do
			if self:hasTrickEffective(duel, friend, self.player) and self:isWeak(friend) and (getCardsNum("Slash", friend, self.player) < upperlimit or self:isWeak())
				and self:getSaveNum(true) < 1 then
				return true
			end
		end
	end
	return false
end

sgs.ai_skill_playerchosen.liyu = function(self, targets)
	local enemies = {}
	for _, target in sgs.qlist(targets) do
		if self:isEnemy(target) then table.insert(enemies, target) end
	end
	-- should give one card to Lv Bu
	local damage = self.room:getTag("CurrentDamageStruct"):toDamage()
	local lvbu = damage.from
	if not lvbu then return nil end
	local duel = sgs.cloneCard("duel")
	if lvbu:isLocked(duel) then
		if self:isFriend(lvbu) and self:needToThrowArmor() and #enemies > 0 then
			return enemies[1]
		else
			return nil
		end
	end
	if self:isFriend(lvbu) then
		if self.player:getHandcardNum() >= 3 or self:needKongcheng()
			or (self:getLeastHandcardNum() > 0 and self.player:getHandcardNum() <= self:getLeastHandcardNum())
			or self:needToThrowArmor() or self.player:getOffensiveHorse() or (self.player:getWeapon() and self:evaluateWeapon(self.player:getWeapon()) < 5)
			or (not self.player:getEquips():isEmpty() and lvbu:hasSkills("zhijian|yuanhu|huyuan")) then
		else
			return nil
		end
	else
		if self.player:getEquips():isEmpty() then
			local all_peach = true
			for _, card in sgs.qlist(self.player:getHandcards()) do
				if not isCard("Peach", card, lvbu) then all_peach = false break end
			end
			if all_peach then return nil end
		end
		local upperlimit = (self.player:hasSkill("wushuang") and 2 or 1)
		local prior_friends = getPriorFriendsOfLiyu(self, lvbu)
		if #prior_friends > 0 then
			for _, friend in ipairs(prior_friends) do
				if self:hasTrickEffective(duel, friend, lvbu) and self:isWeak(friend)
					and (getCardsNum("Slash", friend, self.player) < upperlimit or self:isWeak(lvbu)) then
					return friend
				end
			end
		end
		if self:getValuableCard(self.player) then return nil end
		local valuable = 0
		for _, card in sgs.qlist(self.player:getHandcards()) do
			if self:isValuableCard(card) then valuable = valuable + 1 end
		end
		if valuable / self.player:getHandcardNum() > 0.4 then return nil end
	end

	-- the target of the Duel
	self:sort(enemies)
	for _, enemy in ipairs(enemies) do
		if self:hasTrickEffective(duel, enemy, lvbu) then
			if not (self:isFriend(lvbu) and getCardsNum("Slash", enemy, self.player) > upperlimit and self:isWeak(lvbu)) then
				return enemy
			end
		end
	end
end

sgs.ai_playerchosen_intention.liyu = 60

-- 离间
function SmartAI:getLijianCard()
	local card_id
	local cards = self.player:getHandcards()
	cards = sgs.QList2Table(cards)
	self:sortByKeepValue(cards)
	local lightning = self:getCard("Lightning")

	if self:needToThrowArmor() then
		card_id = self.player:getArmor():getId()
	elseif self.player:getHandcardNum() > self.player:getHp() then
		if lightning and not self:willUseLightning(lightning) then
			card_id = lightning:getEffectiveId()
		else
			for _, acard in ipairs(cards) do
				if (acard:isKindOf("BasicCard") or acard:isKindOf("EquipCard") or acard:isKindOf("AmazingGrace"))
					and not self:isValuableCard(acard) then
					card_id = acard:getEffectiveId()
					break
				end
			end
		end
	elseif not self.player:getEquips():isEmpty() then
		local player = self.player
		if player:getOffensiveHorse() then card_id = player:getOffensiveHorse():getId()
		elseif player:getWeapon() then card_id = player:getWeapon():getId()
		elseif player:getDefensiveHorse() then card_id = player:getDefensiveHorse():getId()
		elseif player:getArmor() and player:getHandcardNum() <= 1 then card_id = player:getArmor():getId()
		end
	end
	if not card_id then
		if lightning and not self:willUseLightning(lightning) then
			card_id = lightning:getEffectiveId()
		else
			for _, acard in ipairs(cards) do
				if (acard:isKindOf("BasicCard") or acard:isKindOf("EquipCard") or acard:isKindOf("AmazingGrace"))
					and not self:isValuableCard(acard) then
					card_id = acard:getEffectiveId()
					break
				end
			end
		end
	end
	return card_id
end

function SmartAI:findLijianTarget(card_name, use)
	local lord = self.room:getLord()
	local duel = sgs.cloneCard("duel")

	local findFriend_maxSlash = function(self, first)
		local maxSlash = 0
		local friend_maxSlash
		local nos_fazheng
		for _, friend in ipairs(self.friends_noself) do
			if friend:isMale() and self:hasTrickEffective(duel, first, friend) then
				if friend:hasSkill("nosenyuan") and friend:getHp() > 1 then nos_fazheng = friend end
				if (getCardsNum("Slash", friend, self.player) > maxSlash) then
					maxSlash = getCardsNum("Slash", friend, self.player)
					friend_maxSlash = friend
				end
			end
		end

		if friend_maxSlash then
			local safe = false
			if first:hasSkills("ganglie|vsganglie|fankui|nosfankui|enyuan|nosganglie|nosenyuan") and not first:hasSkills("wuyan|noswuyan") then
				if (first:getHp() <= 1 and first:getHandcardNum() == 0) then safe = true end
			elseif (getCardsNum("Slash", friend_maxSlash, self.player) >= getCardsNum("Slash", first, self.player)) then safe = true end
			if safe then return friend_maxSlash end
		end
		if nos_fazheng then return nos_fazheng end
		return nil
	end

	if not sgs.GetConfig("EnableHegemony", false)
		and (self.role == "rebel" or (self.role == "renegade" and sgs.current_mode_players["loyalist"] + 1 > sgs.current_mode_players["rebel"])) then
		if lord and lord:objectName() ~= self.player:objectName() and lord:isMale() and not lord:isNude() then
			self:sort(self.enemies, "handcard")
			local e_peaches = 0
			local loyalist
			for _, enemy in ipairs(self.enemies) do
				e_peaches = e_peaches + getCardsNum("Peach", enemy, self.player)
				if enemy:getHp() == 1 and self:hasTrickEffective(duel, enemy, lord) and enemy:objectName() ~= lord:objectName() and enemy:isMale() then
					loyalist = enemy
					break
				end
			end
			if loyalist and e_peaches < 1 then return loyalist, lord end
		end

		if #self.friends_noself >= 2 and self:getAllPeachNum() < 1 then
			local nextplayerIsEnemy
			local nextp = self.player:getNextAlive()
			for i = 1, self.room:alivePlayerCount() do
				if not self:willSkipPlayPhase(nextp) then
					if not self:isFriend(nextp) then nextplayerIsEnemy = true end
					break
				else
					nextp = nextp:getNextAlive()
				end
			end
			if nextplayerIsEnemy then
				local round = 50
				local to_die, nextfriend
				self:sort(self.enemies,"hp")

				for _, a_friend in ipairs(self.friends_noself) do
					if a_friend:getHp() == 1 and a_friend:isKongcheng() and not a_friend:hasSkill("kongcheng") and a_friend:isMale() then
						for _, b_friend in ipairs(self.friends_noself) do
							if b_friend:objectName() ~= a_friend:objectName() and b_friend:isMale() and self:playerGetRound(b_friend) < round
								and self:hasTrickEffective(duel, a_friend, b_friend) then

								round = self:playerGetRound(b_friend)
								to_die = a_friend
								nextfriend = b_friend
							end
						end
						if to_die and nextfriend then break end
					end
				end
				if to_die and nextfriend then return to_die, nextfriend end
			end
		end
	end

	if lord and lord:objectName() ~= self.player:objectName() and self:isFriend(lord)
		and lord:hasSkill("hunzi") and lord:getHp() == 2 and lord:getMark("hunzi") == 0 then
		local enemycount = self:getEnemyNumBySeat(self.player, lord)
		local peaches = self:getAllPeachNum()
		if peaches >= enemycount then
			local f_target, e_target
			for _, ap in sgs.qlist(self.room:getOtherPlayers(self.player)) do
				if ap:objectName() ~= lord:objectName() and ap:isMale() and self:hasTrickEffective(duel, lord, ap) and ap:getMark("@luoyi") == 0 then
					if ap:hasSkills("jiang|nosjizhi|jizhi") and self:isFriend(ap) and not ap:isLocked(duel) then
						if not use.isDummy then lord:setFlags("AIGlobal_NeedToWake") end
						return lord, ap
					elseif self:isFriend(ap) then
						f_target = ap
					else
						e_target = ap
					end
				end
			end
			if f_target or e_target then
				local target
				if f_target and not f_target:isLocked(duel) then
					target = f_target
				elseif e_target and not e_target:isLocked(duel) then
					target = e_target
				end
				if target then
					if not use.isDummy then lord:setFlags("AIGlobal_NeedToWake") end
					return lord, target
				end
			end
		end
	end

	local shenguanyu = self.room:findPlayerBySkillName("wuhun")
	if shenguanyu and shenguanyu:isMale() and shenguanyu:objectName() ~= self.player:objectName() then
		if self.role == "rebel" and lord and lord:isMale() and not lord:hasSkill("jueqing") and self:hasTrickEffective(duel, shenguanyu, lord) then
			return shenguanyu, lord
		elseif self:isEnemy(shenguanyu) and #self.enemies >= 2 then
			for _, enemy in ipairs(self.enemies) do
				if enemy:objectName() ~= shenguanyu:objectName() and enemy:isMale() and not enemy:isLocked(duel)
					and self:hasTrickEffective(duel, shenguanyu, enemy) then
					return shenguanyu, enemy
				end
			end
		end
	end

	self:sort(self.enemies, "defense")
	local males, others = {}, {}
	local first, second
	local zhugeliang_kongcheng, xunyu, xuchu
		for _, player in sgs.qlist(self.room:getOtherPlayers(self.player)) do
		if player:isMale() and player:getMark("@luoyi") > 0 and not player:isLocked(duel) then
			xuchu = enemy
			break
		end
	end
	for _, enemy in ipairs(self.enemies) do
		if enemy:isMale() and not enemy:hasSkills("wuyan|noswuyan") then
			if enemy:hasSkill("kongcheng") and enemy:isKongcheng() then zhugeliang_kongcheng = enemy
			elseif enemy:hasSkill("jieming") then xunyu = enemy
			else
				for _, anotherenemy in ipairs(self.enemies) do
					if anotherenemy:isMale() and anotherenemy:objectName() ~= enemy:objectName() then
						if #males == 0 and self:hasTrickEffective(duel, enemy, anotherenemy) then
							if not (enemy:hasSkill("hunzi") and enemy:getMark("hunzi") == 0 and enemy:getHp() == 2) then
								table.insert(males, enemy)
							else
								table.insert(others, enemy)
							end
						end
						if #males == 1 and self:hasTrickEffective(duel, males[1], anotherenemy) and not anotherenemy:isLocked(duel) then
							if not anotherenemy:hasSkills("nosjizhi|jizhi|jiang")
								and not (anotherenemy:hasSkill("jilve") and anotherenemy:getMark("@bear") > 0) then
								table.insert(males, anotherenemy)
							else
								table.insert(others, anotherenemy)
							end
						end
					end
				end
			end
			if #males >= 2 then break end
		end
	end

	local insert_friend_xuchu = false
	if #males > 0 and xuchu and self:hasTrickEffective(duel, males[1], xuchu) then
		if not table.contains(males, xuchu, true) then
			local males1 = males[1]
			if self:isEnemy(xuchu) then
				if not xuchu:hasSkills("nosjizhi|jizhi|jiang") and not (xuchu:hasSkill("jilve") and xuchu:getMark("@bear") > 0) then
					males = { males1, xuchu }
				end
			elseif self:isFriend(xuchu) then
				local fac = xuchu:hasSkill("wushuang") and 2 or 1
				if getCardsNum("Slash", males1, self.player) + 1 <= getCardsNum("Slash", xuchu, self.player) * fac then
					insert_friend_xuchu = true
				end
			end
		end
	end

	if #males >= 1 and sgs.ai_role[males[1]:objectName()] == "rebel" and males[1]:getHp() == 1 then
		if lord and self:isFriend(lord) and lord:isMale()
			and lord:objectName() ~= males[1]:objectName() and lord:objectName() ~= self.player:objectName()
			and self:hasTrickEffective(duel, males[1], lord)
			and not lord:isLocked(duel) and (getCardsNum("Slash", males[1], self.player) < 1
											or getCardsNum("Slash", males[1], self.player) < getCardsNum("Slash", lord, self.player)
											or (getKnownNum(males[1]) == males[1]:getHandcardNum() and getKnownCard(males[1], self.player, "Slash", true, "he") == 0)) then
			return males[1], lord
		end
		local afriend = findFriend_maxSlash(self, males[1])
		if afriend and afriend:objectName() ~= males[1]:objectName() and not afriend:isLocked(duel) then
			return males[1], afriend
		end
	end

	if #males == 1 then
		if males[1]:isLord() and sgs.turncount <= 1 and self.role == "rebel" and self.player:aliveCount() >= 3 then
			local p_slash, max_p, max_pp = 0
			for _, p in sgs.qlist(self.room:getOtherPlayers(self.player)) do
				if p:isMale() and not self:isFriend(p) and p:objectName() ~= males[1]:objectName() and self:hasTrickEffective(duel, males[1], p)
					and not p:isLocked(duel) and p_slash < getCardsNum("Slash", p, self.player) then
					if p:getKingdom() == males[1]:getKingdom() then
						max_p = p
						break
					elseif not max_pp then
						max_pp = p
					end
				end
			end
			if max_p then table.insert(males, max_p) end
			if max_pp and #males == 1 then table.insert(males, max_pp) end
		end
	end

	if #males == 1 then
		if insert_friend_xuchu then
			table.insert(males, xuchu)
		elseif #others >= 1 and not others[1]:isLocked(duel) then
			table.insert(males, others[1])
		elseif xunyu and self:hasTrickEffective(duel, males[1], xunyu) and not xunyu:isLocked(duel) then
			if getCardsNum("Slash", males[1], self.player) < 1 then
				table.insert(males, xunyu)
			else
				local drawcards = 0
				for _, enemy in ipairs(self.enemies) do
					local x = math.max(math.min(5, enemy:getMaxHp()) - enemy:getHandcardNum(), 0)
					if x > drawcards then drawcards = x end
				end
					if drawcards <= 2 then
					table.insert(males, xunyu)
				end
			end
		end
	end

	if #males == 1 and #self.friends_noself > 0 then
		first = males[1]
		if zhugeliang_kongcheng and hasTrickEffective(duel, first, zhugeliang_kongcheng) and not zhugeliang_kongcheng:isLocked(duel) then
			table.insert(males, zhugeliang_kongcheng)
		else
			local friend_maxSlash = findFriend_maxSlash(self, first)
			if friend_maxSlash and not friend_maxSlash:isLocked(duel) then table.insert(males, friend_maxSlash) end
		end
	end

	if #males >= 2 then
		first = males[1]
		second = males[2]
		if first:getHp() <= 1 then
			if self.player:isLord() or sgs.isRolePredictable() then
				local friend_maxSlash = findFriend_maxSlash(self, first)
				if friend_maxSlash and not friend_maxSlash:isCardLimited(duel, sgs.Card_MethodUse) then second = friend_maxSlash end
			elseif lord and lord:objectName() ~= self.player:objectName() and lord:isMale() and not lord:hasSkills("wuyan|noswuyan") then
				if self.role == "rebel" and not lord:isLocked(duel) and not first:isLord() and self:hasTrickEffective(duel, first, lord) then
					second = lord
				else
					if (self.role == "loyalist" or self.role == "renegade") and not first:hasSkills("ganglie|enyuan|vsganglie|nosganglie|nosenyuan")
						and getCardsNum("Slash", first, self.player) <= getCardsNum("Slash", second, self.player) and not lord:isLocked(duel) then
						second = lord
					end
				end
			end
		end

		if first and second and first:objectName() ~= second:objectName() and not second:isLocked(duel) then
			return first, second
		end
	end
end

local lijian_skill = {}
lijian_skill.name = "lijian"
table.insert(sgs.ai_skills, lijian_skill)
lijian_skill.getTurnUseCard = function(self)
	if self.player:hasUsed("LijianCard") or not self.player:canDiscard(self.player, "he") then return end
	local card_id = self:getLijianCard()
	if card_id then return sgs.Card_Parse("@LijianCard=" .. card_id) end
end

sgs.ai_skill_use_func.LijianCard = function(card, use, self)
	local first, second = self:findLijianTarget("LijianCard", use)
	if first and second then
		use.card = card
		if use.to then
			use.to:append(first)
			use.to:append(second)
		end
	end
end

sgs.ai_use_value.LijianCard = 8.5
sgs.ai_use_priority.LijianCard = 4

sgs.ai_card_intention.LijianCard = function(self, card, from, to)
	if sgs.evaluatePlayerRole(to[1]) == sgs.evaluatePlayerRole(to[2]) then
		if sgs.evaluatePlayerRole(from) == "rebel" and sgs.evaluatePlayerRole(to[1]) == sgs.evaluatePlayerRole(from) and to[1]:getHp() == 1 then
		elseif to[1]:hasSkill("hunzi") and to[1]:getHp() == 2 and to[1]:getMark("hunzi") == 0 then
		else
			sgs.updateIntentions(from, to, 40)
		end
	elseif sgs.evaluatePlayerRole(to[1]) ~= sgs.evaluatePlayerRole(to[2]) and not to[1]:hasSkill("wuhun") then
		sgs.updateIntention(from, to[1], 80)
	end
end

-- 闭月
sgs.ai_skill_invoke.biyue = sgs.ai_skill_invoke.jizhi

-- 耀武
sgs.ai_skill_choice.yaowu = function(self, choices)
	if self.player:getHp() >= getBestHp(self.player) or (self:needKongcheng(self.player, true) and self.player:getPhase() == sgs.Player_NotActive) then
		return "draw"
	end
	return "recover"
end

-- 妄尊
sgs.ai_skill_invoke.wangzun = function(self, data)
	local lord = self.room:getCurrent()
	if self.player:getPhase() == sgs.Player_NotActive and self:needKongcheng(self.player, true) then
		return self.player:hasSkill("manjuan") and self:isEnemy(lord)
	end
	if self:isEnemy(lord) then return true
	else
		if not self:isWeak(lord) and (self:getOverflow(lord) < -2 or (self:willSkipDrawPhase(lord) and self:getOverflow(lord) < 0)) then
			return true
		end
	end
	return false
end

sgs.ai_choicemade_filter.skillInvoke.wangzun = function(self, player, promptlist)
	if promptlist[#promptlist] == "yes" then
		local lord = self.room:getCurrent()
		if not self:isWeak(lord) and (self:getOverflow(lord) < -2 or (self:willSkipDrawPhase(lord) and self:getOverflow(lord) < 0)) then return end
		sgs.updateIntention(player, lord, 30)
	end
end

-- 趫猛
sgs.ai_skill_invoke.qiaomeng = function(self, data)
	local damage = data:toDamage()
	if self:isFriend(damage.to) then return damage.to:getArmor() and self:needToThrowArmor(damage.to) end
	return not self:doNotDiscard(damage.to, "e")
end