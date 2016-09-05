module Tire
  module Search

    class Query
      attr_accessor :value

      def initialize(&block)
        @value = {}
        block.arity < 1 ? self.instance_eval(&block) : block.call(self) if block_given?
      end

      def term(field, value, options={})
        query = if value.is_a?(Hash)
          { field => value.to_hash }
        else
          { field => { :term => value }.update(options) }
        end
        @value = { :term => query }
      end

      def terms(field, value, options={})
        @value = { :terms => { field => value } }
        @value[:terms].update(options)
        @value
      end

      def range(field, value)
        @value = { :range => { field => value } }
      end

      def string(value, options={})
        @value = { :query_string => { :query => value } }
        @value[:query_string].update(options)
        @value
      end

      def prefix(field, value, options={})
        if options[:boost]
          @value = { :prefix => { field => { :prefix => value, :boost => options[:boost] } } }
        else
          @value = { :prefix => { field => value } }
        end
      end

      def custom_score(options={}, &block)
        raise "custom score query has been removed"
        @custom_score ||= Query.new(&block)
        @value[:custom_score] = options
        @value[:custom_score].update({:query => @custom_score.to_hash})
        @value
      end

      def constant_score(&block)
        @value.update( { :constant_score => ConstantScoreQuery.new(&block).to_hash } ) if block_given?
      end

      def fuzzy(field, value, options={})
        query = { field => { :term => value }.update(options) }
        @value = { :fuzzy => query }
      end

      def boolean(options={}, &block)
        @boolean ||= BooleanQuery.new(options)
        block.arity < 1 ? @boolean.instance_eval(&block) : block.call(@boolean) if block_given?
        @value[:bool] = @boolean.to_hash
        @value
      end

      def filtered(&block)
        @filtered = FilteredQuery.new
        block.arity < 1 ? @filtered.instance_eval(&block) : block.call(@filtered) if block_given?
        @value[:filtered] = @filtered.to_hash
        @value
      end

      def dis_max(options={}, &block)
        @dis_max ||= DisMaxQuery.new(options)
        block.arity < 1 ? @dis_max.instance_eval(&block) : block.call(@dis_max) if block_given?
        @value[:dis_max] = @dis_max.to_hash
        @value
      end

      def nested(options={}, &block)
        @nested = NestedQuery.new(options)
        block.arity < 1 ? @nested.instance_eval(&block) : block.call(@nested) if block_given?
        @value[:nested] = @nested.to_hash
        @value
      end

      def all(options = {})
        @value = { :match_all => options }
        @value
      end

      def ids(values, type=nil)
        @value = { :ids => { :values => Array(values) }  }
        @value[:ids].update(:type => type) if type
        @value
      end

      def boosting(options={}, &block)
        @boosting ||= BoostingQuery.new(options)
        block.arity < 1 ? @boosting.instance_eval(&block) : block.call(@boosting) if block_given?
        @value[:boosting] = @boosting.to_hash
        @value
      end

      def function_score(options={}, &block)
        function_score_query = FunctionScoreQuery.new(options)
        block.arity < 1 ? function_score_query.instance_eval(&block) : block.call(function_score_query) if block_given?
        @value[:function_score] = function_score_query.to_hash
        @value
      end

      def to_hash
        @value
      end

      def to_json(options={})
        to_hash.to_json
      end

    end

    class BooleanQuery

      # TODO: Try to get rid of multiple `should`, `must`, etc invocations, and wrap queries directly:
      #
      #       boolean do
      #         should do
      #           string 'foo'
      #           string 'bar'
      #         end
      #       end
      #
      # Inherit from Query, implement `encode` method there, and overload it here, so it puts
      # queries in an Array instead of hash.

      def initialize(options={}, &block)
        @options = options
        @value   = {}
        block.arity < 1 ? self.instance_eval(&block) : block.call(self) if block_given?
      end

      def must(&block)
        (@value[:must] ||= []) << Query.new(&block).to_hash
        @value
      end

      def must_not(type, *options)
        (@value[:must_not] ||= []) << Filter.new(type, *options).to_hash
        @value
      end

      def should(&block)
        (@value[:should] ||= []) << Query.new(&block).to_hash
        @value
      end

      def filter(type, *options)
        (@value[:filter] ||= []) << Filter.new(type, *options).to_hash
        @value
      end

      def to_hash
        @value.update(@options)
      end
    end

    class FilteredQuery
      def initialize(&block)
        @value = {}
        block.arity < 1 ? self.instance_eval(&block) : block.call(self) if block_given?
      end

      def query(options={}, &block)
        @value[:query] = Query.new(&block).to_hash
        @value
      end

      def filter(type, *options)
        @value[:filter] ||= {}
        @value[:filter][:and] ||= []
        @value[:filter][:and] << Filter.new(type, *options).to_hash
        @value
      end

      def to_hash
        @value
      end

      def to_json(options={})
        to_hash.to_json
      end
    end

    class ConstantScoreQuery
      def initialize(&block)
        @value = {}
        block.arity < 1 ? self.instance_eval(&block) : block.call(self) if block_given?
      end

      def filter(type, *options)
        @value[:filter] ||= {}
        @value[:filter][:and] ||= []
        @value[:filter][:and] << Filter.new(type, *options).to_hash
        @value
      end

      def query(&block)
        @value.update(:query => Query.new(&block).to_hash)
      end

      def boost(boost)
        @value.update(:boost => boost)
      end

      def to_hash
        @value
      end
    end

    class DisMaxQuery
      def initialize(options={}, &block)
        @options = options
        @value   = {}
        block.arity < 1 ? self.instance_eval(&block) : block.call(self) if block_given?
      end

      def query(&block)
        (@value[:queries] ||= []) << Query.new(&block).to_hash
        @value
      end

      def to_hash
        @value.update(@options)
      end

      def to_json(options={})
        to_hash.to_json
      end
    end

    class NestedQuery
      def initialize(options={}, &block)
        @options = options
        @value = {}
        block.arity < 1 ? self.instance_eval(&block) : block.call(self) if block_given?
      end

      def query(&block)
        @value[:query] = Query.new(&block).to_hash
        @value
      end

      def to_hash
        @value.update(@options)
      end

      def to_json
        to_hash.to_json
      end
    end

    class BoostingQuery
      def initialize(options={}, &block)
        @options = options
        @value   = {}
        block.arity < 1 ? self.instance_eval(&block) : block.call(self) if block_given?
      end

      def positive(&block)
        (@value[:positive] ||= []) << Query.new(&block).to_hash
        @value
      end

      def negative(&block)
        (@value[:negative] ||= []) << Query.new(&block).to_hash
        @value
      end

      def to_hash
        @value.update(@options)
      end
    end

    class FunctionScoreQuery
      def initialize(options={})
        @value = options.dup
      end

      def to_hash
        @value
      end

      def filter(type, *options)
        ensure_filter
        @value[:query][:bool][:filter] << Filter.new(type, *options).to_hash
        @value
      end

      def must_not(type, *options)
        ensure_must_not
        @value[:query][:bool][:must_not] << Filter.new(type, *options).to_hash
      end

      def query &block
        check_for_presence_of :query
        @value[:query] = Query.new(&block).to_hash
        @value
      end

      def script_score(script, lang:nil, params: {}, options:{})
        @value[:functions]||= []
        @value[:functions] << options.merge(:script_score => {script: {inline: script, lang:lang, params:params}}.reject {|k,v| v.blank?})
      end

      def boost_factor(value, options)
        @value[:functions]||= []
        @value[:functions] << options.merge(:weight => value)
      end

      def field_value_factor(field, function_options:{}, field_options:{})
        @value[:functions]||=[]
        @value[:functions] << {field_value_factor: {field: field}.merge(field_options)}.merge(function_options)
      end

      protected

      def ensure_filter
        @value[:query] ||= {bool: {}}
        raise "query is not a bool query" if @value[:query][:bool].nil?
        @value[:query][:bool][:filter]||=[]
      end

      def ensure_must_not
        @value[:query] ||= {bool: {}}
        raise "query is not a bool query" if @value[:query][:bool].nil?
        @value[:query][:bool][:must_not]||=[]
      end

      def check_for_presence_of key
        if @value[key]
          raise "Function score query does not support query and filter #{caller.join(';')}"
        end
      end
    end
  end
end
