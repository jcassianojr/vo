STRUCT _winNMTOOLBAR 
     MEMBER hdr IS _winNMHDR
     MEMBER iItem AS INT
     MEMBER tbButton IS _winTBBUTTON
     MEMBER cchText AS INT
     MEMBER pszText AS PSZ
 
DEFINE TBN_DROPDOWN  := (TBN_FIRST - 10)
 
 
RESOURCE  BARPADRAO_BMP   BITMAP  C:\TEMP\BARPADRAO.bmp
        //------------------------------
 
CLASS  BARPADRAO_BMP  INHERIT Bitmap
 
        //ToolBar Prg file (this file) = C:\TEMP\BARPADRAO.prg
        //CLASS Bitmap=BARPADRAO_BMP
 
METHOD Init(oParent) CLASS  BARPADRAO_BMP
 
        SUPER:Init(ResourceID{"BARPADRAO_BMP",_GetInst()},_Or(BMP_3DTRANSPARENT, BMP_2DTRANSPARENT)) 
 
        RETURN SELF
        //------------------------------
 
 
CLASS MyToolBar INHERIT ToolBar
 
METHOD Init(oParent) CLASS MyToolBar
 
 
          SUPER:Init(oParent)
 
 
        SELF:Flat:=TRUE
        SELF:SetStyle(TBSTYLE_WRAPABLE,FALSE)
        SELF:EnableBands(FALSE)
        SELF:ButtonSize:=Dimension{16,16}
        SELF:Bitmap:=BARPADRAO_BMP{}
        SELF:ButtonStyle := TB_ICONONLY
 
        RETURN SELF
        //------------------------------
 
