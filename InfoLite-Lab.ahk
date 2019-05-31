#Include ILInjectRuby.ahk
#SingleInstance,Force


;Might want to migrate to a custom listview control composed of:
;     Verticle Scroll bar: https://maul-esel.github.io/FormsFramework/files/ScrollBar/ScrollBar-ahk.html
;       |- If not use Gui,Add,Custom,ClassSCROLLBAR (or something) - https://docs.microsoft.com/en-us/windows/desktop/Controls/scroll-bars
;     WM_VSCROLL: https://docs.microsoft.com/en-us/windows/desktop/controls/wm-vscroll
;     Gui,Add,Custom,ClassWindow (background) - https://docs.microsoft.com/en-us/windows/desktop/Controls/static-controls
;     GUI Add Picture - For icons
;     All controls to be within Window allowing position to go 'off window' while scrolling.
;Features to include:
;     Ctrl+Scroll --> Zoom
;     Events
;     Initialise from array of objects: [{:icon=>"file://filePath or data://A123J578DYHCSSNDUD... or http://...", data:[1,2,3]}]

; Create GUI window
Gui,+AlwaysOnTop +ToolWindow +Resize
Gui, Font, Lucida Console S16
Gui, Add, Edit, gSearch vSearchBar x15 y15 w200 h30
Gui, Add, Button, gRefreshLV vRefresh x210 y15 w30 h30, ⟳

;ListView style either "Report" or "Tile"
global lvStyle := "Tile" ;Suggest "Report" or "Tile"

;Add list view
Gui, Add, ListView, x15 y60 r10 w300 vMyListViewV gMyListView %lvStyle%, Name|Path  

;Helper to stop unnecessary redraw
global gui_is_shown := false

;Context menu for items
Menu, MyContextMenu, Add, Show in explorer, ShowInExplorer

;Fill list view with data:
RefreshListView()

;Show gui on side of screen
xStart := A_ScreenWidth-350
Gui,Show, x%xStart%, InfoLite Lab

;Hook keyboard:
WM_KEYUP := 0x101
OnMessage(WM_KEYUP,"OnKeyUp")

;Hide when ICM not active, show when active.
SetTimer, OnTimer
return

RefreshListView(search:=""){
  global lvStyle
  
  ;Get search term:
  if (search = "") {
    search := "*.rb"
  } else {
    search := "*" . search . "*.rb"
  }
  
  ;Remove all rose from LV
  LV_Delete()
  
  ;Initialise ImageList
  bool := lvStyle = "Tile"
  ilLarge := IL_Create(10,10,bool)
  IL_Add(ilLarge,A_ScriptDir "\scripts\_.png") ;default
  
  ; Gather a list of file names from a folder and put them into the ListView:
  Loop, %A_ScriptDir%\scripts\%search%
  {
    ;Add image and get iconID
    iconID := getRbImageID(ilLarge,A_LoopFileFullPath)
    
    ;Add item to list view
    LV_Add("icon" iconID, A_LoopFileName, A_LoopFileFullPath)
  }
  
  ;Set image list
  LV_SetImageList(ilLarge)
  
  ;Resize columns
  LV_ModifyCol(2, 0)
  LV_ModifyCol(1) ;AutoResize
}

getRbImageID(ImgList,path){
  global lvOldHandle
  global lvImageCount
  
  ;Track Image Count:
  if (!(lvOldHandle)) {
    lvImageCount := 1
    lvOldHandle := ImgList
  } else {
    if (lvOldHandle != ImgList) {
      lvImageCount := 1
      lvOldHandle := ImgList
    }
  }
  
  img := rbImageExists(path)
  if (img!="") {
    ;Load image into ImageList and Return ID
    IL_Add(ImgList,img)
    
    ;Return image position
    lvImageCount := lvImageCount + 1
    return lvImageCount
  } else {
    return 1
  }
}

rbImageExists(path){
  exts := ["GIF", "JPG", "BMP", "ICO", "CUR", "ANI", "PNG", "TIF", "Exif", "WMF", "EMF"]
  for k,ext in exts {
    if fileexist(path . "." . ext)
      return path . "." . ext
  }
  return ""
}

GuiContextMenu:
  Menu, MyContextMenu, Show, %A_GuiX%, %A_GuiY%
return

ShowInExplorer:
  Run %COMSPEC% /c explorer.exe /select`, "%EVENT_PATH%",, Hide
return

RefreshLV:
  if GetKeyState("LControl"){
    Reload
  } else {
    RefreshListView()
  }
return

ReloadApp:
  reload
return

Search:
  Gui,Submit,NoHide
  RefreshListView(SearchBar)
return

OnTimer:
  WinGetClass, klass, A
  if WinActive("ahk_exe InnovyzeWC.exe") or klass="AutoHotkeyGUI" {
    hwnd := WinExist("A")
    if !gui_is_shown {
      gui_is_shown:=true
      Gui,Show,, InfoLite Lab
      WinActivate, ahk_id %hwnd%
    }
  } else {
    if gui_is_shown {
      gui_is_shown:=false
      Gui,Hide
    }
  }
return

GUISize:
  RELOAD_Y := 15
  RELOAD_WIDTH := 30
  RELOAD_X := 300                        ;Assumption A_GuiWidth == 300
  
  GUIX := 0
  GUIY := 0
  GUIW := A_GuiWidth
  GUIH := A_GuiHeight
  BND  := 15
  
  RefreshY := BND
  RefreshW := 30
  RefreshX := GUIW - BND - RefreshW
  RefreshH := RefreshW
  
  SearchX := BND
  SearchY := BND
  SearchW := RefreshX - 2*BND
  SearchH := RefreshW
  
  LVX := BND
  LVY := SearchY + SearchH + BND
  LVW := GUIW - 2*BND
  LVH := GUIH - LVY - BND
  listH := LV_GetCount()*55.7
  lvext := ""
  if (listH < LVH) {
    GuiControl, +0x2000, MyListViewV
  } else {
    GuiControl, -0x2000, MyListViewV
  }
  
  
	width:=A_GuiWidth-30
	lv_height:=A_GuiHeight - 60 - 15
  ref_x := A_GuiWidth-15-30
  
  
  
  ;Position and size of search field
  GuiControl ,Move, SearchBar,   x%SearchX% y%SearchY% w%SearchW% h%SearchH%
  
  ;Position of refresh button
  GuiControl ,Move, Refresh,     x%RefreshX% y%RefreshY% w%RefreshW% h%RefreshH%
  
  ;Listview size
	GuiControl, Move, MyListViewV, x%LVX% y%LVY% w%LVW% h%LVH%
return
 

MyListView:
LV_GetText(EVENT_PATH, A_EventInfo,2)
if (A_GuiEvent = "DoubleClick") {
  ;Execute single selected:
  LV_GetText(pth, A_EventInfo,2)
  errors := RubyFileExec(ICMGetPID(),pth)
  if errors
    msgbox, % errors.message
}
return

OnKeyUp(wParam,lParam){
  if (wParam = 13) {
    GuiControlGet,ctrl,Focus
    if (ctrl = "SysListView321") {
      If (LV_GetCount()>1){
        MsgBox 36, InfoLite Lab, You have selected more than one script. Would you like to execute them all sequentially?
        IfMsgBox Yes
        {
          row:=0
          While (row := LV_GetNext(row)) {
            LV_GetText(pth,row,2)
            errors := RubyFileExec(ICMGetPID(),pth)
            if errors {
              msgbox, % pth . ":`r`n`r`n" . errors.message . "`r`n`r`nSequential execution halted."
              break
            }
            
            sleep,100
          }
        }
      } else {
        ;Execute single:
        LV_GetText(pth, A_EventInfo,2)
        errors := RubyFileExec(ICMGetPID(),pth)
        if errors
          msgbox, % errors.message
      }
    }
  }
}

GuiClose:  ; Indicate that the script should exit automatically when the window is closed.
  Gui,Hide
return

  