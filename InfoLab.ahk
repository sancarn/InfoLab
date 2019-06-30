#Include InfoLite-API.ahk
#SingleInstance,Force
global window := new InfoLab()
global window_shown := true
Gui, InfoLab1:+AlwaysOnTop
Gui, InfoLab1:-dpiscale
window.size(0) ;required because of change in dpiscale option

;RegisterObjActive(window  ,"{CCCCCCCC-CCCC-CCCC-CCCC-ACCCCCCCCCC1}")


;TODO:
;  Bugs:
;    * After refresh this.InfoLiteTree.SelectedItem becomes permanently unknown? Not sure why this is occurring...
;      Probably has something to do with CTreeViewControl. Temporary fix is force reloading the app with Reload.
;      #REFRESH to find related code
;  Settings!
;    * Can be stored in any root
;    * Stores the location of other roots   
;        roots=["%A_AppDir%","%A_Documents%\InfoLab","%A_Appdata%\InfoLab"]
;    * Stored as JSON file?
;    * Also allow for other generic sections e.g. Keyboard Shortcuts!
;  Libs:
;    * Maybe ignore folders named "Lib" ?
;  Plugins:
;    * .sql files - Execute SQL from window.
;    * .tb files  - Toolbar execution.
;  General:
;    * Officially register COM Server via CLSID and test using VBScript

;Hide when ICM not active, show when active.
SetTimer, OnTimer
return

#Include Lib\CGUI.ahk
OnTimer:
  WinGetClass, klass, A
  ;tooltip % window.DebugMode . "-" . window.DispState
  if window.DebugMode=0 {
    if window.DispState=0 {
      hwnd := WinExist("A")
      WinGet, A_PID, PID, % "ahk_id " window.hwnd
      if WinActive("ahk_exe InnovyzeWC.exe") || WinActive("ahk_pid " A_PID) {
        if !window_shown {
          window.show()
          window_shown := true
          Winactivate, ahk_id %hwnd%
        }
      } else {
        if window_shown {
          window.hide()
          window_shown := false
        }
      }
    } else if(DispState=1){
      if !window_shown {
        window.show()
        window_shown := true
        Winactivate, ahk_id %hwnd%
      }
    } else if(DispState=2){
      if window_shown {
        window.hide()
        window_shown := false
      }
    }
  }
return

class InfoLab extends CGUI {
  ;Set default registered classes
  static registeredClasses := [ILL_Script,ILL_Folder]
    
  ;Controls can be defined as class variables at the top of the class like this:
  Refresh := this.AddControl("Button", "Refresh", "x210 y15 w30 h30", "R")  ;⟳
  Query := this.AddControl("Edit", "Query", "x15 y15 w200 h30 -Multi", "")
  ;Option -Multi: ensures no multiline up-downs
  
  
  ;Tree generated from hierarchy of IIL_File and IIL_Folder objects.
  class InfoLiteTree {
    static Type    := "TreeView"
    static Options := "x15 y60 w300"
    static Text    := ""
    static Icon    := A_ScriptDir . "\Default.png" ;Default icon
    static DirIcon := A_ScriptDir . "\Folder.ico" ;Default icon
    
    __New() {
      this.LargeIcons := true
      this.DefaultIcon := this.icon
    }
    
    ;When provided a File/Folder hierarchy this function will render it to the TreeView control,
    ;including icons.
    createTree(rootObjects,parent:=false){
      if !parent {
        this.RubyItemDict := {} ;Initialise ID-->rootObj dictionary
        parent := this.Items
      }
      for i,rootObj in rootObjects {
        item := parent.add(rootObj.name)
        this.RubyItemDict[item.id] := rootObj
        
        ;If type is folder then we'll have a different default icon
        if (rootObj.type = "Folder") {
          item.icon := rootObj.icon ? rootObj.icon : this.dirIcon
        } else {
          item.icon := rootObj.icon ? rootObj.icon : this.icon
        }
        try this.createTree(rootObj.children,item)
      }
    }
    
    _ShowInExplorer(path){
      Run %COMSPEC% /c explorer.exe /select`, "%path%",, Hide
    }
  }
  
  ;This constructor is called when the window is instantiated. It's used to setup window properties and also control properties. It's also common that the window shows itself.
  __New()
  {
    ;Set some window properties
    this.Title := "InfoLab"
    this.Resize := true
    this.CloseOnEscape := false
    this.DestroyOnClose := false
    
    ;Bind to API for COM clients
    this.api := InfoLite
    InfoLite.parent := this
    
    ;Set initial position of ILL
    this.WindowWidth := 500
    this.WindowHeight := A_ScreenHeight * 0.9
    this.y := A_ScreenHeight * 0.025
    this.x := A_ScreenWidth - this.WindowWidth
    
    ;Set font sizes:
    this.Query.Font.Size := 16
    this.InfoLiteTree.Font.Size := 15   
    
    ;Bind events:
    this.Refresh.Click.handler := new Delegate(this,"OnRefresh")
    
    WM_KEYUP := 0x0101
    WM_SYSCOMMAND := 0x112
    
    this.OnMessage(WM_KEYUP,"OnGUIKeyUp")
    this.OnMessage(WM_SYSCOMMAND,"onSysCommand")
    
    ;TreeView Events
    this.InfoLiteTree.DoubleClick.Handler := new Delegate(this,"OnExecuteItem")
    this.InfoLiteTree.RightClick.Handler  := new Delegate(this,"OnOpenContext")
    
    ;Set default roots:
    this.roots := [ A_ScriptDir , A_Roaming "\InfoLab" , A_Documents "\InfoLab"]
    
    ;Get file tree
    this.treeItems := this.getFileTrees()
    
    ;Create tree view:
    this.InfoLiteTree.createTree(this.treeItems)
    
    ;Initialise tray menu
    this._iniTrayMenu()
    
    ;Set hidestate
    this.DispState := 0
    
    ;Set debug mode
    this.DebugMode := 1
    
    
    this.initialised := true
    
    ;Show the window
    this.Show("")
  }
  
  DispState {
    get {
      return this._.DispState
    }
    set {
      this._.DispState := value
      ;TOGGLE CHECKBOXES
      if this.initialised
        this.Show("")
      
    }
  }
  DebugMode {
    get {
      return this._.DebugMode
    }
    set {
      this._.DebugMode := value - 1
      this.InfoLite.Debug_Mode := (value - 1)
    }
  }
  
  ;This returns an array of IIL File/Folder objects. The objects returned will contain the hierarchy to be
  ;displayed in the treeview. All file trees are extracted from this.roots.
  getFileTrees(){
    items := []
    ;Process roots
    fso := ComObjCreate("Scripting.FileSystemObject")
    for i,sRoot in this.roots {
      sScriptDir := sRoot . "\scripts"
      if fileexist(sScriptDir){
        scriptDir := fso.GetFolder(sScriptDir)
        item := this.handleChild(scriptDir)
        if (sRoot == A_ScriptDir) {
          item.name := "AppRoot"
        } else if (sRoot == A_Roaming "\InfoLab") {
          item.name := "Roaming"
        } else if (sRoot == A_Documents "\InfoLab") {
          item.name := "Documents"
        }
        items.push(item)
      }
    }
    return items
  }
  
  Size(event){
    ;Get GUI dimensions and constants
    GUIW := this.width  ;/ 1.5
    GUIH := this.height ;/ 1.5
    BND  := 15
    
    ;Calculate Refresh button size/position
    RefreshY := BND
    RefreshW := 30
    RefreshX := GUIW - BND - RefreshW
    RefreshH := RefreshW
    
    ;Calculate Search field size/position
    SearchX := BND
    SearchY := BND
    SearchW := RefreshX - 2*BND
    SearchH := RefreshW
    
    ;Calculate TreeView size/position
    LVX := BND
    LVY := SearchY + SearchH + BND
    LVW := GUIW - 2*BND
    LVH := GUIH - LVY - BND
    
    ;Set refresh button size/position
    this.Refresh.x      := RefreshX
    this.Refresh.y      := RefreshY
    this.Refresh.width  := RefreshW
    this.Refresh.height := RefreshH
    
    ;Set Search field size/position
    this.Query.x      := SearchX
    this.Query.y      := SearchY
    this.Query.width  := SearchW
    this.Query.height := SearchH
    
    ;Set TreeView size/position
    this.InfoLiteTree.x      := LVX
    this.InfoLiteTree.y      := LVY
    this.InfoLiteTree.width  := LVW
    this.InfoLiteTree.height := LVH
  }
  
  ;Replace the data displayed within the current treeview with new data.
  ;New data will overwrite data in this.treeItems property. Invokes InfoLiteTree.createTree()
  SetTree(treeItems){
    ;Clear existing tree items:
    Loop  % this.InfoLiteTree.Items.count {
      this.InfoLiteTree.Items.Delete(0)
    }
    
    ;Clear treeview image lists
    this.InfoLiteTree.ImageListManager.Clear()
    
    ;Get file tree
    this.treeItems := treeItems
    
    ;Create tree view:
    this.InfoLiteTree.createTree(this.treeItems)
  }
  
  ;Find items based on some criteria specified. Criteria is an object as follows:
  ;   regex: Regex to search tree for.
  ;Internally, we use GetFileArray() to get a flat array of File/Folder objects with simplePath attached.
  ;Then we search for items who's simplePath matches the specified criteria.
  FindItems(criteria){
    files  := this.GetFileArray(this.treeItems)
    filter := []
    for i,file in files {
      if criteria.regex {
        if file.simplePath ~= criteria.regex {
          filter.push(file)
        }
      } else {
        ;No criteria
      }
    }
    this.SetTree(filter)
  }
  
  handleChild(shObject,parent:=false){
    if !parent
      parent := this
    for i,klass in InfoLab.registeredClasses {
      if klass.identify(shObject) {
        return klass.create(shObject,parent)
      }
    }
    return false
  }
  
  ;Convert array of File/Folder objects to a FLAT array of File/Folder objects
  ;This function also builds a 'simple path' for the objects based on the TreeView item names and hierarchy.
  GetFileArray(obj,BasePath:="",files := false){
    if !files {
      files := []
    }
    for i,child in obj {
      if child.children {
        this.GetFileArray(child.children,BasePath . child.name . "/", files)
      }
      if child.isFilterable {
        child.simplePath := BasePath . child.name
        files.push(child)
      }
    }
    return files
  }
  
  ;=========================================================================
  ;  EVENT HANDLING
  ;=========================================================================
  
  ;Here we mostly listen for enter key presses.
  ;When enter key is pressed:
  ; If Query field is focused then FindItems() is executed. (If query is blank the tree is reset)
  ; If TreeView is focused then, if the item selected is a script, execute it.
  OnGUIKeyUp(wParam, lParam){  ;
    ;If enter key is pressed
    if (lParam = 13) {
      ;If query is focussed then regex search (or if query text is blank, refresh)
      if (this.Query.Focused) {
        if (this.Query.Text != "") {
          this.FindItems({"regex":this.Query.text})
        } else {
          this.OnRefresh()
        }
      }
      
      ;If TreeView is focussed then execute selected item
      if (this.InfoLiteTree.Focused){
        this.OnExecuteItem(this.InfoLiteTree)
      }
    }
  }
  
  ;OnSysCommand
  onSysCommand(wParam,lParam){
    SC_MINIMIZE := 0xF020
    
    if (lParam = SC_MINIMIZE) {
      ; ILL has been minimised
      this.DispState := 1
      this._helperNamedChoiceListCallback("Minimisable",1,"DisplayState",true)
    }
  }
  
  ;Execute selected ruby item. This is executed on double click and enter press. 
  OnExecuteItem(Tree:=false){ ;FYI Tree is not consistent here...
    selected := this.InfoLiteTree.SelectedItem
    
    ;#REFRESH ToDo: Fix.
    if !selected.id {
      msgbox A known error has occurred. While we try to fix this error as a temporary fix we will reload the app.`r`nPlease try again once the app has reloaded.
      Reload
    }
    
    script := this.InfoLiteTree.RubyItemDict[selected.id]
    if (!script.children) {
      InfoLite.__DebugTip(A_ThisFunc,"BEFORE_ExecuteItem()",true)
      script.execute()
    } else {
      MsgBox, 36, InfoLab, Do you want to execute all scripts within this folder?
      IfMsgbox Yes
        script.execute()
    }
  }
  
  ;This is called whenever the user right clicks on an item.
  ;The item is obtained via the RubyItemDict and then openContext() is called
  OnOpenContext(Tree:=false){ ;FYI Tree is not consistent here...
    selected := this.InfoLiteTree.SelectedItem
    
    ;#REFRESH ToDo: Fix.
    if !selected.id {
      msgbox A known error has occurred. While we try to fix this error as a temporary fix we will reload the app.`r`nPlease try again once the app has reloaded.
      Reload
    }
    item := this.InfoLiteTree.RubyItemDict[selected.id]
    item.openContext()
  }
  
  ;
  OnRefresh(event:=false){
    ;#REFRESH Temporary fix for refresh error.
    Reload
    this.SetTree(this.getFileTrees())
  }
  
  
  
  ;Create menu from keys and values
  _helperMenu(data,show:=false){
    ; Arguments assigned to menu functions: MenuItemClicked,ClickType,MenuName
    ; Binding this to the function ensures this object is preserved.
    try Menu, Context, DeleteAll
    for key,value in data {
      Menu, Context, Add, %key%, %value%
    }
    if show
      Menu, Context, Show
  }
  
  ;Create a named menu from keys and values
  ;
  _helperNamedChoiceList(MenuName,callback,data,default:=1){
    ;Ensure helper object is initialised
    if !this._helperNamedChoiceListData
      this._helperNamedChoiceListData := {}
    
    ;Bind length and callback to data
    this._helperNamedChoiceListData[MenuName] := {"length":data.length(),"callback":callback, "names":data}
    
    ;Get a bound callback function
    fn := this._helperNamedChoiceListCallback.bind(this)
    
    ;Loop through keys (item names) and values (callback function)
    for i,value in data {
      ;Add radio buttons to menu
      Menu, %MenuName%, Add, %value%, %fn%, +Radio
    }
    
    ItemName := data[default]
    Menu, %MenuName%, Check, %ItemName%
  }
  _helperNamedChoiceListCallback(ItemName, ItemPos, MenuName, noCall:=false){
    ;Uncheck all in menu
    data := this._helperNamedChoiceListData[MenuName]
    
    ;Loop through items and uncheck
    for i,sItemName in data.names {
      Menu, %MenuName%, Uncheck, %sItemName%
    }
    
    ;Check chosen item in menu
    Menu, %MenuName%, Check, %ItemName%
    
    ;Call Callback
    if !noCall
      data.callback.Call(ItemName,ItemPos,MenuName)
  }
  
  
  
  ;Initialise tray menu
  _iniTrayMenu(){
    ;Open, Help, Window Spy, Reload This Script, Edit This Script, Suspend Hotkeys, Pause Script, Exit
    Menu, Tray, NoStandard
    
    ;Choice list: DisplayState
    ;0 - Shown/Hidden   (on activate)
    ;1 - Minimized      (will not automatically show)
    ;2 - Always Hidden  (will not automatically show)
    this._helperNamedChoiceList("DisplayState",InfoLab._menuSetDisplayState.bind(this), ["Autohide", "Minimisable", "Always Hidden"])
    Menu, Tray, Add, Display State, :DisplayState
    
    ;Choice List: DebugState
    ;0 - Debug mode off
    ;1 - Debug mode 1
    ;2 - Debug mode 2
    this._helperNamedChoiceList("DebugState",InfoLab._menuSetDebugMode.bind(this), ["Debug mode off", "Debug mode 1", "Debug mode 2"])
    Menu, Tray, Add, Debug Mode, :DebugState
    
    ;Settings
    fn := this._menuSettings.bind(this)
    Menu, Tray, Add, Settings, %fn%
    
    
    ;Reload
    fn := InfoLab._menuReload.bind(this)
    Menu, Tray, Add, Reload, %fn%
    
    ;Exit
    fn := InfoLab._menuExit.bind(this)
    Menu, Tray, Add, Exit, %fn%
  }
  
  _menuSetDebugMode(value,pos){
    this.DebugMode := pos
  }
  _menuSetDisplayState(value,pos){
    this.DispState := pos - 1
  }
  _menuSettings(){
    msgbox, Currently not implemented
  }
  _menuReload(){
    reload
  }
  _menuExit(){
    ExitApp
  }
}

class ILL_Script {
  static iconExts := ["GIF", "JPG", "BMP", "ICO", "CUR", "ANI", "PNG", "TIF", "Exif", "WMF", "EMF"]
  ;Accept only ruby files
  identify(shObj){
    return shObj.path ~= "i).+\.rb$"
  }
  
  ;Static method for creating class (allows external libraries with language limitations)
  create(shObj,parent){
    return new this(shObj,parent)
  }
  
  __New(shObj,parent){
    this.type := "Executable"
    this.name := shObj.name
    this.path := shObj.path
    
    ;Store reference to InfoLab window
    this.parent := parent
    
    this.isFilterable := true
    
    for i,ext in ILL_Script.iconExts {
      img := this.path "." ext
      if fileexist(img) {
        this.icon := img
        break
      } else {
        this.icon := false
      }
    }
  }
  
  ;Execute file
  execute(){
    InfoLite.__DebugTip(A_ThisFunc,"IN_Execute()",true)
    if this.parent.DebugMode = 2 {
      msgbox, % this.path
    } else {
      ;Execute ruby script and report on any errors which occurred
      InfoLite.__DebugTip(A_ThisFunc,"BEFORE_ExecuteRuby()",true)
      errors := InfoLite.executeRuby(this.path)
      if errors
        msgbox, % errors.message
    }
  }
  
  ;Called on right click
  openContext(){
    InfoLab._helperMenu({ "Execute script": this.execute.bind(this)
                             ,"Open in explorer": this.openInExplorer.bind(this)})
    Menu, Context, Show
  }
  
  ;Context item implementation
  openInExplorer(){
    path := this.path
    Run %COMSPEC% /c explorer.exe /select`, "%path%",, Hide
  }
}
class ILL_Folder {
  static iconExts := ["GIF", "JPG", "BMP", "ICO", "CUR", "ANI", "PNG", "TIF", "Exif", "WMF", "EMF"]
  
  ;Accept all directories
  identify(shObj){
    return (ComObjType(shObj, "Name") == "IFolder")
  }
  
  create(shObj,parent){
    return new this(shObj,parent)
  }
  
  __New(shFolder, oILL){
    ;Using type is best avoided but is beneficial to other programs viewing the COM model.
    this.type := "Folder"
    
    ;Name of folder in tree
    this.name := shFolder.name
    
    ;Path of folder on disk
    this.path := shFolder.path
    
    ;Disallow folders to be found by filtering - disallowed because it may look odd
    this.isFilterable := false
    
    ;Store reference to InfoLab window
    this.parent := parent
    
    ;Attempt to find icon for file.
    for i,ext in ILL_Folder.iconExts {
      img := this.path . "\_." ext
      if fileexist(img){
        this.icon := img
        break
      } else {
        this.icon := false
      }
    }
    
    ;Get children
    this.children := []
    ;Get folders
    for child in shFolder.SubFolders {
      if res := InfoLab.handleChild(child,parent) {
        this.children.push(res)
      }
    }
    
    ;Get files
    for child in shFolder.files {
      if res := InfoLab.handleChild(child,parent) {
        this.children.push(res)
      }
    }
  }
  
  execute(){ 
    for i,item in this.children {
      item.execute()
    }
  }
  
  openContext(){
    InfoLab._helperMenu({ "Execute all": this.execute.bind(this) 
                             ,"Open in explorer": this.openInExplorer.bind(this)})
    Menu, Context, Show
  }
  openInExplorer(){
    path := this.path
    Run %COMSPEC% /c explorer.exe /select`, "%path%",, Hide
  }
}

^r::
  reload
return

isWindowActive(){
  global window
  return WinExist("A") = window.hwnd
}


#if isWindowActive()
RButton up::
  SendInput,{LButton}
  SendInput,{RButton}
return



  
