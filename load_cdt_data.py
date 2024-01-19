from sqlalchemy import create_engine
from sqlalchemy.engine import Connection
from sqlalchemy.engine.url import URL
from sqlalchemy.sql import text
import os
from typing import TextIO
import gpxpy
import gpxpy.gpx
from datetime import datetime
import glob                                                                 


#update hitch dates


def main():
  engine = create_engine('mysql+mysqlconnector://localhost/cdt', connect_args={'read_default_file': '/Users/' + getpass.getuser() + '/.my.cnf'})
  conn = engine.connect()
  
  create_tables(conn)
  load_cdt_days(conn)
  load_cdt_places(conn)
  load_cdt_low_temps(conn)

def create_tables(conn):
  conn.execute(text(f"drop table if exists cdt_days"))
  conn.execute(text(f"""create table cdt_days 
  	                    (cdt_day int primary key, 
                         cdt_date date, 
                         miles decimal(3,1),
                         day_type varchar(10),
                         low_temp decimal(4,1),
                         rain int,
                         snow int,
                         sleet int,
                         hail int)"""))


  conn.execute(text(f"drop table if exists cdt_people"))
  conn.execute(text(f"""create table cdt_people 
                        (cp_id int primary key auto_increment,
                         cdt_day int,
                         person varchar(30),
                         index(cdt_day))"""))

  conn.execute(text(f"drop table if exists cdt_places"))
  conn.execute(text(f"""create table cdt_places 
                        (cp_id int primary key auto_increment,
                         cdt_day int,
                         place varchar(30),
                         place_type varchar(10),
                         latitude decimal(10,7),
                         longitude decimal(10,7),
                         index(cdt_day))"""))
  

def load_cdt_days(conn):
  with open("cdt_days.txt", "r") as i: 
    cdt_day = 0
    for line in i.readlines():
      line = line.strip()
      values = line.split()
      
      if len(values) > 1 and is_number(values[0]) and is_number(values[1]):
        cdt_day = values[0]
        
        rain = 0
        snow = 0
        sleet = 0
        hail = 0
        if 'rain' in line:
          rain = 1
        
        if 'snow' in line:
          snow = 1
        
        if 'sleet' in line:
          sleet = 1
        
        if 'hail' in line:
          hail = 1
        
        conn.execute(text(f"""insert into cdt_days
                              values
                              ({cdt_day}, null, {values[1]}, 'full', null, {rain}, {snow}, {sleet}, {hail})"""))
      else:
        if line != '':
          conn.execute(text(f"""insert into cdt_people
                                values
                                (null, {cdt_day}, "{line}")"""))


  conn.execute(text(f"""update cdt_days
                        set cdt_date = date_add("2023-07-01", interval cdt_day DAY)"""))

  conn.execute(text(f"""update cdt_days
                        set day_type = 'zero'
                        where miles = 0"""))

        

def load_cdt_places(conn):
  gpx_file = open('cdt_inreach.gpx', 'r')
  gpx = gpxpy.parse(gpx_file)
  
  start_date = datetime.strptime('2023-07-02', "%Y-%m-%d").date()
  resupplies = ['East Glacier', 'Augusta', 'High Divide Outfittr', 'Elliston', 'Anaconda', 'Darby', 'Leadore', 'Lima', 'West Yellowstone', 'Old Faithful', 'Dubois', 'Pinedale', 'Lander', 'Rawlins', 'Riverside-Encampment', 'Steamboat Springs', 'Grand Lake', 'Dillon', 'Breckenridge', 'Twin Lakes', 'Salida', 'Lake City', 'Pagosa Springs', 'Chama', 'Abiquiu', 'Cuba', 'Grants', 'Pietown', "Doc Campbell's Post", 'Silver City', 'Lordsburg']                 
  sidehikes = ['Thunderbolt Mt', 'Peak 9989', 'Peak 9336', 'Elk Mountain', 'Cottonwood Peak', 'Deadman Pass', 'Taylor Mountain', 'Grand Prismatic Pool', 'Knapsack Col', 'Mt Bonneville SW', 'Lost Ranger Peak', 'James Peak', 'Flora Peak', 'Peak 13208', 'Grays Peak', 'Mt Edwards', 'Argentine Peak', 'Decautur Mountain', 'Sullivan Mtn', 'Geneva Peak', 'Whale Peak', 'Glacier Peak', 'Mt Elbert', 'San Luis Peak', 'Coney Point', 'Alberta Peak', 'Cumbres Pass', 'Mt Taylor', 'Big Hatchet Peak']                 
  terminals = ['Canada', 'Mexico']


  for waypoint in gpx.waypoints:
    cdt_day = waypoint.time.date() - start_date
    cdt_day = cdt_day.days + 1
    
    place_type = 'hitch'
    if waypoint.name[:3] == 'CDT':
      place_type = 'camp'
      cdt_day = waypoint.name[4:]
    elif waypoint.name.strip() in resupplies:
      place_type = 'resupply'
    elif waypoint.name.strip() in sidehikes:
      place_type = 'sidehike'
    elif waypoint.name.strip() in terminals:
      place_type = 'terminal'
            
    conn.execute(text(f"""insert into cdt_places
                          values
                          (null, {cdt_day}, "{waypoint.name}", "{place_type}", {waypoint.latitude},{ waypoint.longitude})"""))
    
  conn.execute(text(f"""update cdt_places
                        set place_type = 'town'
                        where place_type = 'camp'
                        and cdt_day in (6, 11, 19, 20, 24, 25, 37, 46, 50, 51, 56, 57, 60, 61, 67, 68, 71, 74, 75, 84, 88, 89, 94, 95, 98, 102, 103, 109, 113, 121, 122, 125)"""))
   
  conn.execute(text(f"""update cdt_days
                        set day_type = 'nearo'
                        where miles between 1 and 20
                        and cdt_day in (select cdt_day
                                        from cdt_places
                                        where place_type = 'town'
                                        union all
                                        select cdt_day + 1
                                        from cdt_places
                                        where place_type = 'town')"""))

  conn.execute(text(f"""update cdt_days
                        set day_type = 'nearo'
                        where miles between 1 and 20
                        and cdt_day in (1, 130)"""))

  conn.execute(text(f"""update cdt_days
                        set day_type = 'hero'
                        where day_type = 'full'
                        and cdt_day in (select cdt_day
                                        from cdt_places
                                        where place_type = 'resupply')
                        and cdt_day - 1 in (select cdt_day
                                            from cdt_places
                                            where place_type = 'camp')"""))

  conn.execute(text(f"""update cdt_days
                        set day_type = 'hero'
                        where cdt_day in (41)"""))

  conn.execute(text(f"""update cdt_days
                        set day_type = 'full'
                        where cdt_day in (125)"""))


def load_cdt_low_temps(conn):
  low_temps = {}
  start_date = datetime.strptime('2023-07-02', "%Y-%m-%d").date()
  
  for govee_file in list(glob.glob('cdt_govee/*.csv')):     
    with open(govee_file, "r") as g: 
      for line in g.readlines()[1:]:
        line = line.strip()
        (temp_time, temp, humid) = line.split(',')
        temp = float(temp)
        
        cdt_day = datetime.strptime(temp_time[:10], "%Y-%m-%d").date() - start_date
        cdt_day = cdt_day.days
        
        if cdt_day in low_temps:
          if temp < low_temps[cdt_day]:
            low_temps[cdt_day] = temp
        else:
          low_temps[cdt_day] = temp
         
  for cdt_day in low_temps:
    conn.execute(text(f"""update cdt_days
                          set low_temp = {low_temps[cdt_day]}
                          where cdt_day = {cdt_day}"""))
             
       
                 

def is_number(s):
  try:
    float(s)
    return True
  except ValueError:
    return False 
  

if __name__ == '__main__':
  main()
  