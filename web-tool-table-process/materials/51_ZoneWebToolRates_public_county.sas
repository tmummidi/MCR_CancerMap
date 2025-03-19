/* 51_ZoneWebToolRates - Generate cancer rate table for the web tool from SEER*Stat results */

/* 5/25/2022 - added a Zone Design AUTOCALL macro library for commonly used macros */
/* 5/25/2022 - modified Excel file imports to use new ZD_ImportExcel macro */
/* 5/25/2022 - modified Excel file export to use new ZD_ExportExcel macro */
/* 6/27/2022 - eliminated special processing for using SEER vs non-SEER database and
    removed the generation of suppression summary tables */
/* 6/28/2022 - simplified processing of nationwide rate data for results from the new
    NPCR SEER*Stat database */
/* 11/23/2022 - modified to use ZoneIDFull for linking datasets and to use
    a ZoneID for the web tool without the StFIPS or the trailing repetition letters */
/*4/7/2023 - edited 'Export web tool dataset to a CSV file' step to fix typo that originally exported RateTable_WebTool instead of
	RateTable_WebTool4*/
/*10/19/2023 - modifications to allow data by county and to create combined dataset with updated GeoID and GeoType variables*/
/*1/7/2025 - added code to remove cases where sex is not equal to 'Male and Female', 'Male', and 'Female', since these
cases will not have populations to be able to calculate rates*/

options sysprintfont=("Courier New" 8) leftmargin=0.75in nocenter compress=no;

%let stateAbbr=DE;    /* Set state/registry abbreviation */
%let stateName=Delaware; /*10/19/23 Set state name*/
%let stateFIPS = 10; /*10/19/23 Set state FIPS code*/
%let runNum=DE01; /* Run number used for Step 2 AZTool execution */
%let year1=2019;  /* Latest year */
%let year5=2015_2019;  /* 5-year range */
%let year10=2010_2019;  /* 10-year range */
%let nationwide=yes;  /* Include nationwide rates (yes|no)? */
%let allUSdset=AllUS_Combined_2021subm_to2019; /* USCS dataset with national rates */
%let county=yes; /*Include county-level rates (yes|no)? */ /*10/19/2023 add option for county rates*/

/* Specify data path here for portability: */
%let pathbase=C:\Work\WebToolTables;

libname ZONEDATA "&pathbase.";
ods pdf file="&pathbase.\51_ZoneWebToolRates_&stateAbbr.to&year1..pdf";

/* Set up the Zone Design AUTOCALL macro library */
filename ZDAUTOS "&pathbase.\ZDMacros";
options mautosource sasautos=(SASAUTOS ZDAUTOS);

/* Import the final zone list Excel file */
%ZD_ImportExcel(sourcefile=&pathbase.\ZoneList_&runNum._final.xlsx, 
    sheetname=FullStats, /*11/23/22 Update to sheetname*/
    targetds=ZoneList);

/* Import SEER*Stat rate session results - by zone */
PROC IMPORT OUT=SEERin_zones
            DATAFILE="&pathbase.\&runNum.zone_RateCalcs.txt"
            DBMS=DLM REPLACE;
    DELIMITER='09'x; /* Tab */
    GETNAMES=YES;
    DATAROW=2;
    GUESSINGROWS=1000; /* Zone names may be truncated */
run;

/* Import SEER*Stat rate session results - state as a whole */
PROC IMPORT OUT=SEERin_state
            DATAFILE="&pathbase.\&stateAbbr.state_RateCalcs.txt"
            DBMS=DLM REPLACE;
    DELIMITER='09'x; /* Tab */
    GETNAMES=YES;
    DATAROW=2;
    GUESSINGROWS=1000;
run;

%if &nationwide. = %quote(yes) %then %do;
/* Import SEER*Stat rate session results - US as a whole */
PROC IMPORT OUT=SEERin_allUS
            DATAFILE="&pathbase.\National_Cancer_Rates\&allUSdset..txt"
            DBMS=DLM REPLACE;
    DELIMITER='09'x; /* Tab */
    GETNAMES=YES;
    DATAROW=2;
    GUESSINGROWS=1000;
run;
%end; /* &nationwide=yes processing */

%if &county. = %quote(yes) %then %do;
/* Import SEER*Stat rate session results - county-level */ /*10/19/2023 add option for county rates*/
PROC IMPORT OUT=SEERin_county
            DATAFILE="&pathbase.\&stateAbbr.county_RateCalcs.txt"
            DBMS=DLM REPLACE;
    DELIMITER='09'x; /* Tab */
    GETNAMES=YES;
    DATAROW=2;
    GUESSINGROWS=max; 
run;
%end; /* &county=yes processing */

/* Clear formats, informats and labels for SEER*Stat rate session datasets */
proc datasets lib=work nolist;
    MODIFY SEERin_zones; FORMAT _all_; INFORMAT _all_; ATTRIB _all_ label=''; run;
    MODIFY SEERin_state; FORMAT _all_; INFORMAT _all_; ATTRIB _all_ label=''; run;
    %if &nationwide. = %quote(yes) %then %do;
        MODIFY SEERin_allUS; FORMAT _all_; INFORMAT _all_; ATTRIB _all_ label=''; run;
    %end; /* &nationwide=yes processing */
	%if &county. = %quote(yes) %then %do;
        MODIFY SEERin_county; FORMAT _all_; INFORMAT _all_; ATTRIB _all_ label=''; run;
    %end; /* &county=yes processing */
quit;

/* Import SEER*Stat cancer site table */
%ZD_ImportExcel(sourcefile=&pathbase.\CancerSiteTable_&stateAbbr..xlsx,
    sheetname=SEER_Stat,
    targetds=SeerStatSites);

/* Import WebTool tables for site, years, and races */
%ZD_ImportExcel(sourcefile=&pathbase.\CancerSiteTable_&stateAbbr..xlsx,
    sheetname=Webtool CANCERSITE,
    targetds=WebTool_CancerSites);
%ZD_ImportExcel(sourcefile=&pathbase.\CancerSiteTable_&stateAbbr..xlsx,
    sheetname=Webtool TIME,
    targetds=WebTool_Years);
%ZD_ImportExcel(sourcefile=&pathbase.\CancerSiteTable_&stateAbbr..xlsx,
    sheetname=Webtool RACE,
    targetds=WebTool_RaceEthGroups);

/* In the SEER*Stat zone rate dataset, rename the Zone ID variable */
/* 11/23/2022: modified to use ZoneIDFull */
data SEERin_zones2;
    length ZoneIDFull $10;
    set SEERin_zones;
    ZoneIDFull = ZoneID_&stateAbbr.;
    drop ZoneID_&stateAbbr.;
run;

/* Add full zone name and create a ZoneID for use with the web tool */
/* 11/23/2022: use ZoneIDFull as the linkage key and add code to create ZoneID */
proc sort data=SEERin_zones2; by ZoneIDFull; run;
proc sort data=ZoneList; by ZoneIDFull; run;
data SEERin_zones3;
    length ZoneID $10 ZoneName $200 GeoType $10; /* 10/19/2023 add GeoType variable for distinguishing geography type in individual datasets for separation later*/
    merge SEERin_zones2 (in=inData)
        ZoneList (in=inNames keep=ZoneName ZoneIDFull /*11/23/2022 use ZoneIDFull rather than ZoneIDOrig*/
            /*rename=(ZoneIDOrig=ZoneID)*/);
    by ZoneIDFull;
    if inData;
    if not inNames then putlog "*** Missing zone name for ZoneID: " ZoneIDFull;
	ZoneID = substr(ZoneIDFull,3); /* 11/23/2022: Strip off the leading StFIPS code */
    /*ZoneID = compress(ZoneID,'abcdefghijklmnopqrstuvwxyz');*/ /* 11/23/2022: Remove repetition letters */ /*7/31/24 No longer needed*/
    drop ZoneIDFull; /* 11/23/2022 */
	GeoType = "Zone"; /* 10/19/2023 */
run;

/* Add a ZoneID variable to the state dataset so we can combine with zones */
data SEERin_state2;
    length ZoneID $10 ZoneName $200 GeoType $10; /* 10/19/2023 add GeoType and ZoneName variables*/
    set SEERin_state;
    ZoneID = "&stateFIPS.";
	GeoType = "State";
	ZoneName = "&stateName.";
run;

%if &nationwide. = %quote(yes) %then %do;
/* Add a ZoneID variable to the US dataset so we can combine with zones */
data SEERin_allUS2;
    length ZoneID $10 ZoneName $200 GeoType $10; /* 10/19/2023 add GeoType and ZoneName variables*/
    set SEERin_allUS;
    ZoneID = "US";
	GeoType = "Nationwide";
	ZoneName = "United States";
run;
%end; /* &nationwide=yes processing */

/*10/19/2023 add option for county rates*/
%if &county. = %quote(yes) %then %do;
/* Add a ZoneID variable and ZoneName variable to the county dataset so we can combine with zones */
data SEERin_county2;
    length ZoneID $10 ZoneName $200  GeoType $10; /* 10/19/2023 add GeoType and ZoneName variables*/
    set SEERin_county;
	/*10/19/2023 extract state county FIPS code from 'County_DE' field to populate ZoneID*/
	retain re;
	if _N_ = 1 then re=prxparse('/\((.*?)\)/');
	if prxmatch(re,County_&stateAbbr.) then ZoneID = prxposn(re, 1, County_&stateAbbr.);
	/*10/19/2023 extract county name from 'County_&stateAbbr.' field to populate ZoneName*/
	ZoneName = strip(scan(County_&stateAbbr.,2,':('));
	drop County_&stateAbbr. re;
	GeoType = "County";
run;
%end; /* &county=yes processing */

/* Combine zone and state (and possibly national and county) datasets */ /*10/19/23 Added option for county data*/
data RateTable;
    set SEERin_zones3 SEERin_state2
    %if &nationwide. = %quote(yes) %then %do;
    SEERin_allUS2
    %end; /* &nationwide=yes processing */
	%if &county. = %quote(yes) %then %do;
    SEERin_County2
    %end; /* &county=yes processing */
    ;
run;

/* Clean up the data and rename columns */
data RateTable2;
    length ZoneID $10 SexNew $10 Site $40 Years $5 RaceEth $12;
    set RateTable;
	if Sex not in ('Male and female', 'Male', 'Female') then delete; /*1/7/25 adding code to remove cases where sex is not equal to 'Male and Female', 'Male', and 'Female', since these cases will not have populations to be able to calculate rates*/
	else if Sex = 'Male and female' then SexNew = 'Both';
    else SexNew = Sex;
    Site = USCS_Sites;
    select (LatestYears_1_5_10);
        when ("1yr_&year1.")    Years='01yr';
        when ("5yrs_&year5.")   Years='05yrs';
        when ("10yrs_&year10.") Years='10yrs';
        otherwise               Years='???';
        end;
    /* Set RaceEth variable and delete unknowns */
    select (Race_and_origin_recode_with_All);
        when ('AllRaceEth')                                 RaceEth='.AllRaceEth';
        when ('Non-Hispanic White')                         RaceEth='White_NH';
        when ('Non-Hispanic Black')                         RaceEth='Black_NH';
        when ('Non-Hispanic Asian or Pacific Islander')     RaceEth='API_NH';
        when ('Non-Hispanic American Indian/Alaska Native') RaceEth='AIAN_NH';
        when ('Non-Hispanic Unknown Race')                  RaceEth='Unknown_NH';
        when ('Hispanic (All Races)')                       RaceEth='Hispanic';
        otherwise                                           RaceEth='???';
        end;
    if RaceEth = 'Unknown_NH' then delete;
    drop Sex USCS_Sites LatestYears_1_5_10 Race_and_origin_recode_with_All Standard_Error;
    rename
        SexNew = Sex
        Age_Adjusted_Rate = AAIR
        Lower_Confidence_Interval = LCI
        Upper_Confidence_Interval = UCI
        Count = Cases
        Population = PopTot;
run;

/* Modify sex-specific site names and remove opposite sex observations */
proc sort data=RateTable2; /* Sort by Site and Sex last so we can verify the changes */
    by ZoneID Years RaceEth Site Sex;
run;
data RateTable3;
    set RateTable2;
    SexSpecSite = 0; /* Sex-specific site flag */
    if Site = 'Breast' then do;
        SexSpecSite = 1;
        if Sex = 'Female' then Site = 'Breast (female)';
        else delete;
        end;
    if Site = 'Cervix Uteri' then do;
        SexSpecSite = 1;
        if Sex = 'Female' then Site = 'Cervix Uteri (female)';
        else delete;
        end;
    if Site = 'Corpus and Uterus, NOS' then do;
        SexSpecSite = 1;
        if Sex = 'Female' then Site = 'Corpus and Uterus, NOS (female)';
        else delete;
        end;
    if Site = 'Ovary' then do;
        SexSpecSite = 1;
        if Sex = 'Female' then Site = 'Ovary (female)';
        else delete;
        end;
    if Site = 'Prostate' then do;
        SexSpecSite = 1;
        if Sex = 'Male' then Site = 'Prostate (male)';
        else delete;
        end;
    if Site = 'Testis' then do;
        SexSpecSite = 1;
        if Sex = 'Male' then Site = 'Testis (male)';
        else delete;
        end;
run;

/* Create a cancer site sort sequence field based on state rates */
data SiteSortSeq;
    set RateTable3;
    if GeoType = "State"; /*10/19/23 Update criteria from ZoneID to GeoType*/
    if Years = '10yrs';
    if RaceEth = '.AllRaceEth';
    if (Sex = 'Female') and (index(Site,'female')=0) then delete;
    if (Sex = 'Male') and (index(Site,'male')=0) then delete;
    /* Adjust rate for sex-specific cancer sites */
    if (Sex = 'Female') or (Sex = 'Male') then AAIR = AAIR / 2;
    keep Site AAIR;
run;
proc sort data=SiteSortSeq; by descending AAIR; run;
data SiteSortSeq2;
    set SiteSortSeq;
    SiteSort = _N_;
run;

/* Add the site sort sequence field to the rate table */
proc sort data=RateTable3; by Site; run;
proc sort data=SiteSortSeq2; by Site; run;
data RateTable4;
    merge RateTable3 (in=inRates)
        SiteSortSeq2 (in=inSort drop=AAIR);
    by Site;
    if inRates;
    if not inSort then putlog "*** Missing sort sequence number: " ZoneID Years RaceEth Site Sex;
    rename Site = Site_full;
run;

/* Add short site name */
data SeerStatSites2;
    length Site_short $10 Site_SEERStat_var $40 Site_sex $6 Site_full $40;
    set SeerStatSites;
    if Site_sex ^= '' then Site_full = catt(Site_SEERStat_var, ' (', Site_sex, ')');
    else Site_full = Site_SEERStat_var;
run;
proc sort data=RateTable4; by Site_full; run;
proc sort data=SeerStatSites2; by Site_full; run;
data RateTable5;
    length ZoneID $10 Sex $10 Site_short $10 Years $5 RaceEth $12;
    merge RateTable4 (in=inRates)
        SeerStatSites2 (in=inSites);
    by Site_full;
    if inRates;
    if not inSites then putlog "*** Unexpected missing site name: " Site_full;
    drop Site_SEERStat_var Site_sex Site_full;
run;

/* Suppress counts and rates if 15 or fewer cases */
data RateTable_wSuppr;
    set RateTable5;
    if Cases < 16 then do;
        Cases = .;
        AAIR = .;
        LCI = .;
        UCI = .;
        end;
    if Cases = . then LT16cases = 1; /* For summary suppression statistics */
    else LT16cases = 0;
    /* Add a ByGroup variable for summary suppression statistics */
    length ByGroup $18;
    if (Sex = 'Both') and (RaceEth = '.AllRaceEth') then ByGroup = '1-BySite';
    if (Sex ^= 'Both') and (RaceEth = '.AllRaceEth') then do;
        if SexSpecSite = 1 then ByGroup = '1-BySite';
        else                    ByGroup = '2-BySiteSex';
        end;
    if (Sex = 'Both') and (RaceEth ^= '.AllRaceEth') then ByGroup = '3-BySiteRaceEth';
    if (Sex ^= 'Both') and (RaceEth ^= '.AllRaceEth') then do;
        if SexSpecSite = 1 then ByGroup = '3-BySiteRaceEth';
        else                    ByGroup = '4-BySiteSexRaceEth';
        end;
    drop SexSpecSite;
	rename ZoneID = GeoID; /*10/19/23 Rename ZoneID to GeoID to be consistent with other rate table*/
	label ZoneID = GeoID;
run;

/* Create separate rate variables for each race/ethnicity */
proc sort data=RateTable_wSuppr;
    by GeoID Site_short Sex Years RaceEth; /*10/19/23 Update ZoneID to GeoID*/
run;
/*10/19/23 Update ZoneID to GeoID*/
data RateTable_WebTool;
    length GeoID $10 Sex $10 Site_short $10 Years $5;
    retain
        All_PopTot All_Cases All_AAIR All_LCI All_UCI .
        W_PopTot W_Cases W_AAIR W_LCI W_UCI .
        B_PopTot B_Cases B_AAIR B_LCI B_UCI .
        H_PopTot H_Cases H_AAIR H_LCI H_UCI .
        API_PopTot API_Cases API_AAIR API_LCI API_UCI .
        AIAN_PopTot AIAN_Cases AIAN_AAIR AIAN_LCI AIAN_UCI .
        ;
    set RateTable_wSuppr;
    by GeoID Site_short Sex Years;
    select (RaceEth);
        when ('.AllRaceEth') do;
            All_PopTot = PopTot; All_Cases = Cases; All_AAIR = AAIR; All_LCI = LCI; All_UCI = UCI;
            end;
        when ('White_NH') do;
            W_PopTot = PopTot; W_Cases = Cases; W_AAIR = AAIR; W_LCI = LCI; W_UCI = UCI;
            end;
        when ('Black_NH') do;
            B_PopTot = PopTot; B_Cases = Cases; B_AAIR = AAIR; B_LCI = LCI; B_UCI = UCI;
            end;
        when ('API_NH') do;
            API_PopTot = PopTot; API_Cases = Cases; API_AAIR = AAIR; API_LCI = LCI; API_UCI = UCI;
            end;
        when ('AIAN_NH') do;
            AIAN_PopTot = PopTot; AIAN_Cases = Cases; AIAN_AAIR = AAIR; AIAN_LCI = LCI; AIAN_UCI = UCI;
            end;
        when ('Hispanic') do;
            H_PopTot = PopTot; H_Cases = Cases; H_AAIR = AAIR; H_LCI = LCI; H_UCI = UCI;
            end;
        otherwise putlog "*** Unexpected race ethnicity value: " RaceEth GeoID Site_short Sex Years;
        end;
    if last.Years then do;
        output;
        All_PopTot=.; All_Cases=.; All_AAIR=.; All_LCI=.; All_UCI=.;
        W_PopTot=.; W_Cases=.; W_AAIR=.; W_LCI=.; W_UCI=.;
        B_PopTot=.; B_Cases=.; B_AAIR=.; B_LCI=.; B_UCI=.;
        H_PopTot=.; H_Cases=.; H_AAIR=.; H_LCI=.; H_UCI=.;
        API_PopTot=.; API_Cases=.; API_AAIR=.; API_LCI=.; API_UCI=.;
        AIAN_PopTot=.; AIAN_Cases=.; AIAN_AAIR=.; AIAN_LCI=.; AIAN_UCI=.;
        end;
    format
        All_AAIR All_LCI All_UCI
        W_AAIR W_LCI W_UCI
        B_AAIR B_LCI B_UCI
        H_AAIR H_LCI H_UCI
        API_AAIR API_LCI API_UCI
        AIAN_AAIR AIAN_LCI AIAN_UCI
        8.1;
    drop RaceEth AAIR LCI UCI Cases PopTot
        LT16cases ByGroup;
    rename
		ZoneName = GeoName /*10/19/23 rename ZoneName to GeoName to account for new tables by geography*/
        Site_short = Cancer
        All_PopTot = PopTot
        All_Cases = Cases
        All_AAIR = AAIR
        All_LCI = LCI
        All_UCI = UCI;
run;

/* Keep just the data needed for the web tool: filter rows by cancer site */
proc sort data=RateTable_WebTool; by Cancer; run;
proc sort data=WebTool_CancerSites; by value; run;
data RateTable_WebTool2;
    merge RateTable_WebTool (in=inRates)
        WebTool_CancerSites (in=inSites keep=value rename=(value=Cancer));
    by Cancer;
    if inSites and not inRates then putlog "*** Unmatched short site name in WebTool table:" Cancer;
    if inRates and inSites; /* Keep only those rows that are in both datasets */
run;

/* Keep just the data needed for the web tool: filter rows by year */
proc sort data=RateTable_WebTool2; by Years; run;
proc sort data=WebTool_Years; by value; run;
data RateTable_WebTool3;
    merge RateTable_WebTool2 (in=inRates)
        WebTool_Years (in=inYears keep=value rename=(value=Years));
    by Years;
    if inYears and not inRates then putlog "*** Unmatched year value in WebTool table:" Years;
    if inRates and inYears; /* Keep only those rows that are in both datasets */
run;

/* Keep just the data needed for the web tool: drop unneeded race/eth variables */
data _null_; /* Create a macro variable for each race/eth group */
    set WebTool_RaceEthGroups;
    if _N_ = 1 then do;
        call symputx("KeepWhite", "No");
        call symputx("KeepBlack", "No");
        call symputx("KeepHisp", "No");
        call symputx("KeepAPI", "No");
        call symputx("KeepAIAN", "No");
        end;
    if value = "W" then call symputx("KeepWhite", "Yes");
    if value = "B" then call symputx("KeepBlack", "Yes");
    if value = "H" then call symputx("KeepHisp", "Yes");
    if value = "API" then call symputx("KeepAPI", "Yes");
    if value = "AIAN" then call symputx("KeepAIAN", "Yes");
run;
data _null_; /* Verify macro variable values */
    putlog "KeepWhite: &KeepWhite.";
    putlog "KeepBlack: &KeepBlack.";
    putlog "KeepHisp: &KeepHisp.";
    putlog "KeepAPI: &KeepAPI.";
    putlog "KeepAIAN: &KeepAIAN.";
run;
data RateTable_WebTool4; /* Drop unneeded variables */
    set RateTable_WebTool3;
    %if &KeepWhite. = %quote(No) %then %do;
        drop W_:; /* Drop the five White cancer rate variables */
        %end;
    %if &KeepBlack. = %quote(No) %then %do;
        drop B_:; /* Drop the five Black cancer rate variables */
        %end;
    %if &KeepHisp. = %quote(No) %then %do;
        drop H_:; /* Drop the five Hispanic cancer rate variables */
        %end;
    %if &KeepAPI. = %quote(No) %then %do;
        drop API_:; /* Drop the five API cancer rate variables */
        %end;
    %if &KeepAIAN. = %quote(No) %then %do;
        drop AIAN_:; /* Drop the five AIAN cancer rate variables */
        %end;
run;

/* Final sorts */
%macro FinalSort(ds=,zoneIdVar=,lastBy=);
proc sort data=&ds.;
    by GeoType Years SiteSort Sex &zoneIdVar. &lastBy.; /* 10/19/2023 Add sort by GeoType */
run;
%mend FinalSort;
%FinalSort(ds=RateTable_wSuppr,zoneIdVar=GeoID,lastBy=RaceEth); /* 10/19/2023 Update ZoneIDVar to =GeoID*/
%FinalSort(ds=RateTable_WebTool4,zoneIdVar=GeoID,lastBy=); /* 10/19/2023 Update ZoneIDVar to =GeoID*/

/* Save the main SAS datasets */
data ZONEDATA.RateTable_&stateAbbr.to&year1._wSuppr;  /* Rates with suppression */
    set RateTable_wSuppr;
run;
data ZONEDATA.RateTable_&stateAbbr.to&year1._WebTool;  /* Rates for WebTool */
    set RateTable_WebTool4;
run;

/* Export web tool dataset to a CSV file */ 

proc export data=RateTable_WebTool4 (drop=SiteSort)
            OUTFILE= "&pathbase.\RateTable_All_&stateAbbr.to&year1._WebTool.csv"
            DBMS=csv REPLACE;
     PUTNAMES=YES;
run;

/* Summary statistics */
title "51_ZoneWebToolRates_&stateAbbr.to&year1. - summary statistics for web tool rate table";
proc freq data=ZONEDATA.RateTable_&stateAbbr.to&year1._WebTool;
    table Cancer / list missing;
    table Sex / list missing;
    table Years / list missing;
	table GeoType / list missing; /*10/19/2023 Add table for GeoType*/
run;
ods pdf STARTPAGE=NO;
proc means data=ZONEDATA.RateTable_&stateAbbr.to&year1._WebTool;
by GeoType; /*10/19/2023 Add by GeoType to output separate statistics by geography*/
run;
ods pdf STARTPAGE=YES;

title "51_ZoneWebToolRates_&stateAbbr.to&year1. - summary statistics for original rates with suppression";
proc freq data=ZONEDATA.RateTable_&stateAbbr.to&year1._wSuppr;
    table Site_short / list missing;
    table Sex / list missing;
    table Years / list missing;
    table RaceEth / list missing;
    table LT16cases / list missing;
    table ByGroup*LT16cases / list missing;
    table Years*ByGroup*LT16cases / list missing;
run;
ods pdf STARTPAGE=NO;
proc means data=ZONEDATA.RateTable_&stateAbbr.to&year1._wSuppr;
    var AAIR LCI UCI Cases PopTot;
run;
ods pdf STARTPAGE=YES;


ods pdf close;

