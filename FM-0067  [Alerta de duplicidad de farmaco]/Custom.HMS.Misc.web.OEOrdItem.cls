Include EnsUtil

/// ******************************************************************************
/// $Id:  $
/// 
/// Description: Class for business rules related web.OEOrdItem. 
/// 		     This class must be used for OEOrdItem CLXX (Region) customizations 
/// 			 (Just "web.OEOrdItem" edition customizations). 
/// 	    	 OEOrdItem custom data related to User.OEOrdItem must be done on 
/// 		     Custom.HMS.Misc.User.OEOrdItem 
/// 
/// Update history:
/// 2011-01-19  Victor Skrobot  CCR:   TRC: Original version
/// 2015-01-12	Victor Skrobot	- Update
/// 2016-03-03	DZ	CCR:	TRC:	JIRA:TC-72952
/// 	- Test if %request exists on several methods, due to error raised in HL7 routines (integrations/interfaces)
/// ******************************************************************************/
Class Custom.HMS.Misc.web.OEOrdItem Extends %RegisteredObject [ Not ProcedureBlock ]
{

/// This Parameter should be updated when synced from Perforce
Parameter SrcVer = "$Id:  $";

/// Check if list of order items has controlled drugs and these have "folio" (OEORIText1) fiels entered
/// Log:
/// 		TRC: 119452 2012-08-29 , Add validation for OEORIText1 fiel for pharmacy order items when is a conrolled drug	
ClassMethod CheckControlledItems(pItemList) As %String
{
	Set tResult=""
	Set tResultIDs=""
	Try {
		if (pItemList="") Quit
		Set len=$l(pItemList,"^")
		For tI=1:1:len
		{
			Set itemID = $p(pItemList,"^",tI)
			If (itemID'="")
			{
				Set ordId = $p(itemID,"||",1)
				Set ordCS = $p(itemID,"||",2)
				If ((ordId'="") && (ordCS'=""))
				{
					///	2017-10-12	Victor Skrobot	JIRA	TC-134351
					if $$GetITM2OrderVersion^COEOrdItem9(itemID) continue
					///	
					Set itemMasterID = $p($g(^OEORD(ordId,"I",ordCS,1)),"^",2)	
					Set text1 = $p($g(^OEORD(ordId,"I",ordCS,13)),"^",20) //;OEORI_Text1 
					Set tempItmRes = ..CheckControlledDrgItem(itemMasterID,text1,"")
					If (tempItmRes'="")
					{							
						Set tResult=tResult_tempItmRes_$c(13)
						///	2014-05-26	Victor Skrobot	TRC	134119
						Set tResultIDs=tResultIDs_itemID_"^"
					}				
				}	
			}
		}
	}Catch(tException){Set tResult="ERROR"}
	
	If (tResult'="")
	{
		Set tSC = $System.Status.OK()
		Set tMsg = "Los siguientes items son controlados y requiere que se ingrese el numero de folio:" ///	##class(Region.CLXX.Integration.Nexus.CS.ConfigRegistry).GetConfigValueFor("Drugs.Msg.FolioRequired","",.tSC)
		If $System.Status.IsError(tSC) Set tMsg="" 
		If (tMsg="") Set tMsg = "Los siguientes items son controlados y requiere que se ingrese el numero de folio:"
		Set tResult=tMsg_$c(13)_tResult
		///	2014-05-26	Victor Skrobot	TRC	134119
		Set tResult=tResult_"#"_tResultIDs
	}
	
	Quit tResult
}

ClassMethod CheckControlledDrgItem(pItemMastId, pItemValue, pFlag = "") As %String
{
	New tResult
	Set tResult=""
	Try {
		If (pItemMastId="") Quit 
		Set itmMastIndex1 = $p(pItemMastId,"||",1) If (itmMastIndex1="") Quit 
		Set itmMastIndex2 = $p(pItemMastId,"||",2) If (itmMastIndex2="") Quit 
		Set drgFormDR = $p($g(^ARCIM(itmMastIndex1,itmMastIndex2,1)),"^",12)
		If (drgFormDR="") Quit 
		Set drgFrmIdx1 = $p(drgFormDR,"||",1) If (drgFrmIdx1="") Quit 
		Set poisonId = $p($g(^PHCD(drgFrmIdx1,1)),"^",4) If (poisonId="") Quit 
		Set requireApproval = $p($g(^PHCPO(poisonId)),"^",6)
		Set pItemValue = $ZStrip(pItemValue,"<>W")
		// The  next line is commented out due to TRC 136830.
		//Set tSCValidInteger = ##class(%Integer).IsValid(pItemValue)		
		If (requireApproval="Y")  && (pItemValue="")
		{
			Set itemDesc = $p($g(^ARCIM(+pItemMastId,$p(pItemMastId,"||",2),1)),"^",2) 
			Set tResult = $c(13)_itemDesc
		}
	}Catch(tException)
	{
		Set tResult="Se ha producido un error al validar droga controlada. Intente nuevamente o contáctese con administrador"
	}
	If ((tResult'="") && (pFlag'=""))
	{
		Set tSC = $System.Status.OK()
		Set tMsg = "Los siguientes items son controlados y requiere que se ingrese el numero de folio:"	///	##class(Region.CLXX.Integration.Nexus.CS.ConfigRegistry).GetConfigValueFor("Drugs.Msg.FolioRequired","",.tSC)
		If $System.Status.IsError(tSC) Set tMsg="" 
		If (tMsg="") Set tMsg = "Los siguientes items son controlados y requiere que se ingrese el numero de folio:"
		s tResult = tMsg_$c(13)_tResult
	}
	Quit tResult
}

/// TRC92184-  Add method because is required from oeorder.sessionlist.js
ClassMethod GetVolumeDefault(pOID As %String) As %String
{
	s Dosage="" 
	s Date=+$h 
	&sql(select OEORI_ARCOS_DR, OEORI_ItmMast_DR, OEORI_FlowQty into :OSId,:OrdItemId, :Volume 
	from SQLUser.OE_OrdItem where OEORI_RowId = :pOID) 
	i OSId,Volume="" { 
		&sql( select ITM_DoseQty into :Dosage from SQLUser.ARC_OrdSetDateItem where ITM_ParRef->DATE_ParRef = :OSId and (((ITM_ParRef->DATE_DateFrom <= :Date) OR (ITM_ParRef->DATE_DateFrom is null)) and ((ITM_ParRef->DATE_DateTo >= :Date) or (ITM_ParRef->DATE_DateTo is null))) and ITM_ARCIM_DR = :OrdItemId ) 
		i Dosage { 
			&sql(update SQLUser.OE_OrdItem (OEORI_FlowQty, OEORI_Unit) values (:Dosage, 'ML') where OEORI_RowId = :pOID) 
		} 
	} 
	q Dosage
}

ClassMethod LookUpExecute(ByRef QHandle As %Library.Binary, pEpisodeID As %String, pDate As %Date, pNo As %String) As %Library.Status
{
	New repid,ind,papmi,dt,stop,zsess,str

	Set repid=$I(^CacheTemp("TRAK"))
	
	Set pDate = $Select(pDate'="":$ZDateH(pDate,4),1:"")
	
	Set tPars=0
	Set strSQL = "SELECT "_
		"DISTINCT by (COEORI_No) COEORI_No, COEORI_Date, COEORI_Time, COEORI_CTPCP_DR->CTPCP_Desc CTPCP_Desc "_
		"FROM  "_
		"Custom_HMS_Misc_User.OEOrdItem "
		if (pEpisodeID'="")!(pDate'="")!(pNo'="") Set strSQL=strSQL_"WHERE "
		if pEpisodeID'="" Set strSQL=strSQL_"COEORI_PAAdm_DR="_pEpisodeID_" ",tPars=1
		if pDate'="" Set strSQL=strSQL_$Select('tPars:"",tPars:"AND")_" COEORI_Date="_pDate_" ",tPars=tPars+1
		if pNo'="" Set strSQL=strSQL_$Select('tPars:"",tPars:"AND")_" COEORI_No='"_pNo_"' ",tPars=tPars+1
		Set strSQL=strSQL_" and NOT COEORI_OEORI_DR->OEORI_ItemStat_DR->OSTAT_Code in ('U','D')"
		Set strSQL=strSQL_" order by TO_CHAR(COEORI_No,'09999') desc"
		
	Set tRs = ##class(%Library.ResultSet).%New()
	
	If ('$IsObject(tRs)) Quit $$$OK
	
	Do tRs.Prepare(strSQL)
	
	Set tSc = tRs.Execute()
    
	If $System.Status.IsOK(tSc)
	{
		
		While tRs.Next() 
		{			
			set tNo				= tRs.Data("COEORI_No")
			set tDate			= $ZDate(tRs.Data("COEORI_Date"),4)
			set tTime			= $ZTime(tRs.Data("COEORI_Time"),2)
			set tDoc			= tRs.Data("CTPCP_Desc")
			
			s ^CacheTemp("TRAK",repid,$i(ind))=$lb(tNo,tDate,tTime,tDoc)
		}
		
		do tRs.Close()
	}

	// Build QHandle (AtEnd,ReportID,Index)
	Set QHandle=$lb(0,repid,0)
	Quit $$$OK
}

ClassMethod LookUpFetch(ByRef QHandle As %Library.Binary, ByRef Row As %Library.List, ByRef AtEnd As %Library.Integer = 0) As %Library.Status
{
	// This fetch method should never have to change. 

	// repid - Report ID
	// ind - sequence index which represents each row
	
	New repid,ind

	// Restore QHandle
	Set AtEnd=$li(QHandle,1)
	Set repid=$li(QHandle,2)
	Set ind=$li(QHandle,3)

	Set ind=$o(^CacheTemp("TRAK",repid,ind))
	If ind="" {				// if there are no more rows, finish fetching
		Set AtEnd=1
		Set Row=""
	}
	Else {					// fetch row
		Set Row=^CacheTemp("TRAK",repid,ind)
	}
	

	// Save QHandle
	s QHandle=$lb(AtEnd,repid,ind)
	Quit $$$OK
}

ClassMethod LookUpClose(QHandle As %Library.Binary) As %Library.Status
{
	New repid
	Set repid=$li(QHandle,2)

	Kill ^CacheTemp("TRAK",repid)

	Quit $$$OK
}

Query LookUp(pEpisodeID As %String, pDate As %Date, pNo As %String) As %Library.SQLQuery(CONTAINID = 0, ROWSPEC = "No:%String,Date:%Date,Time:%Time")
{
}

ClassMethod UpdPrescNo(pEpisodeID As %String, pRepeating As %String = "") As %String
{
	
	if pEpisodeID="" Quit $$$OK
	
	Set tResult = "1^ok"
	
	Set tMessages(0)="Confirma la inserción (s) artículo (s) en la prescripcion actual?"
	Set tMessages(1)="No es posible incluir porque no hay prescripcion anterior. Haga click en Generar Nueva para generar una nueva prescripcion."
	Set tMessages(2)="No se puede incluir porque la última receta no es hoy. Debe generar una nueva receta."

	Set tMaxHours = 36
	Set tHourNow = $Piece($h,",",2)/60/60
	Set tMinDay = $h-1
	Set tMinHour = tMaxHours-tHourNow
	if tMinHour>24 Set tMinDay = $h-1, tMinHour = (tMaxHours-tHourNow)-24
	
	Kill %session.Data("CurrPrescNo")
	
	Set strSQL = "SELECT TOP 1 COEORI_No, COEORI_Date, COEORI_Time FROM Custom_HMS_Misc_User.OEOrdItem WHERE COEORI_PAAdm_DR = ? "
	If pRepeating'="" Set strSQL = strSQL_"AND COEORI_OEORI_DR->OEORI_ItemStat_DR->OSTAT_Code = 'U' "
	If pRepeating="" Set strSQL = strSQL_"AND COEORI_OEORI_DR->OEORI_ItemStat_DR->OSTAT_Code <> 'U' "
	Set strSQL = strSQL_"and +COEORI_No > 0 ORDER BY COEORI_Date Desc, COEORI_Time Desc"
	
	Set tRsCheck = ##class(%Library.ResultSet).%New()
	
	Do tRsCheck.Prepare(strSQL)
	
	Set tSc = tRsCheck.Execute(pEpisodeID)
	    
	If $System.Status.IsOK(tSc)
	{

		If tRsCheck.Next()
		{

			Set tDate = tRsCheck.Data("COEORI_Date")
			Set tTime = tRsCheck.Data("COEORI_Time")/60/60
			
			if ((tDate<tMinDay)!(tDate=tMinDay&(24-tTime>tMinHour))),(pRepeating="") {
				
				Set tResult = "0^"_tMessages(2)
				
			}else{
				
				If pRepeating'="" {
					Set %session.Data("CurrPrescNo") = -1
				}else{
					Set %session.Data("CurrPrescNo") = tRsCheck.Data("COEORI_No")
				}
				
			}
	
		}else{
			
			if (pRepeating="") Set tResult = "0^"_tMessages(1)
			
		}
		
	}
	
	Quit tResult
}

/// 	2013-09-05	Victor Skrobot	TRC		CCR		
ClassMethod IsNewPrescNo(tParam As %String = "") As %String
{
	Set tResult = ""
	
	If $ZCVT(tParam,"U")="YES" {
		//If $ZCVT($Get(%session.Data("IsNewPrescNo")),"U")'="YES" Set tResult = "changed"
		Set %session.Data("IsNewPrescNo") = "Yes"
	}elseif $ZCVT(tParam,"U")="NO"{
		//If $ZCVT($Get(%session.Data("IsNewPrescNo")),"U")="YES" Set tResult = "changed"
		Kill %session.Data("IsNewPrescNo")
	}

	Set tResult = $ZCVT($Get(%session.Data("IsNewPrescNo")),"U")
	Quit tResult
}

ClassMethod CancelPrescNo(pEpisodeID) As %String
{
	Kill %session.Data("CurrPrescNo")

	Quit ""
}

ClassMethod OnAfterSaveInWorkflow() As %String
{
	Set tSC 			= $$$OK
	Set tClassName 		= $$$CurrentClass
	Set tEventMethod	= $$$CurrentMethod
	Quit:'$Data(%request) tSC
	
	Set tForm		  	= $Get(%request.Data("TFORM",1))	
	Set tID			 	= $Get(%request.Data("ID",1))
	Set tEpisodeID 	 	= $Get(%request.Data("EpisodeID",1))
	Set tOEOrdItemIDs 	= $Get(%request.Data("OEOrdItemIDs",1))
	
	Try {
		If (tForm = "OEOrder.SummaryScreen") {
			Set lOrderItems = $ListFromString(tOEOrdItemIDs, "^")
			For iCtr = 1:1:$ListLength(lOrderItems) {
				Set tOrderItemID = $Piece($List(lOrderItems, iCtr), "*", 2)
				If ($Get(tOrderItemID) '= "") {
					Set oOEOrdItem = ##class(User.OEOrdItem).%OpenId(tOrderItemID)
					If ($IsObject(oOEOrdItem)) {
						If ("PNAC|PACAM" [ oOEOrdItem.OEORIItmMastDR.ARCIMItemCatDR.ARCICCode) {
							Set executed = ..IsExecuted(tOrderItemID)
							If ('executed) {
								Do ..Execute(tOrderItemID)
							}
						}
					}
				}
			}
		}
	} Catch (tException) {
		Set tSC = tException.AsStatus()
	}
	
	If ($System.Status.IsError(tSC)) {
		Set tText = $System.Status.GetErrorText(tSC)
		Do:msg msg.AddItem("A","Error ("_tClassName_"."_tEventMethod_"):",tText,$Get(compid),"")
		Set tSC = 0
	}
	
	Quit tSC
}

/// TRC 89938: Permite ejecutar un item de orden dado.
ClassMethod Execute(OEItmID As %String = "") As %String
{
	If OEItmID="" Quit 0
	d ChangeStatus^COEOrdItem(OEItmID,"E",%session.Data("LOGON.USERID"))
	Quit 1
}

/// TRC 89938: Permite obtener el estado actual del item de orden dado.
ClassMethod IsExecuted(OEItmID As %String = "") As %String
{
	If OEItmID="" Quit 0
	Set Status=$p($g(^OEORD(+OEItmID,"I",$p(OEItmID,"||",2),1)),"^",13) /// Permite obtener el ID del estado actual
	Set ExecStat=$o(^OEC("OSTAT",0,"Code","E","")) /// Permite obtener el ID del estado (E)xecuted
	Quit (Status=ExecStat)
}

ClassMethod GetOrderItemPriority(OrdItemId As %String) As %String
{
	Set tResult = ""
	Try {
		If (OrdItemId '= "") {
			Set oOrderItem = ##class(User.OEOrdItem).%OpenId(OrdItemId)
			If ($IsObject(oOrderItem)) {
				Set tResult = $p($g(^OEORD(+OrdItemId,"I",+$p(OrdItemId,"||",2),1)),"^",8) _ "^" _ oOrderItem.OEORIItmMastDR.ARCIMDesc
			}
		}
	} Catch(tException) {
		Set tResult = "ERROR^" _ ##class(Custom.HMS.Misc.Utilities.General).GetFmtErrText(tException)
	}
	Quit tResult
}

ClassMethod OnAfterSave() As %String
{
	
	Set tSC = $$$OK	
	Set tClassName    = $$$CurrentClass 
	Set tEventMethod  = $$$CurrentMethod	
	Quit:'$Data(%request) tSC
	
	Set tForm		  = $Get(%request.Data("TFORM",1))	
	Set tID			  = $Get(%request.Data("ID",1))
	Set tEpisodeID 	  = $Get(%request.Data("EpisodeID",1))
	Set tOEOrdItemIDs = $Get(%request.Data("OEOrdItemIDs",1))

	Set HashStatus = ""
	If ((tOEOrdItemIDs '= "") && '$Data(^TEMP("OnAfterSave^OEOrdItem", +$h, $System.Encryption.MD5Hash(tOEOrdItemIDs)))) {
		Set ^TEMP("OnAfterSave^OEOrdItem", +$h, $System.Encryption.MD5Hash(tOEOrdItemIDs)) = "0^0^0"
	}
	Set:(tOEOrdItemIDs '= "") HashStatus = $Get(^TEMP("OnAfterSave^OEOrdItem", +$h, $System.Encryption.MD5Hash(tOEOrdItemIDs)))

	If $Get(COPYID)'="",$Get(RptRowID)'="" {
		
		//////////////////////////////////////////////////
		///	2015-12-21	Victor Skrobot	TRC	I47271	JIRA
		///	change OEORIOrdDeptDR if its wrong (distinct from PAAdm)
		/*
		Set (tWard,tDept) = ""
		&sql(select PAADM_currentward_dr->WARD_LocationDR into :tWard  
					from SQLUser.PA_Adm where 
					PAADM_Rowid=:tEpisodeID)
					
		&sql(select oeori_orddept_dr into :tDept from SQLUser.OE_OrdItem where oeori_rowid=:RptRowID)
		if (SQLCODE=0)&&(tDept'=tWard){
			&sql(update %notrigger SQLUser.OE_OrdItem set oeori_orddept_dr=:tWard where oeori_rowid=:RptRowID)
		}
		*/
		///
		///////////////////////////////////////////////////
		
	}

	/////////////////////////////////////////////////
	/// after edit Details save "X" on OEORIText4
	TRY {
		If tID'="","OEOrder.Med^OEOrder.Lab^OEOrder.Normal^OEOrder.RM^OEOrder.IV^OEOrder.Diet"[tForm {
			Set oeitm = ##class(User.OEOrdItem).%OpenId(tID)
			If $IsObject(oeitm) {
				If oeitm.OEORIItemStatDR.OSTATDesc = "Inactivo" {
					Set oeitm.OEORIText4 = "X"
					Do oeitm.%Save()
				}
				////////////////////////////////////////////////////
				///	2015-03-18	Victor Skrobot	TRC	190339	
				///	update frequency the same as RM
				If tForm="OEOrder.RM" {
					Set tRMFrequency = $Get(%request.Data("RMFrequency",1))
					If tRMFrequency'="" {
						Do ##class(Custom.HMS.Misc.web.OEOrdItem).UpdateRMFrequency(tID,tRMFrequency)
					}
				}
				///
				////////////////////////////////////////////////////
				
				////////////////////////////////////////////////////
				///	2016-04-11	Victor Skrobot	JIRA	TC-73770
				If $Get(%request.Data("OEORICurrRepeatNumber",1)),$Get(%request.Data("OEORICurrRepeatNumber",1))'=oeitm.OEORICurrRepeatNumber {
					Set oeitm.OEORICurrRepeatNumber = %request.Data("OEORICurrRepeatNumber",1)
					Do oeitm.%Save()
				}
				///
				////////////////////////////////////////////////////
				Kill oeitm
			}
		}
		
		If ((tID '= "") && (tForm = "OEOrder.Med")) {
			Do ..CheckOrdItemExpiryDate(tID, 1)
			
			Set oeitm = ##class(User.OEOrdItem).%OpenId(tID)
			If $IsObject(oeitm) {
				If oeitm.OEORICalcQtyFlag = "Y",oeitm.OEORIVariableDose '= "" {
					Set oeitm.OEORIVariableDose = ""
					Do oeitm.%Save()
				}
			}
			
		}
		
		If ((tOEOrdItemIDs '= "") && (tForm = "OEOrder.Custom")) {
			Do ..CheckOrdItemExpiryDate(tOEOrdItemIDs, 1)
		}
		If (tForm = "OEOrder.Custom") {
			///
			Set tCheckGES = $Get(^TMP("WEB","ORDER_ENTRY", %session.SessionId, "CLXX_GES")) 
			Set tId = $Order(^TMP("WEB","ORDER_ENTRY","VISIBLEITEMS",%session.SessionId,""))
			While tId,tCheckGES {
				If $Data(^OEORD(+tId,"I",$Piece(tId,"||",2),1)) {
					Set $Piece(^OEORD(+tId,"I",$Piece(tId,"||",2),13),"^",24) = $S($Piece(tCheckGES,"^",1):"Y",1:"N")
					Set $Piece(^OEORD(+tId,"I",$Piece(tId,"||",2),13),"^",25) = $S($Piece(tCheckGES,"^",2):"Y",1:"N")
					Set $Piece(^OEORD(+tId,"I",$Piece(tId,"||",2),13),"^",26) = $S($Piece(tCheckGES,"^",3):"Y",1:"N")
				}
				Set tId = $Order(^TMP("WEB","ORDER_ENTRY","VISIBLEITEMS",%session.SessionId,tId))
			}
			///
		}

	}CATCH{
		}
	/////////////////////////////////////////////////
	
	/// 2015-08-11	DZ	CCR:CLXX9429	TRC:I39109
	/// 	- solve error in repeat order, when there are 2 or more orders of the same item, and they have linked items
	If $Data(%session)
	{
		If +$Get(COPYID), +$Get(RptRowID)
		{
			Set ^TMP("WEB","ORDER_ENTRY", %session.SessionId, "CLXX_COPYID", RptRowID) = COPYID
		}
	}
	
	////////////////////////////////////////////////////
	/// 2016-06-08	Victor Skrobot	JIRA	TC-83546
	///	check if RecLoc its Ok by the configuration rule
	If $Data(%session)
	{
		If +$Get(COPYID), +$Get(RptRowID)
		{
			Set tRepeatId = RptRowID
			///	check RecLoc
			Set tAdm = +$Get(^OEORD(+tRepeatId))
			Set tArcim = $Piece(^OEORD(+tRepeatId,"I",$Piece(tRepeatId,"||",2),1),"^",2)
			Set tRecLoc = $Piece(^OEORD(+tRepeatId,"I",$Piece(tRepeatId,"||",2),3),"^",6)
			Set tPriority = $Piece(^OEORD(+tRepeatId,"I",$Piece(tRepeatId,"||",2),1),"^",8)
			Set tSttDat = $Piece($Get(^OEORD(+tRepeatId,"I",$Piece(tRepeatId,"||",2),1)),"^",9)
			Set tOkRecLoc = $$recloc^COEOrdItem14(tArcim,tAdm,$Piece($h,",",2),"",tPriority,"",tSttDat)
			If tOkRecLoc'=tRecLoc {
				&sql(update %notrigger SQLUser.OE_OrdItem (OEORI_RecDep_DR) values (:tOkRecLoc) where OEORI_RowID = :tRepeatId)
			}
			///
		}
	}
	///
	////////////////////////////////////////////////////

	//if tForm = "OEOrder.SummaryScreen" {
	
		//Do:$Get(%request.Data("TCUSTOM",1))="" 
		If ($Piece(HashStatus, "^", 1) = "0") {
			Do ..UpdatePrescNo(tEpisodeID, tOEOrdItemIDs)
			Set $Piece(HashStatus, "^", 1) = "1"
		}
	
		//Do ..CheckUnverified(tEpisodeID, tOEOrdItemIDs)
		
	//}
	
	If ($Piece(HashStatus, "^", 2) = "0") {
		Do ..UpdateOEORIFromLinked(tOEOrdItemIDs)
		Set $Piece(HashStatus, "^", 2) = "1"
	}

	Do ..UpdateDetailsFromParentItem(tID)

	If ($Piece(HashStatus, "^", 3) = "0") {
		Do ..UpdateOrderSeq(tOEOrdItemIDs,"")
		Set $Piece(HashStatus, "^", 3) = "1"
	}
	
	///	Do ..ExecuteItemsWithTCEDIQuestionnaire(tOEOrdItemIDs)
	
	Set:(tOEOrdItemIDs '= "") ^TEMP("OnAfterSave^OEOrdItem", +$h, $System.Encryption.MD5Hash(tOEOrdItemIDs)) = HashStatus
	Set HashDate = ""
	Do {
		Set HashDate = $Order(^TEMP("OnAfterSave^OEOrdItem", HashDate))
		Quit:((HashDate=+$h) || (HashDate=""))
		Kill ^TEMP("OnAfterSave^OEOrdItem", HashDate)
	} While ((HashDate < +$h) && (HashDate '= ""))

	if tForm = "OEOrder.SummaryScreen" {
	
		////////////////////////////////////////////////////////////
		///	2013-01-11	Victor Skrobot	TRC		CCR
		/// if user is Enfermeria  ------- changed ------ and SubCategory is INFUSION set Status as Unverified
		/// and DrugForm is "FA SOL INY","POLV LIOF","POLV LIOF INY","SOL INY","SOL ISOT INY","MT COLAP","MT NO COLAP"
		/*
		If $zcvt($Get(%session.Data("LOGON.GROUPDESC")),"U")["ENFERMER" {
			
			For tCount=1:1:$Length(tOEOrdItemIDs,"^")-1 {
				
				Set tOEOrdItemID = $Piece($Piece(tOEOrdItemIDs,"^",tCount),"*",2)
				Set tArcim = $p($p(tOEOrdItemIDs,"^",tCount),"*",1)
				//Set tType = $$ordertype^COEOrdItem(tArcim)
				//If tType="I" {
				Set tThisDrgForm = ..GetDrgForm(tArcim)
				Set tDrgForms = $LISTBUILD("FA SOL INY","POLV LIOF","POLV LIOF INY","SOL INY","SOL ISOT INY","MT COLAP","MT NO COLAP")
				If $LISTFIND(tDrgForms,tThisDrgForm) {
					&SQL(update SQLUser.OE_OrdItem (OEORI_ItemStat_DR) values (2) where OEORI_RowID = :tOEOrdItemID)
					///	2013-01-24	
					If $Get(%session.Data("SUMMINCItmLocs"))'="" {
						Set tINCILoc = $Piece(%session.Data("SUMMINCItmLocs"),"^",tCount)
						Set tLoc = $Piece(tINCILoc,"*",1)
						Set tQtyLogic = $Piece(tINCILoc,"*",2)
						Set tSQL = "select INCIL_RowID, INCIL_LogQty from SQLUser.INC_ItmLoc where "_
									"INCIL_INCI_ParRef->INCI_ARCIM_DR=? "_
									"and "_
									"INCIL_CTLOC_DR=?"
						Set tRs = ##class(%Library.ResultSet).%New()
						Do tRs.Prepare(tSQL)
						Set tSc = tRs.Execute(tArcim,tLoc)
			    		If tRs.Next() {
				    		Set tINCIRowID = tRs.GetData(1)
				    		If tRs.GetData(2)'=tQtyLogic {
					    		&sql(update SQLUser.INC_ItmLoc (INCIL_LogQty) values (:tQtyLogic) where INCIL_RowID = :tINCIRowID)
				    		}
			    		}
			    		Do tRs.%Close()
					}
					///
				}
				
			}
			
		}
		*/
		////////////////////////////////////////////////////////////
    	
		//Do ..ChkRepeatProcess(tOEOrdItemIDs)
		//Kill %session.Data("IsNewPrescNo")
		
		////////////////////////////////////////////////////////////
		///	2013-10-07	Victor Skrobot	TRC	155570	CCR	SMOC0869	
		///	set PAADM_TempLoc_DR empty to avoid problem with Floorplan
		&sql(UPDATE SQLUser.PA_Adm SET PAADM_TempLoc_DR = NULL WHERE PAADM_RowID = :tEpisodeID)
		////////////////////////////////////////////////////////////
    	
	}
	
	Quit tSC
}

ClassMethod OnBeforeSummary() As %String
{
	Quit:'$Data(%request) 1
	
	///	2013-01-24
	/// verified Stock to avoid override
	Kill %session.Data("SUMMINCItmLocs")
	If $zcvt($Get(%session.Data("LOGON.GROUPDESC")),"U")["ENFERMERIA" {
		Set tOEOrdItemIDs = $Get(%request.Data("OEOrdItemIDs",1))
		For tCount=1:1:$Length(tOEOrdItemIDs,"^")-1 {
		
			Set tArcim = $p($p(tOEOrdItemIDs,"^",tCount),"*",1)
			Set tOEORI = $p($p(tOEOrdItemIDs,"^",tCount),"*",2)
			//Set tINCI = ..GetINCIByArcim(tArcim)
			Set tINCI = $$GetINCI^ST02(+tArcim)
			Set tOBJ = ##class(User.OEOrdItem).%OpenId(tOEORI)
			Set tLoc = tOBJ.OEORIRecDepDR.%Id()
			Set tItmLoc = ##class(web.INCItmLoc).GetItemLocData(tINCI,tLoc)
			Set tQtyLogic = $Piece(tItmLoc,"^",3)
			Set %session.Data("SUMMINCItmLocs") = $Get(%session.Data("SUMMINCItmLocs"))_tLoc_"*"_tQtyLogic_"^"
		
		}

	}
	///
	
	Quit 1
}

ClassMethod GetINCIByArcim(pARCIM As %String) As %String
{
	Set tReturn = ""
	
	&sql(select INCI_RowId into :INCIRowId
		 from SQLUSer.INC_Itm
		 where INCI_OriginalARCIM_DR = :pARCIM)
	
	If 'SQLCODE Set tReturn = INCIRowId
	
	Quit tReturn
}

ClassMethod FormatSeqNo(pOEItms As %String)
{
	
	s itemc=$l(pOEItms,"^")-1,hoje=+$h
	
	f c=1:1:itemc {
		
		s itm=$p($p(pOEItms,"^",c),"*",2)
		
		s obj=##class(User.OEOrdItem).%OpenId(itm)
		
		if obj, '$IsObject(obj.OEORIOEORIDR), (obj.OEORIItemStatDR = 10) {
			
			s seqno=obj.OEORISeqNo
		
			s seqno1=$p(seqno,".")
			s seqno2=$p(seqno,".",2)
		
			s seqno1=$e(10000+seqno,2,5)
			i seqno2'="" s seqno2=$e(100+seqno2,2,3)
		
			s seqno=seqno1
		
			i seqno2'="" s seqno=seqno_"."_seqno2
		
			s obj.OEORISeqNo = seqno
		
			d obj.%Save()
			
			Kill obj
			
		}
				
	}

	k seqnos
	f c=1:1:itemc {
		
		s itm=$p($p(pOEItms,"^",c),"*",2)
		
		s obj=##class(User.OEOrdItem).%OpenId(itm)
		
		if obj, $IsObject(obj.OEORIOEORIDR), (obj.OEORIItemStatDR = 10) {
			
			s seqno=obj.OEORIOEORIDR.OEORISeqNo
		
			s seqno1=$p(seqno,".")
			S seqnos=$Get(seqnos)+1
			s seqno2=seqnos
		
			s seqno1=$e(10000+seqno,2,5)
			i seqno2'="" s seqno2=$e(100+seqno2,2,3)
		
			s seqno=seqno1
		
			i seqno2'="" s seqno=seqno_"."_seqno2
		
			s obj.OEORISeqNo = seqno
		
			d obj.%Save()
			
			Kill obj	
		}
				
	}
}

ClassMethod OnBeforeSave() As %String
{
	Set tSC = 1 //$$$OK	
	Set tClassName   = $$$CurrentClass 
	Set tEventMethod = $$$CurrentMethod
	Quit:'$Data(%request) tSC
	
	Set tForm    = $Get(%request.Data("TFORM",1))
	if (tForm="OEOrder.ChangeStatus")
	{
		
		Set tGroupID = %session.Data("LOGON.GROUPID")
		Set tOrdId   = $Get(ordid)
		Set tStatus  = %request.Get("ChangeStatus")
		Set tStatus  = ##class(web.OECOrderStatus).GetIdFromCodeOrDescription(tStatus)
		Set tObjItm  = ##class(User.OEOrdItem).%OpenId(tOrdId)
		Set tItmStat = tObjItm.OEORIItemStatDR.OSTATDesc
		
		If (tItmStat["Suspen")
		{
			Do msg.AddItem("E","Cambio de Estado","Esto estado no puede ser cambiado!")
			Set tSC = 0
		}
		
		///	Suspendido
		If (tStatus=4)
		{

			Set tCateg   = tObjItm.OEORIItmMastDR.ARCIMItemCatDR.ARCICOrdCatDR.ORCATDesc
			Set tRsCateg = ##class(%ResultSet).%New("web.SSGroupOrderCategory:FindList")
			DO tRsCateg.Execute(tGroupID,tCateg)
			If 'tRsCateg.Next()
			{
				Do msg.AddItem("E","Cambio de Estado","Su grupo de seguridad no tiene permiso para este cambio! Ingrese en contacto con Administrador!")
				Set tSC = 0
			}
			
			;s zn=$zn
			;d ^SSMOCARQ
			If (..CheckUnverified($Get(EpisodeID),$Get(ordid))) {
				If ($Get(TOVERRIDE)="")
				{
					Do msg.AddItem("W","Cambio de Estado","Existe solicitud(es) para manana. Desea suspender tambien para manana?")
					Set tSC = 0
				}elseif ($Get(TDIRTY)'="")
				{
					Do ..CheckUnverified($Get(EpisodeID),$Get(ordid),"Suspendido")
					Set tSC = 1
				}
			}
		}
		
		Kill tObjItm
		
	}
	
	Quit tSC
}

ClassMethod GetLastPrescByEpis(pEpisodeID As %String, pUser As %String = "", pDefault As %String = "", pPrescNo As %String = "") As %String
{

	Set tResult = ""
	
	Set strSQL = "SELECT COEORI_No, COEORI_Date, COEORI_Time FROM Custom_HMS_Misc_User.OEOrdItem WHERE COEORI_PAAdm_DR = ? and not COEORI_OEORI_DR->OEORI_ItemStat_DR->OSTAT_Code in ('U','D') "
	If pPrescNo'="" Set strSQL = strSQL_" and COEORI_No = "_pPrescNo
	If pUser="",$Get(%session),$IsObject(%session) {
		Set pUser = %session.Get("LOGON.USERID")
	}
	If pUser'="" {
		Set (CPId,CTCPT)=""
		Set CPId=##class(web.SSUser).GetDefaultCareProvider(pUser)
		If CPId'="" {
			Set obj=##class(User.CTCareProv).%OpenId(CPId)
			If obj,$IsObject(obj.CTPCPCarPrvTpDR) {
				Set CTCPT=obj.CTPCPCarPrvTpDR.CTCPTInternalType
				Set strSQL = strSQL_"and COEORI_CarePrvTp_DR->CTCPT_InternalType = '"_CTCPT_"' "
			}
		}	
	}
	If pPrescNo="" Set strSQL = strSQL_"ORDER BY COEORI_Date Desc, COEORI_Time Desc"
	If pPrescNo'="" Set strSQL = strSQL_"ORDER BY COEORI_Date Asc, COEORI_Time Asc"
	Set tRsCheck = ##class(%Library.ResultSet).%New()
	
	Do tRsCheck.Prepare(strSQL)
	
	Set tSc = tRsCheck.Execute(pEpisodeID)
	    
	If $System.Status.IsOK(tSc)
	{

		If tRsCheck.Next()
		{
			
			///	Set tResult = tRsCheck.Data("COEORI_No")_"^"_$ZDate(tRsCheck.Data("COEORI_Date"),4)_"^"_$Ztime(tRsCheck.Data("COEORI_Time"),2)
			Set tResult = tRsCheck.Data("COEORI_No")_"^^"_$Ztime(tRsCheck.Data("COEORI_Time"),2)
			If pPrescNo'="" Set tResult = tRsCheck.Data("COEORI_No")_"^"_tRsCheck.Data("COEORI_Date")_"^"_$Ztime(tRsCheck.Data("COEORI_Time"),2)
			
		}
		Do tRsCheck.Close()
	}
	
	Quit tResult
}

/// 2011-02-02  Fabio Goncalves
/// 	This method returns the custom PrescNo from OEORI_RowId 
/// The custom prescription number is stored on Custom_HMS_Misc_User.OEOrdItem.
ClassMethod GetPrescNoFromOrderId(pOEORIRowId As %String) As %String
{
	
	Set tReturn = ""
	Set tSC 	= ""
	Set tSQL 	= ""
 	
	Quit:pOEORIRowId="" tReturn
	
	Set tSQL = "SELECT COEORI_No FROM Custom_HMS_Misc_User.OEOrdItem WHERE COEORI_OEORI_DR = ? ORDER BY COEORI_Date Desc, COEORI_Time Desc"
	
	Set tRs = ##class(%Library.ResultSet).%New()
		
	Do tRs.Prepare(tSQL)	
	
	Set tSC = tRs.Execute(pOEORIRowId)
	    
	If $System.Status.IsOK(tSC)
	{
		If tRs.Next()
		{			
			Set tReturn = tRs.Data("COEORI_No")			
		}
		
		Do tRs.Close()
		Kill tRs		
	}
		
	Quit tReturn
}

/// 2016-03-15 Hansel Gaete Cleaning Code and pre-set vars
ClassMethod FixSeqNo(pOEItms As %String, pParentToEmpty As %String = "") As %Boolean
{
	Quit:pOEItms="" 1
	// add Set (link,pos)=""
	Set (link,pos)=""
	Set itemc=$l(pOEItms,"^")-1,hoje=+$h
	For c=1:1:itemc {
		Set itm=$p($p(pOEItms,"^",c),"*",2)
		Set arcim=$p($p(pOEItms,"^",c),"*",1)
		Set (arcos, ordent, pseq, oeoridr) = ""
		&sql(select OEORI_ARCOS_DR,OEORI_OrdEnt_DR,OEORI_PrescSeqNo,OEORI_OEORI_DR,OEORI_ItmMast_DR
		            into :arcos,:ordent,:pseq,:oeoridr,:tarcim
		     from SQLUser.OE_OrdItem
		     where OEORI_RowId = :itm)
		If $l(ordent),'$l(oeoridr){
			If arcim="" Set arcim = tarcim
			&sql(select ITM_LinkToVisibleItem,ITM_Childsub into :link,:pos
			     from SQLUser.ARC_OrdSetDateItem
			     where 	(ITM_ParRef->DATE_ParRef = :arcos) and (ITM_ARCIM_DR = :arcim) and
			     		(ITM_ParRef->DATE_DateFrom <= :hoje) and 
							((ITM_ParRef->DATE_DateTo is null) or (ITM_ParRef->DATE_DateTo >= :hoje)))
			If 'pParentToEmpty Set ^TMP("zSEQ",$j,"ORDENT",ordent,pos,itm)=link
		}
		If (oeoridr'=""){
			Set ^TMP("zSEQ",$j,"OEORIDR",oeoridr,itm)=""
		}
	}
	//acerta OEORI_OEORI_DR
	Set ordent="" For {
		Set ordent=$o(^TMP("zSEQ",$j,"ORDENT",ordent)) q:ordent=""
		Set pos=""
		For  {
			Set pos=$o(^TMP("zSEQ",$j,"ORDENT",ordent,pos)) q:pos=""
			Set itm=""
			For  {
				Set itm=$o(^TMP("zSEQ",$j,"ORDENT",ordent,pos,itm)) q:itm=""
				Set link=$g(^TMP("zSEQ",$j,"ORDENT",ordent,pos,itm))
				If link,$d(^TMP("zSEQ",$j,"ORDENT",ordent,link)) {
					Set pai=$o(^TMP("zSEQ",$j,"ORDENT",ordent,link,""))
					If pai'="",itm'=pai, ##class(User.OEOrdItem).%ExistsId(pai), ##class(User.OEOrdItem).%ExistsId(itm) {
						&sql(update SQLUser.OE_OrdItem (OEORI_OEORI_DR) values (:pai) where OEORI_RowId = :itm)
						If 'SQLCODE s ^TMP("zSEQ",$j,"OEORIDR",pai,itm)=""
					}
				}
			}
		}
	}
	//acerta OEORI_SeqNo
	Set oeoridr="" f  {
			Set oeoridr=$o(^TMP("zSEQ",$j,"OEORIDR",oeoridr)) q:oeoridr=""
			Set itm=""
			For  {
				Set itm=$o(^TMP("zSEQ",$j,"OEORIDR",oeoridr,itm)) q:itm=""
				If itm'=oeoridr {
					&sql(select OEORI_SeqNo,OEORI_SttDat into :seqno,:sttdat from SQLUser.OE_OrdItem where OEORI_RowId = :oeoridr)
 					Set jj=1
 					If $d(sttdat),$d(seqno) { //due to TRC145873, MAguirre@2013.04.18
	 					while $d(^OEORDi(0,"StDtSeqNo",+oeoridr,+sttdat,seqno_"."_jj)){
		 					Set jj=jj+1
	 					}
 					}
 					Set $p(seqno,".",2)=jj-1
 					If $p(seqno,".",2)>0 &sql(update SQLUser.OE_OrdItem (OEORI_SeqNo) values (:seqno) where OEORI_RowId = :itm)
				}
			}
	}
	Quit 1
}

/// 2011-04-28  Fabio Goncalves  CCR:BRXX0623	TRC:69395
/// This method returns the parent item from an oe_orditem. It uses OEORI_OEORI_DR field or OEORI_SeqNo, if blank.
/// The is called from a UDF list method of epr.ClinicWorkList. 
/// 	The UDF component list is placed on EPVisitNumber.ClinicWorkList.
ClassMethod GetParentItem(pOEOrdItemId As %Library.String, pCheckSeqNo As %Library.String = "0") As %String
{
	#Dim oOEOrdItem As User.OEOrdItem
	Set tOEORIParentId      = ""
	Set tOEORDId		    = ""
 	Set tOEORIParentSeqNo   = ""
	Set tOEORISttDate 	    = ""
	Set tOEORIParentChildId = ""
	Set oOEOrdItem = ##class(User.OEOrdItem).%OpenId(pOEOrdItemId)
	If $IsObject(oOEOrdItem)
	{
		If $IsObject(oOEOrdItem.OEORIOEORIDR)
		{		
			Set tOEORIParentId = oOEOrdItem.OEORIOEORIDR.%Id()
			///	2014-06-23	Victor Skrobot
			///	adminroute type 
			If tOEORIParentId'="" Set tOEORIParentId=tOEORIParentId_"^"_oOEOrdItem.OEORIOEORIDR.OEORIIVType
		}		
		If (tOEORIParentId = "") && (pCheckSeqNo = "1")
		{
			Set tOEORDId 		  = +oOEOrdItem.%Id()
			Set tOEORIParentSeqNo = $Piece(oOEOrdItem.OEORISeqNo,".",1)
			Set tOEORISttDate     = oOEOrdItem.OEORISttDat
				
			Set tOEORIParentChildId = $Order(^OEORDi(0,"StDtSeqNo",tOEORDId,tOEORISttDate,tOEORIParentSeqNo,""))
				
			If (tOEORIParentChildId '= "")
			{
				Set tOEORIParentId = tOEORDId_"||"_tOEORIParentChildId				
			}
		}				
	}
	Kill oOEOrdItem
	Quit tOEORIParentId
}

ClassMethod UpdatePrescNo(pEpisodeID As %String, pOEOrdItemIDs As %String, pBefore As %String = "")
{
	
	Quit:pEpisodeID=""
	Quit:pOEOrdItemIDs=""

	Set tCurrPrescNo = $Get(%session.Data("CurrPrescNo"))
	
	if tCurrPrescNo = "" {
		
		Set strSQL = "SELECT TOP 1 COEORI_No FROM Custom_HMS_Misc_User.OEOrdItem WHERE COEORI_PAAdm_DR = ? "
		Set strSQL = strSQL_"AND COEORI_OEORI_DR->OEORI_ItemStat_DR->OSTAT_Code <> 'U' "
		Set strSQL = strSQL_"AND +COEORI_No > 0 ORDER BY COEORI_Date Desc, COEORI_Time Desc"
		
		Set tRsCheck = ##class(%Library.ResultSet).%New()
		
		Do tRsCheck.Prepare(strSQL)
		
		Set tSc = tRsCheck.Execute(pEpisodeID)
		    
		If $System.Status.IsOK(tSc)
		{
	
			If tRsCheck.Next()
			{
				
				Set tCurrPrescNo=tRsCheck.Data("COEORI_No")+1
				
			}else{
				
				Set tCurrPrescNo="1"
				
			}
		
		}
		
		Do tRsCheck.Close()
		
	}
	
	Set tToday = +$H
	Set tNow = $Piece($H,",",2)

	Set strSQL = "INSERT INTO "_
			"Custom_HMS_Misc_User.OEOrdItem "_
			"(COEORI_OEORI_DR, COEORI_Date, COEORI_Time, COEORI_No, COEORI_PAAdm_DR, COEORI_CTPCP_DR, COEORI_CarePrvTp_DR, COEORI_GES, COEORI_GESInfo, COEORI_GESSRQ, COEORI_Repeated_DR, COEORI_GESRTST, COEORI_GESRST) "_
			"VALUES "_
			"(?,?,?,?,?,?,?,?,?,?,?,?,?)"

	Set strSQL2 = "SELECT COEORI_OEORI_DR FROM Custom_HMS_Misc_User.OEOrdItem WHERE COEORI_OEORI_DR = ?"
	
	Set tRs = ##class(%Library.ResultSet).%New()
	
	Set tRsRev = ##class(%Library.ResultSet).%New()

	Do tRs.Prepare(strSQL)
	
	Do tRsRev.Prepare(strSQL2)

	For tCount=1:1:$Length(pOEOrdItemIDs,"^")-1 {
		
		Set tOEOrdItemID=$Piece($Piece(pOEOrdItemIDs,"^",tCount),"*",2)
		
		Do tRsRev.Execute(tOEOrdItemID)

		if 'tRsRev.Next() {
					
			Set (tCareProv,tCareProvTP)=""
			if ##class(User.OEOrdItem).%OpenId(tOEOrdItemID).OEORIDoctorDR {
				Set tCareProv=##class(User.OEOrdItem).%OpenId(tOEOrdItemID).OEORIDoctorDR.%Id()
				if ##class(User.OEOrdItem).%OpenId(tOEOrdItemID).OEORIDoctorDR.CTPCPCarPrvTpDR {
					Set tCareProvTP=##class(User.OEOrdItem).%OpenId(tOEOrdItemID).OEORIDoctorDR.CTPCPCarPrvTpDR.%Id()
				}	
			}
			if tCareProv="" {
				//If there is no Doctor get Last Doctor from OEOrdItem
				Set tLastCareProv=..GetLastCareProvFromOrder($Piece(tOEOrdItemID,"||",1))
				Set tCareProv=$Piece(tLastCareProv,"^",1)
				Set tCareProvTP=$Piece(tLastCareProv,"^",2)
			}
			Set tGES = ##class(User.OEOrdItem).%OpenId(tOEOrdItemID).OEORIText4
			///	2013-03-25	Victor Skrobot	TRC	143232	CCR	SMOC0009
			Set tGES = $s(tGES'="":1,1:0)
		
			Set tGESInfo = ""
			Set tGESInfo = ##class(User.OEOrdItem).%OpenId(tOEOrdItemID).OEORIComment3
			Set tGESInfoTxt = $Piece(tGESInfo,";",1)
			Set tGESInfoSRQ = $Piece(tGESInfo,";",2),tGESInfoSRQ=##class(web.PACSourceRefQualifier).GetIdFromCodeOrDescription(tGESInfoSRQ)
			Set tGESRefTempStageType = ##class(web.PACRefTemplateStageType).GetIdFromCodeOrDescription($Piece(tGESInfoTxt," - ",1))
			Set tGESRefStageTemplate = ##class(web.PACRefStageTemplate).GetIdFromCodeOrDescription($Piece(tGESInfoTxt," - ",2))
			
			s tIDOrig=""
			if $g(pEpisodeID)="" s pEpisodeID=$p(^OEORD(+tOEOrdItemID),"^",1)
			if $g(pSessionId)="" s pSessionId=%session.SessionId
			
			s tIDOrig=$g(^TMP("OEOrdRepeatItemO",pSessionId,pEpisodeID,tOEOrdItemID))
			///	2016-10-14	Victor Skrobot	JIRA	TC-95706
			///	removed Automatic change status DI
			///	if $g(tIDOrig)'="" d ..DescExecs(tIDOrig)
			
			Set tSc = tRs.Execute(tOEOrdItemID,tToday,tNow,tCurrPrescNo,pEpisodeID,tCareProv,tCareProvTP,tGES,tGESInfoTxt,tGESInfoSRQ,tIDOrig,tGESRefTempStageType,tGESRefStageTemplate)

		}
		
		    
	}
	Do tRs.Close()		
	
	///&sql(DELETE %NOTRIGGER SQLUser.OE_OrdItem where OEORI_OEORD_ParRef->OEORD_Adm_DR = :pEpisodeID and OEORI_ItemStat_DR = 10)
		
	If pBefore = "" Kill %session.Data("CurrPrescNo")
}

ClassMethod DescExecs(tryrow)
{
	;TO DO For edition this part is more simply 
 	 n (tryrow,itemcat)
 	 s RowId=tryrow
	 s dtatual=$zd($h,3)_" "_$zt($p($h,",",2))
	 
	 &sql(select STAT_RowId into :STATRowId 
	 from SQLUser.OEC_Order_AdminStatus 
	 Where STAT_Code='DI')
 	 if SQLCODE=100
 	 {
	 	 &sql(insert into SQLUser.OEC_Order_AdminStatus (STAT_Code,STAT_Desc,STAT_Bill,STAT_DeductStock )
		 values('DI','Interrumpidas','N','Y'))
		 
		 &sql(select STAT_RowId 
		 into :STATRowId 
	 	 from SQLUser.OEC_Order_AdminStatus 
	 	 Where STAT_Code='DI')
	 }
	 s tArcim=$p(^OEORD(+tryrow,"I",$p(tryrow,"||",2),1),"^",2)
	 s tSub=$p(^ARCIM(+tArcim,1,1),"^",10)
	 s tSev=$p(^ARCIM(+tArcim,1,1),"^",7)
	 s tCat=$p(^ARC("IC",tSub),"^",8)
	 //OEORI_ItemStat_DR_  1______________  13______  "^"_______    < M Code >
	 s ItemStatDRi=$p(^OEORD(+tryrow,"I",$p(tryrow,"||",2),1),"^",13)
	 if SQLCODE=0
	 {
 		&sql( declare k cursor for
	    select {fn CONVERT(DATEDIFF('mi',:dtatual,DATEADD('ss',%internal(OEORE_ExStTime),{fn CONVERT(%external(OEORE_ExStDate),SQL_TIMESTAMP)})),SQL_INTEGER)},
		OEORE_RowId
	    into   :dtdif,
		:OERowId
	    from   SQLUser.OE_OrdExec
	    Where  OEORE_Order_Status_DR is null and
		OEORE_OEORI_ParRef=:RowId)
		&sql(open k)
		&sql(fetch k)
		while(SQLCODE=0)
		{ 
			s dti=+$h
			s hri=$p($h,",",2)
			if dtdif>0 
			{
				&sql(select CTPCP_Rowid into :tCTPCP from SQLUser.CT_CareProv where CTPCP_Code='AUTO')
				if $g(SQLCODE)=100
				{
					s tID=$i(^CTPCP(0))
					s ^CTPCP(tID,1)="AUTO^Automatico Trak^^34^^^^^Y^^^^^^Z^N"
					s ^CTPCP(tID,2)="^^^^^^^^^^^^^60285^60285^^N^N^N^"
					s ^CTPCP(tID,3)="^^^^^^^^^^X^^^^^^^^^^^^^^^^^^^"
					s ^CTPCP(0,"CareProvType",34,tID)=""
					s ^CTPCP(0,"Code","AUTO",tID)=""
					s ^CTPCP(0,"Decs","AUTOMATICOTRAK",tID)=""
					s tCTPCP=tID
				}
				&sql(update SQLUser.OE_OrdExec set OEORE_Order_Status_DR=:STATRowId,OEORE_CTPCP_DR=:tCTPCP,OEORE_DateExecuted=:dti,OEORE_TimeExecuted=:hri Where OEORE_RowId=:OERowId)
			}
			&sql(fetch k)
		}
		&sql(close k)
	 	
	 }
}

ClassMethod GenerateExec(newOEORI)
{
	//[Alteração] - Renan Pessoa Menezes de Almeida - 06/10/2011
	//CCR - BRIP1473
	//TRC - 85833
	 set OEORIChildsub = $p(newOEORI,"||",2)
	 set ARCIM  = $piece($get(^OEORD(+newOEORI,"I",OEORIChildsub,1)),"^",2)
	 if ARCIM'=""{
	    set ordertype  = $$ordertype^COEOrdItem(ARCIM)
		if " R X I "[(" "_ordertype_" "){
		 	if ##class(web.OEOrdExec).GetFirstExec(newOEORI)=""{
		  		d updexe^COEOrdItem6(newOEORI)
			}
		}
	 }
	q
}

/*******************************************
*TRC 69242
*Change repeated linked rowid
*2011-05-02  Victor Skrobot  CCR:	TRC: 69242
********************************************/
/// 2016-03-15 Hansel Gaete Code Cleaning and get for error detected
ClassMethod UpdateOEORIFromLinked(pOEOrdItemIDs As %String, pRepeatOrderIDs As %String = "") As %String
{
	Quit:pOEOrdItemIDs="" ""
	kill tNewSeqSuf
	///	2014-07-25	Victor Skrobot
	///	fix linked items with repetition
	If pRepeatOrderIDs'="" {
		Set tNewSeq = 0
		kill tOrder,tOrderRep,tOrderSeq
		Kill vCurrentOrders
		For tCount=$Length(pOEOrdItemIDs,"^")-1:-1:1 {
			Set tARCIMID=$Piece($Piece(pOEOrdItemIDs,"^",tCount),"*",1)
			Set tOEOrdItemID=$Piece($Piece(pOEOrdItemIDs,"^",tCount),"*",2)
			Set vCurrentOrders(tOEOrdItemID) = ""
			/// 2015-08-11	DZ	CCR:CLXX9429	TRC:I39109
			/// 	- solve error in repeat order, when there are 2 or more orders of the same item, and they have linked items
			If $Data(%session), $Data(^TMP("WEB", "ORDER_ENTRY", %session.SessionId, "CLXX_COPYID", tOEOrdItemID))
			{
				Set tOrdItemRepeatFrom = $Get(^TMP("WEB", "ORDER_ENTRY", %session.SessionId, "CLXX_COPYID", tOEOrdItemID))
				If (tOrdItemRepeatFrom '= "")
				{
					Set tOrderRep(tOEOrdItemID) = tOrdItemRepeatFrom
					Set tOrdItemRepLinked = $Piece(^OEORD(+tOrdItemRepeatFrom,"I",+$Piece(tOrdItemRepeatFrom,"||",2),11),"^",39)
					If +tOrdItemRepLinked, '$Data(^OEORD(+tOrdItemRepLinked,"I",+$Piece(tOrdItemRepLinked,"||",2),1)) Set tOrdItemRepLinked = ""
					Set tOrderRepFrom(tOrdItemRepeatFrom)=tOEOrdItemID_"^"_tOrdItemRepLinked
				}
			}
			/// 2015-08-11	DZ	CCR:CLXX9429	TRC:I39109
			/// 	- solve error in repeat order, when there are 2 or more orders of the same item, and they have linked items
			/// 	- commented lines below
			/*
			///	Get items generated by repetition
			For tCountRep=1:1:$Length(pRepeatOrderIDs,$c(6)) {
				Set tARCIMIDrep=$Piece($Piece(pRepeatOrderIDs,$c(6),tCountRep),$c(4),11)
				Set tOEOrdItemIDrep=$Piece($Piece(pRepeatOrderIDs,$c(6),tCountRep),$c(4),1)
				If tARCIMID=tARCIMIDrep,'$Data(tOrderRep(tOEOrdItemID)) {
					Set tOrderRep(tOEOrdItemID)=tOEOrdItemIDrep
					Set tOrderRepFrom(tOEOrdItemIDrep)=tOEOrdItemID_"^"_$Piece(^OEORD(+tOEOrdItemIDrep,"I",$Piece(tOEOrdItemIDrep,"||",2),11),"^",39)
				}
			}
			*/
			Set tObjOEORI = ##class(User.OEOrdItem).%OpenId(tOEOrdItemID)
			/// 2015-08-21	DZ	CCR:CLXX9474	TRC:197859	JIRA:TC-52827
			/// 	- solve error in repeat order, in linked orders
#;			Validate exist before try to void OREF Error
			Set ttOEORDRowId = $Piece(tOEOrdItemID,"||",1)
			Set ttOEORIChildsub = $Piece(tOEOrdItemID,"||",2)
			Set ttData = $Get(^OEORD(ttOEORDRowId,"I",ttOEORIChildsub,11))
			Set ttValue = $Piece(ttData,"^",39)
			Set oOriLinked = ""
			If (ttValue'="")
				Set oOriLinked = tObjOEORI.OEORIOEORIDR
#;			Set oOriLinked = tObjOEORI.OEORIOEORIDR
			///	Define new SeqNo for items NOT linked
			If (tObjOEORI '= ""), ('$IsObject(oOriLinked)  || ($IsObject(oOriLinked) && $Get(tOrderRep(tOEOrdItemID)) && ($Piece($Get(tOrderRepFrom(tOrderRep(tOEOrdItemID))),"^",2) = "")))
			{
				Set tNewSeq=tNewSeq+1
				Set tOrder(tOEOrdItemID)=tNewSeq
				Set tOrderSeq(tNewSeq)=tOEOrdItemID
			}
			Kill tObjOEORI, oOriLinked
		}
		///	Define new SeqNo for items linked
		For tCount=$Length(pOEOrdItemIDs,"^")-1:-1:1 {
			Set tARCIMID=$Piece($Piece(pOEOrdItemIDs,"^",tCount),"*",1)
			Set tOEOrdItemID=$Piece($Piece(pOEOrdItemIDs,"^",tCount),"*",2)
			If '$Data(tOrder(tOEOrdItemID)) {
				If $Data(tOrderRep(tOEOrdItemID)) {
					Set tItmFrom = tOrderRep(tOEOrdItemID)
					Set tItmFromLinked = $Piece(tOrderRepFrom(tItmFrom),"^",2)
					// Add $Get
					Set tItmNew = $Piece($Get(tOrderRepFrom(tItmFromLinked)),"^",1)
		//	2016-03-18 Hansel Gaete
		// 	<UNDEFINED>zUpdateOEORIFromLinked+62^Custom.web.OEOrdItem.1 *tOrder("") // If Added
					If (tItmNew'="" && $g(tOrder(tItmNew))'=""){
						Set tThisSeq = +tOrder(tItmNew)
						Set tOrderSeq(tThisSeq) = tOrderSeq(tThisSeq)_"^"_tOEOrdItemID
						Set tOrder(tOEOrdItemID)=+tOrder(tItmNew)_"."_($Length(tOrderSeq(tThisSeq),"^")-1)
					}
				}else{
					Set tItmNew = $Piece(^OEORD(+tOEOrdItemID,"I",$Piece(tOEOrdItemID,"||",2),11),"^",39)
					Set tThisSeq = +tOrder(tItmNew)
					Set tOrderSeq(tThisSeq) = tOrderSeq(tThisSeq)_"^"_tOEOrdItemID
					Set tOrder(tOEOrdItemID)=+tOrder(tItmNew)_"."_($Length(tOrderSeq(tThisSeq),"^")-1)
				}
			}
		}
		///	update OEORISeqNo and OEORIOEORIDR
		Set tOEOrdItemID = $Order(tOrder(""))
		While tOEOrdItemID'="" {
			Set tObjOEORI = ##class(User.OEOrdItem).%OpenId(tOEOrdItemID)
			If $IsObject(tObjOEORI) {
				Set tObjOEORI.OEORISeqNo = tOrder(tOEOrdItemID)
				If tOrder(tOEOrdItemID)["." {
					Set tSeqNo = $Piece(tOrder(tOEOrdItemID),".",1)
					Set tObjOEORI.OEORIOEORIDR = ##class(User.OEOrdItem).%OpenId($Piece(tOrderSeq(tSeqNo),"^",1))
				}
				/// 2015-08-11	DZ	CCR:CLXX9429	TRC:I39109
				/// 	- solve error in repeat order, when there are 2 or more orders of the same item, and they have linked items
				If tObjOEORI.OEORIOEORIDR
				{
					If '$Data(vCurrentOrders(tObjOEORI.OEORIOEORIDR.%Id())) Set tObjOEORI.OEORIOEORIDR = ""
				}
				Do tObjOEORI.%Save()
			}
			Set tOEOrdItemID = $Order(tOrder(tOEOrdItemID))
		}
	}else{
		Set tNewSeq=..GetLastSeqNoByOrder(pOEOrdItemIDs)
		kill tOrder,tOrderRep,tOrderSeq,tOrdersSeqs
		//Do ..updLinkedByARCOS(pOEOrdItemIDs)
		//Parent Sequence
		For tCount=1:1:$Length(pOEOrdItemIDs,"^")-1 {
			Set tOEOrdItemID=$Piece($Piece(pOEOrdItemIDs,"^",tCount),"*",2)
			Set tObjOEORI = ##class(User.OEOrdItem).%OpenId(tOEOrdItemID)
			d ..GenerateExec(tOEOrdItemID)
			///	2017-02-15	Victor Skrobot	TC-105000
			///	linked item not visible
			If ( (tObjOEORI'="") && (tObjOEORI.OEORIOEORIDR="") ) || ( $IsObject(tObjOEORI.OEORIOEORIDR) && '$Get(^TMP("WEB","ORDER_ENTRY","VISIBLEITEMS",%session.SessionId,tObjOEORI.OEORIOEORIDR.%Id())) ) {
				Set tNewSeq=tNewSeq+1
				Set tOrder(tOEOrdItemID)=tNewSeq
				Set tOrderSeq(tNewSeq)=tOEOrdItemID
			}
		}
		For tCount=1:1:$Length(pOEOrdItemIDs,"^")-1 {
			Set tOEOrdItemID=$Piece($Piece(pOEOrdItemIDs,"^",tCount),"*",2)
			If '$Data(tOrder(tOEOrdItemID)) {
				Set tObjOEORI = ##class(User.OEOrdItem).%OpenId(tOEOrdItemID)
				If tObjOEORI
				{
					For tCountP=1:1:$Length(pOEOrdItemIDs,"^")-1 {
						Set tOEOrdItemIDP=$Piece($Piece(pOEOrdItemIDs,"^",tCountP),"*",2)
						If tObjOEORI.OEORIOEORIDR, (tObjOEORI.OEORIOEORIDR.%Id()=tOEOrdItemIDP) {
							Set tOrder(tOEOrdItemIDP,tOEOrdItemID) = tOrderSeq(tOrder(tOEOrdItemIDP))
							Set tOrderSeq(tOrder(tOEOrdItemIDP),$i(tOrdersSeqs(tOEOrdItemIDP)))=tOEOrdItemID
						}
					}
				}
			}
		}
		//Children Sequence
		For tCount=1:1:$Length(pOEOrdItemIDs,"^")-1 {
			Set tOEOrdItemID=$Piece($Piece(pOEOrdItemIDs,"^",tCount),"*",2)
			Set tObjOEORI = ##class(User.OEOrdItem).%OpenId(tOEOrdItemID)
			If tObjOEORI'="",tObjOEORI.OEORIOEORIDR'="",tObjOEORI.OEORIOEORIDR.%Id() {
				If $Get(%session.Data("Custom.HMS.Misc.web.OEOrdItem",tOEOrdItemID))="Update" {
					Set tOrder(tObjOEORI.OEORIOEORIDR.%Id(),tOEOrdItemID)=""
					If $Get(tOrder(tObjOEORI.OEORIOEORIDR.%Id())) = "" {
						Set tOrder(tObjOEORI.OEORIOEORIDR.%Id()) = $Piece(tObjOEORI.OEORISeqNo,".",1)
					}
				}else{
					If $Get(tLastRowId)'="",tObjOEORI.OEORIOEORIDR.%Id()'=tLastRowId,'$Data(tOrder(tObjOEORI.OEORIOEORIDR.%Id())) {
						///	2017-02-15	Victor Skrobot	TC-105000
						///	linked item not visible
						If $Get(^TMP("WEB","ORDER_ENTRY","VISIBLEITEMS",%session.SessionId,tObjOEORI.OEORIOEORIDR.%Id())) {
							Set tObjOEORI.OEORIOEORIDR=##class(User.OEOrdItem).%OpenId(tLastRowId)
							Do tObjOEORI.%Save()
						}

					}
					Set tOrder(tObjOEORI.OEORIOEORIDR.%Id(),tOEOrdItemID)=""
				}
			} else {
				Set tLastRowId = tOEOrdItemID
			}
		}
		//Update Data
		Set tSeqNo = $Order(tOrderSeq(""))
		While tSeqNo'="" {
			Set tOEOrdItemID = tOrderSeq(tSeqNo)
			Set tObjOEORI = ##class(User.OEOrdItem).%OpenId(tOEOrdItemID)
			Set tObjOEORI.OEORISeqNo = tSeqNo
			If ($Piece($Get(^OEORD(+tOEOrdItemID,"I",$Piece(tOEOrdItemID,"||",2),11)),"^",39) '= ""), (tObjOEORI.OEORIOEORIDR = "")
			{
				Do tObjOEORI.OEORIOEORIDRSetObjectId("")
			}
			Do tObjOEORI.%Save()
			Kill tObjOEORI
			Set tSeqNoSub = $Order(tOrderSeq(tSeqNo,""))
			While tSeqNoSub'="" {
				Set tOEOrdItemID = tOrderSeq(tSeqNo,tSeqNoSub)
				Set tObjOEORI = ##class(User.OEOrdItem).%OpenId(tOEOrdItemID)
				Set tObjOEORI.OEORISeqNo = tSeqNo_"."_tSeqNoSub
				If ($Piece($Get(^OEORD(+tOEOrdItemID,"I",$Piece(tOEOrdItemID,"||",2),11)),"^",39) '= ""), (tObjOEORI.OEORIOEORIDR = "")
				{
					Do tObjOEORI.OEORIOEORIDRSetObjectId("")
				}
				Do tObjOEORI.%Save()
				Kill tObjOEORI
				Set tSeqNoSub = $Order(tOrderSeq(tSeqNo,tSeqNoSub))
			}
			Set tSeqNo = $Order(tOrderSeq(tSeqNo))
		}
	}
	/************************************************
	*Update after repeated changed
	*************************************************/
	//Do ..FixSeqNo(pOEOrdItemIDs, pParentToEmpty)
	Do ..FormatSeqNo(pOEOrdItemIDs)
	Do ..UpdateOrderSeq(pOEOrdItemIDs,"")
	Quit ""
}

/// 	2013-09-12	Victor Skrobot	TRC		CCR
/// update linked orders by arcordsets inactiveds 
ClassMethod updLinkedByARCOS(pOEOrdItemIDs) As %String
{
	New (pOEOrdItemIDs,%session)
	Set tITMRowIDs = ""

	For tCount=1:1:$Length(pOEOrdItemIDs,"^")-1 {
		Set tOEOrdItemID=$Piece($Piece(pOEOrdItemIDs,"^",tCount),"*",2)
		///	2016-02-03	Victor Skrobot	JIRA	TC-69311	TRC	I51158
		If $Data(^TMP("WEB","ORDER_ENTRY",%session.SessionId,"CLXX_COPYID",tOEOrdItemID)) Quit
		///
		Set tObjOEORI = ##class(User.OEOrdItem).%OpenId(tOEOrdItemID)
		If tObjOEORI'="" {
			If $IsObject(tObjOEORI.OEORIARCOSDR) {
				
				Set tARCIM = tObjOEORI.OEORIItmMastDR.%Id()
				Set tARCOS = tObjOEORI.OEORIARCOSDR.%Id()

				Set tLnkNumber = 0
				Set tARCOSDate = $Order(^ARCOS(tARCOS,"DATE",0))
				If tARCOSDate {
					Set tARCOSDateItm = $Order(^ARCOS(tARCOS,"DATE",tARCOSDate,"ITM",0))
					While tARCOSDateItm {
						Set tData = ^ARCOS(tARCOS,"DATE",tARCOSDate,"ITM",tARCOSDateItm)
						Set tARCIM2 = $Piece(tData,"^",1)
						Set tNumber = $Piece(tData,"^",26)
						Set tItms(tNumber) = tARCIM2
						If tARCIM=tARCIM2 {
							Set tLnkNumber = $Piece(tData,"^",6)
						}
						Set tARCOSDateItm = $Order(^ARCOS(tARCOS,"DATE",tARCOSDate,"ITM",tARCOSDateItm))
						
					}

					If tLnkNumber {
						For tCount2=1:1:$Length(pOEOrdItemIDs,"^")-1 {
							Set tOEOrdItemID2=$Piece($Piece(pOEOrdItemIDs,"^",tCount2),"*",2)
							Set tObjOEORI2 = ##class(User.OEOrdItem).%OpenId(tOEOrdItemID2)
							If $IsObject(tObjOEORI2) {
								If $IsObject(tObjOEORI2.OEORIARCOSDR),tObjOEORI2.OEORIARCOSDR.%Id()=tARCOS {
									If $Data(tItms(tLnkNumber)),tObjOEORI.%Id()'=tObjOEORI2.%Id(),tObjOEORI2.OEORIItmMastDR.%Id()=tItms(tLnkNumber) {
										Set tObjOEORI.OEORIOEORIDR = tObjOEORI2
										Do tObjOEORI.%Save()
									}
								}
							}
						}
					}
				}
			}
		}
	}
		
	Quit ""
}

/// 2016-03-15 Hansel Gaete Dynamic SQL to Embedded / SDSR
ClassMethod UpdateDetailsFromParentItem(pOrdItemID As %String, pParams As %String = "") As %Integer
{
	#Dim oRs As %Library.ResultSet
	#Dim oOrdItem As User.OEOrdItem
	#Dim oParentOrdItem As User.OEOrdItem
	Set tSC = 1
	Quit:'$Data(%request) tSC
	
	Set tOrderType = ""
	Set tOrderTypePar = ""
	Set tOrdItemID = pOrdItemID
	Set tOrdItemUpdatedIDs = ""
	Set:tOrdItemID="" tOrdItemID = $Get(%request.Data("ID",1))
	Quit:tOrdItemID="" tSC
	// Calculate again OrdExec from OrdItem Main
	//d updexe^COEOrdItem6(tOrdItemID)
	Set oParentOrdItem = ##class(User.OEOrdItem).%OpenId(tOrdItemID)
	Quit:'$IsObject(oParentOrdItem) tSC
	Set tOrdItemIDParent = $Piece(^OEORD(+tOrdItemID,"I",$Piece(tOrdItemID,"||",2),11),"^",39)
	/// 2012-11-29
	/// update AdminRoute if there is same desc in Instruc
	Set tInstrucDesc = oParentOrdItem.OEORIInstrDR.PHCINDesc1
	Set tAdminRoute = ##class(web.PHCAdministrationRoute).GetIdFromCodeOrDescription(tInstrucDesc)
	If tAdminRoute'="" {
		Set oParentOrdItem.OEORIAdminRouteDR = ##class(User.PHCAdministrationRoute).%OpenId(tAdminRoute)
		Do oParentOrdItem.%Save()
	}
	///	2013-05-23	Victor Skrobot	TRC		CCR
	If pParams'="", oParentOrdItem.OEORIYesNo1 '= $S($Piece(pParams,"^",4)="on":"Y",1:"") {
		Set oParentOrdItem.OEORIYesNo1 = $S($Piece(pParams,"^",4)="on":"Y",1:"")
		Do oParentOrdItem.%Save()
	}
	///	2013-08-12	Victor Skrobot	TRC		CCR
	If pParams'="", oParentOrdItem.OEORIYesNo2 '= $S($Piece(pParams,"^",6)="on":"Y",1:"") {
		Set oParentOrdItem.OEORIYesNo2 = $S($Piece(pParams,"^",6)="on":"Y",1:"")
		Do oParentOrdItem.%Save()
	}
	If pParams'="", oParentOrdItem.OEORIYesNo3 '= $S($Piece(pParams,"^",7)="on":"Y",1:"") {
		Set oParentOrdItem.OEORIYesNo3 = $S($Piece(pParams,"^",7)="on":"Y",1:"")
		Do oParentOrdItem.%Save()
	}
	// Try to find out parent item
	// Consulta os dados do item pai
	// Intenta buscar los datos del item padre, consultado los datos de este
	If (tOrdItemIDParent) {
		Set oParentOrdItem = ##class(User.OEOrdItem).%OpenId(tOrdItemIDParent)
		Set tPasstOrdItemIDParent = tOrdItemIDParent
		Set tPasstOrdIDParent = +tOrdItemIDParent
	}else{
		Set tOrdItemIDParent = tOrdItemID
		Set tPasstOrdItemIDParent = tOrdItemID
		Set tPasstOrdIDParent = +tOrdItemID
		// Calculate again OrdExec from OrdItem
		do:oParentOrdItem.OEORICalcQtyFlag="Y" updexe^COEOrdItem6(tOrdItemID)
	}
	&SQL(DECLARE CursorParentItems CURSOR FOR
	SELECT OEORI_RowId into :tOEORIRowId FROM SQLUser.OE_OrdItem WHERE OEORI_OEORD_ParRef = :tPasstOrdIDParent and OEORI_OEORI_DR = :tPasstOrdItemIDParent)
	&sql(OPEN CursorParentItems)
	&sql(FETCH CursorParentItems)
	While (SQLCODE = 0){
		//Update on child item / linked order from parent item data	s
		Set oOrdItem = ##class(User.OEOrdItem).%OpenId(tOEORIRowId)
		///	2016-04-10	Victor Skrobot	JIRA	TC-73770
		If oOrdItem.OEORIItmMastDR.%Id() = oParentOrdItem.OEORIItmMastDR.%Id() Quit
		If $IsObject(oOrdItem)
		{
			If $IsObject(oOrdItem.OEORIItmMastDR)
			{
				Set tOrderType = ##class(web.ARCItmMast).GetOrderType(oOrdItem.OEORIItmMastDR.%Id())
			}
			If $IsObject(oParentOrdItem.OEORIItmMastDR)
			{
				Set tOrderTypePar = ##class(web.ARCItmMast).GetOrderType(oParentOrdItem.OEORIItmMastDR.%Id())
			}
			// Diet, Diet Thickened Fluid, Enteral Feed, IV, Normal, Drug, Rehab Medicine
			If " D DTF E I N R X " [ tOrderType
			{
				// Duratrion / Duração
				If $IsObject(oParentOrdItem.OEORIDuratDR)
				{
					Do oOrdItem.OEORIDuratDRSetObjectId(oParentOrdItem.OEORIDuratDR.%Id())
				}
				// Priority / Prioridade
				If $IsObject(oParentOrdItem.OEORIPriorityDR)
				{
					Do oOrdItem.OEORIPriorityDRSetObjectId(oParentOrdItem.OEORIPriorityDR.%Id())
				}
				// IV, Drug, Rehab Medicine
				If " I R X " [ tOrderType
				{
					// Frequency / Frequencia
					If tOrderTypePar'="X",$IsObject(oParentOrdItem.OEORIPHFreqDR)
					{
						Do oOrdItem.OEORIPHFreqDRSetObjectId(oParentOrdItem.OEORIPHFreqDR.%Id())
						Do oOrdItem.OEORIRMFreqDRSetObjectId(oParentOrdItem.OEORIPHFreqDR.%Id())
						///	2016-12-21	Victor Skrobot	JIRA	TC-104582
						///	fix FreqDelay frequency Inmediata
						do ..UpdFreqDelay(oParentOrdItem.%Id(), oParentOrdItem.OEORIPHFreqDR.PHCFRDesc1, oParentOrdItem.OEORIFreqDelay)
					}
					If tOrderTypePar="X",$IsObject(oParentOrdItem.OEORIRMFreqDR)
					{
						Do oOrdItem.OEORIPHFreqDRSetObjectId(oParentOrdItem.OEORIRMFreqDR.%Id())
						Do oOrdItem.OEORIRMFreqDRSetObjectId(oParentOrdItem.OEORIRMFreqDR.%Id())
					}
					///	2016-12-21	Victor Skrobot	JIRA	TC-104582
					///	fix FreqDelay frequency Inmediata
					do ..UpdFreqDelay(oOrdItem.%Id(), oParentOrdItem.OEORIPHFreqDR.PHCFRDesc1, oParentOrdItem.OEORIFreqDelay)					
				}
				// IV, Drug
				If " I R " [ tOrderType
				{
					// Admin Route / Via
					If $IsObject(oParentOrdItem.OEORIAdminRouteDR)
					{
						if ('$IsObject(oOrdItem.OEORIARCOSDR)) Do oOrdItem.OEORIAdminRouteDRSetObjectId(oParentOrdItem.OEORIAdminRouteDR.%Id())
					}
					/// 2013-01-16	Victor Skrobot
					/// cant be empty so fields 0
					Set oOrdItem.OEORIUnit = "ML" //oParentOrdItem.OEORIUnit
					Set oOrdItem.OEORIUnitHrs = "hrs" //oParentOrdItem.OEORIUnitHrs
					Do oOrdItem.%Save()
					Set oOrdItem.OEORIFlowQty = 0
					Set oOrdItem.OEORITime = 0
				}
				// TRC 99234, 190347
				// Quantity
				Set oOrdItem.OEORIPhQtyOrd = oParentOrdItem.OEORIPhQtyOrd
				If tOrderType'="I" Set oOrdItem.OEORIPhQtyOrd = oParentOrdItem.OEORIPhQtyOrd * oOrdItem.OEORIDoseQty
				///	TRC	190347
				///	MaxRepeats
				Set oOrdItem.OEORIMaxRepeats = oParentOrdItem.OEORIMaxRepeats
				///	2016-09-14	Victor Skrobot	JIRA	TC-94145
				///	set Receiving Location from Parent
				///	2018-01-17	Victor Skrobot	JIRA	TC-143276
				///	dont change Receiving Location
				///	Do:$IsObject(oParentOrdItem.OEORIRecDepDR) oOrdItem.OEORIRecDepDRSetObjectId(oParentOrdItem.OEORIRecDepDR.%Id())
			}
			Do oOrdItem.%Save()
			//Do oOrdItem.%Close()
			// TRC 72477
			// Calculate again OrdExec from OrdItem
			d updexe^COEOrdItem6(tOEORIRowId)
			///	2014-06-20	Victor Skrobot
			///	adminroute IV (ex. infusion)
			If " I "[tOrderTypePar,oParentOrdItem.OEORIIVType="C" {
				Set tOrdItemIDChild = tOEORIRowId
				Kill ^OEORD(+tOrdItemIDChild,"I",$Piece(tOrdItemIDChild,"||",2),"X")
				Merge ^OEORD(+tOrdItemIDChild,"I",$Piece(tOrdItemIDChild,"||",2),"X")=^OEORD(+tOrdItemIDParent,"I",$Piece(tOrdItemIDParent,"||",2),"X")
				Set tExecID = $Order(^OEORD(+tOrdItemIDChild,"I",$Piece(tOrdItemIDChild,"||",2),"X",0))
				While tExecID'="" {
					Do ##class(User.OEOrdExec).%BuildIndices(tOrdItemIDChild_"||"_tExecID)
					///	2016-06-22	Victor Skrobot	TC-84157
					///	change PhQtyOrd on OEOrdExec
					Set $Piece(^OEORD(+tOrdItemIDChild,"I",$Piece(tOrdItemIDChild,"||",2),"X",tExecID),"^",4) = oOrdItem.OEORIDoseQty
					///
					Set tExecID = $Order(^OEORD(+tOrdItemIDChild,"I",$Piece(tOrdItemIDChild,"||",2),"X",tExecID))
				}
				///
				//If $Get(^TMP(%session.SessionId,"UDFOEOrdItem",tOrdItemID))="" {
				//	Set ^TMP(%session.SessionId,"UDFOEOrdItem",tOrdItemID) = oOrdItem.OEORIDoseQty
				//}
				Set tDoseQty = oOrdItem.OEORIDoseQty	//^TMP(%session.SessionId,"UDFOEOrdItem",tOrdItemID)
				Set oOrdItem.OEORIPhQtyOrd = (tDoseQty * oParentOrdItem.OEORIPhQtyOrd)
				Do oOrdItem.%Save()
			}
			///
			Do oOrdItem.%Close()
			///	2016-07-11	Victor Skrobot	JIRA	TC-84157
			If " I "[tOrderTypePar {
				Set tQty = oOrdItem.OEORIPhQtyOrd
				Set tExecQty = "", tExecCount = 0
				&sql(SELECT sum(OEORE_PhQtyOrd), count(*) INTO :tExecQty, :tExecCount FROM SQLUser.OE_OrdExec WHERE OEORE_OEORI_ParRef  = :tOEORIRowId)
				If tExecQty'="",tExecQty'=tQty {
					Set tNewQty = tQty / tExecCount
					&sql(UPDATE %NOTRIGGER SQLUser.OE_OrdExec (OEORE_PhQtyOrd) VALUES (:tNewQty)  WHERE OEORE_OEORI_ParRef  = :tOEORIRowId)
				}
			}
			///
			/// BUG - wrong
			If $Piece(^OEORD(+tOrdItemID,"I",$Piece(tOrdItemID,"||",2),11),"^",39)="",tOrdItemIDParent'="",tOrdItemIDParent'=tOrdItemID {
				Set $Piece(^OEORD(+tOrdItemID,"I",$Piece(tOrdItemID,"||",2),11),"^",39)=tOrdItemIDParent
				Set ^OEORDi(0,"OEORI",+tOrdItemID,tOrdItemIDParent,$Piece(tOrdItemID,"||",2))=""
			}
			Set tChanges = "#"_oOrdItem.OEORIPriorityDR.OECPRDesc_"#"_oOrdItem.OEORIPHFreqDR.PHCFRDesc1_"#"_oOrdItem.OEORIDuratDR.PHCDUDesc1_"#"_oOrdItem.OEORIPhQtyOrd_"#"_oOrdItem.OEORIAdminRouteDR.ADMRDesc_"#"_oOrdItem.OEORIMaxRepeats_"#"_oOrdItem.OEORIInstrDR.PHCINDesc1_"#"_oOrdItem.OEORIRecDepDR.CTLOCDesc_"#"_oOrdItem.OEORIFreqDelay_"*"
			Set tOrdItemUpdatedIDs = $Select(tOrdItemUpdatedIDs="":oOrdItem.%Id()_tChanges,1:tOrdItemUpdatedIDs_"*"_oOrdItem.%Id()_tChanges)
			Set tSC = "1^"_tOrdItemUpdatedIDs
		}
		Kill oOrdItem
		&sql(FETCH CursorParentItems)
	}
	&sql(CLOSE CursorParentItems)
	Do:$IsObject(oParentOrdItem) oParentOrdItem.%Close()
	Kill oParentOrdItem
	Quit tSC
}

Query LookUpCareProvTP(EpisodeID As %String, PrescDate As %String, PrescNo As %String, CareProv As %String, CareProvTP As %String) As %Library.SQLQuery(CONTAINID = 0, ROWSPEC = "HIDDEN:%String,Descricao:%String,Codigo:%String")
{
	SELECT
		DISTINCT
		COEORI_CarePrvTp_DR,
		COEORI_CarePrvTp_DR->CTCPT_Desc,
		COEORI_CarePrvTp_DR->CTCPT_Code
	FROM
		Custom_HMS_Misc_User.OEOrdItem
	WHERE
		(COEORI_PAAdm_DR = :EpisodeID)
		AND
		(TO_CHAR(COEORI_Date,'DD/MM/YYYY') = :PrescDate OR (:PrescDate IS NULL AND COEORI_Date > CURRENT_DATE-100))
		AND
		(COEORI_CarePrvTp_DR->CTCPT_Desc %STARTSWITH :CareProvTP)
		AND
		(COEORI_No = :PrescNo OR :PrescNo IS NULL)
		AND
		(COEORI_CTPCP_DR->CTPCP_Desc = :CareProv OR :CareProv IS NULL)
}

ClassMethod LookUpCareProvTPBroker(itmjs As %String = "", itmjsex As %String = "", EpisodeID As %String = "", PrescDate As %String = "", PrescNo As %String = "", CareProvider As %String = "", CareProvTP As %String = "") As %Boolean
{
 n rs,CTZIPRowId,CTZIPCode,CTZIPDesc
 set (rs,CTZIPRowId,CTZIPCode,CTZIPDesc)=""
 set found=1
 set rs=##Class(%Library.ResultSet).%New("Custom.HMS.Misc.web.OEOrdItem:LookUpCareProvTP")
 if rs {		
	    do rs.Execute(EpisodeID,PrescDate,PrescNo,CareProvider,CareProvTP)
		// 2011-11-11 - DZ - TRC 90055
		While (rs.Next()) && (found = 1)
		{
			If (CareProvTP = "") ! ($ZCVT(rs.GetData(2),"U") = $ZCVT(CareProvTP,"U"))
			{
				set RowId=rs.GetData(1)
				set Desc=rs.GetData(2)
				set Code=rs.GetData(3)
				set found=0
			}
		}
		do rs.%Close()
		Kill rs
	}
 quit:found 0
 set retval=itmjs_"('"_$ZCVT(Code,"O","JS")_"');"
 if itmjsex'="""" s retval=retval_itmjsex_"('"_$ZCVT(RowId,"O","JS")_"^"_$ZCVT(Desc,"O","JS")_"^"_$ZCVT(Code,"O","JS")_"');"
 &javascript<#(retval)#>
 quit 1
}

Query LookUpCareProv(EpisodeID As %String, PrescDate As %String, PrescNo As %String, CareProvTP As %String, CareProvider As %String) As %Library.SQLQuery(CONTAINID = 0, ROWSPEC = "HIDDEN:%String,Descricao:%String,Codigo:%String")
{
	SELECT 
		DISTINCT
		COEORI_CTPCP_DR,
		COEORI_CTPCP_DR->CTPCP_Desc,
		COEORI_CTPCP_DR->CTPCP_Code
	FROM 
		Custom_HMS_Misc_User.OEOrdItem
	WHERE
		(COEORI_PAAdm_DR = :EpisodeID OR :EpisodeID IS NULL)
		AND
		(COEORI_No = :PrescNo OR :PrescNo IS NULL)
		AND
		(TO_CHAR(COEORI_Date,'DD/MM/YYYY') = :PrescDate OR :PrescDate IS NULL)
		AND
		(COEORI_CarePrvTp_DR->CTCPT_Desc = :CareProvTP OR :CareProvTP IS NULL)
		AND
		(COEORI_CTPCP_DR->CTPCP_Desc %STARTSWITH :CareProvider)
}

ClassMethod LookUpCareProvBroker(itmjs As %String = "", itmjsex As %String = "", EpisodeID As %String = "", PrescDate As %String = "", PrescNo As %String = "", CareProvTP As %String = "", CareProvider As %String = "") As %Boolean
{
 n rs,CTZIPRowId,CTZIPCode,CTZIPDesc
 set (rs,CTZIPRowId,CTZIPCode,CTZIPDesc)=""
 set found=1
 set rs=##Class(%Library.ResultSet).%New("Custom.HMS.Misc.web.OEOrdItem:LookUpCareProv")
 if rs {		
	    do rs.Execute(EpisodeID,PrescDate,PrescNo,CareProvTP,CareProvider)
		if rs.Next() {
			set RowId=rs.GetData(1)
			set Desc=rs.GetData(2)						
			set Code=rs.GetData(3)
			set found=0
		}else{
			set found=1
		}
		do rs.%Close()
	}
 quit:found 0
 set retval=itmjs_"('"_$ZCVT(Code,"O","JS")_"');"
 if itmjsex'="""" set retval=retval_itmjsex_"('"_$ZCVT(RowId,"O","JS")_"^"_$ZCVT(Desc,"O","JS")_"^"_$ZCVT(Code,"O","JS")_"');"
 &javascript<#(retval)#>
 quit 1
}

// 

// Get Doctor from Last Order Item without not empty

// 

ClassMethod GetLastCareProvFromOrder(pOrdItem As %String) As %String
{
	
	Set tReturnTop = ""
 	
	Quit:pOrdItem="" tReturnTop
	
	Set tSQL = "SELECT TOP 1 OEORI_Doctor_DR, OEORI_Doctor_DR->CTPCP_CarPrvTp_DR FROM SQLUser.OE_OrdItem WHERE OEORI_OEORD_ParRef=? AND NOT OEORI_Doctor_DR IS NULL ORDER BY OEORI_SttDat DESC, OEORI_SttTim DESC"
	
	Set tRsTop = ##class(%Library.ResultSet).%New()
		
	Do tRsTop.Prepare(tSQL)	
	
	Set tSC = tRsTop.Execute(pOrdItem)
	    
	If $System.Status.IsOK(tSC)
	{
		If tRsTop.Next()
		{			
			Set tReturn = tRsTop.Data("OEORI_Doctor_DR")_"^"_tRsTop.Data("CTPCP_CarPrvTp_DR")
		}
		
		Do tRsTop.Close()
		Kill tRsTop		
	}
		
	Quit tReturnTop
}

ClassMethod GetLastSeqNoByOrder(pOrder) As %String
{
	
	Set tReturn = "0"
	Set tToday  = +$h
	
	Quit:pOrder="" tReturn
	
	Set tOrder = $Piece($Piece($Piece(pOrder,"^",1),"*",2),"||",1)
	Set tChild = $Piece($Piece($Piece(pOrder,"^",1),"*",2),"||",2)
	Set tChilds = "0"
	For tI=1:1:($Length(pOrder,"^")-1) {
		Set tChilds = tChilds_","_$Piece($Piece($Piece(pOrder,"^",tI),"*",2),"||",2)
	}
	Set tSQL = "SELECT max(+OEORI_SeqNo) from oe_orditem where OEORI_OEORD_ParRef = "_tOrder_" AND OEORI_SttDat = "_tToday_" AND NOT OEORI_Childsub IN ("_tChilds_")"
	
	Set tRsTop = ##class(%Library.ResultSet).%New()
		
	Do tRsTop.Prepare(tSQL)	
	
	Set tSC = tRsTop.Execute()
	    
	If $System.Status.IsOK(tSC)
	{
		If tRsTop.Next()
		{			
			Set tReturn = tRsTop.GetData(1)
		}
		
		Do tRsTop.Close()
		Kill tRsTop		
	}
		
	Quit $Piece(tReturn,".",1)
}

/// 2011-05-05  Fabio Goncalves  CCR:	TRC:
/// This method returns the linked items from a parent It uses OEORI_OEORI_DR field.
/// The is called from javascript custom/brxx/scripts/epr.ClinicWorkList. 
ClassMethod GetLinkedItems(pOEOrdItemId As %Library.String) As %String
{
		
	#Dim oRs As %Library.ResultSet
	#Dim oOEOrdItem As User.OEOrdItem	
	Set tOEORILinkedIds     = ""
	Set tOEORDId		    = ""
 	Set tOEORIParentSeqNo   = ""
	Set tOEORISttDate 	    = ""
	Set tOEORIParentChildId = ""	
	// Try to find out linked item of a parent item  
	// Consulta os dados de itens ligados de um pai
	Set tSQL = "SELECT OEORI_RowId FROM OE_OrdItem WHERE OEORI_OEORD_ParRef = '"_(+pOEOrdItemId)_"' AND OEORI_OEORI_DR = '"_pOEOrdItemId_"'"
	
	Set oRs = ##class(%Library.ResultSet).%New()
	Do oRs.Prepare(tSQL)
	Set tSC = oRs.Execute()
	If $System.Status.IsOK(tSC)
	{
		While oRs.Next()
		{	
			Set tOEORILinkedIds = $Select(tOEORILinkedIds="":oRs.GetDataByName("OEORI_RowId"),1:tOEORILinkedIds_"^"_oRs.GetDataByName("OEORI_RowId"))
		}
		Do oRs.Close()
	}
	
	Kill oRs
	
	Quit tOEORILinkedIds
}

/// 2011-05-05  Fabio Goncalves  CCR:	TRC:
/// This method returns the linked items from a parent It uses OEORI_OEORI_DR field.
/// The is called from javascript custom/brxx/scripts/epr.ClinicWorkList. 
ClassMethod GetAllLinkedItems(pOEOrdItemId As %Library.String) As %String
{
		
	Quit:pOEOrdItemId=""
	
	Set tOEORILinkedIds     = ""
		
	Set tOEORILinkedIds = ..GetLinkedItems(pOEOrdItemId)
	Set:tOEORILinkedIds="" tOEORILinkedIds = ..GetParentItem(pOEOrdItemId)
	
	Quit tOEORILinkedIds
}

ClassMethod GetLinkedItemsDesc(pOEOrdItemId As %Library.String) As %String
{
		Set tReturn = ""
		
		If pOEOrdItemId="" Quit ""
		
		Set %session.Data("Custom.HMS.Misc.web.OEOrdItem",pOEOrdItemId)="Update"
	
		Set tLinked = ##class(Custom.HMS.Misc.web.OEOrdItem).GetLinkedItems(pOEOrdItemId)
		
		If tLinked'="" {
			
			Set tLinkedDesc=""
			For tI=1:1:$Length(tLinked,"^") {
				Set tObjItm  = ##class(User.OEOrdItem).%OpenId($Piece(tLinked,"^",tI))
				Set tLinkedDesc = tLinkedDesc_" '"_tObjItm.OEORIItmMastDR.ARCIMDesc_"'"
			}
			Set tReturn=tLinkedDesc
			
		}
		
		Quit tReturn
}

ClassMethod GetLinkedItemsByParentDesc(pOEOrdItemId As %Library.String) As %String
{
	Set tReturn = ""
	Set tOEORILinkedIds = ""
	
	If pOEOrdItemId="" Quit ""
	
	Set tSQL = "SELECT OEORI_OEORI_DR->OEORI_ItmMast_DR->ARCIM_Desc FROM OE_OrdItem WHERE OEORI_RowID = '"_pOEOrdItemId_"' AND NOT OEORI_OEORI_DR IS NULL"
		
	Set oRs = ##class(%Library.ResultSet).%New()
	Do oRs.Prepare(tSQL)
	Set tSC = oRs.Execute()		
		
	If $System.Status.IsOK(tSC)
	{
		If oRs.Next()
		{	
			Set tReturn = "'"_oRs.GetDataByName("ARCIM_Desc")_"'"
		}
		
		Do oRs.Close()		
	}		
		
	Quit tReturn
}

ClassMethod GetLinkedByOEOrdExec(pOEOrdExecIDs As %Library.String) As %String
{
		Set tReturn = ""
		
		If pOEOrdExecIDs="" Quit ""
		
		Set tReturn = pOEOrdExecIDs
		
		Set tSQL = "SELECT OEORE_RowId FROM OE_OrdExec where OEORE_OEORI_ParRef = ? AND OEORE_ExStDate = ? AND OEORE_ExStTime = ?"
		Set oRsTmp = ##class(%Library.ResultSet).%New()
		Do oRsTmp.Prepare(tSQL)
		
		for tInt=1:1:$Length(pOEOrdExecIDs,"^")-1 {
	
			Set tObjOEOrdExec=##class(User.OEOrdExec).%OpenId($Piece(pOEOrdExecIDs,"^",tInt))
			
			Set tCurrTime=tObjOEOrdExec.OEOREExStTime
			Set tCurrDate=tObjOEOrdExec.OEOREExStDate
			
			Set pOEOrdItemId=$Piece($Piece(pOEOrdExecIDs,"^",tInt),"||",1,2)
	
			Set tLinked = ##class(Custom.HMS.Misc.web.OEOrdItem).GetParentItem(pOEOrdItemId)
		
			if tLinked'="" {

				for tIntL=1:1:$Length(tLinked,"^") {
				
					Set tSC = oRsTmp.Execute($Piece(tLinked,"^",tIntL),tCurrDate,tCurrTime)		
		
					If $System.Status.IsOK(tSC)
					{
						While oRsTmp.Next()
						{	
					
							Set tNewID = oRsTmp.GetData(1)
						
							if pOEOrdExecIDs'[(tNewID_"^") Set pOEOrdExecIDs=pOEOrdExecIDs_tNewID_"^"
						
						}
					
					}
					
				}
				
			}
			
		}
		
		for tInt=1:1:$Length(pOEOrdExecIDs,"^")-1 {

			Set tObjOEOrdExec=##class(User.OEOrdExec).%OpenId($Piece(pOEOrdExecIDs,"^",tInt))
			
			Set tCurrTime=tObjOEOrdExec.OEOREExStTime
			Set tCurrDate=tObjOEOrdExec.OEOREExStDate
			
			Set pOEOrdItemId=$Piece($Piece(pOEOrdExecIDs,"^",tInt),"||",1,2)

			Set tLinked = ##class(Custom.HMS.Misc.web.OEOrdItem).GetLinkedItems(pOEOrdItemId)
			
			if tLinked'="" {

				for tIntL=1:1:$Length(tLinked,"^") {
				
					Set tSC = oRsTmp.Execute($Piece(tLinked,"^",tIntL),tCurrDate,tCurrTime)		
		
					If $System.Status.IsOK(tSC)
					{
						While oRsTmp.Next()
						{	
					
							Set tNewID = oRsTmp.GetData(1)

							if pOEOrdExecIDs'[(tNewID_"^") Set pOEOrdExecIDs=pOEOrdExecIDs_tNewID_"^"
						
						}
					
					}
					
				}
				
			}
		

		}
		
		Quit pOEOrdExecIDs
}

/// 2011-05-17  Victor Skrobot  CCR: 	TRC:  Original version
/// Show last doctor from prescrition
ClassMethod GetDefaultProf() As %String
{
	
	Set tReturn = ""
	Quit:'$Data(%request) tReturn
	
	Set tEpisodeID = $Get(%request.Data("EpisodeID",1))
	Set tPrescNo   = $Get(%request.Data("PrescNo",1))
	Set tPrescDate = $Get(%request.Data("PrescDate",1))
	Set tUserID    = $Get(%session.Data("LOGON.USERID"))
	
	Quit:tEpisodeID="" tReturn
	
	If $Get(%request.Data("CareProvTP",1))="" Quit tReturn
	
	Set tCTPCP  = ##Class(web.SSUser).GetDefaultCareProvider(tUserID)
	Set tType   = ##class(web.CTCareProv).GetCPTypeDesc(tCTPCP)
	Set tTypeId = ##class(web.CTCarPrvTp).GetIdFromCodeOrDescription(tType)
	
	Quit:tTypeId="" tReturn
	
	Set strSQL = "SELECT COUNT(*) FROM "_
			"Custom_HMS_Misc_User.OEOrdItem "_
			"WHERE "_
			"COEORI_PAAdm_DR = "_tEpisodeID_" "_
			"AND "_
			"COEORI_CarePrvTp_DR = '"_tTypeId_"' "
	If tPrescNo'="" Set strSQL=strSQL_"AND COEORI_No = '"_tPrescNo_"' "
	If tPrescDate'="" Set strSQL=strSQL_"AND TO_CHAR(COEORI_Date,'DD/MM/YYYY') = '"_tPrescDate_"' "

	Set tRs = ##class(%Library.ResultSet).%New()
	
	Do tRs.Prepare(strSQL)
	
	Do tRs.Execute()	
	
	If tRs.Next() {
		
		if tRs.GetData(1) > 0 {
		
			Set tReturn = tType
		
		}
		
	}
	
	Quit tReturn
}

/// 2011-05-17  Victor Skrobot  CCR:	TRC: 70280
ClassMethod ShowItemDescOnCmp(pDesc As %Library.String) As %String
{
	Set pLnk=$p(pDesc,"^",2)
	Set pDesc=$p(pDesc,"^",1)
	
	Write:pLnk'="" "<img src='../images/websys/arrow2_right.png' />"
	Write pDesc
	Write !
	
	Quit ""
}

/// 2011-05-17  Victor Skrobot  CCR: 	TRC: 70280 Original version
/// This method is called from preferences "List Filter" of OEOrdItem
/// Show only OrderItem Inativo
/// Don't show OrderItem Diet
ClassMethod ListRowFilter(pRs As %Library.ResultSet) As %Integer [ ProcedureBlock = 1 ]
{
	Set tResult = 1

	Quit:'$Data(%request) tResult
	Quit:'$IsObject(pRs) tResult

	If pRs.GetData(8)'="Inactivo",pRs.GetData(8)'="" Set tResult = 0
	///	2015-08-04	Victor Skrobot	TRC	195491	
	///	only category 35 and 36
	Set tOEORI = $Get(%request.Data("P9",1))
	If tOEORI {
		Set tObjOEORI = ##class(User.OEOrdItem).%OpenId(tOEORI)
		If $IsObject(tObjOEORI) {
			If "*F*MED*"'[$Extract(tObjOEORI.OEORIItmMastDR.ARCIMItemCatDR.ARCICOrdCatDR.ORCATCode,1) Set tResult = 0
		}
	}
	///
	
	If tResult = 1 {

		Set tOEORI = pRs.GetData(4)
	
		Set tObjOEORI = ##class(User.OEOrdItem).%OpenId(tOEORI)
	
		If '$Data(^TMP("WEB","ORDER_ENTRY","VISIBLEITEMS",%session.SessionId,tOEORI)) Quit 0
		If $Get(%request.Data("P9",1))=pRs.GetData(4) Quit 0
		If $ZCVT(pRs.GetData(3),"U")'[$ZCVT($Get(%request.Data("P8",1)),"U") Quit 0
		If '$IsObject(tObjOEORI) Quit 0
		If '$IsObject(tObjOEORI.OEORIItmMastDR) Quit 0
		///	2015-08-04	Victor Skrobot	TRC	195491	
		///	only category 35 and 36
		If "*F*MED*"'[$Extract(tObjOEORI.OEORIItmMastDR.ARCIMItemCatDR.ARCICOrdCatDR.ORCATCode,1) Quit 0
		///
		If $IsObject(tObjOEORI.OEORIOEORIDR) Quit 0
		Set tType = ##class(web.ARCItmMast).GetOrderType(tObjOEORI.OEORIItmMastDR.%Id())
	
		If tType = "D" Set tResult = 0
		
		If tResult,$Get(%request.Data("P9",1)) {
			If $Data(^OEORDi(0,"OEORI",+tOEORI,%request.Data("P9",1))) Set tResult = 0
		}

	}
	
	Quit tResult
}

/// 
/// TRC 
/// New method to be smaller
ClassMethod LRFil(pRs As %Library.ResultSet) As %Integer
{
	Quit ..ListRowFilter(.pRs)
}

/// 2011-06-02 Victor Skrobot
/// TRC 74525
/// Check if some field required was empty
ClassMethod GetFieldEmptyRequired(pOEOrdItemIDs As %Library.String) As %String
{
	
	Set tReturn  = ""
	Set tQuest   = ""
	Set tToday   = +$h
	Set tMessage = ""
	
	For tCount=1:1:$Length(pOEOrdItemIDs,"^")-1 {
		
		Set tOEOrdItemID=$Piece($Piece(pOEOrdItemIDs,"^",tCount),"*",2)
		
		Set oOrdItem = ##class(User.OEOrdItem).%OpenId(tOEOrdItemID)
		
		If $IsObject(oOrdItem)
		{

			Set tOrderType = ##class(web.ARCItmMast).GetOrderType(oOrdItem.OEORIItmMastDR.%Id())
		
			// Hard coded because dont know how to understand if was required in layout
		
			If tOrderType = "I" {
			
				Set tEmpty = 0
				//"FlowQuantity" or 
				If oOrdItem.OEORIFlowQty="" Set tEmpty = 1
				If oOrdItem.OEORIUnit="" Set tEmpty = 1
			
				If tEmpty {
				
					Set tReturn = tReturn_$Select(tReturn="":"",1:", ")_oOrdItem.OEORIItmMastDR.ARCIMDesc 
				
				}
			
			}
			
			// 2011-12-13	Henrique Dias 	TRC:88186
			// Itens de Prescrição Restrita - Tipo R (Medicamento)
			If tOrderType = "R"
			{
				Set tQDuration = ""
				Set tWINCode   = ""
				
				If $IsObject(oOrdItem.OEORIOEORDParRef)
				{
					If $IsObject(oOrdItem.OEORIOEORDParRef.OEORDAdmDR)
					{
						Set tEpisodeID = oOrdItem.OEORIOEORDParRef.OEORDAdmDR.%Id()
					}
				}
				
				//Set tOrderType = ##class(web.ARCItmMast).GetOrderType(oOrdItem.OEORIItmMastDR.%Id())
				
				// Recupera o objeto para o ARCIM			
				Set oARCIM = ##class(User.ARCItmMast).%OpenId(oOrdItem.OEORIItmMastDR.%Id())
				
				If $IsObject(oARCIM)
				{
					// Se o item de pedido possuir algum questionário associado, verificar o OEORI_Questionnaire
					If $IsObject(oARCIM.ARCIMQuestionnaireDR)
					{
						Set tWINRowID = oARCIM.ARCIMQuestionnaireDR.%Id()
						Set tWINCode  = oARCIM.ARCIMQuestionnaireDR.WINCode 
						
						// Valida se o Codigo do Questionário esta entre os itens restritos
						If ((tWINCode="MNPPE")||(tWINCode="ANTIMICROB")||(tWINCode="SMPE"))
						{
							If (oOrdItem.OEORIQuestionnaire="")
							{							
								// Atribui de acordo com o questionario o campo que armazena a duração
								If ((tWINCode="MNPPE")||(tWINCode="SMPE"))
								{
									Set tQDuration = "Q14"
								}
								
								If (tWINCode="ANTIMICROB")
								{
									Set tQDuration = "Q13"
								}
								
								Set tQuest = 0
								
								// Verifico para essa passagem e questionario a data que foi criado o questionario e a duração
								Set tSQL = "Select QUESCreateDate,"_tQDuration_" As Duration From questionnaire.Q"_tWINCode_" Where QUESPAAdmDR = '"_tEpisodeID_"' AND QUESSSUserDefWindowDR = '"_tWINRowID_"'"
								
								Set tRs = ##class(%Library.ResultSet).%New()
								
								Set tSC = tRs.Prepare(tSQL)	
	
								Set tSC = tRs.Execute()
								
								If $System.Status.IsOK(tSC)
								{
									While tRs.Next()
									{
										Set tQUESCreateDate = tRs.GetDataByName("QUESCreateDate")
										Set tDuration = tRs.GetDataByName("Duration")
										
										// Passagem já possui um item de pedido anterior
										If (tQUESCreateDate'="")
										{
											// Verificar se a duração do item de pedido ainda está válida
											Set tCheckDuration = tQUESCreateDate + tDuration
											
											//If (tCheckDuration < tToday)
											If (tCheckDuration > tToday)
											{
												Set tQuest = 0
											}
											Else
											{
												Set tQuest = 1
												Set tMessage = "Prazo vencido, preencher novo questionario"
											}
										}
									}
									Do tRs.Close()
								}
								Else
								{
									Set tQuest = 1
								}
								Kill tRs
							}
						
							If $Get(tQuest) = 1
							{
								Set tReturn = tReturn_oOrdItem.OEORIItmMastDR.ARCIMDesc_$char(13,10)_tMessage
							}
						}
					}
				}
			}
			//}			
		}
				
	}
	
	Quit tReturn
}

/// 2011-06-06 Victor Skrobot
/// TRC 
/// Check if some field required was empty
ClassMethod CheckLinkedAllReady(pOEOrdItemID As %Library.String, pLinked As %Library.String, pItmMast As %Library.String) As %String
{
	
	Set tReturn = ""
	
	Quit:pOEOrdItemID="" tReturn
	Quit:pLinked="" tReturn
	Quit:pItmMast="" tReturn
	
	Set strSQL = "SELECT OEORI_RowID FROM "_
			"SQLUser.OE_OrdItem "_
			"WHERE "_
			"OEORI_OEORD_ParRef = '"_(+pLinked)_"' "_
			"AND "_
			"OEORI_OEORI_DR = '"_pLinked_"' "_
			"AND "_
			"OEORI_ItmMast_DR = '"_pItmMast_"' "_
			"AND "_
			"OEORI_RowID <> '"_pOEOrdItemID_"' "

	Set tRs = ##class(%Library.ResultSet).%New()
	
	Do tRs.Prepare(strSQL)
	
	Do tRs.Execute()	
	
	If tRs.Next() {
		
		Set tReturn = "ERROR"
		
	}
		
	Quit tReturn
}

/// 2011-11-22 Victor Skrobot
/// TRC 90987
/// Check if linked is the same category
ClassMethod CheckLinkedCategory(pOEOrdItemID As %Library.String, pLinked As %Library.String) As %String
{
	
	Set tReturn = ""
	
	Quit:pOEOrdItemID="" tReturn
	Quit:pLinked="" tReturn
	
	Set oOrdItem = ##class(User.OEOrdItem).%OpenId(pOEOrdItemID)
	Set oOrdLinked = ##class(User.OEOrdItem).%OpenId(pLinked)
	
	If $IsObject(oOrdItem),$IsObject(oOrdLinked),oOrdItem.OEORIItmMastDR.ARCIMItemCatDR.ARCICOrdCatDR.%Id()'=oOrdLinked.OEORIItmMastDR.ARCIMItemCatDR.ARCICOrdCatDR.%Id(){
		
		Set tReturn = "ERROR"
		
	}
		
	Quit tReturn
}

/// 2011-05-17  Victor Skrobot  CCR: 	TRC:  Original version
/// This method is called from preferences "List Filter" with list Code
ClassMethod ListRowFilterByListCode(pList As %String) As %Integer [ ProcedureBlock = 0 ]
{
	Set tResult = 1
	
	Quit:'$IsObject(rs) tResult
	Quit:pList="" tResult
	
	Set tList = $LISTFROMSTRING(pList,"^")
	
	If '$LISTFIND(tList,rs.GetData(2)) Set tResult = 0
	
	Quit tResult
}

/// This method is called from preferences "List Filter" with list Code No
ClassMethod ListRowFilterByListCodeNo(pList As %String) As %Integer [ ProcedureBlock = 0 ]
{
	Set tResult = 1
	
	Quit:'$IsObject(rs) tResult
	Quit:pList="" tResult
	
	Set tList = $LISTFROMSTRING(pList,"^")
	
	If $LISTFIND(tList,rs.GetData(2)) Set tResult = 0
	
	Quit tResult
}

/// TRC 73811
/// This method is a Custom update Frequency for RM Frequency
ClassMethod GetRMFrequency(pID As %String) As %Integer [ ProcedureBlock = 0 ]
{
	Set tResult = ""
	Set oOrdItem = ##class(User.OEOrdItem).%OpenId(pID)	
	If $IsObject(oOrdItem) {
		If $IsObject(oOrdItem.OEORIRMFreqDR) {
			Set tResult = $List(##class(web.PHCFreq).GetCodeDescriptionFromId(oOrdItem.OEORIRMFreqDR.%Id()),1)
		}
	}
	Quit tResult
}

ClassMethod UpdateRMFrequency(pID As %String, pValue As %String) As %Integer [ ProcedureBlock = 0 ]
{
	Set tResult = ""
	Set oOrdItem = ##class(User.OEOrdItem).%OpenId(pID)	
	If $IsObject(oOrdItem) {
		Set idFreq = ##class(web.PHCFreq).GetIdFromCodeOrDescription(pValue)
		Do oOrdItem.OEORIPHFreqDRSetObjectId(idFreq)
		Do oOrdItem.OEORIRMFreqDRSetObjectId(idFreq)
		Do oOrdItem.%Save()
		d updexe^COEOrdItem6(pID)
	}
	Quit tResult
}

/// TRC 78224
/// This method is called from preferences "List Filter" to
/// Don't show lines with Status = 
ClassMethod ListRowFilterWithStatus(pRs As %Library.ResultSet) As %Integer [ ProcedureBlock = 0 ]
{
	Set tResult = 1
	
	Quit:'$IsObject(pRs) tResult
	Quit:pRs="" tResult
	
	If (pRs.Data("StatusCode")="U") Set tResult = 0
	
	Quit tResult
}

/// 2011-08-19  Henrique Dias
/// This method returns the RowId No from Questionnaire (SS_UserDefWindow)
ClassMethod GetIdQuest(pWINCode As %String) As %String
{
	
	Set tReturn = ""
	Set tSC 	= ""
	Set tSQL 	= ""
 	
	Quit:pWINCode="" tReturn
	
	Set tSQL = "Select WIN_RowId From SS_UserDefWindow Where WIN_Code = ?"
	
	Set tRs = ##class(%Library.ResultSet).%New()
		
	Do tRs.Prepare(tSQL)	
	
	Set tSC = tRs.Execute(pWINCode)
	    
	If $System.Status.IsOK(tSC)
	{
		If tRs.Next()
		{			
			Set tReturn = tRs.Data("WIN_RowId")			
		}
		
		Do tRs.Close()
		Kill tRs		
	}
		
	Quit tReturn
}

// TRC

// Update order sequence

ClassMethod UpdateOrderSeq(pList As %String, pFirstSeq As %String) As %String
{
	Set tResult = ""
	
	Kill UpdateOrderSeq

	If pFirstSeq="",pList'="" {
		Set tId = $Piece(pList,"^",1)
		If $Length(tId,"*")>2 Set tId=$Piece(tId,"*",2)
		Set tObj = ##class(User.OEOrdItem).%OpenId(tId, 0)
		If tObj
		{
			Set pFirstSeq = tObj.OEORISeqNo
			Kill tObj
		}
	}
	Set tParRef = $Piece(pList,"^",1)
	Set:$Length(tParRef,"*")>1 tParRef = $Piece(tParRef,"*",2)
	Set tParRef = $Piece(tParRef,"||",1)

	&SQL(SELECT 
	Max (OEORI_SeqNo) into :pFirstSeq
	FROM SQLUser.OE_ORDItem 
	WHERE OEORI_OEORD_ParRef = :tParRef AND OEORI_ItemStat_DR->OSTAT_Code <> 'I')

	If pFirstSeq = "" Set pFirstSeq = "0"
	Set tSeq = $Piece(pFirstSeq,".",1)
	
	/*
	Set tOthPos = ""

	For tI=1:1:$Length(pList,"^") {

		Set tId = $Piece(pList,"^",tI)
		If $Length(tId,"*")>2 Set tId=$Piece(tId,"*",2)
		
		Set oOrdItem = ##class(User.OEOrdItem).%OpenId(tId)	

		If $IsObject(oOrdItem),$IsObject(oOrdItem.OEORIOEORIDR) {
			
			For tJ=1:1:$Length(pList,"^") {
				
				Set tIdx = $Piece(pList,"^",tJ)
				If $Length(tIdx,"*")>2 Set tIdx=$Piece(tIdx,"*",2)
				
				If tIdx = oOrdItem.OEORIOEORIDR.%Id(), tI'>tJ {
				
					Set tOthPos = $Piece(pList,"^",tI)
					Set $Piece(pList,"^",tI) = $Piece(pList,"^",tJ) 
					Set $Piece(pList,"^",tJ) = tOthPos 
					
				}
				
			}
			
		}
		
	}
	*/
	For tI=1:1:$Length(pList,"^") {

		Set tId = $Piece(pList,"^",tI)
		If $Length(tId,"*")>2 Set tId=$Piece(tId,"*",2)
		
		Set oOrdItem = ##class(User.OEOrdItem).%OpenId(tId)	
	
		If $IsObject(oOrdItem) {
			
			If oOrdItem.OEORIItemStatDR.OSTATCode="I" { 
			
			
				///	If oOrdItem.OEORISeqNo'["." Set tSeq=tSeq+1,oOrdItem.OEORISeqNo=tSeq
				Set tCurrSeq = oOrdItem.OEORISeqNo
				Set tNewSeq = $Piece(tCurrSeq,".",1)
				Set tNewSeq = $E("0000",1,4-$Length(tNewSeq))_tNewSeq
				If $Piece(tCurrSeq,".",2)'="" Set tNewSeq = tNewSeq_"."_$E("00",1,2-$Length($Piece(tCurrSeq,".",2)))_$Piece(tCurrSeq,".",2)
				Set oOrdItem.OEORISeqNo = tNewSeq
						
				Do oOrdItem.%Save()

			}
			
			Set tResult = tResult_oOrdItem.OEORISeqNo_"^"
			
		}
		
	}
	
	Quit tResult
}

/// TRC 99216 : Based on EXECTIME^USSMOCUpdateExec() called by the field ExecutionTimesNext into the component Custom.OEOrdItem.ListEMR
Method ExecTime(OEItmID As %String = "", Fecha As %Integer) As %String
{
	n (OEItmID,Fecha)
	set lnk=""
	set datelast=Fecha-1
			
	&sql(declare horas cursor for
		 select %external(OEORE_ExStTime),
		        OEORE_OEORI_ParRef->OEORI_OEORD_ParRef->OEORD_Adm_DR,
		        OEORE_OEORI_ParRef->OEORI_OEORD_ParRef->OEORD_Adm_DR->PAADM_PAPMI_DR,
		        OEORE_RowId,
		        OEORE_Order_Status_DR->STAT_Desc,
		        %external(OEORE_TimeExecuted),
		        OEORE_OEORI_ParRef->OEORI_Priority_DR->OECPR_Code,
		        OEORE_OEORI_ParRef->OEORI_Priority_DR->OECPR_Desc 
		 into :hora,:Passagem,:Paciente,:oeore,:zstat,:exec,:PRN,:PRNDesc
		 from SQLUser.OE_OrdExec
		 where OEORE_OEORI_ParRef = :OEItmID and OEORE_ExStDate = :Fecha)
	
	&sql(open horas)
	
	// Get parent item from OE_Orditem	
	Set tParentItem = ##class(Custom.HMS.Misc.web.OEOrdItem).GetParentItem(OEItmID)
	// Get child item from OE_Orditem	
	Set tChildItem = ##class(Custom.HMS.Misc.web.OEOrdItem).GetLinkedItems(OEItmID)

	s stop=0 f  &sql(fetch horas) d  q:stop
	.
	.i SQLCODE &sql(close horas) s stop=1 q
	.
	.i $l(exec)>2 s hora=exec
	.
	.i zstat'="Suspendido" d
	..s lnk=lnk_"<A id=""SESHRz"" name=""SESHRz"" HREF=""#"" "
	..i (tParentItem'=""),zstat="" d
	...s lnk=lnk_"onClick=""websys_lu('oeordexec.linkedorders.csp?PatientBanner=1&PatientID="_Paciente_"&EpisodeID="_Passagem_"&PARREF="_tParentItem_"&ID="_oeore_"',false,'top=200,left=40,width=1000,height=500');return false;"" " 
	..i (tChildItem'=""),zstat="" d
	...s lnk=lnk_"onClick=""websys_lu('oeordexec.linkedorders.csp?PatientBanner=1&PatientID="_Paciente_"&EpisodeID="_Passagem_"&PARREF="_OEItmID_"&ID="_oeore_"',false,'top=200,left=40,width=1000,height=500');return false;"" " 
	..i (tParentItem="")!(tChildItem="")!(zstat'="") d
	...s lnk=lnk_"onClick=""websys_lu('oeordexec.edit.csp?PatientBanner=1&PatientID="_Paciente_"&EpisodeID="_Passagem_"&PARREF="_OEItmID_"&ID="_oeore_"',false,'top=0,left=0,width=780,height=540');return false;"" " 
	..if $l(exec)>2 s lnk=lnk_"style=""color:#333388; WIDTH: 102px; HEIGHT: 21px"" >"_$p(hora,":",1,2)_" "_zstat_"</A>" 
	..e  d
	...s lnk=lnk_"style=""WIDTH: 102px; HEIGHT: 21px"" >"
	...i PRN="PRN" s lnk=lnk_PRNDesc,stop=1
	...i PRN'="PRN" s lnk=lnk_$p(hora,":",1,2)_" "_zstat
	...s lnk=lnk_"</A>"
	...i PRN="PRN" d
	....&sql(select count(*) into :totlast from SQLUser.OE_OrdExec where OEORE_OEORI_ParRef = :OEItmID and OEORE_ExStDate = :datelast and OEORE_OEORI_ParRef->OEORI_Priority_DR->OECPR_Code = 'PRN' and OEORE_DateExecuted is null)
	....i totlast>0 s lnk=""
 
	w lnk,!
	
	q lnk
}

ClassMethod FSeqNo(pRs As %String) As %String
{
	W $C(60)_"img src='../webemr/adsas.gif' /"_$C(62)_pRs.Data("OrderName")
	Quit 1
}

ClassMethod No(pList As %String) As %String
{
	Quit ..ListRowFilterByListCodeNo(pList)
}

/// Method: CheckRestrictions
/// Description: Verificar se os itens pedidos possuem alguma restricao
/// Update history [Descending order - newest first]:
/// 2011-12-19	Daniel Zola	CCR:BRIP1831	TRC:77549
ClassMethod CheckRestrictions(pEpisodeID As %String) As %String [ ProcedureBlock = 1 ]
{
	Set tResult = ""
	Set tReferralMsg = ""
	If $Get(%session), (pEpisodeID '= "")
	{
		Set tSessionId = %session.SessionId
		Set tOeoriId = ""
		Do
		{
			Set tOeoriId = $Order(^TMP("WEB", "ORDER_ENTRY", tSessionId, tOeoriId))
			If (tOeoriId '= "")
			{
				Set oOri = ##class(User.OEOrdItem).%OpenId(tOeoriId, 0)
				If $IsObject(oOri), $IsObject(oOri.OEORIItemStatDR), (oOri.OEORIItemStatDR.%Id()=10)
				{
					If $IsObject(oOri.OEORIItmMastDR.ARCIMItemCatDR), $IsObject(oOri.OEORIItmMastDR.ARCIMItemCatDR.ARCICOrdCatDR)
					{
						// TRC 77549: Verificar se ja foi feito o mesmo pedido de INTERCONSULTA
						If (oOri.OEORIItmMastDR.ARCIMItemCatDR.ARCICOrdCatDR.ORCATCode = "INTERC")
						{
							Set tHasReferral = ..CheckReferral(tOeoriId, oOri.OEORIItmMastDR.%Id())
							If (tHasReferral)
							{
								Set tReferralMsg = tReferralMsg _ " - "_ oOri.OEORIItmMastDR.ARCIMDesc _ $Char(10)
							}
						}
					}
				}
				Kill oOri
			}
		} While (tOeoriId '= "")
	}
	If (tReferralMsg '= "")
	{
		Set tResult = 	"Pedido(s) ja' realizado(s) e aguardando visita: " _ $Char(10) _ tReferralMsg _ $Char(10) _
						"Favor apaga-lo(s) para prosseguir."
	}
	Quit tResult
}

/// Method: CheckReferral
/// Description: Verificar se ja existe pedido de interconsulta
/// Update history:
/// 2011-12-19	Daniel Zola	CCR:BRIP1831	TRC:77549
ClassMethod CheckReferral(pOriId As %String, pItemId As %String) As %Boolean [ ProcedureBlock = 1 ]
{
	Set tResult = 0
	If (pOriId '= ""), (pItemId '= "")
	{
		Set tOrderId = +pOriId
		Set tOrdItemId = ""
		&SQL(
			SELECT	OEORI_RowId
			INTO	:tOrdItemId
			FROM	SQLUser.OE_OrdItem
			WHERE	(OEORI_OEORD_ParRef = :tOrderId)
			  AND	(OEORI_ItmMast_DR = :pItemId)
			  -- Status: D - Suspenso, E - Executado
			  AND	(OEORI_ItemStat_DR->OSTAT_Code not in ('D', 'E'))
			  AND	(OEORI_SttDat is not null)
		)
		If (tOrdItemId '= ""), (tOrdItemId '= pOriId)
		{
			Set tResult = 1
		}
	}
	Quit tResult
}

ClassMethod UpdLinked(pID As %String, pParentID As %String, pForce As %String = 0) As %String
{
	Set tResult = 0
	If pID = "" Quit 0
	///	If pParentID = "" Quit 0
	Set tObj = ##class(User.OEOrdItem).%OpenId(pID)
	If $IsObject(tObj) {
		Set tChange = 0
		If pParentID'="",'$IsObject(tObj.OEORIOEORIDR) Set tChange=1
		If 'tChange,pParentID'="",$IsObject(tObj.OEORIOEORIDR),tObj.OEORIOEORIDR.%Id()'=pParentID Set tChange=1
		If 'tChange,pParentID="",$IsObject(tObj.OEORIOEORIDR) Set tChange=1
		If tChange {
			Set tSQL = "update SQLUser.OE_OrdItem (OEORI_OEORI_DR) values (?) where OEORI_RowId = ?"
			Set tRs = ##class(%ResultSet).%New()
			Do tRs.Prepare(tSQL)
			Do tRs.Execute(pParentID, pID)

			If pParentID'="" {
				Set tSQL = "update SQLUser.OE_OrdItem (OEORI_OEORI_DR) values (NULL) where OEORI_OEORD_ParRef = ? and OEORI_OEORI_DR = ?"
				Set tRs = ##class(%ResultSet).%New()
				Do tRs.Prepare(tSQL)
				Do tRs.Execute(+pID, pID)
			}
			
			Do ..UpdateDetailsFromParentItem(pID)
			//Do ..FixSeqNo("*"_pID_"*^",pParentID="")
			Set tResult = 1
			
		}else{
			
			If pParentID="" {
				Set tSQL = "update SQLUser.OE_OrdItem (OEORI_OEORI_DR) values (NULL) where OEORI_RowID = ?"
				Set tRs = ##class(%ResultSet).%New()
				Do tRs.Prepare(tSQL)
				Do tRs.Execute(pID)
				Do ..UpdateDetailsFromParentItem(pID)
				//Do ..FixSeqNo("*"_pID_"*^")
				Set tResult = 1
			}
			
		}
		
	}
	
	If pForce Set tResult = 1
	Quit tResult
}

ClassMethod LRFSessionList(pRs As %Library.ResultSet) As %String
{
	Set tResult = 1
	
	Quit:'$Data(%request) tResult
	Quit:'$IsObject(pRs) tResult
	
	d ##class(Custom.HMS.Misc.web.EPVisitNumber).CompRepItems(%session.SessionId)
	
	Set tObj = ##class(User.OEOrdItem).%OpenId(pRs.Data("ID"))
	
	If $IsObject(tObj) {
		If $IsObject(tObj.OEORIOEORIDR) {
			Set pRs.Data("OEORBillDesc") = tObj.OEORIOEORIDR.OEORIItmMastDR.ARCIMDesc
		}
		/// first time check
		If $Get(%session.Data("OEORIs"))'[("*"_pRs.Data("ID")_"*") {
			If $replace(tObj.OEORIDayBookAccessionNo,"/","||")'[pRs.Data("ID") Set tObj.OEORIYesNo4 = "Y"
			
			Set tObj.OEORIDSReportFlag = "Y"
			If tObj.OEORIYesNo1="",$Get(%session.Data("OEORIsGES"))'="" {
				///	YesNo1 (ClinSignF) = GES
				///	If "*35*36*MED*"'[tObj.OEORIItmMastDR.ARCIMItemCatDR.ARCICOrdCatDR.ORCATCode {
					Set tObj.OEORIYesNo1 = "Y"
				///	}
			}

			Do tObj.%Save()
			Set pRs.Data("ClinSignO")="Y"
			
			Set %session.Data("OEORIs")=$Get(%session.Data("OEORIs"))_"*"_pRs.Data("ID")_"*"
		}
		///	2014-04-29	Victor Skrobot	TRC	174704	
		/// removed line to avoid repeticion error
		/*	If tObj.OEORIText4'="" Set pRs.Data("PBSRepeats")="Y" */
		///	
		If pRs.Data("PBSRepeats")'="",pRs.Data("MaxRpts")'="",pRs.Data("MaxRpts")>pRs.Data("PBSRepeats") Set pRs.Data("PBSRepeats")=""
		
		/// 2013-05-23	Victor Skrobot	TRC		CCR	
		/// show ClinSignf as YesNo1
		Set pRs.Data("ClinSignf") = tObj.OEORIYesNo1

		///	2013-12-11	Victor Skrobot	TRC		CCR		
		///	make link as the same on new version
		Set OEITMDesc="<A id=""OEITMDesc"_ID_""" name=""OEITMDesc"_ID_""" HREF=""#"""
		Set OEITMDesc=OEITMDesc_" onClick=""websys_ToggleInfo('websys.csp?&TINFOMODE=H&PatientBanner=0&ID="_pRs.Data("ID")_"&OrderWindow=oeorder_entry&EpisodeID="_%request.Get("EpisodeID")_"&OEORIItmMastDR="_pRs.Data("arcim")_"&PatientID="_%request.Get("PatientID")_"&CONTEXT="_$g(%request.Data("CONTEXT",1))_"&mradm="_%request.Get("mradm")_"&TWKFL="_##class(websys.WorkFlow).GetIdFromCodeOrDescription("Trak.Order Item Entry")_"','60','OEOrder.Custom',window);"" tabIndex='0'>"_pRs.Data("OEITMName")_"</A>"
		Set pRs.Data("OEITMDesc") = OEITMDesc
		///
		
		/////////////////////////////////////////////////////////////
		///	2014-06-20	Victor Skrobot	
		///	dont show questionnaire "TCEPATFAR" if the user is Doctor
		Set tUserID = %session.Data("LOGON.USERID")
		Set tCTPCP  = ##Class(web.SSUser).GetDefaultCareProvider(tUserID)
		Set tCPType = ##class(web.CTCareProv).GetInternalType(tCTPCP)
		///	2014-11-12	Victor Skrobot	TRC	185025
		///	dont show questionnaire "TCEPATFAR" if the user is Odontologo / Matrona
		Set tCPTypeDesc = ""
		If tCTPCP, ($Data(^CTPCP(tCTPCP, 1))#10 = 1) Set tCPTypeDesc = $ZCVT(##class(web.CTCareProv).GetCPTypeDesc(tCTPCP),"U")
		
		If (tCPType="DOCTOR")!(tCPTypeDesc["ODONT")!(tCPTypeDesc["MATRON") { 
			Set tQuestionnaireID = pRs.Data("QuestionnaireID")
			Set tQuestionnaireCode = $lg(##class(web.SSUserDefWindow).GetCodeDescriptionFromId(tQuestionnaireID),3)
			If tQuestionnaireCode = "TCEPATFAR" {
				Set pRs.Data("QuestionnaireID") = ""
			}
		}
		
		If $ZCVT($p($g(^PHCFR(+pRs.Data("Frequency"))),"^",3),"U")["NMEDIAT" {
			Set pRs.Data("FreqMins")=tObj.OEORIFreqDelay
		}
		
		///
		//////////////////////////////////////////////////////////////
		
		If tObj.OEORIPhQtyOrd '= pRs.Data("Qty") Set pRs.Data("Qty")=tObj.OEORIPhQtyOrd
		If $IsObject(tObj.OEORIItmMastDR.ARCIMPHCDFDR) {
			Set tMaxRepeats = tObj.OEORIItmMastDR.ARCIMPHCDFDR.PHCDFMaxNumberRepeats
			Write "<input id=""MaxRepeatsz"_$g(xcnt)_""" name=""MaxRepeatsz"_$g(xcnt)_""" type=""hidden"" value="""_tMaxRepeats_""">",!
		}

		///	2016-12-21	Victor Skrobot	TC-103797
		Set tLocQty = ""
		Set tINCI = $$GetINCI^ST02(+tObj.OEORIItmMastDR.%Id())
		If $IsObject(tObj.OEORIRecDepDR) {
			Set tLoc = tObj.OEORIRecDepDR.%Id()
			&SQL(select INCIL_LogQty into :tLocQty from SQLUser.INC_ItmLoc where INCIL_INCI_ParRef = :tINCI and INCIL_CTLOC_DR = :tLoc)
		}
		Write "<input id=""INCItmStockz"_$g(xcnt)_""" name=""INCItmStockz"_$g(xcnt)_""" type=""hidden"" value="""_tLocQty_""">",!
		///
	}
	
	Quit tResult
}

ClassMethod UpdUOM(pID As %String, pUOMID As %String) As %String
{
	
	If pID = "" Quit 0
	If pUOMID = "" Quit 0
	
	Set tObj = ##class(User.OEOrdItem).%OpenId(pID)

	If $IsObject(tObj) {
		
		Set tObj.OEORIUnitDR = ##class(User.CTUOM).%OpenId(pUOMID)
		Do tObj.%Save()
		
	}
	
	Quit 1
}

ClassMethod LRFPharmacyList(pRs As %Library.ResultSet) As %String
{
	Set tResult = 1
	
	Set tSQL = "Select OEORI_Doctor_DR from SQLUser.OE_OrdItem where OEORI_PrescNo = ?"
	Set tRs = ##class(%ResultSet).%New()
	Do tRs.Prepare(tSQL)
	Do tRs.Execute(pRs.Data("PrNo"))
	
	If tRs.Next() Set pRs.Data("PAADMCProv") = tRs.GetData(1)
	
	Quit tResult
}

ClassMethod AuthorizeOEOris(pUser As %String, pPwd As %String, pOEOrdItemIDs As %String) As %String
{
	Set tResult = "", tEpisodeID = ""
	Set msg = ##class(websys.Message).%New(0)
	
	If ##class(web.SSUser).ValidatePIN(pUser,pPwd) {
		
		Set tUserID = ##class(web.SSUser).GetIdFromCodeOrDescription(pUser)
		/// TRC 105866
		/// Set IscPresc global with the User Authorizing
		Set tToday = +$h
		Set tNow = $Piece($h,",",2)
		Set tOEOrdItemID=$Piece(pOEOrdItemIDs,"^",1)
		&sql(select OEORI_OEORD_ParRef->OEORD_Adm_DR into :tEpisodeID from SQLUser.OE_OrdItem where OEORI_RowID = :tOEOrdItemID)
		Set tNewPrescNo = ..GetNewPrescNo(tEpisodeID,"")
		
		For tCount=1:1:$Length(pOEOrdItemIDs,"^")-1 {
		
			Set tOEOrdItemID=$Piece(pOEOrdItemIDs,"^",tCount)
			Do ..AuthoriseOrder(tOEOrdItemID)			
						
		}
				
	}else{
		
		Set tResult = "Usuario y/o Contraseña invalidos."
		
	}
	
	Quit tResult
}

ClassMethod RejectOEOris(pUser As %String, pPwd As %String, pOEOrdItemIDs As %String) As %String
{
	Set tResult = ""
	Set msg = ##class(websys.Message).%New(0)
	
	If ##class(web.SSUser).ValidatePIN(pUser,pPwd) {
		
		Set tUserID = ##class(web.SSUser).GetIdFromCodeOrDescription(pUser)
		
		For tCount=1:1:$Length(pOEOrdItemIDs,"^")-1 {
		
			Set tOEOrdItemID=$Piece(pOEOrdItemIDs,"^",tCount)
		
			Set oOrdItem = ##class(User.OEOrdItem).%OpenId(tOEOrdItemID)
			
			If $IsObject(oOrdItem) {
				
				/// TRC 105866
				/// Set IscPresc global with the User Authorizing
				Set tToday = +$h
				Set tNow = $Piece($h,",",2)
				///Set ^IscPresc("Authorized",tOEOrdItemID) = tUserID_"^"_tToday_"^"_tNow
				Set oOrdItem.OEORIItemStatDR = ##class(User.OECOrderStatus).%OpenId(15)
			
				Do oOrdItem.%Save()	
			}
			
		}
				
	}else{
		
		Set tResult = "Usuario y/o Contraseña invalidos."
		
	}
	
	Quit tResult
}

ClassMethod VerifiedOEOris(pOEOrdItemIDs As %String) As %String
{
	Set tResult = ""

	For tCount=1:1:$Length(pOEOrdItemIDs,"^")-1 {
	
		Set tOEOrdItemID=$Piece(pOEOrdItemIDs,"^",tCount)
	
		Set tCustomID = $Order(^Custom.User.OEOrdItemI("IndexOEORI",tOEOrdItemID,""))
		If tCustomID'="" {
				
			Set oOrdItem = ##class(Custom.HMS.Misc.User.OEOrdItem).%OpenId(tCustomID)
		
			If $IsObject(oOrdItem) {
			
				Set oOrdItem.COEORIVerified = 1
		
				Do oOrdItem.%Save()	
			
			}
			
		}
		
	}
				
	Quit tResult
}

ClassMethod CheckOrdItemUnverified(pEpisodeID As %String) As %String
{
	Set tImg = 0

	Set tUser = $Get(%session.Data("LOGON.USERID"))
	Set tUserType = ##class(web.SSUser).GetDefaultCareProviderType(tUser)

	//If tUserType="DOCTOR" Quit tImg
	
	Set tOEORD = $Order(^OEORD(0,"Adm",pEpisodeID,""))
	While tOEORD'="" {
		
		Set tOEORDItem = $Order(^OEORD(tOEORD,"I","0"))
		While tOEORDItem'="" {
			
			Set tSttDat = $Piece($Get(^OEORD(tOEORD,"I",tOEORDItem,1)),"^",9)
		
			Set tStat = $Piece($Get(^OEORD(tOEORD,"I",tOEORDItem,1)),"^",13)
			Set tStat = $Piece(^OEC("OSTAT",tStat),"^",1)
			
			If "EVI"[tStat {
			
				Set tCustomID = $Order(^Custom.User.OEOrdItemI("IndexOEORI",tOEORD_"||"_tOEORDItem,""))
				If tCustomID'="" {
					Set tList = $Get(^Custom.User.OEOrdItemD(tCustomID))
					// field COEORI_Verified on Custom.HMS.Misc.User.OEOrdItem
					If $LISTGET(tList,10)="" Set tImg = 1 
				}
				
			}
			
			Set tOEORDItem = $Order(^OEORD(tOEORD,"I",tOEORDItem))
		}
		If tImg Quit
		
		Set tOEORD = $Order(^OEORD(0,"Adm",pEpisodeID,tOEORD))
	}

	
	Quit tImg
}

ClassMethod CheckOrdItemUnauthorized(pEpisodeID As %String) As %String
{
	Set tImg = 0
	Set tToday = +$h
	Set tNow = $Piece($h,",",2)

	Set tUser = $Get(%session.Data("LOGON.USERID"))
	//Set tUserCareProv = $Piece(^SSU("SSUSR",tUser),"^",14)
	Set tUserType = ##class(web.SSUser).GetDefaultCareProviderType(tUser)

	If (tUserType'="DOCTOR"),(tUserType'="NURSE") Quit tImg
	Set tTMPCurrPrescNo = ""
	Set tOEORD = $Order(^OEORD(0,"Adm",pEpisodeID,""))
	While tOEORD'="" {
		
		Set tOEORDItem = $Order(^OEORD(tOEORD,"I","0"))
		While tOEORDItem'="" {
			
			Set tSttDat = $Piece($Get(^OEORD(tOEORD,"I",tOEORDItem,1)),"^",9)
			Set tSttTim = $Piece($Get(^OEORD(tOEORD,"I",tOEORDItem,1)),"^",10)
			//If tSttDat '< tSearchStartDate {

				Set tCareProv = $Piece($Get(^OEORD(tOEORD,"I",tOEORDItem,1)),"^",11)
				Set tUserAdd = $Piece($Get(^OEORD(tOEORD,"I",tOEORDItem,7)),"^",1)
			
				If tCareProv'="",tUserAdd'="" {
					Set tCareUser = $Piece($Get(^SSU("SSUSR",tUserAdd)),"^",14)
					/// TRC 105866
					/// Set tSecondUser = $Piece($Get(^OEORD(tOEORD,"I",tOEORDItem,12)),"^",45)
					/// Set tSecondUser = +$Get(^IscPresc("Authorized",tOEORD_"||"_tOEORDItem))
	
					/// If tSecondUser="0",tCareProv'=tCareUser {
						// TRC 105421
						Set tStat = $Piece($Get(^OEORD(tOEORD,"I",tOEORDItem,1)),"^",13)
						Set tStat = $Piece(^OEC("OSTAT",tStat),"^",1)
						If "U"[tStat {
							If ((tSttDat=+$h)&(tNow>tSttTim))!(tSttDat<+$h) {
								If tTMPCurrPrescNo="" Set tTMPCurrPrescNo = ..GetNewPrescNo(pEpisodeID,"")
								Set tNewPrescNo = tTMPCurrPrescNo
								Do ..AuthoriseOrder(tOEORD_"||"_tOEORDItem)
							}else{
								Set tImg = 1 Quit
							}
						}
					/// }
					
				}

			//}
			
			Set tOEORDItem = $Order(^OEORD(tOEORD,"I",tOEORDItem))
		}
		If tImg Quit
		
		Set tOEORD = $Order(^OEORD(0,"Adm",pEpisodeID,tOEORD))
	}

	
	Quit tImg
}

ClassMethod CheckItmsDays(pIds) As %String
{
	Set tReturn = ""
	
	Set tSQL = "Select OEORI_ItmMast_DR->ARCIM_Desc from SQLUser.OE_OrdItem where OEORI_RowID in ("_pIds_") and (OEORI_Durat_DR->PHCDU_Code > 1)"
	Set tRs = ##class(%ResultSet).%New()
	Do tRs.Prepare(tSQL)
	Do tRs.Execute()
	While tRs.Next() {
		Set tReturn = tReturn_$s(tReturn="":"",1:", ")_tRs.GetData(1)
	}
	Do tRs.Close()
	
	Quit tReturn
}

ClassMethod GetDrgForm(pArcim) As %String
{
	Set tResult = ""
	Quit:pArcim="" ""
	
	Set (tCode,tDesc)=""
	&sql(SELECT ARCIM_PHCDF_DR->PHCDF_PHCF_DR->PHCF_Code, ARCIM_PHCDF_DR->PHCDF_PHCF_DR->PHCF_Desc into :tCode, :tDesc FROM SQLUser.ARC_ITMMAST WHERE ARCIM_ROWID = :pArcim)
	If 'SQLCODE Set tResult=tCode

	Quit tResult
}

/// 2016-03-15 Hansel Gaete Cleannig code and verif posible errors
/// calculate execution times with delay
ClassMethod UpdFreqDelay(pID, pFreqDesc, pFreqDelay) As %String
{
	Set tResult = ""
	Quit:pID="" tResult
	Set tToday = +$h
	Set tNow = $Piece($h,",",2)
	Set tFreqID = ##class(web.PHCFreq).GetIdFromCodeOrDescription(pFreqDesc)
	Set tOrd = ##class(User.OEOrdItem).%OpenId(pID)
	Set tOrd.OEORISttDat = tToday
	Set tOrd.OEORISttTim = tNow
	///	2016-12-21	Victor Skrobot	JIRA	TC-104582
	if ( $ZCVT(pFreqDesc,"U") '[ "INMEDIAT" ) Set pFreqDelay = ""
	Set tOrd.OEORIFreqDelay = pFreqDelay
	If pFreqDelay="" {
		Set tToday = ""
		Set tTime = ""
	}else{
		// Add "tFreqID &"
		/// 2016-03-18	Hansel Gaete
		/// <INVALID OREF>zUpdFreqDelay+14^Custom.web.OEOrdItem.1 // 
		Set tCount = 2
		If ($IsObject(tOrd.OEORIPHFreqDR) & tFreqID'="")
			If (tOrd.OEORIPHFreqDR.%Id()'=tFreqID) 
				Set tOrd.OEORIPHFreqDR = ##class(User.PHCFreq).%OpenId(tFreqID)
				Set tCount = tOrd.OEORIPHFreqDR.PHCFRFactor
			Set tTime = tNow
			Set tLastTime = $zth("23:59:59")
			For tI=2:1:tCount {
				If (tTime + (pFreqDelay*60)) > tLastTime {
					Set tToday = tToday + 1
					Set tTime = (tTime + (pFreqDelay*60)) - tLastTime
				}else {
					Set tTime = tTime + (pFreqDelay*60)
				}
			}
	}
	Set tOrd.OEORIEndDate = tToday
	Set tOrd.OEORIEndTime = tTime
	Do tOrd.%Save()
	Do updexe^COEOrdItem6(pID)
	Quit tResult
}

/// when changed Frequency verify
ClassMethod ChkFrequency(pID, pNewFreq) As %Library.String
{
	/// verify linked items
	Set tResult = ..GetLinkedItems(pID)

	/// get Factor and Days
	Set (tFactor,tDays)=""
	Set tFreqId = ##class(web.PHCFreq).GetIdFromCodeOrDescription(pNewFreq)
	Set tOrd = ##class(User.PHCFreq).%OpenId(tFreqId)
	If $IsObject(tOrd) {
		Set tFactor = tOrd.PHCFRFactor
		Set tDays = tOrd.PHCFRDays
	}
	
	Quit tResult_"*"_tFactor_"^"_tDays
}

/// Check if was selected as GES
ClassMethod ThereIsGES(pPatientID, pEpisodeID, Desc) As %String
{
	Set tResult = 0
	
	If pEpisodeID '= "" {
		
		Set tResult = ..GetThereIsGES(pEpisodeID,.Desc)		

	}else{
		
		Set tSQL = "select PAADM_RowID from SQLUser.PA_Adm where PAADM_PAPMI_DR = ?"
		Set tRs = ##class(%ResultSet).%New()
		Do tRs.Prepare(tSQL)
		Do tRs.Execute(pPatientID)
		While tRs.Next() {
			
			Set tResult = ..GetThereIsGES(tRs.GetData(1),.Desc)
			If tResult Quit
			
		}
		
	}
	
	Quit tResult
}

ClassMethod GetThereIsGES(pEpisodeID, Desc) As %String
{
	Set tResult = 0
	
	Set tSQL = "select COUNT(*) from Custom_HMS_Misc_User.OEOrdItem where COEORI_PAAdm_DR = ? and (COEORI_GES > 0 and NOT COEORI_GES IS NULL)"
	Set tRs = ##class(%ResultSet).%New()
	Do tRs.Prepare(tSQL)
	Do tRs.Execute(pEpisodeID)
	If tRs.Next() Set tResult = tRs.GetData(1)
	
	If tResult {
		
		Set Desc = " IPD = ?"
		Set tSQL = "select Q01, Q07 from questionnaire.QIPDSDSR where QUESPAADMDR = ?"
		Set tRs = ##class(%ResultSet).%New()
		Do tRs.Prepare(tSQL)
		Do tRs.Execute(pEpisodeID)
		If tRs.Next() {
			
			Set Desc = " IPD = "_tRs.GetData(1)_"; "_tRs.GetData(2)
			
		}
		
	}
		
	Quit tResult
}

/// set OEORIText4 checked as GES
ClassMethod SetOEORIGES(pIds, pStt) As %String
{
	Set tResult = ""
	
	If pStt'="" Set pStt=$S(pStt="ON":1,1:0)
	
	Set tSQL = "update SQLUser.OE_OrdItem (OEORI_Text4) values (?) where OEORI_RowID in (?)"
	Set tRs = ##class(%ResultSet).%New()
	Do tRs.Prepare(tSQL)
	Do tRs.Execute(pStt,pIds)
	
	Quit tResult
}

ClassMethod LRFilterRWB(pRs) As %String
{
	Set tResult = 1
	
	Set tSessionId = %session.SessionId
	If '$Data(^TMP("WEB","LRFilterRWB",tSessionId,pRs.GetDataByName("PatientID"))) {
	
		Set tResult = ..GetThereIsGESPossible(pRs.GetDataByName("EpisodeID"),.Desc) 
		Set ^TMP("WEB","LRFilterRWB",tSessionId,pRs.GetDataByName("PatientID"))=""
		
	}else{
		Set tResult = 0
	}
	
	Quit tResult
}

ClassMethod GetThereIsGESPossible(pEpisodeID, Desc) As %String
{
	Set tResult = 0
	
	Set tSQL = "select COUNT(*) from Custom_HMS_Misc_User.OEOrdItem where COEORI_PAAdm_DR = ? and ((COEORI_GES > 0 and NOT COEORI_GES IS NULL) or (NOT COEORI_OEORI_DR->OEORI_ItmMast_DR->ARCIM_Text4 IS NULL))"
	Set tRs = ##class(%ResultSet).%New()
	Do tRs.Prepare(tSQL)
	Do tRs.Execute(pEpisodeID)
	If tRs.Next() Set tResult = tRs.GetData(1)
	
	If tResult {
		
		Set Desc = " IPD = ?"
		Set tSQL = "select Q01, Q07 from questionnaire.QIPDSDSR where QUESPAADMDR = ?"
		Set tRs = ##class(%ResultSet).%New()
		Do tRs.Prepare(tSQL)
		Do tRs.Execute(pEpisodeID)
		If tRs.Next() {
			
			Set Desc = " IPD = "_tRs.GetData(1)_"; "_tRs.GetData(2)
			
		}
		
	}
		
	Quit tResult
}

/// set COEORI_GES as GES
ClassMethod websysSaveGES(compref As %String, pID As %String) As %Status
{
	Set tResult = $$$OK
	Quit:'$Data(%request) tResult
	
	If $Get(pID) = "" Set pID = $Get(%request.Data("ID",1))
	
	If $Get(pID)'="" {

		Set cID = ""
		
		&sql(select ID into :cID from Custom_HMS_Misc_User.OEOrdItem where COEORI_OEORI_DR = :pID)

		If cID'="" {
			
			Set obj = ##class(Custom.HMS.Misc.User.OEOrdItem).%OpenId(cID)
			If $IsObject(obj) {
				If obj.COEORIGES = 1 {
					Set obj.COEORIGES = 0
				}else{
					Set obj.COEORIGES = 1
				}
				Do obj.%Save()
			}
			Set tResult = "OK"
			
		}else{
			
			&sql(select OEORI_Text4 into :currGES from SQLUser.OE_OrdItem where OEORI_RowID = :pID)
			Set tSQL = "update SQLUser.OE_OrdItem (OEORI_Text4) values (?) where OEORI_RowID = (?)"
			Set tRs = ##class(%ResultSet).%New()
			Do tRs.Prepare(tSQL)
			Do tRs.Execute($S(currGES=1:"0",1:"1"),pID)
			Set tResult = $S(currGES=1:"0",1:"1")
			
		}
		
	}
	
	Quit 1 ///	tResult
}

/// link questionnaire IPD to GES item
ClassMethod LinkIPDtoGES(pID As %String, pIDs As %String) As %Status
{
	Set tResult = ""
	
	For tI=1:1:$Length(pIDs,"^")-1 {
		
		Set tID = $Piece(pIDs,"^",tI)
		Set tSQL = "update Custom_HMS_Misc_User.OEOrdItem (COEORI_QuestID) values (?) where COEORI_OEORI_DR = (?)"
		Set tRs = ##class(%ResultSet).%New()
		Do tRs.Prepare(tSQL)
		Do tRs.Execute(pID,tID)

	}	
	
	Quit tResult
}

/// link questionnaire IPD to GES item
ClassMethod UnLinkIPDtoGES(pIDs As %String) As %Status
{
	Set tResult = ""
	
	For tI=1:1:$Length(pIDs,"^")-1 {
		
		Set tID = $Piece(pIDs,"^",tI)
		Set tSQL = "update Custom_HMS_Misc_User.OEOrdItem (COEORI_QuestID) values (NULL) where COEORI_OEORI_DR = (?)"
		Set tRs = ##class(%ResultSet).%New()
		Do tRs.Prepare(tSQL)
		Do tRs.Execute(tID)

	}	
	
	Quit tResult
}

/// verify if OEOrdItem there Result Questionnaire
ClassMethod ChkItmResQuest(pID As %String, pApptID As %String = "") As %Integer [ ProcedureBlock = 1 ]
{
	Set tResult = 0
 	If pID="",pApptID'="" {
	 	&sql(select appt_rbcserv_dr->SER_ARCIM_DR into :pID from SQLUser.RB_Appointment where appt_rowid = :pApptID)
	 	Set tSQL = "select ARCIM_UserDefWindow_DR->WIN_Code from SQLUser.ARC_ItmMast where ARCIM_RowID = ?"
 	}else{
 		Set tSQL = "select OEORI_ItmMast_DR->ARCIM_UserDefWindow_DR->WIN_Code from SQLUser.OE_OrdItem where OEORI_RowID = ?"
 	}
	Set tRs = ##class(%ResultSet).%New()
	Do tRs.Prepare(tSQL)
	Do tRs.Execute(pID)
	If tRs.Next() {
		If tRs.GetDataByName("WIN_Code")'="" Set tResult = 1
	}
	
	Quit tResult
}

/// GetIdFromCodeOrDescription by OEOrdItem with Result Questionnaire
ClassMethod GetIdFromCodeOrDescription(pID, pCode, pAppt = "", OEOrdID = "")
{
	Set pCode = ""
	Set tSQL = "select OEORI_ItmMast_DR->ARCIM_UserDefWindow_DR, OEORI_ItmMast_DR->ARCIM_UserDefWindow_DR->WIN_Code, OEORI_RowID from SQLUser.OE_OrdItem where OEORI_RowID = ?"
	If pID="",pAppt'="" {
		Set tSQL = "select appt_rbcserv_dr->SER_ARCIM_DR->ARCIM_UserDefWindow_DR, appt_rbcserv_dr->SER_ARCIM_DR->ARCIM_UserDefWindow_DR->WIN_Code, APPT_OEORI_DR from SQLUser.RB_Appointment where appt_rowid = ?"
		Set pID = pAppt
	}
	Set tRs = ##class(%ResultSet).%New()
	Do tRs.Prepare(tSQL)
	Do tRs.Execute(pID)
	If tRs.Next() {
		Set tResult = tRs.GetDataByName("ARCIM_UserDefWindow_DR")
		Set pCode = tRs.GetDataByName("WIN_Code")
		If pAppt'="" Set OEOrdID = tRs.GetData(3)
	}

	Quit tResult
}

/// 	2013-03-28	Victor Skrobot	TRC	143263	CCR	
/// bug - fix calculated OEORIPHQtyOrd
ClassMethod UpdatePHQtyOrd(pID, pUOM) As %String
{
	Set tResult = ""
	////////////////////////////////////////////////////
	///	Check if Feature OrderRepeat is Activated
	/*Set tUDF = ##class(websys.Feature).GetIdFromCodeOrDescription("OrderRepeat")
	If 'tUDF Quit tResult
	Set tUDF = ##class(websys.Feature).%OpenId(tUDF)
	If tUDF.DateFrom,tUDF.DateFrom > +$H Quit tResult
	If tUDF.DateTo,tUDF.DateTo < +$H Quit tResult*/
	///
	///////////////////////////////////////////////////
	
	Set oOrdItem = ##class(User.OEOrdItem).%OpenId(pID)	
	
	If $IsObject(oOrdItem) {
		
		Set tQtyChanged = oOrdItem.OEORIPhQtyOrd
		Set tQtyEquiv = ##class(web.OEOrder).SetDispbuomQtyNoQtyCal(oOrdItem.OEORIItmMastDR.%Id(),pUOM)
		Set tResult = tQtyEquiv
		
		///	2015-10-20	Victor Skrobot	JIRA	TC-55899
		///	removing condition of qty Dosis Equivalente
		///	If tQtyEquiv="1" {
		
		///////////////////////////////////////
		///	2019-07-23	Victor Skrobot	
		///	if Order Custom AND not check calculate AND dosis variable AND round individual admin
		If (('$$GetITM2OrderVersion^COEOrdItem9(pID))&&(oOrdItem.OEORICalcQtyFlag'="Y")&&(oOrdItem.OEORIVariableDose'="")) {
			set drgform=$piece($get(^ARCIM(+oOrdItem.OEORIItmMastDR.%Id(),1,1)),"^",12)	///	ARCIMPHCDFDR
			set phcdfRound = $piece($get(^PHCD(+drgform,"DF",$piece(drgform,"||",2),3)),"^",13)	///	PHCDFRoundIndivAdmin
			if phcdfRound="Y" {
				set totResult = 0
				set iExec=$order(^OEORD(+pID,"I",$piece(pID,"||",2),"X",0))	/// get OEOrdExecs
				while iExec {
					set qtyExec = $piece(^OEORD(+pID,"I",$piece(pID,"||",2),"X",iExec),"^",4)	///	OEOREPhQtyOrd
					if ((qtyExec # tQtyEquiv)>0) set totResult = totResult + (((qtyExec \ tQtyEquiv)+1) * tQtyEquiv)
					if ((qtyExec # tQtyEquiv)=0) set totResult = totResult + ((qtyExec \ tQtyEquiv) * tQtyEquiv)
					set iExec=$order(^OEORD(+pID,"I",$piece(pID,"||",2),"X",iExec))
				}
				set oOrdItem.OEORIPhQtyOrd = totResult	///	update Order Item Qty
				do oOrdItem.%Save()
				Quit tResult
			}
		}
		///
		///////////////////////////////////////
			
		If oOrdItem.OEORICalcQtyFlag'="Y" Quit tResult
			
		///	2015-11-03	Victor Skrobot	JIRA	TC-60459
		/// dont recalculate Infusion Continua
		If oOrdItem.OEORIIVType '= "C" {
		
			Set tSQL = "select count(*) from SQLUser.OE_OrdExec where OEORE_OEORI_ParRef = ?"
			Set tRs = ##class(%ResultSet).%New()
			Do tRs.Prepare(tSQL)
			Do tRs.Execute(pID)
			If tRs.Next() {
				
				///	if its child...
				If $IsObject(oOrdItem.OEORIOEORIDR),oOrdItem.OEORIItmMastDR.%Id()'=oOrdItem.OEORIOEORIDR.OEORIItmMastDR.%Id() {
				
					Set tOrderType = ##class(web.ARCItmMast).GetOrderType(oOrdItem.OEORIItmMastDR.%Id())
					Set tOrderTypeParent = ##class(web.ARCItmMast).GetOrderType(oOrdItem.OEORIOEORIDR.OEORIItmMastDR.%Id())
					If tOrderType'="I" {
						If oOrdItem.OEORIVariableDose="" {
							If tOrderTypeParent="I" {
								If oOrdItem.OEORIOEORIDR.OEORIIVType = "P" {
									Set oOrdItem.OEORIPhQtyOrd = oOrdItem.OEORIOEORIDR.OEORIPhQtyOrd * oOrdItem.OEORIDoseQty
								}else{
									Set oOrdItem.OEORIPhQtyOrd = oOrdItem.OEORIDoseQty * tRs.GetData(1)
								}
							}else{
								Set oOrdItem.OEORIPhQtyOrd = oOrdItem.OEORIDoseQty * tRs.GetData(1)
							}
						}else{
							Set oOrdItem.OEORIPhQtyOrd = oOrdItem.OEORIOEORIDR.OEORIPhQtyOrd
						}
					}else{
						Set oOrdItem.OEORIPhQtyOrd = oOrdItem.OEORIOEORIDR.OEORIFlowQty * tRs.GetData(1)
					}
					If tQtyChanged'=oOrdItem.OEORIPhQtyOrd {
						Set oOrdItem.OEORIVariableDose = ""
					}
					Do oOrdItem.%Save()
					Set tResult = oOrdItem.OEORIPhQtyOrd
					
				}else{
					
					If oOrdItem.OEORIVariableDose="" {
						If (oOrdItem.OEORIDoseQty * tRs.GetData(1) '= oOrdItem.OEORIPhQtyOrd) {
							set drgform=$piece($get(^ARCIM(+oOrdItem.OEORIItmMastDR.%Id(),1,1)),"^",12)
							///
							set phcdfRound = $piece($get(^PHCD(+drgform,"DF",$piece(drgform,"||",2),3)),"^",13)	///	PHCDFRoundIndivAdmin
							if (phcdfRound'="Y") {
							/// 
								Set oOrdItem.OEORIPhQtyOrd = oOrdItem.OEORIDoseQty * tRs.GetData(1)
								
								set DoseEqvFact=##class(web.OEOrder).GetDoseEqvFact(drgform,oOrdItem.OEORIUnitDR.%Id())
								///	s ^zlsss=oOrdItem.%Id()_"^"_drgform_"^"_oOrdItem.OEORIUnitDR.%Id()_"^"_oOrdItem.OEORIPhQtyOrd
								if DoseEqvFact'="" set oOrdItem.OEORIPhQtyOrd = oOrdItem.OEORIPhQtyOrd * DoseEqvFact
								;If $Piece(oOrdItem.OEORIPhQtyOrd,".",2)'="" Set oOrdItem.OEORIPhQtyOrd = $Piece(oOrdItem.OEORIPhQtyOrd,".",1)+1
								Do oOrdItem.%Save()
							}
						}
					}else{
						If tQtyChanged'=oOrdItem.OEORIPhQtyOrd {
							Set oOrdItem.OEORIVariableDose = ""
							Do oOrdItem.%Save()
						}
					}
					Set tResult = oOrdItem.OEORIPhQtyOrd
					
				}
				
			}
			
		}
						
	}
	
	Quit tResult
}

/// verify if OEOrdItem by Appt
ClassMethod GetOEORIByAppt(pApptID As %String) As %Integer [ ProcedureBlock = 1 ]
{
	Set tResult = ""
	
 	&sql(select appt_oeori_dr into :tResult from SQLUser.RB_Appointment where appt_rowid = :pApptID)
	
	Quit tResult
}

/// don't show Frequency "Inmediata" on SessionList
ClassMethod LRFFreq(pRs) As %String
{
	Set tResult = 1
	Quit:'$Data(%request) tResult
	
	If $Get(%request.Data("TBLI",1))["Frequencyz",pRs.GetData(1)["Inmediata" Set tResult = 0
	
	Quit tResult
}

ClassMethod OnAfterSaveConfirmed() As %String
{
	Set tSC = $$$OK	
	Quit:'$Data(%request) tSC
	
	Set tClassName    = $$$CurrentClass 
	Set tEventMethod  = $$$CurrentMethod	
	Set tForm		  = $Get(%request.Data("TFORM",1))	
	Set tID			  = $Get(%request.Data("ID",1))
	Set tEpisodeID 	  = $Get(%request.Data("EpisodeID",1))
	Set tOEOrdItemIDs = $Get(%request.Data("OEOrdItemIDs",1))

	////////////////////////////////////////////////////////////
	///	2013-07-18	Victor Skrobot	TRC		CCR
	/// if repeated and OEORISttDat is after today set Status as Unverified
	Set tRepeated = 0
thisLoop
	Set tToday = +$h
	For tCount=1:1:$Length(tOEOrdItemIDs,"^")-1 {
		
		Set tID = $Piece($Piece(tOEOrdItemIDs,"^",tCount),"*",2)
		Set tOBJ = ##class(User.OEOrdItem).%OpenId(tID)
		
		If ((tOBJ.OEORIYesNo4="Y")!(tRepeated)),((tOBJ.OEORISttDat>tToday)!(tOBJ.OEORIYesNo4="Y")),tOBJ.OEORIItemStatDR.OSTATCode'="U" {

			Set tOEOrdItemID = $Piece($Piece(tOEOrdItemIDs,"^",tCount),"*",2)
			Set tArcim = $p($p(tOEOrdItemIDs,"^",tCount),"*",1)
			If 'tRepeated Set tRepeated=1
			//	Status as Unverified
			&SQL(update SQLUser.OE_OrdItem (OEORI_ItemStat_DR) values (2) where OEORI_RowID = :tOEOrdItemID)

		}
		
		d updexe^COEOrdItem6(tID)
		
	}
	;
	If tRepeated=1 {
		Set tRepeated=2
		Goto thisLoop
	}
	;
	//Do ..ChkRepeatProcess(tOEOrdItemIDs)
	////////////////////////////////////////////////////////////
	Set tSessionId = %session.SessionId
	Set ^TMP(tSessionId, "WEB", "ORDER_ENTRY", "lastRequest", "EpisodeID",1)=$Get(%request.Data("EpisodeID",1))
	Set ^TMP(tSessionId, "WEB", "ORDER_ENTRY", "lastRequest", "mradm",1)=$Get(%request.Data("mradm",1))
	Set ^TMP(tSessionId, "WEB", "ORDER_ENTRY", "lastRequest", "PatientID",1)=$Get(%request.Data("PatientID",1))

	////////////////////////////////////////////////////////////
	///	2013-09-05	Victor Skrobot	TRC		CCR
	/// if OEORIDuratDR->PHCDUCode = 1D4H delete OEOrdExec after limited 04:00
	Set tToday = +$h
	Set tHour0400 = $zth("04:00")
	For tCount=1:1:$Length(tOEOrdItemIDs,"^")-1 {
		
		Set tID = $Piece($Piece(tOEOrdItemIDs,"^",tCount),"*",2)
		Set tOBJ = ##class(User.OEOrdItem).%OpenId(tID)
		If (tOBJ.OEORIDuratDR.PHCDUCode="1D4H"),(tOBJ.OEORIItemStatDR.OSTATCode="V") {
			Set tSQL = "DELETE SQLUser.OE_OrdExec WHERE OEORE_OEORI_ParRef = '"_tID_"' and OEORE_ExStDate > "_tToday_" and OEORE_ExStTime > "_tHour0400
			Set tRs = ##class(%Library.ResultSet).%New()
			Do tRs.Prepare(tSQL)
			Set tSc = tRs.Execute()
		}
		
	}	
	
	Kill %session.Data("IsNewPrescNo")
	
	Quit tSC
}

ClassMethod GetReturnWithRun(tClass, tMethod, tParam1, tParam2 = "", tParam3 = "", tParam4 = "", tParam5 = "") As %String
{
	
	Set tResult = ""
	
	Set tStr = "Set tResult=##class("_tClass_")."_tMethod_"("_$s(tParam1["$lb":tParam1,1:""""_tParam1_"""")_""
	If tParam2'="" Set tStr = tStr_","""_tParam2_""""
	If tParam3'="" Set tStr = tStr_","""_tParam3_""""
	If tParam4'="" Set tStr = tStr_","""_tParam4_""""
	If tParam5'="" Set tStr = tStr_","""_tParam5_""""
	Set tStr = tStr_")"
	xecute tStr
	
	Quit tResult
}

ClassMethod GetLastPatient() As %String
{
	Set tResult = ""
	Set tSessionId = %session.SessionId

	//s zn="presc" d ^SSMOCARQ
	If '$Data(^TMP(tSessionId, "WEB", "ORDER_ENTRY", "lastRequest")) Quit tResult
	If $Get(%request.Data("EpisodeID",1))'="" Quit tResult
	
	Set %request.Data("EpisodeID",1)=$Get(^TMP(tSessionId, "WEB", "ORDER_ENTRY", "lastRequest", "EpisodeID", 1))
	Set %request.Data("mradm",1)=$Get(^TMP(tSessionId, "WEB", "ORDER_ENTRY", "lastRequest", "mradm", 1))
	Set %request.Data("PatientID",1)=$Get(^TMP(tSessionId, "WEB", "ORDER_ENTRY", "lastRequest", "PatientID", 1))
	
	Set EpisodeID=$Get(%request.Data("EpisodeID",1))
	Set mradm=$Get(%request.Data("mradm",1))
	Set PatientID=$Get(%request.Data("PatientID",1))
	
	Kill ^TMP(tSessionId, "WEB", "ORDER_ENTRY", "lastRequest")

	Quit tResult
}

ClassMethod AddToUnverified(pItems, pEpisodeID) As %String
{
	Set tResult = ""
	Set OrderItemIds = ""
	
	Set strSQL = "SELECT COEORI_No, COEORI_OEORI_DR->OEORI_SttDat, COEORI_OEORI_DR->OEORI_SttTim FROM Custom_HMS_Misc_User.OEOrdItem WHERE COEORI_PAAdm_DR = ? and COEORI_OEORI_DR->OEORI_ItemStat_DR->OSTAT_Code='U' ORDER BY COEORI_Date Desc, COEORI_Time Desc"
	Set tRsCheck = ##class(%Library.ResultSet).%New()
	Do tRsCheck.Prepare(strSQL)
	Set tSc = tRsCheck.Execute(pEpisodeID)
	If 'tRsCheck.Next() Quit ""
	
	Set tNo = tRsCheck.GetData(1)
	Set tDate = tRsCheck.GetData(2)
	Set tTime = tRsCheck.GetData(3)
	
	Do tRsCheck.%Close()
	
	For tI=1:1:($Length(pItems,"^")-1) {
		
		Set tID = $Piece(pItems,"^",tI)
		Set tField = "OEORI_OEORD_ParRef , OEORI_OrdEnt_DR , OEORI_ItmMast_DR , OEORI_OrdDept_DR , OEORI_PrescType , OEORI_ItemStat_DR , OEORI_Doctor_DR , OEORI_SttDat , OEORI_SttTim , OEORI_Priority_DR , OEORI_PHFreq_DR , OEORI_Dosage_DR , OEORI_Instr_DR , OEORI_Unit_DR , OEORI_PhQtyOrd , OEORI_XDate , OEORI_Durat_DR , OEORI_WhoGoWhere , OEORI_OperCategory_DR , OEORI_PrescNo , OEORI_PrescSeqNo , OEORI_ConsultDep_DR , OEORI_ConsultDr_DR , OEORI_Unit , OEORI_Time , OEORI_Unit_Hrs , OEORI_SpeedFlowRate , OEORI_FlowQty , OEORI_RecDep_DR , OEORI_Billed , OEORI_SeqNo , OEORI_AdmInsurance_DR , OEORI_Price , OEORI_CollectedBy , OEORI_Date , OEORI_NoOrdersLink , OEORI_OrderType_DR , OEORI_PRN , OEORI_DoseQty , OEORI_ARCOS_DR , OEORI_LinkNo , OEORI_LabEpisodeNo , OEORI_LabEpisodeSetup , OEORI_TimeOrd , OEORI_DateTime , OEORI_ResultFlag , OEORI_RMFreq_DR , OEORI_RMDurat_DR , OEORI_ItemGroup , OEORI_DateExecuted , OEORI_TimeExecuted , OEORI_UserExecuted , OEORI_APPT_DR , OEORI_DRGOrder , OEORI_UserAdd , OEORI_FinDate , OEORI_LabTestSetRow , OEORI_RefCln_DR , OEORI_HICClaimNo , OEORI_MainOeEnt_DR , OEORI_PharmacyStatus , OEORI_UserUpdate , OEORI_CollectionDep_DR , OEORI_ExpectedCollDate , OEORI_ExpectedCollTime , OEORI_Lab1 , OEORI_Lab2 , OEORI_MaxNumberOfRepeats , OEORI_AccessionNumber , OEORI_UpdateDate , OEORI_UpdateTime , OEORI_NoConsentOverrideReas_DR , OEORI_NoOrderedBags , OEORI_CurrSampleExpiry , OEORI_ReasOrdCMVNegBlood , OEORI_CompXMatchReq , OEORI_AutologousBloodReq , OEORI_PatConsentObtained , OEORI_BBTAG1 , OEORI_BBTAG2 , OEORI_BBTAG3 , OEORI_BBTAG4 , OEORI_BBTAG5 , OEORI_BBExtCode , OEORI_RefDoc_DR , OEORI_BBStatus , OEORI_Action_DR , OEORI_ResultComments , OEORI_AllergyReason_DR , OEORI_LabAction , OEORI_LabVolume , OEORI_LabSeqNo , OEORI_PlacerNo , OEORI_SentInExtract , OEORI_SeriesNo , OEORI_LabReceiveDate , OEORI_LabReceiveTime , OEORI_PostExamUserHospDR , OEORI_PreExamUserHospDR , OEORI_UserAuthoriseHospDR , OEORI_UserAddHospDR , OEORI_TheatreRequired , OEORI_TheatreDate , OEORI_TestSetComments , OEORI_ReturnDate , OEORI_ReturnTime , OEORI_ReturnUser_DR , OEORI_OEORI_DR , OEORI_DayBookAccessionNo , OEORI_DayBookSpecimen , OEORI_UnitsCollected , OEORI_IncompleteCollection , OEORI_UserUnRead_DR , OEORI_DateUnRead , OEORI_TimeUnread , OEORI_ReasonNotCollected , OEORI_PostExamStartTime , OEORI_IndicTransfusion_DR , OEORI_ClinicallySignificant , OEORI_SensitivitiesSignoff , OEORI_ContOrderAfterDischarge , OEORI_Route_DR , OEORI_PendingStatus_DR , OEORI_AuthoriseClinician_DR , OEORI_Notify , OEORI_NotifyClinician , OEORI_PACClinic_DR , OEORI_ResultUpdateDate , OEORI_ResultUpdateTime , OEORI_ResultUpdateUser_DR , OEORI_ResultUpdateHospital_DR , OEORI_EligibilityStatus , OEORI_RecLocVerified , OEORI_ResultAvailable , OEORI_ExternalPrimarySpecSite , OEORI_ExternalSecondarySpecSite , OEORI_ExternalRefDoctor_DR , OEORI_ResultAvailableDate , OEORI_ManufacturerOrder_DR , OEORI_HL7ResultStatus , OEORI_HL7ResultDate , OEORI_HL7ResultTime , OEORI_FreqDelay , OEORI_CancelReason_DR , OEORI_LabelText , OEORI_Specialty_DR , OEORI_AdminRoute_DR , OEORI_PRNMaxDose24hrs , OEORI_PRNTotNumberDosesAll , OEORI_PRNIndication , OEORI_Pregnant , OEORI_LDMP , OEORI_WeeksPregnant , OEORI_DayOfCycle , OEORI_LtClinicalCondition , OEORI_Questionnaire , OEORI_SupplierContactedDate , OEORI_SupplierContactedTime , OEORI_ProsReceivedDate , OEORI_ProsReceivedTime , OEORI_ProsBatchNo , OEORI_ProsSerialNo , OEORI_ProsSupplier , OEORI_ExpiryDate , OEORI_Size , OEORI_ImplantType_DR , OEORI_ReadyToBill , OEORI_DietFlag , OEORI_Activity , OEORI_View , OEORI_DSReportFlag , OEORI_ResultDSReportFlag , OEORI_PrescRepExpiryDate , OEORI_PrescRepNumberDays , OEORI_MaxRepeats , OEORI_CurrRepeatNumber , OEORI_Categ_DR , OEORI_Consult_DR , OEORI_Annotation_DR , OEORI_SkinTestOutcome_DR , OEORI_LTSpecCode , OEORI_LTSiteCode , OEORI_RetentionDays , OEORI_PackOverReason_DR , OEORI_UrgentReport , OEORI_PhoneOrder , OEORI_SecondOrderingUser_DR , OEORI_DatePOAuthorised , OEORI_TimePOAuthorised , OEORI_DateAuthReq , OEORI_TimeAuthReq , OEORI_AnaestAgent_DR , OEORI_OriginalOrder_DR , OEORI_ExamAbandonReason_DR , OEORI_ResultExist , OEORI_PreparationTime , OEORI_Personnel , OEORI_Comment1 , OEORI_Comment2 , OEORI_Comment3 , OEORI_RadiationDoesUnit_DR , OEORI_ReasonRejectPresc_DR , OEORI_DemandNumber , OEORI_RadiologyStatus , OEORI_RadAuthDoc_DR , OEORI_Panic , OEORI_LabelCopies , OEORI_OPB_IPB_Conversion , OEORI_ReassessmentDate , OEORI_ReassessmentTime , OEORI_DoNotDisplay , OEORI_ExtQtyTobePacked , OEORI_TotalExtQtyInBaseUOM , OEORI_ExtBaseUOM_DR , OEORI_DerivedFrom , OEORI_InsCardNoOverride , OEORI_BrokerageVendor_DR , OEORI_RepeatDesc , OEORI_BrokerageVendorRate_DR , OEORI_NumberPerWeek , OEORI_BrokerageGenerated , OEORI_InfoType , OEORI_InfoSubType , OEORI_ApplyTimeFrame , OEORI_IsBrokerage , OEORI_CalcQtyFlag , OEORI_EnteredUOM_DR , OEORI_PARefPathwayStage_DR , OEORI_Significant , OEORI_IsAdHoc , OEORI_UserReviewed_DR , OEORI_DateReviewed , OEORI_TimeReviewed , OEORI_Text1Reviewed , OEORI_Text2Reviewed , OEORI_EpisDepartDate , OEORI_EpisDepartTime , OEORI_EpisReadyDate , OEORI_EpisReadyTime , OEORI_Text1 , OEORI_Text2 , OEORI_Text3 , OEORI_Text4 , OEORI_YesNo1 , OEORI_YesNo2 , OEORI_YesNo3 , OEORI_YesNo4 , OEORI_ApprovalDate , OEORI_ApprovalTime , OEORI_ApprovedBy , OEORI_ApprovalNo , OEORI_ApprovalInd , OEORI_VariableDose , OEORI_ReasonIncReturn_DR , OEORI_IVType , OEORI_OEOrdItem2_DR , OEORI_ClinicGroup_DR "
		Set tSQL = "select "_tField_" from SQLUser.OE_OrdItem where OEORI_RowID = '"_tID_"'"
		Set tRs = ##class(%ResultSet).%New()
		Do tRs.Prepare(tSQL)
		Do tRs.Execute()
		If tRs.Next() {
			Set tSQL = "insert into SQLUser.OE_OrdItem "
			Set tFields = "",tValues = ""
			For tJ=1:1:tRs.GetColumnCount() {
				If tRs.GetColumnName(tJ)'="OEORI_RowId",tRs.GetColumnName(tJ)'="OEORI_ChildSub",tRs.GetColumnType(tJ)'=6,tRs.GetData(tJ)'="",tRs.GetColumnName(tJ)'="OEORI_LabelText" {
					Set tFields = tFields_tRs.GetColumnName(tJ)_","
					If tRs.GetColumnName(tJ)="OEORI_ItemStat_DR" {
						Set tValues = tValues_"'2'"_","
					}ElseIf tRs.GetColumnName(tJ)="OEORI_SttDat" {
						Set tValues = tValues_tDate_","
					}ElseIf tRs.GetColumnName(tJ)="OEORI_SttDat" {
						Set tValues = tValues_tTime_","
					}Else{
						Set tVal = tRs.GetData(tJ)
						//If tRs.GetColumnType(tJ)=6,tRs.GetData(tJ)'="" Set tVal =$lb(tRs.GetData(tJ))
						If tRs.GetData(tJ)="" {
							Set tValues = tValues_"NULL,"
						}else{
							Set tValues = tValues_"'"_tVal_"',"
						}
					}
				}
			}
			Set tSQL = tSQL_"("_$e(tFields,1,$Length(tFields)-1)_") values ("_$e(tValues,1,$Length(tValues)-1)_")"

			Set tRs = ##class(%ResultSet).%New()
			Do tRs.Prepare(tSQL)
			Do tRs.Execute()
			
			Set OrderItemIds=OrderItemIds_"*"_%ROWID_"*U^"
			
		}

		Do ..UpdatePrescNo(pEpisodeID,OrderItemIds,"AddToUnverified")
		
	}
	
	Quit OrderItemIds
}

ClassMethod CheckUnverified(pEpisodeID, pOrdItems = "", pStatus = "") As %String
{
	New (pEpisodeID, pOrdItems, pStatus)
	Set tResult = "0"
	Set tToday=+$h
	If pEpisodeID="" Quit tResult
	
	Set tSQL = "SELECT COEORI_OEORI_DR, COEORI_OEORI_DR->OEORI_ItmMast_DR FROM Custom_HMS_Misc_User.OEOrdItem WHERE COEORI_PAAdm_DR = ? and COEORI_OEORI_DR->OEORI_ItemStat_DR->OSTAT_Code = 'U' and COEORI_OEORI_DR->OEORI_SttDat >= ? ORDER BY COEORI_Date Desc, COEORI_Time Desc"
	Set tRs = ##class(%ResultSet).%New()
	Do tRs.Prepare(tSQL)
	Do tRs.Execute(pEpisodeID,tToday)
	If pOrdItems="" {
		Set tResult = tRs.Next()
	}else{
		Set tARCIMs = "",tSTAT = ""
		Set tIsUnferified = 1
		For tI=1:1:$Length(pOrdItems,"^") {
			Set tID = $Piece(pOrdItems,"^",tI),tARCIM="",tNo=""
			&sql(select COEORI_OEORI_DR->OEORI_ItmMast_DR, COEORI_No, COEORI_OEORI_DR->OEORI_ItemStat_DR->OSTAT_Code into :tARCIM, :tNo, :tSTAT from Custom_HMS_Misc_User.OEOrdItem where COEORI_OEORI_DR = :tID)
			Set tARCIMs = tARCIMs_"*"_tARCIM_"*"
			If tSTAT'="U" Set tIsUnferified = 0
		}
		If tARCIMs = "" Quit tResult
		If tIsUnferified Quit tResult
		While tRs.Next() {

			Set tItm = "*"_tRs.GetData(2)_"*"
			If tARCIMs[tItm {

				If pStatus="" {
					Set tResult = 1
					Quit
				}else{
					Set tOrd = tRs.GetData(1)
					Set tStatusID = ##class(web.OECOrderStatus).GetIdFromCodeOrDescription(pStatus)
					&sql(update SQLUser.OE_OrdItem (OEORI_ItemStat_DR) values (:tStatusID) where OEORI_RowID = :tOrd)
					&sql(update Custom_HMS_Misc_User.OEOrdItem (COEORI_No) values (:tNo) where COEORI_OEORI_DR = :tOrd)
				}

			}
		}
	}
	
	Quit tResult
}

ClassMethod SetUnverified(pOEOrdItemIDs)
{
	
	For tCount=1:1:$Length(pOEOrdItemIDs,"^")-1 {
		
		Set tOEOrdItemID=$Piece($Piece(pOEOrdItemIDs,"^",tCount),"*",2)	
		Set tObj = ##class(User.OEOrdItem).%Open(tOEOrdItemID)
		If $IsObject(tObj) {
			If tObj.OEORISttDat>tObj.OEORIDate {
			}
		}
		
	}
}

ClassMethod GetDatas(pID, pFields) As %String
{
	Set tResult = ""
	Set tSQL = "select "_pFields_" from SQLUser.OE_OrdItem where OEORI_RowID = '"_pID_"'"
	Set tRs = ##class(%ResultSet).%New()
	Do tRs.Prepare(tSQL)
	Do tRs.Execute()
	If tRs.Next() {
		For tJ=1:1:tRs.GetColumnCount() {
			Set tResult = tResult_tRs.GetData(tJ)_"^"
		}
	}
	Quit tResult
}

ClassMethod ChkRepeatProcess(tOEOrdItemIDs)
{
	////////////////////////////////////////////////////////////
	///	2013-01-11	Victor Skrobot	TRC		CCR
	/// verify frequency with limits
	/// 1 - New prescription does not allow frequency more than next day after 13:00pm - REMOVED
	/// 2 - Repetition prescription can not be did with the same time of frequency of original
	Set tToday = +$h
	Set tTomorrow = $h+1
	Set tItmsDel = "''"

	For tCount=1:1:$Length(tOEOrdItemIDs,"^")-1 {
		
		Set tID = $Piece($Piece(tOEOrdItemIDs,"^",tCount),"*",2)
		Set tOBJ = ##class(User.OEOrdItem).%OpenId(tID)
		Set tTime13 = 46801
		/// rule only for Duration = 1 dia
		If tOBJ,tOBJ.OEORIDuratDR.PHCDUCode=1,+tOBJ.OEORIPHFreqDR.PHCFRCode,+tOBJ.OEORIPHFreqDR.PHCFRDays {
					
			Set tAllowExtPresc = tOBJ.OEORIDSReportFlag
			Set tHrs = (24 / tOBJ.OEORIPHFreqDR.PHCFRFactor) * 60 * 60
		
			Set tSQL = "select OEORE_RowID, OEORE_ExStTime from OE_OrdExec where OEORE_OEORI_ParRef = ? "_
						"and ( "_
	        			"(OEORE_ExStDate > ?) "_
	    				")"
			Set tRs = ##class(%Library.ResultSet).%New()
			Do tRs.Prepare(tSQL)
			Set tSc = tRs.Execute(tID,tToday)
    		While tRs.Next() {
    		
	    		/// remove itens from tomorrow
	    		If tAllowExtPresc '= "Y" {
		    		Set tItmsDel = tItmsDel_",'"_tRs.GetData(1)_"'"
	    		}else{
		    		If tRs.GetData(2) > tTime13 {
			    		///	Set tItmsDel = tItmsDel_",'"_tRs.GetData(1)_"'"
		    		}
	    		}
    		
    		}
    		Do tRs.Close()
		
    		If tItmsDel'="''" {
    		
	    		Set tSQL = "delete SQLUser.OE_OrdExec where OEORE_RowID in ("_tItmsDel_")"
				Set tRs = ##class(%Library.ResultSet).%New()
				Do tRs.Prepare(tSQL)
				Set tSc = tRs.Execute()
			
    		}
NextSearch
			Set tSQL = "select top 1 OEORE_RowID, OEORE_ExStDate, OEORE_ExStTime from OE_OrdExec where "_
						"OEORE_OEORI_ParRef = ? and "_
						"OEORE_ExStDate >= ? "_
						"ORDER BY OEORE_ExStDate DESC, OEORE_ExStTime DESC"
			Set tRs = ##class(%Library.ResultSet).%New()
			Do tRs.Prepare(tSQL)
			Set tSc = tRs.Execute(tID,tToday)
			If tRs.Next() {
			
				Set tNeedNew = 0
				If tRs.GetData(2) = +$h {
					if tRs.GetData(3) + tHrs > 86399 {
						Set tDate = tToday + 1
						Set tTime = tHrs - (86400 - tRs.GetData(3))
					}else{
						Set tDate = tToday
						Set tTime = tHrs + tRs.GetData(3)
					}
					Set tNeedNew = 1
				}
				
				If (tRs.GetData(2) = tTomorrow),(tTime13 - tRs.GetData(3) > tHrs) {
					Set tDate = tTomorrow
					Set tTime = tRs.GetData(3) + tHrs
					Set tNeedNew = 1
				}
				
				
				If tNeedNew {
				
					//Do tRs.Close()
					////// BUG - childsub not auto generated
					Set tChildSub = $Get(^OEORD($Piece(tID,"||",1),"I",$Piece(tID,"||",2),"X",0))+1
					////// BUG - childsub not auto generated
		    		Set tSQL = "insert into SQLUser.OE_OrdExec "_
		    				"(OEORE_OEORI_ParRef, OEORE_ChildSub, OEORE_PhQtyOrd, OEORE_ExStDate, OEORE_ExStTime, OEORE_StDateTime) "_
		    				"values "_
		    				"(?,?,?,?,?,?)"
					Set tRsIns = ##class(%Library.ResultSet).%New()
					Do tRsIns.Prepare(tSQL)
					Set tSc = tRsIns.Execute(tID, tChildSub, 1, tDate, tTime, tDate_"Z"_tTime)
					If tSc Goto NextSearch
					
				}
				
			}
			//Do tRs.Close()
		
			/// it's an repetition
			If tOBJ.OEORIYesNo4 = "Y" {

				Set tIDRepeatFrom = $replace(tOBJ.OEORIDayBookAccessionNo,"/","||")
				Set tIDRepeatFrom = $e(tIDRepeatFrom,1,$l(tIDRepeatFrom)-1)
				
				Set (tDateFirst,tDateLast,tTimeFirst,tTimeLast)=""
				Set tSQL = "select top 1 OEORE_RowID, OEORE_ExStDate, OEORE_ExStTime from SQLUser.OE_OrdExec where "_
							"OEORE_OEORI_ParRef = ? "_
							"ORDER BY OEORE_ExStDate ASC, OEORE_ExStTime ASC"
				Set tRs = ##class(%Library.ResultSet).%New()
				Do tRs.Prepare(tSQL)
				Set tSc = tRs.Execute(tIDRepeatFrom)
				If tRs.Next() {
					Set tDateFirst = tRs.GetData(2)
					Set tTimeFirst = tRs.GetData(3)
				}
				Do tRs.Close()
				Set tSQL = "select top 1 OEORE_RowID, OEORE_ExStDate, OEORE_ExStTime from SQLUser.OE_OrdExec where "_
							"OEORE_OEORI_ParRef = ? "_
							"ORDER BY OEORE_ExStDate DESC, OEORE_ExStTime DESC"
				Set tRs = ##class(%Library.ResultSet).%New()
				Do tRs.Prepare(tSQL)
				
				Set tSc = tRs.Execute(tIDRepeatFrom)
				If tRs.Next() {
					Set tDateLast = tRs.GetData(2)
					Set tTimeLast = tRs.GetData(3)
				}
				Do tRs.Close()

				Set tSQL = "delete SQLUser.OE_OrdExec where "_
							"OEORE_OEORI_ParRef = ? and "_
							"((OEORE_ExStDate = ? and OEORE_ExStTime >= ?) "_
							"or "_
							"(OEORE_ExStDate = ? and OEORE_ExStTime <= ?)) "
				Set tRs = ##class(%Library.ResultSet).%New()
				Do tRs.Prepare(tSQL)
				Set tSc = tRs.Execute(tID, tDateFirst, tTimeFirst, tDateLast, tTimeLast)
				
			}

		}
		
	}
	
	Kill %session.Data("OEORIs")
	////////////////////////////////////////////////////////////
}

/// 	2013-08-20	Get New Prescripcion Number from PAAdm
ClassMethod GetNewPrescNo(pEpisodeID As %String, pDate As %String = "") As %String
{
	Set tResult = 0
	
	Set tSQL = "select COEORI_No from Custom_HMS_Misc_User.OEOrdItem where COEORI_PAAdm_DR = "_pEpisodeID_" ORDER BY +COEORI_No DESC"	
	Set tRs = ##class(%Library.ResultSet).%New()
	Do tRs.Prepare(tSQL)
	Do tRs.Execute()
	If tRs.Next() {
		Set tResult = tRs.GetData(1)	
	}
	Set tResult = tResult + 1
	
	Quit tResult
}

/// 	2013-08-20
ClassMethod AuthoriseOrder(pOEOrdItem As %String)
{
	Set tToday = +$h
	Set tNow = $Piece($h,",",2)
	Set tOrder = $Piece(pOEOrdItem,"||",1)
	Set oOrdItem = ##class(User.OEOrdItem).%OpenId(pOEOrdItem)
	
	If $IsObject(oOrdItem) {
		
		Set tArcim = oOrdItem.OEORIItmMastDR.%Id()
		///Set ^IscPresc("Authorized",tOEOrdItemID) = tUserID_"^"_tToday_"^"_tNow
		Set oOrdItem.OEORIItemStatDR = ##class(User.OECOrderStatus).%OpenId(1)
	
		//////////////////////////////////////////////////
		/// save data on OEOrdItem
		/// UPDATE SttDat and SttTim and OEOrdExec
		Set oOrdItem.OEORISttDat = +$h
		Set oOrdItem.OEORISttTim = tNow
		/// UPDATE Date and Time on OEOrdItem
		Set oOrdItem.OEORIDate = +$h
		Set oOrdItem.OEORITime = tNow
		Set oOrdItem.OEORITimeOrd = tNow
		Do oOrdItem.%Save()	
		Do updexe^COEOrdItem6(pOEOrdItem)
		//////////////////////////////////////////////////

		//////////////////////////////////////////////////
		/// save data on OEOrdItem
		/// UPDATE Date and Time and No on Custom_HMS_Misc_User.OEOrdItem
		Set tSQL = "update Custom_HMS_Misc_User.OEOrdItem (COEORI_Date, COEORI_Time, COEORI_No) values ("_tToday_","_tNow_","_tNewPrescNo_") where COEORI_OEORI_DR = '"_pOEOrdItem_"'"
		Set tRs = ##class(%ResultSet).%New()
		Do tRs.Prepare(tSQL)
		Do tRs.Execute()
		//////////////////////////////////////////////////
		
		//////////////////////////////////////////////////
		/// save data on OEOrdItem
		/// set Status as Suspendido if duplicated
		Set tAdminStatus = ##class(web.OECOrderAdminStatus).GetIdFromCodeOrDescription("Suspendido automatico")
		Set tSQL = "select OEORE_RowId from oe_ordexec where "_
					"OEORE_OEORI_ParRef->OEORI_OEORD_ParRef = ? and "_
					"OEORE_OEORI_ParRef->OEORI_ItmMast_DR = ? and "_
					"OEORE_OEORI_ParRef <> ? and "_
					"(OEORE_ExStDate > ? or (OEORE_ExStDate = ? and OEORE_ExStTime >= ?)) and "_
					"OEORE_Order_Status_DR IS NULL"
		Set tRs = ##class(%ResultSet).%New()
		Do tRs.Prepare(tSQL)
		Do tRs.Execute(tOrder,tArcim,pOEOrdItem,tToday,tToday,tNow)
		While tRs.Next() {
			Set tOEOREID = tRs.GetData(1)
			&sql(UPDATE SQLUser.OE_OrdExec (OEORE_Order_Status_DR) values (:tAdminStatus) where OEORE_RowID = :tOEOREID)
		}
		/// check if there is none other status
		Set tOEORIStatusD = 1
		Set tX=$Order(^OEORD(+pOEOrdItem,"I",$Piece(pOEOrdItem,"||",2),"X",0))
		While tX'="" {
			If $Piece(^OEORD(+pOEOrdItem,"I",$Piece(pOEOrdItem,"||",2),"X",tX),"^",16)'=tAdminStatus Set tOEORIStatusD = 0
			Set tX=$Order(^OEORD(+pOEOrdItem,"I",$Piece(pOEOrdItem,"||",2),"X",tX))
		}
		If tOEORIStatusD {
			Do ChangeStatus^COEOrdItem(pOEOrdItem,"D","","","DIS")
		}
		//////////////////////////////////////////////////
		Set tResult = ""

	}
	
	Quit
}

/// 2013-08-12	Victor Skrobot	TRC		CCR		
/// get YesNo fields
Query GetYesNos() As %Library.SQLQuery(CONTAINID = 0, ROWSPEC = "Code:%String,Description:%String")
{

	select
	Dic.Phrase Code,
	case ISNULL(Trans.Phrase,0)
	when 0 then Dic.Phrase
	else Trans.Phrase
	end Description
	from websys.Dictionary Dic
	left outer join websys.DictionaryTranslated Trans on Item = Dic.ID
	where
	Dic.Phrase %STARTSWITH 'YesNo'
	and not Trans.Phrase is null
	-- hardcoded YesNo1 or YesNo2 or YesNo3
	and (Dic.Phrase='YesNo1' or Dic.Phrase='YesNo2' or Dic.Phrase='YesNo3')
}

/*
TRC: 76989
Author: ggerena
Description: Returns 0 if 
	1. HospId = HSJD
	2. Sec Group = "HSJD SSMOC Medico Ambulatorio" or "HSJD SSMOC MEDICO GINECO-OBSTETRA AMB" 
	3. (at least) one of the given oe_orditem's is associated to subcategory "Microbiologia" (ARCItemCat)
  Otherwise it returns 1
*/
ClassMethod ShowReportRecetaExterna3(OEOrdItemIDs As %String, HospId As %String, GroupDesc As %String, pEpisodeID As %String = "") As %String
{
	
	Set Ret = 1

	/// rule 1
	/// si el hospital de logon NO es HSJD muestra el reporte
	If ($g(HospId)="")||(HospId'=2){
		Quit Ret
	}
	
	/*
	/// rule 3
	/// NO muestra reporte si el episodio es Hospitalizado o Urgente
	If $Get(OEOrdItemIDs)'="" {
		Set OEOrder=$Piece($Piece(OEOrdItemIDs,"*",2),"||",1),AdmType=""
		&SQL(select OEORD_Adm_DR->PAADM_Type into :AdmType from SQLUser.OE_Order where OEORD_RowId = :OEOrder)
		If AdmType'="O" {
			Set Ret=0 
			Quit Ret
		}
	}
	
	/// rule 4
	/// muestra reporte con algunos grupos de seguridad 
	If ($g(GroupDesc)="") || ((GroupDesc'="HSJD SSMOC Medico Ambulatorio")&&(GroupDesc'="HSJD SSMOC MEDICO GINECO-OBSTETRA AMB")&&(GroupDesc'="HSJD SSMOC Medico Urg")){
		Quit Ret
	}
	*/
	
	/// rule 2
	/// si la subcategoria de item es Microbiológicos muestra el reporte
	Set Ret = 0
	Quit:($g(OEOrdItemIDs)="") Ret
	For i=1:1:$Length(OEOrdItemIDs,"*") {
		Set OEORIRowId = $p(OEOrdItemIDs,"*",i)
		Quit:((+OEORIRowId)=0)
		&SQL(select OEORI_ItmMast_DR->ARCIM_ItemCat_DR->ARCIC_Code into :ARCICCode from SQLUser.OE_OrdItem where OEORI_RowId = :OEORIRowId)
		If (SQLCODE=0),(ARCICCode="0306000"){
			Set Ret = 1
			Quit 
		}
	}

	Quit Ret
}

/*
 * TRC		: 93347
 * Author	: MAguirre
 * Date		: 2011.12.14
 * Comments	: Replaces the current behavior of the counter, because in GALAH isn't work properly.
 *			  The LOG 84667 was generated to fix this issue, meanwhile this workaround repairs the problem.
 */
ClassMethod RadCountTotal(TSRTITM As %Library.String = "", TSRTORD As %Library.String = "", CTLOCDesc As %Library.String = "", DateFrom As %Library.Date = "", DateTo As %Library.Date = "", RegistrationNo As %Library.String = "", TestEpisodeNo As %Library.String = "", OSTATDesc As %Library.String = "", ConsCTPCPDesc As %Library.String = "", RESCDesc As %Library.String = "", OEORIAccessionNumber As %Library.String = "", ApptOnly As %Library.String = "", EpisodeType As %Library.String = "", resultstatusapex As %Library.String = "", resultstatuskestral As %Library.String = "", resultstatus As %Library.String = "") As %String
{
	;do ToGlobal^SSMOCARQ
	n user,work,AtEnd,cnt,UID,GID
	n CTLOC,OSTAT,ConsCTPCP,Resource,AccessionNo,RBRES,EpisCode,OSTATCode,RefID,OPriID,ResultDesc,TranscribedBy,urgent,overseen,code
	s (CTLOC,OSTAT,ConsCTPCP,Resource,AccessionNo,RBRES,EpisCode,OSTATCode,RefID,OPriID,ResultDesc,TranscribedBy,urgent,overseen,code,getReport,ExecStatList)=""
	s (newepis,SupResFlag,startflag)=0

	s DateFrom=##Class(websys.Conversions).DateHtmlToLogical($g(DateFrom))
	s DateTo=##Class(websys.Conversions).DateHtmlToLogical($g(DateTo))

	s UID=%session.Get("LOGON.USERID")
	s GID=%session.Get("LOGON.GROUPID")
	; Log 61269 - AI - 26-02-2007 : Get the translation of "Non-Standard Report" from the component messages.
	d ##Class(websys.Component).GetComponentMessages(.t,"OEOrdItem.RadiologyWorkBench")
	s NSRmessage=$g(t("NonStandardReport"))

	; LOG 39988 RC 23/10/03 We need to call it this way instead of passing it through the query because the query can't handle
	; more than 16 variables, and these are the ones more than 16.
	s ATTENDDesc=$g(%request.Data("ATTENDDesc",1))
	s OrderPrior=$g(%request.Data("OrderPriority",1))
	s ItemDesc=$g(%request.Data("OrdItemDesc",1))
	s OSTATString=$g(%request.Data("hiddenOSTATDesc",1))
	;log 61271 TedT new search fields
	s ResultDesc=%request.Get("ResultDesc")
	s TranscribedBy=##Class(web.SSUser).GetIdFromCodeOrDescription(%request.Get("TranscribedBy"))
	;s UserCode=##Class(web.CTCareProv).GetIdFromCodeOrUserDesc(%request.Get("UserCode"))
	s urgent=##Class(websys.Conversions).YesNoHtmlToLogical(%request.Get("urgent"))
	s overseen=##Class(web.CTCareProv).GetIdFromCodeOrUserDesc(%request.Get("OverseenBy"))
	s ExecStatList=%request.Get("HidExecStatList")
	i $g(ExecStatList)'="" s ExecStatList=$e(ExecStatList,1,$l(ExecStatList)-1)
	;log 64239
	s executeFrom=##Class(websys.Conversions).DateHtmlToLogical(%request.Get("executeFrom"))
	s executeTo=##Class(websys.Conversions).DateHtmlToLogical(%request.Get("executeTo"))
	s personId=%request.Get("personId")
	s groupResult=%request.Get("groupResult")

	s WardID=##Class(web.PACWard).GetIdFromCodeOrDescription(%request.Get("WardDesc"))
	s parameters=executeFrom_"^"_executeTo_"^"_personId_"^"_groupResult_"^"_ExecStatList_"^"_WardID

	i OSTATDesc="",OSTATString'="" s OSTATDesc=OSTATString
	s ItemId=##Class(web.ARCItmMast).GetIdFromCodeOrDescription(ItemDesc)
	;LOG 52109 RC 23/05/05 If ID is blank, but desc isn't, then it's probably an alias and work out accordingly.
	i ItemId="",ItemDesc'="" d 
	. s ItemId=$$findbyalias^COEOrdItem1($p(ItemDesc,"-"))
	. s ItemId=$p(ItemId,"^")

	;i TSRTITM'="" s %request.Data("RetainFieldValue",1)="on" d ..RetainValues()
	i TSRTORD="" s TSRTORD="D"
	s VSTAT=##Class(web.OECOrderStatus).GetIdFromCodeOrDescription("V") ;verified status
	s PatientID=##Class(web.PAPatMas).GetIdFromCodeOrDescription(RegistrationNo)
	i CTLOCDesc'="" s CTLOC=##Class(web.CTLoc).GetIdFromCodeOrDescription(CTLOCDesc)
	i CTLOCDesc="" s CTLOC=##Class(web.OEOrdItem).GetLocations(%session.Get("LOGON.GROUPID")) ;MartinM: Log 70792
	;s TestEpisodeNo=##Class(%Library.Collation).AlphaUp(TestEpisodeNo)
	i ConsCTPCPDesc'="" s ConsCTPCP=##Class(web.CTCareProv).GetIdFromCodeOrUserDesc(ConsCTPCPDesc)
	i OSTATDesc'="" 
	{
	n statTemp
	s len=$l(OSTATDesc,"|")-1
	i len=0
	{
	    s OSTATDesc=OSTATDesc_"|"
	    s len=1
	}

	f statCount=1:1:len
	{
	    s statTemp=""       
	    s OSTATCode=##Class(websys.StandardTypeItem).GetIdFromCodeOrDescription("RadiologyOrderStatus",$p(OSTATDesc,"|",statCount))
	    s statTemp=##Class(web.OECOrderStatus).GetIdFromCodeOrDescription(OSTATCode) ;s OSTAT=$o(^OEC("OSTAT",0,"Code",OSTATCode))
	    i statTemp="" s statTemp=OSTATCode
	    s OSTAT=OSTAT_statTemp_"|"          
	}
	}
	;RC 22/06/06 59740 Use security group status selections if a status is not selected when clicking find.
	i OSTAT="" {
	s ID=##Class(epr.GroupSettings).GetIdFromGroupId(GID) 
	i ID s grp=##Class(epr.GroupSettings).%OpenId(ID,0)
	i grp {
	    s statlist=grp.RadSTOrdStatus
	    d grp.%Close()
	}
	i statlist'="" {
	    f i=1:1:$l(statlist,",") {
	        q:$p(statlist,",",i)=""
	        s statTemp=""
	        s OSTATCode=##Class(websys.StandardTypeItem).GetIdFromCodeOrDescription("RadiologyOrderStatus",$p(statlist,",",i))
	        s statTemp=##Class(web.OECOrderStatus).GetIdFromCodeOrDescription(OSTATCode)
	        i OSTATCode="P",$p(OSTATDesc,"|",i)="Prescribed" s statTemp=OSTATCode
	        i statTemp="" s statTemp=OSTATCode
	        s OSTAT=OSTAT_statTemp_"|"
	    }
	}
	}
	i RESCDesc'="" s RBRES=##Class(web.RBResource).GetIdFromLocationAndRes(CTLOC,RESCDesc)
	i EpisodeType'="" d
	. s EpisCode=##Class(websys.StandardTypeItem).GetIdFromCodeOrDescription("AdmType",EpisodeType)
	i ATTENDDesc'="" d
	. s RefID=##Class(web.PACSourceOfAttendance).GetIdFromCodeOrDescription(ATTENDDesc)
	i OrderPrior'="" d
	. s OPriID=##Class(web.OECPriority).GetIdFromCodeOrDescription(OrderPrior)
	k PRIORlist
	n work,zcnt,oeitm
	s (work,user,oeitm)=""
	s OEORIAccessionNumber=$tr(OEORIAccessionNumber," ")

	n resultstatusapexCode,resultstatuskestralCode,resultstatusCode
	s (resultstatusapexCode,resultstatuskestralCode,resultstatusCode)=""
	i resultstatuskestral'="" s resultstatuskestralCode=##Class(websys.StandardTypeItem).GetIdFromCodeOrDescription("KestralLabStatus",resultstatuskestral)
	i resultstatus'="" s resultstatusCode=##Class(websys.StandardTypeItem).GetIdFromCodeOrDescription("ResultType",resultstatus)
	s AllowViewVIP=##Class(web.SSGroup).GetAllowViewVIP(%session.Get("LOGON.GROUPID"))     ; cjb 19/01/2006 55848

	s ExecOnly=$g(%request.Data("ExecOnly",1))
	i $g(ExecOnly)="on" s ExecOnly="Y"

	k PLIST 
	s tmpurgent=$g(urgent)
	s code=$$open^COEOrdItem3(TSRTITM,TSRTORD,CTLOC,DateFrom,DateTo,RegistrationNo,TestEpisodeNo,OSTAT,ConsCTPCP,RBRES,OEORIAccessionNumber,ApptOnly,EpisCode,resultstatusapexCode,resultstatuskestralCode,resultstatusCode,RefID,ItemId,OPriID,tmpurgent,parameters,ExecOnly)

	k PLIST //need to kill before the fetch 
	s count = 0
	f  s code=$$fetch^COEOrdItem3(TSRTITM,TSRTORD,CTLOC,DateFrom,DateTo,RegistrationNo,TestEpisodeNo,OSTAT,ConsCTPCP,RBRES,OEORIAccessionNumber,ApptOnly,EpisCode,resultstatusapexCode,resultstatuskestralCode,resultstatusCode,RefID,ItemId,OPriID,tmpurgent,parameters,ExecOnly) q:code  q:count>250  d
	. s startflag=0
	. s ID=PLIST(1)
	. s ResDesc=##Class(web.OEOrdResult).GetDescription(ID)
	. s urg=##Class(web.OEOrdResult).GetUrgentReport(ID)
	. s startflag=(##Class(web.OEOrdResult).GetReport(ID,ResultDesc,TranscribedBy,overseen)'="")
	. s APPTStatus=PLIST(17) ;apptstat
	. s OEORIItemStatus=##Class(web.OECOrderStatus).GetCodeFromDescription("",PLIST(19))
	. s OEORIAuthorisedDate=PLIST(20)
	. s RESULTStatus=##Class(web.OEOrdResult).GetRadiologyStatus(ID,.SupResFlag)
	. i RESULTStatus'="",OEORIItemStatus="IP" s OEORIItemStatus="E"
	. i $o(^OEORD(+ID,"I",+$p(ID,"||",2),"ACT",""),-1)'="" d 
	. . s action=$o(^OEORD(+ID,"I",+$p(ID,"||",2),"ACT",""),-1)
	. . s OEORIItemStatus=$p($g(^OEORD(+ID,"I",+$p(ID,"||",2),"ACT",action)),"^")
	. s ItemStatusCode=OEORIItemStatus
	. s:(OEORIItemStatus="V")&(OEORIAuthorisedDate'="") OEORIItemStatus="AUTH"
	. s:(APPTStatus="N")&(OEORIItemStatus="V") OEORIItemStatus="DNA"
	. s:(APPTStatus="N")&(OEORIItemStatus="S") OEORIItemStatus="DNA"
	. s:(APPTStatus="N")&(OEORIItemStatus="AUTH") OEORIItemStatus="DNA"
	. s:(RESULTStatus'="")&(OEORIItemStatus="E") OEORIItemStatus=RESULTStatus
	. s StandType=##class(websys.StandardTypeItem).GetDescriptionPlus("RadiologyOrderStatus",OEORIItemStatus)
	. i $g(OSTAT)'="",startflag d
	. . s startflag=0
	. . i OEORIItemStatus="V",OEORIAuthorisedDate'="" s OEORIItemStatus="AUTH"
	. . s statlen=$l(OSTAT,"|")
	. . f i=1:1:statlen-1 d
	. . . q:startflag=1 
	. . . s stat=$p(OSTAT,"|",i)
	. . . i stat="AUTH",OEORIItemStatus=stat s startflag=1
	. . . i RESULTStatus="",OEORIItemStatus=##Class(web.OECOrderStatus).GetCodeFromDescription("",stat) s startflag=1
	. . . i RESULTStatus'="",RESULTStatus=stat s startflag=1
	. . . i stat="DNA",APPTStatus="N" s startflag=1
	. i startflag s count=count+1

	s code=$$close^COEOrdItem3()

	q $s(count>250 : "> 250", 1:count)
}

/*
 * END TRC	: 93347
 */

/**
 * TRC		: 94331
 * Author	: MAguirre
 * Date		: 2011.12.22
 * Comments	: Method that changes the Pharmacy Status field of the specified Oder Items
 */
ClassMethod SetPharmacyStatus(OEOrdItemIDs As %String, PharmacyStatus As %String) As %String
{
	Set tResult = ""
	
	Set rs = ##class(%ResultSet).%New()
	Set sc = rs.Prepare(
		"UPDATE SQLUser.OE_OrdItem SET OEORI_PharmacyStatus = ? " _
		"WHERE OEORI_RowId IN (" _ OEOrdItemIDs _ ")"
	)
	Quit:$System.Status.IsError(sc) "ERROR^" _ $System.Status.GetErrorText(sc)
	
	Set sc = rs.Execute(PharmacyStatus)
	Quit:$System.Status.IsError(sc) "ERROR^" _ $System.Status.GetErrorText(sc)
	
	Quit tResult
}

/**
 * END TRC	: 94331
 */

/**
 * TRC		: 100814
 * Author	: MAguirre
 * Date		: 2011.12.22
 * Comments	: Method that changes the Quantity ordered field of the specified Order Items
 */
ClassMethod SetPharmacyQty(OEOrdItemID As %String, Qty As %String) As %String
{
	Set tResult = ""
	Set rs = ##class(%ResultSet).%New()
	Set sc = rs.Prepare(
		"UPDATE SQLUser.OE_OrdItem SET OEORI_DoseQty = ?, OEORI_PhQtyOrd = ? " _
		"WHERE OEORI_RowId = ? "
	)
	Quit:$System.Status.IsError(sc) "ERROR^" _ $System.Status.GetErrorText(sc)
	
	Set sc = rs.Execute(Qty,Qty,OEOrdItemID)
	Quit:$System.Status.IsError(sc) "ERROR^" _ $System.Status.GetErrorText(sc)
	
	Quit tResult
}

/**
 * END TRC	: 100814
 */

/**
 * TRC		: 94483
 * Author	: MAguirre
 * Date		: 2011.12.23
 * Comments	: Method that get the Controlled Drug status of an order item
 */
ClassMethod IsControlledDrug(OEOrdItemID As %String) As %String
{
	Set tResult = "0"
	
	Set order = ##class(User.OEOrdItem).%OpenId(OEOrdItemID)
	If $IsObject(order) {
		Set poison = order.OEORIItmMastDR.ARCIMPHCDFDR.PHCDFPoisonDR
		If $IsObject(poison) {
			Set tResult = "1"
		}
	} Else {
		Set tResult = "ERROR^No existe el item"
	}
	
	Quit tResult
}

/**
 * END TRC	: 94483
 */
ClassMethod ChangePriority(OEOrdItemID As %String, PriorityCode As %String) As %String
{
	Set tResult = 1
	Try {
		If OEOrdItemID '= "" && PriorityCode '= "" {
			Set PriorityId = ##class(web.OECPriority).GetIdFromCodeOrDescription(PriorityCode)
			If PriorityId '= "" {
				&Sql(
					UPDATE SQLUser.OE_OrdItem
					   SET OEORI_Priority_DR = :PriorityId
					 WHERE OEORI_RowId = :OEOrdItemID
				)
			}
		}
	} Catch(ex) {
		Set tResult = 0
	}
	Quit tResult
}

/// TRC 100944. 20120302. JKam.
/// Este metodo Permite saber si el paciente tiene un procedimiento invasivo instalado sin retirar.
/// Se debe configurar Site Text 2 en Sitio para definir la relación de item de alerta con item de retiro.
/// Return 1 si la atención tiene uno o más procedimientos invasivos creados pero no retirados y 0 en caso contrario.
ClassMethod hasProcedimientoInvasivo(EpisodeID As %String = "") As %Integer
{
	If EpisodeID="" Quit 0
	Set tResult=0
	&sql(
	DECLARE rs1 CURSOR FOR
	SELECT DISTINCT OEORI_ItmMast_DR
	FROM SQLUser.OE_OrdItem
	WHERE OEORI_OEORD_ParRef->OEORD_Adm_DR=:EpisodeID
	AND UPPER(OEORI_ItmMast_DR->ARCIM_Code) %STARTSWITH('IIH')
	)
	&sql(OPEN rs1)
	&sql(FETCH rs1 INTO :arcitmid)
	While 'SQLCODE {
		Set itmCode = ""
		Set nodo = $Get(^ARCIM(+arcitmid,$Piece(arcitmid,"||",2),9))
		If nodo'="" Set itmCode = $Piece(nodo,"^",33) //Site Text 2
		If (itmCode '= "") {
			Set itmMast = ##class(web.ARCItmMast).GetIdFromCodeOrDescription(itmCode)
			Set statusE = ##class(web.OECOrderStatus).GetIdFromCodeOrDescription("E") ; action 18
			If $Get(itmMast)'="" {
				&sql(
				SELECT OEORI_RowId
				FROM SQLUser.OE_OrdItem
				WHERE OEORI_OEORD_ParRef->OEORD_Adm_DR=:EpisodeID
				AND OEORI_ItmMast_DR = :itmMast
				AND OEORI_ItemStat_DR = :statusE
				)
				Set:(SQLCODE=100) tResult=1  
			} else {
				Set tResult=1
			}			
		}		
		&sql(FETCH rs1 INTO :arcitmid)
	}
	&sql(CLOSE rs1)
	Quit tResult
}

/// Este metodo permite obtener el listado de procedimientos invasivos que tiene un paciente en una atención.
/// Se debe configurar Site Text 2 en Sitio para definir la relación de item de alerta con item de retiro.
/// Devuelve una cadena con listado de procedimientos instalados sin retirar, que se alojará en el title del icono.
ClassMethod getProcedimientosInvasivos(EpisodeID As %String = "") As %String
{
	If EpisodeID="" Quit 0
	Set tResult=$C(13)
	&sql(
	DECLARE rs CURSOR FOR
	SELECT DISTINCT OEORI_ItmMast_DR, OEORI_ItmMast_DR->ARCIM_Desc,(CURRENT_DATE-OEORI_SttDat)
	FROM SQLUser.OE_OrdItem
	WHERE OEORI_OEORD_ParRef->OEORD_Adm_DR=:EpisodeID
	AND UPPER(OEORI_ItmMast_DR->ARCIM_Code) %STARTSWITH('IIH')
	)
	&sql(OPEN rs)
	&sql(FETCH rs INTO :arcitmid, :Description, :Days)
	While 'SQLCODE {
		; B.R.: No mostrar el icono si la atención tiene un procedimiento retirado.
		Set itmCode = ""
		Set nodo = $Get(^ARCIM(+arcitmid,$Piece(arcitmid,"||",2),9))
		If nodo'="" Set itmCode = $Piece(nodo,"^",33) //Site Text 2
		If (itmCode '= "") {
			Set itmMast   = ##class(web.ARCItmMast).GetIdFromCodeOrDescription(itmCode)
			If $Get(itmMast)'="" {
				&sql(
				SELECT OEORI_RowId
				FROM SQLUser.OE_OrdItem
				WHERE OEORI_OEORD_ParRef->OEORD_Adm_DR=:EpisodeID
				AND OEORI_ItmMast_DR = :itmMast
				)
				If 'SQLCODE Set Description=""
			} else {
				Set Description="Retiro no vinculado. Favor revisar campo Site Text2 de Alerta."
				Set Days="Error"
			}
		}
		If (Description'="") Set tResult=tResult_Description_" ("_Days_")"_$C(13)
		&sql(FETCH rs INTO :arcitmid, :Description, :Days)
	}
	&sql(CLOSE rs)
	Quit tResult
}

///  End TRC 100944.
/// Permite crear un item de orden a partir de una atención.
ClassMethod AddItem(EpisodeID As %String = "", CareProvDesc As %String = "", ARCIMID As %String = "", %session As %CSP.Session) As %String
{
	If (EpisodeID="")!(ARCIMID="") Quit 0
	// Order Item Restriction Validation
	Set ordcat=""
    Set ordsubcat=""
    Set ordsubcat=$p($g(^ARCIM(+ARCIMID,1,1)),"^",10)
    Set ordsubcat=+ordsubcat
    Set ordcat=$p($g(^ARC("IC",ordsubcat)),"^",8)
    Set ordcat=+ordcat
    Set ret=0
    i (##Class(web.OEOrdItem).GroupSecForOrdItem($g(%session.Data("LOGON.GROUPID")),ordcat,ordsubcat,ARCIMID)) Set ret=1
	// Todo Make validation before save
	Set prioryDesc = "Normal"
	Set statusDesc = "Solicitado"
	Set today      = +$h
	Set now        = $p($h,",",2)
	Set qty        = "1"
	Set userID     = %session.Get("LOGON.USERID")
	Set WhoGoWhere = "P"
	Set Doctor     = ##class(web.CTCareProv).GetIdFromCodeOrDescription(CareProvDesc)
	If (Doctor = "") Set Doctor = 88 ; default doctor is Medico Test Test
	Set reclocDesc = ""
	Set reclocID   = $$recloc^COEOrdItem14(ARCIMID,EpisodeID,now,"","","")
	If $Data(^CTLOC(reclocID)) Set reclocDesc = $Piece(^CTLOC(reclocID),"^",2)
	Set wildcard   = "" ; used for unnecesary fields
	Do OIINsert^COEOrdItem(EpisodeID,wildcard,prioryDesc,reclocDesc,today,now,wildcard,qty,
	wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,
	wildcard,wildcard,ARCIMID,wildcard,wildcard,today,now,wildcard,wildcard,wildcard,WhoGoWhere,
	wildcard,Doctor,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,
	wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,
	wildcard,wildcard,userID,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,
	wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,
	wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,
	wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,
	wildcard,wildcard,statusDesc,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,
	wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,
	wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,
	wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,
	wildcard,wildcard,wildcard,wildcard,%session.SessionId,wildcard,wildcard,wildcard,wildcard,
	wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard,wildcard)
	Quit 1
}

/// Devuelve el estado actual del Item de Orden
/// TRC 106325 by MAguirre
ClassMethod GetCurrentStatus(ordItemId As %String) As %String
{
	Set tResult = ""
	
	If ordItemId '= "" {
		Set ordItemData = $Get(^OEORD(+ordItemId,"I", $Piece(ordItemId, "||", 2), 1))
		If ordItemData '= "" {
			Set ostatId = $Piece(ordItemData, "^", 13)
			Set:ostatId tResult = $Piece($Get(^OEC("OSTAT", ostatId)), "^", 1)
		}
	}
	
	Quit tResult
}

/// Devuelve las notas de procesamiento del Item de Orden
/// TRC 122081. 20120905. JKam.
ClassMethod GetNotes(ordItemId As %String) As %String
{
	Set tResult = ""
	
	If ordItemId '= "" {
		Set ordItemRemId = $Order(^OEORD(+ordItemId,"I", $Piece(ordItemId, "||", 2), "REM", 0))
		If ordItemRemId '= "" {
			Set tResult = ^OEORD(+ordItemId,"I", $Piece(ordItemId, "||", 2), "REM", ordItemRemId)
		}
	}
	
	Quit tResult
}

ClassMethod ShowReportRecetaExterna4(OEOrdItemIDs As %String, HospId As %String, GroupDesc As %String, pEpisodeID As %String = "") As %String
{
	
	Set Ret = 1

	/// rule 1
	/// si el hospital de logon NO es HSJD muestra el reporte
	If ($g(HospId)="")||(HospId'=2){
		Quit Ret
	}
	
	/// rule 3
	/// NO muestra reporte si el episodio es Hospitalizado
	If $Get(OEOrdItemIDs)'="" {
		Set OEOrder=$Piece($Piece(OEOrdItemIDs,"*",2),"||",1),AdmType=""
		&SQL(select OEORD_Adm_DR->PAADM_Type into :AdmType from SQLUser.OE_Order where OEORD_RowId = :OEOrder)
		If AdmType'="O" {
			Set Ret=0 
			Quit Ret
		}
	}
	
	/// rule 4
	/// muestra reporte con algunos grupos de seguridad 
	If ($g(GroupDesc)="") || ((GroupDesc'="HSJD SSMOC Medico Ambulatorio")&&(GroupDesc'="HSJD SSMOC MEDICO GINECO-OBSTETRA AMB")){
		Quit Ret
	}
	
	/// rule 2
	/// si la subcategoria de item es Microbiológicos muestra el reporte
	Set Ret = 0
	Quit:($g(OEOrdItemIDs)="") Ret
	For i=1:1:$Length(OEOrdItemIDs,"*") {
		Set OEORIRowId = $p(OEOrdItemIDs,"*",i)
		Quit:((+OEORIRowId)=0)
		&SQL(select OEORI_ItmMast_DR->ARCIM_ItemCat_DR->ARCIC_Code into :ARCICCode from SQLUser.OE_OrdItem where OEORI_RowId = :OEORIRowId)
		If (SQLCODE=0),(ARCICCode="0306000"){
			Set Ret = 1
			Quit 
		}
	}

	Quit Ret
}

/**
 * TRC      : 151303
 * Date     : 2013-12-05
 * Author   : MAguirre
 * Comments : Defines the new Expiry Dates to Orders including repeats. The formula describes how to calculate
 *            the new Expiry Date based on two values, the Duration (Factor) of the order item and number of repeats (NRepeats)
 *            So the new expiry date is calculated using the following formula:
 *
 *            Factor <= 30 => ExpiryDate = PrescriptionDate + ( 30 * NRepeats + 1 )
 *            Factor >  30 => ExpiryDate = PrescriptionDate + ( Factor * NRepeats + 1 )
 **/
ClassMethod CheckOrdItemExpiryDate(orders, overwrite As %String = 0) As %String
{
	New tReturn
    Set ClassName = $classname($this)
    Set ClassMethod = ##expression(""""_$get(%methodname)_"""")
    Set tReturn = ""
    Try {
        For i=1:1:$l(orders,"^") {
            Set OrdId = $p(orders,"^",i)
            If ('OrdId) Quit
            Set tOEORIData = $Get(^OEORD(+OrdId,"I",$Piece(OrdId,"||",2),12))
            Set tOEORIItmMastDR = $Piece($Get(^OEORD(+OrdId, "I", $Piece(OrdId, "||", 2), 1)), "^", 2)
            Set tARCICOrderType = ""
            Set tORCATPrescrExpDays = ""
            Set tARCICPrescrExpDays = ""
            &SQL(
                SELECT ARCIM_ItemCat_DR->ARCIC_OrderType, 
                	ARCIM_ItemCat_DR->ARCIC_OrdCat_DR->ORCAT_PrescrExpDays,
                	ARCIM_ItemCat_DR->ARCIC_PrescrExpDays
                  INTO :tARCICOrderType, :tORCATPrescrExpDays, :tARCICPrescrExpDays
                  FROM SQLUser.ARC_ItmMast
                 WHERE ARCIM_RowID = :tOEORIItmMastDR
            )
            Quit:(" R I "'[tARCICOrderType)
            Set tOEORIDate = $Piece($Get(^OEORD(+OrdId,"I",$Piece(OrdId,"||",2),3)),"^",7)
            Set tExpiryDaysBase = 30

            Set tOEORIPrescRepExpiryDate = $Piece(tOEORIData, "^", 32)
            Set tOEORIMaxRepeats = +$Piece(tOEORIData, "^", 34)
            Set:(tOEORIMaxRepeats="") tOEORIMaxRepeats = 0
            Set tOEORIDuratDR = $Piece($Get(^OEORD(+OrdId,"I",$Piece(OrdId,"||",2),2)),"^",6)
            Set:(tOEORIDuratDR'="") tPHCDUFactor = $Piece($Get(^PHCDU(tOEORIDuratDR)),"^",2)
            Set:($Get(tPHCDUFactor)="") tPHCDUFactor = 0
        
        	If tOEORIMaxRepeats {
	            If (tPHCDUFactor > 30) {
	                Set tOEORIMaxRepeats = tPHCDUFactor * (tOEORIMaxRepeats + 1)
	            } Else {
	                Set tOEORIMaxRepeats = tExpiryDaysBase * (tOEORIMaxRepeats + 1)
	            }
        	}else{
	        	If tARCICPrescrExpDays {
		        	Set tOEORIMaxRepeats = tARCICPrescrExpDays
	        	}else{
	        		Set tOEORIMaxRepeats = tORCATPrescrExpDays
	        	}
        	}
			// 2014-07-14	DZ	TRC:178741	CCR:CLXX5953,SDSR3234
			//		- Update ExpiryDate every time the field MaxRpts is changed
            If ((overwrite) || (tOEORIPrescRepExpiryDate = "") || (tOEORIPrescRepExpiryDate '= (tOEORIDate + tOEORIMaxRepeats))) {
                Set tOEORIPrescRepExpiryDate = (tOEORIDate + tOEORIMaxRepeats)
                &SQL(
                    UPDATE %NOTRIGGER SQLUser.OE_OrdItem
                       SET OEORI_PrescRepExpiryDate = :tOEORIPrescRepExpiryDate
                     WHERE OEORI_RowID = :OrdId
                )
            }
        }
    } Catch (tException) {
        Set tErrText = ##class(Custom.HMS.Misc.Utilities.General).GetFmtErrText(tException.AsStatus())
        Set ^TEMP("ERROR-log", ClassMethod_"^"_ClassName, $zDate($h,4), $zTime($h)) = tErrText
        Set tReturn = "ERROR ("_ClassMethod_"^"_ClassName_") : "_tErrText
    }
    Quit tReturn
}

/**
 * END TRC  : 151303
 **/

/**
 * TRC		: 174646
 * Author	: MAguirre
 * Date		: 2014.04.28
 * Comments	: Returns the Expiry Date stored using the specified id
 */
ClassMethod GetPrescRepExpiryDate(pOEORIRowId) As %String
{
	Set tResult = ""
	If ((pOEORIRowId '= "")) {
		Set tOEORIData = $Get(^OEORD(+pOEORIRowId, "I", $Piece(pOEORIRowId, "||", 2), 12))
		Set tOEORIPrescRepExpiryDate = $Piece(tOEORIData, "^", 32)
		Set tResult = $zDate(tOEORIPrescRepExpiryDate, 4)
	}
	Quit tResult
}

/**
 * END TRC	: 174646
 */

/**
 * TRC		: 161105
 * Date		: 2014-02-21
 * Author	: MAguirre
 * Comments	: Implements the function that enable or disable the TCEIINTER icon
 *	2015-10-14	Victor Skrobot	JIRA	TC-54904
 *	Tooltip with Alias 
 */
ClassMethod GetTCEINTERIconStatus(pEpisodeID As %String, title) As %String
{
	Set tResult = 0
	
	Try {
		If (pEpisodeID '= "") {

			&SQL(DECLARE arcim cursor for
			SELECT OEORI_ItmMast_DR, OEORI_ItmMast_DR->ARCIM_Desc
			  FROM SQLUser.OE_OrdItem
			 WHERE OEORI_OEORD_ParRef->OEORD_Adm_DR = :pEpisodeID
			   AND OEORI_Categ_DR->ORCAT_Code = 'TCEINTER'
			   AND OEORI_ItemStat_DR->OSTAT_Code != 'E')
			&SQL(OPEN arcim)
			&SQL(FETCH arcim into :tARCIM, :tARCIMDesc)
			While ('SQLCODE) {
	   			Set tResult = 1

	   			/*Set tAlias = $Order(^ARC("ALIAS",0,"ARCIM",tARCIM,""))
	   			While tAlias {
		   			Set tDateTo = $Piece(^ARC("ALIAS",tAlias),"^",13)
		   			If (tDateTo="")!(+tDateTo>+$h) {
		   				Set tDesc = $Piece(^ARC("ALIAS",tAlias),"^",3)
		   				Set title = $g(title)_$c(13,10)_tDesc
		   			}
		   			Set tAlias = $Order(^ARC("ALIAS",0,"ARCIM",tARCIM,tAlias))
	   			}*/
	   			Set title = title_$c(13,10)_tARCIMDesc

				&SQL(FETCH arcim into :tARCIM, :tARCIMDesc)
			}
			&SQL(CLOSE arcim)
		}
	} Catch(tException) {
	}
	
	Quit tResult
}

/**
 * END TRC	: 161105
 **/
/// ////////////////////////////////////////////////////////////////
/// 2013-12-13	Victor Skrobot	TRC	165947	CCR		
/// Show links to New Order by SourceReferralQualified
ClassMethod GetLinkSRQ(pPatientID As %String, pEpisodeID As %String = "") As %String
{
	Set tResult = ""
	Set tMRAdm = ##class(web.PAAdm).GetMRAdm(pEpisodeID)
	Set TWKFL=##Class(websys.WorkFlow).GetIdFromCodeOrDescription("TCE.Trak.Popup Order Entry")
    Set tURL="websys.csp?&TWKFL="_TWKFL_"&PatientBanner=1&mradm="_tMRAdm
        
	Set tSQL = "select distinct by (WL_SourceRefQualif_DR) WL_SourceRefQualif_DR->SRQ_Desc, WL_SourceRefQualif_DR->SRQ_Code, WL_SourceRefQualif_DR from SQLUser.PA_WaitingList where WL_PAPMI_DR = ? and not WL_SourceRefQualif_DR->SRQ_Code is null"
	Set tRs = ##class(%ResultSet).%New()
	Do tRs.Prepare(tSQL)
	Do tRs.Execute(pPatientID)
	While tRs.Next() {
	    ; Encrypt URL
	    
	    Set eprcomponentCONTEXT = "W"_TWKFL_"RTT"_tRs.GetData(2)
	    Set tTmp="&PatientID="_pPatientID_"&EpisodeID="_pEpisodeID_"&XCONTEXT="_eprcomponentCONTEXT

	    i tURL'="" s tURL=##Class(websys.Page).URLSet(tURL_tTmp)
		Set tOnClick = "NewClick('"_tURL_"','0')"
		Set tLnk = "<A class=""chartitemheading2"" HREF=""#"" onclick="""_tOnClick_"; websys_cancel(); return false;""><IMG class=""clsChartItemHeadingLinkIcon"" SRC=""../images/websys/action_add.png"" BORDER=0>"_tRs.GetData(1)_"</A>"
		
		Set tResult = tResult_tLnk
	}
	
	Quit tResult
}

/// 2013-12-16	Victor Skrobot	TRC	165947	CCR		
/// Show row only if the ARCIM is in some one Order Preferences "RTT"
ClassMethod LRFSRQ(pRs) As %String
{
	Set tResult = 0
	
	// removed temporary - was did by order favourites 
	Set tSQL = "select Data,ID from websys.Preferences where AppSubKey = 'OEOrder.PrefTabs.EditList' and AppKeyContext [ 'RTT'"
	Set tRs = ##class(%ResultSet).%New()
	Do tRs.Prepare(tSQL)
	Do tRs.Execute()

	s row = 0
	While tRs.Next() {
		
		s row=row+1
		Set tData = tRs.GetData(1)

		For tI=1:1:$listlength($lg(tData,3)) {
			Set tDataFav = $lg($lg(tData,3),tI)
			;Set tItemsFav = $Piece(tDataFav,"^",3)
			For tJ=2:1:$length(tDataFav,$c(1)) {
				Set tDataFavItm = $Piece(tDataFav,$c(1),tJ)
				For tK=2:1:$length(tDataFavItm,$c(28)) {
					Set tARCIM = $Piece($Piece(tDataFavItm,$c(28),tK),$c(4),2)
					If tARCIM = pRs.GetDataByName("OEItemMstID") Set tResult = 1
				}
			}
		}
		
	}
	
	///	new version - did by custom data with GES
	If pRs.GetDataByName("ID")'="" {
		Set tSQL = "select COEORI_GESInfo, COEORI_GESSRQ from Custom_HMS_Misc_User.OEOrdItem where COEORI_OEORI_DR = ?"
		Set tRs = ##class(%ResultSet).%New()
		Do tRs.Prepare(tSQL)
		Do tRs.Execute(pRs.GetDataByName("ID"))
		If tRs.Next() {
			If (tRs.GetData(1)'="")!(tRs.GetData(2)'="") Set tResult = 1
		}
	}

	Quit tResult
}

/// ///////////////////////////////////////////////////////
/// 2013-12-29	Victor Skrobot	TRC	166790	CCR	CLXX3536
ClassMethod GetDrawOrderPrefTabItems(tUser, tGroup, tSite, tRegion, tContext, tItem) As %String
{
	
	Do ##Class(epr.PreferencesQuery).GetOEPrefDelims(.itemdataDelim,.groupitemDelim,.tabgroupDelim)
	Set tParam=##Class(websys.Preferences).GetDataExPlus(tUser,tGroup,tSite,"",tContext,.app,"ORDER","OEOrder.PrefTabs.EditList",.activeCONTEXT,"",tRegion)
	Set tTitle = $Piece($lg($lg(tParam,3),tItem),tabgroupDelim,1)
	
	Quit tTitle
}

/// ///////////////////////////////////////////////////////
/// 	2014-01-02	Victor Skrobot	TRC	166793	CCR
/// update OEORIComment3 field as GESInfo from favourites
ClassMethod updGESInfo(pOEOrdItemIDs, pFavouriteText) As %String
{
	New (pOEOrdItemIDs,pFavouriteText)
	
	For tCount=1:1:$Length(pOEOrdItemIDs,"^")-1 {
		Set tOEOrdItemID=$Piece($Piece(pOEOrdItemIDs,"^",tCount),"*",2)
		Set tObjOEORI = ##class(User.OEOrdItem).%OpenId(tOEOrdItemID)
		If tObjOEORI'="" {
			Set tFavouriteText = $Piece(pFavouriteText,";",1)
			Set tFavouriteCode = $Piece(pFavouriteText,";",2)
			Set tObjOEORI.OEORIComment3 = pFavouriteText
			Do tObjOEORI.%Save()
		}
	}
	
	Quit ""
}

ClassMethod ExecuteItemsWithTCEDIQuestionnaire(pOEOrdItemIDs As %String) As %String
{
	Quit:pOEOrdItemIDs=""
		
	For tCount=1:1:$Length(pOEOrdItemIDs,"^")-1 {
		Set tOEOrdItemID=$Piece($Piece(pOEOrdItemIDs,"^",tCount),"*",2)
		#Dim tObjOEORI As User.OEOrdItem
		Set tObjOEORI = ##class(User.OEOrdItem).%OpenId(tOEOrdItemID)
		Set tWINRowId = ##class(Custom.HMS.Misc.web.SSUserDefWindow).GetIdFromCode("TCEDI")
		If (tObjOEORI.OEORIQuestionnaire [ tWINRowId) {
			Set tQuestID = $Piece(tObjOEORI.OEORIQuestionnaire, "||", 2)
			Set tObjQuest = ##class(questionnaire.QTCEDI).%OpenId(tQuestID)
			If (($IsObject(tObjQuest)) && (tObjQuest.Q02)) {
				Do ##class(Custom.HMS.Misc.questionnaire.QTCEDI).ExecuteItem(tOEOrdItemID)
			}
		}
	}
}

ClassMethod GetMenuByChartBookGroup(pGroupID) As %String
{
	
	Set tResult = ""
	
	Set tChartBook = ##class(epr.GroupSettings).GetMainChartBook(pGroupID)
	If 'tChartBook Quit ""
	
	Set tMainMenu = ##class(epr.GroupSettings).GetMainMenu(pGroupID)
	If 'tMainMenu Quit ""
	
	Set tRs = ##class(%ResultSet).%New()
	Do tRs.Prepare("select ID from websys.Menu where ChartBook = ? and SubMenuOf = ? ")
	Do tRs.Execute(tChartBook,tMainMenu)
	If tRs.Next() {
		Set tResult = tRs.GetData(1)
	}
	
	Quit tResult
}

ClassMethod GetOthSRQ(pPatientID) As %String
{
	Set tResult = ""
	Set tSQL = "select distinct by (WL_SourceRefQualif_DR) WL_SourceRefQualif_DR->SRQ_Desc, WL_SourceRefQualif_DR->SRQ_Code, WL_SourceRefQualif_DR from SQLUser.PA_WaitingList where WL_PAPMI_DR = ? and not WL_WaitListPrior_DR is null and not WL_Date is null and not WL_SourceRefQualif_DR->SRQ_Code is null"
	Set tRs = ##class(%ResultSet).%New()
	Do tRs.Prepare(tSQL)
	Do tRs.Execute(pPatientID)
	
	While tRs.Next() {
		Set tResult = tResult_tRs.GetData(1)_"*"_tRs.GetData(2)_"^"
	}
	If tResult'="" Set tResult = "Ingresar Indicaciones*^"_tResult 
	
	Quit tResult
}

ClassMethod UpdateListRowHandler(pID, pFields, pValues) As %String
{
	Set tResult = "", tFields = "", tValues = ""
	
	For tI=1:1:$Length(pFields,"^")-1 {
		Set tFields = tFields_$s(tFields'="":",",1:"")_$Piece(pFields,"^",tI)
	}
	For tI=1:1:$Length(pValues,"^")-1 {
		//Set tValues = tValues_$s(tValues'="":",",1:"")_$S($Piece(pValues,"^",tI)'="":"'"_$Piece(pValues,"^",tI)_"'",1:"NULL")
		Set tValues = tValues_$s(tValues'="":",",1:"")_"'"_$Piece(pValues,"^",tI)_"'"
	}
	
	Set tSQL = "update SQLUser.OE_OrdItem ("
	Set tSQL = tSQL_tFields_") values ("
	Set tSQL = tSQL_tValues_") where OEORI_RowID = '"_pID_"'"
	
	Set tRs = ##class(%ResultSet).%New()
	Do tRs.Prepare(tSQL)
	Do tRs.Execute()
	
	Quit tResult
}

ClassMethod UpdSessionData(pParam) As %String
{
	Set tResult =""
	
	For tI=1:1:$Length(pParam,"^") {
		If $Piece(pParam,"^",tI)'="" Set %session.Data($Piece($Piece(pParam,"^",tI),"*",1))=$Piece($Piece(pParam,"^",tI),"*",2)
	}
	Quit tResult
}

/// 	2014-06-20	Victor Skrobot
/// 	update OEORIPhQtyOrd (with status Inactive) 
/// 	if sum OEORE_PhQtyOrd is wrong after update on OEOrder.Med
ClassMethod UpdPhQtyOrdByOEOrdExec(pID) As %String
{
	Set tResult = 0
	Set tSQL = "SELECT	sum(OEORE_PhQtyOrd) "_
				"FROM SQLUser.OE_OrdExec "_
				"WHERE OEORE_OEORI_ParRef = '"_pID_"'"
	Set tRs = ##class(%ResultSet).%New()
	Do tRs.Prepare(tSQL)
	Do tRs.Execute()
	If tRs.Next() {
		Set tOBJ = ##class(User.OEOrdItem).%OpenId(pID)
		If $IsObject(tOBJ) {
			If tOBJ.OEORIItemStatDR.OSTATCode="I",tOBJ.OEORIPhQtyOrd '= tRs.GetData(1),tOBJ.OEORICalcQtyFlag'="N" {
				If ('$IsObject(tOBJ.OEORIOEORIDR))!(tOBJ.OEORIOEORIDR.OEORIIVType'="C" ) {
					Set tOBJ.OEORIPhQtyOrd = tRs.GetData(1)
					Do tOBJ.%Save()
					Set tResult =  tRs.GetData(1)
				}
			}
		}
	}
	Quit tResult
}

/// 	2014-11-15	Victor Skrobot
ClassMethod ClearInactive(pEpisodeID) As %String
{
	Set adm=pEpisodeID
	Set tToday=+$h,tNow=$Piece($h,",",2)
	/// copied (and fixed) from inactive^COEOrdItem13
	s in=$o(^OEC("OSTAT",0,"Code","I",""))
	s ord=$o(^OEORD(0,"Adm",+adm,""))
	s pat=$p($g(^PAADM(+adm)),"^")
	q:'ord
	s itm=0 f  s itm=$o(^OEORD(ord,"I",itm)) q:itm=""  d
	.s st=$p($g(^OEORD(ord,"I",itm,1)),"^",13) q:st-in
	.s arcim=$p($g(^OEORD(ord,"I",itm,1)),"^",2)
	.s stdate=$p($g(^OEORD(ord,"I",itm,1)),"^",9)
	.s sttime=$p($g(^OEORD(ord,"I",itm,1)),"^",10)
	.If stdate=tToday,sttime>(tToday-3600) q
	.s row=ord_"||"_itm
	.s ManufactureID=""
	.s ManufactureID=$p($g(^OEORD(+row,"I",$p(row,"||",2),11)),"^",68)
	.s labts=$p($g(^OEORD(ord,"I",itm,3)),"^",35)
	.i $d(^DeleteOrdItmID("debug")) s ^DeleteOrdItmID($zn,"inactive:"_row)=""
	.&SQL(DELETE %NOCHECK FROM SQLUser.OE_OrdItem WHERE OEORI_RowId = :row)
	.i $g(ManufactureID)'="" &SQL(DELETE %NOCHECK FROM SQLUser.IN_Manufacture_Order WHERE INMAN_RowId = :ManufactureID)
	.q:labts=""
	.s labepis=$p(labts,"||"),ts=$p(labts,"||",2),seq=$p(labts,"||",3)
	.k ^TEPIi("MEDTRAK",+pat,+stdate,+sttime,+adm,row)
	.q:labepis=""  q:ts=""  q:seq=""
	.k ^TEPIi("MEDTRAKi",labepis,ts,seq)
	s que="" f  s que=$o(^PAQUE1(0,"QUE1_PAADM_DR",adm,que)) q:que=""  d
	.q:'$d(^PAQUE1(que))  s s=^(que)
    .i $Get(presno)'="",$d(^OEORD(0,"PrescNo",presno)) q
	.&SQL(DELETE %NOCHECK FROM SQLUser.PA_Que1
	WHERE QUE1_RowId = :que)
	q
}

/// 	2015-01-15	Victor Skrobot	TRC	
/// 	
ClassMethod LookUpItemPrescExecute(ByRef QHandle As %Library.Binary, pPrescNo As %String, pText As %String) As %Library.Status
{
	New repid,ind,papmi,dt,stop,zsess,str

	Set repid=$I(^CacheTemp("TRAK"))
	
	If pPrescNo="" Quit $$$OK
	
	Set tPars=0
	Set strSQL = "select "_
	"OEORI_ItmMast_DR->ARCIM_Code, OEORI_ItmMast_DR->ARCIM_Desc, OEORI_MaxRepeats, OEORI_CurrRepeatNumber, OEORI_ItmMast_DR, OEORI_RowID "_
	"from SQLUser.OE_OrdItem where OEORI_PrescNo = ? and OEORI_ItmMast_DR->ARCIM_Desc %STARTSWITH ? and "_
	"not OEORI_ItemStat_DR in (4,6) "
			
	Set tRs = ##class(%Library.ResultSet).%New()
	
	If ('$IsObject(tRs)) Quit $$$OK
	
	Do tRs.Prepare(strSQL)
	
	Set tSc = tRs.Execute(pPrescNo, pText)
    
	If $System.Status.IsOK(tSc)
	{
		
		While tRs.Next() 
		{			
		
			///	only show pharmacy items "Accepted"	
			Set PharmStatus = $$pharmst^COEOrdItem6(tRs.GetData(6))
			If ((PharmStatus["P")!(PharmStatus["A")!(PharmStatus["M")!(PharmStatus["C")!(PharmStatus["O")) {
				
				set tID	= tRs.GetData(4)
				set tDesc	= tRs.GetData(1)_" - "_tRs.GetData(2)_" - "_$S(tRs.GetData(3)'="":tRs.GetData(4)_"/"_tRs.GetData(3),1:"")
				set tCode	= tRs.GetData(1)
				
				s ^CacheTemp("TRAK",repid,$i(ind))=$lb(tDesc,tID,tCode)
				
			}
		}
		
		do tRs.Close()
	}

	// Build QHandle (AtEnd,ReportID,Index)
	Set QHandle=$lb(0,repid,0)
	Quit $$$OK
}

ClassMethod LookUpItemPrescFetch(ByRef QHandle As %Library.Binary, ByRef Row As %Library.List, ByRef AtEnd As %Library.Integer = 0) As %Library.Status
{
	// This fetch method should never have to change. 

	// repid - Report ID
	// ind - sequence index which represents each row
	
	New repid,ind

	// Restore QHandle
	Set AtEnd=$li(QHandle,1)
	Set repid=$li(QHandle,2)
	Set ind=$li(QHandle,3)

	Set ind=$o(^CacheTemp("TRAK",repid,ind))
	If ind="" {				// if there are no more rows, finish fetching
		Set AtEnd=1
		Set Row=""
	}
	Else {					// fetch row
		Set Row=^CacheTemp("TRAK",repid,ind)
	}
	

	// Save QHandle
	s QHandle=$lb(AtEnd,repid,ind)
	Quit $$$OK
}

ClassMethod LookUpItemPrescClose(QHandle As %Library.Binary) As %Library.Status
{
	New repid
	Set repid=$li(QHandle,2)

	Kill ^CacheTemp("TRAK",repid)

	Quit $$$OK
}

Query LookUpItemPresc(pPrescNo As %String, pText As %String) As %Library.SQLQuery(CONTAINID = 0, ROWSPEC = "Description:%String,HIDDEN:%String,Code:%String")
{
}

ClassMethod MaxNoRepeatsExceeded(OrderIDs As %String = "", MaxRpts) As %String
{
	n (OrderIDs,MaxRpts)
	 s Result=0
	 q:MaxRpts=""
	 f i=1:1:$l(OrderIDs,"^")-1  d
	 . s (OEOrdItemID,ord,itm)=""
	 . s OEOrdItemID=$p(OrderIDs,"^",i),ord=+OEOrdItemID,itm=$p(OEOrdItemID,"||",2)
	 . q:'ord
	 . q:'itm
	 . q:'$d(^OEORD(ord,"I",itm))
	 . s (oi1,df,dfMaxRpt)=""
	 . s oi1=$g(^OEORD(ord,"I",itm,1))
	 . s arcim=$p(oi1,"^",2)
	 . i arcim'="" s df=$p($g(^ARCIM(+arcim,1,1)),"^",12)
	 . i df'="" s dfMaxRpt=$p($g(^PHCD(+df,"DF",$p(df,"||",2),3)),"^",5)
	 . i (MaxRpts>dfMaxRpt)&&(dfMaxRpt) s Result=dfMaxRpt
	 . i Result q
		 
	 q Result
}

ClassMethod GetOrdItemDesc(pOEOrdItemIDs As %String) As %String [ ProcedureBlock = 1 ]
{
	Set tItemDesc = ""
	If $Get(pOEOrdItemIDs)
	{
		For tItemCount = 1:1:$Length(pOEOrdItemIDs, "^")
		{
			Set tItemId = $Piece(pOEOrdItemIDs, "^", tItemCount)
			If (tItemId = "") Quit
			Set oItem = ##class(User.OEOrdItem).%OpenId(tItemId)
			If $IsObject(oItem)
			{
				Set tItemDesc = oItem.OEORIItmMastDR.ARCIMDesc
				If (tItemDesc '= "") Quit
			}
		}
	}
	Quit tItemDesc
}

/// 2015-06-18	DZ	CCR:CLXX9368	TRC:194628	JIRA:TC-46063
/// 	- Add Order Item for OT
ClassMethod AddItemForOT(pOperRoomId As %String, pCareProvId As %String = "", pUserId As %String = "") As %Status [ ProcedureBlock = 1 ]
{
	Set tSC = $$$OK
	If ($Get(pOperRoomId) '= "")
	{
		Set oOpRoom = ##class(User.RBOperatingRoom).%OpenId(pOperRoomId, 0, .tSC)
		// RBOPStatus = B -  Booked 
		If $IsObject(oOpRoom), $IsObject(oOpRoom.RBOPAppointDR), (oOpRoom.RBOPStatus = "B"), $IsObject(oOpRoom.RBOPOperationDR)
		{
			Set tApptId = oOpRoom.RBOPAppointDR.%Id()
			Set oAppt = ##class(User.RBAppointment).%OpenId(tApptId, ,.tSC)
			If $IsObject(oAppt), $IsObject(oAppt.APPTAdmDR), ((oAppt.APPTStatus = "I") || (oAppt.APPTStatus = "P")), $IsObject(oAppt.APPTRBOPDR), (oAppt.APPTOEORIDR = "")
			{
				#dim oOper As User.ORCOperation
				Set oOper = oOpRoom.RBOPOperationDR
				If $IsObject(oOper.OPERARCIMDR)
				{
					Set tApptSchedId	= oAppt.APPTASParRef.%Id()
					// User.RBResource - RESCTLOCDR - Resource Location
					Set tRecLocId		= $Piece($Get(^RB("RES", +tApptSchedId)), "^", 1)
					Set tArcimId		= oOper.OPERARCIMDR.%Id()
					Set tEpisodeId		= oAppt.APPTAdmDR.%Id()
					Set tApptDate		= oAppt.APPTASParRef.ASDate
					Set tApptTime		= oAppt.APPTASParRef.ASSessStartTime
					//Set tComments		= oAppt.APPTRemarks
					
					If (pUserId = "")
					{
						If $Data(%session) Set pUserId = $Get(%session.Data("LOGON.USERID"))
						If (pUserId = ""), $IsObject(oAppt.APPTBookedByDR) Set pUserId = oAppt.APPTBookedByDR.%Id()
					}
					Set tSC = ..AddOneOrderForAppt(.oAppt, tArcimId, tEpisodeId, tRecLocId, tApptId, tApptDate, tApptTime, 1, pCareProvId, pUserId, "", 0)
				}
				Kill oOper
			}
			Kill oAppt
		}
		Kill oOpRoom
	}
	Quit tSC
}

/// 2015-06-18	DZ	CCR:CLXX9368	TRC:194628	JIRA:TC-46063
/// 	- Add Order Item for Appointment
ClassMethod AddOneOrderForAppt(oAppt As User.RBAppointment, pArcimId As %String, pEpisodeId As %String, pRecLocId As %String, pApptId As %String, pDate As %Date, pTime As %Time, pQty As %String, pCareProvId As %String, pUserId As %String, pComments As %String = "", pForceHL7Creation As %Boolean = 0) As %String [ ProcedureBlock = 0 ]
{
	New (%request, %session, oAppt, pArcimId, pEpisodeId, pRecLocId, pApptId, pDate, pTime, pQty, pCareProvId, pUserId, pComments, pForceHL7Creation)
	
	Set tSC = $$$OK
	Set (tPriority, tItemStat, tRecLocDesc, tSttDat, tSttTim, tItemGroup, tDepProcNotes, tOrderSet, tLabEpisodeNo, tLab1, tLab2, tDoseQty, tUnit, tFreq, tInstr, tDurat, tMaxNumberOfRepeats,tItemMast, tLabSpecimen, tnewappt, tSttDat1, tSttTim1, tApptCP, tCPSpec, tViews, tActivity) = ""
	
	// User.OECOrderStatus - S = "Booked"
	Set tStat = $Order(^OEC("OSTAT",0,"Code","S","")), tItemStat=$p(^OEC("OSTAT", tStat),"^",2)
	Set tFrequencyId = $Piece($Get(^ARCIM(+pArcimId, 1, 8)),"^",17)
	Set tDurationId = $Piece($Get(^ARCIM(+pArcimId, 1 ,8)),"^",16)
	
	If (pRecLocId '= "") Set tRecLocDesc = $Piece($Get(^CTLOC(pRecLocId)),"^",2)
	
	Set tSttDat = pDate
	Set tSttTim = pTime
	
	Do OIINsert^COEOrdItem(pEpisodeId, tPriority, tItemStat, tRecLocDesc, tSttDat, tSttTim, tItemGroup, pQty, pComments, tDepProcNotes, tOrderSet, tLabEpisodeNo, tLab1, tLab2, tDoseQty, tUnit, tFrequencyId, tInstr, tDurationId, tMaxNumberOfRepeats, pArcimId, tLabSpecimen, pApptId, tSttDat, tSttTim, "" /*ConsDep*/, "" /*ConsDoc*/, "" /*ConsCat*/, "" /*ConsWhoGoesWhere*/, "" /*ConsPrice*/, pCareProvId, "" /*RMFreq*/, "" /*RMDurat*/, "" /*BillDesc*/, "" /*BillPrice*/, "" /*MealType*/, "" /*RiceType*/, "" /*Volume*/, "" /*Energy*/, "" /*Protein*/, "" /*Fat*/, "" /*Carbo*/, "" /*DelayMeal*/, "" /*SterUten*/, "" /*PasteurFood*/, "" /*CovByMainInsur*/, "" /*PortEquipReq*/, "" /*AdmAfterSkinTest*/, "" /*ARCIMText*/, "" /*RadNo*/, "" /*Contact*/, "" /*AlertReason*/, pUserId, "" /*Doctors*/, "" /*OrderID*/, "" /*NeedleGauge*/, "" /*NeedleType*/, "" /*BodySite*/, "" /*IVUnit*/, "" /*FlowQty*/, "" /*UnitHrs*/, "" /*IVTime*/, "" /*FlowRateUnit*/, "" /*Interval*/, "" /*Teeth*/, "" /*clinPathwayDR*/, "" /*Linked*/, "" /*VarianceReas*/, "" /*Modifiers*/, "" /*HotReport*/, "" /*CollectDate*/, "" /*CollectTime*/, "" /*LnkDietItm*/, "" /*ReasOrdCMVNegBlood*/, "" /*CompXMatchReq*/, "" /*AutoBlReq*/, "" /*PatCons*/, "" /*NoConsOvrReas*/, "" /*BBTAG1*/, "" /*BBTAG2*/, "" /*BBTAG3*/, "" /*BBTAG4*/, "" /*BBTAG5*/, "" /*SpecSites*/, "" /*EndDate*/, "" /*RefDocCode*/, "" /*AccessNo*/, "" /*DBSpecType*/, "" /*LabVol*/, "" /*ReceivedDate*/, "" /*ReceivedTime*/, "" /*PatLoc*/, "" /*TempStat*/, "" /*TheatDate*/, "" /*ReqTheat*/, "" /*HL7Flag*/, "" /*UnitsColl*/, "" /*IncompReas*/, "" /*IndicateTransfusion*/, "" /*OEORIEndDate*/, "" /*OEORIEndTime*/, "" /*OEORILink*/, "" /*OEORIContOrderAfterDischarge*/, "" /*OEORIRoute*/, "" /*AuthDoctor*/, "" /*COPYID*/, "" /*PrefConMethod*/, "" /*RefDoctorList*/, "" /*NotifyClinician*/, "" /*groupid*/, "" /*refclincode*/, "" /*StartEndMealType*/, "" /*EligibilityStatus*/, "" /*CreateDate*/, "" /*CreateTime*/, "" /*OEORIFreqDelay*/, "" /*PRNIndication*/, "" /*PRNTotNumDoseAllow*/, "" /*PRNMaxDose24hr*/, "" /*RouteAdmin*/, "" /*DayCycle*/, "" /*OEORIQtyPackUOM*/, "" /*LTClinCond*/, "" /*zProsthetics*/, tCPSpec/*Specialty*/, "" /*LabelText*/, tViews /*OEORIView*/, tActivity /*OEORIActivity*/, "" /*OEORIPrescRepExpiryDate*/, "" /*OEORIPrescRepNumberDays*/, "" /*OEORIMaxRepeats*/, "" /*OEORICurrRepeatNumber*/, "" /*OEORIAnnotateDR*/, "" /*OEORIConsult*/, "" /*Session*/, "" /*PhoneOrder*/, "" /*urgent*/, "" /*PreparationTime*/, "" /*NewOrdItemID*/, "" /*DoNotDisp*/, "" /*DefRptLoc*/, "" /*DefRptDur*/, "" /*Altpatloc*/, "" /*CalcQtyFlag2*/, "" /*EnteredUOM*/, "" /*ClinSignf*/, "" /*OEORIText1*/, "" /*OEORIText2*/, "" /*OEORIText3*/, "" /*OEORIText4*/, "" /*OEORIYesNo1*/, "" /*OEORIYesNo2*/, "" /*OEORIYesNo3*/, "" /*OEORIYesNo4*/, "" /*OEORIApprovalDate*/, "" /*OEORIApprovalTime*/, "" /*OEORIApprovedBy*/, "" /*OEORIApprovalNo*/, "" /*OEORIApprovalInd*/, "" /*RequestedDate*/, "" /*RequestedTime*/, "" /*ITM2DoNotSubstitute*/, "" /*ITM2MinDoseQty*/, "" /*ITM2MinPhQtyOrd*/, "" /*IVType*/, "" /*ITM2PHCIVAdminSetDR*/, "" /*ITM2DropsMin*/, "" /*ClinSignfOrd*/, "" /*ITM2LoanRetDate*/, "" /*ITM2LostLoanItem*/, "" /*DrugDelRate*/, "" /*DrugDelUnit*/, "" /*ITM2OverrideQtyBaseUOM*/)
	Do UpdateApptOEOri
	Quit tSC
	
UpdateApptOEOri
	Set appt = oAppt
	Set (PPAPayorID, PPAPlanID) = ""
    // OIINsert creates variable NewOrders containing all order items
    // Copied the loop below from CRBAppointment.mac
    If $Data(%request)
    {
		s PPAPayorID=$g(%request.Data("InsurPayorID",1))
		s PPAPlanID=$g(%request.Data("InsurPlanID",1))
    }
	
	f b1=1:1:$l($g(NewOrders),"^") {
		s order=$p($g(NewOrders),"^",b1)
		s oeitmrow=$p(order,"&",2)
		s OrdItmMastID=$p(order,"&",1)
		i $g(oeitmrow)'="" {
			d setepis^COEOrdItem14("*"_oeitmrow_"*","")
			;d presno^aOET1(Adm) ;EZ 09/08/07 for log 64272 to create prescription no for orders
			i PPAPlanID'="",PPAPayorID'="" {
				/// 2016-05-03	DZ	CCR:CLXX10658	TRC:I57235	JIRA:TC-79357
				/// 	- Fix error on OT booking
				d overridepayplan^CRBAppointment(oeitmrow,PPAPayorID,PPAPlanID,pEpisodeId)
			}
			i $g(newappt)'="",$g(UpdOEConsDoc)'="" {
				s apptcpx="",apptcpx=$p($g(^RB("RES",+newappt)),"^",2)
				i apptcpx'="" &SQL(UPDATE SQLUser.OE_OrdItem SET OEORI_ConsultDr_DR = :apptcpx WHERE OEORI_RowId = :oeitmrow)
			}
			;ez copied next two lines from T68 for log 62851
			d appt.APPTOEORIDRSetObjectId(oeitmrow)
			s save=appt.%Save(0)
			s newApptId=appt.%Id()
			i newApptId'="" d ##Class(web.RBApptCP).AssignMDTsToAppt(newApptId)
			
			If (pForceHL7Creation)
			{
				Set bLabInterface = ##class(Region.CLXX.Integration.Nexus.CS.ConfigRegistry).GetConfigValueFor("Laboratory.Integration.Interface","HL7Outbound",.tSC)
				Quit:$system.Status.IsError(tSC)
				Do Order^HL7OutboundORM(oeitmrow, bLabInterface)
			}
		}
	}
	Quit
}

/// 	2015-09-02	Victor Skrobot		JIRA	TC-40016
/// don't show Linked Items as Linked if it was repeated (its the same ARCItmMast)
ClassMethod LRFRCE(pRs) As %String
{
	Set tResult = 1

	///	check if item linked was repeated	
	If pRs.GetDataByName("LinkedArcimID")=pRs.GetDataByName("OEItemMstID") {
		///	empty fields to does not display
		Set pRs.Data("LinkedToItmID")=""
		Set pRs.Data("LinkedTo")=""
	}
	
	///	TC-153251
	set AdmType = $piece($get(^PAADM(pRs.GetDataByName("OrdItmEpisodeID"))),"^",2)
	Set pRs.Data("OEORIText4") = ##Class(websys.StandardTypeItem).GetDescription("AdmType",AdmType)

	Quit tResult
}

ClassMethod OrderRepeated(COPYID, RptRowID) As %Integer
{
	Set tSC = $$$OK
	/////////////////////////////////////////////////
	/// 2015-08-17	Victor Skrobot	- check CalcQtyFlag with repeat process
	If $Get(COPYID)'="",$Get(RptRowID)'="" {
		Set tORD = +RptRowID	//+COPYID
		Set tITM = $Order(^OEORD(tORD,"I",0))
		///
		Set EpisodeID = +^OEORD(+COPYID)
		Set:'$Get(^TMP("OEOrdRepeatNew",%session.SessionId,EpisodeID)) ^TMP("OEOrdRepeatNew",%session.SessionId,EpisodeID)=RptRowID
		If COPYID'=$Piece($Get(^TMP("OEOrdRepeat",%session.SessionId,EpisodeID)),"^",$Length($Get(^TMP("OEOrdRepeat",%session.SessionId,EpisodeID)),"^")){ 
			//when Order its repeated from view "Indicaciones / Solicitud"
			Set tITM = $Piece(RptRowID,"||",2)
			///	empty OEORIText1
			set $piece(^OEORD(tORD,"I",tITM,13),"^",20)=""
			///	empty OEORIText2
			set $piece(^OEORD(tORD,"I",tITM,13),"^",21)=""
			Quit tSC
		}
		Set tITM = $Piece($Get(^TMP("OEOrdRepeatNew",%session.SessionId,EpisodeID)),"||",2)-1
		Kill ^TMP("OEOrdRepeatNew",%session.SessionId,EpisodeID)
		///
		While tITM {
			// inactivo
			If $Piece($Get(^OEORD(tORD,"I",tITM,1)),"^",13)=10 {
				Set tCalc = $Piece($Get(^OEORD(tORD,"I",tITM,13)),"^",6)
				///	If tCalc'="Y" {
					Set tUOM = $Piece($Get(^OEORD(tORD,"I",tITM,2)),"^",3)
					If tUOM {
						If $Piece(^OEORD(tORD,"I",tITM,11),"^",39)'="" {
							Do ..UpdateDetailsFromParentItem(tORD_"||"_tITM)
						}
						///	OEORIVariableDose
						/// check/copy OEORIVariableDose from Copy and Generate OEORIExec
						If ( $piece(^OEORD(+COPYID,"I",$piece(COPYID,"||",2),13),"^",33)'="" )&&( $piece(^OEORD(tORD,"I",tITM,13),"^",33)'=$piece(^OEORD(+COPYID,"I",$piece(COPYID,"||",2),13),"^",33) ) {
							set $piece(^OEORD(tORD,"I",tITM,13),"^",33)=$piece(^OEORD(+COPYID,"I",$piece(COPYID,"||",2),13),"^",33)
							set tThisOEORI = tORD_"||"_tITM
							&sql(delete %NOTRIGGER SQLUser.OE_OrdExec where OEORE_OEORI_ParRef = :tThisOEORI)
							do copyexe^COEOrdItem16(tORD_"||"_tITM,COPYID)
						}
						Set tOEORIVariableDose = $Piece(^OEORD(tORD,"I",tITM,13),"^",33)
						If tOEORIVariableDose="" {
							Set $Piece(^OEORD(tORD,"I",tITM,13),"^",6)="Y"
							If tUOM Set tUOM = $Piece(^CT("UOM",tUOM),"^",2)
							Set tRes = ..UpdatePHQtyOrd(tORD_"||"_tITM,tUOM)
							Set $Piece(^OEORD(tORD,"I",tITM,13),"^",6)="Y"
						}
					}
				///	}
				//when Order its repeated from view "RCE HMS"
				///	empty OEORIText1
				set $piece(^OEORD(tORD,"I",tITM,13),"^",20)=""
				///	empty OEORIText2
				set $piece(^OEORD(tORD,"I",tITM,13),"^",21)=""
			}
			Set tITM = $Order(^OEORD(tORD,"I",tITM))
			
		}
	}
	///	
	/////////////////////////////////////////////////

	Quit tSC
}

ClassMethod SetSessionCheckGES(pGES, pCronico, pMorbilidad) As %String
{
	Set tResult = ""
	
	Set ^TMP("WEB","ORDER_ENTRY", %session.SessionId, "CLXX_GES") = pGES_"^"_pCronico_"^"_pMorbilidad
	
	Quit tResult
}

/// ///////////////////////////////////////////////////////
/// 	2015-12-21	Victor Skrobot	JIRA	TC-64635
/// 	After Save on UpdateOrderDetails FIX Frequency
ClassMethod OnAfterUpdateOrderDetails() As %String
{
	
	///	on 2015 its not need
	/*
	Set tFreq = $Get(%request.Data("PHCFRDesc1",1))
	If tFreq'="" {
		
		Set tFreq=##Class(web.PHCFreq).GetIdFromCodeOrDescription(tFreq)
		Set tIDS = $Get(%request.Data("IDS",1))
		For tI=1:1:$Length(tIDS,"^")-1 {
			
			Set OEOrdItemID=$Piece(tIDS,"^",tI),ord=+OEOrdItemID,itm=$Piece(OEOrdItemID,"||",2)
			Set oi1=$g(^OEORD(ord,"I",itm,1)),oi2=$g(^OEORD(ord,"I",itm,2)),arcim=$p(oi1,"^",2)

			Set tType = $$ordertype^COEOrdItem(arcim)			
			Set OldFreq=$p(oi2,"^",4)
			If (OldFreq'=tFreq),(" R X I "[(" "_tType_" ")) {
				
				Set $Piece(^OEORD(ord,"I",itm,2),"^",4) = tFreq
				If tType="X" Set $Piece(^OEORD(ord,"I",itm,1),"^",6) = tFreq
				Do updexe^COEOrdItem6(OEOrdItemID)
				Set tUOM = $Piece(^OEORD(ord,"I",itm,2),"^",3)
				If tUOM Set tUOM = $Piece(^CT("UOM",tUOM),"^",2)
				If tType'="X" Set tRes = ..UpdatePHQtyOrd(OEOrdItemID,tUOM)
				
			}
			
		}
		
	}
	*/
	///	2016-06-23	With Duration calculate IV "C" Quantity	TC-83952
	Set tDur = $Get(%request.Data("PHCDUDesc1",1))
	If tDur'="" {
		
		Set tFreq=##Class(web.PHCDuration).GetIdFromCodeOrDescription(tDur)
		Set tIDS = $Get(%request.Data("IDS",1))
		For tI=1:1:$Length(tIDS,"^")-1 {

			Set OEOrdItemID=$Piece(tIDS,"^",tI),ord=+OEOrdItemID,itm=$Piece(OEOrdItemID,"||",2)
			Set oi1=$g(^OEORD(ord,"I",itm,1)),oi2=$g(^OEORD(ord,"I",itm,2)),arcim=$p(oi1,"^",2)

			Set tType = $$ordertype^COEOrdItem(arcim)			
			If " I "[(" "_tType_" ") {
				
				Set tObj = ##class(User.OEOrdItem).%OpenId(OEOrdItemID)
				///	Infusion Continua
				If tObj.OEORIIVType = "C" {
					
					Set tVolume = tObj.OEORIFlowQty
					Set tVolUnit = $s(tObj.OEORIUnit="L":1000,1:1)
					Set tTime = tObj.OEORITime
					Set tTimeUnit = $s(tObj.OEORIUnitHrs="hrs":1,1:60)
					Set tRate=(tVolume*tVolUnit)/(tTime*tTimeUnit)
					
					Set tPHCDrug = tObj.OEORIItmMastDR.ARCIMPHCDFDR.%Id()
					Set tTotVol = $Piece(^PHCD(+tPHCDrug,"DF",$Piece(tPHCDrug,"||",2),3),"^",15)
					
					Set tDurFac = tObj.OEORIDuratDR.PHCDUFactor
					
					Set tQuantity=(tRate*tDurFac*24)/tTotVol
					If $Piece(tQuantity,".",2)'="" Set tQuantity = $Piece(tQuantity,".",1)+1
					
					If tObj.OEORIPhQtyOrd'=tQuantity {
						Set tObj.OEORIPhQtyOrd=tQuantity
						Do tObj.%Save()
						Do ..UpdateDetailsFromParentItem(OEOrdItemID)
					}
					
				}
				
			}

		}

	}


	Quit 1
}

/// ////////////////////////////////////////////////////////
/// 	2016-06-01	Victor Skrobot	JIRA	TC-82614
/// 	Show component OEOrder.Question
/// * copied from Core oeorder.summaryscreen.csp
ClassMethod ShowQuestion() [ ProcedureBlock = 0 ]
{
 s displayQAonSumm=$p($g(^SSU("SSGRP",+$g(%session.Data("LOGON.GROUPID")))),"^",107)
 if ((displayQAonSumm'="B")&&(displayQAonSumm'="")) d
 . d ##Class(web.ARCItemQuestion).OEOrderQuestionPresetData($g(%request.Data("OEOrdItemIDs",1)))
 . s %request.Data("ScreenType",1)="S"
 . i displayQAonSumm="A" s %request.Data("ScreenType",1)="A"
 . s %request.Data("distinct",1)=""
 . s %request.Data("TINFO",1)=""
 . s cmp=##Class(websys.Component).OpenName("OEOrder.Question")
 . i cmp d cmp.Show() s cmp=""    
 Quit
}

/// 	2016-09-30	Victor Skrobot	JIRA	TC-94145
/// 	
ClassMethod GetOldExecQty(pID, pUpdateAsOld = 0) As %String
{
	Set tResult = 1
	
	Set tOrder = $Piece(pID,"||",1)
	Set tItem = $Piece(pID,"||",2)
	If 'pUpdateAsOld {
		
		Merge ^TMP($ZN,%session.SessionId,"OEOREEXEC",pID) = ^OEORD(tOrder,"I",tItem,"X")
		
	}else{
		
		Merge tExecs = ^TMP($ZN,%session.SessionId,"OEOREEXEC",pID)
		Set tExecId = $Order(tExecs(0))
		While tExecId'="" {
			
			Set tCurrExecId = $Order(^OEORD(tOrder,"I",tItem,"X",0))
			While tCurrExecId'="" {
				
				If $Piece(^OEORD(tOrder,"I",tItem,"X",tCurrExecId),"^",1)=$Piece(tExecs(tExecId),"^",1) {
					If $Piece(^OEORD(tOrder,"I",tItem,"X",tCurrExecId),"^",2)=$Piece(tExecs(tExecId),"^",2) {
						
						Set $Piece(^OEORD(tOrder,"I",tItem,"X",tCurrExecId),"^",4)=$Piece(tExecs(tExecId),"^",4)
						Quit
					}
				}
				
				Set tCurrExecId = $Order(^OEORD(tOrder,"I",tItem,"X",tCurrExecId))
			}
			
			Set tExecId = $Order(tExecs(tExecId))	
		}
		;Kill ^TMP($ZN,%session.SessionId,"OEOREEXEC")
		
	}
	
	Quit tResult
}

ClassMethod ChkShowQuestionnaire(pWinDesc) As %String
{
	#;
	#;	2018-02-14	Victor Skrobot	JIRA	TC-143651
	#;	dont show questionnaire "TCEPATFAR" if the user is Doctor
	set tResult = 1
	
	set tWinId = ##class(web.SSUserDefWindow).GetIdFromCodeOrDescription(pWinDesc)
	quit:tWinId="" tResult
	set tWinCode = $piece($get(^SSU("WIN",tWinId)),"^",1)
	quit:tWinId="" tResult
	quit:tWinCode'="TCEPATFAR" tResult
	
	set tUserID = %session.Data("LOGON.USERID")
	set tCTPCP  = ##Class(web.SSUser).GetDefaultCareProvider(tUserID)
	set tCPType = ##class(web.CTCareProv).GetInternalType(tCTPCP)
	set tCPTypeDesc = ""
	if tCTPCP, ($Data(^CTPCP(tCTPCP, 1))#10 = 1) set tCPTypeDesc = $ZCVT(##class(web.CTCareProv).GetCPTypeDesc(tCTPCP),"U")
	
	if (tCPType="DOCTOR")!(tCPTypeDesc["ODONT")!(tCPTypeDesc["MATRON") { 
		set tResult = 0
	}
	
	quit tResult
}

ClassMethod LRFEntry(ByRef rs) As %String
{
	set tResult = 1
	#;	2018-02-16	Victor Skrobot	JIRA	TC-143651
	#;	dont show questionnaire "TCEPATFAR" if the user is Doctor
	#;	dont show questionnaire "TCEPATFAR" if the user is Odontologo / Matrona
	set tUserID = %session.Data("LOGON.USERID")
	set tCTPCP  = ##Class(web.SSUser).GetDefaultCareProvider(tUserID)
	set tCPType = ##class(web.CTCareProv).GetInternalType(tCTPCP)
	set tCPTypeDesc = ""
	if tCTPCP, ($Data(^CTPCP(tCTPCP, 1))#10 = 1) set tCPTypeDesc = $ZCVT(##class(web.CTCareProv).GetCPTypeDesc(tCTPCP),"U")
	
	if (tCPType="DOCTOR")!(tCPTypeDesc["ODONT")!(tCPTypeDesc["MATRON") { 
		set tQuestionnaireID = rs.Data("QuestionnaireID")
		set tQuestionnaireCode = $lg(##class(web.SSUserDefWindow).GetCodeDescriptionFromId(tQuestionnaireID),3)
		if tQuestionnaireCode = "TCEPATFAR" {
			set rs.Data("QuestionnaireID") = ""
		}
	}
	Quit tResult
}

ClassMethod GetItemsVinculados(pOrderId, pEpisodeId) As %String
{
	New tResult
	Set tResult=""
	Try {
		set ^jb("vinc",1)="1 pOrderId "_pOrderId_" pEpisodeId "_pEpisodeId
		If (pOrderId="") Quit 
		
		&sql(Declare cVinculados cursor for 
			 select OEORI_ItmMast_DR
			 into :tItemMastId
			 from SQLUser.OE_OrdItem
			 where OEORI_OEORD_ParRef->OEORD_Adm_DR=:pEpisodeId
  			   and OEORI_OEORI_DR = :pOrderId)
		
		&sql(open cVinculados)
		&sql(fetch cVinculados)
		
		set tDescripcion = ""
		while $g(SQLCODE)=0
		{
			if tItemMastId '= ""
			{
				if tDescripcion = ""
				{
					set tDescVinculado = ##class(web.ARCItmMast).GetItemNameByGenePresc(tItemMastId)
					set tDescripcion = tDescVinculado
				}
				else
				{
					set tDescVinculado = ##class(web.ARCItmMast).GetItemNameByGenePresc(tItemMastId)
					set tDescripcion = tDescripcion_" ; "_tDescVinculado
				}
			}
			&sql(fetch cVinculados)	
		}
		
		&sql(close cVinculados)	
		
		Set tResult = tDescripcion
		
	}Catch(tException)
	{
		Set tResult=""
	}
	Quit tResult
}

Query LookUpItm(Item As %String, GroupID As %String, Category As %String, SubCategory As %String, TYPE As %String, LUCategoryDesc As %Library.String, LUSubCategoryDesc As %Library.String, EpisodeID As %Library.String, BillingGrp As %Library.String, BillingSubGrp As %Library.String, DateRestriction As %Library.String, OrdCatGrp As %Library.String, Pharm As %Library.String, Param As %Library.String, Hospital As %Library.String, GenericDrug As %String, ProfileID As %Library.String, returnAllOrdCats As %Library.String) As %Query(CONTAINID = 0, ROWSPEC = "ARCIMDesc:%String:Description,HIDDEN_ARCIMID:%String,HIDDEN_freq:%String,HIDDEN_ARCIMorARCOS:%String,HIDDEN_alias:%String,HIDDEN_OrderType:%String,HIDDEN_OrderCat:%String,HIDDEN_ARCOSID:%String,HIDDEN_mes:%String,HIDDEN_RangeFrom:%String,HIDDEN_RangeTo:%String,HIDDEN_UOM:%String,HIDDEN_dur:%String,HIDDEN_Generic:%String,HIDDEN_modif:%String,HIDDEN_ositems:%String,HIDDEN_OrderSubCat:%String,HIDDEN_hasdefault:%String,HIDDEN_drgfrm:%String,HIDDEN_DoseQty:%String,HIDDEN_DoseUOM:%String,HIDDEN_LookupEvent:%String,HIDDEN_arcimEpType:%String,HIDDEN_arcimLOS:%String,HIDDEN_arcimAnaMeth:%String,HIDDEN_arcimAnaTime:%String,HIDDEN_arcimSameDay:%String,HIDDEN_arcimEpisBill:%String,HIDDEN_arcimroomstring:%String,HIDDEN_arcimEpTypeId:%String,HIDDEN_rmType:%String,HIDDEN_rmTypeID:%String,HIDDEN_AifaNotes:%String,HIDDEN_AifaNotesId:%String,HIDDEN_EqGrp:%String,HIDDEN_Licensable:%String,HIDDEN_PrescClass:%String,HIDDEN_DispOnBehalf:%String,HIDDEN_Repeat:%String,HIDDEN_CurrPrice:%String,FormularyInd:%String:&nbsp,HIDDEN_Code:%String,HIDDEN_ARCIMCode:%String,HIDDEN_CompService:%String")
{
}

ClassMethod LookUpItmClose(QHandle As %Library.Binary) As %Library.Status [ PlaceAfter = LookUpItmFetch ]
{
	kill ^TMP("O",$job)
	set QHandle=""
	quit $$$OK
}

ClassMethod LookUpItmExecute(ByRef QHandle As %Library.Binary, Order As %String = "", GroupID As %Library.String = "", Category As %Library.String = "", SubCategory As %Library.String = "", TYPE As %Library.String = "", LUCategoryDesc As %Library.String = "", LUSubCategoryDesc As %Library.String = "", EpisodeID As %Library.String = "", BillingGrp As %Library.String = "", BillingSubGrp As %Library.String = "", DateRestriction As %Library.String = "", OrdCatGrp As %Library.String = "", Pharm As %Library.String = "", Param As %Library.String = "", Hospital As %Library.String = "", GenericDrug As %String = "", ProfileID As %Library.String = "", returnAllOrdCats As %Library.String = "") As %Library.Status
{
	
	new user,work,GenericPrescribing,FromCTOSet
	new type,PharmacyParam,GenericPrescribing,Route,Form,Strength
	new RtFrmStr,NonFormulary,GenericDrugId,Parameter,LookupEvent
	set AtEnd=0
	set (PharmacyParam,PharmacyItem,GenericPrescribing,LookupEvent,FromCTOSet)=""
	set (RtFrmStr,NonFormulary,Region,VendorOrd,GenericDrugId,Parameter,ContOnly)=""
	set LookupEvent=$get(%request.Data("ID",1)) //RC Field name that lookup was fired from. Used for Lookups in lists to determine row number.
	if $get(ProfileID)="",$data(%session) set ProfileID=$get(%session.Data("LOGON.PROFILEID"))
	if $get(Pharm)'="" do
	. set NonFormulary=$piece($get(Pharm),"^",1)
	. set RtFrmStr=$piece($get(Pharm),"^",2)
	. set Region=$piece($get(Pharm),"^",3)
	
	set formularyIP =$piece($get(NonFormulary),"|",1)
	
	set NoOrderSets = ""
	if $get(Param)'="" do
	. set NoOrderSets = $piece(Param,"^",1)
	. if NoOrderSets="" set NoOrderSets="0"
	. set VendorOrd=$piece($get(Param),"^",2)
	. set ContOnly=$piece($get(Param),"^",3)
	. set FromCTOSet=$piece($get(Param),"^",4)
	kill ^TMP("O",$job)
	set EpisodeID=$get(EpisodeID)
	set visitstatus=$piece($get(^PAADM(+EpisodeID)),"^",20)
	if visitstatus'="C" do
	. set BillingGrp=##class(web.ARCBillGrp).GetIdFromCodeOrDescription(BillingGrp)
	. set BillingSubGrp=##class(web.ARCBillSub).GetIdFromCodeOrDescription(BillingSubGrp)
	. set OrdCatGrp=##class(web.OECOrderCategoryGroup).GetIdFromCodeOrDescription(OrdCatGrp)
	. set GenericPrescribing=$piece($get(^CF("OE",1)),"^",74)
	. set Route=$piece($get(RtFrmStr),"|",1)
	. set Form=$piece($get(RtFrmStr),"|",2)
	. set Strength=$piece($get(RtFrmStr),"|",3)
	. if Form'="" set Form=##class(web.PHCForm).GetIdFromDesc(Form)
	. if Strength'="" set Strength=##class(web.PHCStrength).GetIdFromDesc(Strength)
	. if Route'="" set Route=##class(web.OECRoute).GetIdFromCodeOrDescription(Route)
	. set FindStock=""
	. set FindStock=$piece($get(NonFormulary),"|",3)
	. set ShowBrand=$piece($get(NonFormulary),"|",2)
	. if ShowBrand="true" set ShowBrand="Y"
	. set NonFormulary=$piece($get(NonFormulary),"|",1)
	. if NonFormulary="true" set NonFormulary="ALL"
	. if NonFormulary="false" set NonFormulary="Y"
	. set NonFormulary=NonFormulary_"|"_ShowBrand_"|"_FindStock
	. set PharmacyParam="0|"_PharmacyItem_"|"_Form_"|"_Route_"|"_Strength_"|"_NonFormulary_"|"_Region
	. if GenericDrug'="" set GenericDrugId=##class(web.PHCGeneric).GetIdFromCodeOrDescription(GenericDrug)
	. set Parameter=VendorOrd_"|"_GenericDrugId_"|"_ContOnly_"|||||||"_FromCTOSet
	. set x=$$open^UHMS.COEOrdItemLookUp(Order,GroupID,Category,SubCategory,TYPE,LUCategoryDesc,LUSubCategoryDesc,EpisodeID,BillingGrp,BillingSubGrp,DateRestriction,OrdCatGrp,PharmacyParam,Hospital,Parameter,ProfileID,returnAllOrdCats)
	. if x'=0 set AtEnd=1
	
	do ##class(websys.Component).GetComponentMessages(.t, "OEOrder.Entry")
	set formularyFlag = $get(t("FORMULARY_FLAG"))
	set nonFormularyFlag = $get(t("NON_FORMULARY_FLAG"))
	
	set user=$listbuild(Order,GroupID,Category,SubCategory,TYPE,LUCategoryDesc,LUSubCategoryDesc,EpisodeID,BillingGrp,BillingSubGrp,DateRestriction,OrdCatGrp,PharmacyParam,GenericPrescribing,Hospital,NoOrderSets,VendorOrd,Parameter,LookupEvent,ProfileID,formularyFlag,nonFormularyFlag,formularyIP)
	
	if visitstatus="C" set AtEnd=1
	//
	set work=$listbuild("")
	//
	set QHandle=$listbuild(AtEnd,user,work)
	//
	quit $$$OK
}

ClassMethod LookUpItmFetch(ByRef QHandle As %Library.Binary, ByRef Row As %Library.List, ByRef AtEnd As %Library.Integer = 0) As %Library.Status [ PlaceAfter = LookUpItmExecute ]
{
	new user,work,Order,GroupID,Category,SubCategory,TYPE,LUCategoryDesc,LUSubCategoryDesc,EpisodeID,BillingGrp,BillingSubGrp,DateRestriction,ARCIMCode
	new PharmacyParam,GenericPrescribing,Hospital,Schedule
	new arcimEpType,arcimLOS,arcimAnaMeth,arcimAnaTime,arcimSameDay,arcimEpisBill,arcimroomstring,compService
	set (Order,GroupID,Category,SubCategory,TYPE,LUCategoryDesc,LUSubCategoryDesc,EpisodeID,BillingGrp,BillingSubGrp,DateRestriction,ARCIMCode)=""
	set (OrdCatGrp,PharmacyParam,GenericPrescribing,sUser,hasdefault,Hospital,drgfrm,FindStock,DoseQty,DoseUOM,OrderType,VendorOrd,Schedule,Parameter,LookupEvent)=""
	set (arcimEpType,arcimLOS,arcimAnaMeth,arcimAnaTime,arcimSameDay,arcimEpisBill,arcimroomstring,rmType,rmTypeID)=""
	set (AifaNotes, AifaNotesID, EqGrp, Licensable, PrescClass, DispOnBehalf, Repeat, CurrPrice,compService)=""
	
	set AtEnd=$list(QHandle,1)
	set user=$list(QHandle,2)
	set work=$list(QHandle,3)
	
	if AtEnd=1 set Row="" quit $$$OK
	//
	set Order=$list(user,1)
	set GroupID=$list(user,2)
	set Category=$list(user,3)
	set SubCategory=$list(user,4)
	set TYPE=$list(user,5)
	set LUCategoryDesc=$list(user,6)
	set LUSubCategoryDesc=$list(user,7)
	set EpisodeID=$list(user,8)
	set BillingGrp=$list(user,9)
	set BillingSubGrp=$list(user,10)
	set DateRestriction=$list(user,11)
	set OrdCatGrp=$list(user,12)
	set PharmacyParam=$list(user,13)
	set GenericPrescribing=$list(user,14)
	set Hospital=$list(user,15)
	set NoOrderSets=$list(user,16)
	set VendorOrd=$list(user,17)
	set Parameter=$list(user,18)
	set LookupEvent=$list(user,19)
	set ProfileID=$list(user,20)
	set formularyFlag=$list(user,21)
	set nonFormularyFlag=$list(user,22)
	set formularyIP = $list(user,23)
	if $get(PharmacyParam)'="" set FindStock=$piece($get(PharmacyParam),"|",8)
Loop
	set y=$$fetch^UHMS.COEOrdItemLookUp(Order,GroupID,Category,SubCategory,TYPE,LUCategoryDesc,LUSubCategoryDesc,EpisodeID,BillingGrp,BillingSubGrp,DateRestriction,OrdCatGrp,PharmacyParam,Hospital,Parameter)
	if NoOrderSets="1",y=0,$find(arcimrow,"||")=0 goto Loop
	if y'=0 set AtEnd=1,Row="" quit $$$OK
	if ($get(FindStock)="Y")&&(($order(^INCI(0,"ARCIM_DR",+arcimrow,""))="")||(Type="ARCOS")) goto Loop
	if $data(%session) set sUser=$get(%session.Data("LOGON.USERID"))
	if sUser'="",arcimrow'="" do get^MVBSSAST(sUser,"ORDER_ENTRY",arcimrow)
	if $get(PLIST(1))'="" set hasdefault="Y"
	kill PLIST
	if $get(arcimrow)'="",$length(arcimrow,"||")=2 set drgfrm=$piece($get(^ARCIM(+arcimrow,1,1)),"^",12)
	if drgfrm'="" {
		set obj=##class(User.PHCDrgForm).%OpenId(drgfrm)
		if obj {
			set DoseUOM  = obj.PHCDFCTUOMDR.CTUOMDesc
			set DoseQty  = obj.PHCDFBaseQty
			set Schedule = obj.PHCDFScheduleClassDR.PHCSDCCode
			set Schedule = ##class(web.PHCScheduledDrugClass).GetIdFromCodeOrDescription(Schedule)
			set obj=""
		}
		if Schedule,'$$CheckOrderPermissions^MVBPAQUESDC(%session.Data("LOGON.PROFILEID"),Schedule) goto Loop
		if $piece(^SSU("SSGRP",$get(%session.Data("LOGON.GROUPID"))),"^",40)="Y" {
			set (equiv,equivglb)=""
			set equiv=$order(^PHCD(+drgfrm,"DF",+$piece(drgfrm,"||",2),"EQ",0))
			if $get(equiv)'="" set equivglb=$get(^PHCD(+drgfrm,"DF",+$piece(drgfrm,"||",2),"EQ",equiv))
			if $get(equivglb)'="" {
				set DoseUOM=$piece(equivglb,"^",1)
				if DoseUOM'="" set DoseUOM=$piece($get(^CT("UOM",DoseUOM)),"^",2)
				set DoseQty=$piece(equivglb,"^",3)
				if $get(DoseQty)="" set DoseQty=$piece(equivglb,"^",2)
			}
		}
		// select AIFA prescribing note
		set aifa=""
		for {
			set AifaNotes="", aifa=$order(^PHCD(+drgfrm,"DF",+$piece(drgfrm,"||",2),"AIFA",aifa), 1, AifaNotes)
			quit:(aifa="")
			
			set AifaNotesID=$piece(AifaNotes, "^",2)
			set nation=$piece(AifaNotes, "^",2)
			set hcr=$piece(AifaNotes, "^",6)
			set hca=$piece(AifaNotes, "^",7)
			set datefrom=$piece(AifaNotes, "^",3)
			set dateto=$piece(AifaNotes, "^",4)
			
			continue:('..IsValidHCAorHCR($get(%session("LOGON.HOSPID")), datefrom, dateto, hca, hcr, nation))
			
			if ((+AifaNotesID)'="") {
				set AifaNotes=$piece($get(^PHC("AIFAN",+AifaNotesID)),"^",2)
			}
		}
		// select Equivalent group
		set eqgrp="",EqGrp=""
		for {
			set eqgrp=$order(^PHCD(+drgfrm,"DF",+$piece(drgfrm,"||",2),"EQGRP",eqgrp), 1, EqGrp)
			quit:(eqgrp="")
			
			set nation=$piece(EqGrp, "^",2)
			set datefrom=$piece(EqGrp, "^",3)
			set dateto=$piece(EqGrp, "^",4)
			set hcr=$piece(EqGrp, "^",6)
			set hca=$piece(EqGrp, "^",7)
			
			continue:('..IsValidHCAorHCR($get(%session("LOGON.HOSPID")), datefrom, dateto, hca, hcr, nation))
			
			if ((+EqGrp)'="") {
				set EqGrp=$piece($get(^PHC("EQGRP",+EqGrp)),"^",2)
			}
		}
		// select Other repeatability parameters
		set rep="",Repeating="",Licensable="", PrescClass="", DispOnBehalf="", Repeat="", CurrPrice=""
		for {
			set rep=$order(^PHCD(+drgfrm,"DF",+$piece(drgfrm,"||",2),"REPEAT",rep), 1, Repeating)
			quit:(rep="")
			
			set nation=$piece(Repeating, "^",6)
			set hcr=$piece(Repeating, "^",7)
			set hca=$piece(Repeating, "^",8)
			set datefrom=$piece(Repeating, "^",9)
			set dateto=$piece(Repeating, "^",10)
			
			continue:('..IsValidHCAorHCR($get(%session("LOGON.HOSPID")), datefrom, dateto, hca, hcr, nation))
			set Licensable=$piece(Repeating, "^",1)
			set PrescClass=$piece(Repeating, "^",2)
			set DispOnBehalf=$piece(Repeating, "^",3)
			set Repeat=$piece(Repeating, "^",4)
			set CurrPrice=$piece(Repeating, "^",5)

			if ((+Repeat)'="") {
				set Repeat=$piece($get(^PHC("REPEAT",+Repeat)),"^",2)
			}
		}
		
	}
	
	set formularyInd=""
	if arcimrow'="",$length(arcimrow,"||")=2 {
		set ARCIMCode = $piece($get(^ARCIM(+arcimrow,$piece(arcimrow,"||",2),1)),"^",1)
		set arcimdata=$get(^ARCIM(+arcimrow,$piece(arcimrow,"||",2),11))
		set arcimEpTypeId=$piece(arcimdata,"^",12)  //User.ARCItmMast.ARCIMEpisodeType
		set arcimEpType=""
		set:arcimEpTypeId'="" arcimEpType=##class(websys.StandardTypeItem).GetDescription("AdmType",arcimEpTypeId)
		set arcimLOS=$piece(arcimdata,"^",13)     //User.ARCItmMast.ARCIMExpLOS
		set arcimAnaMeth=$piece(arcimdata,"^",14) //User.ARCItmMast.ARCIMAnaestMethodDR
		if arcimAnaMeth'="" set arcimAnaMeth=$piece($get(^ORC("ANMET",arcimAnaMeth)),"^",2) //User.ORCAnaestMethod.ANMETDesc
		set arcimAnaTime=$piece(arcimdata,"^",15) //User.ARCItmMast.ARCIMExpAnaestTime
		set arcimSameDay=$piece(arcimdata,"^",17) //User.ARCItmMast.ARCIMSameDay
		set arcimEpisBill=$piece(arcimdata,"^",16) //User.ARCItmMast.ARCIMEpisodicBilling
		set arcimroomstring=##class(web.ARCItemRoomType).GetRoomString(arcimrow)
		set rmTypeID=$piece(arcimdata,"^",19)
		set:rmTypeID'="" rmType=$piece($get(^PAC("ROOMT",rmTypeID)),"^",2)
		set compService=$piece(arcimdata,"^",36)
		set:(compService'="") compService=$piece($get(^ARCIM(+compService,$piece(compService,"||",2),1)),"^",2)
		
		set orderType = $$ordertype^COEOrdItem(arcimrow,"")
		if formularyIP="true" && ((orderType="R")||(orderType="I")) {
			set formularyInd = ##class(web.ARCItmMast).getItemFormularyFlag(arcimrow)
			if formularyInd="" set formularyInd="N"
			
			if formularyInd="N" set formularyInd = nonFormularyFlag
			else  if formularyInd="Y" set formularyInd=formularyFlag
		}
		else{
			set formularyInd = ""
		}
	}
	if $get(arcimrow)'="",$length(arcimrow,"||")=2 set code=$piece($get(^ARCIM(+arcimrow,1,1)),"^",1)
	if $get(arcimrow)'="",$length(arcimrow,"||")=1 set ARCIMCode = $piece($get(^ARCOS(+arcimrow)),"^",1)
	set Row=$listbuild(desc,arcimrow,freq,Type,alias,OrderType,OrderCat,OrderSetID,mes,RangeFrom,RangeTo,UOM,dur,gen,modif,ositems,OrderSubCat,hasdefault,drgfrm,DoseQty,DoseUOM,LookupEvent,arcimEpType,arcimLOS,arcimAnaMeth,arcimAnaTime,arcimSameDay,arcimEpisBill,arcimroomstring,arcimEpTypeId,rmType,rmTypeID,AifaNotes,AifaNotesID,EqGrp,Licensable, PrescClass, DispOnBehalf, Repeat, CurrPrice,formularyInd,code,ARCIMCode,compService)
	set QHandle=$listbuild(AtEnd,user,work)
	//
	quit $$$OK
}

ClassMethod IsValidHCAorHCR(userhosp, datefrom, dateto, hca, hcr, nation, HCANation As %String = "")
{
	if ( datefrom && (datefrom>+$h) ) quit 0
	if ( dateto && (dateto<+$h) ) quit 0
	// check if default based on healthcare area or region
	if HCANation="Area"!(HCANation="Region") {
		set usercity=$piece($get(^CT("HOSP",+userhosp)),"^",19)
		if (usercity) {
			
			set userhca = $order(^CT("CITHCA",0,"City",+usercity,""))
			if (userhca) {
				
				// compare HealthCare Area
				if ( (hca'="") && (hca = userhca) ) quit 1
				// if checking area and not found do not check region
				if HCANation="Area" quit 0
				set userhcr = $piece($get(^CT("HCA",+userhca)),"^",3)
				if (userhcr) {
					
					// compare HealthCare Region
					if ( (hcr'="") && (hcr = userhcr) ) quit 1
				}
			}
		}
	}
	// check if default based on national flag
	if HCANation="National",nation="Y" quit 1
	quit 0
}

/// /////////////////////////////////////////////////////////////
/// 	2019-08-27	Victor Skrobot	JIRA	TC-216578
/// 	
ClassMethod ChkSubstitution(pOEOrdItem As %String) As %String [ ProcedureBlock = 1 ]
{
	set tLinked = 0
	set tVariableDosis = 0
	
	set tOrderID = $piece(pOEOrdItem,"||",1)
	set tItemID = $piece(pOEOrdItem,"||",2)
	
	set tOEORIOEORIDR = $piece($get(^OEORD(tOrderID,"I",tItemID,11)),"^",39)	///	OEORI_OEORI_DR
	if (tOEORIOEORIDR="") {
		set tOEORIOEORIDR = $order(^OEORDi(0,"OEORI",tOrderID,""))
		while tOEORIOEORIDR {
			set tThisItemID = $piece(tOEORIOEORIDR,"||",2)
			if tThisItemID=tItemID quit
			set tOEORIOEORIDR = $order(^OEORDi(0,"OEORI",tOrderID,tOEORIOEORIDR))
		}
	}
	set tVariableDosis = $piece($get(^OEORD(tOrderID,"I",tItemID,13)),"^",33)	///	OEORI_VariableDose
	
	quit tOEORIOEORIDR_"^"_tVariableDosis
}

}
