-- =============================================================================
-- retry.lua
-- Author: iNTERFACEWARE Inc.
-- Date: 07/17/25
--
-- Purpose:
--   Generic retry handler for retrying a function call multiple times
--   with a configurable delay between attempts.
--
--   Commonly used in integrations that interact with unstable endpoints,
--   such as HTTP APIs or network services that may fail intermittently.
--
--   This module:
--     - Supports configurable retry count and pause duration
--     - Accepts variadic arguments using arg1, arg2, ..., argN
--     - Provides hooks for custom error evaluation
--     - Logs retry events and updates Iguana status lights/messages
--     - Returns early if successful; throws an error after max retries
--
-- See:
--   https://interfaceware.atlassian.net/wiki/spaces/IXB/pages/2713911370/Retry+Library
--
-- License:
--   Copyright (c) 2011–2023 iNTERFACEWARE Inc. ALL RIGHTS RESERVED.
--   Permitted for use under the iNTERFACEWARE license agreement.
-- =============================================================================

-- customize the (generic) error messages used by retry() if desired
local RETRIES_FAILED_MESSAGE = 'Retries completed - was unable to recover from connection error.'
local FATAL_ERROR_MESSAGE    = 'Stopping channel - fatal error, function returned false. Function name: '
local RECOVERED_MESSAGE      = 'Recovered from error, connection is now working. Function name: '

-- =============================================================================
-- Function: sleep
-- Purpose : Pause execution (in seconds), only when not in test mode
-- Input   : S (number) - seconds to sleep
-- =============================================================================
local function sleep(S)
   if not iguana.isTest() then
      util.sleep(S*1000)
   end
end

-- =============================================================================
-- Function: checkParam
-- Purpose: Validate retry() input table, allow argN dynamic keys
-- Input:
--   T     - Table of parameters
--   List  - Table of allowed keys
--   Usage - Usage string for error display (unused here)
-- =============================================================================
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

-- =============================================================================
-- Function: getArgs
-- Purpose: Extract sequential function arguments from keys arg1, arg2, ...
-- Input: P - parameter table
-- Returns: args (array) - values in numeric order
-- =============================================================================
local function getArgs(P)
   local args = {}
   for k,v in pairs(P) do
      if k:find('arg')==1 then
         args[tonumber(k:sub(4))] = P[k]
      end
   end
   return args
end

-- =============================================================================
-- Function: LIMSretry
-- Purpose: Executes a function with retry logic
-- Input: 
--   P.func      - Function to execute
--   P.argN      - Arguments to pass to the function
--   P.retry     - Number of retry attempts (default: 100)
--   P.pause     - Delay between retries (default: 10 seconds)
--   P.funcname  - Optional label for logging
--   P.errorfunc - Optional function to determine success from result
-- Returns : Result of P.func or throws an error on failure
-- =============================================================================
function LIMSretry(P)
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

return retry