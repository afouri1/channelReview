
--[[ 
]]

local socket = require "socket"
local LuaLog,dump           = setLocLuaLog(1, "GLoginLayerMediator", dump)
local LobbyNetworkCmd       = s_LuaRequire("LobbyNetworkCmd")
local DeviceUtil            = s_LuaRequire("DeviceUtil")
local GameSocketEvent       = s_LuaRequire("GameSocketEvent")
local GLoginLayerViewTest = s_LuaRequire("GLoginLayerViewTest")
local UUpdate           = require("GUpdate.UUpdate")

local GLoginLayerMediator   = classpb(TYGameNode)

local bid = 0 

local LoginLayerHttpType = {
    REGIST = 1 ,
    LOGIN = 2,
    ZQBCHANNEL_LOGIN = 3 , 
}
    
function GLoginLayerMediator:ctor(...)

	self:cAddChild( nil  )

    self.uid    = cc.UserDefault:getInstance():getStringForKey("user_id" , "")
    self.guid   = cc.UserDefault:getInstance():getStringForKey("game_id" , "")

    self:tyRegistNotification( handler(self, self.onEvent_connectSuccess), GameSocketEvent.ID_SOCKET_CONNECT_SERVER_SUCCESS )
    -- if self.uid ~= "" and self.guid ~= "" then
    --     self.isAutoLogin = true
    -- end

    -- dump( self:getVersion()  ,"version_info:" )

    -- print("----------------------GLoginLayerMediator_ctor__________")
    -- s_TiFunction.saveErrorInfo("traceback")

    
    s_SceneRoot:setZQPlatDate(nil)

end 
		
function GLoginLayerMediator:dealloc(...)
    print("GLoginLayerMediator_____dealloc")
    s_IsWxGetCode = false
end

function GLoginLayerMediator:getVersion()       -- 获取版本号
    return UUpdate.new({isGetVersion=true}):getVersionByGameid()   -- { version =  , date =  ,clientVersion= }
end 

function GLoginLayerMediator:isHaveAcc( ... )
    local ishava = false
    if self.uid ~= "" and self.guid ~= "" then
        ishava = true
    end
    print("---------------GLoginLayerMediator:isHaveAcc:" , self.uid , self.guid , ishava)
    return ishava
end

function GLoginLayerMediator:onRegister(args)

    if s_isUseYouKe then

        self._viewComponent:initVisitors()

        if not self:isHaveAcc() then
            local loginTest = GLoginLayerViewTest.new()
            self:addChild(loginTest,99)
            loginTest:createPlayerAccout( function( )
                self._viewComponent:showVisitorBtn()
                local uid_gid_tab  = loginTest:getAcc()

                local ugTemp = string.split(uid_gid_tab[1], "-")
                local uid = ugTemp[1]
                local gid = ugTemp[2]
                

                self:saveSelfAcc( uid , gid )


            end , 1 )

        else
            self._viewComponent:showVisitorBtn()
        end
    end
end 


function GLoginLayerMediator:requestZqbChannelLogin( userid , sessionid , platform_id)
    userid = userid or 0
    sessionid = sessionid or 0
    platform_id = platform_id or 0

    self.platform_id = platform_id

    local configurl = TI_S_CONFIG.fastZqbChannelLoginUrl()

    print("GLoginLayerMediator##########requestZqbChannelLogin:" , userid , sessionid , platform_id , TI_S_CONFIG.fastZqbChannelLoginUrl())


    local url = string.format("%suserid=%s&sessionid=%s&platID=%s" , configurl , userid , sessionid , platform_id)

    -- local url = TI_S_CONFIG.fastZqbChannelLoginUrl() .. "userid=" .. userid .. "&sessionid=" .. sessionid .. "&platID=" .. platform_id

    print("fastZqbChannelLoginUrl:" , url)

    local request = network.createHTTPRequest(function(event)       
        self:onLoginLayerResponse(event, LoginLayerHttpType.ZQBCHANNEL_LOGIN)
    end, url, "GET")
    request:start()

end



--玩家注册
function GLoginLayerMediator:requestPlayerRegistered( code )
    code = code or ""
    local url = TI_S_CONFIG.playerRegisterUrl() .. "code=" .. code .. "&channel=" .. (channelId or 0) .. "&appid=" .. game_appid
    print("requestPlayerRegistered_url:" , url)

    local request = network.createHTTPRequest(function(event)       
        self:onLoginLayerResponse(event, LoginLayerHttpType.REGIST)
    end, url, "GET")
    request:start()

end


function GLoginLayerMediator:requestPlayerLogin( uid , guid )
    if not uid or uid == 0 or uid == "" then
        print("uid is invalid: " , uid)
        return
    end

    if not guid or guid == 0 or guid == "" then
        print("guid is invalid: " , guid)
        return
    end

    local url = TI_S_CONFIG.playerLoginUrl() .. "guid=" .. guid .. "&uid=" .. uid
    print("requestPlayerLogin_url:" , url)

    local request = network.createHTTPRequest(function(event)       
        self:onLoginLayerResponse(event, LoginLayerHttpType.LOGIN)
    end, url, "GET")
    request:start()

end


function GLoginLayerMediator:playerLoginProtoBuff( uid , guid )   -- 微信流程完成
    LuaLog("playerLoginProtoBuff:" ,uid ,  guid)
    if not uid or uid == 0 or uid == "" then
        print("uid is invalid: " , uid)
        return
    end

    if not guid or guid == 0 or guid == "" then
        print("guid is invalid: " , guid)
        return
    end
    print("playerLoginProtoBuff__:" , uid , guid)

    uid     = uid or self.uid
    guid    = guid or self.guid
    self:tryDo_Login( uid, guid )
end 

-- socket已连直接登录
function GLoginLayerMediator:tryDo_Login(uid, guid)
    if not self._viewComponent.yhxyState then 
        s_SceneRoot:showAlert({tips="请同意<<用户服务协议>>", dur=3.0})
        return nil 
    end 
    local loginArg = { device = uid or self.uid , token = guid or self.guid }
    s_MsgHandler:doLogin( loginArg  )
end 

function GLoginLayerMediator:onEvent_connectSuccess()
    
    if self._viewComponent.loadingBar then 
        self._viewComponent.loadingBar.__hbar:setPercentDur(100, 0.25, function()
            self._viewComponent:removeFakeLoadingBar()
        end )
    end 
end 

function GLoginLayerMediator:saveSelfAcc( uid , guid )
    print("-------:" , uid , guid)
    if not uid or uid == 0 or uid == "" then
        print("saveSelfAcc uid is invalid: " , uid)
        return
    end

    if not guid or guid == 0 or guid == "" then
        print("saveSelfAcc guid is invalid: " , guid)
        return
    end

    self.uid    = uid
    self.guid   = guid

    cc.UserDefault:getInstance():setStringForKey("user_id", uid)
    cc.UserDefault:getInstance():setStringForKey("game_id", guid)
    cc.UserDefault:getInstance():flush()

end


function GLoginLayerMediator:onLoginLayerResponse(event, req)
    local request = event.request
    if event.name == "completed" then
        local code = request:getResponseStatusCode()    
        local response = request:getResponseString()
        if code == 200 then
            local data = json.decode(response) 
            print("req:" , req)
            dump( data , "onLoginLayerResponsedata:")

            if not data then
                print("GLoginLayerMediator##########onLoginLayerResponse")
                return
            end
            if req == LoginLayerHttpType.REGIST then

                self:saveSelfAcc( data.uid , data.guid )
                --self:requestPlayerLogin( self.uid , self.guid )
                self:playerLoginProtoBuff( self.uid , self.guid )

            elseif req == LoginLayerHttpType.LOGIN then

                self:playerLoginProtoBuff( self.uid , self.guid )

            elseif req == LoginLayerHttpType.ZQBCHANNEL_LOGIN then

                self:saveSelfAcc( data.uid , data.guid )
                self:playerLoginProtoBuff( self.uid , self.guid )

                if data.data then
                    s_SceneRoot:setZQPlatDate( self.platform_id , data.data.account , data.data.session , data.data.accid , data.data.ext )
                end

            end
        else
            print("player regist faild code:" , code)
        end
    elseif event.name == "progress" then

    else
        --失败
        print("player regist faild getErrorCode:" , request:getErrorCode())
    end

end

function GLoginLayerMediator:btnVisitorLoginCallback( args )

    print("________btnVisitorLoginCallback:")

       
    -- self:onSelectAcc( { uid = "25921", gid = "e0f728b98f0ba76df443abde580d90cc" })
    self:playerLoginProtoBuff( self.uid , self.guid )

end

function  GLoginLayerMediator:btnWechatLoginCallback( args )

    local time =  socket.gettime()
    if self.lastTime and time - self.lastTime < 0.8 then
        -- print("-------------btnWechatLoginCallback:" , time - self.lastTime)
        return
    end

    self.lastTime = time

    print("________btnWechatLoginCallback:")

    if self:isHaveAcc() then
        self:playerLoginProtoBuff( self.uid , self.guid )
        return
    end

    if TI_DEBUG_TABLE.notUseNetwork then 
        s_SceneRoot:enterDntg()
        return
    end

    if S_isZQChannel then
            -- -- local argMsg = string.gsub(argMsg, "%%", "%%25")
            -- local argMsg  = [[zqbtest123|session_123_中文_/=%|10000"]]
            -- local retArr = LuaSplit(argMsg, "|")
            -- retArr[2] = string.urlencode(retArr[2])
            -- dump(retArr , "retArr:")
            -- self:requestZqbChannelLogin(retArr[1] , retArr[2] , retArr[3])

        DeviceUtil.zqbChannelLogin(function( argMsg )
            print("----------- zqbChannelLoginargMsg:" , argMsg)
            -- argMsg = string.gsub(argMsg, "%%", "%%25")
            local retArr = LuaSplit(argMsg, "|&|")
            print("________0:" , retArr[1] , retArr[2] , retArr[3])
            retArr[2] = string.urlencode(retArr[2])
            dump(retArr , "retArr:")
            print("________1:" , retArr[1] , retArr[2] , retArr[3])
            self:requestZqbChannelLogin(retArr[1] , retArr[2] , retArr[3])
        end)
        return
    end


    if device.platform == "windows" then
        -- self:playerLoginProtoBuff( "67200" , "94aa7b42a2be04f58228c5da1db5d2ea" )
       	-- self:playerLoginProtoBuff( "55780" , "a3bcb054d259e93701dcf1daec34d1e5" )
        -- self:playerLoginProtoBuff( "55864" , "46669e33c8fda963dc109273b5f4d1e8" )
        self:playerLoginProtoBuff( "69411" , "678faaed0f5afbe75b2679fb8765632a" )
    else
        s_IsWxGetCode = true
        DeviceUtil.getWeChatCode(function( code )
            print("btnWechatLoginCallback__code:" , code)
            self:requestPlayerRegistered( code )

            self:tyScheduleOnce(function()
                s_IsWxGetCode = false
            end , 0.6)
        end)
    end
end

function GLoginLayerMediator:onSelectAcc(args)
    dump(args , "GLoginLayerMediator:onSelectAcc:")
    -- s_MsgHandler:doLogin( { device = args.uid  , token = args.gid } )
    self:tryDo_Login( args.uid, args.gid )
end 


return GLoginLayerMediator
