import gpxpy
import gpxpy.gpx
from datetime import datetime
import glob                                                                 
import sys

#python3 process_gpx.py 2023-07-02 cdt_inreach.gpx

def main():
  (start_date, gpx_file) = sys.argv[1:]
  
  start_date = datetime.strptime(start_date, "%Y-%m-%d").date()
  with open('cdt_gps_raw.txt', 'w') as c:
    c.write(f"""Day\tPlace name\tPlace type\tLatitude\tLongitude\n""")
    
    with open(gpx_file, 'r') as g:
      gpx = gpxpy.parse(g)
    
      for waypoint in gpx.waypoints:
        waypoint.name = waypoint.name.strip()
        cdt_day = waypoint.time.date() - start_date
        cdt_day = cdt_day.days + 1
        place_type = ''
       
        if waypoint.name[:3] == 'CDT':
          place_type = 'camp'
          cdt_day = waypoint.name[4:]
        
        c.write(f"""{cdt_day}\t{waypoint.name}\t{place_type}\t{waypoint.latitude}\t{waypoint.longitude}\n""")


if __name__ == '__main__':
  main()
