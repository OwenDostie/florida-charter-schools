# Add school grades & performance measures to the dataset


# load data
sg14 <- fread("src/school_grades/School_Grades_1999-2014_v2.csv", integer64 = "double") %>% as.data.table
sg19 <- fread("src/school_grades/School_Grades_2015-2019_v2.csv", integer64 = "double") %>% as.data.table

# school grades refer to the year at the end of the schoolyear, our data refers to the beginning of the schoolyear so to have the 
# merge work properly subtracting 1 from the year of the school grades makes sense. We don't care about grades in 1998
sg14$Year <- sg14$Year-1; sg19$Year <- sg19$Year-1; sg14 <- sg14[Year >= 1999]

# fix a couple of issues with sg19, including some duplicate rows that I don't know the source of
sg19[,Grade := `Grade in Year tested`]; sg19 <- unique(sg19)

# create distnum_schnum
sg19[,distnum_schnum := paste0(str_pad(`District Number`, 2, side="left", pad=0),"-", str_pad(`School Number`, 4, side="left", pad=0))]
sg14[Year%!in%c(2002,2003),distnum_schnum := paste0(str_pad(`District Number`, 2, side="left", pad=0),"-", str_pad(`School Number`, 4, side="left", pad=0))]
sg14[Year%in%c(2002,2003),distnum_schnum := (paste0(str_pad(`School Number`, 6, side="left", pad=0) %>% substr(1,2),"-", str_pad(`School Number`, 6, side="left", pad=0) %>% substr(3,6))) ]


# clean columns; create keys
setnames(sg14, names(sg14), gsub(" ","_",tolower(names(sg14)))); setnames(sg19, names(sg19), gsub(" ","_",tolower(names(sg19))))

# create ncessch_new in sg14 to capture whether a school had multiple grade levels at the same time
# and it was stored as several observations in the data
sg14[sg14[by=c("year","distnum_schnum"),,.N][N!=1], ncessch_suffix:=c("_e","_m","_h","_c")[school_type], on=c("year","distnum_schnum") ]

# drop irrelevant columns
sg19[,c("district_name","district_number","school_number","school_name","school_type","region","charter_school"):=NULL]
sg14[,c("district_name","district_number","school_number","school_name","school_type"):=NULL]

# merge the two school grades files
setkey(sg19,distnum_schnum,year); setkey(sg14,distnum_schnum,year)
sg <- merge(sg19,sg14,all=T)
sg[,`:=`(  comb_school_grade=coalesce(grade.x,grade.y), percent_tested = coalesce(percent_tested.x,percent_tested.y)  )]
sg[,names(sg)[grep("\\.[xy]",names(sg))] := NULL]
(df[,setdiff(names(sg),c("distnum_schnum","year")):=NULL])

# merge them with df, this will add rows; create ncessch_new
setkey(df,distnum_schnum,year); setkey(sg,distnum_schnum,year)
df <- merge(df,sg,all.x=T)
df[is.na(ncessch_new),ncessch_new:=paste0(ncessch,replace_na(ncessch_suffix,""))]
df[ncessch_suffix=="_e",c(paste0("grade",c(6:12),"_enr")):=0]
df[ncessch_suffix=="_m",c(paste0("grade",c(1:5,9:12),"_enr")):=0]
df[ncessch_suffix=="_h",c(paste0("grade",c(1:8),"_enr")):=0]
df[ncessch_suffix %in% c("_m","_h"), "k_enr":=0]
df[,ncessch_suffix:=NULL]

# Performance measures ----
names(df)

# math_proficiency
df[,comb_math_proficiency:=coalesce(math,percent_level_3_and_above_fcat_math)]

# ela proficiency
df[,comb_ela_proficiency:=coalesce(english_language_arts, rowMeans(matrix(c(percent_level_3_and_above_fcat_reading, percent_level_3_and_above_writing),ncol=2,byrow=F), na.rm=T))]

# ela_gains
df[,comb_ela_gains:=coalesce(english_language_arts_gains, percente_making_learning_gains_in_reading)]
df[,comb_math_gains:=coalesce(math_gains, percente_making_learning_gains_in_math)]
df[,comb_ela_gains_lowest_25:=coalesce(`english_language_arts_gains_of_lowest_25%`, percent_of_lowest_25p_making_learning_gains_in_reading)]


# Validation ----


if (nrow(df) != 61744) warning("\nThere's not 61744 rows in df which is what was expected after creating ncessch_new column")
if (df[by=year,,sum(!is.na(comb_ela_proficiency))][V1==0,nrow(.SD)] > 0) warning("\nSome years have no values for comb_ela_proficiency")
if (sg[nchar(distnum_schnum) != 7] %>% nrow() > 0) warning("\nNot all distnum_schnum are 7 characters")
