-- =============================================================================
-- LIMSencrypt.lua
-- Author: Stephen Piccone
-- Date: 07/17/25
--
-- Purpose:
--   Utility module for securely storing sensitive values (e.g., API tokens,
--   credentials) in a config file outside of the Lua source code. This is
--   particularly useful when committing code to version control and needing
--   to keep secrets out of the repository.
--
--   This module:
--     - Encrypts values using AES with a salted SHA-512 derived key.
--     - Stores encrypted values and salt in a local XML file.
--     - Decrypts and loads stored values when needed.
--
-- References:
--   - AES Encryption: https://en.wikipedia.org/wiki/Advanced_Encryption_Standard
--   - Iguana Help: http://help.interfaceware.com/v6/encrypt-password-in-file
--
-- Exposed Functions:
--   - LIMSencrypt.save{config=..., key=..., password=...}
--   - LIMSencrypt.load{config=..., key=...}
--
-- =============================================================================

LIMSencrypt = {}

-- Default XML template used for encrypted config files
local XmlSaveFragment = [[
<config password='' salt=''/>
]]

-- =============================================================================
-- Function: LoadFile
-- Purpose: Read file content as string
-- Input: FileName (string) - Path to config file
-- Returns: File contents (string) or nil if not found
-- =============================================================================
local function LoadFile(FileName)
   local F = io.open(FileName, "r")
   if not F then
      return nil
   end
   local C = F:read("*a")
   F:close()
   return C
end

-- =============================================================================
-- Function: SaveFile
-- Purpose: Write string content to file
-- Input:
--   FileName (string) - Path to save file
--   Content  (string) - Content to write
-- =============================================================================
local function SaveFile(FileName, Content)
   local F = io.open(FileName, "w")
   F:write(Content)  
   F:close()
end

-- =============================================================================
-- Function: LIMSencrypt.load
-- Purpose: Decrypt and return the stored password/token
-- Input:
--   T.config (string) - Path to config file
--   T.key    (string) - Secret key used in encryption
-- Returns:
--   - Decrypted password/token (string)
--   - "No password file saved" (string) if config file not found
-- =============================================================================
function LIMSencrypt.load(T)
   local Config = T.config
   local Key = T.key

   local Data = LoadFile(Config)
   if not Data then
      return "No password file saved"
   end

   local X = xml.parse{data=Data}
   local Salt = X.config.salt:S()
   local TotalKey = filter.base64.enc(
      crypto.digest{data=Key .. Salt, algorithm='SHA512'}
   ):sub(1, 32)

   local Password = X.config.password:S()
   Password = filter.base64.dec(Password)
   Password = filter.aes.dec{data=Password, key=TotalKey}

   -- Remove padding null bytes from the end of the decrypted value
   for i = #Password, 1, -1 do
      if Password:byte(i) ~= 0 then
         Password = Password:sub(1, i)
         break
      end
   end

   return Password
end

-- XML comment prepended to all saved config files
local Comment = [[
<!-- This config file was saved with the config.load -->
]]

-- Redefine fragment in case of accidental override
local XmlSaveFragment = [[
<config password='' salt=''/>
]]

-- =============================================================================
-- Function: LIMSencrypt.save
-- Purpose: Encrypt and store a password/token in a local config file
-- Input:
--   T.config   (string) - File path for output config
--   T.password (string) - Value to encrypt and store
--   T.key      (string) - Secret used to derive encryption key
-- Behavior:
--   - Generates a random salt (GUID)
--   - Computes encryption key from key+salt (SHA-512 hashed, base64, first 32 chars)
--   - Encrypts and base64-encodes the password
--   - Saves salt and encrypted password in an XML config file
-- =============================================================================
function LIMSencrypt.save(T)
   local Config = T.config
   local Password = T.password
   local Key = T.key

   local Salt = util.generateGUID(128)
   local TotalKey = filter.base64.enc(
      crypto.digest{data=Key .. Salt, algorithm='SHA512'}
   ):sub(1, 32)

   local X = xml.parse{data=XmlSaveFragment}

   local EncryptedPassword = filter.aes.enc{data=Password, key=TotalKey}
   EncryptedPassword = filter.base64.enc(EncryptedPassword)

   X.config.salt = Salt
   X.config.password = EncryptedPassword

   local Content = Comment..X:S()
   SaveFile(Config, Content)
end

-- Maps module methods to help documentation if using `iguana.help`
help.map{dir='LIMS/help', methods=LIMSencrypt}

-- Export the module
return LIMSencrypt