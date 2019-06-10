;#Persistent
;#SingleInstance,Force


class InfoLite {
  static VersionWParams := {"IN-6.5" :0x88FC ;Assumption
                  ,"ICM-6.5":0x88FC
                  ,"IN-7.5" :0x8A69
                  ,"ICM-7.5":0x8A69 ;Assumption
                  ,"IN-8.5" :0x8A69
                  ,"ICM-8.5":0x8A69}
  
  static rubyExtScript := InfoLite._getRubyExtScript()
  static Messages := {"WM_COMMAND":     0x0111
                     ,"WM_MDIGETACTIVE":0x0229}
  
  
  
  getPID(){
    WinGet, pidNew, PID, ahk_exe InnovyzeWC.exe
    return pidNew
  }
  
  EvaluateRuby(scpt,pid:=0){
    if(pid=0){
      pid := this.getPID()
    }
    
    file := this._GenerateFileName("azAZ09__",20,A_Temp . "\rb",".rb")
    out   = %file%.log
    scpt := StrReplace(this.rubyExtScript,"##outFile##",out) . scpt
    
    ;Write temp in and out files
    FileAppend, %scpt%, %file%
    FileAppend,, %out%
      ;Wait a few microseconds for stability
      sleep,50
      
      ;Execute script
      errors := this.Execute(pid,file)
      
      ;Read out data
      FileRead,retData,%out%
      
    ;Delete temp in and out files
    FileDelete, %file%
    FileDelete, %out%
    
    ;Return data
    return {"errors":errors,"return":retData}
  }

  ExecuteRuby(rbFile,pid:=0){
    ;Process  ID
    if (pid=0) {
      pid := this.getPID()
    }
    
    ;Required events from HookEventLib.ahk
    this.EVENTS_REQUIRED := [this.WinEvents.EVENT.OBJECT.SHOW,this.WinEvents.EVENT.OBJECT.DESTROY]
    
    ;Ensure file exists
    this.__DebugTip(A_ThisFunc,"BEFORE_RubyFileExists",true)
    if !fileexist(rbFile){
      return Exception("#2 Ruby file does not exist.","checkRubyCanRun","")
    }
    
    ;Set unhook on exit
    OnExit("Unhook_pRunWaitRuby")
    
    ;Set ruby script to run
    this._RUBY_SCRIPT := rbFile
    
    ;When debugging
    this.__DebugTip(A_ThisFunc,"BEFORE_CheckRubyCanRun",true)
    if (!this.checkRubyCanRun(pid)) {
      return Exception("#1 Ruby can't run at the moment. Please select a GeoPlan and try again.","checkRubyCanRun","")
    }
    
    
    ;Hook window events
    this.__DebugTip(A_ThisFunc,"BEFORE_HookWinEvents",true)
    WinEvents.HookEvent(this.pRunWaitRuby, this.EVENTS_REQUIRED, pid)
    
    ;Ensure we always get the event:
    sleep,50 
    
    ;Track ICM state
    this.ICM_READY_STATE := 3
    
    ;Run 'Run Ruby Script' command:
    this.__DebugTip(A_ThisFunc,"BEFORE_PostMessage",true)
    this.LaunchRubyScriptDlg(pid)
    
    ;Wait till processing has finished
    while (this.ICM_READY_STATE!=0) {
      sleep,100
    }
    this.__DebugTip(A_ThisFunc,"AFTER_IcmReadyStateZeroed",true)
    
    ;Unhook window events
    this.__DebugTip(A_ThisFunc,"BEFORE_UnhookWinEvents",true)
    WinEvents.UnHookEvent(this.pRunWaitRuby, this.EVENTS_REQUIRED)
    
    ;Ensure ICM is ready
    sleep,300
    
    ;TODO: Handle error messages
    
    this.__DebugTip(A_ThisFunc,false,true)
    return ""
  }
  
  getILVersion(pid){
    for Item in ComObjGet( "winmgmts:" ).ExecQuery("Select * from Win32_Process") {
      details := "CMD:" Item.CommandLine "`r`nName:" Item.Name "`r`nPath" Item.ExecutablePath "`r`nHandle:" Item.Handle "`r`nPID:" Item.ProcessId
      if item.Name = "InnovyzeWC.exe" {
        if item.ProcessId = pid {
          name := instr(item.CommandLine,"/asset") ? "IN" : "ICM"
          RegexMatch(this._FGP_Value(Item.ExecutablePath,"File version"),"(\d+\.\d+).+",match)
          num := match1
          
          return name . "-" .  num
        }
      }
    }
  }
  
  LaunchRubyScriptDlg(pid){
    ilVersion := this.getILVersion(pid)
    wParam := this.VersionWParams[ilVersion]
    
    hwnd := this.getILMainWindow(pid)
    PostMessage, % this.Messages.WM_COMMAND,%wParam%,0,,ahk_id %hwnd%
  }

  getILMainWindow(pid){
    DetectHiddenWindows,On
    WinGet, wList, List, ahk_pid %pid%
    index := 0
    Loop, % wList {
      hwnd := wList%A_Index%
      WinGetClass, cls, ahk_id %hwnd%
      WinGetTitle, title, ahk_id %hwnd%
      if (cls ~= "Afx:.*" && title ~= "(InfoNet|InfoWorks).+"){
        return hwnd
      }
    }
  }
   
  ;Check ruby can run:
  ;Ruby can only run on networks and the network tab must be open before InfoLite apps
  ;will respond to ruby requests.
  checkRubyCanRun(pid){
    main := this.getILMainWindow(pid)
    SendMessage,% this.Messages.WM_MDIGETACTIVE,,, MDIClient1, ahk_id %main%
    hwnd := ErrorLevel
    if (hwnd="Fail") {
      ;Set error?
      return false
    }
    
    WinGetTitle,title,ahk_id %hwnd%
    return (title ~= "GeoPlan.+") || (title ~= "Grid.+")
  }

  pRunWaitRuby(hHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime){
    WinGetTitle Title, ahk_id %hwnd%
    WinGetClass cls, ahk_id %hwnd%
    
    if (this.DEBUG_MODE){
      s := "Ev:" . event . " HWND:" . hwnd . " idObj:" . idObject . " idChild:" . idChild . " dwET:" . dwEventThread . " Title:" . title . " Class:" . cls . "`r`n"
      FileAppend, %s%, C:\log.txt
    }
    
    ;Title check:
    if (this.ICM_READY_STATE=3 && Title = "Open" && cls = "#32770") {
      ControlSetText, Edit1, % this._RUBY_SCRIPT, ahk_id %hwnd%
      Control,Check,,Button1,ahk_id %hwnd%
      this.ICM_READY_STATE:=2
    }
    
    ;Store progress bar hwnd
    if ((Title~="Please wait.*") && (event=32770)){ ;EVENT_OBJECT_SHOW
      ;Ev:3 idObj:0 idChild:0 dwET:10664 Title:Please wait... Class:#32770
      this.ICM_READY_STATE:=1
      this.PROGRESS_HWND:=hwnd
    }
    
    ;When progress bar destroyed then ICM Ready state 5
    if (this.PROGRESS_HWND){
      if (hwnd = this.PROGRESS_HWND && event = 32769){ ;EVENT_OBJECT_DESTROY
        ;Ev:32769 HWND:2834482 idObj:0 idChild:0 dwET:21268 Title: Class:
        this.ICM_READY_STATE:=0
      }
    }
    
    return 0
  }

  ;Unhook event on delete
  __Delete(){
    WinEvents.UnHookEvent(this.pRunWaitRuby, this.EVENTS_REQUIRED)
  }
  



  
  
  
  
  
  ;======================================================================================
  ;Private Helpers
  ;======================================================================================
  
  
  ;Function:    _getRubyExtScript
  ;Description: Private helper for ruby getting wrapper script for ExecScript()
  _getRubyExtScript(){
    rubyExtScript := ""
    rubyExtScript .= "scrpt = DATA.read                                             `r`n"
    rubyExtScript .= "scope = binding                                               `r`n"
    rubyExtScript .= "ext=<<EXTEND                                                  `r`n"
    rubyExtScript .= "  require 'json'                                              `r`n"
    rubyExtScript .= "  class StdIO                                                 `r`n"
    rubyExtScript .= "    def puts(s)                                               `r`n"
    rubyExtScript .= "      @s ||= """"                                             `r`n"
    rubyExtScript .= "      @s += s + ""\n""                                        `r`n"
    rubyExtScript .= "      return nil                                              `r`n"
    rubyExtScript .= "    end                                                       `r`n"
    rubyExtScript .= "    def string                                                `r`n"
    rubyExtScript .= "      @s                                                      `r`n"
    rubyExtScript .= "    end                                                       `r`n"
    rubyExtScript .= "  end                                                         `r`n"
    rubyExtScript .= "  $veryCoolWrapperLog = StdIO.new                             `r`n"
    rubyExtScript .= "                                                              `r`n"
    rubyExtScript .= "  def puts(*args)                                             `r`n"
    rubyExtScript .= "    $veryCoolWrapperLog.puts(*args)                           `r`n"
    rubyExtScript .= "  end                                                         `r`n"
    rubyExtScript .= "  def outputDump(var)                                         `r`n"
    rubyExtScript .= "    #serialise                                                `r`n"
    rubyExtScript .= "    if var.respond_to?(:to_json)                              `r`n"
    rubyExtScript .= "      begin                                                   `r`n"
    rubyExtScript .= "        ret = var.to_json                                     `r`n"
    rubyExtScript .= "      rescue Exception => e                                   `r`n"
    rubyExtScript .= "        err = e.full_message                                  `r`n"
    rubyExtScript .= "      end                                                     `r`n"
    rubyExtScript .= "    else                                                      `r`n"
    rubyExtScript .= "      ret = var.to_s                                          `r`n"
    rubyExtScript .= "    end                                                       `r`n"
    rubyExtScript .= "    returnData = {                                            `r`n"
    rubyExtScript .= "      :return => ret,                                         `r`n"
    rubyExtScript .= "      :log    => $veryCoolWrapperLog.string                   `r`n"
    rubyExtScript .= "    }.to_json                                                 `r`n"
    rubyExtScript .= "                                                              `r`n"
    rubyExtScript .= "    File.open(""##outFile##"",""w"") {|f| f.write(returnData)}`r`n"
    rubyExtScript .= "  end                                                         `r`n"
    rubyExtScript .= "EXTEND                                                        `r`n"
    rubyExtScript .= "scope.eval(ext)                                               `r`n"
    rubyExtScript .= "retData = scope.eval(""def main;"" + scrpt + "";end;main()"") `r`n"
    rubyExtScript .= "__END__                                                       `r`n"
    rubyExtScript .= "                                                              `r`n"
    rubyExtScript .= "                                                              `r`n"
    rubyExtScript := RegexReplace(rubyExtScript,"\s+\r\n","`r`n")
    return rubyExtScript
  }
  
  ;Function:    _GenerateFileName
  ;Description: Generates a file path from chars specified, for a certain length, including prefix and suffix.
  _GenerateFileName(chars,length,prefix="",suffix=""){
     Loop,Parse,chars
     {
        If !Mod(A_Index,2){
           Loop % Asc(SubStr(A_LoopField,1,1))-Asc+1
              usedChars.=Chr(A_Index + Asc - 1)
        } else Asc:=Asc(A_LoopField)
     }
     while StrLen(name)<length {
        Random,Chr,1,% StrLen(usedChars)
        name.=SubStr(usedChars,Chr,1)
     }
     return prefix . name . suffix
  }
  
  ;Function:    _FGP_Init()
  ;Description: Gets an object containing all of the property numbers that have corresponding names. Used to initialize the other functions.
  ;Returns:
  ;	An object with the following format:
  ;		PropTable.Name["PropName"]	:= PropNum
  ;		PropTable.Num[PropNum]		:= "PropName"
  _FGP_Init() {
    static PropTable
    if (!PropTable) {
      PropTable := {Name: {}, Num: {}}, Gap := 0
      oShell := ComObjCreate("Shell.Application")
      oFolder := oShell.NameSpace(0)
      while (Gap < 11)
        if (PropName := oFolder.GetDetailsOf(0, A_Index - 1)) {
          PropTable.Name[PropName] := A_Index - 1
          PropTable.Num[A_Index - 1] := PropName
          Gap := 0
        }
        else
          Gap++
    }
    return PropTable
  }

  ;Function:    _FGP_Value(FilePath, Property)
  ;Description:	Gets a file property value.
  ;Parameters:
  ;	            FilePath - The full path of a file.
  ;	            Property - Either the name or number of a property.
  ;Returns:
  ;	            If succesful the file property value is returned. Otherwise:
  ;	               0	 - The property is blank.
  ;	               -1 - The property name or number is not valid.
  _FGP_Value(FilePath, Property) {
    static PropTable := this._FGP_Init()
    if ((PropNum := PropTable.Name[Property] != "" ? PropTable.Name[Property]
    : PropTable.Num[Property] ? Property : "") != "") {
      SplitPath, FilePath, FileName, DirPath
      oShell := ComObjCreate("Shell.Application")
      oFolder := oShell.NameSpace(DirPath)
      oFolderItem := oFolder.ParseName(FileName)
      if (PropVal := oFolder.GetDetailsOf(oFolderItem, PropNum))
        return PropVal
      return 0
    }
    return -1
  }
  
  class WinEvents {
    static EVENT := {"OBJECT":{"CREATE":0x8000
                               ,"DESTROY":0x8001
                               ,"SHOW":0x8002
                               ,"HIDE":0x8003
                               ,"REORDER":0x8004
                               ,"FOCUS":0x8005
                               ,"SELECTION":0x8006
                               ,"SELECTIONADD":0x8007
                               ,"SELECTIONREMOVE":0x8008
                               ,"SELECTIONWITHIN":0x8009
                               ,"STATECHANGE":0x800A
                               ,"LOCATIONCHANGE":0x800B
                               ,"NAMECHANGE":0x800C
                               ,"DESCRIPTIONCHANGE":0x800D
                               ,"VALUECHANGE":0x800E
                               ,"PARENTCHANGE":0x800F
                               ,"HELPCHANGE":0x8010
                               ,"DEFACTIONCHANGE":0x8011
                               ,"ACCELERATORCHANGE":0x8012
                               ,"INVOKED":0x8013
                               ,"TEXTSELECTIONCHANGED":0x8014
                               ,"CONTENTSCROLLED":0x8015
                               ,"CLOAKED":0x8017
                               ,"UNCLOAKED":0x8018
                               ,"LIVEREGIONCHANGED":0x8019
                               ,"HOSTEDOBJECTSINVALIDATED":0x8020
                               ,"DRAGSTART":0x8021
                               ,"DRAGCANCEL":0x8022
                               ,"DRAGCOMPLETE":0x8023
                               ,"DRAGENTER":0x8024
                               ,"DRAGLEAVE":0x8025
                               ,"DRAGDROPPED":0x8026
                               ,"IME_SHOW":0x8027
                               ,"IME_HIDE":0x8028
                               ,"IME_CHANGE":0x8029
                               ,"TEXTEDIT_CONVERSIONTARGETCHANGED":0x8030
                               ,"END":0x80FF}
                     ,"SYSTEM":{"SOUND":0x0001
                               ,"ALERT":0x0002
                               ,"FOREGROUND":0x0003
                               ,"MENUSTART":0x0004
                               ,"MENUEND":0x0005
                               ,"MENUPOPUPSTART":0x0006
                               ,"MENUPOPUPEND":0x0007
                               ,"CAPTURESTART":0x0008
                               ,"CAPTUREEND":0x0009
                               ,"MOVESIZESTART":0x000A
                               ,"MOVESIZEEND":0x000B
                               ,"CONTEXTHELPSTART":0x000C
                               ,"CONTEXTHELPEND":0x000D
                               ,"DRAGDROPSTART":0x000E
                               ,"DRAGDROPEND":0x000F
                               ,"DIALOGSTART":0x0010
                               ,"DIALOGEND":0x0011
                               ,"SCROLLINGSTART":0x0012
                               ,"SCROLLINGEND":0x0013
                               ,"SWITCHSTART":0x0014
                               ,"SWITCHEND":0x0015
                               ,"MINIMIZESTART":0x0016
                               ,"MINIMIZEEND":0x0017
                               ,"DESKTOPSWITCH":0x0020
                               ,"END":0x00FF
                               ,"ARRANGMENTPREVIEW":0x8016}}

    static EVENT_ALL := InfoLite.WinEvents.getAllEvents()
    
    getAllEvents(){
      events := []
      for key,value in this.EVENT.OBJECT {
        events.push(value)
      }
      for key,value in this.EVENT.SYSTEM {
        events.push(value)
      }
      return events
    }

    HookEvent(function, events, pid := "0", flags := "0") {
        if(!this.EventHookTable)
          this.EventHookTable:={}
        
        for i, event_id in events {
            if(!this.EventHookTable[event_id])
                this.EventHookTable[event_id] := Array() 
            if(this.CreateWinEventHook(function, event_id, pid, flags))
                this.EventHookTable[event_id].Push(function)
        }
    }

    UnHookEvent(function, events) {
        for i, event_id in events {
            if(this.EventHookTable[event_id]) {
                for i2, v2 in this.EventHookTable[event_id] {
                    if(v2 == function) {
                        this.DeleteWinEventHook(function, event_id)
                        this.EventHookTable[event_id].RemoveAt(i2)
                    }
                }
                if(this.EventHookTable[event_id].Length() == 0)
                    this.EventHookTable.Delete(event_id)
            }
        }
    }

    CreateWinEventHook(function, event, pids := "0", dwflags := "0") {
        this._hHookTable
        if(!this._hHookTable)
          this._hHookTable:={}
        
        cb := RegisterCallback(function)
        this.DeleteWinEventHook(function, event)
        
        ;Try to co-initialise
        try nCheck := DllCall( "CoInitialize", Ptr, 0)
        
        DllCall( "SetLastError", UInt,nCheck ) ; SetLastError in case of success/error
        
        E_INVALIDARG   := 0x80070057
        E_OUTOFMEMORY  := 0x8007000E
        E_UNEXPECTED   := 0x8000FFFF
        
        ;Error checking
        if nCheck==E_INVALIDARG
          throw Exception("Invalid argument", "CreateWinEventHook","Try restarting InfoNet/InfoWorks")
        if nCheck==E_OUTOFMEMORY
          throw Exception("Out of memory", "CreateWinEventHook","Try restarting InfoNet/InfoWorks")
        if nCheck==E_UNEXPECTED
          throw Exception("Unexpected error", "CreateWinEventHook","Try restarting InfoNet/InfoWorks")
          
        if(hHook := DllCall("SetWinEventHook", UInt, event, UInt, event, UInt, 0, UInt, cb, UInt, pids, UInt, 0, UInt, dwflags))
            this._hHookTable[function.name . "_" . event] := hHook

        return (hHook != 0)
    }

    DeleteWinEventHook(function, event) {
        hHook := this._hHookTable.Delete(function.name . "_" . event)
        return (hHook != 0 ? DllCall("UnhookWinEvent", UInt, hHook) : false)
    }
  }
  
  
  ;======================================================================================
  ;Private debugging helpers
  ;======================================================================================
  
  __DebugTip(f,msg,logToFile:=false){
    if (this.DEBUG_MODE) {
      if msg {
        tooltip, %f%::%msg%
        if logToFile {
          FileAppend, %f%::%msg%, C:\log.txt
        }
      } else {
        tooltip,
      }
    }
  }
}