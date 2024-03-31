setwd('~/Dropbox/hiking/CDT/CDT_data')
library(RMySQL)
library(fields)
library(maps)

#connect to mysql using credentials stored in .my.cnf file
myCon <- dbConnect(dbDriver("MySQL"), host = "localhost", default.file = paste("/Users/", Sys.getenv("USER"), "/.my.cnf", sep=''), dbname = "cdt")


#get per day info including sleeping location and termini
cdt_days <- dbGetQuery(myCon, "select d.cdt_day, miles, day_type, hike_friend_day_status, latitude, longitude, rain, snow, sleet, hail
                               from cdt_days d, cdt_places p
                               where d.cdt_day = p.cdt_day
                               and place_type in ('camp', 'town', 'termini')
                               and ! (place_type = 'terminal' and d.cdt_day = 1)
                               order by d.cdt_day")


cdt_places <- dbGetQuery(myCon, "select cdt_day, place, place_type, latitude, longitude
                                 from cdt_places
                                 order by cdt_day")

#low temps for nights spent camping 
cdt_low_temps <- dbGetQuery(myCon, "select d.cdt_day, low_temp, latitude, longitude
                                    from cdt_days d, cdt_places p
                                    where d.cdt_day = p.cdt_day
                                    and place_type = 'camp'                   
                                    order by cdt_day")

#number of new people met each day and sleeping location
cdt_people <- dbGetQuery(myCon, "select p.cdt_day, latitude, longitude, num_people
                                 from cdt_places p, (select cdt_day, count(*) num_people
                                                     from cdt_people
                                                     group by cdt_day) x
                                 where x.cdt_day = p.cdt_day
                                 and place_type in ('camp', 'town')                 
                                 order by cdt_day")

#hitchhiking, bus, and train start and end locations. The first query selects hitches into towns where you did not stay, the second query selects hitches or rides into towns
#where you stayed the night, and the third query selects hitches or rides from town back to a different location than the one where you hitched or rode into town.
cdt_hitches <- dbGetQuery(myCon, "select p.cdt_day, p.place_type, p.latitude lat_start, p.longitude long_start, p2.latitude lat_end, p2.longitude long_end
                                  from cdt_places p, cdt_places p2
                                  where p.cdt_day = p2.cdt_day
                                  and p.place_type in ('hitch', 'car', 'bus', 'train')
                                  and p2.place_type = 'resupply'
                                  and p.cdt_day not in (select cdt_day 
                                                       from cdt_places
                                                       where place_type = 'town')
                                  union all
                                  select p.cdt_day, p.place_type, p.latitude, p.longitude, p2.latitude, p2.longitude
                                  from cdt_places p, cdt_places p2
                                  where p.cdt_day = p2.cdt_day
                                  and p.place_type in ('hitch', 'car', 'bus', 'train')
                                  and p2.place_type = 'town'
                                  union all
                                  select p.cdt_day, p.place_type, p2.latitude, p2.longitude, p.latitude, p.longitude
                                  from cdt_places p, cdt_places p2
                                  where p.cdt_day = p2.cdt_day + 1
                                  and p.place_type in ('hitch', 'car', 'bus', 'train')
                                  and p2.place_type = 'town'
                                  and p.cdt_day not in (select cdt_day 
                                                       from cdt_places
                                                       where place_type in ('town', 'resupply'))
                                  order by cdt_day")                                
                                  
                                  
#define map latitude and longitude ranges
long_range <- c(-117, -102)
lat_range <- c(31, 49)
states <-c('Montana', 'Idaho', 'Wyoming', 'Colorado', 'New Mexico')


#calculate latitude and longitude distances using Haversine formula
long_dist <-  2 * 3958.8 * asin(sqrt(cos(mean(lat_range) * pi / 180) * cos(mean(lat_range) * pi / 180) * sin(diff(long_range) / 2 * pi / 180)^2))
lat_dist <- 2 * 3958.8 * asin(sqrt(sin(diff(lat_range * pi / 180) / 2)^2))

#define day types, their plotting labels, and respective colors
day_types <- c('full', 'zero', 'nearo', 'hero')
day_type_mains <- c('Full days', 'Zeroes', 'Nearos', 'Heroes')
day_type_cols <- adjustcolor(c('black', 'blue', 'orange', 'green'), .6)


#day based plots
pdf("cdt_days.pdf", height=10, width=10)
#miles per day
plot(cdt_days$cdt_day, cdt_days$miles, pch=20, col=day_type_cols[match(cdt_days$day_type, day_types)], xlab='CDT days', ylab='Miles', main='CDT miles per day')
legend("topright", day_type_mains, fill=day_type_cols, border=day_type_cols)

mile_matrix <- c()
for (i in 1:length(day_types))
  {
  miles_i <- hist(cdt_days$miles[cdt_days$day_type == day_types[i]], breaks = seq(-1, max(cdt_days$miles), 1), plot=F)  
  mile_matrix <- rbind(mile_matrix, miles_i$counts)
  }

barplot(mile_matrix, beside=F, col=day_type_cols, space=0, border=NA, xlab='Miles', ylab='Days', main='CDT miles per day')
legend("topright", day_type_mains, fill=day_type_cols, border=day_type_cols)
axis(1, at=0.5 + seq(0, max(cdt_days$miles) + 5, 5), seq(0, max(cdt_days$miles) + 5, 5))

for (i in 1:length(day_types))
  {
  abline(v=mean(cdt_days$miles[cdt_days$day_type == day_types[i]]), col=day_type_cols[i])
  text(mean(cdt_days$miles[cdt_days$day_type == day_types[i]]) - 2, max(mile_matrix), round(mean(cdt_days$miles[cdt_days$day_type == day_types[i]]), 1), col=day_type_cols[i], cex=.7)
  }



#low temps
hist(cdt_low_temps$low_temp, col='black', breaks = seq(floor(min(cdt_low_temps$low_temp)), max(cdt_low_temps$low_temp) + 1, 1), xlab='Degrees Fahrenheit', ylab='Days', main='CDT overnight low temps')
abline(v=mean(cdt_low_temps$low_temp), col='red')
abline(v=32, col='black')
text(mean(cdt_low_temps$low_temp) - 3, 7, round(mean(cdt_low_temps$low_temp), 1), col='red')


#new people met each day
plot(cdt_people$cdt_day, cdt_people$num_people, pch=20, xlim=c(0, max(cdt_days$cdt_day)), ylim=c(0, max(cdt_people$num_people)), xlab='CDT day', ylab='People', main='New people by day')
dev.off()





#map based plots
pdf("cdt_maps.pdf", height=lat_dist / 100, width=long_dist / 100)
#summary of campsites, hitches, cars, buses, trains, and resupplies for all days
plot(1, type='n', xlim=long_range, ylim=lat_range, bty='n', xaxt='n', yaxt='n', xlab='', ylab='', main = 'All days')
map('state', region = states, add=T)

points(cdt_days$longitude, cdt_days$latitude, col=day_type_cols[match(cdt_days$day_type, day_types)], pch=20, cex=2)
points(cdt_places$longitude[cdt_places$place_type == 'resupply'], cdt_places$latitude[cdt_places$place_type == 'resupply'], pch='x')
arrows(cdt_hitches$long_start[cdt_hitches$place_type == 'hitch'], cdt_hitches$lat_start[cdt_hitches$place_type == 'hitch'], cdt_hitches$long_end[cdt_hitches$place_type == 'hitch'], cdt_hitches$lat_end[cdt_hitches$place_type == 'hitch'], length=.05, lwd=2, col='red')
arrows(cdt_hitches$long_start[cdt_hitches$place_type == 'car'], cdt_hitches$lat_start[cdt_hitches$place_type == 'car'], cdt_hitches$long_end[cdt_hitches$place_type == 'car'], cdt_hitches$lat_end[cdt_hitches$place_type == 'car'], length=.05, lwd=2, col='grey')
arrows(cdt_hitches$long_start[cdt_hitches$place_type == 'bus'], cdt_hitches$lat_start[cdt_hitches$place_type == 'bus'], cdt_hitches$long_end[cdt_hitches$place_type == 'bus'], cdt_hitches$lat_end[cdt_hitches$place_type == 'bus'], length=.05, lwd=2, col='gold')
arrows(cdt_hitches$long_start[cdt_hitches$place_type == 'train'], cdt_hitches$lat_start[cdt_hitches$place_type == 'train'], cdt_hitches$long_end[cdt_hitches$place_type == 'train'], cdt_hitches$lat_end[cdt_hitches$place_type == 'train'], length=.05, lwd=2, col='purple')

legend("bottomleft", day_type_mains, fill=day_type_cols, border=day_type_cols, bty='n')
arrows(-117.5, 34.5, -117, 34.5, length=.05, lwd=2, col='red')
arrows(-117.5, 34, -117, 34, length=.05, lwd=2, col='grey')
arrows(-117.5, 33.5, -117, 33.5, length=.05, lwd=2, col='gold')
arrows(-117.5, 33, -117, 33, length=.05, lwd=2, col='purple')
text(-116.5, 34.5, 'Hitchhike', col='red', adj=0)
text(-116.5, 34, 'Car', col='grey', adj=0)
text(-116.5, 33.5, 'Bus', col='gold', adj=0)
text(-116.5, 33, 'Train', col='purple', adj=0)
text(-117.25, 32.5, 'x')
text(-116.5, 32.5, 'Resupply', adj=0)


#separate map plots for each day type
for (i in 1:length(day_types))
  {
  plot(1, type='n', xlim=long_range, ylim=lat_range, bty='n', xaxt='n', yaxt='n', xlab='', ylab='', main = day_type_mains[i])
  map('state', region = states, add=T)
  
  points(cdt_places$longitude[cdt_places$place_type == 'camp'], cdt_places$latitude[cdt_places$place_type == 'camp'], type='l', col=adjustcolor('grey', .6))
  points(cdt_days$longitude[cdt_days$day_type == day_types[i]], cdt_days$latitude[cdt_days$day_type == day_types[i]], col=day_type_cols[i], pch=20, cex=2)
  }
  
#map of resupplies
plot(1, type='n', xlim=c(-117, -102), ylim=c(31, 50), bty='n', xaxt='n', yaxt='n', xlab='', ylab='', main = 'Resupplies')
map('state', region = states, add=T)

points(cdt_places$longitude[cdt_places$place_type == 'camp'], cdt_places$latitude[cdt_places$place_type == 'camp'], type='l', col=adjustcolor('grey', .6))
text(cdt_places$longitude[cdt_places$place_type == 'resupply'], cdt_places$latitude[cdt_places$place_type == 'resupply'], cdt_places$place[cdt_places$place_type == 'resupply'], cex=.6)


#map of sidehikes (may be cluttered)
plot(1, type='n', xlim=c(-117, -102), ylim=c(31, 50), bty='n', xaxt='n', yaxt='n', xlab='', ylab='', main = 'Sidehikes')
map('state', region = states, add=T)

points(cdt_places$longitude[cdt_places$place_type == 'camp'], cdt_places$latitude[cdt_places$place_type == 'camp'], type='l', col=adjustcolor('grey', .6))
text(cdt_places$longitude[cdt_places$place_type == 'sidehike'], cdt_places$latitude[cdt_places$place_type == 'sidehike'], cdt_places$place[cdt_places$place_type == 'sidehike'], cex=.3)



#map of amount of each day hiking with other people
plot(1, type='n', xlim=c(-117, -102), ylim=c(31, 50), bty='n', xaxt='n', yaxt='n', xlab='', ylab='', main = 'Amount of each day hiking with other people')
map('state', region = states, add=T)

points(cdt_days$longitude[cdt_days$hike_friend_day_status == 'all' & cdt_days$day_type != 'zero'], cdt_days$latitude[cdt_days$hike_friend_day_status == 'all' & cdt_days$day_type != 'zero'], pch=20, cex=2, col=adjustcolor('red', .6))
points(cdt_days$longitude[cdt_days$hike_friend_day_status == 'most' & cdt_days$day_type != 'zero'], cdt_days$latitude[cdt_days$hike_friend_day_status == 'most' & cdt_days$day_type != 'zero'], pch=20, cex=2, col=adjustcolor('purple', .6))
points(cdt_days$longitude[cdt_days$hike_friend_day_status == 'less' & cdt_days$day_type != 'zero'], cdt_days$latitude[cdt_days$hike_friend_day_status == 'less' & cdt_days$day_type != 'zero'], pch=20, cex=2, col=adjustcolor('blue', .6))
points(cdt_days$longitude[cdt_days$hike_friend_day_status == 'none' & cdt_days$day_type != 'zero'], cdt_days$latitude[cdt_days$hike_friend_day_status == 'none' & cdt_days$day_type != 'zero'], pch=20, cex=2, col=adjustcolor('darkgrey', .6))

legend("bottomleft", c('All', 'More than half', 'Less than half', 'None'), fill=adjustcolor(c('red', 'purple', 'blue', 'darkgrey'), .6), border=NA)



#overnight low temperature map
#define color palette based on temperature range
temp_cols <- tim.colors(max(round(cdt_low_temps$low_temp)) - min(round(cdt_low_temps$low_temp)))

plot(1, type='n', xlim=long_range, ylim=lat_range, bty='n', xaxt='n', yaxt='n', xlab='', ylab='', main = 'Overnight low temps')
map('state', region = states, add=T)
points(cdt_low_temps$longitude, cdt_low_temps$latitude, col=temp_cols[round(cdt_low_temps$low_temp) - min(round(cdt_low_temps$low_temp))], pch=20, cex=2)


#plot custom legend
longitude_min <- -115
longitude_max <- -114
latitude_min <- 33
latitude_max <- 38

latitude_step <- (latitude_max - latitude_min) / length(temp_cols)

for (i in 1:length(temp_cols))
  {
  rect(longitude_min, latitude_min + latitude_step * (i - 1), longitude_max, latitude_min + latitude_step * i, col=temp_cols[i], border=temp_cols[i])  
  }
  
legend_temps <- seq(min(round(cdt_low_temps$low_temp)), max(round(cdt_low_temps$low_temp)), 5)
text(longitude_max + .5, latitude_min + latitude_step * (legend_temps - min(legend_temps)), legend_temps)
text(mean(c(longitude_min, longitude_max)), latitude_max + .5, 'Degrees F')


#daily precipitation map
plot(1, type='n', xlim=c(-117, -102), ylim=c(31, 50), bty='n', xaxt='n', yaxt='n', xlab='', ylab='', main = 'Precipitation')
map('state', region = states, add=T)

points(cdt_places$longitude[cdt_places$place_type == 'camp'], cdt_places$latitude[cdt_places$place_type == 'camp'], type='l', col=adjustcolor('grey', .6))
points(cdt_days$longitude[cdt_days$rain == 1], cdt_days$latitude[cdt_days$rain == 1], pch=92, col='blue')
points(cdt_days$longitude[cdt_days$sleet == 1], cdt_days$latitude[cdt_days$sleet == 1], pch=47, col='blue')
points(cdt_days$longitude[cdt_days$snow == 1], cdt_days$latitude[cdt_days$snow == 1], pch=0, col='black')
points(cdt_days$longitude[cdt_days$hail == 1], cdt_days$latitude[cdt_days$hail == 1], pch=1, col='black', cex=2)

legend("bottomleft", c('Rain', 'Sleet', 'Snow', 'Hail'), pch=c(92, 47, 0, 1), col=c('blue', 'blue', 'black', 'black'), pt.cex=c(1,1,1,2))


#map of number of new people met each day
plot(1, type='n', xlim=long_range, ylim=lat_range, bty='n', xaxt='n', yaxt='n', xlab='', ylab='', main = 'New people by day')
map('state', region = states, add=T)

people_cols = tim.colors(max(cdt_people$num_people))
points(cdt_people$longitude, cdt_people$latitude, pch=20, col=adjustcolor(people_cols[cdt_people$num_people], .6), cex=cdt_people$num_people / 2)
legend('bottomleft', legend=1:max(cdt_people$num_people), pch=20, pt.cex=(1:max(cdt_people$num_people))/2, col=adjustcolor(people_cols, .6), y.intersp=1.3)
dev.off()



