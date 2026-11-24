-- SlopHub
local b="https://raw.githubusercontent.com/ZaneTuffTwin/SlopHub-Loader/main"
local h=game:GetService("HttpService")
local r=h:JSONDecode(game:HttpGet(b.."/release.json?v="..tostring(os.time()),false))
assert(type(r.sha256)=="string" and #r.sha256==64 and r.sha256:match("^[0-9a-f]+$"),"SlopHub: invalid release")
local s=game:HttpGet(b.."/releases/"..r.sha256..".luau",false)
assert(#s==r.bytes and crypt.hash(s,"sha256")==r.sha256,"SlopHub: incomplete download")
local f,e=loadstring(s,"SlopHub");assert(f,e);return f()
