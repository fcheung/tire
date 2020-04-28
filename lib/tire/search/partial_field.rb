module Tire
  module Search

    class PartialField
      def initialize(name='_tire_partial', &block)
        @value = {}
        @name = name
        block.arity < 1 ? self.instance_eval(&block) : block.call(self) if block_given?
      end


      def include(*values)
        @value['includes']= values
      end

      def exclude(*values)
        @value['excludes']= values
      end

      def to_hash
        {@name => @value}
      end

      def to_json(options={})
        to_hash.to_json
      end
    end

  end
end
