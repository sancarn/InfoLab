; Autoexecute
    #NoEnv
    #SingleInstance force

;Wingmts info:
;  string   CreationClassName;
;  string   Caption;
;  string   CommandLine;
;  datetime CreationDate;
;  string   CSCreationClassName;
;  string   CSName;
;  string   Description;
;  string   ExecutablePath;
;  uint16   ExecutionState;
;  string   Handle;
;  uint32   HandleCount;
;  datetime InstallDate;
;  uint64   KernelModeTime;
;  uint32   MaximumWorkingSetSize;
;  uint32   MinimumWorkingSetSize;
;  string   Name;
;  string   OSCreationClassName;
;  string   OSName;
;  uint64   OtherOperationCount;
;  uint64   OtherTransferCount;
;  uint32   PageFaults;
;  uint32   PageFileUsage;
;  uint32   ParentProcessId;
;  uint32   PeakPageFileUsage;
;  uint64   PeakVirtualSize;
;  uint32   PeakWorkingSetSize;
;  uint32   Priority = NULL;
;  uint64   PrivatePageCount;
;  uint32   ProcessId;
;  uint32   QuotaNonPagedPoolUsage;
;  uint32   QuotaPagedPoolUsage;
;  uint32   QuotaPeakNonPagedPoolUsage;
;  uint32   QuotaPeakPagedPoolUsage;
;  uint64   ReadOperationCount;
;  uint64   ReadTransferCount;
;  uint32   SessionId;
;  string   Status;
;  datetime TerminationDate;
;  uint32   ThreadCount;
;  uint64   UserModeTime;
;  uint64   VirtualSize;
;  string   WindowsVersion;
;  uint64   WorkingSetSize;
;  uint64   WriteOperationCount;
;  uint64   WriteTransferCount;


;WinGet,pid,pid, ahk_exe InnovyzeWC.exe
;msgbox, % getInfoLiteVersion(pid)
;return




getInfoLiteVersion(pid){
  for Item in ComObjGet( "winmgmts:" ).ExecQuery("Select * from Win32_Process") {
      details := "CMD:" Item.CommandLine "`r`nName:" Item.Name "`r`nPath" Item.ExecutablePath "`r`nHandle:" Item.Handle "`r`nPID:" Item.ProcessId
      if item.Name = "InnovyzeWC.exe" {
        if item.ProcessId = pid {
          name := instr(item.CommandLine,"/asset") ? "IN" : "ICM"
          RegexMatch(FGP_Value(Item.ExecutablePath,"File version"),"(\d+\.\d+).+",match)
          num := match1
          
          return name . "-" .  num
        }
      }
  }
}



/*  FGP_Init()
 *		Gets an object containing all of the property numbers that have corresponding names. 
 *		Used to initialize the other functions.
 *	Returns
 *		An object with the following format:
 *			PropTable.Name["PropName"]	:= PropNum
 *			PropTable.Num[PropNum]		:= "PropName"
 */
FGP_Init() {
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

/*  FGP_Value(FilePath, Property)
 *		Gets a file property value.
 *	Parameters
 *		FilePath	- The full path of a file.
 *		Property	- Either the name or number of a property.
 *	Returns
 *		If succesful the file property value is returned. Otherwise:
 *		0			- The property is blank.
 *		-1			- The property name or number is not valid.
 */
FGP_Value(FilePath, Property) {
	static PropTable := FGP_Init()
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







