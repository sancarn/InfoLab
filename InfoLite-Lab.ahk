﻿#Include ILInjectRuby.ahk
#SingleInstance,Force
global DEBUG_VIEWER:= false
global window := new InfoLiteLab()
global window_shown := true
Gui, InfoLiteLab1:+AlwaysOnTop

;Hide when ICM not active, show when active.
SetTimer, OnTimer
return

#Include Lib\CGUI.ahk
OnTimer:
  WinGetClass, klass, A
  if !DEBUG_VIEWER {
    hwnd := WinExist("A")
    if WinActive("ahk_exe InnovyzeWC.exe") || WinActive("ahk_id " window.hwnd) {
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
  }
return


;TODO:
;  Settings!
;    * Can be stored in any root
;    * Stores the location of other roots   
;        roots=["%A_AppDir%","%A_Documents%\InfoLite-Lab","%A_Appdata%\InfoLite-Lab"]
;    * Stored as JSON file?
;    * Also allow for other generic sections e.g. Keyboard Shortcuts!
;  Libs:
;    * Maybe ignore folders named "Lib" ?



;Tree generated from object as follows:
;[
;  {
;    type:"Folder",
;    name:"System",
;    icon:"%A_ScriptDir%\scripts\_.png",
;    children:[
;      {
;        type:"Script",
;        name:"FileName",
;        path:"%A_ScriptDir%\scripts\FileName.rb",
;        icon:"%A_ScriptDir%\scripts\FileName.rb.png"
;      },
;      ...
;    ]
;  },{
;    type:"Folder",
;    name:"User",
;    icon:"%A_AppData%\InfoLite-Lab\scripts\_.png",
;    children:[
;      ...
;    ]
;  },{
;    type:"Folder",
;    name:"User",
;    icon:"%A_Documents%\InfoLite-Lab\scripts\_.png",
;    children:[
;      ...
;    ]
;  }
class InfoLiteLab extends CGUI {  
  ;Controls can be defined as class variables at the top of the class like this:
  Refresh := this.AddControl("Button", "Refresh", "x210 y15 w30 h30", "R")  ;⟳
  Query := this.AddControl("Edit", "Query", "x15 y15 w200 h30 -Multi", "")
  ;Option -Multi: ensures no multiline up-downs
  
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
    this.Title := "InfoLite-Lab"
    this.Resize := true
    this.CloseOnEscape := false
    this.DestroyOnClose := false
    
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
    this.OnMessage(0x0101,"OnGUIKeyUp")
    
    ;TreeView Events
    this.InfoLiteTree.DoubleClick.Handler := new Delegate(this,"OnExecuteRuby")
    this.InfoLiteTree.RightClick.Handler  := new Delegate(this,"OnOpenContext")
    
    this.roots := [ A_ScriptDir , A_Roaming "\InfoLite-Lab" , A_Documents "\InfoLite-Lab"]
    
    ;Get file tree
    this.treeItems := this.getFileTrees()
    
    ;Create tree view:
    this.InfoLiteTree.createTree(this.treeItems)
    
    ;Show the window
    this.Show("")
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
        item := (new ILL_Folder(scriptDir))
        if (sRoot == A_ScriptDir) {
          item.name := "AppRoot"
        } else if (sRoot == A_Roaming "\InfoLite-Lab") {
          item.name := "Roaming"
        } else if (sRoot == A_Documents "\InfoLite-Lab") {
          item.name := "Documents"
        }
        items.push(item)
      }
    }
    return items
  }
  
  Size(event){
    ;Get GUI dimensions and constants
    GUIW := this.width / 1.5
    GUIH := this.height / 1.5
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
  
  ;Convert array of File/Folder objects to a FLAT array of File/Folder objects
  ;This function also builds a 'simple path' for the objects based on the TreeView item names and hierarchy.
  GetFileArray(obj,BasePath:="",files := false){
    if !files {
      files := []
    }
    for i,child in obj {
      if child.type = "Folder" {
        this.GetFileArray(child.children,BasePath . child.name . "/", files)
      } else if child.type = "Script" {
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
        this.OnExecuteRuby(this.InfoLiteTree)
      }
    }
  }
  
  ;Execute selected ruby item. This is executed on double click and enter press. 
  OnExecuteRuby(Tree){
    script := Tree.RubyItemDict[Tree.SelectedItem.id]
    if (script.type != "Folder") {
      script.execute()
    }
  }
  
  ;This is called whenever the user right clicks on an item.
  ;The item is obtained via the RubyItemDict and then openContext() is called
  OnOpenContext(Tree){
    item := Tree.RubyItemDict[Tree.SelectedItem.id]
    item.openContext()
  }
  
  ;
  OnRefresh(event:=false){
    this.SetTree(this.getFileTrees())
  }
}

;folder := ComObjCreate("Scripting.FileSystemObject").GetFolder(A_ScriptDir "\scripts")
;structure := new ILL_Folder(folder)
;msgbox Please debug

;Create menu from keys and values
helperMenu(data){
  ; Arguments assigned to menu functions: MenuItemClicked,ClickType,MenuName
  ; Binding this to the function ensures this object is preserved.
  try Menu, Context, DeleteAll
  for key,value in data {
    Menu, Context, Add, %key%, %value%
  }
}

class ILL_Script {
  static iconExts := ["GIF", "JPG", "BMP", "ICO", "CUR", "ANI", "PNG", "TIF", "Exif", "WMF", "EMF"]
  __New(shFile){
    this.type := "Script"
    this.name := shFile.name
    this.path := shFile.path
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
  execute(){
    if DEBUG_VIEWER {
      msgbox, % this.path
    } else {
      ;Execute ruby script and report on any errors which occurred
      errors := RubyFileExec(ICMGetPID(),pth)
      if errors
        msgbox, % errors.message
    }
  }
  openContext(){
    helperMenu({ "Execute script": this.execute.bind(this)
                ,"Open in explorer": this.openInExplorer.bind(this)})
    Menu, Context, Show
  }
  openInExplorer(){
    path := this.path
    Run %COMSPEC% /c explorer.exe /select`, "%path%",, Hide
  }
}
class ILL_Folder {
  static iconExts := ["GIF", "JPG", "BMP", "ICO", "CUR", "ANI", "PNG", "TIF", "Exif", "WMF", "EMF"]
  __New(shFolder){
    this.type := "Folder"
    this.name := shFolder.name
    this.path := shFolder.path
    for i,ext in ILL_Folder.iconExts {
      img := this.path . "\_." ext
      if fileexist(img){
        this.icon := img
        break
      } else {
        this.icon := false
      }
    }
    this.children := []
   
    ;Get folders
    for child in shFolder.SubFolders {
      this.children.push(new ILL_Folder(child))
    }
   
    for child in shFolder.files {
      if (child.name ~= "i).+\.rb$") {
        this.children.push(new ILL_Script(child))
      }
    }
  }
  
  execute(){ 
    for i,item in this.children {
      item.execute()
    }
  }
  
  openContext(){
    helperMenu({ "Execute all": this.execute.bind(this) 
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


#ifwinactive InfoLite-Lab
RButton::
  Send,{LButton}
  Send,{RButton}
return



  