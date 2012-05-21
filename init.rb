ActiveRecord::Base.send :include, MiniGIS::Record
ActiveRecord::Base.send :extend, MiniGIS::Record::Base
