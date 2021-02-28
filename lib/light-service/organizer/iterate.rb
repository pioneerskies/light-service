require 'light-service/action.rb'

module LightService
  module Organizer
    Iterate = Struct.new(:organizer, :collection_key, :steps) do
      include ScopedReducable

      def rollback(ctx)
        collection = ctx[collection_key]
        item_key = collection_key.to_s.singularize.to_sym
        collection.reverse_each do |item|
          ctx[item_key] = item
          steps.reverse_each do |action|
            action.rollback(ctx) if action.respond_to?(:rollback)
          end
        end

        ctx
      end

      def call(ctx)
        return ctx if ctx.stop_processing?

        collection = ctx[collection_key]
        item_key = collection_key.to_s.singularize.to_sym
        collection.each do |item|
          ctx[item_key] = item
          ctx = scoped_reduce(organizer, ctx, steps)
        end

        ctx
      end

      using LightService::Refinements::Array
      def self.run(organizer, collection_key, steps)
        new(organizer, collection_key, Array.wrap(steps))
      end
    end
  end
end
