-- =============================================================================
-- LIMSclient.lua
-- Author: Stephen Piccone
-- Date: 07/17/25
--
-- Purpose:
--   Factory module for creating a configured LIMS API client object. 
--   The returned object provides access to various LIMS integration 
--   methods such as sending mapped records, uploading attachments, and 
--   authenticating to retrieve access tokens.
--
--   Upon instantiation, this module:
--     - Accepts credentials and connection config from input table `T`
--     - Loads previously cached encrypted token (if available)
--     - Binds related method modules to the returned object using metatable
--
-- Dependencies:
--   - LIMSencrypt.lua: Loads encrypted OAuth token + expiry (if cached)
--   - LIMSauth.lua: Handles token retrieval via client_credentials
--   - LIMScustom.lua: Custom utility methods for LIMS interactions
--   - LIMSsendTable.lua: Responsible for POSTing mapped records
--   - LIMScreateAttachmentRecord.lua: Creates attachment entry in LIMS
--   - LIMSuploadAttachmentFile.lua: Uploads actual PDF or binary file
--
-- =============================================================================

-- Load module for reading encrypted tokens
require "LIMS.auth.LIMSencrypt"

-- Metatable definition for LIMS client
local MT = {}

-- Associate method modules with the metatable's __index table
MT.__index = {}
MT.__index.auth                   = require 'LIMS.auth.LIMSauth'
MT.__index.custom                 = require "LIMS.LIMScustom"
MT.__index.sendTable              = require "LIMS.methods.LIMSsendTable"
MT.__index.createAttachmentRecord = require "LIMS.methods.LIMScreateAttachmentRecord"
MT.__index.uploadAttachmentFile   = require "LIMS.methods.LIMSuploadAttachmentFile"
MT.__index.downloadAttachmentFile = require "LIMS.methods.LIMSdownloadAttachmentFile"

-- Register module help mapping (if using Iguana's help system)
help.map{dir='LIMS/help', methods=MT.__index}

-- =============================================================================
-- Function: LIMSclient
-- Purpose: Constructs and returns a new LIMS client object with config/state
-- Input:
--   T (table) - Required input fields:
--     ClientId, ClientSecret, TokenUrl, LimsBaseUrl, Scope, AppGuid
--     Optional: Timeout, RetryMax, RetryPause
-- Returns :
--   LIMS client object with attached methods and configuration
-- =============================================================================
function LIMSclient(T)
   local S = {}
   setmetatable(S, MT)

   -- Set required API connection fields
   S.client_id     = T.ClientId
   S.client_secret = T.ClientSecret
   S.token_url     = T.TokenUrl
   S.base_url      = T.LimsBaseUrl
   S.scope         = T.Scope
   S.app_guid      = T.AppGuid

   -- Optional retry + timeout configuration
   S.timeout       = T.Timeout or 10
   S.retry_max     = T.RetryMax or 15
   S.retry_pause   = T.RetryPause or 5

   -- Load previously cached encrypted token (if present)
   local EncryptedDetails = LIMSencrypt.load{
      config = component.id()..'.xml',
      Key    = 'oaibdsfpbreundansp21342sdfp4'
   }

   if EncryptedDetails ~= 'No password file saved' then
      local KeyDetails  = json.parse{data=EncryptedDetails}
      S.Key             = KeyDetails.token
      S.KeyExpiry      = KeyDetails.expiry
   end

   return S
end