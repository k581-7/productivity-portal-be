require 'rails_helper'

RSpec.describe DailyProd, type: :model do
  describe 'associations' do
    it 'belongs to user' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      daily_prod = DailyProd.create!(user: user, date: Date.today)
      
      expect(daily_prod.user).to eq(user)
    end
  end

  describe 'validations and common tests' do
    it 'can be created with valid attributes' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      daily_prod = DailyProd.new(user: user, date: Date.today)
      
      expect(daily_prod.save).to be true
    end

    it 'requires a date' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      daily_prod = DailyProd.new(user: user)
      
      expect(daily_prod.save).to be false
    end

    it 'requires a user' do
      daily_prod = DailyProd.new(date: Date.today)
      
      expect(daily_prod.save).to be false
    end

    it 'accepts valid status values' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      
      ['Exempted', 'Day Off', 'Offset', 'Leave'].each do |valid_status|
        daily_prod = DailyProd.create!(user: user, date: Date.today, status: valid_status)
        expect(daily_prod.status).to eq(valid_status)
      end
    end

    it 'sets totals to 0 when status is present' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      daily_prod = DailyProd.create!(
        user: user,
        date: Date.today,
        status: 'Exempted',
        auto_total: 100,
        manual_total: 50
      )
      
      expect(daily_prod.auto_total).to eq(0)
      expect(daily_prod.manual_total).to eq(0)
      expect(daily_prod.overall_total).to eq(0)
    end
  end
end
