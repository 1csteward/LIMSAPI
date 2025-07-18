-- =============================================================================
-- LIMScreateAttachmentRecord.lua
-- Author: Conor Steward/Stephen Piccone
-- Date: 07/17/25
--
-- Purpose:
--   Creates a new Attachment record in the LIMS database via API.
--   Typically used to associate a PDF or binary file with a parent
--   eRequest record. This function constructs the correct payload
--   for the `/datarecord/Attachment` endpoint.
--
--   This module:
--     - Accepts a parent_recordId and filename from input table T
--     - Builds the POST payload for the Attachment object
--     - Invokes the LIMSclient:custom() method to send the request
--
-- Input (T):
--   - T.parent_record : Table with one entry containing RecordId (eRequest)
--   - T.file_name     : String, name of the file to associate
--   - T.live          : Boolean, true for live mode or false/test
--
-- Returns:
--   - API response from LIMSclient:custom (true/false, response, code)
-- =============================================================================

local function LIMScreateAttachmentRecord(S,T)
   -- Construct the payload. RelatedRecord223 is the eRequest recordId
   local Payload = {}
   Payload[1] = {
      dataTypeName = "Attachment",
      fields = {RelatedRecord223 = T.parent_record[1].RecordId, FilePath = T.file_name}
   }

   -- Set required HTTP headers for JSON content
   local Headers = {}
   Headers["Content-Type"] = "application/json"
   Headers["Accept"] = "application/json"

   -- Call custom API handler to send POST request to /datarecord/Attachment
   return S:custom{method='post',api='/datarecord/Attachment',parameters=Payload,headers=Headers,live=T.live} 
end

return LIMScreateAttachmentRecord