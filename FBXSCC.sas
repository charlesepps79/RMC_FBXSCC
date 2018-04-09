**********************************************************************;
*** IMPORT NEW CROSS SELL FILES. --------------------------------- ***;
*** INSTRUCTIONS HERE: R:\Production\MLA\Files for MLA Processing\ ***;
*** XSELL\XSELL TCI DECSION LENDER.txt --------------------------- ***;
*** CHANGE DATES IN THE LINES IMMEDIATELY BELOW ALONG WITH FILE    ***;
*** PATHS. FOR THE FILES PATHS, YOU WILL LIKELY NEED TO CREATE A   ***;
*** NEW FOLDER "CC" IN THE APPROPRIATE MONTH FILE. DO NOT CHANGE   ***;
*** THE ARGUMENT TO THE LEFT OF THE COMMA - ONLY CHANGE WHAT IS TO ***;
*** THE RIGHT OF THE COMMA. ALSO NOTE THE CHANGE TO "Odd" OR "Even"***; 
*** BASED ON WHAT IS NEEDED FOR THE CURRENT PULL. ---------------- ***;
**********************************************************************;

*** ASSIGN MACRO VARIABLES --------------------------------------- ***;
DATA 
	_NULL_;

	CALL SYMPUT ('_1day','2018-04-01'); /* DAY BEFORE PULL */
	CALL SYMPUT ('_1month','2018-03-02'); /* 1 MONTH FROM PULL */
	CALL SYMPUT ('_16month','2016-12-02'); /*16 MONTHS FROM PULL*/
	CALL SYMPUT('_3year','2015-04-02'); /* 3 YEARS FROM PULL */
	CALL SYMPUT('_5year','2013-04-02'); /* 5 YEARS FROM PULL */
	CALL SYMPUT ('_15month','2017-01-02'); /*15 MONTHS FROM PULL*/

	*** ASSIGN ID MACRO VARIABLES -------------------------------- ***;
	CALL SYMPUT ('retail_id', 'RetailXS_5.0_2018');
	CALL SYMPUT ('auto_id', 'AutoXS_5.0_2018');
	CALL SYMPUT ('fb_id', 'FB_5.0_2018CC');

	*** ASSIGN ODD/EVEN MACRO VARIABLE --------------------------- ***;
	CALL SYMPUT ('odd_even', 'Odd'); 

	*** ASSIGN DATA FILE MACRO VARIABLE -------------------------- ***;
	CALL SYMPUT ('finalexportflagged', 
		'\\mktg-app01\E\Production\2018\04-April_2018\FBXSCC\FBXS_CC_.20180402flagged.txt');
	CALL SYMPUT ('finalexportdropped', 
		'\\mktg-app01\E\Production\2018\04-April_2018\FBXSCC\FBXS_CC_20180402final.txt');
	CALL SYMPUT ('exportMLA', 
		'\\mktg-app01\E\Production\MLA\MLA-Input files TO WEBSITE\FBCC_20180402.txt');
	CALL SYMPUT ('finalexportED', 
		'\\mktg-app01\E\Production\2018\04-April_2018\FBXSCC\FBXS_CC_20180402final_HH.csv');
	CALL SYMPUT ('finalexportHH', 
		'\\mktg-app01\E\Production\2018\04-April_2018\FBXSCC\FBXS_CC_20180402final_HH.txt');
RUN;

*** CHECK THAT MACRO VARIABLES WERE ASSIGNED CORRECTLY ----------- ***;
%PUT "&_15monthsago" "&_5yrdate" "&yesterday";

*** NEW TCI DATA - RETAIL AND AUTO ------------------------------- ***;
PROC IMPORT 
	DATAFILE = 
		"\\mktg-app01\E\Production\2018\04-April_2018\FBXSCC\XS_Mail_Pull.xlsx" 
		DBMS = XLSX OUT = XS REPLACE;
	RANGE = "XS Mail Pull$A3:0";
	GETNAMES = YES;
RUN;

*** FORMAT THE `NEWXS` DATASET AND STORE AS `NEWXS2` ------------- ***;
DATA XS2;
	SET XS;

	*** CREATE `SOURCE` VARIABLE AND ASSIGN `LOAN TYPE = AUTO      ***;
	*** INDIRECT` AS `TCICENTRAL` OR `LOAN TYPE = RETAIL` AS       ***; 
	*** `TCIRETAIL` ---------------------------------------------- ***;
	IF 'loan type'n = "Auto Indirect" THEN SOURCE = "TCICentral";
	IF 'loan type'n = "Retail" THEN SOURCE = "TCIRetail";
	IF SOURCE NE "";

	*** SEPERATE `applicant address` VARIABLE INTO `ADR1`, `CITY`, ***; 
	*** `STATE`, AND `ZIP` VARIABLES WHEN `applicant address` DOES ***; 
	*** NOT CONTAIN THE STRING "Apt" ----------------------------- ***;
	IF FIND('applicant address'n, "Apt") = 0 THEN DO;
		ADR1 = SCAN('applicant address'n, 1, ",");
		CITY = SCAN('applicant address'n, 2, ",");
		STATE = SCAN('applicant address'n, 3, ",");
		ZIP = SCAN('applicant address'n, 4, ",");
	END;

	*** SEPERATE `applicant address` VARIABLE INTO `ADR1`, `ADR2`, ***;
	*** `CITY`, `STATE`, AND `ZIP` VARIABLES WHEN `applicant       ***;
	*** address` CONTAINS THE STRING "Apt" ----------------------- ***;
	IF FIND('applicant address'n, "Apt") GE 1 THEN DO;
		ADR1 = SCAN('applicant address'n, 1, ",");
		ADR2 = SCAN('applicant address'n, 2, ",");
		CITY = SCAN('applicant address'n, 3, ",");
		STATE = SCAN('applicant address'n, 4, ",");
		ZIP = SCAN('applicant address'n, 5, ",");
	END;

	*** FORMAT `applicant dob` AS YYMMDD10 AND STORE IN `DOB`      ***;
	*** VARIABLE. ------------------------------------------------ ***;
	DOB = PUT('applicant dob'n, YYMMDD10.);

	*** FORMAT `application date` AS MMDDYY10 -------------------- ***;
	'application date1'n = PUT('application date'n, MMDDYY10.);

	*** CONCATENATE "TCI" TO `Application Number` AND STORE AS     ***;
	*** `BRACCTNO` VARIABLE -------------------------------------- ***;
	BRACCTNO = CATS("TCI", 'Application Number'n);

	*** SUB-STRING THE LAST 7 DIGITS FROM THE `applicant ssn`      ***;
	*** VARIABLE AND STORE THEM IN `SSNO1_RT7` VARIABLE ---------- ***;
	SSNO1_RT7 = SUBSTRN('applicant ssn'n, MAX(1, 
		length('applicant ssn'n) - 6), 7);

	*** DROP THE VARIABLES `Application Date`, `Applicant Address`,***;
	*** `Applicant Address Zip`, `Applicant DOB`, `app. work phone`***;
	*** FROM NEWXS2 DATASET -------------------------------------- ***;
	DROP 'Application Date'n 'Applicant Address'n
		'Applicant Address Zip'n 'Applicant DOB'n 'app. work phone'n;

	*** RENAME THE `application date1`, `applicant email`,         ***;
	*** `Applicant Credit Score`, `Applicant First Name`,          ***;
	*** `Applicant Last Name`, `Applicant SSN`, `Applicant Middle  ***;
	*** Name`, `app. cell phone`, AND `app. home phone` VARIABLES  ***;
	RENAME 
		'application date1'n = 'application date'n
		'applicant email'n = EMAIL 
		'Applicant Credit Score'n = CRSCORE
		'Applicant First Name'n = FIRSTNAME
		'Applicant Last Name'n = LASTNAME 
		'Applicant SSN'n = SSNO1
		'Applicant Middle Name'n = MIDDLENAME 
		'app. cell phone'n = CELLPHONE 
		'app. home phone'n = PHONE;
RUN;

DATA TCI;

	*** SET LENGTH FOR `ADR1`, `CITY`, `STATE`, `ZIP`,             ***;
	*** `MIDDLENAME`, `SOURCE`, AND `BRACCTNO` VARIABLES --------- ***;
	LENGTH 
		ADR1 $40 
		CITY $25 
		STATE $4 
		ZIP $10 
		MIDDLENAME $25 
		SOURCE $11
		BRACCTNO $15;
	SET XS2;
	SSNO1 = STRIP(SSNO1); /* STRIP WHITE SPACE FROM `SSNO1` */
	DOB = COMPRESS(DOB, "-"); /* REMOVE HYPHEN FROM `DOB` */
	FORMAT _CHARACTER_; /* SET CHAR FORMAT TO SAS DEFAULT */
RUN;


*** READ IN DATA FROM `dw.vw_loan_NLS` TABLE. SUBSET FOR RELEVANT  ***;
*** VARIABLES. FILTER TO ISOLATE XS LOANS. STORE AS `XS_L` DATASET ***;
DATA XS_L;
	
	*** SUBSET `dw.vw_loan_NLS` USING RELEVANT VARIABLES --------- ***;
	SET dw.vw_loan_NLS (
		KEEP = OWNST PURCD CIFNO BRACCTNO ID SSNO1 OWNBR SSNO1_RT7 
			SSNO2 LNAMT NETLOANAMOUNT FINCHG LOANTYPE ENTDATE LOANDATE 
			CLASSID CLASSTRANSLATION XNO_TRUEDUEDATE FIRSTPYDATE SRCD 
			POCD POFFDATE PLCD PLDATE PLAMT BNKRPTDATE BNKRPTCHAPTER
			CONPROFILE1 DATEPAIDLAST APRATE CRSCORE CURBAL);
	
	*** FILTER DATA. REMOVE NULLS FROM `CIFNO`. FILTER FOR         ***;
	*** `ENTDATE` FROM A YEAR AGO UNTIL MOST RECENT. KEEP ONLY     ***;
	*** NULLS FROM `POCD`. KEEP ONLY NULLS FROM `PLCD`. KEEP ONLY  ***;
    *** NULLS FROM `PLDATE`. KEEP ONLY NULLS FROM `POFFDATE`. KEEP ***;
	*** ONLY NULLS FROM `BNKRPTDATE`. KEEP RELEVANT `CLASSID`S and ***;
	*** `OWNST`S ------------------------------------------------- ***;
	WHERE CIFNO NE "" & 
		ENTDATE >= "&_15month" & 
		POCD = "" & 
		PLCD = "" & 
		PLDATE = "" & 
		POFFDATE = ""  & 
		BNKRPTDATE = "" & 
		CLASSID in (10,19,20,31,34) & 
		OWNST in ("NC","VA","NM","SC","OK","TX");
	
	*** CREATE `SS7BRSTATE` VARIABLE ----------------------------- ***;
	SS7BRSTATE = CATS(SSNO1_RT7, SUBSTR(OWNBR, 1, 2)); 
RUN;
