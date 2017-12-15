local wamp = Proto("wamp", "WAMP")

local wampRaw = ProtoField.string("wamp.raw", "Raw")
local wampRealm = ProtoField.string("wamp.realm", "Realm")
local wampMessageType = ProtoField.string("wamp.message_type", "Type")
local wampRequestId = ProtoField.string("wamp.request_id", "Request ID")
local wampTopic = ProtoField.string("wamp.topic", "Topic")
local wampProcedureUri = ProtoField.string("wamp.procedure_uri", "Procedure URI")
local wampErrorUri = ProtoField.string("wamp.error_uri", "Error URI")
local wampErrorType = ProtoField.string("wamp.error_message_type", "Error Type")

local wampArguments = ProtoField.string("wamp.arguments", "Arguments")
local wampArgument = ProtoField.string("wamp.argument", "Argument")

wamp.fields = {
  wampRaw,
  wampRealm,
  wampMessageType,
  wampRequestId,
  wampTopic,
  wampProcedureUri,
  wampErrorUri,
  wampErrorType,
  wampArguments,
  wampArgument
}

json = require("dkjson")

local WAMP_MSG = {
    [1] = {
      name="HELLO",
      dissector=function (this,msg,subtree) 
        subtree:add(wampRealm, msg[2])
        return this.name .. " " .. msg[2]
      end
    },
    [2] = {name="WELCOME"},
    [3] = {name="ABORT"},
    [4] = {name="CHALLENGE"},
    [5] = {name="AUTHENTICATE"},
    [6] = {name="GOODBYE"},
    [8] = {
      name="ERROR",
      -- see below for the dissector because it references WAMP_MSG
    },
    [16] = {name="PUBLISH"},
    [17] = {name="PUBLISHED"},
    [32] = {
      name="SUBSCRIBE",
      dissector=function (this,msg,subtree)
        subtree:add(wampRequestId,tostring(msg[2]))
        subtree:add(wampTopic,msg[4])
        return this.name .. " " .. msg[4]
      end
    },
    [33] = {name="SUBSCRIBED"},
    [34] = {name="UNSUBSCRIBE"},
    [35] = {name="UNSUBSCRIBED"},
    [36] = {name="EVENT"},
    [48] = {
      name="CALL",
      dissector = function (this, msg, subtree)
        local progressiveInfo = ""
        subtree:add(wampProcedureUri,msg[4])
        if msg[3].receive_progress ~= nil and msg[3].receive_progress then
          progressiveInfo = " with progress"
        end
        
        if msg[5] ~= nil then -- args
          local args = subtree:add(wampArguments, json.encode(msg[5]))
          for i = 1, #msg[5] do
            args:add(wampArgument, json.encode(msg[5][i]))
          end

        end
        
        return this.name .. " " .. msg[4] .. progressiveInfo
      end
    },
    [49] = {name="CANCEL"},
    [50] = {name="RESULT"},
    [64] = {name="REGISTER"},
    [65] = {name="REGISTERED"},
    [66] = {name="UNREGISTER"},
    [67] = {name="UNREGISTERED"},
    [68] = {name="INVOCATION"},
    [69] = {name="INTERRUPT"},
    [70] = {name="YIELD"}
}

WAMP_MSG[8].dissector = function (this,msg,subtree)
  subtree:add(wampErrorUri,msg[5])
  subtree:add(wampErrorType,WAMP_MSG[msg[2]].name .. " (" .. msg[2] .. ")")
  return WAMP_MSG[msg[2]].name .. " " .. this.name .. " " .. msg[5]
end


function wamp.dissector(buf, pinfo, root)
  pinfo.cols.protocol = "WAMP"
  --pinfo.cols.info = buf:raw()
  
  msg = json.decode(buf:raw())
--  parse_ok, msg = pcall(json.decode, buf:raw())
--  print(msg)
--  if not parse_ok then
--    pinfo.cols.info = "INVALID JSON: " .. buf:raw()
--    return
--  end
  
  if msg[1] == nil then
    pinfo.cols.info = "INVALID PAYLOAD: " .. buf:raw()
    return
  end
  
  if WAMP_MSG[msg[1]] == nil then
    pinfo.cols.info = "UNKNOWN MESSAGE CODE " .. msg[1] .. ": " .. buf:raw()
    return
  end
  
  local subtree = root:add(wamp, buf(0))
  subtree:add(wampMessageType, WAMP_MSG[msg[1]].name .. " (" .. msg[1] .. ")")
  
  if WAMP_MSG[msg[1]].dissector ~= nil then
    pinfo.cols.info = WAMP_MSG[msg[1]]:dissector(msg, subtree)
    return
  end
  pinfo.cols.info = WAMP_MSG[msg[1]].name
  
end

DissectorTable.get("ws.protocol"):add("wamp.2.json", wamp)

debug("Starting WAMP dissector.")