
# Create key_sch ----------------------------------------------------------


# zero pad and split sg2014 district and school number
# fix issue where district number is reported in the school number field
sg2014$`District Number`[nchar(sg2014$`School Number`) > 4] <- str_pad(sg2014$`School Number`[nchar(sg2014$`School Number`) > 4],6,pad=0) %>% substr(.,1,2)
sg2014$`District Number` <- str_pad(sg2014$`District Number`,2 ,pad=0)
sg2014$`School Number` <- substr(sg2014$`School Number`, nchar(sg2014$`School Number`)-3, nchar(sg2014$`School Number`)) %>%
  str_pad(.,4,pad=0)

# zero pad and split sg2017 district and school number
sg2017$`District Number` <- sg2017$`District Number` %>% str_pad(.,2, pad = 0)
sg2017$`School Number` <- sg2017$`School Number` %>% str_pad(.,4, pad = 0)

# create distnum_schnum and then key sch for both
sg2014$distnum_schnum <- sg2014[,paste0(`District Number`,"-",`School Number`)]
sg2017$distnum_schnum <- sg2017[,paste0(`District Number`,"-",`School Number`)]
sg2014$key_sch <- sg2014[,paste0(`distnum_schnum`,"_",`Year`)]
sg2017$key_sch <- sg2017[,paste0(`distnum_schnum`,"_",`Year`)]

# Rename columns ----------------------------------------------------------


names(sg2017)
# Data validation ---------------------------------------------------------


# make sure if there's no NA values
if (sum(is.na(sg2014$`District Number`) | is.na(sg2014$`School Number`) | is.na(sg2014$`District Number`) | is.na(sg2014$`School Number`)) != 0)
  stop("There are missing district or school numbers in the school grades dataset")

# make sure they have the correct number of digits
if (nchar(sg2014$`District Number`) %>% max(na.rm=T) != 2 |
    nchar(sg2014$`School Number`) %>% max(na.rm=T) != 4 |
    nchar(sg2017$`District Number`) %>% max(na.rm=T) != 2 |
    nchar(sg2017$`School Number`) %>% max(na.rm=T) != 4 |
    nchar(sg2014$`District Number`) %>% min(na.rm=T) != 2 |
    nchar(sg2014$`School Number`) %>% min(na.rm=T) != 4 |
    nchar(sg2017$`District Number`) %>% min(na.rm=T) != 2 |
    nchar(sg2017$`School Number`) %>% min(na.rm=T) != 4)
  stop("School grades district or school number have incorrect number of digits")