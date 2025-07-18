-- =============================================================================
-- LIMSuploadAttachmentFile.lua
-- Author: Conor Steward/Stephen Piccone
-- Date: 07/17/25
--
-- Purpose:
--   Uploads a binary PDF file to an existing Attachment record in the LIMS.
--   This function decodes the base64-encoded PDF string and posts it as
--   raw binary data to the correct LIMS API endpoint using octet-stream.
--
--   This module:
--     - Accepts the base64-encoded PDF, record ID, and file name
--     - Decodes the PDF into binary format
--     - Constructs the correct endpoint for uploading the file content
--     - Sets appropriate headers for binary file upload
--     - Uses the general-purpose `S:custom()` function to transmit the file
--
-- Input (T):
--   - T.attachment: Base64-encoded PDF content
--   - T.record_id: Record ID of the previously created Attachment
--   - T.file_name: File name (e.g., "results.pdf")
--   - T.live: Boolean flag for live/test execution
--
-- Returns:
--   - Result of S:custom() (true/false, response string or object, HTTP code)
-- =============================================================================

local function LIMSuploadAttachmentFile(S,T)
   -- Decode pdf into binary
   local PdfBinary = filter.base64.dec(T.attachment)

   -- Construct full endpoint using record ID and file name
   local Api = '/datarecord/attachment/Attachment/'..T.record_id..'/'..T.file_name

   -- Set headers for binary upload
   local Headers = {}
   Headers["Content-Type"] = "application/octet-stream"
   Headers["X-APP-KEY"] = S.app_guid

   -- Perform HTTP POST to upload PDF content
   return S:custom{method='post',api=Api,parameters=PdfBinary,headers=Headers,live=T.live}
end

return LIMSuploadAttachmentFile