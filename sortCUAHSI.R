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
offsetHRS <- 2
#offset <- offsetHRS*3600 # UTC offset for SAST is 2 hours
mrid_start <- min(dat$mrid)

wide <- dat %>%
      select(timestamp_utc,measurement,value) %>%
      pivot_wider(names_from = measurement, values_from = value)

# Arrange data
if (site == "mutale") {
      cuahsi <- wide %>%
            mutate(LocalDateTime=as.character(as_datetime(timestamp_utc, tz = "Africa/Johannesburg"))) %>%
            mutate(UTCOffset=offsetHRS) %>%
            mutate(DateTimeUTC=as.character(as_datetime(timestamp_utc))) %>%
            mutate(at=(`Air Temperature`+273.15)) %>% # convert air temperature to Kelvin
            mutate(svp=(6984.505294+at*(-188.903931+at*(2.133357675+at*(-0.01288580973+at*(0.00004393587233+at*(-0.00000008023923082+at*6.136820929E-11))))))/10) %>% # compute saturation vapor pressure in kPa via the Goff-Gratch equation, in nested form (Lowe, 1977; Brutsaert, 2005)
            mutate(VPRS=`Vapor Pressure`) %>% # import vapor pressure in kPa
            mutate(PRCP=Precipitation, SRAD=`Solar Radiation`, TEMP=`Air Temperature`, RHMD=round(100*(VPRS/svp), digits = 1), APRS=`Atmospheric Pressure`, WSPD=`Wind Speed`, WDIR=`Wind Direction`) %>%
            mutate(RIVS=(`Water Level`-875)/1000) %>% # measured above the weir crest, to coincide with the staff gage at the weir, sensor is located 0.875 m below the weir crest, converted to m from mm
            mutate(WTMP=`Water Temperature`) %>%
            mutate(COND=1000 * EC) %>% # convert from mS/cm to uS/cm.
            # mutate(TRBD=-8888) %>%
            select(LocalDateTime,UTCOffset,DateTimeUTC,PRCP,SRAD,TEMP,VPRS,RHMD,APRS,WSPD,WDIR,RIVS,WTMP,COND,TRBD) %>%
            pivot_longer(c(PRCP,SRAD,TEMP,VPRS,RHMD,APRS,WSPD,WDIR,RIVS,WTMP,COND,TRBD), names_to = "VariableCode", values_to = "DataValue")
} else {
      cuahsi <- wide %>%
            mutate(LocalDateTime=as.character(as_datetime(timestamp_utc, tz = "Africa/Johannesburg"))) %>%
            mutate(UTCOffset=offsetHRS) %>%
            mutate(DateTimeUTC=as.character(as_datetime(timestamp_utc))) %>%
            mutate(at=(`Air Temperature`+273.15)) %>% # convert air temperature to Kelvin
            mutate(svp=(6984.505294+at*(-188.903931+at*(2.133357675+at*(-0.01288580973+at*(0.00004393587233+at*(-0.00000008023923082+at*6.136820929E-11))))))/10) %>% # compute saturation vapor pressure in kPa via the Goff-Gratch equation, in nested form (Lowe, 1977; Brutsaert, 2005)
            mutate(VPRS=`Vapor Pressure`) %>% # import vapor pressure in kPa
            mutate(PRCP=Precipitation, SRAD=`Solar Radiation`, TEMP=`Air Temperature`, RHMD=round(100*(VPRS/svp), digits = 1), APRS=`Atmospheric Pressure`, WSPD=`Wind Speed`, WDIR=`Wind Direction`) %>%
            select(LocalDateTime,UTCOffset,DateTimeUTC,PRCP,SRAD,TEMP,VPRS,RHMD,APRS,WSPD,WDIR) %>%
            pivot_longer(c(PRCP,SRAD,TEMP,VPRS,RHMD,APRS,WSPD,WDIR), names_to = "VariableCode", values_to = "DataValue")
}

# Log data download
tracker <- array("NA", dim=c(1,6))
tracker[1,1] <- paste(as.character(as_datetime(now(), "UTC")), "UTC") # the current/download time in UTC
tracker[1,2] <- as.character(min(dat$mrid)) # record start reference
start <- min(dat$timestamp_utc)
tracker[1,3] <- paste(as.character(as_datetime(start)), "UTC") # first date/time in download, in date format
no_records <- nrow(usaid)
tracker[1,4] <- as.character(no_records)
end <- max(dat$timestamp_utc)
no_time <- (end-start)/(15*60)+1 # MUST be no_time>=no_records, SHOULD be no_time==no_records
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

# Prep data for CUAHSI HIS upload
# DataValues tab:
# DataValue the value
# LocalDateTime local/SAST date and time in format: string YYYY-MM-DD (guide suggests MM/DD/YYYY)
# UTCOffset time from UTC: +2 for SAST
# DateTimeUTC date and time in UTC 
# SiteCode name of site: mutale or medike
# VariableCode name of variable/measurement
# MethodCode method/instrument: Atmos41 or Hydros21
# SourceCode data source: LimpopoResilienceLab
# QualityControlLevelCode QC level: 0, 1, 2, 3, 4 - all should be 0 except for RH, which is 2

SiteCode = array(site, dim=nrow(cuahsi))
MethodCode = array("", dim=nrow(cuahsi))
SourceCode = array("LimpopoResilienceLab", dim=nrow(cuahsi))
QualityControlLevelCode = array("", dim=nrow(cuahsi))
for (i in 1:nrow(cuahsi)) {
      if ( (cuahsi$VariableCode[i] == "PRCP") | (cuahsi$VariableCode[i] == "SRAD") | (cuahsi$VariableCode[i] == "TEMP") | (cuahsi$VariableCode[i] == "VPRS") | (cuahsi$VariableCode[i] == "APRS") | (cuahsi$VariableCode[i] == "WSPD") | (cuahsi$VariableCode[i] == "WDIR") ) {
            MethodCode[i] <- "Atmos41"
            QualityControlLevelCode[i] <- 0
      } else if (cuahsi$VariableCode[i] == "RHMD") {
            MethodCode[i] <- "Atmos41"
            QualityControlLevelCode[i] <- 2
      } else if (cuahsi$VariableCode[i] == "RIVS") {
            MethodCode[i] <- "Hydros21"
            QualityControlLevelCode[i] <- 2
      }else if ( (cuahsi$VariableCode[i] == "COND") | (cuahsi$VariableCode[i] == "WTMP") ) {
            MethodCode[i] <- "Hydros21"
            QualityControlLevelCode[i] <- 0
      }
}

upload <- data.frame(cuahsi$DataValue,cuahsi$LocalDateTime,cuahsi$UTCOffset,cuahsi$DateTimeUTC,SiteCode,cuahsi$VariableCode,MethodCode,SourceCode,QualityControlLevelCode)
upload <- upload %>%
      rename(
            DataValue=cuahsi.DataValue,
            LocalDateTime=cuahsi.LocalDateTime,
            UTCOffset=cuahsi.UTCOffset,
            DateTimeUTC=cuahsi.DateTimeUTC,
            VariableCode=cuahsi.VariableCode
      )

today <- Sys.Date()
h <- names(upload)
s <- length(h)
hl <- array("a", dim = c(1,s))
for (i in 1:length(h)) {
      hl[1,i] <- h[i]
}
hl <- data.frame(hl)
write_csv(hl, paste0(site, "_", as.character(mrid_start[[1]]), "_", today, ".cuahsi.csv"), append = TRUE, eol = "\n") # writes headers
write_csv(upload, paste0(site, "_", as.character(mrid_start[[1]]), "_", today, ".cuahsi.csv"), na = "NA", append = TRUE, eol = "\n") # writes data, UNIX standard end of line, comma-delimited, decimal point used "."




