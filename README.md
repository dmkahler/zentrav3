# Zentra Cloud v3 Downloads  
The Zentra Cloud documentation is available: https://docs.zentracloud.com/l/en/article/gbv2iyxhar-api-v-3-0.
## Get API token and address  
To begin, sign in to [Zentra Cloud](https://zentracloud.com/) and click on the `API` button on the menu on the left.  You may have API tokens to use or you may need to `Add New API Key`.  Copy, by clicking the copy button on the right of the field, the token you wish to use for this purpose.  
## Get Curl command  
Go to the Zentra Cloud [API page](https://zentracloud.com/api/v3/documentation/) to generate the custom Curl command to retrieve your data.  On the right, click on the `Authorize` button.  On the pop-up screen, paste the entire token you copied from your account page.  This text **should** contain the word, 'Token'.  Then click `Authorize` and `Close`.  Later, use the `Logout` button to switch to another API key, if needed.  In the *Reading* section, enter the device serial number and either the start date or the start mrid value (for simplicity, I recommend only using one of those).  You may also enter an end date or end mrid value.  You should select your output format:  
- comma-separated values (csv)  
- pandas DataFrame (df)  
- json output (json)  

Also, you will likely want to change the number of readings returned to 2000 (the maximum) or it will only give you 500.  Select ascending or descending order.  When you have your settings loaded into the fields, click on `Execute` at the bottom and copy the Curl code to the terminal window.  
## Excecute the Curl command  
To save the output, use the `>` command.  

```
curl -X GET "https://zentracloud.com/api/v3/get_readings/?device_sn=<YOUR SERIAL NUMBER HERE>&start_mrid=<YOUR START MRID>&output_format=csv&per_page=2000&sort_by=ascending" -H  "accept: application/json" -H  "Authorization: Token <YOUR API TOKEN>" > YOUR_OUTPUT_FILE.csv
```

## Use the shell scripts  
This syntax is used in the shell scripts (which are sometimes batch, .bat, files).  To use these codes, you need to make the file executable.  In the terminal, use the chmod command.  

```
chmod +x mutale.sh
```

Execute the shell script such as, `./mutale.sh`.

## Additional Notes  
The script runs fairly quickly; however, there is a limit of one pull per 60 seconds.  Do not query the database more frequently or you can get locked out (temporarily).  Also, if you use the published maximum of 200 records, you will have to pull less than one month at a time; therefore, you may have to pull repeatedly.  


