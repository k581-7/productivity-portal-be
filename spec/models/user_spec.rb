require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it 'has many daily_prods' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      daily_prod = DailyProd.create!(user: user, date: Date.today)
      
      expect(user.daily_prods).to include(daily_prod)
    end

    it 'has many todos' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      todo = Todo.create!(user: user, content: 'Test todo')
      
      expect(user.todos).to include(todo)
    end

    it 'has many suppliers' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      supplier = Supplier.create!(name: 'Test Supplier', start_date: Date.today, assigned_pic: user)
      
      expect(user.suppliers).to include(supplier)
    end
  end

  describe 'validations and common tests' do
    it 'can be created with valid attributes' do
      user = User.new(email: 'test@example.com', name: 'Test User', role: :developer)
      expect(user.save).to be true
    end

    it 'has role enum' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      expect(user.developer?).to be true
      
      user.leader!
      expect(user.leader?).to be true
    end
  end
end
