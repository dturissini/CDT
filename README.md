# CDT
Scripts for analyzing data I collected on my Continental Divide Trail thru hike.

These script process different types of data recorded during the hike and produce two pdfs containing informative plots. There are three main input data files:

**1) Day specific data**

    This information was collected daily along the hike. For simplicity data entry was done in the Notes app on an iPhone and saved as a text file after the hike. Information was structured to enable easier parsing and contained: the day on trail, miles hiked that day, precipitation encountered, total miles hiked to date, and new people met that day. Only day on trail and miles hiked that day were requried, with the other data being optional. The data was structured as follows:
    CDT_DAY MILES_HIKED [PRECIPITATION] [TOTAL_MILES_HIKED]
    [PERSON_1]
    [PERSON_2]

Precipitation could be 0-4 values delimited by a"/", for example rain/snow/sleet/hail 
TOTAL_MILES_HIKED must be prefaced with a T such as T2109. It was handy to track total mileage in this way long the trail to know how far I had already hiked.
A separate person's name was typed on each line beneath the day's header line.
    
**2) GPS data**

    GPS data was collected daily along the hike using a Garmin InReach Mini and exported as a gpx file from the Garmin website after the hike. GPS Waypoints were recorded each night (camping or in town), at resupply locations, at road crossings when hitchhiking into town, and at sidehike destinations. Nightly sleep waypoints used the naming convention "CDT ##" to simplify downstream processing. Note that, unfortunately, after the hike I learned that Garmin does not store elevation or the waypoint icons resulting in the loss of expected data.

**3) Temperature data**

    Temperature was recorded along the hike using a 1 oz GoVee thermometer. The thermometer was either hung outside my tarp or at least placed away from my body at night. Temperature data was exported from the GoVee app on an iPhone after the hike.
  

Analyzing data

The data is processed in several steps:

1) preparing directory
    Create a ~/Dropbox/hiking/CDT/CDT_data directory or one in a different location and update the path in cdt_days.R

2) preparing data files
    Place the following files in the directory:
      a) a .gpx file of waypoints (can be downloaded from Garmin website)
      b) text file of daily info recorded during hike (see above for format)
      c) directory with Govee temperature data files (can be exported from GoVee iPhone app)

3) preparing mySQL
    Create a schema called cdt. Create a .my.cnf file in your user directory containing password and set permissions so it's only readable by you (https://dev.mysql.com/doc/refman/8.0/en/option-files.html).

4) running process_gpx.py
    Process the .gpx file to make an editable form. The program requires the date the hike started and the name of the gpx file. 
    Example: python3 process_gpx.py 2023-07-02 cdt_inreach.gpx

5) manually editing gps text file
    Manually edit the tab-delimited gpx file in a text editor or spreadsheet program. to esnure the day on trail and place types are correct. Note that place type information was recorded as the waypoint icon on trail, but unfortunately, Garmin does not include that information in the gpx. Additionally, the day may need to be changed if the waypoint was added at a later date on the trail.

6) running load_cdt_data.py
    Process all the the data files and store the information in MySQL. The script requires the start date for the hike, cdt days text file, edited gps file, and directory containing the Govee temperature files.
    Example: python3 load_cdt_data.py 2023-07-02 cdt_days.txt cdt_gps_edited.txt cdt_govee


7) running cdt_days.R
    Finally, run the R script (Rscript cdt_days.R) to generate pdf reports. The script generates two pdfs:
      a) cdt_days.pdf
          Contains day-specific summaries regarding mileage, low temperatures, and new people met. 
      b) cdt_maps.pdf
          Contains map plots showing the route including sleeping locations, resupplies, hitchhikes, low temperatures, precipitation, and new people met each day. Separate plots are also made based on day_type:
              i) full day - entire day spent hiking
              ii) nearo - near zero day where only part of the day was spent hiking
              iii) hero - resupply day where you went in and out of town and kept hiking
              iv) zero - full day in one location where no hiking was done

