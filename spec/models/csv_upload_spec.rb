require 'rails_helper'

RSpec.describe CsvUpload, type: :model do
  describe 'associations' do
    it 'belongs to supplier' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      supplier = Supplier.create!(name: 'Test Supplier', start_date: Date.today, assigned_pic: user)
      
      csv_upload = CsvUpload.create!(
        supplier: supplier,
        uploaded_by: user,
        batch_id: 'BATCH001',
        filename: 'test.csv',
        source_type: 'manual'
      )
      
      expect(csv_upload.supplier).to eq(supplier)
    end

    it 'belongs to uploaded_by (User)' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      supplier = Supplier.create!(name: 'Test Supplier', start_date: Date.today, assigned_pic: user)
      
      csv_upload = CsvUpload.create!(
        supplier: supplier,
        uploaded_by: user,
        batch_id: 'BATCH001',
        filename: 'test.csv',
        source_type: 'manual'
      )
      
      expect(csv_upload.uploaded_by).to eq(user)
    end
  end

  describe 'validations and common tests' do
    it 'can be created with valid attributes' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      supplier = Supplier.create!(name: 'Test Supplier', start_date: Date.today, assigned_pic: user)
      
      csv_upload = CsvUpload.new(
        supplier: supplier,
        uploaded_by: user,
        batch_id: 'BATCH001',
        filename: 'test.csv',
        source_type: 'manual'
      )
      
      expect(csv_upload.save).to be true
    end

    it 'requires batch_id to be unique' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      supplier = Supplier.create!(name: 'Test Supplier', start_date: Date.today, assigned_pic: user)
      
      CsvUpload.create!(
        supplier: supplier,
        uploaded_by: user,
        batch_id: 'BATCH001',
        filename: 'test.csv',
        source_type: 'manual'
      )
      
      duplicate = CsvUpload.new(
        supplier: supplier,
        uploaded_by: user,
        batch_id: 'BATCH001',
        filename: 'test2.csv',
        source_type: 'manual'
      )
      
      expect(duplicate.save).to be false
    end

    it 'requires batch_id' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      supplier = Supplier.create!(name: 'Test Supplier', start_date: Date.today, assigned_pic: user)
      
      csv_upload = CsvUpload.new(
        supplier: supplier,
        uploaded_by: user,
        filename: 'test.csv',
        source_type: 'manual'
      )
      
      expect(csv_upload.save).to be false
    end
  end
end
