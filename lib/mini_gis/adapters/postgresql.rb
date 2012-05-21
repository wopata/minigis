module MiniGIS::Adapters
  class PostgreSQL
    include Geokit::Mappable::ClassMethods # That's where calculations are defined..

    def distance_sql_for_select rel, lat, lng, latc, lngc, opts={}
      lat, lng = lat.degrees, lng.degrees
      t = rel.table_name
      units = opts[:units] || Geokit.default_units
      "(ACOS(least(1,COS(#{lat})*COS(#{lng})*COS(RADIANS(#{t}.#{latc}))*COS(RADIANS(#{t}.#{lngc}))+
       COS(#{lat})*SIN(#{lng})*COS(RADIANS(#{t}.#{latc}))*SIN(RADIANS(#{t}.#{lngc}))+
       SIN(#{lat})*SIN(RADIANS(#{t}.#{latc}))))*#{units_sphere_multiplier(units)})"
    end
    alias distance_sql_for_where distance_sql_for_select
  end
end
