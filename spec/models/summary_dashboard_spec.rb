require 'rails_helper'

RSpec.describe SummaryDashboard, type: :model do
  describe 'associations' do
    it 'belongs to user' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      summary = SummaryDashboard.create!(user: user, period_start: Date.today)
      
      expect(summary.user).to eq(user)
    end
  end

  describe 'validations and common tests' do
    it 'can be created with valid attributes' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      summary = SummaryDashboard.new(user: user, period_start: Date.today)
      
      expect(summary.save).to be true
    end

    it 'can store productivity totals' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      summary = SummaryDashboard.create!(
        user: user,
        period_start: Date.today,
        manual_total: 10,
        auto_total: 20,
        total_productivity: 30
      )
      
      expect(summary.manual_total).to eq(10)
      expect(summary.auto_total).to eq(20)
      expect(summary.total_productivity).to eq(30)
    end
  end
end
