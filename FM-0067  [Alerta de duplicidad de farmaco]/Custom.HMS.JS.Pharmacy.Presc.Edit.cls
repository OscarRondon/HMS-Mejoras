/// Component JavaScript for: Pharmacy.Presc.Edit
Class Custom.HMS.JS.Pharmacy.Presc.Edit Extends websys.AbstractJavaScript
{

///  
ClientMethod JSContent() [ Language = javascript ]
{
/*
TRC         : 65232.
Description : Setting up PrescNo if patient with episode is selected.
Last Updated: 20110224. JKam.
*/
function gup( name )
{
  name = name.replace(/[\[]/,"\\\[").replace(/[\]]/,"\\\]");
  var regexS = "[\\?&]"+name+"=([^&#]*)";
  var regex = new RegExp( regexS );
  var results = regex.exec( window.location.href );
  if( results == null )
    return "";
  else
    return results[1];
}


function DocumentLoadHandlerCustom() {
	
	
	//Call to ERP Stock Update
	var action = document.getElementById("Action").value;
	var PrescNo=document.getElementById('AllScripts').value;
	var loc=document.getElementById('Loc').value;
	
	if (action=="Pack")		
	{
		
		var UpdateStock=tkMakeServerCall("Custom.ERP.StockHandler","StockGetUpdate",PrescNo,loc);
	}
	
	
	
	var objPrescNo=document.getElementById('PrescNo');
	if(objPrescNo&&objPrescNo.value=="") {
		objPrescNo.value = gup( 'PrescNo' );
	}
	DocumentLoadHandler();
	
	if(objPrescNo&&objPrescNo.value!="") {
		EnquireClick();
	}
	
	///	2018-02-27	
	var tbl = document.getElementById("tPharmacy_Presc_Edit");
	var f = document.getElementById("fPharmacy_Presc_Edit");
	var action = document.getElementById("Action").value;
	var aryfound=checkedCheckBoxes(f,tbl,"ActionOKz");
	for (var i=0;i<aryfound.length;i++) {
		var count=aryfound[i];
		var currStatus=f.elements["HIDDENPrescStatz"+count].value;
		var currCheck=f.elements["ActionOKz"+count];
		if (action=="Pack") {
			if ((currStatus!="A")&&(currCheck)) {
				currCheck.checked=false; //TRC 131723. Select only the Accepted order items to Pack.
			}
		}
		else if(action=="Collect") {
			if ((currStatus!="M")&&(currCheck)) {
				currCheck.checked=false; //TRC 131723. Select only the Packed order items to Collect.				
			}
		}
	}

}

/* TRC69224 jperez Valida que no se pueda dispensar x barcode mas que lo solicitado*/
function ScanPickHandler(){
	if (document.getElementById('ScanPick').value!="") {
		var pick=tkMakeServerCall("Custom.HMIL.Stock.BarcodeHandler","ScanPickBroker",document.getElementById('ScanPick').value);
		if (pick!=1) { 
			var msg1="";
			if (pick=="inci") msg1=t['INCICODE'];
			if (pick=="batch") msg1=t['BATCHCODE'];
			if (pick=="incil") msg1=t['INCILERR'];
			if (pick=="incib") msg1=t['INCIBERR'];
			if (pick=="avail") msg1=t['NILAVAIL'];
			if (pick=="exp") msg1=t['BATEXP'];
			if (pick=="hmserr") msg1="No se encuentra lote disponible o no se puede dispensar mas de lo solicitado"
			
			if (msg1=="") msg1=t['NOMATCH'];

			
			alert(t['BARCODEINVALID'] + " " + msg1); 
		}
	 	else { Reload(); }
	}
	return false;
}

/*END TRC69224 */

websys_removeListener("load","onload",DocumentLoadHandler);
websys_addListener("load","onload",DocumentLoadHandlerCustom);
}

/// This Parameter is updated by Perforce
Parameter SrcVer = "$Id: //trak/main/releases/T2016.2/6/SYS/cls/websys/JavaScript.xml#1 $";

}
