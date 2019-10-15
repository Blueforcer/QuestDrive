B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Service
Version=9.3
@EndOfDesignText@
#Region  Service Attributes 
	#StartAtBoot: true
	
#End Region

Sub Process_Globals
	'These global variables will be declared once when the application starts.
	'These variables can be accessed from all modules.

End Sub

Sub Service_Create

End Sub

Sub Service_Start (StartingIntent As Intent)
	If File.Exists(File.DirDefaultExternal,"autostart") Then
		StartService(ServerService)
	End If
	Service.StopAutomaticForeground
End Sub

Sub Service_Destroy

End Sub
