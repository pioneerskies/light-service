require 'spec_helper'

class RollbackWithIterationOrganizer
  extend LightService::Organizer

  def self.call(number, times)
    with(:number => number, :times => 0..times).reduce(
      AddsOneActionWithRollback,
      iterate(:times, AddsOneActionWithRollback),
      AddsTwoActionWithRollback
    )
  end
end

class AddsOneActionWithRollback
  extend LightService::Action
  expects :number
  promises :number

  executed do |ctx|
    ctx.number += 1
  end

  rolled_back do |ctx|
    ctx.number -= 1
  end
end

class AddsTwoActionWithRollback
  extend LightService::Action
  expects :number

  executed do |context|
    context.number = context.number + 2
    context.fail_with_rollback!("I did not like this a bit!")
  end

  rolled_back do |context|
    context.number -= 2
  end
end

class RollbackWithIterationOrganizerIndexDependent
  extend LightService::Organizer

  def self.call(string:, words:)
    with(:string => string, :words => words).reduce(
      iterate(:words, ConcatenateString),
      CallRollback
    )
  end
end

class ConcatenateString
  extend LightService::Action
  expects :string,
          :word
  promises :string

  executed do |context|
    context.string.concat context.word
  end

  rolled_back do |context|
    context.string.chomp! context.word
  end
end

class CallRollback
  extend LightService::Action

  executed do |context|
    context.fail_with_rollback!('Arbitrary rollback.')
  end
end

describe "Rolling back actions when there is a failure" do
  it "Increment using iterate and rollback to revert value to zero" do
    result = RollbackWithIterationOrganizer.call(0, 3)
    number = result.fetch(:number)

    expect(result).to be_failure
    expect(result.message).to eq("I did not like this a bit!")
    expect(number).to eq(0)
  end

  # When the iterated collection is not just "exploited" as an iterator, but it contains
  # data that will be processed and the order will determinate a specific outcome, then
  # rolling back in reversed collection's order will turn critical.
  context 'when the order of the iterated collection is important' do
    it 'will apply rollback on each action with in correct order' do
      result = RollbackWithIterationOrganizerIndexDependent.call(
        string: 'sausage',
        words: ['bacon', 'spam']
      )
      expect(result.fetch(:string)).to eq('sausage')
    end
  end
end
