module Tire
  module Search
    class Aggregation

      def initialize(name, type, body, &block)
        @name    = name
        @value = {type => body}
        block.arity < 1 ? self.instance_eval(&block) : block.call(self) if block_given?
      end

      def aggregate(name, type, body={}, &block)
        @value['aggregations'] ||= {}
        @value['aggregations'].update Aggregation.new(name, type, body, &block).to_hash
      end

      def to_hash
        {@name => @value}
      end
    end
  end
end
