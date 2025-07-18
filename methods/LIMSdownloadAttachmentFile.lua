local function LIMSdownloadAttachmentFile(S,T)
   local Api = 'datarecord/attachment/Attachment/'..T.record_id
   local Headers = {}
   Headers["Content-Type"] = "application/octet-stream"
   Headers["AppGuid"] = S.app_guid
   return S:custom{method='get',api=Api,headers=Headers,live=T.live}
end
return LIMSdownloadAttachmentFile