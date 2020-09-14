if not VocalHeisters then
    _G.VocalHeisters = {}
    VocalHeisters.ModPath = ModPath
    VocalHeisters.SavePath = SavePath .. "/vocalheisters.json"

	VocalHeisters.Settings = {
		disable_voice_line_force_loading = false
	}

	-- Dice roll value that determines which peer will say voice lines that should only be played once.
	-- Example: at the end of an assault, only the player with the highest dice roll should comment on the assault ending
	-- This number is sent and received over the network as a string.
	VocalHeisters.SayOnceDiceRoll = math.random(1, 1000)
	VocalHeisters.LostDiceRoll = false

	-- Holds other players' diceroll values
	VocalHeisters.PeersWithMod = {}

    -- Saving menu settings
	function VocalHeisters:Save()
		local file = io.open(self.SavePath, "w+")
		if file then
			file:write(json.encode(VocalHeisters.Settings))
			file:close()
		end
	end

	-- Loading menu settings
	function VocalHeisters:Load()
		local file = io.open(self.SavePath, "r")
		if file then
			local fileSettings = json.decode(file:read("*all"))
			for k, v in pairs(fileSettings) do
				VocalHeisters.Settings[k] = v
			end
			file:close()
		end
	end
	
	-- Immediately load and write data so that defaults exist
	VocalHeisters:Load()
	VocalHeisters:Save()

    -- Generic function that makes the player say a voice line
    function VocalHeisters:Say(voice_id)
        if Utils:IsInHeist() and not Utils:IsInCustody() and Utils:IsInGameState() then
			managers.player:local_player():sound():say(voice_id, true, false)
		end
	end

	-- Function that makes the player say a voice line, but only if they have not lost the dice roll.
	function VocalHeisters:SayOnce(voice_id)
		if not self.LostDiceRoll then
			self:Say(voice_id)
		end
	end

	-- Function that makes the player say lines that are normally third-person only
	function VocalHeisters:SayThirdPersonLine(voice_id)
		if Utils:IsInHeist() and not Utils:IsInCustody() and Utils:IsInGameState() then
			managers.player:local_player():sound()._unit:sound_source():set_switch("int_ext", "third")
			managers.player:local_player():sound():say(voice_id, true, false)
			managers.player:local_player():sound()._unit:sound_source():set_switch("int_ext", "first")
		end
	end

	-- Should be called every time a new dice roll value is received, recalculates dice roll value.
	function VocalHeisters:_recalculate_dice_roll()
		self.LostDiceRoll = false

		for peer, roll in pairs(self.PeersWithMod) do
			if peer and roll and roll > self.SayOnceDiceRoll then
				self.LostDiceRoll = true
			end
		end
	end
	
	-- On network load complete, tell peers that you have Vocal Heisters installed.
	-- Also give them your dice roll number, which is used for determining who says an end of assault line.
	Hooks:Add('BaseNetworkSessionOnLoadComplete', 'BaseNetworkSessionOnLoadComplete_VocalHeisters', function(local_peer, id)
		LuaNetworking:SendToPeers("vocalheisters_hello", tostring(math.floor(VocalHeisters.SayOnceDiceRoll)))
	end)

	-- Same as above, if a single peer joins then tell them your dice roll.
	Hooks:Add('BaseNetworkSessionOnPeerEnteredLobby', 'BaseNetworkSessionOnPeerEnteredLobby_VocalHeisters', function(peer, peer_id)
		LuaNetworking:SendToPeer(peer_id, "vocalheisters_hello", tostring(math.floor(VocalHeisters.SayOnceDiceRoll)))
	end)
	
	-- Network data receiving function
	Hooks:Add('NetworkReceivedData', 'NetworkReceivedData_VocalHeisters', function(sender, messageType, data)
		-- Acknowledge that a peer has this mod installed and store their dice roll number
		if messageType == "vocalheisters_hello" then
			VocalHeisters.PeersWithMod[sender] = tonumber(data)
			VocalHeisters:_recalculate_dice_roll()
		end
	end)

	-- If a peer leaves, remove them from the list
	Hooks:Add('BaseNetworkSessionOnPeerRemoved', 'BaseNetworkSessionOnPeerRemoved_VocalHeisters', function(peer, peer_id, reason)
		VocalHeisters.PeersWithMod[peer_id] = nil
		VocalHeisters:_recalculate_dice_roll()
	end)
end