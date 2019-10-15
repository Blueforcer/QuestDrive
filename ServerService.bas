B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Service
Version=9.3
@EndOfDesignText@
#Region  Service Attributes 
	#StartAtBoot: False
#End Region

Sub Process_Globals
	Private Server As HttpServer
	Private templates As Map
	Private su As StringUtils
	Private cannotdelete As Boolean
	Public Port = 7123 As Int
	Private root As String
	Public DeviceIP As String
	Public ClientIP As String
	Public IsRunning As Boolean
	Public Greeting As String
	Dim hg As PhoneEvents
	Dim bat As Int
	Public ftp As FTPServer
End Sub

Sub Service_Create
	Try
		Server.Initialize("Server")
		Server.Start(Port)
		templates.Initialize
		hg.Initialize("hg")
		Dim n As Notification
		n.Initialize
		n.Icon = "icon"
		n.SetInfo("Http Server is running", "", Main)
		Service.StartForeground(1, n)
		If File.Exists(File.DirDefaultExternal,"useftp") Then
			ftp.Initialize
			ftp.SetPorts(51041, 51042, 51142)
			ftp.AddUser("quest", "drive")
			ftp.BaseDir = File.DirRootExternal
			ftp.Start
			IsRunning = True
		End If
		
	Catch
		ToastMessageShow("Server is already running in another application.",False)
	End Try
End Sub

Sub GetFreeSpace As Long
	Dim jo As JavaObject
	jo.InitializeNewInstance("java.io.File", Array(File.DirRootExternal))
	Return jo.RunMethod("getFreeSpace", Null)
End Sub

Sub Service_Start (StartingIntent As Intent)
	IsRunning=True
	Service.StopAutomaticForeground
End Sub

Sub Server_HandleRequest (Request As ServletRequest, Response As ServletResponse)
	Log(Request.RequestURI.SubString(1))
	Try
		ClientIP = Request.RemoteAddress
		Dim command As String = Request.GetParameter("query")
		If command <> "" Then
			HandleRemoteControl(Request, Response, command)
			Return
		End If
		Select True
			Case Request.RequestURI.Contains("remote_template.html")
				HandleRemotePageStart(Response)
			Case Request.RequestURI = "/"
				HandleMainPage (Request, Response)
			Case Request.RequestURI.StartsWith("/list/")
				HandleList (Request, Response)
			Case Request.RequestURI.StartsWith("/download/")
				SetContentType(Request.RequestURI, Response)
	
				Response.SendFile("", DecodePath(Request.RequestURI.SubString(9)))
			Case Request.RequestURI.StartsWith("/upload/")
				HandleUpload(Request, Response)
			Case Request.RequestURI.StartsWith("/delete/")
				HandleDeleteFile(Request, Response)
			Case Request.RequestURI.StartsWith("/mkdir/")
				HandleMakeFolder(Request, Response)
			Case Else 'send a file as a response (this section is enough in order to host a site)
				SetContentType(Request.RequestURI, Response)
				Response.SendFile(File.DirAssets, DecodePath(Request.RequestURI.SubString(1)))
		End Select
	Catch
		Response.Status = 500
		Log("Error serving request: " & LastException)
		Response.SendString("Error serving request: " & LastException)
	End Try
End Sub

Sub HandleMainPage(Request As ServletRequest, Response As ServletResponse)
	Dim p As Phone
	Dim Info As StringBuilder
	Dim MainPage As String = GetTemplate("main_template.html") 'load the template from the assets folder
	MainPage = MainPage.Replace("$APPLABEL$","QuestDrive")
	MainPage = MainPage.Replace("$DATE$", DateTime.Date(DateTime.Now))
	MainPage = MainPage.Replace("$TIME$", DateTime.Time(DateTime.Now))
	Info.Initialize
	Info.Append("Model: ").Append("<b>" &p.Model&"</b>").Append("<br/>")
	Info.Append("Battery: ").Append("<b>" & bat & "%" &"</b>").Append("<br/>")
	Info.Append("Free Space: ").Append("<b>" & $"$1.2{GetFreeSpace / 1024 / 1024 / 1024} GB"$&"</b>").Append("<br/>")
	MainPage = MainPage.Replace("$OTHERINFORMATION$", Info)
	Response.SetContentType("text/html")
	Response.SendString(MainPage)
End Sub

Sub HandleRemotePageStart(Response As ServletResponse)
	Dim Page As String = GetTemplate("remote_template.html") 'load the template just for replacing space holders such as link back to TOP
	Page = Page.Replace("$HOMELINK$", "http://" & DeviceIP & ":" & Port)
	Response.SendString(Page)
End Sub

Sub hg_BatteryChanged (Level As Int, Scale As Int, Plugged As Boolean, Intent As Intent)
	bat = Level
End Sub

Sub HandleRemoteControl(Request As ServletRequest, Response As ServletResponse, cmd As String)
	Dim Page As String = GetTemplate("remote_template.html") 'load the template from the assets folder
	Response.SetContentType("text/html")
	Log(cmd)
	Log(Request.GetParameter("descp"))
'	CallSubDelayed3(Main,"ExecuteCommand",cmd, "")
	Page = Page.Replace("$HOMELINK$", "http://" & DeviceIP & ":" & Port)
	Response.SendString(Page)
End Sub

Sub HandleUpload(Request As ServletRequest, Response As ServletResponse)
	Dim CurrentPath As String = DecodePath(Request.RequestURI.SubString("/upload/".Length))
	Dim upload As String = Request.GetUploadedFile("upfile")
	'copy the temporary file to the correct folder
	File.Copy(Server.TempFolder, upload, CurrentPath, Request.GetParameter("upfile")) 'the file name is sent as a parameter
	File.Delete(Server.TempFolder, upload) 'delete the temporary file.
	Response.SendRedirect("/list/" & EncodePath(CurrentPath)) 'redirect to the list page
End Sub

Sub HandleDeleteFile(Request As ServletRequest, Response As ServletResponse)
	SetContentType(Request.RequestURI, Response)
	Dim FullPath As String = DecodePath(Request.RequestURI.SubString("/delete/".Length))
	Dim CurrentDir As String = FullPath.SubString2(0, FullPath.LastIndexOf("/"))
	cannotdelete = False
	If File.IsDirectory("", FullPath) Then
		Dim lfiles = File.ListFiles(FullPath) As List
		If lfiles.Size > 0 Then
			cannotdelete = True
		Else
			Log(File.Delete("", FullPath))
		End If
	Else
		Log(File.Delete("", FullPath))
	End If
	Response.SendRedirect("/list/" & EncodePath(CurrentDir)) 'redirect to the list page
End Sub

Sub HandleMakeFolder(Request As ServletRequest, Response As ServletResponse)
	SetContentType(Request.RequestURI, Response)
	Dim FullPath As String = DecodePath(Request.RequestURI.SubString("/mkdir/".Length))
	Dim CurrentDir As String = FullPath.SubString2(0, FullPath.LastIndexOf("/"))
	Dim NewFolder As String = FullPath.SubString(FullPath.LastIndexOf("/") + 1)
	File.MakeDir(CurrentDir,NewFolder)
	Response.SendRedirect("/list/" & EncodePath(CurrentDir)) 'redirect to the list page
End Sub

Sub HandleList(Request As ServletRequest, Response As ServletResponse)
	Dim d As Long
	Dim s As String
	Dim CurrentPath As String = DecodePath(Request.RequestURI.SubString(6)) 'remove /list/
	If CurrentPath = "" Then CurrentPath = File.DirRootExternal.SubString(1) 'remove the first slash
	If CurrentPath.Contains("functions.js") Then Return
	If CurrentPath.Contains("icon.png") Then Return
	Dim listSb As StringBuilder
	listSb.Initialize
	listSb.Append("<button class='btn btn-info btn-sm ' onclick='askNewFolder(" & Chr(34) & "/mkdir/" & CurrentPath & Chr(34) & ")'>New Directory</Button><br><br>" & CRLF)
	listSb.Append("<small><b>Files in ").Append(CurrentPath).Append(":</b></small><br>" & CRLF)
	listSb.Append($"<table class="table" >"$ & CRLF)
	listSb.Append($"
	<form name="upform" method='POST' enctype="multipart/form-data" action="${"/upload/" & EncodePath(CurrentPath)}" onsubmit="return validateUpload()">
	<div class="input-group mb-3">
	<div class="custom-file">
	<input Type="file" name="upfile" class="custom-file-input" id="inputGroupFile02">
	<label class="custom-file-label" For="inputGroupFile02">Choose File</label>
	</div>
	<div class="input-group-append">
	<button  Type="submit" value="Upload" class="btn btn-primary">Upload</button>
	</div>
	</div>
	</div>
	</form>
	"$)
	listSb.Append($"<thead >
    <tr>
      <th style='background-color:#F8F9FA;' scope="col">#</th>
      <th style='background-color: #F8F9FA;' scope="col">Modified</th>
      <th style='background-color: #F8F9FA;' scope="col">Size</th>
      <th style='background-color: #F8F9FA;' scope="col">Actions</th>
    </tr>
  </thead>
  <tbody>"$)
	Dim all, files, folders As List
	files.Initialize
	folders.Initialize
	all = File.ListFiles(CurrentPath)
	If all.IsInitialized = False Then
		Response.SendString("Cannot access folder.")
		Return
	End If
	For Each f As String In all
		If File.IsDirectory(CurrentPath, f) Then
			folders.Add(f)
		Else
			files.Add(f)
		End If
	Next
	folders.Add("..") 'up folder
	folders.SortCaseInsensitive(True)
	files.SortCaseInsensitive(True)
	For Each f As String In folders
		If f = ".." Then
			root = EncodePath(File.Combine(CurrentPath, f))
			listSb.Append("<tr><td><a class='upd' href='/list/").Append(EncodePath(File.Combine(CurrentPath, f))).Append("/'>").Append(f.Replace("emulated","Internal SD")).Append("</a>&nbsp;&nbsp;&nbsp;</td>" & CRLF)
		Else If f.ToLowerCase.Contains("emulated") Then
			listSb.Append("<tr><td><a class='pho' href='/list/").Append(EncodePath(File.Combine(CurrentPath, f))).Append("/'>").Append(f.Replace("emulated","Internal SD")).Append("</a>&nbsp;&nbsp;&nbsp;</td>" & CRLF)
		Else If f.ToLowerCase.Contains("sdcard") Or f.ToLowerCase.Contains("microsd") Or f.ToLowerCase.Contains("sd-")  Or f.ToLowerCase.Contains("_sd")Then
			listSb.Append("<tr><td><a class='sdc' href='/list/").Append(EncodePath(File.Combine(CurrentPath, f))).Append("/'>").Append(f.Replace("emulated","Internal SD")).Append("</a>&nbsp;&nbsp;&nbsp;</td>" & CRLF)
		Else If f.ToLowerCase.Contains("usb") Then
			listSb.Append("<tr><td><a class='usb' href='/list/").Append(EncodePath(File.Combine(CurrentPath, f))).Append("/'>").Append(f.Replace("emulated","Internal SD")).Append("</a>&nbsp;&nbsp;&nbsp;</td>" & CRLF)
		Else
			listSb.Append("<tr><td><a class='fld' href='/list/").Append(EncodePath(File.Combine(CurrentPath, f))).Append("/'>").Append(f.Replace("emulated","Internal SD")).Append("</a>&nbsp;&nbsp;&nbsp;</td>" & CRLF)
		End If
		If (f <> "..") Then listSb.Append("<td></td><td></td><td style='padding-right: 0'><button  class='btn btn-danger fa fa-trash-o btn-sm' style='margin-left: 10px; margin-right: 10px;' onclick='askDelete(" & Chr(34) & "/delete/" & EncodePath(File.Combine(CurrentPath, f)) & Chr(34) & ")'></button></td>")
	Next
	

'	If files.Size > 0 Then listSb.Append("<tr><th></th><th>Name</th><th></th><th>Last Modified</th><th>Size</th><th></th></tr>" & CRLF) '==================================
	For Each f As String In files
		d = File.LastModified(CurrentPath, f)
		s = FormatSize(File.Size(CurrentPath, f))
		listSb.Append($"<tr><td><a class='${geticon(f)}' href='#'></a>&nbsp;&nbsp;&nbsp;"$)
		listSb.Append(f).Append("</td><td>" & DateTime.Date(d) & " " & DateTime.Time(d) & "</td><td style='text-align: right'>" & s &"</td><td style='padding-right: 0'>").Append("<a href='/download/").Append(EncodePath(File.Combine(CurrentPath, f))).Append("'><button class='btn btn-success fa fa-download btn-sm' style='margin-left: 10px; margin-right: 10px;' ></button></a><button class='btn btn-danger fa fa-trash-o  btn-sm ' style='margin-left: 10px; margin-right: 10px;' onclick='askDelete(" & Chr(34) & "/delete/" & EncodePath(File.Combine(CurrentPath, f)) & Chr(34) & ")'></button></td>")
		
		listSb.Append("</tr>" & CRLF)
	Next
'	If files.Size > 0 Then listSb.Append("<tr><th></th><th>Name</th><th></th><th>Last Modified</th><th>Size</th><th></th></tr>" & CRLF) '==================================
	listSb.Append("  </tbody></table>" & CRLF)
	Dim listPage As String = GetTemplate("list_template.html")
	If cannotdelete Then
		listPage = listPage.Replace("$ERRMSG$", "1")
		cannotdelete = False
	Else
		listPage = listPage.Replace("$ERRMSG$", "0")
	End If
	listPage = listPage.Replace("$UPLOADACTION$", "/upload/" & EncodePath(CurrentPath))
	listPage = listPage.Replace("$LIST$", listSb)
	listPage = listPage.Replace("$HOMELINK$", "http://" & DeviceIP & ":" & Port)
	listPage = listPage.Replace("$LISTLINK$", "http://" & DeviceIP & ":" & Port & "/list/")
	listPage = listPage.Replace("$LISTCARD$", "http://" & DeviceIP & ":" & Port & "/list/" & root.SubString2(0,root.IndexOf("%2F")+3))
	Response.SetContentType("text/html")
	Response.SendString(listPage)
End Sub

Sub EncodePath(P As String) As String
	Return su.EncodeUrl(P, "UTF8")
End Sub

Sub DecodePath(S As String) As String
	Return su.DecodeUrl(S, "UTF8")
End Sub

Sub GetTemplate(Name As String) As String
	If templates.ContainsKey(Name) Then Return templates.Get(Name)
	Dim temp As String = File.ReadString(File.DirAssets, Name)
	templates.Put(Name, temp)
	Return temp
End Sub

Sub SetContentType(FileName As String, Response As ServletResponse)
	Dim extension, ContentType As String
	Dim m As Matcher = Regex.Matcher("\.([^\.]*)$", FileName) 'find the file extension
	If m.Find Then
		extension = m.Group(1).ToLowerCase
		Select extension
			Case "js"
				ContentType = "text/javascript"
			Case "gif", "png"
				ContentType = "image/" & extension
			Case "jpeg", "jpg"
				ContentType = "image/jpeg"
			Case "css", "xml", "php", "htm", "html", "cgi"
				ContentType = "text/" & extension
			Case "ico"
				ContentType = "image/x-icon"
			Case "", "txt", "dat", "rtf"
				ContentType = "text/plain"
			Case "mpg","mpeg"
				ContentType = "video/" & extension
			Case "mjpg"
				ContentType = "video/x-motion-jpeg"
			Case "m4v","mp4","mts"
				ContentType = "video/mp4"
			Case "mp3"
				ContentType = "audio/mp3"
			Case "wav"
				ContentType = "audio/wav"
			Case "mid"
				ContentType = "audio/midi"
			Case "pdf"
				ContentType = "application/pdf"
			Case "swf"
				ContentType = "application/x-shockwave-flash"
			Case "zip"
				ContentType = "application/zip"
			Case "doc"
				ContentType = "application/msword"
			Case "xls","xla","xlm","xlt","xlw"
				ContentType = "application/vnd.ms-excel"
			Case "ppt","pps","ppz"
				ContentType = "application/vnd.ms-powerpoint"
			Case "kmz"
				ContentType = "application/vnd.google-earth.kmz"
			Case "kml"
				ContentType = "application/vnd.google-earth.kml+xml"
			Case "apk"
				ContentType = "application/vnd.android.package-archive"
			Case "ods"
				ContentType = "application/vnd.oasis.opendocument.spreadsheet"
			Case "odt"
				ContentType = "application/vnd.oasis.opendocument.text "
			Case Else
				ContentType = "application/octet-stream"
		End Select
		'Add more:
		'http://webdesign.about.com/od/multimedia/a/mime-types-by-content-Type.htm
		'http://en.wikipedia.org/wiki/Internet_media_type
		'http://www.sitepoint.com/web-foundations/mime-types-complete-list/
		Response.SetContentType(ContentType)
	End If
End Sub

Sub Service_Destroy
	Server.Stop
	ftp.Stop
	Service.StopForeground(1)
	IsRunning = False
End Sub

Sub geticon(extension As String) As String
	If extension.EndsWith("mp4") Then
		Return "mov"
	End If
	If extension.EndsWith("jpg") Then
		Return "pho"
	End If
	Return "fle"
End Sub

Sub FormatSize(Size As Float) As String
   
	Dim unit() As String = Array As String(" Byte", " KB", " MB", " GB", " TB", " PB", " EB", " ZB", " YB")
   
	If (Size == 0) Then
		Return "N/A"
	Else
       
		Dim po,si As Double
		Dim i As Int
       
		i  = Floor(Logarithm(Size, 1024))
		po = Power(1024,i)
		si = Size / po
       
		Return NumberFormat(si,0,2) & unit(i)
       
	End If
   
End Sub