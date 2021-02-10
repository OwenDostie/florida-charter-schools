

# Lookup function ----


# takes about 30 seconds per 50 lookups
# init address list
# adl <- unique(df[!is.na(street_location) & !is.na(city_location),
#                  .(street_location,city_location)])
# adl[,gm_formatted_address:=as.character(NA)]

# if (file.exists("src/gm_addresses.csv", na.strings = "") & T) { gm <- fread("src/gm_addresses.csv"); warning("gm was loaded from a file") } else
#   if (F) {
#     adl <- fread("src/gm_addresses.csv", na.strings = "")
#     adl[,street_location:=str_replace_all(street_location, "\\.|\\,|\\#", "")]
#     adl$gm_street_number <- as.character(adl$gm_street_number); adl$gm_postal_code <- as.character(adl$gm_postal_code)
#     for (row in 1:nrow(adl)) {
#       if (!is.na(adl[row,gm_formatted_address])) next
#       rs <- googleway::google_geocode(address = paste0(adl[row,.(street_location,city_location,"FL")],collapse = ", "),
#                                       key = "AIzaSyCbtZ1HhyXnHcY2c5AFM5xHH2OV6UvxSYU",
#                                       bounds = list(c(24.761501,-87.683950),c(31.062565,-79.726350)))[[1]][1,]
#       adl[row,gm_lat:=rs$geometry$location$lat%||%NA[1]]
#       adl[row,gm_lon:=rs$geometry$location$lng%||%NA[1]]
#       adl[row,gm_formatted_address:=rs$formatted_address%||%NA]
#       adl[row,gm_street_number:=rs$address_components[[1]]$short_name[which(rs$address_components[[1]]$types == "street_number")]%||%NA %>% paste0("")]
#       adl[row,gm_route:=rs$address_components[[1]]$short_name[which(rs$address_components[[1]]$types == "route")]%||%NA %>% paste0("")]
#       adl[row,gm_postal_code:=rs$address_components[[1]]$short_name[which(rs$address_components[[1]]$types == "postal_code")]%||%NA %>% paste0("")]
#       if (row %% 50 == 0) { warning(paste0("Completed row ", row," --- ")); tictoc::toc(); tictoc::tic()
#         fwrite(adl,"src/gm_addresses.csv"); warning("wrote the new addresses to the file")
#         }
#     }
#     fwrite(adl,"src/gm_addresses.csv"); warning("wrote the new addresses to the file")
#   }


# Round 2 lookup with zipcode


# takes about 30 seconds per 50 lookups
# init address list
# df[gm_formatted_address %!in% lva$gm_formatted_address & gm_formatted_address %!in% zva$gm_formatted_address,.(old_gmfa = first(gm_formatted_address)),by=c("street_location","city_location","zip_location")] %>% as.data.table -> adl
# adl[,gm_formatted_address:=as.character(NA)]
# if (file.exists("src/gm_addresses2.csv", na.strings = "") & T) { gm <- fread("src/gm_addresses2.csv"); warning("gm was loaded from a file") } else
#   if (F) {
#     # adl <- fread("src/gm_addresses2.csv", na.strings = "")
#     # adl[,street_location:=str_replace_all(street_location, "\\.|\\,|\\#", "")]
#     # adl$gm_street_number <- as.character(adl$gm_street_number); adl$gm_postal_code <- as.character(adl$gm_postal_code)
#     for (row in 1:nrow(adl)) {
#       if (!is.na(adl[row,gm_formatted_address])) next
#       rs <- googleway::google_geocode(address = paste0(adl[row,.(street_location,city_location,"FL",zip_location)],collapse = ", "),
#                                       key = "AIzaSyCbtZ1HhyXnHcY2c5AFM5xHH2OV6UvxSYU",
#                                       bounds = list(c(24.761501,-87.683950),c(31.062565,-79.726350)))[[1]][1,]
#       adl[row,gm_lat:=rs$geometry$location$lat%||%NA[1]]
#       adl[row,gm_lon:=rs$geometry$location$lng%||%NA[1]]
#       adl[row,gm_formatted_address:=rs$formatted_address%||%NA]
#       adl[row,gm_street_number:=rs$address_components[[1]]$short_name[which(rs$address_components[[1]]$types == "street_number")]%||%NA %>% paste0("")]
#       adl[row,gm_route:=rs$address_components[[1]]$short_name[which(rs$address_components[[1]]$types == "route")]%||%NA %>% paste0("")]
#       adl[row,gm_postal_code:=rs$address_components[[1]]$short_name[which(rs$address_components[[1]]$types == "postal_code")]%||%NA %>% paste0("")]
#       if (row %% 50 == 0) { warning(paste0("Completed row ", row," --- ")); tictoc::toc(); tictoc::tic()
#         fwrite(adl,"src/gm_addresses2.csv"); warning("wrote the new addresses to the file")
#       }
#     }
#     fwrite(adl,"src/gm_addresses2.csv"); warning("wrote the new addresses to the file")
#   }
# tictoc::toc()


# ROund 3 lookup using school_name ----


# t_names <- data.table(name = as.character(NA), name_original = df$school_name %>% unique(), gm_lat = as.numeric(NA),gm_lon = as.numeric(NA), gm_address = as.character(NA), gm_name = as.character(NA))
# t_names$name <- gsub("\\-|\\,|\\:|\\.|\\(|\\)|\\@|\\/|\\&|\\&|\\#|\\`","",t_names$name_original)
# df[,.(mzip=head(names(sort(table(zip_location),dec=T)),1)),by=school_name]
# t_names <- merge(t_names,df[,.(mzip=head(names(sort(table(zip_location),dec=T)),1)),by=school_name],all.x=T,by.x="name_original",by.y="school_name")
# tictoc::tic()
# for (i in 1:nrow(t_names)) {
#   if (T) next
#   if (!is.na(t_names[i,gm_address])) next
#   q <- googleway::google_geocode(address = paste0(t_names[i,.(name,mzip,"FL")],collapse = " "),
#                                  key = "AIzaSyCbtZ1HhyXnHcY2c5AFM5xHH2OV6UvxSYU",
#                                  bounds = list(c(24.761501,-87.683950),c(31.062565,-79.726350)))
#   if (q$status == "ZERO_RESULTS") next
#   q <- q[[1]][1,]
#   t_names[i, gm_lat:=q$geometry$location$lat%||%NA[1]]
#   t_names[i, gm_lon:=q$geometry$location$lng%||%NA[1]]
#   t_names[i, gm_address:=q$formatted_address%||%NA]
#   if (i %% 50 == 0) { warning(paste0("\nCompleted row ", row," --- ")); tictoc::toc(); tictoc::tic()
#     fwrite(t_names,"src/gm_addresses3.csv")
#   }
# }

# Read from a file ----


adl <- fread("src/gm_addresses.csv", na.strings = "") %>% as.data.table()
df <- merge(df,adl,by=c("street_location","city_location"),all.x=T)
