#!/usr/bin/env Rscript

d <- commandArgs(trailingOnly=TRUE)
site <- d[1]

library(readr)
library(dplyr)
library(tidyr)
library(rjson)
library(lubridate)
library(RCurl)

# Import data
dat <- readr::read_csv("apidownload.csv", skip = 8)
offset <- 2*3600 # UTC offset for SAST is 2 hours

wide <- dat %>%
      select(timestamp_utc,measurement,value) %>%
      pivot_wider(names_from = measurement, values_from = value)
usaid <- wide %>%
      mutate(dt=as_datetime(timestamp_utc)) %>%
      mutate(yr=year(dt+offset), mo=month(dt+offset), da=day(dt+offset), hr=hour(dt+offset), mn=minute(dt+offset)) %>%
      # FOR USAID: YEAR, MNTH, DAYN, HOUR, MINU, PRCP, SRAD, TEMP, RHMD, APRS, WSPD, WDIR
      mutate(at=(`Air Temperature`+273.15)) %>% # convert air temperature to Kelvin
      mutate(svp=(6984.505294+at*(-188.903931+at*(2.133357675+at*(-0.01288580973+at*(0.00004393587233+at*(-0.00000008023923082+at*6.136820929E-11))))))/10) %>% # compute saturation vapor pressure in kPa via the Goff-Gratch equation, in nested form (Lowe, 1977; Brutsaert, 2005)
      mutate(vp=`Vapor Pressure`) %>% # import vapor pressure in kPa
      mutate(PRCP=Precipitation, SRAD=`Solar Radiation`, TEMP=`Air Temperature`, RHMD=round(100*(vp/svp), digits = 1), APRS=`Atmospheric Pressure`, WSPD=`Wind Speed`, WDIR=`Wind Direction`) %>%
      select(yr,mo,da,hr,mn,PRCP,SRAD,TEMP,RHMD,APRS,WSPD,WDIR)

hl <- c("YEAR", "MONT", "DAYN", "HOUR", "MINU", "PRCP", "SRAD", "TEMP", "RHMD", "APRS", "WSPD", "WDIR")

if (site == "mutale") {
      usaid <- usaid %>%
            mutate(RIVS=(`water`-875)/1000) %>% # measured above the weir crest, to coincide with the staff gage at the weir, sensor is located 0.875 m below the weir crest, converted to m from mm
            mutate(WTMP=`water temp`) %>%
            mutate(COND=1000 * conductivity) %>% # convert from mS/cm to uS/cm.
            mutate(TRBD=-8888)
      hl <- c("YEAR", "MONT", "DAYN", "HOUR", "MINU", "PRCP", "SRAD", "TEMP", "RHMD", "APRS", "WSPD", "WDIR", "RIVS", "WTMP", "COND", "TRBD")
}

today <- Sys.Date()
hl <- data.frame(hl)
write_csv(hl, paste0(site, "_", today, ".usaid.csv"), append = TRUE, eol = "\n") # writes headers
write_csv(usaid, paste0(site, "_", today, ".usaid.csv"), na = "NA", append = TRUE, eol = "\n") # writes data, UNIX standard end of line, comma-delimited, decimal point used "."

# Log data download
tracker <- array("NA", dim=c(1,6))
tracker[1,1] <- paste(as.character(as_datetime(now(), "UTC")), "UTC") # the current/download time in UTC
tracker[1,2] <- as.character(min(dat$mrid)) # record start reference
start <- min(dat$timestamp_utc)
tracker[1,3] <- paste(as.character(as_datetime(start)), "UTC") # first date/time in download, in date format
no_records <- nrow(usaid)
tracker[1,4] <- as.character(no_records)
end <- max(dat$timestamp_utc)
no_time <- (end-start)/(15*60)+1 # MUST be no_time>=no_records, SHOULD by no_time==no_records
print(paste("Number of time steps:  ",no_time))
print(paste("Number of records:     ",no_records))
tracker[1,5] <- paste(as.character(as_datetime(end)), "UTC") # last date/time in download, in date format
tracker[1,6] <- as.character(max(dat$mrid))
print(paste("Final time downloaded: ",as.character(as_datetime(end)), "UTC"))

# headers: NUM,DOWNLOAD_DATE_TIME,START_MRID,BEGIN_DATE_TIME,NUMBER_OF_RECORDS,END_DATE_TIME,LAST_MRID  
write.table(tracker, file = paste0(site, "_mrid.csv", ""), append = TRUE, sep = ",", dec = ".", col.names = FALSE)

next_mrid <- max(dat$mrid) + 1
next_mrid <- data.frame(next_mrid)
write_csv(next_mrid, file = paste0(site, "_mrid_next.txt", ""), append = FALSE, col_names = FALSE)

