local STATE_MESSAGE = {
	[-1] = {msg = "~m~(MISSING)", desc = "The resource could not be found, likely due to a change of name."},
	[0] = {msg = "~r~(STOPPED)", desc = "The resource was found but not running."},
	[1] = {msg = "~g~(RUNNING)", desc = "The resource was found and running."}
}

local SAS_STATE = -1
local WMSS_STATE = -1
local USE_SUBMENUS = false
local SAS_DEPARTMENTS = { }
local WMSS_REFS = { }
local REQD_AUDIO_BANKS = { }
local DEBUG_MODE = false
local NOTIFIED = false

--MENUS
RMenu.Add('SSAT', 'main', RageUI.CreateMenu("Server Side Audio Tester", "Main Menu"))
RMenu.Add('SSAT', 'sas', RageUI.CreateSubMenu(RMenu:Get('SSAT', 'main'),"Server Side Audio Tester", "Server Sided Sounds and Sirens (SAS)"))
RMenu.Add('SSAT', 'wmss', RageUI.CreateSubMenu(RMenu:Get('SSAT', 'main'),"Server Side Audio Tester", "WM-ServerSirens (WM-SS)"))
RMenu:Get('SSAT', 'main'):SetTotalItemsPerPage(13)
RMenu:Get('SSAT', 'main'):DisplayGlare(false)
RMenu:Get('SSAT', 'sas'):DisplayGlare(false)
RMenu:Get('SSAT', 'wmss'):DisplayGlare(false)

RegisterCommand("ssat", function(source, args)
	RageUI.Visible(RMenu:Get('SSAT', 'main'), not RageUI.Visible(RMenu:Get('SSAT', 'main')))
	
	if not NOTIFIED then
		--HUD Notification
		AddTextEntry("SSAT_Start","~b~SSAT~s~: Remember, ~y~server side audio is only loaded at join~s~. In order for changes to take effect please restart the resource and rejoin.")
		SetNotificationTextEntry("SSAT_Start")
		DrawNotification(false, true)
		
		--Chat Notification
		TriggerEvent('chat:addMessage', {
			multiline = true,
			args = {"~b~SSAT~s~", "Remember, ~y~server side audio is only loaded at join~s~. In order for changes to take effect please restart the resource and rejoin."}
		})
		NOTIFIED = true
	end
end)

RegisterCommand("ssatdebug", function(source, args)
	DEBUG_MODE = not DEBUG_MODE
	print("DEBUG_MODE: ",DEBUG_MODE)
end)

--print function based on debug_mode state
function PRINT(text)
	if DEBUG_MODE then
		print(text)
	end
end

--FIFO Audio Banks, adds and requests audio banks up to 7 then releases oldest
function ReqNewAudioBank(bank)
	print(bank)
	while #REQD_AUDIO_BANKS > 6 do
		ReleaseNamedScriptAudioBank(REQD_AUDIO_BANKS[7])
		ReleaseScriptAudioBank()
		table.remove(REQD_AUDIO_BANKS, 7)
	end
	for i,v in ipairs(REQD_AUDIO_BANKS) do
		if v == bank then
			return
		end
	end
	RequestScriptAudioBank(bank)
	Citizen.Wait(50)
	table.insert(REQD_AUDIO_BANKS, 1, bank)
end

--Returns true if any menu is open
function IsMenuOpen()
	local submenu_open = false
	for i,dept in ipairs(SAS_DEPARTMENTS) do
		if RageUI.Visible(RMenu:Get('SSAT', dept)) then
			submenu_open = true
		end
	end
	for i,ref in ipairs(WMSS_REFS) do
		if RageUI.Visible(RMenu:Get('SSAT', ref)) then
			submenu_open = true
		end
	end
	return 	RageUI.Visible(RMenu:Get('SSAT', 'main')) or 
			RageUI.Visible(RMenu:Get('SSAT', 'sas')) or 
			RageUI.Visible(RMenu:Get('SSAT', 'wmss')) or
			submenu_open
end

--Handle Disabling Controls while menu open
Citizen.CreateThread(function()
Citizen.Wait(1000)
	while true do 
		while IsMenuOpen() do
			DisableControlAction(0, 27, true) 
			DisableControlAction(0, 99, true) 
			DisableControlAction(0, 172, true) 
			DisableControlAction(0, 173, true) 
			DisableControlAction(0, 174, true) 
			DisableControlAction(0, 175, true) 
			Citizen.Wait(0)
		end
		Citizen.Wait(100)
	end
end)

Citizen.CreateThread(function()
	--Build submenus dynamically for submenu organization (USE_SUBMENUS)
	for i,soundset in ipairs(SAS_STRING_REF) do
		ref = soundset[1]
		bank_substring = string.sub(ref,1,-10)
		dept = string.sub(bank_substring,17,-1)
		RMenu.Add('SSAT', dept, RageUI.CreateSubMenu(RMenu:Get('SSAT', 'sas'), "Server Side Audio Tester", bank_substring))
		RMenu:Get('SSAT', dept):DisplayGlare(false)
	end
	for i,soundset in ipairs(SAS_STRING_REF) do
		ref = soundset[1]
		bank_substring = string.sub(ref,1,-10)
		dept = string.sub(bank_substring,17,-1)
		table.insert(SAS_DEPARTMENTS, dept)
	end	
	for i,soundset in ipairs(WMSS_STRING_REF) do
		ref = soundset[1]
		RMenu.Add('SSAT', ref, RageUI.CreateSubMenu(RMenu:Get('SSAT', 'wmss'), "Server Side Audio Tester", ref))
		RMenu:Get('SSAT', ref):DisplayGlare(false)
	end
	for i,soundset in ipairs(WMSS_STRING_REF) do
		ref = soundset[1]
		table.insert(WMSS_REFS, ref)
	end
	
	--Resource state checking, are the resources even running?
	local SAS_STATE_STRING = ""
	local WMSS_STATE_STRING = ""
	
	while true do 
		Citizen.Wait(1000)
		SAS_STATE_STRING = GetResourceState(SAS_RESOURCE_NAME)
		WMSS_STATE_STRING = GetResourceState(WMSS_RESOURCE_NAME)
		
		if SAS_STATE_STRING == "started" or SAS_STATE_STRING == "starting" then
			SAS_STATE = 1
		elseif SAS_STATE_STRING == "stopped" or SAS_STATE_STRING == "stopping" then
			SAS_STATE = 0
		else 
			SAS_STATE = -1
		end		

		if WMSS_STATE_STRING == "started" or WMSS_STATE_STRING == "starting" then
			WMSS_STATE = 1
		elseif WMSS_STATE_STRING == "stopped" or WMSS_STATE_STRING == "stopping" then
			WMSS_STATE = 0
		else 
			WMSS_STATE = -1
		end
	end

end)



Citizen.CreateThread(function()
	local sound_id, siren_name, bank_substring, dept, bank, ref
	local last_siren 

    while true do
		--Main Menu Visible
	    RageUI.IsVisible(RMenu:Get('SSAT', 'main'), function()
			RageUI.Separator("Resource Status")
			RageUI.Button('SAS Resource State', STATE_MESSAGE[SAS_STATE].desc, {RightLabel = STATE_MESSAGE[SAS_STATE].msg}, true, {
				onSelected = function()
				end,
			})					
		
			RageUI.Button('WM-SS Resource State', STATE_MESSAGE[WMSS_STATE].desc, {RightLabel = STATE_MESSAGE[WMSS_STATE].msg}, true, {
				onSelected = function()
				end,
			})					
			RageUI.Checkbox('Submenu Organization', "Toggles whether to list all sirens on one page or to sort them into submenus.", USE_SUBMENUS, {}, {
				onChecked = function()
					USE_SUBMENUS = true
				end,
				onUnChecked = function()
					USE_SUBMENUS = false
				end,
			})
			RageUI.Button('Server Sided Sounds and Sirens (SAS)', "Test the 'Server Sided Sounds and Sirens' resource.", {RightLabel = "→→→"}, SAS_STATE == 1, {
			}, RMenu:Get('SSAT', 'sas'))			
			
			RageUI.Button('WM-ServerSirens (WM-SS)', "Test the 'WM-ServerSirens' resource.", {RightLabel = "→→→"}, WMSS_STATE == 1, {
				onSelected = function()
					for i,bank in ipairs(WMSS_BANKS) do
						ReqNewAudioBank(bank)
					end
				end,
			}, RMenu:Get('SSAT', 'wmss'))
		end)	

		---------------------------------------------------------------------
		-------------------------------SAS MENUS-----------------------------
		---------------------------------------------------------------------	
		if not USE_SUBMENUS then
			--LIST OF TONES NOT ORGANIZED
			RageUI.IsVisible(RMenu:Get('SSAT', 'sas'), function()
				for i,soundset in ipairs(SAS_STRING_REF) do
					ref = soundset[1]
					bank_substring = string.sub(ref,1,-10)
					dept = string.sub(bank_substring,17,-1)
					RageUI.Separator(dept) 
					for i, string in ipairs(soundset[2]) do
						siren_name = string.sub(string,17,-1)
						RageUI.Button(siren_name, "Play OISS_SSA_VEHAUD_"..siren_name, {RightLabel = "→→→"}, true, {
							onSelected = function()
								bank = string.format("DLC_SERVERSIDEAUDIO\\%s", bank_substring) 
								ReqNewAudioBank(bank)
								StopSound(sound_id)
								ReleaseSoundId(sound_id)
								if siren_name ~= last_siren then
									sound_id = GetSoundId()
									last_siren = siren_name
									PlaySoundFrontend(sound_id, string, ref, 0)
									PRINT(string.format("Playing from BANK: \"%s\" STRING: \"%s\" REF: \"%s\"", bank, string, ref))
								else
									last_siren = nil
								end
							end,
						})
					end
				end
			end)
		else
			--BUTTON DISPLAY FOR SUBMENUS  btn->audioref submenu			
			RageUI.IsVisible(RMenu:Get('SSAT', 'sas'), function()
				for i,soundset in ipairs(SAS_STRING_REF) do
					ref = soundset[1]
					bank_substring = string.sub(ref,1,-10)
					dept = string.sub(bank_substring,17,-1)
					RageUI.Button(dept, "Open tones for \""..dept.."\".", {RightLabel = "→→→"}, true, {
					}, RMenu:Get('SSAT', dept))
				end
			end)
			--AUDIOREF ORGANIZED SUBMENUS
			for i,dept in ipairs(SAS_DEPARTMENTS) do
				RageUI.IsVisible(RMenu:Get('SSAT', dept), function()
					for _, string in ipairs(SAS_STRING_REF[i][2]) do
						siren_name = string.sub(string,17,-1)
						RageUI.Button(siren_name, "Play OISS_SSA_VEHAUD_"..siren_name, {RightLabel = "→→→"}, true, {
							onSelected = function()
								bank_substring = string.sub(SAS_STRING_REF[i][1],1,-10)
								bank = string.format("DLC_SERVERSIDEAUDIO\\%s", bank_substring) 
								ReqNewAudioBank(bank)
								StopSound(sound_id)
								ReleaseSoundId(sound_id)
								if siren_name ~= last_siren then
									sound_id = GetSoundId()
									last_siren = siren_name
									PlaySoundFrontend(sound_id, string, SAS_STRING_REF[i][1], 0)
									PRINT(string.format("Playing from BANK: \"%s\" STRING: \"%s\" REF: \"%s\"", bank, string, SAS_STRING_REF[i][1]))
								else
									last_siren = nil
								end
							end,
						})
					end
				end)
			end
		end

		---------------------------------------------------------------------
		-------------------------------WMSS MENUS-----------------------------
		---------------------------------------------------------------------	
		if not USE_SUBMENUS then
			--LIST OF TONES NOT ORGANIZED
			RageUI.IsVisible(RMenu:Get('SSAT', 'wmss'), function()
					for i,soundset in ipairs(WMSS_STRING_REF) do
					ref = soundset[1]
					if i == 1 then
						RageUI.Separator(ref)
					else
						RageUI.Separator(ref.." (PAID)")
					end
					for i, string in ipairs(soundset[2]) do
						RageUI.Button(string, "Play "..ref.."_"..string, {RightLabel = "→→→"}, true, {
							onSelected = function()
								StopSound(sound_id)
								ReleaseSoundId(sound_id)
								if string ~= last_siren then
									sound_id = GetSoundId()
									last_siren = string
									PlaySoundFrontend(sound_id, string, ref, 0)
									PRINT(string.format("Playing from BANK: \"%s\" STRING: \"%s\" REF: \"%s\"", bank, string, ref))
								else
									last_siren = nil
								end
							end,
						})	
					end 
				end 
			end)
		else
			--BUTTON DISPLAY FOR SUBMENUS  btn->audioref submenu
			RageUI.IsVisible(RMenu:Get('SSAT', 'wmss'), function()
				for i,soundset in ipairs(WMSS_STRING_REF) do
					ref = soundset[1]
					RageUI.Button(ref, "Open tones for \""..ref.."\".", {RightLabel = "→→→"}, true, {
					}, RMenu:Get('SSAT', ref))
				end
			end)
			--AUDIOREF ORGANIZED SUBMENUS
			for i,ref in ipairs(WMSS_REFS) do
				RageUI.IsVisible(RMenu:Get('SSAT', ref), function()
					for _, string in ipairs(WMSS_STRING_REF[i][2]) do
						RageUI.Button(string, "Play "..ref.."_"..string, {RightLabel = "→→→"}, true, {
							onSelected = function()
								StopSound(sound_id)
								ReleaseSoundId(sound_id)
								if string ~= last_siren then
									sound_id = GetSoundId()
									last_siren = string
									PlaySoundFrontend(sound_id, string, ref, 0)
									PRINT(string.format("Playing from BANK: \"%s\" STRING: \"%s\" REF: \"%s\"", bank, string, ref))
								else
									last_siren = nil
								end
							end,
						})	
					end
				end)
			end
		end
        Citizen.Wait(0)
	end
end)