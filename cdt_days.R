library(RMySQL)
library(fields)
library(maps)

myCon <- dbConnect(dbDriver("MySQL"), host = "localhost", default.file = ".my.cnf", dbname = "cdt")
setwd('~/Dropbox/hiking/CDT/CDT_data')

cdt_days <- dbGetQuery(myCon, "select d.cdt_day, miles, day_type, latitude, longitude
                               from cdt_days d, cdt_places p
                               where d.cdt_day = p.cdt_day
                               and place_type in ('camp', 'town', 'terminal')
                               and ! (place_type = 'terminal' and d.cdt_day = 1)
                               order by d.cdt_day")

cdt_places <- dbGetQuery(myCon, "select cdt_day, place, place_type, latitude, longitude
                                 from cdt_places
                                 order by cdt_day")

cdt_low_temps <- dbGetQuery(myCon, "select d.cdt_day, low_temp, latitude, longitude
                                    from cdt_days d, cdt_places p
                                    where d.cdt_day = p.cdt_day
                                    and place_type = 'camp'                   
                                    order by cdt_day")

cdt_people <- dbGetQuery(myCon, "select p.cdt_day, latitude, longitude, num_people
                                 from cdt_places p, (select cdt_day, count(*) num_people
                                                     from cdt_people
                                                     group by cdt_day) x
                                 where x.cdt_day = p.cdt_day
                                 and place_type in ('camp', 'town')                 
                                 order by cdt_day")


pdf("cdt_days.pdf", height=10, width=10)
#miles per day
day_types <- c('full', 'zero', 'nearo', 'hero')
day_type_cols <- c('black', 'blue', 'red', 'green')
plot(cdt_days$cdt_day, cdt_days$miles, pch=20, col=day_type_cols[match(cdt_days$day_type, day_types)], xlab='CDT days', ylab='Miles', main='CDT miles per day')
legend("topright", day_types, fill=day_type_cols, border=day_type_cols)


mile_matrix <- c()
for (i in 1:length(day_types))
  {
  miles_i <- hist(cdt_days$miles[cdt_days$day_type == day_types[i]], breaks = seq(-1, max(cdt_days$miles), 1), plot=F)  
  mile_matrix <- rbind(mile_matrix, miles_i$counts)
  }

barplot(mile_matrix, beside=F, col=day_type_cols, space=0, border=NA, xlab='Miles', ylab='Days', main='CDT miles per day')
legend("topright", day_types, fill=day_type_cols, border=day_type_cols)
axis(1, at=0.5 + seq(0, max(cdt_days$miles) + 5, 5), seq(0, max(cdt_days$miles) + 5, 5))

for (i in 1:length(day_types))
  {
  abline(v=mean(cdt_days$miles[cdt_days$day_type == day_types[i]]))
  text(mean(cdt_days$miles[cdt_days$day_type == day_types[i]]) - 2, max(mile_matrix), round(mean(cdt_days$miles[cdt_days$day_type == day_types[i]]), 1), col=day_type_cols[i], cex=.7)
  }



#low temps
hist(cdt_low_temps$low_temp, col='black', breaks = seq(floor(min(cdt_low_temps$low_temp)), max(cdt_low_temps$low_temp) + 1, 1), xlab='Degrees Fahrenheit', ylab='Days', main='CDT overnight low temps')
abline(v=mean(cdt_low_temps$low_temp), col='red')
abline(v=32, col='black')
text(mean(cdt_low_temps$low_temp) - 3, 7, round(mean(cdt_low_temps$low_temp), 1), col='red')

plot(cdt_low_temps$latitude, cdt_low_temps$low_temp, pch=20, xlab='Latitude', ylab = 'Degrees Fahrenheit', main = 'Low temps by latitude')

temp_cols <- tim.colors(max(round(cdt_low_temps$low_temp)) - min(round(cdt_low_temps$low_temp)))
plot(cdt_low_temps$cdt_day, cdt_low_temps$latitude, col=temp_cols[round(cdt_low_temps$low_temp) - min(round(cdt_low_temps$low_temp))], pch=20, xlab='CDT day', ylab='Latitude', main = 'Low temps by latitude')

#legend
day_min <- 6
day_max <- 12
latitude_min <- 33
latitude_max <- 38

latitude_step <- (latitude_max - latitude_min) / length(temp_cols)

for (i in 1:length(temp_cols))
  {
  rect(day_min, latitude_min + latitude_step * (i - 1), day_max, latitude_min + latitude_step * i, col=temp_cols[i], border=temp_cols[i])  
  }
  
legend_temps <- seq(min(round(cdt_low_temps$low_temp)), max(round(cdt_low_temps$low_temp)), 5)
text(day_max + 2, latitude_min + latitude_step * (legend_temps - min(legend_temps)), legend_temps)
text(mean(c(day_min, day_max)), latitude_max + .5, 'Degrees')


plot(cdt_people$cdt_day, cdt_people$num_people, pch=20, xlim=c(0, max(cdt_days$cdt_day)), ylim=c(0, max(cdt_people$num_people)), xlab='CDT day', ylab='People', main='New people by day')
dev.off()



pdf("cdt_maps.pdf", height=9.5, width=7.5)
plot(1, type='n', xlim=c(-117, -102), ylim=c(31, 50), bty='n', xaxt='n', yaxt='n', xlab='', ylab='', main = 'Day type')
map('state', region = 'Montana', add=T)
map('state', region = 'Idaho', add=T)
map('state', region = 'Wyoming', add=T)
map('state', region = 'Colorado', add=T)
map('state', region = 'New Mexico', add=T)

day_types <- c('full', 'zero', 'nearo', 'hero')
day_type_cols <- c('black', 'blue', 'red', 'green')
points(cdt_days$longitude, cdt_days$latitude, col=day_type_cols[match(cdt_days$day_type, day_types)], pch=20, cex=2)
legend("bottomleft", day_types, fill=day_type_cols, border=day_type_cols)


plot(1, type='n', xlim=c(-117, -102), ylim=c(31, 50), bty='n', xaxt='n', yaxt='n', xlab='', ylab='', main = 'Full days')
map('state', region = 'Montana', add=T)
map('state', region = 'Idaho', add=T)
map('state', region = 'Wyoming', add=T)
map('state', region = 'Colorado', add=T)
map('state', region = 'New Mexico', add=T)

points(cdt_days$longitude[cdt_days$day_type=='full'], cdt_days$latitude[cdt_days$day_type=='full'], col='black', pch=20, cex=2)


plot(1, type='n', xlim=c(-117, -102), ylim=c(31, 50), bty='n', xaxt='n', yaxt='n', xlab='', ylab='', main = 'Zeroes')
map('state', region = 'Montana', add=T)
map('state', region = 'Idaho', add=T)
map('state', region = 'Wyoming', add=T)
map('state', region = 'Colorado', add=T)
map('state', region = 'New Mexico', add=T)

points(cdt_days$longitude[cdt_days$day_type=='zero'], cdt_days$latitude[cdt_days$day_type=='zero'], col='blue', pch=20, cex=2)


plot(1, type='n', xlim=c(-117, -102), ylim=c(31, 50), bty='n', xaxt='n', yaxt='n', xlab='', ylab='', main = 'Nearos')
map('state', region = 'Montana', add=T)
map('state', region = 'Idaho', add=T)
map('state', region = 'Wyoming', add=T)
map('state', region = 'Colorado', add=T)
map('state', region = 'New Mexico', add=T)

points(cdt_days$longitude[cdt_days$day_type=='nearo'], cdt_days$latitude[cdt_days$day_type=='nearo'], col='red', pch=20, cex=2)


plot(1, type='n', xlim=c(-117, -102), ylim=c(31, 50), bty='n', xaxt='n', yaxt='n', xlab='', ylab='', main = 'Heroes')
map('state', region = 'Montana', add=T)
map('state', region = 'Idaho', add=T)
map('state', region = 'Wyoming', add=T)
map('state', region = 'Colorado', add=T)
map('state', region = 'New Mexico', add=T)

points(cdt_days$longitude[cdt_days$day_type=='hero'], cdt_days$latitude[cdt_days$day_type=='hero'], col='green', pch=20, cex=2)


plot(1, type='n', xlim=c(-117, -102), ylim=c(31, 50), bty='n', xaxt='n', yaxt='n', xlab='', ylab='', main = 'Resupplies')
map('state', region = 'Montana', add=T)
map('state', region = 'Idaho', add=T)
map('state', region = 'Wyoming', add=T)
map('state', region = 'Colorado', add=T)
map('state', region = 'New Mexico', add=T)

text(cdt_places$longitude[cdt_places$place_type == 'resupply'], cdt_places$latitude[cdt_places$place_type == 'resupply'], cdt_places$place[cdt_places$place_type == 'resupply'], cex=.5)



temp_cols <- tim.colors(max(round(cdt_low_temps$low_temp)) - min(round(cdt_low_temps$low_temp)))

plot(1, type='n', xlim=c(-117, -102), ylim=c(31, 50), bty='n', xaxt='n', yaxt='n', xlab='', ylab='', main = 'Overnight low temps')
map('state', region = 'Montana', add=T)
map('state', region = 'Idaho', add=T)
map('state', region = 'Wyoming', add=T)
map('state', region = 'Colorado', add=T)
map('state', region = 'New Mexico', add=T)
points(cdt_low_temps$longitude, cdt_low_temps$latitude, col=temp_cols[round(cdt_low_temps$low_temp) - min(round(cdt_low_temps$low_temp))], pch=20, cex=2)


#legend
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
text(mean(c(longitude_min, longitude_max)), latitude_max + .5, 'Degrees')




plot(1, type='n', xlim=c(-117, -102), ylim=c(31, 50), bty='n', xaxt='n', yaxt='n', xlab='', ylab='', main = 'New people by day')
map('state', region = 'Montana', add=T)
map('state', region = 'Idaho', add=T)
map('state', region = 'Wyoming', add=T)
map('state', region = 'Colorado', add=T)
map('state', region = 'New Mexico', add=T)

people_cols = tim.colors(max(cdt_people$num_people))
points(cdt_people$longitude, cdt_people$latitude, pch=20, col=adjustcolor(people_cols[cdt_people$num_people], .6), cex=cdt_people$num_people / 2)
legend('bottomleft', legend=1:max(cdt_people$num_people), pch=20, pt.cex=(1:max(cdt_people$num_people))/2, col=adjustcolor(people_cols, .6), y.intersp=1.3)
dev.off()

