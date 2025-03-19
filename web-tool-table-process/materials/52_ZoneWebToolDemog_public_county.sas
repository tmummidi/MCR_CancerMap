/* 52_ZoneWebToolDemog - Generate a table of demographic data for the web tool */

/* 5/25/2022 - added a Zone Design AUTOCALL macro library for commonly used macros */
/* 5/25/2022 - modified Excel file imports to use new ZD_ImportExcel macro */
/* 11/23/2022 - modified to use the web tool ZoneID without the StFIPS or the trailing repetition letters */
/* 11/9/2023 - modified to allow data by county and to output web tool tables by geography */
/* 5/16/2024 - modified to adjust format of Population data in output to not include commas; modified length of ZoneID variables
where needed to make all lengths of variables the same for merging*/

options sysprintfont=("Courier New" 8) leftmargin=0.75in nocenter compress=no;
ods graphics on;

%let stateName=Delaware;  /* Set state/registry name */
%let stateAbbr=DE;    /* Set state/registry abbreviation */
%let stateFIPS = 10; /*11/9/2023 Set state FIPS code*/
%let runNum=DE01; /* Run number used for Step 2 AZTool execution */
%let nationwide=yes;  /* Include nationwide data (yes|no)? */
%let county=yes; /*Include county-level rates (yes|no)? */ /*11/9/2023 add option for county rates*/
/* Census 2010 variables to include: */
%let keepCens=PctRural PctMinority PctHispanic PctBlackNH;
/* ACS data and variables to include: */
%let oneACSPeriod=no;  /* Use one ACS period for all time periods (yes|no)? */
%let ACS_endyr1=2019;  /* ACS 5yr data period 1 end year (2016 = 2012-2016) */
%let ACS_endyr2=2014;  /* ACS 5yr data period 2 end year (2011 = 2007-2011) */
%let keepACS=Pct100Pov PctNoHealthIns PctEducBchPlus PctEducLHS PctDisabled Pct_forborn;
%let keepACS2=Pct100Pov PctNoHealthIns PctEducBchPlus PctEducLHS PctDisabled Pct_forborn; /* PctNoHealthIns not available for 2011 */

/* Specify data path here for portability: */
%let pathbase=C:\Work\WebToolTables;

libname ZONEDATA "&pathbase.";
libname CENDATA1 "&pathbase.\Census_Data_Tables\ACS&ACS_endyr1._5yr Data";
%if &oneACSPeriod. = %quote(no) %then %do;
libname CENDATA2 "&pathbase.\Census_Data_Tables\ACS&ACS_endyr2._5yr Data";
%end; /* &oneACSPeriod=no processing */
ods pdf file="&pathbase.\52_ZoneWebToolDemog_&stateAbbr.to&ACS_endyr1..pdf";

/* Set up the Zone Design AUTOCALL macro library */
filename ZDAUTOS "&pathbase.\ZDMacros";
options mautosource sasautos=(SASAUTOS ZDAUTOS);

/* Import the final zoned tracts Excel file */
%ZD_ImportExcel(sourcefile=&pathbase.\ZonedTracts_&runNum._final.xlsx,
    sheetname=Tracts,
    targetds=ZonedTracts);

/* Import the final zone list Excel file */
%ZD_ImportExcel(sourcefile=&pathbase.\ZoneList_&runNum._final.xlsx,
    sheetname=FullStats,
    targetds=ZoneList);

/* Get ACS 5-year period 1 (most recent) datasets */
/* 11/9/2023 add GeoType variable for distinguishing geography type in individual datasets for separation later*/
data ACSData_per1_Tract;
    set CENDATA1.ACS&ACS_endyr1._Tract;
run;
data ACSData_per1_State;
	length GeoType $10; 
    set CENDATA1.ACS&ACS_endyr1._State;
	GeoType = "State";
run;
%if &nationwide. = %quote(yes) %then %do;
data ACSData_per1_Nation;
	length GeoType $10; 
    set CENDATA1.ACS&ACS_endyr1._Nation;
	GeoType = "Nationwide";
run;
%end; /* &nationwide=yes processing */
%if &county. = %quote(yes) %then %do; /*11/9/2023 add option for county data*/
data ACSData_per1_County;
	length GeoType $10; 
    set CENDATA1.ACS&ACS_endyr1._County;
	GeoType = "County";
run;
%end; /* &county=yes processing */

%if &oneACSPeriod. = %quote(no) %then %do;
/* Get ACS 5-year period 2 (least recent) datasets */
/* 11/9/2023 add GeoType variable for distinguishing geography type in individual datasets for separation later*/
data ACSData_per2_Tract;
    set CENDATA2.ACS&ACS_endyr2._Tract;
run;
data ACSData_per2_State;
	length GeoType $10; 
    set CENDATA2.ACS&ACS_endyr2._State;
	GeoType = "State";
run;
%end; /* &oneACSPeriod=no processing */
%if &nationwide. = %quote(yes) & &oneACSPeriod. = %quote(no) %then %do;
data ACSData_per2_Nation;
	length GeoType $10; 
    set CENDATA2.ACS&ACS_endyr2._Nation;
	GeoType = "Nationwide";
run;
%end; /* &nationwide=yes & &oneACSPeriod=no processing */
%if &county. = %quote(yes) & &oneACSPeriod. = %quote(no) %then %do; /*11/9/2023 add option for county data*/
data ACSData_per2_County;
	length GeoType $10; 
    set CENDATA2.ACS&ACS_endyr2._County;
	GeoType = "County";
run;
%end; /* &county=yes & &oneACSPeriod=no processing */

%if &nationwide. = %quote(yes) %then %do;
/* Import the US total demographic data table */
%ZD_ImportExcel(sourcefile=&pathbase.\Census_Data_Tables\DemogTable_US_Totals.xlsx,
    sheetname=DemogTable,
    targetds=DemogTable_US);
%end; /* &nationwide=yes processing */

/*11/9/2023 Add step to import county-level demographics data*/
/*Import county demographics Excel file*/
%if &county. = %quote(yes) %then %do;
%ZD_ImportExcel(sourcefile=&pathbase.\Census_Data_Tables\DemogTable_County_All.xlsx,
    sheetname=CountyStats,
    targetds=DemogTable_County);
%end; /* &county=yes processing */

/* Import WebTool table for years */
%ZD_ImportExcel(sourcefile=&pathbase.\CancerSiteTable_&stateAbbr..xlsx,
    sheetname=Webtool TIME,
    targetds=WebTool_Years);


/* Clean up the zone list dataset and keep just what we need */
data ZoneList2;
	length ZoneIDOrig $11;  /* 5/16/2024 modified length of variable*/
    set ZoneList;
	format ZonePop BEST12.; /* 5/16/2024 modified to adjust format so final output does not include commas */
	/*ZoneIDOrig = compress(ZoneIDOrig,'abcdefghijklmnopqrstuvwxyz');*/ /* 11/23/2022: Remove repetition letters */ /*7/31/24 No longer needed*/
    PctRural = 100 - PctUrban_PopMean;
    PctMinority = PctMinority_PopMean;
    PctHispanic = PctHispanic_PopMean;
    PctBlackNH = PctBlackNH_PopMean;
    PctAPINH = PctAPINH_PopMean;
    format PctRural PctMinority PctHispanic PctBlackNH PctAPINH 6.2;
    label
        PctRural = 'Percent of population living in a rural area'
        PctMinority = 'Percent minority (other than non-Hispanic White)'
        PctHispanic = 'Percent Hispanic'
        PctBlackNH = 'Percent non-Hispanic Black'
        PctAPINH = 'Percent non-Hispanic Asian/Pacific Islander';
    keep /* ZoneName */ ZoneIDOrig ZonePop
        &keepCens.; /* Just keep the variables needed for the web tool */
    rename ZoneIDOrig = ZoneID
        ZonePop = TotalPop;
run;

/* Clean up the zoned tracts dataset and keep just what we need */
data ZonedTracts2;
    set ZonedTracts;
	/*ZoneIDOrig = compress(ZoneIDOrig,'abcdefghijklmnopqrstuvwxyz');*/ /* 11/23/2022: Remove repetition letters */ /*7/31/24 No longer needed*/
    keep TractID ZoneIDOrig; /*11/23/2022: Updated to reference ZoneIDOrig variable*/
    rename ZoneIDOrig = ZoneID;
run;

/* Get the state FIPS code from the ACS state dataset and put it in a macro variable */
data _null_;
    set ACSData_per1_State;
    if GeoName = "&stateName.";
    putlog "*** &stateName. FIPS code set to " StFIPS;
    call symputx("stateFIPS", StFIPS);
run;

/* Macro to clean up the ACS datasets and keep just what we need */
%MACRO CleanACS(level=,period=);
data ACSData_per&period._&level.2;
   /* length GeoID $10; /*Test - change from ZoneID to GeoID*/
    set ACSData_per&period._&level.;
    if StFIPS in ("&stateFIPS.","00"); /* Just keep data for this state and the US */
    /* Just keep the variables needed for the web tool */
    %if &period. = %quote(1) %then %do;
        keep &keepACS.; /* Period 1 keeps */ 
        format &keepACS. 6.2;
    %end;
    %else %do;
        keep &keepACS2.; /* Period 2 keeps */ 
        format &keepACS2. 6.2;
    %end;
    %if &level. = %quote(Tract) %then %do;
        keep GeoID Total_pop;
        rename GeoID = TractID
            Total_pop = TotPop;
    %end;
	/*11/9/2023 Update coding for ZoneID so that instead of "Statewide" and "Nationwide" the actual GeoID will be used; Added code for County option.*/
	    %if &level. = %quote(State) %then %do;
        keep GeoID GeoType; /*11/9/2023 keep GeoType variable for distinguishing geography type in individual datasets for separation later*/
        rename GeoID = ZoneID;
    %end;
		%if &level. = %quote(County) %then %do;
        keep GeoID GeoType; /*11/9/2023 keep GeoType variable for distinguishing geography type in individual datasets for separation later*/
        rename GeoID = ZoneID;
    %end;
		%if &level. = %quote(Nation) %then %do;
        keep GeoID GeoType; /*11/9/2023 keep GeoType variable for distinguishing geography type in individual datasets for separation later*/
		GeoID = "US";
        rename GeoID = ZoneID;
	 %end;
run;
%MEND CleanACS;

/* Clean up the period 1 ACS dataset and keep just what we need */
%CleanACS(level=Tract,period=1);
%CleanACS(level=State,period=1);
%if &nationwide. = %quote(yes) %then %do;
%CleanACS(level=Nation,period=1);
%end; /* &nationwide=yes processing */
%if &county. = %quote(yes) %then %do; /*11/9/2023 add option for county data*/
%CleanACS(level=County,period=1);
%end; /* &county=yes processing */

%if &oneACSPeriod. = %quote(no) %then %do;
/* Clean up the period 2 ACS dataset and keep just what we need */
%CleanACS(level=Tract,period=2);
%CleanACS(level=State,period=2);
%end; /* &oneACSPeriod=no processing */
%if &nationwide. = %quote(yes) & &oneACSPeriod. = %quote(no) %then %do;
%CleanACS(level=Nation,period=2);
%end; /* &nationwide=yes & &oneACSPeriod=no processing */
%if &county. = %quote(yes) & &oneACSPeriod. = %quote(no) %then %do; /*11/9/2023 add option for county data*/
%CleanACS(level=County,period=2);
%end; /* &county=yes & &oneACSPeriod=no processing */

%if &nationwide. = %quote(yes) %then %do;
/* Clean up the US total demographic data table and keep just what we need*/
data DemogTable_US2;
    length ZoneID $11 GeoType $10; /* 11/9/2023 add GeoType variable*/
    set DemogTable_US;
   	ZoneID = 'US'; /* 11/9/2023 Set ZoneID to 'US'; previously set to "Nationwide"*/
	GeoType = "Nationwide"; 
    format Pct: 6.2;
run;
%end; /* &nationwide=yes processing */

/* 11/9/2023 Add County option*/
/* Clean up the county demographics dataset and keep just what we need, including filtering to only include state of interest*/
%if &county. = %quote(yes) %then %do;
data Demogtable_county2;
	length StCoFIPS $11 GeoType $10;
    set Demogtable_county;
	if StAbbr = "&stateAbbr.";
	GeoType = "County";
    PctRural = 100 - PctUrban;
    format PctRural PctMinority PctHispanic PctBlackNH PctAPINH 6.2 StCoFIPS $11.;
    label
        PctRural = 'Percent of population living in a rural area'
        PctMinority = 'Percent minority (other than non-Hispanic White)'
        PctHispanic = 'Percent Hispanic'
        PctBlackNH = 'Percent non-Hispanic Black'
        PctAPINH = 'Percent non-Hispanic Asian/Pacific Islander';
    keep GeoType StCoFIPS Pop2010
        &keepCens.; /* Just keep the variables needed for the web tool */
    rename StCoFIPS = ZoneID
        Pop2010 = TotalPop;
run;
%end; /* &county=yes processing */

/* Get state-wide pop-weighted means for Census variables */
proc means data=ZoneList2 NOPRINT NWAY MEAN;
    var &keepCens.;
    weight TotalPop;
    output out=StateMeans_Cens MEAN=;
run;
data StateMeans_Cens2;
    length ZoneID $10 GeoType $10; /*11/9/2023 Add GeoType variable*/
    set StateMeans_Cens;
    ZoneID = "&stateFIPS."; /*11/9/2023 Set ZoneID to StateFIPS code; previously set to "Statewide"*/
	GeoType = "State"; 
    drop _TYPE_ _FREQ_;
run;

/* Get statewide pop total (2010) and add to Census variables */
proc means data=ZoneList2 NOPRINT NWAY SUM;
    var TotalPop;
    output out=StatePopTotal SUM=;
run;
data StatePopTotal2;
    length ZoneID $11 GeoType $10; /*11/9/2023 Add GeoType variable*/
    set StatePopTotal;
    ZoneID = "&stateFIPS."; /*11/9/2023 Set ZoneID to StateFIPS code; previously set to "Statewide"*/
	GeoType = "State"; 
    drop _TYPE_ _FREQ_;
run;
proc sort data=StateMeans_Cens2; by ZoneID; run;
proc sort data=StatePopTotal2; by ZoneID; run;
data StateMeans_Cens3;
    merge StatePopTotal2 (in=inPopTot)
        StateMeans_Cens2 (in=inMeans);
    by ZoneID;
    if inPopTot;
    if not inMeans then
    if not inMeans then putlog "*** Missing state-wide means for census variables";
run;

/* Macro to get zone level pop-weighted means for ACS variables, combine with
    Census 2010 variables, and combine zone, state, and national level data  */
/* Set macro parameter for testing:
%let period=per1;
/* */
%macro zoneMeansAndCombine(period=);
/* Add the ZoneID to the tract-level ACS data */
proc sort data=ACSData_&period._Tract2; by TractID; run; /*11/9/2023 Edit from GeoID to TractID*/
proc sort data=ZonedTracts2; by TractID; run;
data ACSData_&period._Tract3;
    merge ACSData_&period._Tract2 (in=inACS)
        ZonedTracts2 (in=inZoned);
    by TractID;
    if inZoned;
    if not inACS then putlog "*** Missing &period. ACS data for tract " TractID;
run;
/* Get zone pop-weighted means for ACS variables */
proc means data=ACSData_&period._Tract3 NOPRINT NWAY MEAN;
    class ZoneID;
    weight TotPop;
    output out=ZoneMeans_ACS&period. MEAN=;
run;
data ZoneMeans_ACS&period.b;
	/*length ZoneID $10; /*11/9/2023 Set length of ZoneID to match other datasets for combining*/
    set ZoneMeans_ACS&period.;
    drop _TYPE_ _FREQ_;
    %if &period. = %quote(1) %then %do;
    format &keepACS. 6.2;
    %end;
    %else %do;
    format &keepACS2. 6.2;
    %end;
run;
/* Combine Census and ACS variables by zone */
proc sort data=ZoneList2; by ZoneID; run;
proc sort data=ZoneMeans_ACS&period.b; by ZoneID; run;
data ZoneMeans_CensACS&period.;
	length GeoType $10; /*11/9/2023 Add GeoType variable*/
    merge ZoneList2 (in=inCens)
        ZoneMeans_ACS&period.b (in=inACS);
    by ZoneID;
    if inCens;
    if not inACS then putlog "*** Missing ACS &period. data for zone " ZoneID;
	GeoType = "Zone";
run;

/* Combine state-wide Census and ACS variables */
proc sort data=StateMeans_Cens3; by ZoneID; run;
proc sort data=ACSData_&period._State2; by ZoneID; run;
data StateMeans_CensACS&period.;
    merge StateMeans_Cens3 (in=inCens)
        ACSData_&period._State2 (in=inACS);
    by ZoneID;
    if inCens;
    if not inACS then putlog "*** Missing ACS &period. data for zone " ZoneID;
run;
%if &nationwide. = %quote(yes) %then %do;
/* Combine nationwide Census and ACS variables */
proc sort data=DemogTable_US2; by ZoneID; run;
proc sort data=ACSData_&period._Nation2; by ZoneID; run;
data NationalMeans_CensACS&period.;
    merge DemogTable_US2 (in=inCens)
        ACSData_&period._Nation2 (in=inACS);
    by ZoneID;
    if inCens;
    if not inACS then putlog "*** Missing ACS &period. data for zone " ZoneID;
run;
%end; /* &nationwide=yes processing */

/*11/9/2023 Add County option*/
/* Combine county Census and ACS variables*/
%if &county. = %quote(yes) %then %do;
proc sort data = DemogTable_county2; by ZoneID; run;
proc sort data=ACSData_&period._County2; by ZoneID; run;
data CountyMeans_CensACS&period.;
    merge DemogTable_county2 (in=inCens)
        ACSData_&period._County2 (in=inACS);
    by ZoneID;
    if inCens;
    if not inACS then putlog "*** Missing ACS &period. data for zone " ZoneID;
run;
%end; /* &county=yes processing */


/*11/9/2023 Add county option*/
/* Append state, national, and county level data to the zone-level data */
data DemogVars_CensACS&period.;
    set ZoneMeans_CensACS&period.
        StateMeans_CensACS&period.
        %if &nationwide. = %quote(yes) %then %do;
        NationalMeans_CensACS&period.
        %end; /* &nationwide=yes processing */
		%if &county. = %quote(yes) %then %do;
        CountyMeans_CensACS&period.
        %end; /* &county=yes processing */
        ;
run;
%mend zoneMeansAndCombine;

/* Get pop-weighted means for zones and combine with state and national */
%zoneMeansAndCombine(period=per1);
%if &oneACSPeriod. = %quote(no) %then %do;
%zoneMeansAndCombine(period=per2);
%end; /* &oneACSPeriod=no processing */

/* Create 1 year dataset using period 1 ACS data */
data DemogTable_01yr;
    length /*ZoneID $10*/ Years $5;
    set DemogVars_CensACSper1;
    Years = "01yr";
    /* QC check PctMinority */
    if PctMinority <= sum(PctHispanic,PctBlackNH,PctAPINH) then
        putlog "Inconsistent race/ethnicity data, ZoneID: " ZoneID;
    keep ZoneID GeoType Years TotalPop &keepCens. &keepACS.; /*11/9/2023 Add GeoType*/
run;

/* Create 5 year dataset using ACS period 1 data (same as 1 year dataset) */
data DemogTable_05yrs;
    length /*ZoneID $10*/ Years $5;
    set DemogVars_CensACSper1;
    Years = "05yrs";
    /* QC check PctMinority */
    if PctMinority <= sum(PctHispanic,PctBlackNH,PctAPINH) then
        putlog "Inconsistent race/ethnicity data, ZoneID: " ZoneID;
    keep ZoneID GeoType Years TotalPop &keepCens. &keepACS.; /*11/9/2023 Add GeoType*/
run;

/* Create 10 year dataset averaging ACS period 1 and period 2 data (if available) */
/* Note: if any variables are missing for ACS period 2, will use values from period 1 */
data DemogTable_10yrs;
    length /*ZoneID $10*/ Years $5;
    set DemogVars_CensACSper1
        %if &oneACSPeriod. = %quote(no) %then %do;
        DemogVars_CensACSper2
        %end; /* &oneACSPeriod=no processing */
        ;
    Years = "10yrs";
    /* QC check PctMinority */
    if PctMinority <= sum(PctHispanic,PctBlackNH,PctAPINH) then
        putlog "Inconsistent race/ethnicity data, ZoneID: " ZoneID;
    keep ZoneID GeoType Years TotalPop &keepCens. &keepACS.; /*11/9/2023 Add GeoType*/
run;
proc means data=DemogTable_10yrs NOPRINT NWAY MEAN;
    class ZoneID Years GeoType; /*11/9/2023 Add GeoType*/
    output out=DemogTable_10yrs2(drop=_TYPE_ _FREQ_) MEAN=;
run;

/* Append the three pieces for the web tool */
data DemogTable_WebTool;
	length GeoID $10; /* 5/16/2024 Set length of GeoID to be consisent with length in RateTable*/
    set DemogTable_01yr DemogTable_05yrs DemogTable_10yrs2;
    GeoID = ZoneID; /*11/9/2023 Set GeoID to same values as ZoneID*/
	drop ZoneID;
run;

/* Keep just the data needed for the web tool: filter rows by year */
proc sort data=DemogTable_WebTool; by Years; run;
proc sort data=WebTool_Years; by value; run;
data DemogTable_WebTool2;
    merge DemogTable_WebTool (in=inDemog)
        WebTool_Years (in=inYears keep=value rename=(value=Years));
    by Years;
    if inYears and not inDemog then putlog "*** Unmatched year value in WebTool table:" Years;
    if inDemog and inYears; /* Keep only those rows that are in both datasets */
run;

/* Final sort */
proc sort data=DemogTable_WebTool2; by GeoType GeoID Years; run; /*11/9/2023 Update Zone to GeoID; Add GeoType*/


/* Save SAS dataset */
data ZONEDATA.DemogTable_&stateAbbr.to&ACS_endyr1._WebTool;
    set DemogTable_WebTool2;
run;

/* Export to a CSV file */ 
proc export data=DemogTable_WebTool2 
            OUTFILE= "&pathbase.\DemogTable_All_&stateAbbr.to&ACS_endyr1._WebTool.csv"
            DBMS=CSV REPLACE;
     PUTNAMES=YES;
run;

/* Summary statistics */
title "52_ZoneWebToolDemog_&stateAbbr.to&ACS_endyr1. - summary statistics";
proc means data=ZONEDATA.DemogTable_&stateAbbr.to&ACS_endyr1._WebTool;
by GeoType; /*11/9/2023 Add GeoType*/
run;

title "52_ZoneWebToolDemog_&stateAbbr.to&ACS_endyr1. - data table";
proc print data=ZONEDATA.DemogTable_&stateAbbr.to&ACS_endyr1._WebTool;
    id GeoID; /*11/9/2023 Update from Zone to GeoID*/
run;


ods pdf close;

