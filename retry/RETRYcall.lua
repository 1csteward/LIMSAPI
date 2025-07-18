-- The retry module
-- Copyright (c) 2011-2023 iNTERFACEWARE Inc. ALL RIGHTS RESERVED
-- iNTERFACEWARE permits you to use, modify, and distribute this file in accordance
-- with the terms of the iNTERFACEWARE license agreement accompanying the software
-- in which it is used.
--

-- See https://interfaceware.atlassian.net/wiki/spaces/IXB/pages/2713911370/Retry+Library
 
-- customize the (generic) error messages used by retry() if desired
local RETRIES_FAILED_MESSAGE = 'Retries completed - was unable to recover from connection error.'
local FATAL_ERROR_MESSAGE    = 'Stopping channel - fatal error, function returned false. Function name: '
local RECOVERED_MESSAGE      = 'Recovered from error, connection is now working. Function name: '
 
  
local function sleep(S)
   if not iguana.isTest() then
      util.sleep(S*1000)
   end
end
 
-- hard-coded to allow "argN" params (e.g., arg1, arg2,...argN)
local function checkParam(T, List, Usage)
   if type(T) ~= 'table' then
      error(Usage,3)
   end
   for k,v in pairs(List) do
      for w,x in pairs(T) do
         if w:find('arg') then
            if w == 'arg' then error('Unknown parameter "'..w..'"', 3) end
         else
            if not List[w] then error('Unknown parameter "'..w..'"', 3) end
         end
      end
   end
end
 
-- hard-coded for "argN" params (e.g., arg1, arg2,...argN)
local function getArgs(P)
   local args = {}
   for k,v in pairs(P) do
      if k:find('arg')==1 then
         args[tonumber(k:sub(4))] = P[k]
      end
   end
   return args
end
 
-- This function will call with a retry sequence - default is 100 times with a pause of 10 seconds between retries
function RETRYcall(P)--F, A, RetryCount, Delay)
   checkParam(P, {func=0, retry=0, pause=0, funcname=0, errorfunc=0}, Usage)
   if type(P.func) ~= 'function' then
      error('The "func" argument is not a function type, or it is missing (nil).', 2)
   end 
   
   local RetryCount = P.retry or 100
   local Delay = P.pause or 10
   local Fname = P.funcname or 'not specified'
   local Func = P.func
   local ErrorFunc = P.errorfunc
   local Info = 'Will retry '..RetryCount..' times with pause of '..Delay..' seconds.'
   local Success, ErrMsgOrReturnCode
   local Args = getArgs(P)
   
   if iguana.isTest() then RetryCount = 2 end 
   for i =1, RetryCount do
      local R = {pcall(Func, unpack(Args))}
      Success = R[1]
      ErrMsgOrReturnCode = R[2]
      if ErrorFunc then
         Success = ErrorFunc(unpack(R))
      end
      if Success then      
         ui.setStatusLight{color='green'}         
         -- Function call did not throw an error 
         -- but we still have to check for function returning false         
         if ErrMsgOrReturnCode == false then
            error(FATAL_ERROR_MESSAGE..Fname..'()')
         end
         if (i > 1) then
            ui.setStatusMessage{data=RECOVERED_MESSAGE..Fname..'()'}            
            iguana.logInfo(RECOVERED_MESSAGE..Fname..'()')
         end         
         -- add Info message as the last of (potentially) multiple returns
         R[#R+1] = Info
         return unpack(R,2)
      else
         if iguana.isTest() then 
            -- TEST ONLY: add Info message as the last of (potentially) multiple returns
            R[#R+1] = Info
            return "SIMULATING RETRY: "..tostring(unpack(R,2)) -- test return "PRETENDING TO RETRY"
         else -- LIVE
            -- keep retrying if Success ~= true
            local E = 'Error executing operation. Retrying ('
            ..i..' of '..RetryCount..')...\n'..(tostring(ErrMsgOrReturnCode) or '')
            ui.setStatusMessage{data=E}
            ui.setStatusLight{color='yellow'}
            sleep(Delay)
            iguana.logInfo(E)
         end 
      end
      if component.isStopping() then
         error('Component is being forcefully stopped. Stopping retries.')         
      end
   end
   
   -- stop channel if retries are unsuccessful
   ui.setStatusMessage{data=RETRIES_FAILED_MESSAGE}
   error(RETRIES_FAILED_MESSAGE..' Function: '..Fname..'(). Stopping channel.\n'..tostring(ErrMsgOrReturnCode)) 
end 


return RETRYcall