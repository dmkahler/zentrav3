#! /bin/bash

read mrid < "mutale_mrid_next.txt"

curl -X GET "https://zentracloud.com/api/v3/get_readings/?device_sn=z6-03792&start_mrid="$mrid"&output_format=csv&per_page=2000&sort_by=ascending" -H  "accept: application/json" -H  "Authorization: Token b8f6a7828d457419b93b8b2d2a6679ea2ddf012b" > apidownload.csv

git pull

Rscript sortCUAHSI.R "mutale"

git add mutale_mrid.csv
git add mutale_mrid_next.txt
git commit -m "updated logs - Mutale"
git push

