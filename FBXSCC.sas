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

	CALL SYMPUT ('yesterday','2018-04-01'); /* DAY BEFORE PULL */
	CALL SYMPUT ('_1monthago','2018-03-02'); /* 1 MONTH FROM PULL */
	CALL SYMPUT ('_16monthsago','2016-12-02'); /*16 MONTHS FROM PULL*/
	CALL SYMPUT('_3yrdate','2015-04-02'); /* 3 YEARS FROM PULL */
	CALL SYMPUT('_5yrdate','2013-04-02'); /* 5 YEARS FROM PULL */
	CALL SYMPUT ('_15monthsago','2017-01-02'); /*15 MONTHS FROM PULL*/

	*** ASSIGN ID MACRO VARIABLES -------------------------------- ***;
	CALL SYMPUT ('retail_id', 'RetailXS_5.0_2018');
	CALL SYMPUT ('auto_id', 'AutoXS_5.0_2018');
	CALL SYMPUT ('fb_id', 'FB_5.0_2018CC');

	*** ASSIGN ODD/EVEN MACRO VARIABLE --------------------------- ***;
	CALL SYMPUT ('odd_even', 'Odd'); 

	*** ASSIGN DATA FILE MACRO VARIABLE -------------------------- ***;
	CALL SYMPUT ('finalexportflagged', 
		'\\mktg-app01\E\Production\2018\05-May_2018\FBXSCC\FBXS_CC_.20180402flagged.txt');
	CALL SYMPUT ('finalexportdropped', 
		'\\mktg-app01\E\Production\2018\05-May_2018\FBXSCC\FBXS_CC_20180402final.txt');
	CALL SYMPUT ('exportMLA', 
		'\\mktg-app01\E\Production\MLA\MLA-Input files TO WEBSITE\FBCC_20180402.txt');
	CALL SYMPUT ('finalexportED', 
		'\\mktg-app01\E\Production\2018\05-May_2018\FBXSCC\FBXS_CC_20180402final_HH.csv');
	CALL SYMPUT ('finalexportHH', 
		'\\mktg-app01\E\Production\2018\05-May_2018\FBXSCC\FBXS_CC_20180402final_HH.txt');
RUN;

*** CHECK THAT MACRO VARIABLES WERE ASSIGNED CORRECTLY ----------- ***;
%PUT "&_15monthsago" "&_5yrdate" "&yesterday";

*** PULL IN ALL XS SOURCES AND MERGE, THEN PULL IN FB AND MERGE WITH *;
*** XS. ---------------------------------------------------------- ***;

*** IMPORT TCI3_5 DELIMITED DATA FILE AS TCI2 DATA TABLE --------- ***;
PROC IMPORT 
	DATAFILE = 
		"\\mktg-app01\E\Production\MLA\Files for MLA Processing\XSELL\TCI3_5.txt"
		DBMS = DLM OUT = TCI2 REPLACE;
	DELIMITER = '09'x;
	GUESSINGROWS = MAX;
RUN;

*** CREATE NEW DATASET `TCI3`. FORMAT `SSNO1`, `SSNO1_RT7`, AND    ***;
*** `APPLICATION NUMBER` AS CHAR WITH DESIGNATED LENGTHS AND STORE ***;
*** IN `TCI3` DATASET -------------------------------------------- ***;
DATA TCI3;
	SET TCI2;
	SSN = PUT(INPUT(SSNO1, BEST32.), Z9.);
	SS7 = PUT(INPUT(SSNO1_RT7, BEST32.), Z7.);
	APPNUM = STRIP(PUT('application number'n, 10.));
	DROP SSNO1 SSNO1_RT7 'application number'n;
	RENAME SSN = SSNO1 SS7 = SSNO1_RT7 APPNUM = 'application number'n;
RUN;

*** NEW TCI DATA - RETAIL AND AUTO ------------------------------- ***;
PROC IMPORT 
	DATAFILE = 
		"\\mktg-app01\E\Production\2018\05-May_2018\FBXSCC\XS_Mail_Pull.xlsx" 
		DBMS = XLSX OUT = NEWXS REPLACE;
	RANGE = "XS Mail Pull$A3:0";
	GETNAMES = YES;
RUN;

*** FORMAT THE `NEWXS` DATASET AND STORE AS `NEWXS2` ------------- ***;
DATA NEWXS2;
	SET NEWXS;

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

*** CONCATENATE `TCI3` AND `NEWXS2` DATASETS INTO `TCI` ---------- ***;
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
	SET TCI3 NEWXS2; /* CONCATENATE */
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
		ENTDATE >= "&_15monthsago" & 
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

*** READ IN DATA FROM `dw.vw_borrower_nls` TABLE. SUBSET FOR       ***;
*** RELEVANT VARIABLES. FILTER TO ISOLATE XS LOANS. STORE AS       ***; 
*** `BORRNLS` DATASET -------------------------------------------- ***;
DATA BORRNLS;

	*** SET LENGTH FOR `FIRSTNAME`, `MIDDLENAME`, `LASTNAME` ----- ***;
	LENGTH FIRSTNAME $20 MIDDLENAME $20 LASTNAME $30;

	*** SUBSET `dw.vw_borrower_nls` USING RELEVANT VARIABLES ----- ***;
	SET dw.vw_borrower_nls (
		KEEP = RMC_UPDATED PHONE CELLPHONE CIFNO SSNO SSNO_RT7  FNAME 
			LNAME ADR1 ADR2 CITY STATE ZIP BRNO AGE CONFIDENTIAL
			SOLICIT CEASEANDDESIST CREDITSCORE);
	WHERE CIFNO NOT =: "B"; /* REMOVE `CIFNO`S THAT BEGIN WITH "B" */
	
	*** STRIP WHITE SPACE FROM `FNAME`, `LNAME`, `ADR1`, `ADR2`,   ***;
	*** `CITY`, `STATE`, `ZIP` ----------------------------------- ***;
	FNAME = STRIP(FNAME);
	LNAME = STRIP(LNAME);
	ADR1 = STRIP(ADR1);
	ADR2 = STRIP(ADR2);
	CITY = STRIP(CITY);
	STATE = STRIP(STATE);
	ZIP = STRIP(ZIP);
	
	*** FIND ALL INSTANCES OF "JR" IN `FNAME`. REMOVE "JR" FROM    ***;
	*** STRING AND STORE AS `FIRSTNAME`. STORE ALL OCCURENCES OF   ***;
	*** "JR" IN NEW VARIABLE, `SUFFIX` --------------------------- ***;
	IF FIND(FNAME, "JR") GE 1 THEN DO;
		FIRSTNAME = COMPRESS(FNAME, "JR");
		SUFFIX = "JR";
	END;
	
	*** FIND ALL INSTANCES OF "SR" IN `FNAME`. REMOVE "SR" FROM    ***;
	*** STRING AND STORE AS `FIRSTNAME`. STORE ALL OCCURENCES OF   ***;
	*** "SR" IN NEW VARIABLE, `SUFFIX` --------------------------- ***;
	IF FIND(FNAME, "SR") GE 1 THEN DO;
		FIRSTNAME = COMPRESS(FNAME, "SR");
		SUFFIX = "SR";
	END;
	
	*** IF `SUFFIX` IS NULL, TAKE 1ST WORD IN `FNAME` AND STORE AS ***;
	*** `FIRSTNAME`. TAKE 2ND, 3RD, AND 4TH WORDS IN `FNAME` AND   ***;
	*** STORE AS `MIDDLENAME` ------------------------------------ ***;
	IF SUFFIX = "" THEN DO;
		FIRSTNAME = SCAN(FNAME, 1, 1);
		MIDDLENAME = CATX(" ", SCAN(FNAME, 2, " "), 
			SCAN(FNAME, 3, " "), SCAN(FNAME, 4, " "));
	END;
	NWORDS = COUNTW(FNAME, " "); /* COUNT # OF WORDS IN `FNAME` */
	
	*** IF MORE THAN 2 WORDS IN `FNAME`, TAKE 1ST WORD AND STORE IN***; 
	*** `FIRSTNAME`, AND TAKE SECOND WORD AND ADD TO `MIDDLENAME`  ***;
	IF NWORDS > 2 & SUFFIX NE "" THEN DO;
		FIRSTNAME = SCAN(FNAME, 1, " ");
		MIDDLENAME = SCAN(FNAME, 2, " ");
	END;
	DOB = COMPRESS(AGE, "-"); /* REMOVE HYPHEN, STORE `AGE` AS `DOB` */
	LASTNAME = LNAME; /* STORE `LNAME` AS `LASTNAME` */
	DROP FNAME LNAME NWORDS AGE; /* DROP VARIABLES FROM TABLE */
	IF CIFNO NE ""; /* FILTER SET OF NULL `CIFNO`S */

	*** STORE `SSNO` AS `SSNO1`. *STORE `SSNO_RT7` AS `SSNO1_RT7`  ***;
	SSNO1 = SSNO;
	SSNO1_RT7 = SSNO_RT7;
RUN;

*** SPLIT: GROUP BY `CIFNO` - APPLY: FIND MAX `ENTDATE` PER `CIFNO`***:
*** - COMBINE: STORE RECORDS WITH MAX `ENTDATE` PER `CIFNO` IN     ***;
*** `XS_LDEDUPED` TABLE ------------------------------------------ ***;
PROC SQL;
	CREATE TABLE XS_LDEDUPED AS
	SELECT *
	FROM XS_L
	GROUP BY CIFNO
	HAVING ENTDATE = MAX(ENTDATE);
QUIT;

*** REMOVE RECORDS WITH DUPLICATE `CIFNO` FROM `XS_LDEDUPED` ----- ***;
PROC SORT 
	DATA = XS_LDEDUPED NODUPKEY; 
	BY CIFNO;
RUN;

*** SORT `BORRNLS` BY `CIFNO` DEFAULT ASCENDING THEN BY            ***;
*** `RMC_UPDATED` DESCENDING ------------------------------------- ***;
PROC SORT 
	DATA = BORRNLS; 
	BY CIFNO DESCENDING RMC_UPDATED; 
RUN;

*** REMOVE RECORDS WITH DUPLICATE `CIFNO` FROM `BORRNLS` --------- ***;
PROC SORT 
	DATA = BORRNLS OUT = BORRNLS2 NODUPKEY; 
	BY CIFNO; 
RUN;

*** MERGE `XS_LDEDUPED` AND `BORRNLS2` BY `CIFNO` AS `LOANNLSXS` - ***;
DATA LOANNLSXS;
	MERGE XS_LDEDUPED(IN = x) BORRNLS2(IN = y);
	BY CIFNO;
	IF x AND y;
RUN;

*** FIND NLS LOANS NOT IN `vw_loan_nls` AND FLAG BAD `SSN`S ------ ***;
DATA LOANEXTRAXS;
	***Subset `dw.vw_loan` using relevant variables -------------- ***;
	SET dw.vw_loan (
		KEEP = OWNST PURCD BRACCTNO ID SSNO1 OWNBR SSNO1_RT7 SSNO2
			NETLOANAMOUNT LNAMT FINCHG LOANTYPE ENTDATE LOANDATE
			CLASSID CLASSTRANSLATION XNO_TRUEDUEDATE FIRSTPYDATE SRCD
			POCD POFFDATE PLCD PLDATE PLAMT BNKRPTDATE BNKRPTCHAPTER
			CONPROFILE1 DATEPAIDLAST APRATE CRSCORE CURBAL);

	*** FILTER `ENTDATE`S GREATER OR EQUAL TO "&_15monthsago",     ***;
	*** `POCD`S THAT ARE NULL, `PLCD`S THAT ARE NULL, `PLDATE`S    ***;
	*** THAT ARE NULL, `POFFDATE`S THAT ARE NULL, AND              ***;
	*** `BNKRPTDATE`S THAT ARE NULL. ----------------------------- ***;
	WHERE ENTDATE >= "&_15monthsago" & 
		  POCD = "" & 
		  PLCD = "" & 
		  PLDATE = "" & POFFDATE = "" & 
		  BNKRPTDATE = "" & 

		  /* FILTER FOR THE FOLLOWING `CLASSID`S: 
		  		`10` RETAIL: SALES FINANCE - FURNITURE CONTRACTS
		  			(PRECOMPUTE)
		  		`19` AUTO-D: SALES FINANCE - SET YOUR OWN PARAMETER
		  		`20` AUTO-I: SALES FINANCE - AUTO (INTEREST BEARING)
		  		`31` RETAIL: SALES FINANCE - FURNITURE CONTRACTS
		  			(INTEREST BEARING)
				`34` AUTO-I: SALES FINANCE - SET YOUR OWN PARAMETER
		  			(INTEREST BEARING) */
		  CLASSID IN (10, 19, 20, 31, 34) & 

		  /* FILTER FOR THE FOLLOWING `OWNST`S: "NC", "VA", "NM", "SC",
		  	 "OK", "TX" */
		  OWNST IN ("NC", "VA", "NM", "SC", "OK", "TX");

	*** CONCATENATE `SSNO1_RT7` WITH THE FIRST 2 NUMBERS IN        ***;
	*** `OWNBR` AND STORE IN NEW VARIABLE, `SS7BRSTATE` ---------- ***;
	SS7BRSTATE = CATS(SSNO1_RT7, SUBSTR(OWNBR, 1, 2));

	*** FLAG BAD `SSNO1`S THAT BEGIN WITH "99" OR "98" AS          ***;
	*** `BADSSN`S ------------------------------------------------ ***;
	IF SSNO1 =: "99" THEN BADSSN = "X";
	IF SSNO1 =: "98" THEN BADSSN = "X";
RUN;

*** EXTRACT `BRACCTNO` FROM `XS_L` AND STORE IN NEW TABLE          ***;
*** `LOAN1_2XS` -------------------------------------------------- ***;
DATA LOAN1_2XS;
	SET XS_L;
	KEEP BRACCTNO;
RUN;

*** SORT `LOAN1_2XS` BY `BRACCTNO` ------------------------------- ***;
PROC SORT 
	DATA = LOAN1_2XS; 
	BY BRACCTNO; 
RUN;

*** SORT `LOANEXTRAXS` BY `BRACCTNO`***;
PROC SORT 
	DATA = LOANEXTRAXS; 
	BY BRACCTNO; 
RUN;

*** MERGE `LOANEXTRAXS` AND `LOAN1_2XS` BY `BRACCTNO` AS           ***;
*** `LOANEXTRA2XS` ----------------------------------------------- ***;
DATA LOANEXTRA2XS;
	MERGE LOANEXTRAXS(IN = x) LOAN1_2XS(IN = y);
	BY BRACCTNO;
	IF x AND NOT y;
RUN;

*** CREATE `LOANPARADATAXS` TABLE FROM `dw.vw_loan` AND FLAG BAD   ***;
*** `SSN`S ------------------------------------------------------- ***;
DATA LOANPARADATAXS;

	*** SUBSET `dw.vw_loan` USING RELEVANT VARIABLES ------------- ***;
	SET dw.vw_loan(
		KEEP = PURCD BRACCTNO XNO_AVAILCREDIT XNO_TDUEPOFF ID OWNBR
			OWNST SSNO1 SSNO2 SSNO1_RT7 LNAMT FINCHG LOANTYPE ENTDATE
			LOANDATE CLASSID CLASSTRANSLATION XNO_TRUEDUEDATE
			FIRSTPYDATE SRCD POCD POFFDATE PLCD PLDATE PLAMT BNKRPTDATE
			BNKRPTCHAPTER DATEPAIDLAST APRATE CRSCORE NETLOANAMOUNT
			XNO_AVAILCREDIT XNO_TDUEPOFF CURBAL CONPROFILE1);

	*** FILTER `ENTDATE`S GREATER OR EQUAL TO "&_15monthsago",     ***;
	*** `PLCD`S THAT ARE NULL, `POCD`S THAT ARE NULL, `POFFDATE`S  ***;
	*** THAT ARE NULL, `PLDATE`S THAT ARE NULL, AND `BNKRPTDATES`S ***;
	*** THAT ARE NULL. ------------------------------------------- ***;
	WHERE ENTDATE >= "&_15monthsago" & 
		  PLCD = "" & 
		  POCD = "" & 
		  POFFDATE = "" &
		  PLDATE = "" & 
		  BNKRPTDATE = "" & 

		  /* FILTER FOR THE FOLLOWING `OWNST`S: "NC", "VA", "NM", "SC",
		  		"OK", "TX" */
		  OWNST NOT IN ("NC", "VA", "NM", "SC", "OK", "TX") & 

		  /* FILTER FOR THE FOLLOWING `CLASSID`S: 
		  		`10` RETAIL: SALES FINANCE - FURNITURE CONTRACTS
		  			(PRECOMPUTE)
		  		`19` AUTO-D: SALES FINANCE - SET YOUR OWN PARAMETER
		  		`20` AUTO-I: SALES FINANCE - AUTO (INTEREST BEARING)
		  		`31` RETAIL: SALES FINANCE - FURNITURE CONTRACTS
		  			(INTEREST BEARING)
				`34` AUTO-I: SALES FINANCE - SET YOUR OWN PARAMETER
		  			(INTEREST BEARING) */
		  CLASSID IN (10, 19, 20, 31, 34);
	
	*** CONCATENATE `SSNO1_RT7` WITH THE FIRST 2 NUMBERS IN        ***;
	*** `OWNBR` AND STORE IN NEW VARIABLE, `SS7BRSTATE` ---------- ***;
	SS7BRSTATE = CATS(SSNO1_RT7, SUBSTR(OWNBR, 1, 2));
	
	*** FLAG BAD `SSNO1`S THAT BEGIN WITH "99" OR "98" AS          ***;
	*** `BADSSN`S ------------------------------------------------ ***;
	IF SSNO1 =: "99" THEN BADSSN = "X";
	IF SSNO1 =: "98" THEN BADSSN = "X"; 
RUN;

*** TO CREATE A TABLE OF RECORDS NOT IN `vw_Loan_NLS`, CONCATENATE ***;
*** `LOANPARADATAXS` AND `LOANEXTRA2XS` TABLES AND STORE IN        ***;
*** `SET1XS` ----------------------------------------------------- ***;
DATA SET1XS;
	SET LOANPARADATAXS LOANEXTRA2XS;
RUN;

DATA BORRPARADATA;
	LENGTH FIRSTNAME $20 MIDDLENAME $20 LASTNAME $30;
	SET dw.vw_borrower(
		KEEP = RMC_UPDATED PHONE CELLPHONE CIFNO SSNO SSNO_RT7 FNAME
			   LNAME ADR1 ADR2 CITY STATE ZIP BRNO AGE CONFIDENTIAL
			   SOLICIT CEASEANDDESIST CREDITSCORE);
	FNAME = STRIP(FNAME);
	LNAME = STRIP(LNAME);
	ADR1 = STRIP(ADR1);
	ADR2 = STRIP(ADR2);
	CITY = strip(city);
	State=STRIP(STATE);
	ZIP = STRIP(ZIP);
	IF FIND(FNAME, "JR") GE 1 THEN DO;
		FIRSTNAME = COMPRESS(FNAME, "JR");
		SUFFIX = "JR";
	END;
	IF FIND(FNAME, "SR") GE 1 THEN DO;
		FIRSTNAME = COMPRESS(FNAME, "SR");
		SUFFIX = "SR";
	END;
	IF SUFFIX = "" THEN DO;
		FIRSTNAME = SCAN(FNAME, 1, 1);
		MIDDLENAME = CATX(" ", SCAN(FNAME, 2, " "), 
						  SCAN(FNAME, 3, " "), SCAN(FNAME, 4, " "));
	END;
	NWORDS = COUNTW(FNAME, " ");
	IF NWORDS > 2 & SUFFIX NE "" THEN DO;
		FIRSTNAME = SCAN(FNAME, 1, " ");
		MIDDLENAME = SCAN(FNAME, 2, " ");
	END;
	DOB = COMPRESS(AGE, "-");
	SS7BRSTATE = CATS(SSNO_RT7, SUBSTR(BRNO, 1, 2));
	LASTNAME = LNAME;
	IF SSNO =: "99" THEN BADSSN = "X"; /* FLAG BAD SSNS */
	IF SSNO =: "98" THEN BADSSN = "X"; 
	DROP NWORDS FNAME LNAME AGE;
	SSNO1 = SSNO;
	SSNO1_RT7 = SSNO_RT7;
RUN;

DATA GOODSSN_LXS BADSSN_LXS;
	SET SET1XS;
	IF BADSSN ="X" THEN OUTPUT BADSSN_LXS;
	ELSE OUTPUT GOODSSN_LXS;
RUN;