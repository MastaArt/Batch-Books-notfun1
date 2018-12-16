/*  
[INFO] 

NAME = Batch Books
VERSION = 1.0.1
AUTHOR = Vasily Lukyanenko
DEV = 3DGROUND
CUSTOMER = Andrew Andreyuk
SKYPE = notfun1
HELP = 

[INSTALL]

MACRO=BatchBooks
CAT=3DGROUND
TEXT=Batch Books
ICON=#("PhysX_Main", 30)

[1.0.0]

* First release =

[1.0.1]

- BugFix: texmap_diffuse for non geometry objects =

[ABOUT]

- Creates books collections=
- Render books scenes=
- Pack books scenes=

[TEST]

[SCRIPT]
*/	

try(closeRolloutFloater fBatchBooks)catch()
global fBatchBooks = newRolloutFloater "Batch Books" 280 850

global _BATCH_BOOKS_STEP1
global BitmapTypes = #(Bitmaptexture, CoronaBitmap)

fn trim s c: " " = trimRight (trimLeft s c) c

fn getScriptInfo s releaseInfo: "" =
(		
	if(releaseInfo != "") do
	(
		r = getINISetting s releaseInfo
		return r
	)
	
	v = getINISetting s "INFO" "VERSION"
	a = getINISetting s "INFO" "AUTHOR"
	n = getINISetting s "INFO" "NAME"
	o = getINISetting s "ABOUT"
	c = getINISetting s "INFO" "DEV"
	h = getINISetting s "INFO" "HELP"
	
	r = for i in (getINISetting s) where i != "ABOUT" and i != "SCRIPT" and i != "COPY" collect i
	
	return #(n, a, v, o, r, c, h)
)

fn getMaxVersion =
(
	v = maxVersion()
	v = (v[1] / 1000) - 2
	
	a = 2000 + v
	
	o = case v of 
	(
		11: #(2010,2011)
		12: #(2010,2011,2012)
		default: #(a - 3, a - 2, a - 1, a)		
	)
	
	return (for i in o collect i as string)
)

fn resolvePaths =
(
	ATSOps.Visible = false
	ATSOps.Visible = true
	
	ATSOps.ExcludeOutputFiles = true
	actionMan.executeAction -841213575 "2"  
	actionMan.executeAction -841213575 "16" 
	actionMan.executeAction -841213575 "2"  
	actionMan.executeAction -841213575 "17" 
	ATSOps.ClearSelection() 
	ATSOps.refresh()
	gc()
	
	ATSOps.Visible = false	
)

fn getFullPath p = (	
	--return mapPaths.getFullFilePath (filenameFromPath  p)
	return pathConfig.normalizePath ((p as AssetUser).GetFullFilePath())
)

fn showTooltip c t =
(
	toolTip = dotnetobject "System.Windows.Forms.ToolTip"
	toolTip.SetToolTip c t   
	--toolTip.Active = true    
	toolTip.isBalloon = true
	toolTip.InitialDelay = 100
	toolTip.AutoPopDelay = 500
	toolTip.ReshowDelay = 50
	toolTip.ToolTipTitle = "Warning!"
	toolTip.Show t c 3000	
	toolTip.ToolTipIcon = (dotnetclass "System.Windows.Forms.ToolTipIcon").Warning
)

fn stripName n = (
	nn = filterString n "_"
	if(nn.count ==  0) do return undefined
	if(nn.count == 1) do return nn[1]
	
	s = ""
	for i in 1 to nn.count - 1 do (
		s += nn[i]
		if(i != (nn.count - 1)) do s += "_"
	)
	
	return s
)

fn useSettings k v type:#get =
(
	f = getThisScriptFilename() + ".ini"
	case type of
	(
		#set: setIniSetting f "SETTINGS" k v
		default: getIniSetting f "SETTINGS" k
	)
)

fn isVray =
(
	rr = renderers.current
	if(matchPattern (rr as string) pattern:"V_Ray_Adv*") do return true
	return false
)

fn boost = if (((maxVersion())[1] / 1000) >= 13) do windows.processPostedMessages() 


fn freezeUi =
(
  	source = ""
  	source += "using System;\n"
  	source += "using System.Runtime.InteropServices;\n"
  	source += "class WindowsGhosting\n"
  	source += "{\n"
  	source += " [DllImport(\"user32.dll\")]\n"
  	source += " public static extern void DisableProcessWindowsGhosting();\n"
  	source += "}\n"
  
  	csharpProvider = dotnetobject "Microsoft.CSharp.CSharpCodeProvider"
  	compilerParams = dotnetobject "System.CodeDom.Compiler.CompilerParameters"
  
  	compilerParams.GenerateInMemory = on
  	compilerResults = csharpProvider.CompileAssemblyFromSource compilerParams #(source)
  
  	assembly = compilerResults.CompiledAssembly
  	windowsGhosting = assembly.CreateInstance "WindowsGhosting"
  	windowsGhosting.DisableProcessWindowsGhosting()
)

fn getOpenMaxFiles = 
(
	f = #()
	
	d = dotNetObject "System.Windows.Forms.OpenFileDialog" 
	d.title = "Select Files"
	d.Multiselect = true
	d.Filter = "3dsmax (*.max)|*.max"
	d.FilterIndex = 1
	
	result = d.showDialog() 
	result.ToString() 
	result.Equals result.OK 
	result.Equals result.Cancel 
	
	f = d.fileNames 
			 
	return f
)

struct zip
(
	dirs = #(),
	files = #(),
	
	fn getRecusive d =
	(		
		c = getDirectories (d + "*")
		f = getFiles (d + "*")
		join dirs c
		join files f
		for i in c do getRecusive i
	),
	fn writeFile f t =
	(
		local tmp
		try(tmp = createFile f) catch (return false)			
		format t to:tmp
		flush tmp
		close tmp
				
		return true
	),
	
	fn br t =
	(
		return "\"" + t + "\""
	),
	
	fn rmDir d =
	(
		cmd = "RMDIR " + (br d) + " /S /Q"
		hiddendosCommand cmd 				
	),
	
	fn packFiles source: "" target: "" name: "tmpzip" del: false =
	(
		dirs = #()
		files = #()
		
		makeDir @"C:\temp\"
		makeDir target
		tmp = @"C:\temp\ziptmp.txt" 
		maxZip = (getDir #maxRoot) + "maxzip.exe"
			
		source = (trimRight source "\\") + "\\"
		target = (trimRight target "\\") + "\\"
		
		if(not doesFileExist source or source.count < 2) do return false
		if(not doesFileExist target or target.count < 2) do return false
		
		getRecusive source
		
		if(files.count == 0) do return false
		
		if(doesFileExist tmp) do deleteFile tmp
		t = ""		
		for i in files do t += (substituteString i source "") + "\n"
		writeFile tmp t
		
		curDir = sysInfo.currentDir
		sysInfo.currentDir = source
		out = target + name + ".zip"
		
		cmd = (br maxZip) + " " + (br out) + " @" + tmp
		
		hiddendosCommand cmd exitcode:&exitcode
		sysInfo.currentDir = curDir 
		
		if(del == true) do rmDir source
		
		if(exitcode == 0) do return true 
		return false
	)
)


rollout _BATCH_BOOKS_STEP1 "STEP 1: Create Books Collections"
(
	group "Select Books Variations" (
		listbox lbxBooksVars ""
		button btnSelectBooksPath "Load Books" across: 2 width: 100 height: 25 offset: [0, 5]
		button btnClearBooksLibs "Clear All" width: 100 height: 25 offset: [0, 5]
	)
	
	group "Books Covers Path" (
		edittext edtBooksCoverPath "" readonly: true height: 25 across: 2 align: #left fieldwidth: 200
		button btnLoadBooksCover "..." width: 35 height: 25 align: #right
	)
	
	group "Settings" (
		spinner spnBooksCombinations "Unique combinations for each variation:" type: #integer range: [1, 999, 2] fieldwidth: 35
	)
	
	button btnCreateBooksCombinations "Create Books Combinations" height: 35 width: 240 offset: [0, 12]
	
	-------------------
		
	
	fn getBooksVars = (
		lbxBooksVars.items = #()
		ini = getThisScriptFilename() + ".ini"
		f = getIniSetting ini "BOOKS_VARS" 		
		libs = for i in f where doesFileExist i collect i 				
		if(libs.count == 0) do return undefined		
				
		lbxBooksVars.items = for i in libs collect getFileNameFile i
				
		return libs
	)
	
	fn getBooksCombinations = (
		v = useSettings "BOOKS_COMBINATIONS" undefined type:#get
		if(v == "") do spnBooksCombinations.value = 3
		spnBooksCombinations.value = v as integer
	)
	
	fn clearBooksVars = (
		q = queryBox "Do you really want to clear all books variations from list?" title: "Confirm?"
		if(not q) do return false
		
		ini = getThisScriptFilename() + ".ini"
		delIniSetting ini "BOOKS_VARS"				
		lbxBooksVars.items = #()
	)
	
	fn loadBooksCoverPath = (
		v = useSettings "BOOKS_COVERS" undefined type:#get
		if(v != "") do (
			edtBooksCoverPath.text = v		
			return v
		)
		edtBooksCoverPath.text = ""
		return ""
	)
	
	fn getRandomTexList t v = (
		c = t.count
		o = #()
		
		if(c < v) do v = c
		
		while o.count < v do (
			ii = random 1 c	
			appendIfUnique o t[ii]
		)
				
		return o
	)
	
	on btnSelectBooksPath pressed do
	(						
		f = getOpenMaxFiles()			
		if(f.count == 0) do return false		
		ini = getThisScriptFilename() + ".ini"		
		--delIniSetting ini "BOOKS_VARS"				
		for i in f do setIniSetting ini "BOOKS_VARS" i ""			
		libs = getBooksVars()			
	)
	
	on btnLoadBooksCover pressed do (
		f = getSaveFileName filename: "DO NOT CHANGE NAME" caption:"Save File" types:"JPEG (*.jpg)|*.jpg"
		if(f == undefined) do return false
		
		p = getFileNamePath f
				
		useSettings "BOOKS_COVERS" p type:#set
		
		loadBooksCoverPath()
	)
		
	on spnBooksCombinations changed v do (
		useSettings "BOOKS_COMBINATIONS" (v as string) type:#set
	)
	
	on btnClearBooksLibs pressed do clearBooksVars()
	
	on btnCreateBooksCombinations pressed do (
		q = queryBox ("Do you really want to create books combinations?") title: "Confirm?"
		if(not q) do return false
		
		szBooksVars = getBooksVars()
		
		if(isVray() == false) do return messageBox "V-Ray not assigned!" title: "Error!"
		if(szBooksVars == undefined) do return messageBox "Please select at least one book variation!" title: "Error!"
		if(edtBooksCoverPath.text == "") do return messageBox "Please choose books covers path!" title: "Error!"
				
		obj = $'Book_main'
		if(obj == undefined) do return messageBox "Book_main object with material not found!" title: "Error!"
		if(obj.material == undefined) do return messageBox "Book_main has no material!" title: "Error!"
		
		origMaterial = copy obj.material
		origMaxFile = maxFilePath + maxFileName
		
		if(origMaxFile == "") do return messageBox "Please open the scene for render!" title: "Error!"
		
		f = getSaveFileName filename: "DO NOT CHANGE NAME" caption:"Save File" types:"3dsmax (*.max)|*.max"
		if(f == undefined) do return false
		p = getFileNamePath f
		
		vars = getBooksVars()
		
		progressStart "Books in process..."
		escapeEnable = true
					
		for s in 1 to vars.count do (
			for i in 1 to spnBooksCombinations.value do (
				resetMaxFile #noPrompt 
				mergeMaxFile vars[s] #noRedraw #autoRenameDups #renameMtlDups quiet: true 
				disableSceneRedraw()
			
				tex = getFiles (edtBooksCoverPath.text + "*.jpg")
				
				objs = geometry as array
				v = objs.count
				
				list = getRandomTexList tex v
				
				fileName = (getFileNameFile vars[s])
				
				for ii in 1 to v do (
					mm = copy origMaterial
					objs[ii].material = mm
					objs[ii].material.texmap_diffuse.filename = list[ii]
					objs[ii].material.name = fileName + "_" + (ii as string)
				)
				
				nn = p + fileName + "_" + (i as string) + ".max"
				saveMaxFile nn quiet: true
			)
			if(getProgressCancel()) do exit
			progressUpdate (100 * s / vars.count)
		)	
		
		progressEnd()
		
		enableSceneRedraw()
		enableSceneRedraw()
		enableSceneRedraw()
		
		loadMaxFile origMaxFile useFileUnits: true quiet: true
		
		enableSceneRedraw()
		enableSceneRedraw()
		enableSceneRedraw()
	)
	
	on _BATCH_BOOKS_STEP1 open do (
		getBooksVars()		
		getBooksCombinations()
		loadBooksCoverPath()
	)
)

fn getSortedCamList = (
	cc = for i in cameras as array where classOf i != Targetobject collect i.name
	sort cc	
	l = for i in cc collect execute ("$'" + i + "'")
	return l
)

fn animateCamera = (
	cams = getSortedCamList()
	c1 = cams[1]
	if(c1 == undefined) do return false
		
	sliderTime = 0f
	animatedCam = freeCamera fov: c1.fov name: "Animated Camera Render"
		
	animate on (
		for c in 1 to cams.count do (
			at time (c-1) (
				animatedCam.transform = cams[c].transform
				animatedCam.pos = cams[c].pos
			)
		)
	)

	animationRange = interval 0 (cams.count-1)
	
	return animatedCam
)

rollout _BATCH_BOOKS_STEP2 "STEP 2: Render & Pack"
(
	group "Select Scenes For Batch Render && Pack" (
		listbox lbxBooksVars ""
		button btnSelectBooksPath "Load Scenes" across: 2 width: 100 height: 25 offset: [0, 5]
		button btnClearBooksLibs "Clear All" width: 100 height: 25 offset: [0, 5]
	)
	
	group "Choose Action" (		
		radiobuttons rdoAction "" labels: #("Render", "Pack", "Render && Pack") columns: 1 align: #left default: 3
	)
	
	group "Render" (
		edittext edtBatchRenderPath "" readonly: true height: 25 across: 2 align: #left fieldwidth: 200
		button btnSetBatchRenderPath "..." width: 35 height: 25 align: #right
		
		button btnRenderAndPack "Render & Pack" height: 35 width: 240 offset: [0, 12]
	)
	

	fn changeButtonStatus = (		
		case rdoAction.state of (
			1: btnRenderAndPack.caption = "Render"
			2: btnRenderAndPack.caption = "Pack"
			default: btnRenderAndPack.caption = "Render & Pack"
		)			
	)
	
	fn getBooksScenes = (
		lbxBooksVars.items = #()
		ini = getThisScriptFilename() + ".ini"
		f = getIniSetting ini "BOOKS_TO_RENDER" 		
		libs = for i in f where doesFileExist i collect i 				
		if(libs.count == 0) do return undefined		
				
		lbxBooksVars.items = for i in libs collect getFileNameFile i
				
		return libs
	)


	fn clearBooksVars = (
		q = queryBox "Do you really want to clear list?" title: "Confirm?"
		if(not q) do return false
		
		ini = getThisScriptFilename() + ".ini"
		delIniSetting ini "BOOKS_TO_RENDER"				
		lbxBooksVars.items = #()
	)
	
	fn batchPack ff = (
		zipper = zip()
		bb = edtBatchRenderPath.text
		
		resolvePaths()
		
		fileName = getFilenameFile ff
		outFolder = bb + fileName
		
		_OBJ = outFolder + @"\OBJ\"
		_FBX = outFolder + @"\FBX\"
		_MAX = outFolder + @"\MAX\"
		_3DDD = outFolder + @"\3DDD\"
		
		makeDir _OBJ all: true
		makeDir _FBX all: true
		makeDir _MAX all: true
		makeDir _3DDD all: true
				
		for i in getClassInstances Bitmaptex do (
			n =  filenameFromPath i.filename
			k = getFullPath i.filename
						
			if(not doesFileExist ((i.filename as AssetUser).GetFullFilePath())) do print ("Error: Not found texture " + i.filename)
			
			copyFile k (_OBJ + n)
			copyFile k (_FBX + n)
			copyFile k (_MAX + n)
			copyFile k (_3DDD + n)
			i.filename = n
				
			if(getProgressCancel()) do return false
		)
		
		FBXExporterSetParam "FileVersion" "FBX201200"
		
		if(getProgressCancel()) do return false
		exportFile (_OBJ + fileName + ".obj") #noPrompt 
		if(getProgressCancel()) do return false
		exportFile (_FBX + fileName + ".fbx") #noPrompt 
		
		if(getProgressCancel()) do return false
		exportFile (_3DDD + fileName + ".obj") #noPrompt 
		if(getProgressCancel()) do return false
		exportFile (_3DDD + fileName + ".fbx") #noPrompt 
		
		version = getMaxVersion()
		version = version[1] as integer
		
		if(getProgressCancel()) do return false
		saveMaxFile (_MAX + fileName + ".max") saveAsVersion: version quiet: true
		if(getProgressCancel()) do return false
		saveMaxFile (_3DDD + fileName + ".max") saveAsVersion: version quiet: true
		if(getProgressCancel()) do return false
			
		zipper.packFiles source: _OBJ target: outFolder name: "OBJ" del: true
		zipper.packFiles source: _FBX target: outFolder name: "FBX" del: true
		zipper.packFiles source: _MAX target: outFolder name: "MAX" del: true
		zipper.packFiles source: _3DDD target: outFolder name: "3DDD" del: true
	)
	
	fn batchRender ff = (
		
		vr = renderers.current
		cams = cameras as array
		bb = edtBatchRenderPath.text
		
		tmp = @"C:\temp\temp_out_render_books_.jpg"
		for ii in (getFiles @"C:\temp\temp_out_render_books_*.jpg") do deleteFile ii
		deleteFile tmp
		
		fileName = getFileNameFile ff
		rendersDir = bb + fileName + @"\Renders\"
		makeDir rendersDir all: true
		n = rendersDir + fileName + "_.jpg"
		
		c = animateCamera()
		viewport.setCamera c
		if (renderSceneDialog.isOpen()) do renderSceneDialog.close() 
			
		rendSaveFile = true
		rendOutputFilename = tmp		
		rendTimeType = 2
			
		vr.output_splitgbuffer = true
		vr.output_splitfilename = n	
			
		split_bitmap = Bitmap 10 10 fileName: n	
		save split_bitmap
		close split_bitmap
			
		vr.output_splitbitmap = split_bitmap
		deleteFile n
			
		renderSceneDialog.update()
			
		max quick render
	)
	
	on rdoAction changed v do (
		changeButtonStatus()		
	)
	
	on btnSelectBooksPath pressed do
	(						
		f = getOpenMaxFiles()			
		if(f.count == 0) do return false		
		ini = getThisScriptFilename() + ".ini"		
		--delIniSetting ini "BOOKS_TO_RENDER"				
		for i in f do setIniSetting ini "BOOKS_TO_RENDER" i ""			
		libs = getBooksScenes()			
	)
	
	fn loadRenderPath = (
		v = useSettings "RENDER_TO" undefined type:#get
		if(v != "") do (
			edtBatchRenderPath.text = v		
			return v
		)
		edtBatchRenderPath.text = ""
		return ""
	)
	
	on btnSetBatchRenderPath pressed do (		
			
		f = getSaveFileName filename: "DO NOT CHANGE NAME" caption:"Save File" types:"JPEG (*.jpg)|*.jpg"
		if(f == undefined) do return false
		
		p = getFileNamePath f
				
		useSettings "RENDER_TO" p type:#set
		
		loadRenderPath()
	)
	
	on btnClearBooksLibs pressed do clearBooksVars()
	
	on _BATCH_BOOKS_STEP2 open do (
		getBooksScenes()	
		loadRenderPath()
	)
	
	on btnRenderAndPack pressed do (		
		q = queryBox ("Do you really want to continue ?") title: "Confirm?"
		if(not q) do return false	
		
		vr = renderers.current
		cams = cameras as array
		bb = edtBatchRenderPath.text
		
		if(rdoAction.state == 1 or rdoAction.state == 3) do (
			if(not isVray()) do return messageBox "V-Ray not assigned!" title: "Error!"	
			if(maxFileName == "" ) do return messageBox "Is it correct render scene? Seems the clear scene!" title: "Warning!"	
			if(cams.count == 0) do return messageBox "Cameras not found!" title: "Warning!"	
		)
				
		if(bb == "") do return messageBox "Please select Render path!" title: "Warning!"	
		scenes = getBooksScenes()
		
		origMaxFile = maxFilePath + maxFileName
		
		if(rdoAction.state == 3 or rdoAction.state == 1) do (
			progressStart "Books in process..."
			escapeEnable = true	
			for s in 1 to scenes.count do (
				loadMaxFile origMaxFile useFileUnits: true quiet: true
				mergeMaxFile scenes[s] #noRedraw #autoRenameDups #renameMtlDups quiet: true 
				batchRender scenes[s]
				progressUpdate (100 * s / scenes.count)
			)	

			progressEnd()	
		)

		if(rdoAction.state == 3 or rdoAction.state == 2) do (			
			progressStart "Pack in process..."
			escapeEnable = true	
			for s in 1 to scenes.count do (
				resetMaxFile #noPrompt
				mergeMaxFile scenes[s] #noRedraw #autoRenameDups #renameMtlDups quiet: true 
				batchPack scenes[s]
				progressUpdate (100 * s / scenes.count)
			)	
			progressEnd()	
		)
				
		loadMaxFile origMaxFile useFileUnits: true quiet: true
	)
)

rollout _rAbout "About" 
(
	label lblName "" 
	label lblVer "" 
	
	label lblAuthor "" height: 30
	label lblCopy ""  height: 30
	
	local c = color 200 200 200 
	hyperLink href1 "http://3dground.net/" address: "http://3dground.net/" align: #center hoverColor: c visitedColor: c offset: [0, 20]
	
	on _rAbout open do
	(		
		i = getScriptInfo (getThisScriptFilename())
			
		lblName.caption = i[1]
		lblAuthor.caption = i[2]
		lblVer.caption = i[3]
		lblCopy.caption = i[6]
	)
)

addRollout _BATCH_BOOKS_STEP1 fBatchBooks 
addRollout _BATCH_BOOKS_STEP2 fBatchBooks rolledup: false
addRollout _rAbout fBatchBooks rolledUp:true