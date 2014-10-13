module Tire
  module Search

    class Source
      def initialize(&block)
        @value = {}
        block.arity < 1 ? self.instance_eval(&block) : block.call(self) if block_given?
      end


      def include(*values)
        @value['include']= values
      end
        
      def exclude(*values)
        @value['exclude']= values
      end

      def to_hash
        @value
      end

      def to_json(options={})
        @value.to_json
      end
    end

  end
end
