-- Generated from src/load-failures.luau and src/public-entry-body.luau.
local Failures=(function()
-- Startup failures only. No global error listener, gameplay logs or success pings.
local Failures={}
function Failures.detail(value,player)
 local text=tostring(value):match('[^\r\n]+') or ''
 if player then
  for _,name in ipairs({player.Name or '',player.DisplayName or ''}) do
   if #name>=3 then text=text:gsub(name:gsub('(%W)','%%%1'),'[player]') end
  end
 end
 text=text:gsub('https?://%S+','[url]'):gsub('[%a]:[\\/][^:]*','[path]')
 text=text:gsub('[%w_.+%-]+@[%w_.%-]+','[email]')
 text=text:gsub('github_pat_[%w_]+','[credential]'):gsub('gh[pousr]_[%w_]+','[credential]')
 text=text:gsub('[%w_%-]+',function(word) return #word>=40 and '[token]' or word end)
 text=text:gsub('[^ -~]','?')
 return text:sub(1,384)
end
local messages={missing_api='A required function is unavailable.',http='A download request failed.',
 timeout='No startup confirmation within 90 seconds.',compile='Downloaded code could not compile.',
 integrity='Downloaded code failed its integrity check.',menu='The expected menu was not created.',
 runtime='Startup code raised an error.'}
function Failures.new(api,phase,module)
 local placeId,placeVersion=api.placeId or game.PlaceId,api.placeVersion or game.PlaceVersion
 local context={stage='bootstrap',functionName='SlopHub.entry',phase=phase,module=module or '',done=false,version=api.releaseVersion}
 function context:set(stage,name) if self.done then return end;self.stage=stage;self.functionName=name or self.functionName end
 function context:compile(source,name)
  self.compileUnit=name;self.compileBytes=#source
  local _,lines=source:gsub('\n','');self.compileLines=lines+1
  local ok,chunk,message=pcall(loadstring,source,name)
  if not ok then return nil,tostring(chunk) end
  return chunk,message
 end
 function context:success() self.done=true end
 function context:cancel() self.done=true end
 function context:fail(err,code)
  if self.done then return end;self.done=true
  local stage,functionName,releaseVersion,phase,module=self.stage,self.functionName,self.version,self.phase,self.module
  -- Classify locally; Only the first sanitized exception line is reported; no stack or source body.
  local raw=tostring(err);local lower=raw:lower();local class='runtime'
  local missing=raw:match('%[SlopHubAPI:([%w_%.]+)%]')
  local knownAPIs={setthreadidentity=true,hookfunction=true,newcclosure=true,hookmetamethod=true,getnamecallmethod=true,getrawmetatable=true,getconnections=true,getgc=true,
   ['debug.getupvalue']=true,['debug.setupvalue']=true,['debug.info']=true}
  if missing and knownAPIs[missing] then functionName=missing end
  if code=='STARTUP_TIMEOUT' then class='timeout'
  elseif code=='MENU_NOT_CREATED' or lower:find('menu not created',1,true) then class='menu'
  elseif lower:find('nil value',1,true) or lower:find('missing method',1,true) or lower:find('requires ',1,true) then class='missing_api'
  elseif self.stage:find('compile',1,true) then class='compile'
  elseif self.stage:find('integrity',1,true) or lower:find('hash self-test',1,true) then class='integrity'
  elseif self.stage:find('download',1,true) then class='http' end
  local line=tonumber(raw:match('SlopHub[^\n]-:(%d+):')) or 0
  line=math.clamp(line,0,1000000)
  local function emit()
   if api.env and api.env.SlopHubDisableStats==true then return end
   local player=game:GetService('Players').LocalPlayer
   local userId=api.userId or (player and player.UserId)
   for _,id in ipairs(api.excludedUserIds or {11902139381}) do if userId==id then return end end
   local send=api.statsRequest or request or http_request
   if type(send)~='function' then return end
   local http=game:GetService('HttpService')
   local name,version='Unknown',''
   local identify=api.identifyExecutor or identifyexecutor
   if type(identify)=='function' then
    local ok,n,v=pcall(identify)
    if ok and type(n)=='string' then name=n;version=type(v)=='string' and v or '' end
   end
   local clean=function(value) return (value:gsub('[^%w ._+%-%(%)]',''):sub(1,64)) end
   name=clean(name);if name=='' then name='Unknown' end
   local event={id=http:GenerateGUID(false),kind='load_failure',version=releaseVersion or '0.6.10',
    place=placeId,build=placeVersion,
    executor=name,executorVersion=clean(version),phase=phase,module=module,
    stage=stage,code=code or 'STARTUP_ERROR',errorClass=class,message=messages[class],
    functionName=functionName,line=line,errorDetail=Failures.detail(raw,player),
    compileUnit=self.compileUnit or '',compileBytes=self.compileBytes or 0,compileLines=self.compileLines or 0}
   local body=http:JSONEncode(event)
   for attempt=1,2 do
    local ok,response=pcall(send,{Url=api.failureEndpoint or 'https://slophub-execution-tracker.slophub-execution-tracker.workers.dev/failures',Method='POST',Headers={['Content-Type']='application/json'},Body=body})
    local status=ok and type(response)=='table' and tonumber(response.StatusCode)
    if status and status>=200 and status<300 then return end
    if attempt==1 and task and task.wait then task.wait(1) end
   end
  end
  local function safeEmit() pcall(emit) end
  if task and type(task.spawn)=='function' then task.spawn(safeEmit) else safeEmit() end
 end
 if task and type(task.delay)=='function' then
  task.delay(90,function() if not context.done then context:fail('Startup timeout','STARTUP_TIMEOUT') end end)
 end
 return context
end
return Failures

end)()
-- GitHub HTTPS is the release trust anchor. Generated wrapper has no crypto dependency for reporting.
local env={};if type(getgenv)=='function' then local ok,e=pcall(getgenv);if ok and type(e)=='table' then env=e end end
local startup=Failures.new({env=env,releaseVersion="0.6.15"},'launcher')
-- HttpGet's optional boolean is not portable across executor bridges. Use its
-- raw/default form, then a standard request response if the bridge fails.
local function fetchRelease(url,limit)
 local send
 if type(request)=='function' then send=request
 elseif type(http_request)=='function' then send=http_request
 elseif type(http)=='table' and type(http.request)=='function' then send=http.request
 elseif type(syn)=='table' and type(syn.request)=='function' then send=syn.request end
 local plain=url:match('^[^?]+')
 local last='no usable response'
 for attempt=1,2 do
  local target=attempt==1 and url or plain
  local ok,body=pcall(function() return game:HttpGet(target) end)
  if ok and type(body)=='string' and #body>0 and #body<=limit then return body end
  last=ok and ('HttpGet returned '..type(body)..' or an invalid body size') or 'HttpGet failed'
  if send then
   local sent,response=pcall(send,{Url=target,Method='GET',Headers={['Cache-Control']='no-cache',['Pragma']='no-cache'}})
   local status=sent and type(response)=='table' and tonumber(response.StatusCode or response.Status)
   if status and status>=200 and status<300 and response.Success~=false and type(response.Body)=='string' and #response.Body>0 and #response.Body<=limit then return response.Body end
   last=status and ('request HTTP '..tostring(status)) or 'request failed or returned an invalid response'
  end
  if attempt==1 and task and type(task.wait)=='function' then task.wait(.25) end
 end
 error('SlopHub: release download failed ('..last..')',0)
end
local ok,result=xpcall(function()
 local base='https://raw.githubusercontent.com/ZaneTuffTwin/SlopHub-Loader/main'
 local http=game:GetService('HttpService')
 startup:set('bootstrap','loadstring')
 local compile=loadstring;local hash=crypt and crypt.hash
 assert(type(compile)=='function','SlopHub: executor requires loadstring')
 startup:set('bootstrap','crypt.hash')
 assert(type(hash)=='function','SlopHub: executor requires crypt.hash')
 assert(hash('abc','sha256'):lower()=='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad','SlopHub: hash self-test failed')
 startup:set('metadata_download','api.fetch')
 local metadata=fetchRelease(base..'/release.json?v='..tostring(os.time()),4096)
 assert(type(metadata)=='string' and #metadata<=4096,'SlopHub: invalid release metadata size')
 startup:set('metadata_decode','HttpService.JSONDecode')
 local release=http:JSONDecode(metadata)
 assert(type(release)=='table' and release.schema==2,'SlopHub: invalid release schema')
 for key in pairs(release) do assert(key=='schema' or key=='version' or key=='sha256' or key=='bytes','SlopHub: unexpected release field') end
 assert(type(release.version)=='string' and release.version:match('^%d+%.%d+%.%d+$') and #release.version<=15,'SlopHub: invalid release version')
 assert(type(release.sha256)=='string' and #release.sha256==64 and release.sha256:match('^[0-9a-f]+$'),'SlopHub: invalid release digest')
 assert(type(release.bytes)=='number' and release.bytes%1==0 and release.bytes>0 and release.bytes<=8000000,'SlopHub: invalid release size')
 startup.version=release.version
 startup:set('payload_download','api.fetch')
 local source=fetchRelease(base..'/releases/'..release.sha256..'.luau',release.bytes)
 startup:set('payload_integrity','crypt.hash')
 assert(type(source)=='string' and #source==release.bytes and hash(source,'sha256'):lower()==release.sha256,'SlopHub: release integrity check failed')
 assert(loadstring==compile and crypt.hash==hash,'SlopHub: loader APIs changed during download')
 startup:set('payload_compile','loadstring')
 local chunk,message=startup:compile(source,'SlopHub/Package');assert(chunk,message)
 startup:set('payload_start','SlopHub.payload')
 local launched=chunk(startup)
 assert(type(launched)=='table' and launched.gui and launched.alive,'SlopHub: launcher menu not created')
 return launched
end,function(err) return tostring(err) end)
if not ok then startup:fail(result);error(result,0) end
return result
