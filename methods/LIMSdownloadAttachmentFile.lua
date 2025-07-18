-- =============================================================================
-- LIMSdownloadAttachmentFile.lua
-- Author: Conor Steward/Stephen Piccone
-- Date: 07/18/25
--
-- Purpose:
--   Downloads the raw binary content of an Attachment file from Castle
--   Biosciences’ LIMS system using the record ID of an existing Attachment.
--   This function builds the proper endpoint URL for the file and invokes
--   the `custom()` method from the LIMS client to issue an authenticated
--   GET request. The file content is returned in raw form (e.g., PDF bytes).
--
--   This module:
--     - Accepts the Attachment recordId and optional `live` mode
--     - Constructs the correct `/datarecord/attachment/Attachment/{recordId}` path
--     - Sends a GET request with appropriate headers
--
-- Input (T):
--   - T.record_id: String, unique Attachment recordId to fetch content from
--   - T.live: Boolean, true for live mode or false/test (optional)
--
-- Returns:
--   - true/false: Whether the request succeeded
--   - response: File byte content (string) if success, or error message if failure
--   - HTTP code: Numeric HTTP status code from the server
--
-- Dependencies:
--   - Requires the caller to pass a configured LIMS client object (S)
--   - Requires the LIMS client to be authenticated with a valid Bearer token
--
-- =============================================================================

local function LIMSdownloadAttachmentFile(S, T)
   -- Construct the endpoint path for the Attachment file
   local Api = '/datarecord/attachment/Attachment/' .. T.record_id

   -- Define headers required for the file download
   local Headers = {}
   Headers["Content-Type"] = "application/octet-stream"
   Headers["AppGuid"] = S.app_guid

   -- Issue the GET request using the LIMS client
   return S:custom{
      method  = 'get',
      api     = Api,
      headers = Headers,
      live    = T.live
   }
end

-- Export the function for external use
return LIMSdownloadAttachmentFile