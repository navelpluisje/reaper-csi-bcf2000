-- This script was generated by Lokasenna_Show only specified tracks.lua


local settings = {
	showsiblings = false,
	showparents = false,
	tcp = false,
	mcp = true,
	matchonlytop = true,
	search = "Guitar",
	showchildren = true,
	matchmultiple = true,
}


local info = debug.getinfo(1,'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
local script_filename = ({reaper.get_action_context()})[2]:match("([^/\\]+)$")


local function Msg(str)
    reaper.ShowConsoleMsg(tostring(str) .. "\n")
end




------------------------------------
-------- Search Functions ----------
------------------------------------


-- Returns true if the individual words of str_b all appear in str_a
local function fuzzy_match(str_a, str_b)

    if not (str_a and str_b) then return end
    str_a, str_b = string.lower(tostring(str_a)), string.lower(tostring(str_b))

    --Msg("\nfuzzy match, looking for:\n\t" .. str_b .. "\nin:\n\t" .. str_a .. "\n")

    for word in string.gmatch(str_b, "[^%s]+") do
        --Msg( tostring(word) .. ": " .. tostring( string.match(str_a, word) ) )
        if not string.match(str_a, word) then return end
    end

    return true

end



local function is_match(str, tr_name, tr_idx)

    if str:sub(1, 1) == "#" then

        -- Force an integer until/unless I come up with some sort of multiple track syntax
        str = tonumber(str:sub(2, -1))
        return str and (math.floor( tonumber(str) ) == tr_idx)

    elseif tostring(str) then

        return fuzzy_match(tr_name, tostring(str))

    end

end


local function merge_tables(...)

  local tables = {...}

  local ret = {}
  for i = #tables, 1, -1 do
      if tables[i] then
          for k, v in pairs(tables[i]) do
              if v then ret[k] = v end
          end
      end
  end

  return ret

end



-- Returns an array of MediaTrack == true for all parents of the given MediaTrack
local function recursive_parents(track)
    if reaper.GetTrackDepth(track) == 0 then
        return {[track] = true}
    else
        local ret = recursive_parents( reaper.GetParentTrack(track) )
        ret[track] = true
        return ret
    end

end


local function get_children(tracks)

    local children = {}
    for idx in pairs(tracks) do

        local tr = reaper.GetTrack(0, idx - 1)
        local i = idx + 1
        while i <= reaper.CountTracks(0) do
            children[i] = recursive_parents( reaper.GetTrack(0, i-1) )[tr] == true
            if not children[i] then break end
            i = i + 1
        end
    end

    return children

end


local function get_parents(tracks)

    local parents = {}
    for idx in pairs(tracks) do

        local tr = reaper.GetTrack(0, idx - 1)
        for nextParent in pairs( recursive_parents(tr)) do
            parents[ math.floor( reaper.GetMediaTrackInfo_Value(nextParent, "IP_TRACKNUMBER") ) ] = true
        end

    end

    return parents

end


local function get_top_level_tracks()

    local top = {}
    for i = 1, reaper.CountTracks() do
        if reaper.GetTrackDepth( reaper.GetTrack(0, i-1) ) == 0 then
            top[i] = true
        end
    end

    return top
end


local function get_siblings(tracks)

    local siblings = {}
    for idx in pairs(tracks) do

        local tr = reaper.GetTrack(0, idx - 1)
        local sibling_depth = reaper.GetTrackDepth(tr)

        if sibling_depth > 0 then
            local parent = reaper.GetParentTrack(tr)

            local children = get_children( {[reaper.GetMediaTrackInfo_Value(parent, "IP_TRACKNUMBER")] = true} )
            for child_idx in pairs(children) do

                -- Can't use siblings[idx] = ___ here because we don't want to set existing
                -- siblings to false
                if reaper.GetTrackDepth( reaper.GetTrack(0, child_idx-1) ) == sibling_depth then
                    siblings[child_idx] = true
                end

            end

        else

            -- Find all top-level tracks
            siblings = merge_tables(siblings, get_top_level_tracks())

        end

    end

    return siblings

end


local function get_tracks_to_show(settings)
    --[[
        settings = {
            search = str,

            matchmultiple = bool,
            matchonlytop = bool,
            showchildren = bool,
            showparents = bool,

            mcp = bool,
            tcp = bool
        }
    ]]--
    local matches = {}

    -- Abort if we don't need to be doing this
    if not (settings.tcp or settings.mcp) then return nil end

    -- Find all matches
    for i = 1, reaper.CountTracks(0) do

        local tr = reaper.GetTrack(0, i - 1)
        local _, name = reaper.GetTrackName(tr, "")
        local idx = math.floor( reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER") )
        local ischild = reaper.GetTrackDepth(tr) > 0

        if is_match(settings.search, name, idx) and not (ischild and settings.matchonlytop) then

            matches[idx] = true
            if not settings.matchmultiple then break end

        end

    end

    -- Hacky way to check if length of a hash table == 0
    for k in pairs(matches) do
        if not k then return {} end
    end

    local parents = settings.showparents and get_parents(matches)
    local children = settings.showchildren and get_children(matches)
    local siblings = settings.showsiblings and get_siblings(matches)

    return merge_tables(matches, parents, children, siblings)

end

local function select_first_visible_MCP()
  for i = 1, reaper.CountTracks(0) do
    local tr = reaper.GetTrack(0, i - 1)
    if reaper.IsTrackVisible(tr, true) then
      reaper.SetOnlyTrackSelected(tr)
      break
    end
  end
end

local function set_visibility(tracks, settings)

    if not tracks then return end
    --if not tracks or #tracks == 0 then return end

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    for i = 1, reaper.CountTracks(0) do

        local tr = reaper.GetTrack(0, i - 1)
        if settings.tcp then
            reaper.SetMediaTrackInfo_Value(tr, "B_SHOWINTCP", tracks[i] and 1 or 0)
        end
        if settings.mcp then
            reaper.SetMediaTrackInfo_Value(tr, "B_SHOWINMIXER", tracks[i] and 1 or 0)
        end

    end

    if settings.mcp then
      select_first_visible_MCP()
    end

    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Show only specified tracks", -1)

    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()

end




------------------------------------
-------- Standalone startup --------
------------------------------------


if script_filename ~= "Lokasenna_Show only specified tracks.lua" then

    local tracks = settings and get_tracks_to_show(settings)
    if tracks then
        set_visibility( tracks, settings )
    else
        reaper.MB(
          "Error reading the script's settings. Make sure you haven't edited the script or changed its filename.", "Whoops!", 0)
    end

    return

end


