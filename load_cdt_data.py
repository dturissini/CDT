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
import sys
import getpass

#python3 load_cdt_data.py 2023-07-02 cdt_gps_edited.txt cdt_govee


def main():
  engine = create_engine('mysql+mysqlconnector://localhost/cdt', connect_args={'read_default_file': '/Users/' + getpass.getuser() + '/.my.cnf'})
  conn = engine.connect()
  
  (start_date, edited_gps_file, govee_dir) = sys.argv[1:]
  
  
  create_tables(conn)
  load_cdt_days(start_date, conn)
  load_cdt_places(start_date, edited_gps_file, conn)
  update_day_types(conn)
  load_cdt_low_temps(start_date, govee_dir, conn)



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
  

def load_cdt_days(start_date, conn):
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
                        set cdt_date = date_add('{start_date}', interval cdt_day DAY)"""))

  conn.execute(text(f"""update cdt_days
                        set day_type = 'zero'
                        where miles = 0"""))

        

def load_cdt_places(start_date, edited_gps_file, conn):
  with open(edited_gps_file, 'r') as g: 
    g.readline()     
    for line in g:
      line = line.strip()
      (cdt_day, place, place_type, latitude, longitude) = line.split('\t')
            
      conn.execute(text(f"""insert into cdt_places
                            values
                            (null, {cdt_day}, "{place}", "{place_type}", {latitude}, {longitude})"""))
    

def update_day_types(conn):   
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

  max_cdt_day = conn.execute(text(f"""select max(cdt_day)
                                      from cdt_days""")).fetchone()[0]

  conn.execute(text(f"""update cdt_days
                        set day_type = 'nearo'
                        where miles between 1 and 20
                        and cdt_day in (1, {max_cdt_day})"""))


  conn.execute(text(f"""update cdt_days
                        set day_type = 'hero'
                        where day_type = 'full'
                        and cdt_day in (select cdt_day
                                        from cdt_places
                                        where place_type = 'resupply')
                        and cdt_day not in (select cdt_day
                                            from cdt_places
                                            where place_type = 'town')
                        and cdt_day - 1 not in (select cdt_day
                                                from cdt_places
                                                where place_type = 'town')"""))


def load_cdt_low_temps(start_date, govee_dir, conn):
  low_temps = {}
  start_date = datetime.strptime(start_date, "%Y-%m-%d").date()
  
  govee_file_str = govee_dir + '/*.csv'
  
  for govee_file in list(glob.glob(govee_file_str)):     
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
  