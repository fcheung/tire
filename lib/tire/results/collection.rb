module Tire
  module Results

    class Collection
      include Enumerable
      include Pagination

      attr_reader :time, :total, :options, :facets, :max_score, :suggestions, :aggregations

      def initialize(response, options={})
        @response    = response
        @options     = options
        @time        = response['took'].to_i
        @total       = response['hits']['total'].to_i rescue nil
        @facets      = response['facets']
        @aggregations= response['aggregations'] 
        @suggestions = Suggestions.new(response['suggest']) if response['suggest']
        @max_score   = response['hits']['max_score'].to_f rescue nil
        @wrapper     = options[:wrapper] || Configuration.wrapper
      end

      def results
        return [] if failure?
        @results ||= begin
          hits = @response['hits']['hits'].map { |d| d.update '_type'.freeze => Utils.unescape(d['_type'.freeze]) }
          unless @options[:load]
            __get_results_without_load(hits)
          else
            __get_results_with_load(hits)
          end
        end
      end

      # Iterates over the `results` collection
      #
      def each(&block)
        results.each(&block)
      end

      # Iterates over the `results` collection and yields
      # the `result` object (Item or model instance) and the
      # `hit` -- raw Elasticsearch response parsed as a Hash
      #
      def each_with_hit(&block)
        results.zip(@response['hits']['hits']).each(&block)
      end

      def empty?
        results.empty?
      end

      def size
        results.size
      end
      alias :length :size

      def slice(*args)
        results.slice(*args)
      end
      alias :[] :slice

      def to_ary
        results
      end

      def as_json(options=nil)
        to_a.map { |item| item.as_json(options) }
      end

      def error
        @response['error']
      end

      def success?
        error.to_s.empty?
      end

      def failure?
        ! success?
      end

      # Handles _source prefixed fields properly: strips the prefix and converts fields to nested Hashes
      #
      def __parse_fields__(fields={})
        ( fields ||= {} ).clone.each_pair do |key,value|
          next unless key.start_with?('_source'.freeze)                 # Skip regular JSON immediately
          keys = key.split('.')
          keys.shift

          fields.delete(key)

          result = {}
          stack = result
          *keys, last_key = keys
          keys.each do |name|
            stack = (stack[name] ||= {})
          end
          stack[last_key] = value
          fields.update result
        end
        fields
      end


      def __get_results_without_load(hits)
        if @wrapper == Hash
          hits
        else
          _tire_partial = '_tire_partial'.freeze
          _source = '_source'.freeze
          hits.map do |h|
            document = {}

            # Update the document with fields and/or source
            document.update h[_source] if h[_source]
            fields = h['fields'.freeze]
            if fields
              if partial = fields[_tire_partial]
                #ES 1.0 returns an array of hashes here
                partial = partial.first if partial.is_a?(Array)
                document.update __parse_fields__(partial)
                other = fields.except(_tire_partial)
                document.update(__parse_fields__(other)) if other.any?
              else
                document.update __parse_fields__(fields)
              end
            end
            # Set document ID
            document['id'.freeze] = h['_id'.freeze]

            # Update the document with meta information
            ['_score'.freeze, '_type'.freeze, '_index'.freeze, '_version'.freeze, 'sort'.freeze, 'highlight'.freeze, '_explanation'.freeze].each do |key|
              document.update key => h[key]
            end

            # Return an instance of the "wrapper" class
            @wrapper.new(document)
          end
        end
      end

      def __get_results_with_load(hits)
        return [] if hits.empty?

        records = {}
        @response['hits']['hits'].group_by { |item| item['_type'] }.each do |type, items|
          raise NoMethodError, "You have tried to eager load the model instances, " +
                               "but Tire cannot find the model class because " +
                               "document has no _type property." unless type

          begin
            klass = type.camelize.constantize
          rescue NameError => e
            raise NameError, "You have tried to eager load the model instances, but " +
                             "Tire cannot find the model class '#{type.camelize}' " +
                             "based on _type '#{type}'.", e.backtrace
          end

          records[type] = Array(__find_records_by_ids klass, items.map { |h| h['_id'] })
        end

        # Reorder records to preserve the order from search results
        @response['hits']['hits'].map do |item|
          records[item['_type'.freeze]].detect do |record|
            record.id.to_s == item['_id'.freeze].to_s
          end
        end
      end

      def __find_records_by_ids(klass, ids)
        scope = @options[:load] === true ? klass.where(:id => ids) : klass.where(:id => ids).includes(@options[:load][:include])
        scope.to_a
      end
    end

  end
end
