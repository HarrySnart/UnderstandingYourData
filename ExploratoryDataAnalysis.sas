*Define Caslib; 
libname casuser cas;

*Load dataset into memory;
proc sql;
create table casuser.hmeq(replace=yes) as select *,put(bad,1.) as BAD_CLASS FROM  '/home/Demo/hmeq.sas7bdat';
quit;

*Generate correlation and EDA datasets using dataSciencePilot;
proc cas;
	*Load CAS Action Set;
	
	loadactionset "dataSciencePilot";
	
	*Explore Correlation in HMEQ dataset;
	dataSciencePilot.exploreCorrelation / table="HMEQ" 
		casOut={name="HMEQ_INFORMATION_GAIN", replace=True} 
		stats={nominalNominal={"mi"}, 
		nominalInterval={"mi"}, 
		intervalInterval={"mi"}} 
		inputs={{name="BAD_CLASS"}, {name="CLAGE"}, {name="CLNO"},{name="DEBTINC"}, 
				{name="DELINQ"}, {name="DEROG"}, {name="JOB"}, {name="LOAN"}, 
				{name="MORTDUE"}, {name="NINQ"}, {name="REASON"}, {name="VALUE"}, {name="YOJ"}} 
		nominals={"JOB", "REASON",'BAD_CLASS'};
	run;
	
	*Explore Dataset;	
   dataSciencePilot.exploreData / table          = "HMEQ"
                              casOut             = {name    = "HMEQ_EXPLORE", replace = True}
                              target             = "BAD_CLASS"
                              explorationPolicy  = {};
   run;
quit;


*Define ODS settings;
filename odsout "/home/Demo/EDA.html" mod;
filename odp "/home/Demo/";
ods _all_ close;
ods listing image_dpi=500;
ods graphics on / imagemap  noborder  outputfmt=svg; /* enable data tips */


* add html content ; 
data _null_;
     file odsout;
     put '<html>';
	put '<link rel="icon" href="https://www.sas.com/etc/designs/saswww/favicon.ico">';
     put '<HEAD>';
	 put '<center><img src="https://www.sas.com/en_gb/software/viya/_jcr_content/par/styledcontainer_5560/par/styledcontainer_faf2/par/styledcontainer_b1f3/par/image_412b.img.png/1592920282272.png" alt="logo"/></center>';
     put '<TITLE>EDA Output</TITLE>';
	 put '<head><link rel="stylesheet" href="mystyle2.css"></head>';
     put '</HEAD>';
     put "<BODY class='body'>";
     put '<h1><center>Exploratory Data Analysis for HMEQ Dataset</h1>';
	 put '<h2><center>This report analyses key summary statistics for the HMEQ dataset in order to evaluate best features for building a predictive model</h2>';
	 put '<br></br>';
   run;

*Create report;
ods html5 path=odp body=odsout(notop)  style=raven options(svg_mode='inline') ;


*View a sample of the data;
ods text='<h2 style = "color:#eeeeee"><u><b><center>Sample of Dataset</center></u></b>
</h2>';
footnote1 italic 'We have a mix of categorical and numeric inputs, with incomplete observations in the dataset';
proc print data=casuser.hmeq (obs=5);run;


*Summary Statistics;

ods text='<h2 style = "color:#eeeeee"><u><b><center>Summary Statistics for Numerical Features by Class</center></u></b>
</h2>';
footnote1 italic 'Our positive class only represents around 20% of the dataset. ';
footnote2 italic 'All numeric attributes appear to have a wide range of values.';
footnote3 italic 'There may be outliers in the dataset as the mean and median is often quite different';
proc means data=casuser.hmeq chartype mean std min max median n nmiss 
		vardef=df qmethod=os;
	var LOAN MORTDUE VALUE YOJ DEROG DELINQ CLAGE NINQ CLNO DEBTINC;
	by BAD_CLASS;
run;


*Explore linear correlation between Interval Measures by Target;

ods text='<h2 style = "color:#eeeeee"><u><b><center>Pairplot Analysis of Interval Features</center></u></b>
</h2>';

footnote1 italic 'There appears to be collinearity between the outstanding Mortgage amount and Value amount. The numeric attributes are skewed and may benefit from transformation.\n There is no visible difference between the scatter plots for the BAD class';
proc sgscatter data=casuser.hmeq; 
matrix Loan Mortdue Value /group=BAD_CLASS diagonal=(histogram kernel);
run;


*Generate Panel Frequency Plot;
ods text='<h2 style = "color:#eeeeee"><u><b><center>Frequency Analysis of Categorical Features</center></u></b>
</h2>';

footnote1 italic 'For both event levels most observations list OTHER as job role. In both cases the majority of loans are for Debt Consolidation. Missing values do not appear related to the event level so may be missing at random.';
*Replace nulls with missing label for plotting;
data casuser.hmeq_freq_input;
set casuser.hmeq;
if reason = '' then reason='Missing';
if job = '' then job = 'Missing';
run;

*Generate Frequencies by Category;
proc freq data=casuser.hmeq_freq_input noprint;
	tables REASON * JOB  / nocum out=casuser.freq  outexpect sparse;
	by BAD_CLASS;
run;

*Plot Frequencies in single panel plot;
proc sgpanel data=casuser.freq;
panelby bad_class;
vbar job /
    response=count
    stat=percent
 group=reason
CATEGORYORDER=RESPASC;
run;

*Explore Mutual Information Gain for all Inputs;

PROC SQL ;
CREATE TABLE WORK.BARPLOT AS select
CASE WHEN FIRSTVARIABLE = 'BAD_CLASS' THEN SECONDVARIABLE ELSE FIRSTVARIABLE END AS FEATURE,
MI FROM CASUSER.HMEQ_INFORMATION_GAIN WHERE FIRSTVARIABLE = 'BAD_CLASS' OR SECONDVARIABLE='BAD_CLASS';
QUIT;

ods text='<h2 style = "color:#eeeeee"><u><b><center>Information Gain by Feature</center></u></b>
</h2>';

footnote1 italic 'DELINQ DEROG and DEBTINC appear to have them most explanatory value for BAD. The job and reason for the loan appears to not be very important, which is consistent with our frequency plot';
*interactive bar plot;
proc sgplot data=WORK.BARPLOT;
  vbar FEATURE /
    response=MI
    stat=SUM
CATEGORYORDER=RESPASC;
run;

ods html5 close;
