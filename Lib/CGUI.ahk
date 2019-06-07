#NoEnv ;Leave this here if you don't want weird ListView icon behavior (and possibly other side effects)

;Assume no initialisation code - note: initialisation code should be in __new() method.
;https://www.autohotkey.com/boards/viewtopic.php?f=76&t=65142&p=279708#p279708
GoTo CGUI_END 


;GUI core code
#include %A_LineFile%\..\CGUICore.ahk

;Include CControl
;  CControl requires both EventHandler and Delegate
#include *i %A_LineFile%\..\EventHandler.ahk
#include *i %A_LineFile%\..\Delegate.ahk
#include *i %A_LineFile%\..\CControl.ahk

;All the below scripts require CControl
#include *i %A_LineFile%\..\CTextControl.ahk
#include *i %A_LineFile%\..\CEditControl.ahk
#include *i %A_LineFile%\..\CButtonControl.ahk
#include *i %A_LineFile%\..\CCheckboxControl.ahk
#include *i %A_LineFile%\..\CChoiceControl.ahk
#include *i %A_LineFile%\..\CListViewControl.ahk
#include *i %A_LineFile%\..\CLinkControl.ahk
#include *i %A_LineFile%\..\CGroupBoxControl.ahk
#include *i %A_LineFile%\..\CStatusBarControl.ahk
#include *i %A_LineFile%\..\CTreeViewControl.ahk
#include *i %A_LineFile%\..\CTabControl.ahk
#include *i %A_LineFile%\..\CProgressControl.ahk
#include *i %A_LineFile%\..\CSliderControl.ahk
#include *i %A_LineFile%\..\CHotkeyControl.ahk
#include *i %A_LineFile%\..\CActiveXControl.ahk

;Include CPictureControl:
#include *i %A_LineFile%\..\gdip.ahk
#include *i %A_LineFile%\..\CPictureControl.ahk

;Other useful controls
#include *i %A_LineFile%\..\CFileDialog.ahk
#include *i %A_LineFile%\..\CFolderDialog.ahk
#include *i %A_LineFile%\..\CEnumerator.ahk
#include *i %A_LineFile%\..\CMenu.ahk

;UNTESTED WIP:
;  #include %A_LineFile%\..\CCompoundControl.ahk
;  #include %A_LineFile%\..\CPathPickerControl.ahk
;  #include %A_LineFile%\..\Parse.ahk

;POTENTIAL CONTROLS:
;  * Toolbar
;  * Ribbon
;  * ...?

;Required to prevent label pointing to function.
CGUI_END:
{

}


;;DEBUGGING:
;if true {
;  traytip Loaded, Loaded
;  sleep, 3000
;  ExitApp
;}
