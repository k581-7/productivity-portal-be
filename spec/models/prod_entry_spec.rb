require 'rails_helper'

RSpec.describe ProdEntry, type: :model do
  describe 'associations' do
    it 'belongs to entered_by_user' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      supplier_user = User.create!(email: 'supplier@example.com', name: 'Supplier User', role: :developer)
      supplier = Supplier.create!(name: 'Test Supplier', start_date: Date.today, assigned_pic: supplier_user)
      
      prod_entry = ProdEntry.create!(
        entered_by_user: user,
        supplier: supplier,
        mapping_type: :auto,
        source: :api,
        date: Date.today
      )
      
      expect(prod_entry.entered_by_user).to eq(user)
    end

    it 'belongs to supplier' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      supplier = Supplier.create!(name: 'Test Supplier', start_date: Date.today, assigned_pic: user)
      
      prod_entry = ProdEntry.create!(
        entered_by_user: user,
        supplier: supplier,
        mapping_type: :auto,
        source: :api,
        date: Date.today
      )
      
      expect(prod_entry.supplier).to eq(supplier)
    end

    it 'can have an optional assigned_user' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      assigned = User.create!(email: 'assigned@example.com', name: 'Assigned User', role: :developer)
      supplier = Supplier.create!(name: 'Test Supplier', start_date: Date.today, assigned_pic: user)
      
      prod_entry = ProdEntry.create!(
        entered_by_user: user,
        assigned_user: assigned,
        supplier: supplier,
        mapping_type: :auto,
        source: :api,
        date: Date.today
      )
      
      expect(prod_entry.assigned_user).to eq(assigned)
    end
  end

  describe 'validations and common tests' do
    it 'can be created with valid attributes' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      supplier = Supplier.create!(name: 'Test Supplier', start_date: Date.today, assigned_pic: user)
      
      prod_entry = ProdEntry.new(
        entered_by_user: user,
        supplier: supplier,
        mapping_type: :auto,
        source: :api,
        date: Date.today
      )
      
      expect(prod_entry.save).to be true
    end

    it 'requires entered_by_user' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      supplier = Supplier.create!(name: 'Test Supplier', start_date: Date.today, assigned_pic: user)
      
      prod_entry = ProdEntry.new(
        supplier: supplier,
        mapping_type: :auto,
        source: :api,
        date: Date.today
      )
      
      expect(prod_entry.save).to be false
    end

    it 'has mapping_type enum' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      supplier = Supplier.create!(name: 'Test Supplier', start_date: Date.today, assigned_pic: user)
      
      prod_entry = ProdEntry.create!(
        entered_by_user: user,
        supplier: supplier,
        mapping_type: :manual,
        source: :api,
        date: Date.today
      )
      
      expect(prod_entry.manual?).to be true
    end

    it 'has source enum' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      supplier = Supplier.create!(name: 'Test Supplier', start_date: Date.today, assigned_pic: user)
      
      prod_entry = ProdEntry.create!(
        entered_by_user: user,
        supplier: supplier,
        mapping_type: :auto,
        source: :csv_import,
        date: Date.today
      )
      
      expect(prod_entry.csv_import?).to be true
    end
  end
end
