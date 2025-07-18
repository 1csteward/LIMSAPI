-- =============================================================================
-- LIMSsendTable.lua
-- Author: Conor Steward/Stephen Piccone
-- Date: 07/17/25
--
-- Purpose:
--   Sends a mapped LIMS record to the appropriate table endpoint via API.
--   This function handles automatic table name extraction and builds the
--   correct URI to send POST requests to the `/datarecordlist/fields/{table}` endpoint.
--
--   This module:
--     - Extracts base table name from `T.table_name` (e.g., removes any suffix after colon)
--     - Constructs the correct API URL for posting data
--     - Applies standard JSON headers
--     - Delegates the request to the LIMSclient:custom method
--
-- Input (T):
--   - T.table_name : String with table name (may include colon suffix)
--   - T.record     : Record payload (table or array)
--   - T.live       : Boolean flag for live/test mode
--
-- Returns:
--   - Result of S:custom() (true/false, response table or string, HTTP code)
-- =============================================================================

local function LIMSsendTable(S,T)
   -- Extract base table name if colon-delimited (e.g., "eRequest:Details" → "eRequest")
   local BaseTableName = T.table_name:match("^(.-):") or T.table_name

   -- Construct API path for posting records to the correct table
   local Api = 'datarecordlist/fields/'..BaseTableName

   -- Set required HTTP headers for JSON format
   local Headers = {}
   Headers["Content-Type"] = "application/json"
   Headers["Accept"] = "application/json"

   -- Submit the record via LIMSclient's general-purpose POST method
   return S:custom{method='post',api=Api,parameters=T.record,headers=Headers,live=T.live}
end

return LIMSsendTable