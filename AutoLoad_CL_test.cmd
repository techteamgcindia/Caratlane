move "D:\SymphonyData\HistoryFolder\"*.* "D:\SymphonyData\History_Folder_Archive"


sqlcmd -S localhost -U sa -P Supp!y_99$ -d SymphonyCL -Q "EXEC [dbo].[Client_SP_STATUS_RESET]"


cd "C:\Program Files\Symphony\Symphony Auto Load\" 
AutoLoadFiles.exe -DB=SYMPHONYCL



sqlcmd -S localhost -U sa -P Supp!y_99$ -d SymphonyCL -Q  "[dbo].[Client_SP_OUTPUT_MTAR]"


move "D:\SymphonyData\CustomReports\Output_Script\"WH_Barcode_stock*.* "D:\SymphonyData\CustomReports\Output_Script\Archive\"


sqlcmd -S localhost -U sa -P Supp!y_99$ -d SymphonyCL -Q "EXEC [dbo].[Client_SP_STATUS_RESET_2]"



cd "C:\Program Files\Symphony\Symphony Auto Load\" 
AutoLoadFiles.exe -DB=SYMPHONYCL


sqlcmd -S localhost -U sa -P Supp!y_99$ -d SymphonyCL -Q  "[dbo].[Client_SP_OUTPUT]"




sqlcmd -S localhost -U sa -P Supp!y_99$ -d SymphonyCL -Q "EXEC [dbo].[Client_SP_STATUS_RESET_3]"



cd "C:\Program Files\Symphony\Symphony Auto Load\" 
AutoLoadFiles.exe -DB=SYMPHONYCL



move "D:\SymphonyData\CustomReports\Output_Script\"WH_Barcode_stock*.* "D:\SymphonyData\CustomReports\Output_Script\Archive\"
