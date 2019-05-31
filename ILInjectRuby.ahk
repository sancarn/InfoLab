/* 
  TODO:
    * ::execRuby Detect ICM ruby error!
    * ::execRuby Detect critical crash error!
    * Make RubyFileExec class based:
        Init acc on __NEW
        Init event runtime on __NEW
        Stop event runtime on __DELETE
        Migrate from using globals to using instance variables
      This should greatly speed up the initial runtime
    * Look into migrating to EWinHook as this seems to be better built https://www.autohotkey.com/boards/viewtopic.php?t=830
      Alternative OnWin() https://github.com/cocobelgica/AutoHotkey-Util/blob/master/OnWin.ahk
        - however this is unlikely to help much 
        
    * Standard way to obtain output of script (RubyExec only). Ideas:
      - Replace puts with $f.puts and prepend $f = File.open(<<tempFilePath>>,'a') to beginning of script.
      - Wrap code in function so return can be used to return data.
    * Use VersionWParams()
*/    


#Include ILGetVersion.ahk
#include HookEventLib.ahk

DEBUG_MODE:=false
rubyExtScript=
(
scrpt = DATA.read
scope = binding
ext=<<EXTEND
  require 'json'
  class StdIO
    def puts(s)
      @s ||= ""
      @s += s + "\n"
      return nil
    end
    def string
      @s
    end
  end
  $veryCoolWrapperLog = StdIO.new
  
  def puts(*args)
    $veryCoolWrapperLog.puts(*args)
  end
  def outputDump(var)
    #serialise
    if var.respond_to?(:to_json)
      begin
        ret = var.to_json
      rescue Exception => e
        err = e.full_message
      end
    else
      ret = var.to_s
    end
    returnData = {
      :return => ret,
      :log    => $veryCoolWrapperLog.string
    }.to_json
    
    File.open("##outFile##","w") {|f| f.write(returnData)}
  end
EXTEND
scope.eval(ext)
retData = scope.eval("def main;" + scrpt + ";end;main()")
__END__


)

VersionWParams := {"IN-6.5" :0x88FC ;Assumption
                  ,"ICM-6.5":0x88FC
                  ,"IN-7.5" :0x8A69
                  ,"ICM-7.5":0x8A69 ;Assumption
                  ,"IN-8.5" :0x8A69
                  ,"ICM-8.5":0x8A69}

ICMGetPID(){
  WinGet, pidNew, PID, ahk_exe InnovyzeWC.exe
  return pidNew
}

RubyExec(pid,scpt){
  global rubyExtScript
  file := GenerateFileName("azAZ09__",20,A_Temp . "\rb",".rb")
  out   = %file%.log
  scpt := StrReplace(rubyExtScript,"##outFile##",out) . scpt
  
  ;Write temp in and out files
  FileAppend, %scpt%, %file%
  FileAppend,, %out%
    ;Wait a few microseconds for stability
    sleep,50
    
    ;Execute script
    errors := RubyFileExec(pid,file)
    
    ;Read out data
    FileRead,retData,%out%
    
  ;Delete temp in and out files
  FileDelete, %file%
  FileDelete, %out%
  
  ;Return data
  return {"errors":errors,"return":retData}
}

RubyFileExec(pid, scpt){
  global RUBY_SCRIPT
  global EVENT_OBJECT_SHOW
  
  ;Required events from HookEventLib.ahk
  global EVENTS_REQUIRED := [EVENT_OBJECT_SHOW,EVENT_OBJECT_DESTROY]
  
  ;Ensure file exists
  DebugTip(A_ThisFunc,"BEFORE_RubyFileExists",true)
  if !fileexist(scpt){
    return Exception("#2 Ruby file does not exist.","checkRubyCanRun","")
  }
  
  ;Set unhook on exit
  OnExit("Unhook_pRunWaitRuby")
  
  ;Set ruby script to run
  RUBY_SCRIPT := scpt
  
  ;When debugging
  DebugTip(A_ThisFunc,"BEFORE_CheckRubyCanRun",true)
  if (!checkRubyCanRun(pid)) {
    return Exception("#1 Ruby can't run at the moment. Please select a GeoPlan and try again.","checkRubyCanRun","")
  }
  
  
  ;Hook window events
  DebugTip(A_ThisFunc,"BEFORE_HookWinEvents",true)
  HookEvent("pRunWaitRuby", EVENTS_REQUIRED, pid)
  
  ;Ensure we always get the event:
  sleep,50 
  
  ;Track ICM state
  global ICM_READY_STATE := 3
  
  ;Run 'Run Ruby Script' command:
  DebugTip(A_ThisFunc,"BEFORE_PostMessage",true)
  LaunchRubyScriptDlg(pid)
  
  ;Wait till processing has finished
  while (ICM_READY_STATE!=0) {
    sleep,100
  }
  DebugTip(A_ThisFunc,"AFTER_IcmReadyStateZeroed",true)
  
  ;Unhook window events
  DebugTip(A_ThisFunc,"BEFORE_UnhookWinEvents",true)
  UnHookEvent("pRunWaitRuby", EVENTS_REQUIRED)
  
  ;Ensure ICM is ready
  sleep,300
  
  ;TODO: 
  
  DebugTip(A_ThisFunc,false,true)
  return ""
}

DebugTip(f,msg,logToFile:=false){
  global DEBUG_MODE
  if DEBUG_MODE {
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

LaunchRubyScriptDlg(pid){
  global VersionWParams
  global WM_COMMAND
  ilVersion := getInfoLiteVersion(pid)
  wParam := VersionWParams[ilVersion]
  
  hwnd := FindILMainWindow(pid)
  PostMessage, %WM_COMMAND%,%wParam%,0,,ahk_id %hwnd%
}

FindILMainWindow(pid){
  DetectHiddenWindows,On
  WinGet, wList, List, ahk_pid %pid%
  index := 0
  Loop, % wList {
    hwnd := wList%A_Index%
    WinGetClass, cls, ahk_id %hwnd%
    WinGetTitle, title, ahk_id %hwnd%
    if (cls ~= "Afx:.*" && title ~= "InfoNet|InfoWorks.+"){
      return hwnd
    }
  }
}
 
 ;Check ruby can run:
 ;Ruby can only run on networks and the network tab must be open before InfoLite apps
 ;will respond to ruby requests.
checkRubyCanRun(pid){
  WM_MDIGETACTIVE := 0x0229
  main := FindILMainWindow(pid)
  SendMessage,%WM_MDIGETACTIVE%,,, MDIClient1, ahk_id %main%
  hwnd := ErrorLevel
  if (hwnd="Fail") {
    ;Set error?
    return false
  }
  
  WinGetTitle,title,ahk_id %hwnd%
  return title ~= "GeoPlan.+"
}


Unhook_pRunWaitRuby(){
  global EVENTS_REQUIRED
  UnHookEvent("pRunWaitRuby", EVENTS_REQUIRED)
}

pRunWaitRuby(hHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime){
  global RUBY_SCRIPT
  global EVENTS_REQUIRED
  global ICM_READY_STATE
  global PROGRESS_HWND
  global DEBUG_MODE
  
  WinGetTitle Title, ahk_id %hwnd%
  WinGetClass cls, ahk_id %hwnd%
  
  if (DEBUG_MODE){
    s := "Ev:" . event . " HWND:" . hwnd . " idObj:" . idObject . " idChild:" . idChild . " dwET:" . dwEventThread . " Title:" . title . " Class:" . cls . "`r`n"
    FileAppend, %s%, C:\log.txt
  }
  
  ;Title check:
  if (ICM_READY_STATE=3 && Title = "Open" && cls = "#32770") {
    ControlSetText, Edit1, %RUBY_SCRIPT%, ahk_id %hwnd%
    Control,Check,,Button1,ahk_id %hwnd%
    ICM_READY_STATE:=2
  }
  
  ;Store progress bar hwnd
  if ((Title~="Please wait.*") && (event=32770)){ ;EVENT_OBJECT_SHOW
    ;Ev:3 idObj:0 idChild:0 dwET:10664 Title:Please wait... Class:#32770
    ICM_READY_STATE:=1
    PROGRESS_HWND:=hwnd
  }
  
  ;When progress bar destroyed then ICM Ready state 5
  if (PROGRESS_HWND){
    if (hwnd = PROGRESS_HWND && event = 32769){ ;EVENT_OBJECT_DESTROY
      ;Ev:32769 HWND:2834482 idObj:0 idChild:0 dwET:21268 Title: Class:
      ICM_READY_STATE:=0
    }
  }
  
  return 0
}

;Code by hotkeyit
GenerateFileName(chars,length,prefix="",suffix=""){
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






;DEFUNCT FUNCTIONS:
;     #include Acc.ahk
;     ...
;     ;Warn: This is slow!
;     ;E.G. accDetectTabExist(pid,"Network")
;     accDetectTabExist(pid,name){
;       ControlGet, id, hwnd,, ToolbarWindow321, ahk_pid %pid%
;       children := Acc_Children(Acc_ObjectFromWindow(id))
;       names := []
;       for k,child in children {
;         if child.accName = name {
;           return true
;         }
;       }
;       return false
;     }