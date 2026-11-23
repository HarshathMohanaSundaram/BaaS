class Stripe::CreateAccountJob < ApplicationJob
  queue_as :default

  def perform(*args)
    puts "Stripe::CreateAccountJob called with args: #{args.inspect}"
  end
end
