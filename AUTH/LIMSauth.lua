-- =============================================================================
-- LIMSauth.lua
-- Author: Conor Steward/Stephen Piccone
-- Date: 07/17/25
--
-- Purpose:
--   Provides OAuth2 client credentials flow for authenticating with
--   Castle Biosciences' LIMS system. Retrieves an access token and
--   stores it in encrypted format using the LIMSencrypt module.
--
--   This function:
--     - Performs a POST request to the LIMS OAuth2 token endpoint.
--     - Authenticates using Basic Auth with ClientId/ClientSecret.
--     - Requests a token with specified scope.
--     - Caches the token with an expiry time using local encryption.
--
-- Dependencies:
--   - LIMSencrypt.lua: Handles encrypted storage of the token.
--   - Iguana config fields must include:
--       * TokenUrl
--       * ClientId
--       * clientSecret
--       * Scope
--
-- Returns:
--   - OAuth2 access token (string) if request is successful.
--   - nil if request fails or returns non-200 response.
-- =============================================================================

-- Require module for encrypted token saving
require "LIMS.auth.LIMSencrypt"

-- =============================================================================
-- Function: LIMSauth
-- Purpose: Authenticate using OAuth2 and return access token
-- Input:
--   S (table) - Config table containing token_url, client_id, client_secret, scope
-- Returns:
--   string - OAuth2 access token if successful, otherwise nil
-- =============================================================================
local function LIMSauth(S)
   -- OAuth2 token endpoint
   local TokenUrl = S.token_url

   -- Basic Auth header with base64-encoded client credentials
   local Headers = {
      ["Content-Type"] = 'application/x-www-form-urlencoded'
   }

   -- Form bodys for client credentials flow
   local Body = string.format("grant_type=client_credentials&scope=%s&client_id=%s&client_secret=%s", tostring(S.scope), tostring(S.client_id), tostring(S.client_secret))

   -- Perform POST request to obtain token
   local Response, Code, H = net.http.post{
      url = TokenUrl,
      headers = Headers,
      body = Body
   }

   -- If successful (HTTP 200), parse and store the token
   if Code == 200 then
      local Auth = json.parse{data=Response}
      local TokenDetails  = {}
      TokenDetails.token  = Auth.access_token
      TokenDetails.expiry = os.time() + Auth.expires_in
      S.Key               = TokenDetails.token
      S.KeyExpiry        = TokenDetails.expiry

      -- Save token using encrypted storage
      LIMSencrypt.save{
         config   = component.id()..'.xml',
         key      = 'oaibdsfpbreundansp21342sdfp4',
         password = json.serialize{data=TokenDetails}
      }

      return Auth.access_token
   else
      Response = Response or ''
      Code = Code or ''
      local Msg = 'Unable to authenticate. Verify authentication endpoint and credentials.\nCode: %s\nError:\n%s'
      Msg = string.format(Msg,Code,Response)
      error(Msg,3)
   end
end

-- Export the function as module return
return LIMSauth