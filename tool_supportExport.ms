(--start code
	/*
	제작자 : 권진영 kwan jin young
	contact : finseag@gmail.com
	2020
		0323 : start.v01.0
		0324 : v01.1
		0325 : v01.2.0 연속익스포트 및 스킵기능추가.
		0327 : v01.2.1 옵션설정 저장기능 추가.
		0328 : v01.3.0 TimeTag 기능 추가.
		0329 : v01.3.1 TimeTag 수정 보안.
		0330 : v01.3.2 List 에 suffix 작동방식 수정 , callBack 함수추가.
		0331 : v01.4.0 세이브시 중복되는 이름 처리방식 변경. 그외 편의성 기능 추가.
		0408 : v01.5.0 bake root 기능 추가. 그외 편의성 배려 기능 추가.
		0426 : v01.5.1 bake root 에 rotation 추가.
	     0510 : v01.5.2 warning도 스킵되도록. 
		0515 : v01.5.3 animationRange 이동시 비정상적인 범위 입력될 가능성이 있는 부분 차단. / rotation 기능 특정 gimbal 값만 추가가능하게끔(임시기능) 
		0516 : v01.6.0 automatic skip Export , timaTag 사이즈 프리셋 설정 추가 , root 선택 버튼추가.
		0518 : v01.6.1 editMode 작동방식추가.
	*/
	global RFloater_supportExportAssign
	global R_spExportAssign_option
	global R_timeTagRange --for function. call back
	global fnReloadTag --for function. call back
	global arrTimeTagListP = #(#(),#(),#(),#(),#(),#(),#()) -- 1 exportName , 2 startF , 3 endF , 4 indexFrame , 5 showStr , 6 id , 7 TagName
		
	string_nameVersion = "tool_support Export v01.6.2"
	try(closeRolloutFloater RFloater_supportExportAssign) catch()
	RFloater_supportExportAssign = newRolloutFloater "" (0) (0)
	try(closeRolloutFloater RFloater_supportExportAssign) catch()
	
	local arr_exportorVersionSTR = #("FBX Export (Version: 2017.0.1)","FBX Export (Version: 2018.0)","FBX Export (Version: 2019.0)")
	local hwnd_nameStringJ = "FBX Export (Version: 2019.0)"
	local root_name = "root"
	local bool_ignoreCase = true --if true, ignore Case.
	local hwnd_nameStr2 = "Warnings and Errors"
	-----------------------------------------------
	local listSpExpObj = #()--1 : root , 2:root Name , 3:ref , 4:ref Name, 5:for show str ,6:stringName
	local targetBiped = undefined
	local LoadFiles
	local attrObjNameStr = "attr_objNode"
	local lastExportPath = @""
	local lastPathJ_ = "" -- << use reference variable &
	local savePathOption_ = (substituteString ((symbolicPaths.getPathValue 34)+"\\aSupportEXP") "\\" "\\\\")-- inArrFile_ini -> #(path , filename)
	local fileNameINI_ = "optionSupportEXP.ini"
	local arrTagFSamples_ini = #("tagList_samples01.ini")
	local ArrFile_ini = #(savePathOption_,fileNameINI_)
	local arrFile_iniSection = #("hwnd_strExport","export_Bone","timeTag_Size_Set")
	local arrFile_iniKeyVal = #(#(#("name","val1")),#(#("rootName","val1")),#(#("set_index","var1")))
	local sizeSet_forTimeTag = #(#(4,140,159),#(8,192,212),#(14,270,290),#(21,360,377))
	local dynamic_Line = 14
	local dynamic_height = 270
	local dynamic_floater_height = 315
	-----------------------------------------------
	--start function
	-----------------------------------------------
	
	fn fn_checkDirMake in_path bCreat:True =(
		bReturn = true
		if (getDirectories in_path).count == 0 do(
			if bCreat then(makeDir in_path)
			else(bReturn = false)
		)--end : if
		return bReturn
	)--end : fn_checkDirMake
	
	fn fn_checkExistFile_ini inArrFile_ini =(
		tempFullPath = inArrFile_ini[1] + "\\" +inArrFile_ini[2]
		if (getfiles tempFullPath).count == 0 do(return (""))
		return tempFullPath
	)--end : fn_checkExistFile_ini
	-----------------------------------------------initial setting start
	tempFPath_ = (ArrFile_ini[1] + "\\" +ArrFile_ini[2])
	if (fn_checkExistFile_ini ArrFile_ini) != "" do (
		init_indexNum = (getINISetting tempFPath_ "timeTag_Size_Set" "set_index") as integer -- if not exist value , return "" 			
		if init_indexNum >= 1 and init_indexNum <= (sizeSet_forTimeTag.count) do(
			dynamic_Line = sizeSet_forTimeTag[(init_indexNum)][1]
			dynamic_height = sizeSet_forTimeTag[(init_indexNum)][2]
			dynamic_floater_height = sizeSet_forTimeTag[(init_indexNum)][3]
		)
	)-----------------------------------------------initial setting end
	
	fn fn_existFileName inFullStr bUnique:True isFullPath:False fileType:".fbx"=(
		--if bUnique is true , will make unique name.
		tempFullPath = ""
		bFinish = True
		if not isFullPath do inFullStr += fileType
		if (getfiles inFullStr).count == 0 do(return (inFullStr))
		if bUnique do(
			tempCh = (getFilenamePath inFullStr) + (getfilenamefile inFullStr) + "_add"
			tempType = getfilenametype inFullStr
			idxC = 1
			while bFinish do(
				if (getfiles (tempCh + (idxC as string) + tempType)).count == 0 do (
					tempFullPath = tempCh + (idxC as string) + tempType
					bFinish = False; 
					exit;
				)--end : if
				if keyboard.escPressed do exit;
				idxC += 1
			)--end : while
		)--end : if
		return tempFullPath
	)--end : fn_existFileName
	
	fn fnArr_getVal_iniFile inFPath maxIter:35 inSection:"List01"=(
		enArr = #()
		for i in 1 to maxIter do(
			str_i = i as string
			if (hasINISetting inFPath inSection str_i) do(
				append enArr (getINISetting inFPath inSection str_i)
			)--end : if
		)--end : for i
		return enArr
	)--end : fnArr_getVal_iniFile
	
	fn fn_saveFile_ini inArrFile_ini inArr_Section inArr_keyVal =(
		fn_checkDirMake inArrFile_ini[1] bCreat:True
		in_File_ini = inArrFile_ini[1] + "\\" +inArrFile_ini[2]
		for i in 1 to inArr_Section.count do(
			for k in 1 to inArr_keyVal[i].count do(
				setINISetting in_File_ini inArr_Section[i] inArr_keyVal[i][k][1] inArr_keyVal[i][k][2]
			)--end : for k
		)--end : for i
	)--end : fn_saveFile_ini
	
	fn fn_saveFPath_ini inFPath inArr_Section inArr_keyVal =(
		for i in 1 to inArr_Section.count do(
			for k in 1 to inArr_keyVal[i].count do(
				setINISetting inFPath inArr_Section[i] inArr_keyVal[i][k][1] inArr_keyVal[i][k][2]
			)--end : for k
		)--end : for i
	)--end : fn_saveFPath_ini
	
	fn fn_getAllChildren Target &arraytemp =(
		for lo in Target.children do(
			append arraytemp lo
			fn_getAllChildren lo arraytemp
		)--end : for
	)--end : fn_getAllChildren

	fn fn_filterStringKeyword in_string in_keyword:"@" bo_ignoreCase:true bo_prefix:true =(
		if not (classof in_string) == String do return 0
		if not (matchPattern in_string pattern:("*"+in_keyword+"*") ignoreCase:(bo_ignoreCase)) do (return in_string)
		--tempArrStr = filterString in_string (in_keyword)
		indexStrT = 0
		for i in in_string.count to 1 by -1 do(
			if in_string[i] == (in_keyword) do (
				indexStrT = i
				exit
			)--end : if
		)--end : for i
		retStr =""
		if bo_prefix then(
			indexStrT -= 1
			if indexStrT < 1 do indexStrT = 1
			retStr = substring in_string 1 indexStrT
		)else(
			retStr = substring in_string indexStrT (indexStrT.count)
		)--end : if else
		return retStr
	)--end : fn_filterStringKeyword
	
	fn fnExistFileRename inFullStr bRename:True isFullPath:False fileType:".fbx"=(
		--if bUnique is true , will make unique name.
		tempFullPath = ""
		bFinish = True
		if not isFullPath do inFullStr += fileType
		if (getfiles inFullStr).count == 0 do(return (inFullStr))
		if bRename do(
			tempCh = (getFilenamePath inFullStr) + (getfilenamefile inFullStr) + "_bOld"
			tempType = getfilenametype inFullStr
			idxC = 1
			while bFinish do(
				if (getfiles (tempCh + (idxC as string) + tempType)).count == 0 do (
					tempNFullPath = tempCh + (idxC as string) + tempType
					chSuccess = (renameFile (inFullStr) (tempNFullPath))
					if chSuccess then (tempFullPath = inFullStr)
					else (tempFullPath = (fn_existFileName inFullStr bUnique:True isFullPath:isFullPath))
					bFinish = False; 
					exit;
				)--end : if
				if keyboard.escPressed do exit;
				idxC += 1
			)--end : while
		)--end : if
		return tempFullPath
	)--end : fnExistFileRename
	
	fn fn_nExportFBX arrTemp &lastPathJ_ saveName_:"" rootCount:1 customPath_:"" addNamePre:"" addNameSuf:"" skipAskPath:1 =(
		--skipAskPath 값이 1 인경우, 익스포트 한번만 한다는 의미. 이경우에는 save file name 에 추가적인 작업을 하지 않음.
		arr_temp_mainbody = #()
		arr_temp_mainhead = #()
		for i in arrTemp do(
			arr_temp_mainbody = #()
			fn_getAllChildren i arr_temp_mainbody
			append arr_temp_mainhead arr_temp_mainbody --this is for many root objects.
		)--end: for i --모든 차일드를 구함. 하지만 중복되서 배열로 들어가 있을 수 있음.	
		tempArr = makeUniqueArray arr_temp_mainhead[1]
		insertItem arrTemp[1] tempArr 1
		select tempArr
		
		tempPath = ""
		if saveName_ == "" do(
			saveName_ = (getFilenameFile maxfilename)
			saveName_ = (fn_filterStringKeyword saveName_ in_keyword:"@" bo_ignoreCase:(bool_ignoreCase) bo_prefix:true)
		)--end : if
		
		if skipAskPath <= 1 then(
			if customPath_ != "" do(saveName_ = customPath_ + saveName_)
			tempPath = getSaveFileName caption:"Select Export Path-FBX" types:"Format(*.fbx)|*.fbx|Apex(*)|*.fbx;*.txt|All(*.*)|*.*" historyCategory:"Export fbx" filename:(saveName_)
		) else (
			saveName_ = addNamePre + (getfilenamefile saveName_) + addNameSuf + (getfilenametype saveName_)
			if lastPathJ_ == "" or lastPathJ_ == undefined do (
				lastPathJ_ = getSaveFileName caption:"Select Export Path-FBX" types:"Format(*.fbx)|*.fbx|Apex(*)|*.fbx;*.txt|All(*.*)|*.*" historyCategory:"Export fbx" filename:(saveName_) 
				if lastPathJ_ != undefined and lastPathJ_ != "" do(lastPathJ_ = getFilenamePath lastPathJ_)
			)--end : if do
			if lastPathJ_ != undefined and lastPathJ_ != "" do(tempPath = lastPathJ_ + saveName_ +".fbx")--end.if
		)--end : if
		
		if tempPath != undefined and tempPath != "" do(
			tempPath = (fnExistFileRename tempPath bRename:True isFullPath:True)--end: if-do -- change file name. 
			lastPathJ_ = getFilenamePath tempPath
			--tempPath = trimRight tempPath ".fbx"
			exportFile tempPath selectedOnly:true
		)--end : if
		return tempPath
	)--end : fn_nExportFBX

	fn fn_export_fbx arrTemp &lastPathJ_ saveName_:"" rootCount:1 customPath_:"" addNamePre:"" addNameSuf:"" skipAskPath:1 =(
		--skipAskPath 값이 1 인경우, 익스포트 한번만 한다는 의미. 이경우에는 save file name 에 추가적인 작업을 하지 않음.
		arr_temp_mainbody = #()
		arr_temp_mainhead = #()
		for i in arrTemp do(
			arr_temp_mainbody = #()
			fn_getAllChildren i arr_temp_mainbody
			append arr_temp_mainhead arr_temp_mainbody --this is for many root objects.
		)--end: for i --모든 차일드를 구함. 하지만 중복되서 배열로 들어가 있을 수 있음.	
		tempArr = makeUniqueArray arr_temp_mainhead[1]
		insertItem arrTemp[1] tempArr 1
		select tempArr
		
		tempPath = ""
		if saveName_ == "" do(
			saveName_ = (getFilenameFile maxfilename)
			saveName_ = (fn_filterStringKeyword saveName_ in_keyword:"@" bo_ignoreCase:(bool_ignoreCase) bo_prefix:true)
		)--end : if
		
		if skipAskPath <= 1 then(
			if customPath_ != "" do(saveName_ = customPath_ + saveName_)
			tempPath = getSaveFileName caption:"Select Export Path-FBX" types:"Format(*.fbx)|*.fbx|Apex(*)|*.fbx;*.txt|All(*.*)|*.*" historyCategory:"Export fbx" filename:(saveName_)
		) else (
			saveName_ = addNamePre + (getfilenamefile saveName_) + addNameSuf + (getfilenametype saveName_)
			if lastPathJ_ == "" or lastPathJ_ == undefined do (
				lastPathJ_ = getSaveFileName caption:"Select Export Path-FBX" types:"Format(*.fbx)|*.fbx|Apex(*)|*.fbx;*.txt|All(*.*)|*.*" historyCategory:"Export fbx" filename:(saveName_) 
				if lastPathJ_ != undefined and lastPathJ_ != "" do(lastPathJ_ = getFilenamePath lastPathJ_)
			)--end : if do
			if lastPathJ_ != undefined and lastPathJ_ != "" do(
				tempPath = lastPathJ_ + saveName_
				tempPath = (fn_existFileName tempPath bUnique:True)--end: if-do -- change file name. 
			)
		)--end : if
		
		if tempPath != undefined and tempPath != "" do(
			lastPathJ_ = getFilenamePath tempPath
			--tempPath = trimRight tempPath ".fbx"
			exportFile tempPath selectedOnly:true
		)--end : if
		return tempPath
	)--end : fn_export_fbx
	
	fn fn_accessUI_FBX removeIncomingPrefix:0 removeCurrentPrefix:0 =(
	/*******************************************************************************
		<DOC> Manipulate the Load Envelopes dialog via the UI Accessor.
		Arguments:
			<int> removeIncomingPrefix:		Corresponds to the "Remove Incoming Prefix" checkbox.  0 is false, 1 is true
			<int> removeCurrentPrefix:		Corresponds to the "Remove Current Prefix" checkbox.  0 is false, 1 is true
		Return:
			<bool> true (needed for DialogMonitorOps)
	*******************************************************************************/
		--local BM_SETCHECK = 241
		local hwnd = dialogMonitorOps.getWindowHandle()
		if (uiAccessor.getWindowText hwnd == hwnd_nameStringJ or uiAccessor.getWindowText hwnd == hwnd_nameStr2) then
		(
			local children = windows.getChildrenHWND hwnd
			/*for child in children do (
				if (child[5] == "Remove Incoming Prefix") then(setUICheckboxState child[1] 1)
				else if (child[5] == "Remove Current Prefix") then(setUICheckboxState child[1] 1)
			)*/
			--forceCompleteRedraw()
			UIAccessor.PressButtonByName hwnd "OK"
			--UIAccessor.PressDefaultButton()
		)
		true
	)--end : fn_accessUI_FBX

	fn fn_accessUI arrTemp &lastPathJ_ saveName_:"" addNamePre:"" addNameSuf:"" rootCount:1 customPath_:"" skipAskPath:1 nExportType:False =(
	/*******************************************************************************
		<DOC> Load an .env file.  There is no function for silently loading an .env, so this
		is a UI Accessor workaround.
		Arguments:
			<skin modifier> theSkin:		The selected skin modifier (must be in modify panel)
			<string>	envFile:					Filename of the .env file.
		Return:
			<ok>
	*******************************************************************************/
		--determine which confirmLoadEnvelopes to use
		DialogMonitorOps.Enabled = true	--DialogMonitorOps.Enabled = false
		DialogMonitorOps.RegisterNotification fn_accessUI_FBX id:#pressSkinOK
		if nExportType then(
			tempPath = (fn_nExportFBX arrTemp &lastPathJ_ saveName_:saveName_ rootCount:rootCount customPath_:customPath_ addNamePre:addNamePre addNameSuf:addNameSuf skipAskPath:skipAskPath)
		)else(
			tempPath = (fn_export_fbx arrTemp &lastPathJ_ saveName_:saveName_ rootCount:rootCount customPath_:customPath_ addNamePre:addNamePre addNameSuf:addNameSuf skipAskPath:skipAskPath)
		)
		DialogMonitorOps.unRegisterNotification id:#pressSkinOK
		DialogMonitorOps.Enabled = false
		ok
		tempPath
	)--end : fn_accessUI
	-----------------------------------
	attr_objNode = attributes attr_objNode	(
		parameters main(
			objNode type:#Node;
			objUserStr type:#string;
		)--end : main
	)--end : Attrib_BnListStore
	attr_forV4System = attributes Custom_Attributes (
		parameters main rollout:Roll_ParamVal(
			RotationAmount type:#float ui:(spn_paramVal)
		)--end : main
		rollout Roll_ParamVal "RotationAmount"(--RotationAmount
			spinner spn_paramVal "RotationAmount" type:#float range:[-360.0,360.0,0.0]
		)
	)--end : Attrib_BnListStore
	/*
	a= custattributes.getdef $ 2
	--custAttributes.delete $ a
	*/
	-----------------------------------
	fn fn_findAttrTarget inObj inObjName =(
		enArrTemp = #(undefined,"")
		if isProperty inObj inObjName do (
			enArrTemp[1] = inObj.baseobject.attr_objNode.objNode
			enArrTemp[2] = inObj.baseobject.attr_objNode.objUserStr
		)--end :if
		return enArrTemp
	)--end : fn_findAttrTarget
	
	fn fn_assignRef2Root inObj inObjName refObj=(
		if not isProperty inObj inObjName do (--"attr_objNode"
			CustAttributes.add inObj attr_objNode
		)--end : if
		inObj.baseobject.attr_objNode.objNode = refObj
	)-- end : fn_assignRef2Root
	
	fn fn_assignStr2Root inObj inObjName inStr =(
		if not isProperty inObj inObjName do (--"attr_objNode"
			CustAttributes.add inObj attr_objNode
		)--end : if
		inObj.baseobject.attr_objNode.objUserStr = inStr
	)-- end : fn_assignRef2Root
	
	fn FnAssign_Attrib_forV4 inObj inObjName =(
		if not isProperty inObj inObjName do (--""
			CustAttributes.add inObj attr_forV4System
		)--end : if
		inObj.baseobject.Custom_Attributes.RotationAmount.controller = bezier_float()
		inObj.baseobject.Custom_Attributes.RotationAmount.controller.keyable = true
		--inObj.baseobject.Custom_Attributes.RotationAmount = inStr
	)--end : FnAssign_Attrib_forV4
	
	fn fn_findAllRoot root_name bool_ignoreCase inObjName=(
		arrTempObj = (getNodeByName (root_name) exact:true ignoreCase:(bool_ignoreCase) all:true)
		arrTempStr = #()
		arrTempRef = #()
		arrTempRefStr = #()
		arrShowStr = #()
		arrTempUserTXT = #()
		if arrTempObj.count != 0 do(
			for i in 1 to arrTempObj.count do(
				append arrTempStr arrTempObj[i].name
				arr_tempRef = (fn_findAttrTarget arrTempObj[i] attrObjNameStr)
				tempRef = arr_tempRef[1]
				tempUserStr = arr_tempRef[2]
				append arrTempRef tempRef
				append arrTempUserTXT tempUserStr
				tempShowStr1 = ""
				if isvalidnode tempRef then (
					append arrTempRefStr tempRef.name
					tempShowStr1 = tempRef.name
				)else (append arrTempRefStr "")--end : if-else
				append arrShowStr (arrTempStr[i]+"    ::  "+ tempUserStr + "    @: " + tempShowStr1)
			)--end : for i
		)--end : if
		enArr = #(arrTempObj,arrTempStr,arrTempRef,arrTempRefStr,arrShowStr,arrTempUserTXT)
	)--end : fn_findAllRoot
		
	fn fn_sel_itemFromMList in_mtb_List in_listSpExpObj selN:1 onlyOneRoot:false=(
		bitArr = in_mtb_List.selection
		sel_target = #()
		for i in 1 to bitArr.count do(
			if (bitArr[i]==true) do(
				if isvalidnode in_listSpExpObj[selN][i] do(append sel_target in_listSpExpObj[selN][i])
			)--end : if
		)--end : for i
		if onlyOneRoot then (try(select sel_target[1])catch())
		else (try(select sel_target)catch())
		return sel_target;
	)--end : fn_sel_itemFromMList
	
	fn fn_MList_assign in_mtb_List in_listSpExpObj attrObjNameStr refObj selN:1=(
		bitArr = in_mtb_List.selection
		for i in 1 to bitArr.count do(
			if (bitArr[i]==true) do(
				tempRoot = in_listSpExpObj[selN][i]
				if isvalidnode tempRoot do(fn_assignRef2Root tempRoot attrObjNameStr refObj)
			)--end : if
		)--end : for i
	)--end : fn_MList_assign
	
	fn fn_MList_StrAssign in_mtb_List in_listSpExpObj attrObjNameStr inAnyRef selN:1=(
		bitArr = in_mtb_List.selection
		for i in 1 to bitArr.count do(
			if (bitArr[i]==true) do(
				tempRoot = in_listSpExpObj[selN][i]
				if isvalidnode tempRoot do(fn_assignStr2Root tempRoot attrObjNameStr inAnyRef)
			)--end : if
		)--end : for i
	)--end : fn_MList_assign
	-----------------------------------------------------------------------------------------
	--timeTage function
	fn fn_rangeFromTag inStr bNotTime:False =(
		tempTagString = #()
		tempRArr = #("",0f,10f)
		tempRArr[1] = (filterString inStr " ~")[1]
		tempTagString = filterString inStr " (~)"
		for k in 1 to tempTagString.count do(
			if (k < tempTagString.count and (tempTagString[k] as integer) != undefined and (tempTagString[k+1]as integer) != undefined) do(
				if bNotTime then(
					tempRArr[2] = tempTagString[k]
					tempRArr[3] = tempTagString[k+1]
				)else(
					tempRArr[2] = tempTagString[k] as time
					tempRArr[3] = tempTagString[k+1] as time
					--exit; --don't use exit  .  for Check last two number. 
				)--end : if-bNotTime
			)--end : if -first
		)--end : for k
		return tempRArr
	)--end : fn_rangeFromTag
	
	fn fn_getTagList bPrint:False =(
		ntags = FrameTagManager.GetTagCount()
		arrTimeTagListP = #(#(),#(),#(),#(),#(),#(),#()) -- 1 exportName , 2 startF , 3 endF , 4 indexFrame , 5 showStr , 6 id , 7 TagName
		arrTag_Names = #()
		arrTag_startF =#()
		arrTag_endF =#()
		arrTag_fIdx = #()
		arrTag_showStr = #()
		arrTag_id = #() --id for delete item.
		arrTag_TagName = #()
		if (ntags!=0) do(
			for i in 1 to ntags do(
				id = FrameTagManager.GetTagID i
				tagName = FrameTagManager.GetNameByID id
				tagTime = FrameTagManager.GetTimeByID id
				
				append arrTag_TagName tagName
				tempReturnArr = fn_rangeFromTag tagName
				append arrTag_Names tempReturnArr[1]
				append arrTag_startF tempReturnArr[2]
				append arrTag_endF tempReturnArr[3]
				append arrTag_fIdx ((tagTime.frame as integer) as string)
				tempPreStr = "idx:"+arrTag_fIdx[i] + "| " + (tempReturnArr[3] - tempReturnArr[2]) as string
				if tempPreStr.count < 20 do(
					for i in tempPreStr.count to 20 do(
						tempPreStr += " "
					)--end : for tempPreStr
				)--end : if tempPreStr
				tempShowStr = (tempPreStr + "  ::  "+ tagName)
				append arrTag_showStr tempShowStr
				append arrTag_id id
				if bPrint do format "% - id:%; tag:%; idxFrame:%;  start-%  , end-%   \n" i id tagName tagTime tempReturnArr[2] tempReturnArr[3]
			)--end : for i
			arrTimeTagListP[1] = arrTag_Names
			arrTimeTagListP[2] = arrTag_startF
			arrTimeTagListP[3] = arrTag_endF
			arrTimeTagListP[4] = arrTag_fIdx
			arrTimeTagListP[5] = arrTag_showStr
			arrTimeTagListP[6] = arrTag_id
			arrTimeTagListP[7] = arrTag_TagName
		)--end : if ntags
	)--end : fn_getTagList
		
	fn fn_replaceStrATTagName inMList inStr inNumTxt aPre:false aSuf:false =(
		if (inStr).count == 0 and inNumTxt == 0 do(return 1;)
		tempBitArr = inMList.selection
		tempSt_id = 0
		for i in 1 to tempBitArr.count do(
			if (tempBitArr[i]==true) do(
				tempSt_id = (arrTimeTagListP[6][i] as integer)
				tempStr = arrTimeTagListP[7][i]
				if aPre do(
					if inNumTxt > 0 do (
						tempStr =(substring tempStr inNumTxt -1)
					)--end : if
					FrameTagManager.SetNameByID tempSt_id (inStr + tempStr)
				)--end : if-aPre
				if aSuf do(
					tempArrtStr = (fn_rangeFromTag tempStr bNotTime:True)
					tempNStr = tempArrtStr[1]
					inNumTxt_suf = (tempNStr.count - inNumTxt)
					if inNumTxt_suf > 0 do(
						tempNStr =(substring tempNStr 1 inNumTxt_suf)
					)--end : if
					FrameTagManager.SetNameByID tempSt_id (tempNStr + inStr + "  ( " + tempArrtStr[2] as string + " ~ " + tempArrtStr[3] as string + " )")
				)--end : if-aSuf
			)--end : if-tempBitArr
		)--end : for i
		return 0
	)--end : fn_replaceStrATTagName
	
	fn fnReloadTag =(--global variable
		fn_getTagList()
		R_timeTagRange.mListTimeTage.selection = #{}
		R_timeTagRange.mListTimeTage.items = arrTimeTagListP[5]
	)--fnG_reloadTag
	-----------------------------------------------------------------------------------------
	--start rollout
	-----------------------------------------------------------------------------------------
	rollout R_spExportAssign_option "option"(
		button btn_optionDir "dir" width:20 pos:[5,5]
		button btn_optionReload "reload" width:50 pos:[30,5]
		button btn_optionSave "save setting" width:80 pos:[280,5]
		button btn_author "author" width:45 pos:[365,5]
		label lab_ex01 "root name    : " pos:[10,35]
		dotNetControl txt_expRootName "System.Windows.Forms.TextBox" width:(280) height:20 pos:[80,35]
		label lab_ex02 "FBX version : " pos:[10,65]
		dotNetControl txt_exportorVersionSTR "System.Windows.Forms.TextBox" width:(280) height:20 pos:[80,65]
		label lab_ex03 "        exam - " pos:[10,92]
		dropdownlist dList_exportorVersionSTR items:#() width:(280) height:20 pos:[80,90]
		label lab_ex04 " )" pos:[365,82]
		label lab_ex05 "timeTag Size :" pos:[10,117]
		dropdownlist dList_SizeTimeTag items:#("4 Lines","8 Lines","14 (default)","21 Lines") selection:3 width:(105) height:20 pos:[80,115]
		label lab_ex06 "- This value affects the tools size." pos:[200,120]
		--button testb "test"
		
		/*on testb pressed do(
			print dList_SizeTimeTag.selected
			--R_spExportAssign_option.dList_SizeTimeTag.selected
		)*/

		on MyForm open do(
			txt_exportorVersionSTR.Visible = true
			txt_exportorVersionSTR.MultiLine = false
			txt_exportorVersionSTR.enabled = true
			txt_exportorVersionSTR.ForeColor = (dotnetclass "System.Drawing.Color").FromArgb 20 20 20
			txt_exportorVersionSTR.BackColor = (dotnetclass "System.Drawing.Color").FromArgb 180 180 180
			txt_exportorVersionSTR.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").FixedSingle
			txt_exportorVersionSTR.Text = "optionSTR"
			txt_exportorVersionSTR.Font = TITLEFONT
			txt_exportorVersionSTR.DeselectAll()
				
			txt_expRootName.Visible = true
			txt_expRootName.MultiLine = false
			txt_expRootName.enabled = true
			txt_expRootName.ForeColor = (dotnetclass "System.Drawing.Color").FromArgb 20 20 20
			txt_expRootName.BackColor = (dotnetclass "System.Drawing.Color").FromArgb 180 180 180
			txt_expRootName.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").FixedSingle
			txt_expRootName.Text = "optionSTR"
			txt_expRootName.Font = TITLEFONT
			txt_expRootName.DeselectAll()
			--showProps txt_infomation
		)
		----------------------------------------------------------------
		fn fnLocal_loadVariable =(
			root_name = txt_expRootName.text
			hwnd_nameStringJ = txt_exportorVersionSTR.text
		)--end : fnLocal_loadVariable
			
		fn fnLocal_reloadOption forOpen:False = (
			tempfullPath = fn_checkExistFile_ini ArrFile_ini
			bExist = false
			if tempfullPath != "" do bExist = true
			if(bExist) then(
				txt_expRootName.text = getINISetting tempfullPath "export_Bone" "rootName"
				txt_exportorVersionSTR.text = getINISetting tempfullPath "hwnd_strExport" "name"
				indexNum = (getINISetting tempfullPath "timeTag_Size_Set" "set_index") as integer -- if not exist value , return "" 
				if indexNum > 0 and indexNum <= (sizeSet_forTimeTag.count) do (dList_SizeTimeTag.selection = indexNum)
				fnLocal_loadVariable()
			) else(
				if forOpen then(
					txt_expRootName.text = "root"
					txt_exportorVersionSTR.text = "FBX Export (Version: 2019.0)"
				) else(messagebox "not exist option file")
			)--end : if
		)--end : fnLocal_reloadOption
		----------------------------------------------------------------
			
		on R_spExportAssign_option open do(
			fnLocal_reloadOption forOpen:True
			--ArrFile_ini = #(savePathOption_,fileNameINI_)
			dlist_exportorVersionSTR.items = arr_exportorVersionSTR
		)--end : R_spExportAssign_option-open
		
		on dList_exportorVersionSTR selected arg do(
			txt_exportorVersionSTR.text = arr_exportorVersionSTR[arg]
			fnLocal_loadVariable()
		)--end : dList_exportorVersionSTR selected
		
		on btn_optionDir pressed do(
			fn_checkDirMake ArrFile_ini[1] bCreat:True
			if(fn_checkDirMake savePathOption_ bCreat:False) do (
				shelllaunch "explorer.exe" (substituteString savePathOption_ "\\\\" "\\")
			)--end : if
		)--end : btn_optionDir
		
		on btn_optionReload pressed do(fnLocal_reloadOption()
		)--end : btn_optionReload
		
		on btn_optionSave pressed do(
			/*
			arrFile_iniSection = #("hwnd_strExport","export_Bone")
			arrFile_iniKeyVal = #(#(#("name","val1")),#(#("rootName","val1")))
			*/
			arrFile_iniKeyVal[1][1][2] = txt_exportorVersionSTR.text
			arrFile_iniKeyVal[2][1][2] = txt_expRootName.text
			arrFile_iniKeyVal[3][1][2] = (dList_SizeTimeTag.selection) as string
			fn_saveFile_ini ArrFile_ini arrFile_iniSection arrFile_iniKeyVal
			fnLocal_reloadOption forOpen:True
			messageBox "save option" beep:false
		)--end : btn_optionSave
		on btn_author pressed do(
			rollout RL_author "author"(
				label lab_exAuthor1 "kwan jin young , 권진영"	
				label lab_exAuthor2"finseag@gmail.com"
			)--end : rollout
			createdialog RL_author width:300 height:80 --style:#(#style_titlebar, #style_border, #style_sysmenu, #style_resizing) 
		)--end : btn_author
		
	)--end : R_spExportAssign_option-------------------------------------------------------------
	
	rollout R_spExportAssign_List "root  List"(
		button btn_selRoot "sel - root" height:25 pos:[15,8]
		label lab_ex010 "   @: "  pos:[75,10]
		button btn_selRef "sel - ref" height:25 pos:[95,8]
		button btn_assign2root "assign Obj" tooltip:"assign selected object to Root "height:25 width:85 pos:[280,8]
		edittext txt_userStrRoot text:"" fieldWidth:260 height:17 readOnly:false pos:[10,45] --multiLine:false
		button btn_assignTXT2root "assign Text" tooltip:"assign Text  to Root "height:25 width:85 pos:[280,40]
		button btn_reload "reload" width:75 height:25 pos:[15,70]
		button btn_export "export" width:75 height:25 pos:[100,70]
		button btn_openLastPath "open dir" width:50 height:25 pos:[190,70]
		checkbox chb_sExport "skipEXP" tooltip:"skip Export window" checked:false pos:[250,80]
		checkbox chb_strPrefix "prefix" checked:false pos:[305,80]
		checkbox chb_strSuffix "suffix" checked:true pos:[355,80]
		MultiListBox mtb_List items:#() selection:#{}
		label lab_ex020 "note !! [ root list ] is not automatically updated ! You must reload this yourself ."
		
		on R_spExportAssign_List open do(
			listSpExpObj = (fn_findAllRoot root_name bool_ignoreCase attrObjNameStr)
			mtb_List.items = listSpExpObj[5]--1 : root , 2:root Name , 3:ref , 4:ref Name , 5:for show str
			mtb_List.selection = #{}
		)--end : R_spExportAssign_List
		on mtb_List rightClick do(
			mtb_List.selection = #{}
		)--end : mtb_List rightClick
		
		on btn_reload pressed do(
			listSpExpObj = (fn_findAllRoot root_name bool_ignoreCase attrObjNameStr)
			mtb_List.items = listSpExpObj[5]--1 : root , 2:root Name , 3:ref , 4:ref Name, 5:for show str
			mtb_List.selection = #{}
		)--end : btn_reloadw
		
		on btn_selRoot pressed do(
			fn_sel_itemFromMList mtb_List listSpExpObj selN:1
		)
		on btn_selRef pressed do(
			fn_sel_itemFromMList mtb_List listSpExpObj selN:3
		)
		
		on mtb_List doubleClicked arg do(
			txt_userStrRoot.text = listSpExpObj[6][arg]
		)--end : mtb_List
		
		on btn_assign2root pressed do with undo off(
			objTargets = #()
			objTargets = selection as array
			if objTargets.count == 0 do (messagebox "need to select Target";return 0)
			refObj = objTargets[1]
			if not isvalidnode refObj do (return 0)
			fn_MList_assign mtb_List listSpExpObj attrObjNameStr refObj
			listSpExpObj = (fn_findAllRoot root_name bool_ignoreCase attrObjNameStr)
			mtb_List.items = listSpExpObj[5]--1 : root , 2:root Name , 3:ref , 4:ref Name, 5:for show str
			--mtb_List.selection = #{}
		)--end : btn_assign2root
		
		on btn_assignTXT2root pressed do with undo off(
			bTempQ = true
			if txt_userStrRoot.text == "" do (bTempQ = queryBox "remove text ?")--end : if
			if not bTempQ do(return 1;)
			fn_MList_StrAssign mtb_List listSpExpObj attrObjNameStr (txt_userStrRoot.text)
			listSpExpObj = (fn_findAllRoot root_name bool_ignoreCase attrObjNameStr)
			mtb_List.items = listSpExpObj[5]--1 : root , 2:root Name , 3:ref , 4:ref Name, 5:for show str
			--mtb_List.selection = #{}
		)--end : btn_assignTXT2root
		
		on btn_export pressed do(
			fn_sel_itemFromMList mtb_List listSpExpObj selN:1 onlyOneRoot:false
			rootArrTemp = selection as array
			if rootArrTemp.count == 0 do return 0;
			rootSingleTemp = #()
			
			if chb_sExport.checked then(
				for k in 1 to rootArrTemp.count do(
					nameTempPre = "";nameTempSuf = "";
					nameTempArr = (fn_findAttrTarget rootArrTemp[k] attrObjNameStr)
					nameTemp = "_"
					if nameTempArr[2] != "" then(
						nameTemp += nameTempArr[2]
					)else(
						if isvalidnode nameTemp then (nameTemp = "_"+nameTemp.name)
						else (nameTemp = "_needName_")
					)--end : if
					if chb_strPrefix.checked do nameTempPre=nameTemp
					if chb_strSuffix.checked do nameTempSuf=nameTemp
					rootSingleTemp[1] = rootArrTemp[k]
					lastExportPath = (fn_accessUI (rootSingleTemp) &lastPathJ_ saveName_:"" addNamePre:nameTempPre addNameSuf:nameTempSuf skipAskPath:k)
					if lastExportPath == undefined do exit;
				)--end : for i
			)else (
				for k in 1 to rootArrTemp.count do(
					nameTempPre = "";nameTempSuf = "";
					nameTempArr = (fn_findAttrTarget rootArrTemp[k] attrObjNameStr)
					nameTemp = "_"
					if nameTempArr[2] != "" then(
						nameTemp += nameTempArr[2]
					)else(
						if isvalidnode nameTemp then (nameTemp = "_"+nameTemp.name)
						else (nameTemp = "_needName_")
					)--end : if
					if chb_strPrefix.checked do nameTempPre=nameTemp
					if chb_strSuffix.checked do nameTempSuf=nameTemp
					rootSingleTemp[1] = rootArrTemp[k]
					lastExportPath = (fn_export_fbx rootSingleTemp &lastPathJ_ saveName_:"" addNamePre:nameTempPre addNameSuf:nameTempSuf skipAskPath:k)
					if lastExportPath == undefined do exit;
				)--end : for i
			)--end : if then
		)--end : btn_export
		
		on btn_openLastPath pressed do(
			if (lastExportPath != "" and lastExportPath != undefined) do(
				lastExportPath = getFilenamePath lastExportPath
				shelllaunch "explorer.exe" (lastExportPath)
			)--end if
		)--end : btn_openLastPath
	)--end R_spExportAssign_List
	-----------------------------------------------------------------------------------------
	rollout R_timeTagRange "timeTag_range"(
		local Text_width = 360
		spinner spn_tagFrameTime "idx " type:#integer range:[-666666,666666,10] width:55 pos:[10, 6] align:#left
		button btn_Edit "|  Edit  |" tooltip:"Edit Item of List" height:24 width:75 pos:[85,2]
		button btn_Add "|  Add  |" tooltip:"Add Item to the List" height:24 width:75 pos:[168,2]		
		button btn_Delete "| Delete |" tooltip:"Delete items of List" height:24 width:63 pos:[280, 2]
		button btn_maxName "name" tooltip:"1.leftClick : Fill Text-field with maxFilename  \n2.rightClick : Clear Text-field" height:24 width:40 pos:[360,2]
		--button btn_Delete_Undo "[@]" tooltip:"Undo Delete Item" height:20 width:28 pos:[367, 4]
		colorpicker colLockState0 "" width:13 height:17 color:(color 217 255 7) pos:[0,30]
		edittext txt_infomation text:"" fieldWidth:330 height:17 readOnly:false pos:[10,30] --multiLine:false
		--dotNetControl txt_infomation "System.Windows.Forms.TextBox" width:(Text_width) height:20 pos:[10,30]
		colorpicker colLockState "" width:13 height:17 color:(color 217 255 7) pos:[342,30]
		checkbox chbox_Fill_Text "Lock" tooltip:"items edits mode (Lock animation range)" checked:false pos:[360,33]
		checkbox chbMoreInfoList "More" tooltip:"show more infomation" checked:true pos:[360,62]
		button btnReload "Reload" tooltip:"Reload List" height:23 width:45 pos:[10,55]
		checkbox chbSkipExportAll "" tooltip:"automatic skip export-window" checked:false pos:[60,62]
		button btnExport " Export " tooltip:"Export (root)" height:23 width:160 pos:[83,55]
		button btnOpenLast "openDir" tooltip:"open last directory\n(this will not work unless you Export)" height:23 width:60 pos:[250,55]
		button btnSelectRoot "sel" tooltip:"1.leftClick : select All inherited from root \n2.rightClick : select only root" height:23 width:25 pos:[320,55]
		--spinner spnMList_Height "" type:#integer range:[50,360,188] width:35 pos:[360, 60]
		multiListBox mListTimeTage "" items:#() height:(dynamic_Line) pos:[10,80]
		button btnEditStrPre "pre" tooltip:"prefix edit" width:30 height:23 pos:[10,(dynamic_height)]
		edittext txtEditStrPre text:"" fieldWidth:92 height:17 readOnly:false pos:[40,(dynamic_height+5)] --multiLine:false
		spinner spnEditStrPre "remove" tooltip:"remove first" type:#integer range:[0,21,0] width:35 pos:[172, (dynamic_height+5)]
		button btnEditStrSuf "suf" tooltip:"suffix edit" width:30 height:23 pos:[212,(dynamic_height)]
		edittext txtEditStrSuf text:"" fieldWidth:92 height:17 readOnly:false pos:[240,(dynamic_height+5)] --multiLine:false
		spinner spnEditStrSuf "remove" tooltip:"remove last" type:#integer range:[0,21,0] width:35 pos:[375, (dynamic_height+5)]
		button btnGetListFromFile "[ get ] File" tooltip:"get tag-list from file" width:70 height:23 pos:[10,(dynamic_height+30)]
		button btnAddExam_01 "CC ~" tooltip:" _CC \n _CU \n _CD \n _RC \n _RU \n _RD \n _LC \n _LU \n _LD " width:50 height:23 pos:[85,(dynamic_height+30)]
		button btnAddExam_02 "fwd ~" tooltip:"note::need to select one or more [ List item ] \n _Rt \n _Lt \n _Fwd \n _FwRt \n _FwLt \n _Bwd" width:50 height:23 pos:[135,(dynamic_height+30)]
		button btnAddExam_03 "list 03" tooltip:"not yet" width:50 height:23 pos:[185,(dynamic_height+30)]
		button btnSaveTagList_INI "[ save ]" tooltip:"save Tag List" width:60 height:23 pos:[350,(dynamic_height+30)]
		--listbox tRange_idCheck "" items:CR_TagNames height:13 width:(Text_width-290) pos:[10,80]
		--listbox tRange "" items:CR_TagNames height:13 width:(Text_width-50) pos:[80,80]
		
		fn fnL_addNewTag inArrTagStr =(
			if inArrTagStr.count == 0 do return 1
			tempTotal = (arrTimeTagListP[4].count)
			NewTag_id = 0
			addAtNum = 1
			if tempTotal > 0 do (addAtNum = arrTimeTagListP[4][tempTotal] as integer)
			for k in 1 to inArrTagStr.count do(
				NewTag_id = frameTagManager.CreatenewTag inArrTagStr[k] (addAtNum + k)
			)--end : for k
			fn_getTagList()
			if chbMoreInfoList.checked then(mListTimeTage.items = arrTimeTagListP[5])else(mListTimeTage.items = arrTimeTagListP[7])
		)--end : fnL_addNewTag
		
		on R_timeTagRange open do(
			colLockState.enabled = false
			colLockState.visible = false
			colLockState0.enabled = false
			colLockState0.visible = false
			fn_getTagList()
			mListTimeTage.selection = #{}
			mListTimeTage.items = arrTimeTagListP[5]
			callbacks.addScript #filepostopen "fnReloadTag()" id:#R_fileopen_Clip
		)--end ; R_timeTagRange-open
		
		on chbox_Fill_Text changed arg do(---> this is for Lock animation range
			if arg then(colLockState.visible = true;colLockState0.visible = true)
			else(colLockState.visible = false;colLockState0.visible = false)
		)--end : chbox_Fill_Text -> this is for Lock animation range
		
		on chbSkipExportAll changed arg do(
			if arg then(btnExport.text = "(skip)  Export  ")
			else(btnExport.text = " Export ")
		)--end : chbSkipExportAll
		
		on R_timeTagRange close do(
			callbacks.removeScripts id:#R_fileopen_Clip
		)--end : R_timeTagRange-close
		
		on btn_Edit pressed do(
			if (txt_infomation.text).count == 0 do return 1;
			tempBitArr = mListTimeTage.selection
			tempSt_id = 0
			for i in 1 to tempBitArr.count do(
				if (tempBitArr[i]==true) do(
					tempSt_id = (arrTimeTagListP[6][i] as integer)
					FrameTagManager.SetNameByID tempSt_id (txt_infomation.text)
					FrameTagManager.SetTimeById tempSt_id (spn_tagFrameTime.value)
					exit;
				)--end : if
			)--end : for i
			fn_getTagList()
			if chbMoreInfoList.checked then(mListTimeTage.items = arrTimeTagListP[5])else(mListTimeTage.items = arrTimeTagListP[7])
			for i in 1 to arrTimeTagListP[6].count do(
				if tempSt_id == arrTimeTagListP[6][i] do (
				tempSt_id = i
				exit;
				)--end : if
			)--end : for i
			if tempSt_id > 0 then mListTimeTage.selection = #{(tempSt_id)}
			else mListTimeTage.selection = #{}
		)--end : btn_Edit
		
		on btn_Add pressed do(
			if (txt_infomation.text).count == 0 do return 1;
			NewTag_id = 0
			NewTag_id = frameTagManager.CreatenewTag txt_infomation.text spn_tagFrameTime.value
			fn_getTagList()
			if chbMoreInfoList.checked then(mListTimeTage.items = arrTimeTagListP[5])else(mListTimeTage.items = arrTimeTagListP[7])
		)--end : btn_Add
		
		on btn_Delete pressed do(
			tempBitArr = mListTimeTage.selection
			tempSt_id = 0
			for i in tempBitArr.count to 1 by -1 do(
				if (tempBitArr[i]==true) do(
					tempSt_id = (arrTimeTagListP[6][i] as integer)
					frametagmanager.deleteTag (tempSt_id)
				)--end : if
			)--end : for i
			mListTimeTage.selection = #{}
			fn_getTagList()
			if chbMoreInfoList.checked then(mListTimeTage.items = arrTimeTagListP[5])else(mListTimeTage.items = arrTimeTagListP[7])
		)--end : btn_Delete
		
		on btn_maxName pressed do(
			txt_infomation.text = (fn_filterStringKeyword (getFilenameFile maxfilename) in_keyword:"@" bo_ignoreCase:(bool_ignoreCase) bo_prefix:true)
		)--end.
		on btn_maxName rightClick do(txt_infomation.text = "")--end.
		
		on chbMoreInfoList changed arg do(
			if arg then(mListTimeTage.items = arrTimeTagListP[5])else(mListTimeTage.items = arrTimeTagListP[7])
		)--end.			
			
		on btnReload pressed do(
			fn_getTagList()
			mListTimeTage.selection = #{}
			if chbMoreInfoList.checked then(mListTimeTage.items = arrTimeTagListP[5])else(mListTimeTage.items = arrTimeTagListP[7])
		)--end : btnReload
		on btnReload rightClick do(
			fn_getTagList bPrint:True
			mListTimeTage.selection = #{}
			if chbMoreInfoList.checked then(mListTimeTage.items = arrTimeTagListP[5])else(mListTimeTage.items = arrTimeTagListP[7])
		)--end : btnReload-rightClick
		
		on mListTimeTage rightClick do(
			mListTimeTage.selection = #{}
			if chbox_Fill_Text.checked then(---> this is for Lock animation range
				chbox_Fill_Text.checked = False
				colLockState.visible = false;colLockState0.visible = false
			)else(
				chbox_Fill_Text.checked = True
				colLockState.visible = true;colLockState0.visible = true
			)
		)--end : mListTimeTage-rightClick
		on mListTimeTage selectionEnd do(
			if chbox_Fill_Text.checked do return 1;
			tempBitArr = mListTimeTage.selection
			bHasInterval = False
			tempInterval = (interval 0f 10f)
			tempInterval_pre = undefined
			for i in 1 to tempBitArr.count do(
				if (tempBitArr[i]==true) do(
					bHasInterval = True
					if arrTimeTagListP[2][i] != arrTimeTagListP[3][i] then(
						tempInterval.start = arrTimeTagListP[2][i]
						tempInterval.end = arrTimeTagListP[3][i]
					)else (
						tempInterval.start = arrTimeTagListP[2][i]
						tempInterval.end = arrTimeTagListP[2][i] + 1f
					)--end : if-then
					if tempInterval_pre != undefined do(
						if tempInterval.start > tempInterval_pre.start do tempInterval.start = tempInterval_pre.start
						if tempInterval.end < tempInterval_pre.end do tempInterval.end = tempInterval_pre.end
					)
					tempInterval_pre = interval tempInterval.start tempInterval.end
				)--end : if-tempBitArr
			)--end : for i
			if bHasInterval do (
				if tempInterval.start >= tempInterval.end do (tempInterval.end = (tempInterval.start + 1); messagebox "wrong range";)
				animationrange = tempInterval; slidertime = animationrange.start
			)--end : if-bHasInterval
		)--end : mListTimeTage
		
		on mListTimeTage doubleClicked arg do(
			txt_infomation.text = arrTimeTagListP[7][arg]
			spn_tagFrameTime.value = arrTimeTagListP[4][arg] as integer
			if chbox_Fill_Text.checked do return 1;
			-----
			tempBitArr = mListTimeTage.selection
			bHasInterval = False
			tempInterval = (interval 0f 10f)
			tempInterval_pre = undefined
			for i in 1 to tempBitArr.count do(
				if (tempBitArr[i]==true) do(
					bHasInterval = True
					if arrTimeTagListP[2][i] != arrTimeTagListP[3][i] then(
						tempInterval.start = arrTimeTagListP[2][i]
						tempInterval.end = arrTimeTagListP[3][i]
					)else (
						tempInterval.start = arrTimeTagListP[2][i]
						tempInterval.end = arrTimeTagListP[2][i] + 1f
					)--end : if-then
					if tempInterval_pre != undefined do(
						if tempInterval.start > tempInterval_pre.start do tempInterval.start = tempInterval_pre.start
						if tempInterval.end < tempInterval_pre.end do tempInterval.end = tempInterval_pre.end
					)
					tempInterval_pre = interval tempInterval.start tempInterval.end
				)--end : if-tempBitArr
			)--end : for i
			if bHasInterval do (
				if tempInterval.start >= tempInterval.end do (tempInterval.end = (tempInterval.start + 1);messagebox "wrong range";)
				animationrange = tempInterval; slidertime = animationrange.start
			)--end : if-bHasInterval
		)--end : mListTimeTage-doubleClicked
		
		on btnExport pressed do(
			tempBitArr = (mListTimeTage.selection)
			bNotSelected = True
			tempInterval = (interval 0f 10f)
			tempInterval_pre = undefined
			rootSingleTemp = #()
			arrTemp = (getNodeByName (root_name) exact:true ignoreCase:(bool_ignoreCase) all:true)
			if arrTemp.count == 0 do (messagebox "can't find root-name"; return 1)
			if arrTemp.count == 1 then (
				rootSingleTemp = #(arrTemp[1])
			) else(
				arrTemp = (fn_sel_itemFromMList (R_spExportAssign_List.mtb_List) listSpExpObj selN:1 onlyOneRoot:True)
				if not isvalidnode arrTemp[1] do(messagebox "need to select root  , check [ root list ]"; return 1)
				rootSingleTemp = #(arrTemp[1])
			)--end : if-else
			
			idxC = 1
			tempStoreRange = animationrange
			for i in 1 to tempBitArr.count do(
				if (tempBitArr[i]==true) do(
					bNotSelected = False
					if arrTimeTagListP[2][i] != arrTimeTagListP[3][i] then(animationrange = interval arrTimeTagListP[2][i] arrTimeTagListP[3][i])
					else (animationrange = interval arrTimeTagListP[2][i] (arrTimeTagListP[2][i] + 1))--end : if-then
					if idxC == 1 then(
						if chbSkipExportAll.checked then(
							lastExportPath = (fn_accessUI (rootSingleTemp) &lastPathJ_ saveName_:arrTimeTagListP[1][i] customPath_:"" skipAskPath:idxC nExportType:True)
							if lastExportPath == undefined or lastExportPath == "" do exit;
						)else(
							lastExportPath = (fn_nExportFBX rootSingleTemp &lastPathJ_ saveName_:arrTimeTagListP[1][i] rootCount:1 customPath_:"" skipAskPath:idxC)
							if lastExportPath == undefined or lastExportPath == "" do exit;
						)--end : inside-if
					)else(
						lastExportPath = (fn_accessUI (rootSingleTemp) &lastPathJ_ saveName_:arrTimeTagListP[1][i] skipAskPath:idxC nExportType:True)
						if lastExportPath == undefined or lastExportPath == "" do exit;
					)--end : if-idx
					idxC+=1
				)--end : if
			)--end : for i
			if bNotSelected do(
				lastExportPath = (fn_nExportFBX rootSingleTemp &lastPathJ_ saveName_:"" rootCount:1 customPath_:"" skipAskPath:1)
			)--end : if-bNotSelected
			animationrange = tempStoreRange
		)--end : btnExport
		
		on btnSelectRoot pressed do(
			arrTemp = #()
			arr_temp_mainbody = #()
			arr_temp_mainhead = #()
			arrTemp = (getNodeByName (root_name) exact:true ignoreCase:(bool_ignoreCase) all:true)
			if arrTemp.count == 0 do (messagebox "can't find root-name"; return 1)
			if arrTemp.count > 1 do (
				arrTemp = (fn_sel_itemFromMList (R_spExportAssign_List.mtb_List) listSpExpObj selN:1 onlyOneRoot:True)
				if not isvalidnode arrTemp[1] do(messagebox "need to select root  , check [ root list ]"; return 1)
				arrTemp = #()
			)--end : if
			for i in arrTemp do(
				arr_temp_mainbody = #()
				fn_getAllChildren i arr_temp_mainbody
				append arr_temp_mainhead arr_temp_mainbody --this is for many root objects.
			)--end: for i --모든 차일드를 구함. 하지만 중복되서 배열로 들어가 있을 수 있음.	
			tempArr = makeUniqueArray arr_temp_mainhead[1]
			insertItem arrTemp[1] tempArr 1
			select tempArr
		)--end : btnSelectRoot
		on btnSelectRoot rightClick do(
			arrTemp = #()
			arrTemp = (getNodeByName (root_name) exact:true ignoreCase:(bool_ignoreCase) all:true)
			if arrTemp.count == 0 do (messagebox "can't find root-name"; return 1)
			if arrTemp.count > 1 do (
				arrTemp = (fn_sel_itemFromMList (R_spExportAssign_List.mtb_List) listSpExpObj selN:1 onlyOneRoot:True)
				if not isvalidnode arrTemp[1] do(messagebox "need to select root  , check [ root list ]"; return 1)
				arrTemp = #()
			)--end : if
			select arrTemp[1]
		)--end : btnSelectRoot-rightClick
		
		on btnOpenLast pressed do(
			if (lastExportPath != "" and lastExportPath != undefined) then(
				lastExportPath = getFilenamePath lastExportPath
				shelllaunch "explorer.exe" (lastExportPath)
			)else(messagebox "can't find [ last export directory ]" beep:False)--end if-else
		)--end : test Btn
		
		on btnEditStrPre pressed do(
			fn_replaceStrATTagName mListTimeTage txtEditStrPre.text spnEditStrPre.value aPre:True
			fn_getTagList()
			if chbMoreInfoList.checked then(mListTimeTage.items = arrTimeTagListP[5])else(mListTimeTage.items = arrTimeTagListP[7])
		)--end : btnEditStrPre
		on btnEditStrPre rightClick do(txtEditStrPre.text = "")

		on btnEditStrSuf pressed do(
			fn_replaceStrATTagName mListTimeTage txtEditStrSuf.text spnEditStrSuf.value aSuf:True
			fn_getTagList()
			if chbMoreInfoList.checked then(mListTimeTage.items = arrTimeTagListP[5])else(mListTimeTage.items = arrTimeTagListP[7])
		)--end : btnEditStrPre
		on btnEditStrSuf rightClick do(txtEditStrSuf.text = "")
		
		on btnAddExam_01 pressed do(
			arrAddTag = #("_Aim_CC 2~4","_Aim_CU 6~7","_Aim_CD 9~10","_Aim_RC 12~13","_Aim_RU 15~16",
				"_Aim_RD 18~19","_Aim_LC 21~22","_Aim_LU 24~25","_Aim_LD 27~28")
			fnL_addNewTag arrAddTag
		)--end : btnAddExam_01
		on btnAddExam_02 pressed do(--임시용도.
			tempBitArr = mListTimeTage.selection
			bHasInterval = False
			arrAddTag= #()
			for i in 1 to tempBitArr.count do(
				if (tempBitArr[i]==true) do(
					bHasInterval = True
					strSt = arrTimeTagListP[2][i] as string
					strEt = arrTimeTagListP[3][i] as string
					append arrAddTag ("_Rt  " + (strSt) + " ~ " + strEt)
					append arrAddTag ("_Lt  " + (strSt) + " ~ " + strEt)
					append arrAddTag ("_Fwd  " + (strSt) + " ~ " + strEt)
					append arrAddTag ("_FwRt  " + (strSt) + " ~ " + strEt)
					append arrAddTag ("_FwLt  " + (strSt) + " ~ " + strEt)
					append arrAddTag ("_Bwd  " + (strSt) + " ~ " + strEt)
				)--end : if-tempBitArr
			)--end : for i
			if not bHasInterval do(
				messagebox "need to select list" beep:false
				--arrAddTag = #("_Rt","_Lt","_Fwd","_FwRt","_FwLt","_Bwd")
			)--end : if-bHasInterval
			fnL_addNewTag arrAddTag
		)--end : btnAddExam_02
		
		on btnGetListFromFile pressed do(
			tempPathF = savePathOption_ + "\\\\" + (arrTagFSamples_ini[1])
			tempPathF = substituteString tempPathF "\\\\" "\\"
			tempPathF = getOpenFileName caption:"get Tag List from *.ini" filename:tempPathF type:"ini(*.ini)"
			if tempPathF == undefined or tempPathF == "" do (return 1;)
			--fn_existFileName tempPathF bUnique:False isFullPath:True fileType:".ini"
			arrAddTag = (fnArr_getVal_iniFile tempPathF maxIter:35 inSection:"List01")
			if arrAddTag.count == 0 do (messagebox "can't find value from File"; return 1)
			fnL_addNewTag arrAddTag
		)--end : btnGetListFromFile
		
		on btnSaveTagList_INI pressed do(
			fn_checkDirMake ArrFile_ini[1] bCreat:True
			tempPathF = savePathOption_ + "\\\\" + (arrTagFSamples_ini[1])
			tempPathF = substituteString tempPathF "\\\\" "\\"
			tempPathF = getSaveFileName caption:"save Tag List " types:"ini(*.ini)|*.ini" historyCategory:"save Tag List" filename:(tempPathF)
			if tempPathF == undefined or tempPathF == "" do return 1;
			tempBitArr = (mListTimeTage.selection)
			tempArr2 = #()
			arrTemp_KeyVal_ini = #()
			idxC = 1
			for i in 1 to arrTimeTagListP[7].count do(
				tempArr = #()
				if (tempBitArr[i]==true) do(
					append tempArr (idxC as string)
					append tempArr (arrTimeTagListP[7][i])
					append tempArr2 tempArr
					idxC += 1
				)--end : if
			)--end : for i
			if tempArr2.count <= 0 do (messagebox "need to select List"; return 1;)
			append arrTemp_KeyVal_ini tempArr2
			arrTemp_Section_ini = #("List01")
			--arrTemp_KeyVal_ini = #(#(#("1","_Fwd"),#("2","_Bwd"),#("3","testL")))
			arrTempFile_ini = #(savePathOption_,arrTagFSamples_ini[1])
			fn_saveFPath_ini (tempPathF) arrTemp_Section_ini arrTemp_KeyVal_ini
		)--end : btnSaveTagList_INI
		
	)--end : R_timeTagRange	
	-----------------------------------------------------------------------------------------
	rollout R_bakeRoot "bake root"(
		groupBox groubBox01 "" width:268 height:41 pos:[1,-5]
		pickbutton	pibRefObj "- - Target Object - -" tooltip:"rightClick is remove" autoDisplay:true width:200 height:30 pos:[5,5]
		button bAssing "< assign " tooltip:"1. leftClick : assign [selected object] to Target \n2. rightClick : select Target" width:55 height:30 pos:[210,5]
		button bPositionOption "pos :" tooltip:"position"width:30 height:20 pos:[5,50]
		checkbox chbPosX "x" checked:true pos:[40,55]
		checkbox chbPosY "y" checked:true pos:[70,55]
		checkbox chbPosZ "z" checked:false pos:[100,55]
		button bAppBakeRoot "[ bake ] root " tooltip:"1. leftClick : run Bake \n2. rightClick : select Root" width:70 height:30 pos:[335,5]
		button bAppBakeSel "bake sel" tooltip:"Bake Selected" width:70 height:25 pos:[335,45]
		button bRotationOption "rot :" tooltip:"rotation" width:30 height:20 pos:[5,80]
		checkbox chbRotAll "Rot" checked:false pos:[40,85]
		checkbox chbRot_x "gX" checked:false pos:[120,85]
		checkbox chbRot_y "gY" checked:false pos:[160,85]
		checkbox chbRot_z "gZ(1)" checked:false pos:[210,85]
		label lab01 "< Gimal Axis (if need)" pos:[265,85]
		label lab02 "choice Axis-plane ::" pos:[5,115]
		checkbox chbRot_planX "pX" checked:false pos:[120,115]
		checkbox chbRot_planY "pY(1)" checked:false pos:[160,115]
		checkbox chbRot_planZ "pZ" checked:false pos:[210,115]
		checkbox chbRot_planInvers "inverse" tooltip:"inverse value" checked:false pos:[270,115]
		button bDeleteAttrib "!! delete Attrib" tooltip:"delete custom attributes [first index]" width:100 height:20 pos:[310,145]
		label lab03 "bake with Curve :: " pos:[5,145]
		checkbox optionBake_rotationAmount " RotationAmount" pos:[10,165]
		
		on chbRot_x changed arg do(
			if arg == true do(
				chbRot_y.checked = not arg
				chbRot_z.checked = not arg
				chbRot_planX.checked = not arg
				chbRot_planX.enabled = not arg
				chbRot_planY.enabled = arg
				chbRot_planZ.enabled = arg
			)
		)--end : chbRot_x
		on chbRot_y changed arg do(
			if arg == true do(
				chbRot_x.checked = not arg
				chbRot_z.checked = not arg
				chbRot_planX.enabled = arg
				chbRot_planY.checked = not arg
				chbRot_planY.enabled = not arg
				chbRot_planZ.enabled = arg
			)
		)--end : chbRot_y
		on chbRot_z changed arg do(
			if arg == true do(
				chbRot_y.checked = not arg
				chbRot_x.checked = not arg
				chbRot_planX.enabled = arg
				chbRot_planY.enabled = arg
				chbRot_planZ.checked = not arg
				chbRot_planZ.enabled = not arg
			)
		)--end : chbRot_z
		
		on bDeleteAttrib pressed do with undo on(
			thisObj = selection[1]
			attribRef = custattributes.getdef thisObj 1
			if not attribRef == undefined do(custAttributes.delete thisObj attribRef)
		)--end : bDeleteAttrib-pressed
		
		on pibRefObj rightClick do(
			pibRefObj.object = undefined;
		)--end : pibRefObj
		on bAssing pressed do(
			if selection.count == 0 do (return 1;)
			pibRefObj.object = selection[1]
		)--end : bAssing
		on bAssing rightClick do(
			if isvalidnode (pibRefObj.object) do (select pibRefObj.object)
		)--end : bAssing-rightClick
		on bPositionOption pressed do(
			if chbPosX.checked then(
				chbPosX.checked = False;chbPosY.checked = False;chbPosZ.checked = False;
			)else(chbPosX.checked = True;chbPosY.checked = True;chbPosZ.checked = True; )
		)--end : btn
		on bRotationOption pressed do(
			chbRotAll.checked = if chbRotAll.checked then False else True
		)--end : btn
		----------------------------------------
		fn fnLocalBakeRoot rootSingleTemp=(
			tarRefObj = pibRefObj.object
			baseMat = rootSingleTemp[1].transform
			tempCicleNode = circle radius:0
			tempCicleNode.transform = matrix3 baseMat[1] baseMat[2] baseMat[3] tarRefObj.transform[4]
			tempCicleNode.parent = tarRefObj
			rotALLbool = chbRotAll.checked
			posXbool = chbPosX.checked
			posYbool = chbPosY.checked
			posZbool = chbPosZ.checked
			adjustPos = (tarRefObj.transform.pos - baseMat.pos) * -1
			rangeArr = #((slidertime),animationrange.end)
			needPos = False;
			rotGimbal = False;
			inversVal = 1;
			if chbRot_planInvers.checked then (inversVal = -1) else(inverseVal = 1);
			opBake_rotationAmount_bool = optionBake_rotationAmount.checked
			if posXbool or posYbool or posZbool do needPos = True;
			if chbRot_x.checked or chbRot_y.checked or chbRot_z.checked do(
				if classof(rootSingleTemp[1].rotation.controller) == Euler_XYZ then(
					if chbRot_planZ.checked or chbRot_planY.checked or chbRot_planX.checked do(
						rotGimbal = True;
						if chbRot_x.checked then axis_ = 1
						else if chbRot_y.checked then axis_ = 2
						else if chbRot_z.checked do axis_ = 3
						if chbRot_planX.checked then plAxis_ = 1
						else if chbRot_planY.checked then plAxis_ = 2
						else if chbRot_planZ.checked do plAxis_ = 3
						preRotVal = rootSingleTemp[1].rotation.controller[axis_].value
						vecThis = rootSingleTemp[1].transform[axis_]
						if opBake_rotationAmount_bool do(
							/*-----
							if not isProperty rootSingleTemp[1] "RotationAmount" do (--""
								CustAttributes.add rootSingleTemp[1] attr_forV4System
							)--end : if
							rootSingleTemp[1].baseobject.Custom_Attributes.RotationAmount.controller = bezier_float()
							rootSingleTemp[1].baseobject.Custom_Attributes.RotationAmount.controller.keyable = true
							*/-----
							FnAssign_Attrib_forV4 (rootSingleTemp[1]) ("RotationAmount")
							deleteKeys rootSingleTemp[1].baseobject.Custom_Attributes.RotationAmount.controller #allKeys
						)--end : if-opBake_rotationAmount_bool
					)--end : if
				)--end : if-check controller
				else (messagebox "rotation controller need Euler-Type"; return 1;)
			)--end : if-chbRot
			
			for i in rangeArr[1] to rangeArr[2] do (
				if keyboard.escPressed do exit --Check . Pressed keyboard ESC Key
				slidertime = i --/ TicksPerFrame
				for k in 1 to rootSingleTemp.count do(
					
					if rotGimbal then(
						animate on(rootSingleTemp[1].rotation.controller[axis_].value = preRotVal)
						vecRef = tempCicleNode.transform[axis_]
						vecRef[3] = 0.0
						vecRef = normalize vecRef
						dotVal = dot vecThis vecRef
						angleDeg = 0.0
						angleTorque = 0.0
						if dotVal != 0.0 do(
							angleDeg = acos dotVal
							vecPlane = rootSingleTemp[1].transform[plAxis_]
							dotVal = dot vecRef vecPlane
							dirVal = 1
							if dotVal > 0.0 do dirVal = -1;
							angleDeg = angleDeg * dirVal
							angleTorque = angleDeg * inversVal
						)--end : if
						preRotVal += angleDeg
						animate on(
							rootSingleTemp[1].rotation.controller[axis_].value = preRotVal
							if opBake_rotationAmount_bool do(
								rootSingleTemp[1].baseobject.Custom_Attributes.RotationAmount = angleTorque
							)--end : if
						)--end : animate
						vecThis = rootSingleTemp[1].transform[axis_]
					)else(
						if rotALLbool do (
							baseMat[1] = tempCicleNode.transform[1]
							baseMat[2] = tempCicleNode.transform[2]
							baseMat[3] = tempCicleNode.transform[3]
							animate on(
								rootSingleTemp[k].rotation.controller.value =  baseMat.rotation
							)--end : rootSingleTemp on
						)--end.if
					)--end : if then else.
					
					if needPos do(
						tempPos = tarRefObj.transform.pos + adjustPos
						tempBasePos = (baseMat[4])
						if posXbool do tempBasePos[1] = tempPos[1]
						if posYbool do tempBasePos[2] = tempPos[2]
						if posZbool do tempBasePos[3] = tempPos[3]
						animate on (
							rootSingleTemp[k].position.controller.value =  tempBasePos
						)--end : amimate on
					)--end : if-needPos
				)--end : for-k
			)--end : for-i
			try(delete tempCicleNode)catch()
			if rotALLbool do (
				for k in 1 to rootSingleTemp.count do(
					if classof(rootSingleTemp[k].rotation.controller) == Euler_XYZ then(
						rootSingleTemp[k].rotation.controller = tcb_rotation()
						rootSingleTemp[k].rotation.controller = Euler_XYZ()
					)else(messagebox "finish but need to check rotation controller" beep:false)
				)--end : for k
			)--end : if-rotALLbool
			
		)--end : fnLocalBakeRoot
		----------------------------------------
		on bAppBakeRoot pressed do with undo on(
			if not isvalidnode pibRefObj.object do(messagebox "check [ Target Object ]" beep:false; 
				pibRefObj.object = undefined;
				return 1;
			)--end : if-not
			arrTemp = (getNodeByName (root_name) exact:true ignoreCase:(bool_ignoreCase) all:true)
			rootSingleTemp = #()
			if arrTemp.count == 0 do (messagebox "can't find root-name"; return 1)
			if arrTemp.count == 1 then (
				rootSingleTemp = #(arrTemp[1])
			) else(
				arrTemp = (fn_sel_itemFromMList (R_spExportAssign_List.mtb_List) listSpExpObj selN:1 onlyOneRoot:True)
				if not isvalidnode arrTemp[1] do(messagebox "need to select root  , check [ root list ]"; return 1)
				rootSingleTemp = #(arrTemp[1])
			)--end : if-else
			--can make function----------------------------------
			fnLocalBakeRoot rootSingleTemp
			--------------------------------------------------
		)--end : bAppBakeRoot
		on bAppBakeSel pressed do with undo on(
			if not isvalidnode pibRefObj.object do(messagebox "check [ Target Object ]" beep:false; 
				pibRefObj.object = undefined;
				return 1;
			)--end : if-not
			if selection.count < 1 do(messagebox "need to select" beep:false;return 1;)
			rootSingleTemp = #(selection[1])
			--can make function----------------------------------
			fnLocalBakeRoot rootSingleTemp
			--------------------------------------------------
		)--end : bAppBakeRoot
		on bAppBakeRoot rightClick do(
			arrTemp = (getNodeByName (root_name) exact:true ignoreCase:(bool_ignoreCase) all:true)
			rootSingleTemp = #()
			if arrTemp.count == 0 do (messagebox "can't find root-name"; return 1)
			if arrTemp.count == 1 then (
				rootSingleTemp = #(arrTemp[1])
			) else(
				arrTemp = (fn_sel_itemFromMList (R_spExportAssign_List.mtb_List) listSpExpObj selN:1 onlyOneRoot:True)
				if not isvalidnode arrTemp[1] do(messagebox "need to select root  , check [ root list ]"; return 1)
				rootSingleTemp = #(arrTemp[1])
			)--end : if-else
			select rootSingleTemp[1]
		)--end : bAppBakeRoot-rightClick
	)--end : R_timeTagRange	
	-----------------------------------------------------------------------------------------

	try(closeRolloutFloater RFloater_supportExportAssign) catch()
	RFloater_supportExportAssign = newRolloutFloater (string_nameVersion) (425) (dynamic_floater_height)
	--style:#(#style_titlebar,#style_toolwindow,#style_sysmenu,#style_resizing,#style_minimizebox,#style_maximizebox)
	addRollout (R_timeTagRange) (RFloater_supportExportAssign) rolledUp:false border:true
	addRollout (R_bakeRoot) (RFloater_supportExportAssign) rolledUp:true border:true
	addRollout (R_spExportAssign_List) (RFloater_supportExportAssign) rolledUp:true border:true
	addRollout (R_spExportAssign_option) (RFloater_supportExportAssign) rolledUp:true border:true
)--end : code