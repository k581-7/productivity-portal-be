require 'rails_helper'

RSpec.describe Supplier, type: :model do
  describe 'associations' do
    it 'belongs to assigned_pic (User)' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      supplier = Supplier.create!(name: 'Test Supplier', start_date: Date.today, assigned_pic: user)
      
      expect(supplier.assigned_pic).to eq(user)
    end

    it 'has many prod_entries' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      supplier = Supplier.create!(name: 'Test Supplier', start_date: Date.today, assigned_pic: user)
      prod_entry = ProdEntry.create!(
        supplier: supplier,
        entered_by_user: user,
        mapping_type: :auto,
        source: :api,
        date: Date.today
      )
      
      expect(supplier.prod_entries).to include(prod_entry)
    end
  end

  describe 'validations and common tests' do
    it 'can be created with valid attributes' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      supplier = Supplier.new(name: 'Test Supplier', start_date: Date.today, assigned_pic: user)
      
      expect(supplier.save).to be true
    end

    it 'validates uniqueness of name scoped to start_date' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      Supplier.create!(name: 'Duplicate', start_date: Date.today, assigned_pic: user)
      duplicate_supplier = Supplier.new(name: 'Duplicate', start_date: Date.today, assigned_pic: user)
      
      expect(duplicate_supplier.save).to be false
    end

    it 'has priority enum' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      supplier = Supplier.create!(name: 'Test Supplier', start_date: Date.today, assigned_pic: user, priority: :low)
      
      expect(supplier.low?).to be true
      
      supplier.high!
      expect(supplier.high?).to be true
    end

    it 'has status enum' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      supplier = Supplier.create!(name: 'Test Supplier', start_date: Date.today, assigned_pic: user, status: :queued)
      
      expect(supplier.queued?).to be true
      
      supplier.completed!
      expect(supplier.completed?).to be true
    end
  end
end
