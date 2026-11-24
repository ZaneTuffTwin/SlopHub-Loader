-- SlopHub permanent entry. GitHub HTTPS is the release trust anchor.
local base='https://raw.githubusercontent.com/ZaneTuffTwin/SlopHub-Loader/main'
local http=game:GetService('HttpService')
local compile=loadstring
local hash=crypt and crypt.hash
assert(type(compile)=='function' and type(hash)=='function','SlopHub: executor requires loadstring and crypt.hash')
assert(hash('abc','sha256'):lower()=='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad','SlopHub: hash self-test failed')
local metadata=game:HttpGet(base..'/release.json?v='..tostring(os.time()),false)
assert(type(metadata)=='string' and #metadata<=4096,'SlopHub: invalid release metadata size')
local release=http:JSONDecode(metadata)
assert(type(release)=='table' and release.schema==2,'SlopHub: invalid release schema')
for key in pairs(release) do
 assert(key=='schema' or key=='version' or key=='sha256' or key=='bytes','SlopHub: unexpected release field')
end
assert(type(release.version)=='string' and release.version:match('^%d+%.%d+%.%d+$') and #release.version<=15,'SlopHub: invalid release version')
assert(type(release.sha256)=='string' and #release.sha256==64 and release.sha256:match('^[0-9a-f]+$'),'SlopHub: invalid release digest')
assert(type(release.bytes)=='number' and release.bytes%1==0 and release.bytes>0 and release.bytes<=8000000,'SlopHub: invalid release size')
local source=game:HttpGet(base..'/releases/'..release.sha256..'.luau',false)
assert(type(source)=='string' and #source==release.bytes and hash(source,'sha256'):lower()==release.sha256,'SlopHub: release integrity check failed')
assert(loadstring==compile and crypt.hash==hash,'SlopHub: loader APIs changed during download')
local chunk,message=compile(source,'SlopHub')
assert(chunk,message)
return chunk()
