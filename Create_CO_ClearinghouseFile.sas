%inc "N:\Administrative\InstRes\Chads\SAS Snips\saslib\Formats\Formats\pods_termsem.sas";
/*
	Ellucian Banner --> This is our student information system.

	Information taken from Student Clearinghouse file upload 
	document. 

	For Cohort (CO) inquiry: Enter the midpoint date of the
	cohorts first semester (YYYYMMDD). For example, enter
	September 15, 2001 as 20010915 for the fall 2001 semester.
	We will search for enrollment for the cohort with terms ending
	subsequent to this date.
*/
%put | ;
%put | createClearingHouseCOfile(ds, folderLoc); 
%put | ---- This macro creates and output file that can be loaded into ;
%put | ---- the student clearninghouse ftp site. This is only a CO inquiry.;
%put | ds = The name of input the dataset; 
%put | ---- This dataset must contain person_uid and term_code fields.;
%put | -------- Multiple terms are allowed.;
%put | -------- The filename will be based on the last term in the dataset.;
%put | ---- This macro will create an output file in the specified folder.;
%put | folderLoc = This is the folder location of the generated output file.;
%put | ---- Trailing slash is optional. ;
%put | ;
%macro createClearingHouseCOfile(ds, folderLoc);
	%local outputFile;
	%let outputFile=;

	* grab data from person data from pods person table. ;
	Proc SQL;
		create table person as
		select A.person_uid, A.term_code, B.id_number, B.last_name, B.first_name, B.middle_initial, 
			compress(B.NAME_SUFFIX, " .") as name_suffix, 
			left(put(B.birth_date, datetime20.)) as birth_date_pods
		from &ds A, pods.mst_person B
		where A.person_uid = B.person_uid;
	Quit;

	* put the most recent term code at the top. ;
	* this will insure that the name of the file is the most recent term in the dataset. ;
	Proc Sort data=person; by descending term_code; Run;

	* process the person data into clearinghouse data. ;
	Data cohort (drop=day month year birth_date_pods search_term_desc search_year search_term_type folder last_char filename);
		record_type = "D1";	
		school_code = "001963";
		branch_code = "00";
		set person;

		* compile the birth day in the right order ;
		* this can be re-written to use dates and month, day, year functions. ;
		length day $2 month $3 year $4;
		day = substr(birth_date_pods, 1, 2);
		month = substr(birth_date_pods, 3, 3);
		year = substr(birth_date_pods, 6, 4);
		if      upcase(month) = "JAN" then month = "01";
		else if upcase(month) = "FEB" then month = "02";
		else if upcase(month) = "MAR" then month = "03";
		else if upcase(month) = "APR" then month = "04";
		else if upcase(month) = "MAY" then month = "05";
		else if upcase(month) = "JUN" then month = "06";
		else if upcase(month) = "JUL" then month = "07";
		else if upcase(month) = "AUG" then month = "08";
		else if upcase(month) = "SEP" then month = "09";
		else if upcase(month) = "OCT" then month = "10";
		else if upcase(month) = "NOV" then month = "11";
		else if upcase(month) = "DEC" then month = "12";
		birthDate = trim(year) || trim(month) || trim(day);

		* compile the search date based on the term ;
		search_term_desc = put(term_code, $termsem.);
		search_year = scan(search_term_desc, 2, " ");
		search_term_type = scan(search_term_desc, 1, " ");
		if search_term_type = "Fall" then
			searchDate = trim(search_year) || "1015";
		else if search_term_type = "Spring" then
			searchDate = trim(search_year) || "0315";
		else if search_term_type = "Summer" then
			searchDate = trim(search_year) || "0801";
		else if search_term_type = "Winter" then
			searchDate = trim(search_year) || "1231";

		* compile the return field - this is pidm_termCode_EKUID ;
		length return_field $50;
		return_field = trim(term_code) || "_" || trim(id_number) || "_" || trim(left(put(person_uid, 10.)));

		* create the output file name, trailing slash in folder is optional ;
		if _N_ = 1 then do;
			folder = &folderLoc;
			last_char = substr(folder, length(folder), 1);
			if last_char = "\" then
				filename = trim(folder) || "\001963_" || trim(term_code) || "_" || compress(search_term_desc, ' ') || "_CO.dat";
			else
				filename = trim(folder) || "\001963_" || trim(term_code) || "_" || compress(search_term_desc, ' ') || "_CO.dat";
			call symput("outputfile", filename);
		end;
	Run;
	%put NOTE: Output Filename will be &outputfile;
	
	* Get the record count ;
	Proc SQL noprint;
	  select count(Record_Type) into :co_count from cohort;
	Quit;
	%put cohort count = &co_count;
	%let total_co_count = %eval(&co_count + 2);  * add 2 for the header and trailer records ;
	
	
	* Output to a file ;
	Data _null_;
	  set cohort;
	  by record_type;   * all RecordType should have value of D1;
	  file "&outputFile" LRECL=500;  * needed to set the maximum record length to 500 spaces;

	   * output the header record; 
	  if first.record_type then do;
		date01 = today();
		year = year(date01);
		
		month = month(date01);
		if month < 10 then 
			m2 = "0" || put(month, 1.);
		else 
			m2 = put(month, 2.);
			
		day = day(date01);
		if day < 10 then 
			d2 = "0" || put(day, 1.);
		else 
			d2 = put(day, 2.);
			
		creation_date = put(year, 4.) || m2 || d2;
		
		H1 = "H1";
		H2 = "001963";
		H3 = "00";
		H4 = "Eastern Kentucky University";
		H5 = creation_date;
		H6 = "CO";
		H7 = "I";
		FillerLeaveBlank = "";
		put H1 1-2 H2 3-8 H3 9-10 H4 11-50 H5 51-58 H6 59-60 H7 61 FillerLeaveBlank 62-500;
	  end;

	  * output the regular records;
	  put Record_Type 1-2
		First_Name 12-31
		Middle_Initial 32
		Last_Name 33-52
		Name_Suffix 53-57
		BirthDate 58-65
		SearchDate 66-73
		School_Code 75-80
		Branch_Code 81-82
		Return_Field 83-132
		FillerLeaveBlank 133-500;

	  if last.record_type then do;
		T1 = "T1";
		T2 = trim("&total_co_count");
		put T1 1-2 T2 3-10 FillerLeaveBlank 11-500;
	  end;
	Run;
%mend;
