# ActiveRoad [![Build Status](https://travis-ci.org/dryade/activeroad.png)](http://travis-ci.org/dryade/activeroad?branch=master) [![Dependency Status](https://gemnasium.com/dryade/activeroad.png)](https://gemnasium.com/dryade/activeroad) [![Code Climate](https://codeclimate.com/github/dryade/activeroad.png)](https://codeclimate.com/github/dryade/activeroad)

Rails engine with a model for transport networks which includes
 - an itinerary research
 - the possibility to import osm data

Requirements
------------
 
This code has been run and tested on :  
* Ruby 1.9.3 and ruby 2.0
* Postgresql 9.X
* Postgis 1.5 and 2.X

External Deps
-------------
On Debian/Ubuntu/Kubuntu OS : 
```sh
sudo apt-get install git postgresql postgis build-essential ruby-dev libproj-dev libgeos-dev libffi-dev zlib1g-dev libxslt1-dev libxml2-dev libbz2-dev
```

Must install [kyotocabinet](https://github.com/dryade/activeroad/wiki/Kyotocabinet)


Installation
------------
 
This package is available in RubyGems and can be installed with:
```sh 
   gem install active_road
```

More Information
----------------
 
More information can be found on the [project website on GitHub](http://github.com/dryade/activeroad). 
There is extensive usage documentation available [on the wiki](https://github.com/dryade/activeroad/wiki).

Example Usage 
------------

### Rake tasks

#### Import data


####Import OSM data : 

```sh
bundle exec rake 'app:active_road:import:osm_data[/data/guyane-latest.osm]'

```

<table>
    <th>
        <td>OSM Data</td>
        <td>time to import</td>
        <td>nodes</td>
        <td>way</td>
    </th>
    <tr>
        <td>guyane</td>
        <td>624,1 seconds</td>
        <td>479209</td>
        <td>121870</td>
    </tr>
</table>


### Itinerary research

Example of basic finder : 

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
 
Users looking for support should file an issue on the GitHub issue tracking page (https://github.com/dryade/activeroad/issues), or file a pull request (https://github.com/dryade/activeroad/pulls) if you have a fix available.
