-- =============================================================================
-- LIMScustom.lua
-- Author: Stephen Piccone
-- Date: 07/17/25
--
-- Purpose:
--   Provides a general-purpose HTTP API utility for interacting with
--   Castle Biosciences’ LIMS system. Supports GET and POST methods,
--   handles OAuth2 bearer token injection, retries failed requests,
--   and parses responses safely.
--
--   This module:
--     - Dynamically loads inputs depending on the HTTP method
--     - Automatically refreshes the token if missing or expired
--     - Makes resilient HTTP requests using LIMSretry
--     - Handles edge cases such as empty or malformed responses
--
-- Dependencies:
--   - LIMSretry.lua : Retry utility that wraps net.http calls with backoff
--
-- Returns:
--   LIMScustom (function) - Callable API executor
-- =============================================================================

local LIMSretry = require "LIMS.retry.LIMSretry"

-- =============================================================================
-- Function: LIMSloadParameters
-- Purpose : Set parameters or body in the HTTP request based on method
-- Input   : 
--   T.method     - 'get' or 'post'
--   T.inputs     - Table to be populated with .parameters or .body
--   T.params     - Parameters to apply
-- Behavior:
--   - For GET: sets .parameters
--   - For POST: serializes params into a JSON .body
-- =============================================================================
local function LIMSloadParameters(T)
   -- Customize method-specific inputs
   if T.method == 'get' then
      T.inputs.parameters = T.params
   elseif T.method == 'post' then
      T.inputs.body = json.serialize{data={T.params}}
   end   
end

-- =============================================================================
-- Function: LIMSparseResponse
-- Purpose: Parse JSON response and determine success/failure
-- Input: 
--   R     - Raw response string
--   Code  - HTTP status code
-- Output:
--   success (bool), parsed JSON (table or string), HTTP code
-- Behavior:
--   - Attempts to parse JSON if not in error list
--   - If status is in known error codes or parsing fails, returns false
-- =============================================================================
local function LIMSparseResponse(R,Code)
   local ErrorResponseCodes = {
      ['400'] = true,
      ['401'] = true,
      ['404'] = true,
      ['422'] = true,
      ['500'] = true,
      ['503'] = true
   }
   local Status, ParsedR = pcall(json.parse,{data=R})
   if not Status then 
      if R:find('PDF') and Code == 200 then
         return true,R,Code
      else
         return false,R,Code 
      end
   end
   if ErrorResponseCodes[tostring(Code)] then return false,ParsedR,Code end
   return true,ParsedR,Code
end

-- =============================================================================
-- Function: LIMScustom
-- Purpose: General-purpose HTTP caller to the LIMS API
-- Input: 
--   S - LIMS client object (with token, base_url, retry config)
--   T - Table containing:
--         * method      = 'get' or 'post'
--         * api         = endpoint path (e.g., '/patient')
--         * parameters  = request parameters/body
--         * headers     = additional headers
--         * live        = boolean, indicates if it's a live call
-- Output:
--   - true/false
--   - response content or parsed JSON
--   - HTTP status code
-- Behavior:
--   - Authenticates if no token or expired
--   - Builds HTTP input dynamically
--   - Calls LIMS API via retry wrapper
--   - Handles empty or malformed responses gracefully
-- =============================================================================
function LIMScustom(S,T)
   -- Check if OAuth token is saved, and not expired.
   if S.Key == nil or tonumber(S.KeyExpiry) < os.time() then
      iguana.logInfo('OAuth token is expired or does not exist. Fetching token.')
      S:auth()
      iguana.logInfo('OAuth token fetched successfully.')
   end

   -- Load HTTP inputs
   local Method = (T.method or 'post'):lower()
   local HttpInput = {}
   HttpInput.url = S.base_url..T.api
   HttpInput.headers = T.headers or {}
   HttpInput.headers.Authorization = 'Bearer ' .. S.Key
   HttpInput.live = T.live
   HttpInput.timeout = S.timeout
   LIMSloadParameters{method = Method, inputs = HttpInput, params = T.parameters}
   trace(HttpInput)

   -- make HTTP call to LIMS
   local R, Code = LIMSretry{func=net.http[Method],arg1=HttpInput,retry=S.retry_max,pause=S.retry_pause}
   trace(Code,R)

   -- Handle empty responses   
   if R == '' then
      if (T.live ~= true and iguana.isTest()) then
         return "notlive"
      elseif (Code == 201) or (Code == 204) then 
         return true, _,Code 
      else
         return false, _,Code
      end
   end

   -- Parse and handle non-empty responses
   return LIMSparseResponse(R, Code)
end

return LIMScustom