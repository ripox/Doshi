# ============================================================================
# FILE: lib/tasks/round_tasks.rake
# ============================================================================
namespace :rounds do
  desc "Check for expired rounds and trigger payouts"
  task check_expired: :environment do
    expired_count = 0
    
    Round.active.find_each do |round|
      if round.expired?
        puts "Round #{round.id} (#{round.name}) has expired. Marking as expired..."
        round.mark_expired!
        expired_count += 1
      end
    end
    
    if expired_count > 0
      puts "Marked #{expired_count} round(s) as expired"
    else
      puts "No expired rounds found"
    end
  end
end
