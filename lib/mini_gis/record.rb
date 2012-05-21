require 'geokit'

class Numeric
  def degrees
    self * Math::PI / 180
  end
end

module MiniGIS
  
  @adapters = Hash.new do |h,conn|
    kind = conn.class.name.scan(/([a-z]+)Adapter\Z/i).first.first
    require "mini_gis/adapters/#{kind.downcase}"
    h[conn] = Adapters.const_get(kind).new
  end

  def self.adapter_for klass
    @adapters[klass.connection]
  end
  
  module Record
    def self.included(base)
      base.extend(ClassMethods)
    end

    module Base
      def acts_as_location name='location', lat='lat', lng='lng', dist='distance'
        raise 'Set it up, plz' if [name,lat,lng,dist].any? &:blank?
        send :include, GeoKit::Mappable
        send :include, Record::InstanceMethods
        send :extend,  Record::ClassMethods
        
        module_eval "
          def #{name}
            #{lat}.nil? && #{lng}.nil? ? nil : GeoKit::LatLng.new(#{lat}, #{lng})
          end
          def self.#{name}_latitude_column_name
            '#{lat}'
          end
          def self.#{name}_longitude_column_name
            '#{lng}'
          end
          def self.#{name}_distance_column_name
            '#{dist}'
          end
          def #{name}= val
            if val.respond_to?(:lat) && val.respond_to?(:lng)
              self.#{lat} = val.lat
              self.#{lng} = val.lng
            elsif val.respond_to?(:x) && val.respond_to?(:y)
              self.#{lat} = val.x
              self.#{lng} = val.y
            else
              self.#{lat}, self.#{lng} = val
            end
          end
          ", __FILE__, __LINE__
      end
      
      def origin lat, lng, opts={}
        return nil unless fetch_column_names(opts)
        adapter = MiniGIS.adapter_for self
        lat, lng = lat.to_f, lng.to_f
        latc, lngc = @latitude_column_name, @longitude_column_name
        rel = {:select => "#{self.table_name}.*, #{adapter.distance_sql_for_where(self, lat, lng, latc, lngc, opts)} AS #{@distance_column_name}"}
        within = opts.delete(:within)
        if within && (within = within.to_f) > 0
          bounds = Geokit::Bounds.from_point_and_radius [lat,lng], within, :units => opts[:units]
          rel.update(:conditions => ["#{latc} >= ? AND #{lngc} >= ? AND #{latc} <= ? AND #{lngc} <= ? AND #{adapter.distance_sql_for_where(self, lat, lng, latc, lngc, opts)} <= ?",
            bounds.sw.lat, bounds.sw.lng, bounds.ne.lat, bounds.ne.lng, within])
        end
      
        case opts[:order]
          when :desc, :far  then rel.update(:order => "#{@distance_column_name} DESC")
          when :asc, :close then rel.update(:order => "#{@distance_column_name} ASC")
        end
        self.all(opts.merge(rel))
      end
      
      def rect lat1, lng1, lat2, lng2, opts={}
        return nil unless fetch_column_names(opts)
        lat1, lat2 = lat2, lat1 if lat1 > lat2
        lng1, lng2 = lng2, lng1 if lng1 > lng2
        self.all(opts.merge(
          :conditions => ["#{@latitude_column_name} >= ? AND #{@latitude_column_name} <= ? AND #{@longitude_column_name} >= ? AND #{@longitude_column_name} <= ?",
          lat1, lat2, lng1, lng2]))
      end
      protected
      def fetch_column_names opts
        rel = opts.delete(:rel) || 'location'
        return false unless self.respond_to? "#{rel}_distance_column_name"
        @distance_column_name = self.send "#{rel}_distance_column_name"
        @latitude_column_name = self.send "#{rel}_latitude_column_name"
        @longitude_column_name = self.send "#{rel}_longitude_column_name"
      end
    end

    module InstanceMethods
      def to_lat_lng
        GeoKit::LatLng.new(
          send(self.class.latitude_column_name),
          send(self.class.longitude_column_name))
      end
    end
    
    module ClassMethods
      def acts_as_mappable
        # Compatibility
      end
    end
  end
end
