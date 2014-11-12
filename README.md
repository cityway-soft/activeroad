# ActiveRoad
[![Build Status](https://travis-ci.org/cityway-transdev/activeroad.png)](http://travis-ci.org/cityway-transdev/activeroad?branch=master) [![Dependency Status](https://gemnasium.com/cityway-transdev/activeroad.png)](https://gemnasium.com/cityway-transdev/activeroad) [![Code Climate](https://codeclimate.com/github/cityway-transdev/activeroad.png)](https://codeclimate.com/github/cityway-transdev/activeroad) [![Coverage Status](https://img.shields.io/coveralls/cityway-transdev/activeroad.svg)](https://coveralls.io/r/cityway-transdev/activeroad?branch=master)

ActiveRoads is a rails engine with a specific models for transport networks. It allows to : 
 - import osm ways form openstreetmap datas (PBF file format)             
 - make an itinerary research
The goal of this project is not to make the faster itinerary search engine like [OSRM](http://map.project-osrm.org/) or [OpenTripPlanner](http://www.opentripplanner.org/) but the more flexible because it doesn't need to binarize datas.    

Requirements
------------
 
This code has been run and tested on :  
* Ruby 1.9.3 and ruby 2.0
* Postgresql 9.X
* Postgis 2.X

External Deps
-------------
On Debian/Ubuntu/Kubuntu OS : 
```sh
 sudo apt-get install git postgresql postgis build-essential ruby-dev libproj-dev libgeos-dev libffi-dev zlib1g-dev libxslt1-dev libxml2-dev libbz2-dev libleveldb-dev libsnappy-dev
```

Installation
------------
 
This package is available in RubyGems and can be installed with:
```sh 
 gem install active_road
```

More Information
----------------
 
More information can be found on the [project website on GitHub](http://github.com/cityway-transdev/activeroad). 
There is extensive usage documentation available [on the wiki](https://github.com/cityway-transdev/activeroad/wiki).

Example Usage 
------------

### Import OSM ways

```sh
bundle exec rake "app:active_road:import:osm_pbf_data[/home/user/test.osm.pbf]"

```

### Itinerary research

Example of basic finder : 

Actually we can use only 4 transport modes : 
* car
* train
* pedestrian
* bike 

```ruby
 from = GeoRuby::SimpleFeatures::Point.from_x_y(-52.652771, 5.174379)
 to = GeoRuby::SimpleFeatures::Point.from_x_y(-52.323182, 4.941829)
 speed = 4 # In kilometer/hour        
 finder = ActiveRoad::ShortestPath::Finder.new(from, to, speed).tap do |finder|
   finder.timeout = 30.seconds
 end

 # Get geometry
 finder.geometry

 # Get steps
 finder.paths
```

For a more complex query, you can use constraints arguments. It's an array of string which 
describes :
 * if we use conditionnal cost for a physical road  Ex : ["car"]
 * if we not use a physical road because it contains a specific conditionnal cost Ex : ["~car"]

```ruby
 from = GeoRuby::SimpleFeatures::Point.from_x_y(-52.652771, 5.174379)
 to = GeoRuby::SimpleFeatures::Point.from_x_y(-52.323182, 4.941829)
 speed = 50 # In kilometer/hour        
 constraints = ["car"]
 finder = ActiveRoad::ShortestPath::Finder.new(from, to, speed, constraints).tap do |finder|
   finder.timeout = 30.seconds
 end
```

License
-------
 
This project is licensed under the MIT license, a copy of which can be found in the LICENSE file.


Support
-------
 
Users looking for support should file an issue on the GitHub issue tracking page (https://github.com/cityway-transdev/activeroad/issues), or file a pull request (https://github.com/cityway-transdev/activeroad/pulls) if you have a fix available.
